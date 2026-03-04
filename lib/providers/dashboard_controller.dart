import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ftpconnect/ftpconnect.dart';

// 1. State
// TODO Error
enum DashboardState { idle, connecting, connected, syncing, success, error }

class DashboardModel {
  final DashboardState state;
  final String? saveDir;
  final String? lastIp;
  final int? lastPort;
  final FTPConnect? ftpClient;

  const DashboardModel({
    this.state = DashboardState.idle,
    this.saveDir,
    this.lastIp,
    this.lastPort,
    this.ftpClient,
  });

  DashboardModel copyWith({
    DashboardState? state,
    String? saveDir,
    String? lastIp,
    int? lastPort,
    FTPConnect? ftpClient,
  }) {
    return DashboardModel(
      state: state ?? this.state,
      saveDir: saveDir ?? this.saveDir,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      ftpClient: ftpClient ?? this.ftpClient,
    );
  }
}

// 2. Controller
class DashboardController extends Notifier<DashboardModel> {

  @override
  DashboardModel build() {
    return const DashboardModel();
  }

  Future<bool> connect(String ip, int port) async {
    state = state.copyWith(state: DashboardState.connecting);

    final client = FTPConnect(ip, port: port);
    try {
      await client.connect();
      state = state.copyWith(
        state: DashboardState.connected,
        lastIp: ip,
        lastPort: port,
        ftpClient: client,
      );
      return true;
    } catch (e) {
      state = state.copyWith(state: DashboardState.error);
      return false;
    }
  }

  void setSaveDir(String path) {
    state = state.copyWith(saveDir: path);
  }

  Future<void> sync() async {
    if (state.saveDir == null || state.ftpClient == null) return;
    // TODO Download files from setSaveDir
    //      It's very finicky, best bet is to copy behavior of https://github.com/Inevitabby/DS-OTA-Backup
    state = state.copyWith(state: DashboardState.syncing);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(state: DashboardState.success);
  }

  // TODO Should I go more ham with the sorting? directories before files *feels* like an existing standard, but is that just a me thing?
  //      What about favoring DIR -> SAVE FILES -> OTHER FILES?
  Future<List<FTPEntry>> list() async {
    if (state.ftpClient == null) return [];
    try {
      List<FTPEntry> entries = await state.ftpClient!.listDirectoryContent();
      // Paranoia check
      entries = entries.where((entry) {
        return entry.type == FTPEntryType.dir || entry.type == FTPEntryType.file;
      }).toList();
      // TODO Is the FTP server returning the absolute path to the CWD, or is it the library?
      if (entries.isNotEmpty && entries.first.name == await currentDir()) {
        entries = entries.sublist(1);
      }
      entries.sort((a, b) {
        if (a.type != b.type) return a.type == FTPEntryType.dir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return entries;
    } catch (e) {
      return [];
    }
  }

  Future<bool> changeDir(String path) async {
    if (state.ftpClient == null) return false;
    try {
      return await state.ftpClient!.changeDirectory(path);
    } catch (e) {
      return false;
    }
  }

  Future<String> currentDir() async {
    if (state.ftpClient == null) return "";
    try {
      return await state.ftpClient!.currentDirectory();
    } catch (e) {
      return "";
    }
  }

  Future<void> reset() async {
    try {
      await state.ftpClient?.disconnect();
    } catch (_) {}
    state = const DashboardModel();
  }
}

// 3. Provider
final dashboardProvider = NotifierProvider<DashboardController, DashboardModel>(DashboardController.new);

