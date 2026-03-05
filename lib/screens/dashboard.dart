import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/modals/browser.dart';
import 'package:nds_save_sync/modals/ip_entry.dart';
import 'package:nds_save_sync/providers.dart';

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
    AppModel appState,
  ) async {
    final controller = ref.read(appProvider.notifier);

    switch (appState.syncState) {
      case SyncState.idle:
        // Connect to FTP server
        if (appState.lastIp != null && appState.lastPort != null) {
          if (await controller.connect(appState.lastIp!, appState.lastPort!)) {
            break;
          }
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
        if (result != null) {
          controller.connect(result['ip'], result['port']);
        }
        break;
      case SyncState.connecting:
        break; // ignore
      case SyncState.connected:
        if (appState.saveDir != null) {
          controller.sync();
          break;
        }
        // Special: Pick Save Folder
        await appState.ftp.changeDir('/');
        final selectedPath = await showDialog<String>(
          context: context,
          builder: (_) => const Dialog(
            insetPadding: EdgeInsets.all(16),
            child: Browser(),
          ),
        );
        if (selectedPath == null) break;
        controller.setSaveDir(selectedPath);
        controller.sync();
        break;
      case SyncState.syncing:
      case SyncState.success:
        break; // ignore
      case SyncState.error: // TODO only for debugging
        controller.reset();
        break;

    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appProvider);
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
                  TextButton(onPressed: () => _onPressed(context, ref, appState), child: Text(_getText(appState.syncState)))
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

String _getText(SyncState state) {
  switch (state) {
    case SyncState.idle:
      return 'IDLE (Tap to Connect)';
    case SyncState.connecting:
      return 'CONNECTING...';
    case SyncState.connected:
      return 'CONNECTED (Tap to Sync)';
    case SyncState.syncing:
      return 'SYNCING...';
    case SyncState.success:
      return 'SUCCESS'; // TODO some sort of indicator to view Save Archive
    case SyncState.error:
      return 'ERROR (Tap to Retry)';
  }
}
