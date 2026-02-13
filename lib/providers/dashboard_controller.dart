import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. State
enum DashboardState { idle, scanning, connected, working, success }

class DashboardModel {
  final DashboardState state;
  final String? saveDir;
  final String? lastAddr;

  const DashboardModel({
    this.state = DashboardState.idle,
    this.saveDir,
    this.lastAddr,
  });

  DashboardModel copyWith({
    DashboardState? state,
    String? saveDir,
    String? lastAddr,
  }) {
    return DashboardModel(
      state: state ?? this.state,
      saveDir: saveDir ?? this.saveDir,
      lastAddr: lastAddr ?? this.lastAddr,
    );
  }
}

// 2. Controller
class DashboardController extends Notifier<DashboardModel> {
  @override
  DashboardModel build() {
    return const DashboardModel();
  }

  Future<void> scan() async {
    // TODO Scan for the console. Try in order:
    // 1. lastAddr (if exists)
    // 2. Current Hotspot subnet (if connected)
    // 3. Current WiFi subnet (if connected)
    //
    // Also responsible for setting lastAddr
  }

  void setSaveDir(String path) {
    state = state.copyWith(saveDir: path);
  }

  Future<void> sync() async {
    // TODO Download files from setSaveDir
    //      It's very finicky, best bet is to copy behavior of https://github.com/Inevitabby/DS-OTA-Backup
  }

  void reset() { state = const DashboardModel(); }
}

// 3. Provider
final dashboardProvider = NotifierProvider<DashboardController, DashboardModel>(DashboardController.new);
