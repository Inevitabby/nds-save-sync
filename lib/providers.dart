import 'dart:io';
 
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
    this.lastIp,
    this.lastPort,
    this.lastSyncResult,
    this.saveDir,
    this.syncProgress,
    this.syncState = SyncState.idle,
  });
 
  final FtpClient ftp;
  final String? archiveUri;
  final String? lastIp;
  final int? lastPort;
  final SyncResult? lastSyncResult;
  final String? saveDir;
  final SyncProgress? syncProgress;
  final SyncState syncState;
 
  AppModel copyWith({
    String? archiveUri,
    String? lastIp,
    int? lastPort,
    SyncResult? lastSyncResult,
    String? saveDir,
    SyncProgress? syncProgress,
    SyncState? syncState,
  }) {
    return AppModel(
      ftp: ftp,
      archiveUri: archiveUri ?? this.archiveUri,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
      saveDir: saveDir ?? this.saveDir,
      syncProgress: syncProgress ?? this.syncProgress,
      syncState: syncState ?? this.syncState,
    );
  }
 
  AppModel clearProgress() => AppModel(
    ftp: ftp,
    archiveUri: archiveUri,
    lastIp: lastIp,
    lastPort: lastPort,
    lastSyncResult: lastSyncResult,
    saveDir: saveDir,
    syncState: syncState,
  );
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
    );
  }

  AppModel get _model => state.requireValue;

  void _update(AppModel next) => state = AsyncValue.data(next);

  Future<bool> connect(String ip, int port) async {
    _update(_model.copyWith(syncState: SyncState.connecting));

    final success = await _model.ftp.connect(ip, port);
    if (success) {
      _update(_model.copyWith(
        syncState: SyncState.connected,
        lastIp: ip,
        lastPort: port,
      ));
      await Persistence.saveLastIp(ip);
      await Persistence.saveLastPort(port);
    } else {
      _update(_model.copyWith(syncState: SyncState.error));
    }
    return success;
  }

  // TODO Perhaps calling all the DS stuff "remoteX" would be better...
  Future<void> setSaveDir(String path) async {
    _update(_model.copyWith(saveDir: path));
    await Persistence.saveSaveDir(path);
  }

  Future<String?> setArchiveUri() async {
    final uri = await SafFolderPicker.pickFolder();
    if (uri != null) {
      _update(_model.copyWith(archiveUri: uri));
      await Persistence.saveArchiveUri(uri);
    }
    return uri;
  }

  Future<void> sync() async {
    if (_model.saveDir == null || !_model.ftp.isConnected) return;
    _update(_model.copyWith(syncState: SyncState.syncing));

    if (_model.archiveUri == null) {
      // TODO need a popup or something to ask the user "Where would you like to store your save backups?" first
      final uri = await setArchiveUri();
      if (uri == null) return;
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

      _update(
        _model.clearProgress().copyWith(
          syncState: SyncState.success,
          lastSyncResult: SyncResult(
            changed: syncResult.changed,
            unchanged: syncResult.unchanged,
            failures: [...downloadResult.failures, ...syncResult.failures],
          ),
        ),
      );
    } catch (e) {
      _update(_model.clearProgress().copyWith(syncState: SyncState.error));
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

/* 
 * Provider
 */

final appProvider = AsyncNotifierProvider<AppController, AppModel>(
  AppController.new,
);
