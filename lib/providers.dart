import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/ftp.dart';
import 'package:nds_save_sync/persistence.dart';

/* 
 * State
 */

// TODO Error state isn't developed
enum SyncState { idle, connecting, connected, syncing, success, error }

class AppModel {
  const AppModel({
    required this.ftp,
    this.syncState = SyncState.idle,
    this.saveDir,
    this.lastIp,
    this.lastPort,
    this.archiveUri,
  });

  final SyncState syncState;
  final String? saveDir;
  final String? lastIp;
  final int? lastPort;
  final String? archiveUri;
  final FtpClient ftp;


  AppModel copyWith({
    SyncState? syncState,
    String? saveDir,
    String? lastIp,
    int? lastPort,
    String? archiveUri,
  }) {
    return AppModel(
      syncState: syncState ?? this.syncState,
      saveDir: saveDir ?? this.saveDir,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      archiveUri: archiveUri ?? this.archiveUri,
      ftp: ftp,
    );
  }
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
    return null;
    // TODO Implement
  }

  Future<void> sync() async {
    if (_model.saveDir == null || !_model.ftp.isConnected) return;
    _update(_model.copyWith(syncState: SyncState.syncing));

    // TODO Implement
    //   1. ftp.downloadSaves(state.saveDir!, stagingDir)
    //   2. Compare each file against last-downloaded version (need to develop archive)
    //   3. Copy changed files into the save archive
    //   4. Update UI with per-file progress
    await Future.delayed(const Duration(seconds: 2));

    _update(_model.copyWith(syncState: SyncState.success));
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
