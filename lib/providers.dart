import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/ftp.dart';
import 'package:nds_save_sync/persistence.dart';
import 'package:nds_save_sync/saf.dart';
import 'package:nds_save_sync/sync.dart';
import 'package:path_provider/path_provider.dart';

/* 
 * State
 */

// TODO Error state isn't developed
enum SyncState { idle, connecting, connected, syncing, success, error }

class AppModel {
  const AppModel({
    required this.ftp,
    this.archiveUri,
    this.consecutiveConnectFailures = 0,
    this.lastIp,
    this.lastPort,
    this.lastSyncResult,
    this.notification,
    this.saveDir,
    this.syncProgress,
    this.syncState = SyncState.idle,
  });
 
  final FtpClient ftp;
  final String? archiveUri;
  final int consecutiveConnectFailures;
  final String? lastIp;
  final int? lastPort;
  final SyncResult? lastSyncResult;
  final String? notification;
  final String? saveDir;
  final SyncProgress? syncProgress;
  final SyncState syncState;
 
  AppModel copyWith({
    String? archiveUri,
    int? consecutiveConnectFailures,
    String? lastIp,
    int? lastPort,
    SyncResult? lastSyncResult,
    String? notification,
    String? saveDir,
    SyncProgress? syncProgress,
    SyncState? syncState,
  }) {
    return AppModel(
      ftp: ftp,
      archiveUri: archiveUri ?? this.archiveUri,
      consecutiveConnectFailures: consecutiveConnectFailures ?? this.consecutiveConnectFailures,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
      notification: notification ?? this.notification,
      saveDir: saveDir ?? this.saveDir,
      syncProgress: syncProgress ?? this.syncProgress,
      syncState: syncState ?? this.syncState,
    );
  }
 
  AppModel clearProgress() => AppModel(
    ftp: ftp,
    archiveUri: archiveUri,
    consecutiveConnectFailures: consecutiveConnectFailures,
    lastIp: lastIp,
    lastPort: lastPort,
    lastSyncResult: lastSyncResult,
    notification: notification,
    saveDir: saveDir,
    syncState: syncState,
  );

  AppModel clearNotification() => copyWith(notification: '');
}

/*
 * Controller
 */

class AppController extends AsyncNotifier<AppModel> {
  @override
  Future<AppModel> build() async {
    final persisted = await Persistence.load();
    // if (kDebugMode) return AppModel(ftp: FtpClient());
    return AppModel(
      ftp: FtpClient(),
      lastIp: persisted.lastIp,
      lastPort: persisted.lastPort,
      saveDir: persisted.saveDir,
      archiveUri: persisted.archiveUri,
      notification: 'Ready to connect to NDS.',
    );
  }

  AppModel get _model => state.requireValue;

  void _update(AppModel next) => state = AsyncValue.data(next);

  Future<bool> connect(String ip, int port) async {
    _update(
      _model.copyWith(
        syncState: SyncState.connecting,
        notification: 'Attempting to reach device...',
      ),
    );

    final success = await _model.ftp.connect(ip, port);
    if (success) {
      _update(_model.copyWith(
        syncState: SyncState.connected,
        consecutiveConnectFailures: 0,
        lastIp: ip,
        lastPort: port,
        notification: 'Connected to NDS.',
      ));
      await Persistence.saveLastIp(ip);
      await Persistence.saveLastPort(port);
    } else {
      _update(_model.copyWith(
        syncState: SyncState.idle,
        consecutiveConnectFailures: _model.consecutiveConnectFailures + 1,
        notification: "Couldn't reach $ip:$port. Is your NDS on?",
      ));
    }
    return success;
  }

  // TODO Perhaps calling all the NDS stuff "remoteX" would be better...
  Future<void> setSaveDir(String path) async {
    _update(_model.copyWith(saveDir: path));
    await Persistence.saveSaveDir(path);
  }

  // Returns the picked URI, or null if the user cancelled.
  Future<String?> pickArchiveUri() async {
    final uri = await SafFolderPicker.pickFolder();
    if (uri != null) {
      _update(_model.copyWith(archiveUri: uri, notification: ''));
      await Persistence.saveArchiveUri(uri);
    } else {
      _update(_model.copyWith(notification: 'User cancelled folder selection.'));
    }
    return uri;
  }

  void clearNotification() => _update(_model.clearNotification());

  Future<void> sync() async {
    if (_model.saveDir == null) return;
    if (_model.archiveUri == null) return;

    _update(
      _model.copyWith(
        syncState: SyncState.syncing,
        notification: 'Preparing to sync...',
      ),
    );

    // Attempt a reconnect if disconnected
    if (!_model.ftp.isConnected) {
      if (_model.lastIp == null || _model.lastPort == null) return;
      final reconnected = await _model.ftp.connect(
        _model.lastIp!,
        _model.lastPort!,
      );
      if (!reconnected) {
        _update(
          _model.copyWith(
            syncState: SyncState.error,
            notification: 'Lost connection to NDS.',
          ),
        );
        return;
      }
    }

    // Temporary staging dir
    final tempBase = await getTemporaryDirectory();
    final stagingDir = Directory(
      '${tempBase.path}/nds_save_sync_staging_${DateTime.now().millisecondsSinceEpoch}',
    );
    await stagingDir.create(recursive: true);

    try {
      // 1. Download to staging
      final downloadResult = await _model.ftp.downloadSaves(
        remoteDir: _model.saveDir!,
        stagingDir: stagingDir,
        onProgress: (filename, done, total) {
          _update(
            _model.copyWith(
              syncProgress: SyncProgress(
                currentFile: filename,
                done: done,
                total: total,
              ),
            ),
          );
        },
      );

      // 2. Compare against latest and archive changed files
      final syncResult = await syncToArchive(
        stagedFiles: downloadResult.files,
        archiveUri: _model.archiveUri!,
        onProgress: (filename, done, total) {
          _update(
            _model.copyWith(
              syncProgress: SyncProgress(
                currentFile: filename,
                done: done,
                total: total,
                phase: SyncPhase.archiving,
              ),
            ),
          );
        },
      );

      final combined = SyncResult(
        changed: syncResult.changed,
        unchanged: syncResult.unchanged,
        failures: [...downloadResult.failures, ...syncResult.failures],
      );

      _update(
        _model.clearProgress().copyWith(
          syncState: SyncState.success,
          lastSyncResult: combined,
          notification: _outcomeNotification(combined),
        ),
      );
    } catch (e) {
      _update(_model.clearProgress().copyWith(
        syncState: SyncState.error,
        notification: 'Sync failed.',
      ));
    } finally {
      try {
        if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> reset() async {
    await _model.ftp.disconnect();
    ref.invalidateSelf();
  }
}

// TODO swipe right for log
String _outcomeNotification(SyncResult result) {
  final updated = result.changed.length;
  final failed = result.failures.length;

  if (failed > 0 && updated == 0) {
    return '$failed save${failed == 1 ? '' : 's'} failed.';
  }
  if (failed > 0) {
    return '$updated archived. $failed failed.';
  }
  if (updated == 0) {
    return 'All saves checked, nothing new to archive.';
  }
  return '$updated save${updated == 1 ? '' : 's'} archived.';
}

/* 
 * Provider
 */

final appProvider = AsyncNotifierProvider<AppController, AppModel>(
  AppController.new,
);
