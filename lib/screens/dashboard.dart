import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/modals/browser.dart';
import 'package:nds_save_sync/modals/ip_entry.dart';
import 'package:nds_save_sync/providers/dashboard_controller.dart';

// STATES
// 
// 1. Idle (Disconnected):
//  - Condition: Initial state
//  - Hero: "Connect to Device" (TODO wording)
// 
// 2. Connecting:
//  - Hero: "Connecting to your DS..."
// 
// 3. Connected:
//  - Condition: Connection established to DS.
//  - Case A: First-Connection
//    - Hero: Modal showing FTP directory browser, user finds and picks saveDir folder
//  - Case B: Ready
//    - Hero: "Tap to Sync" TODO Or just jump straight to syncing and save a tap?
// 
// 4. Syncing
//  - Condition: Sync started
//  - Hero: Some sort of live log/progress indicator. The *bulk* of time will be waiting on the crap link so this'll need to be good. (TODO Design this)
// 
// 5. Success:
//  - Condition: Sync completed
//  - Hero: TODO Some sort of success indicator and something telling the user to check their archive. i.e., "Swipe left to see saves" or something

// OTHER LOCATIONS
// - Left: Save Archive
// - Right: Settings xor Debug (Version Information and Logs (TODO Plan this side))
// 
// TODO Alternatively, just a slide-up modal for Save Archive, I may forgo settings for simplicity's sake.

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  Future<void> _onPressed(
    BuildContext context,
    WidgetRef ref,
    DashboardModel dashboardState,
  ) async {
    final controller = ref.read(dashboardProvider.notifier);

    switch (dashboardState.state) {
      case DashboardState.idle:
        // Connect to FTP server
        if (dashboardState.lastIp != null && dashboardState.lastPort != null) {
          if (await controller.connect(dashboardState.lastIp!, dashboardState.lastPort!)) break;
          // TODO This case is when we failed to connect to saved IP. Log it something here.
        }
        // Special: Ask user for FTP server info
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: const IpEntry(),
            ),
          ),
        );
        if (result != null) controller.connect(result['ip'], result['port']);
        break;
      case DashboardState.connecting:
        break; // ignore
      case DashboardState.connected:
        if (dashboardState.saveDir == null) {
          await controller.changeDir("/");
          final selectedPath = await showDialog<String>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: const Browser(),
            ),
          );
          if (selectedPath == null) break;
          controller.setSaveDir(selectedPath);
          // TODO ...
        } else {
          // 3. Start Syncing if connected and directory is set
          // controller.sync();
        }
        break;
      case DashboardState.syncing:
      case DashboardState.success:
        break; // ignore
      case DashboardState.error: // TODO only for debugging
        controller.reset();
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text('Network')),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: Center(child: 
                  TextButton(onPressed: () => _onPressed(context, ref, dashboardState), child: Text(_getText(dashboardState.state)))
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text('Notifications')),
              ),
            ),
            Expanded( // TODO Left: Save Archive, Right: Settings
              flex: 1,
              child: Container(
                decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary ) ),
                child: const Center(child: Text('Slider Indicators')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _getText(DashboardState state) {
  switch (state) {
    case DashboardState.idle:
      return "IDLE (Tap to Connect)";
    case DashboardState.connecting:
      return "CONNECTING...";
    case DashboardState.connected:
      return "CONNECTED (Tap to Sync)";
    case DashboardState.syncing:
      return "SYNCING...";
    case DashboardState.success:
      return "SUCCESS"; // TODO some sort of indicator to view Save Archive
    case DashboardState.error:
      return "ERROR (Tap to Retry)";
  }
}
