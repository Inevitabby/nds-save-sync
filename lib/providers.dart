import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/ftp.dart';

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
  });

  final SyncState syncState;
  final String? saveDir;
  final String? lastIp;
  final int? lastPort;
  final FtpClient ftp;


  AppModel copyWith({
    SyncState? syncState,
    String? saveDir,
    String? lastIp,
    int? lastPort,
  }) {
    return AppModel(
      syncState: syncState ?? this.syncState,
      saveDir: saveDir ?? this.saveDir,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      ftp: ftp,
    );
  }
}

/*
 * Controller
 */

class AppController extends Notifier<AppModel> {
  @override
  AppModel build() {
    return AppModel(ftp: FtpClient());
  }

  Future<bool> connect(String ip, int port) async {
    state = state.copyWith(syncState: SyncState.connecting);

    final success = await state.ftp.connect(ip, port);
    if (success) {
      state = state.copyWith(
        syncState: SyncState.connected,
        lastIp: ip,
        lastPort: port,
      );
    } else {
      state = state.copyWith(syncState: SyncState.error);
    }
    return success;
  }

  void setSaveDir(String path) {
    state = state.copyWith(saveDir: path);
  }

  Future<void> sync() async {
    if (state.saveDir == null || !state.ftp.isConnected) return;
    state = state.copyWith(syncState: SyncState.syncing);

    // TODO Implement
    //   1. ftp.downloadSaves(state.saveDir!, stagingDir)
    //   2. Compare each file against last-downloaded version (need to develop archive)
    //   3. Copy changed files into the save archive
    //   4. Update UI with per-file progress
    await Future.delayed(const Duration(seconds: 2));

    state = state.copyWith(syncState: SyncState.success);
  }

  Future<void> reset() async {
    await state.ftp.disconnect();
    state = AppModel(ftp: FtpClient());
  }
}

/* 
 * Provider
 */

final appProvider = NotifierProvider<AppController, AppModel>(
  AppController.new,
);
