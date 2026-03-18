import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/modals/browser.dart';
import 'package:nds_save_sync/modals/ip_entry.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/sync.dart';
import 'package:nds_save_sync/widgets/sync_button.dart';

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

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  bool _showFailures = false;

  Future<void> _onPressed(AppModel appState) async {
    final controller = ref.read(appProvider.notifier);

    switch (appState.syncState) {
      case SyncState.idle:
        if (appState.lastIp != null && appState.lastPort != null) {
          // Special: Let the user correct the IP after second connection failure
          if (appState.consecutiveConnectFailures >= 1) {
            await _showIpDialog(appState, controller);
            break;
          }
          if (await controller.connect(appState.lastIp!, appState.lastPort!)) {
            break;
          }
          // NTS: On first failure notification is already set by controller
          break;
        }
        await _showIpDialog(appState, controller);
        break;

      case SyncState.connecting:
        break; // ignore

      case SyncState.connected:
        if (appState.saveDir != null) {
          await _syncWithArchiveGuard(appState, controller);
          break;
        }
        // First connection: pick the remote save folder
        await appState.ftp.changeDir('/');
        final selectedPath = await showDialog<String>(
          context: context,
          builder: (_) => const Dialog(
            insetPadding: EdgeInsets.all(16),
            child: Browser(),
          ),
        );
        if (selectedPath == null) break;
        await controller.setSaveDir(selectedPath);
        await _syncWithArchiveGuard(
          ref.read(appProvider).requireValue,
          controller,
        );
        break;

      case SyncState.syncing:
        break; // ignore
      case SyncState.success:
        if (kDebugMode) {
          controller.reset();
        }
        break;

      case SyncState.error: // TODO only for debugging
        controller.reset();
        break;
    }
  }

  Future<void> _showIpDialog(AppModel appState, AppController controller) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: IpEntry(
            initialIp: appState.lastIp,
            initialPort: appState.lastPort,
          ),
        ),
      ),
    );
    if (result != null) {
      controller.connect(result['ip'], result['port']);
    }
  }

  // Shows a one-time setup dialog if archiveUri is not yet set, then syncs.
  Future<void> _syncWithArchiveGuard(
    AppModel appState,
    AppController controller,
  ) async {
    if (appState.archiveUri == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Choose a Backup Folder'),
          content: const Text(
            'Choose a folder on your phone to store save backups. '
            'This is a one-time setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Choose Folder'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final uri = await controller.pickArchiveUri();
      if (uri == null) return;
    }
    controller.sync();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appProvider);
    return asyncState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Failed to load: $err')),
      ),
      data: (appState) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary)),
                    child: const Center(child: Text('Network')),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SyncButton(
                      state: appState.syncState,
                      onPressed: () => _onPressed(appState),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary)),
                    child: _NotificationsPanel(
                      appState: appState,
                      showFailures: _showFailures,
                      onToggleFailures: () => setState(() => _showFailures = !_showFailures),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(border: BoxBorder.all(color: colorScheme.primary)),
                    child: const Center(child: Text('Slider Indicators')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.appState,
    required this.showFailures,
    required this.onToggleFailures,
  });

  final AppModel appState;
  final bool showFailures;
  final VoidCallback onToggleFailures;

  bool get _hasNotification =>
      appState.notification != null && appState.notification!.isNotEmpty;

  bool get _hasFailures =>
      (appState.lastSyncResult?.hasFailures ?? false) &&
      (_hasNotification && appState.notification!.contains('tap for details'));

  @override
  Widget build(BuildContext context) {
    final progress = appState.syncProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress != null) ...[
            Text(
              progress.phase == SyncPhase.archiving
                  ? 'Archiving...'
                  : _progressText(progress),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            progress.phase == SyncPhase.archiving
                ? const LinearProgressIndicator()
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: progress.fraction),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, value, __) => LinearProgressIndicator(value: value),
                  ),
          ] else if (_hasNotification) ...[
            _hasFailures
                ? GestureDetector(
                    onTap: onToggleFailures,
                    child: Text(
                      appState.notification!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Text(
                    appState.notification!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
            if (showFailures && _hasFailures) ...[
              const SizedBox(height: 8),
              ...appState.lastSyncResult!.failures.map(
                (f) => Text(
                  f,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ] else
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

String _progressText(SyncProgress progress) {
  final verb = switch (progress.phase) {
    SyncPhase.downloading => 'Downloading',
    SyncPhase.archiving   => 'Archiving',
  };
  return '$verb ${progress.currentFile} [${progress.fileIndex} / ${progress.total}]';
}
