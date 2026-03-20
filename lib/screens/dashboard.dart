import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/modals/browser.dart';
import 'package:nds_save_sync/modals/ip_entry.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/sync.dart';
import 'package:nds_save_sync/widgets/sync_button.dart';

// OTHER LOCATIONS
// - Swipe Left: Save Archive
// - Swipe Right: Settings xor Debug (Version Information and Logs (TODO Plan this side))

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  bool _dialogOpen = false;

  Future<void> _onPressed(AppModel appState) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      await _onPressedInner(appState);
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _onPressedInner(AppModel appState) async {
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
        if (selectedPath == 'error') {
          await _showIpDialog(appState, controller);
          break;
        }
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
        controller.reset(); // TODO implement something here?
        break;

      case SyncState.error: // TODO implement logging
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
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const Expanded(
                  flex: 2,
                  child: SizedBox.shrink(),
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
                  child: _NotificationsPanel(appState: appState),
                ),
                const Expanded(
                  flex: 1,
                  child: SizedBox.shrink(),
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
  const _NotificationsPanel({required this.appState});

  final AppModel appState;

  bool get _hasContent =>
      appState.syncProgress != null ||
      (appState.notification != null && appState.notification!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = appState.syncProgress;

    if (!_hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Center(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progress != null) ...[
                  Text(
                    progress.phase == SyncPhase.archiving
                        ? 'Archiving...'
                        : _progressText(progress),
                    style: tt.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  progress.phase == SyncPhase.archiving
                      ? const LinearProgressIndicator()
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: progress.fraction),
                          duration: const Duration(milliseconds: 100),
                          builder: (_, value, __) =>
                              LinearProgressIndicator(value: value),
                        ),
                ] else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    child: Column(
                      key: ValueKey(appState.notification),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (appState.syncState == SyncState.success)
                          Text(
                            'Swipe left to view archive',
                            style: tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          appState.notification!,
                          style: tt.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _progressText(SyncProgress progress) {
  final verb = switch (progress.phase) {
    SyncPhase.downloading => 'Fetching from NDS...',
    SyncPhase.archiving   => 'Archiving...',
  };
  return '$verb\n${progress.currentFile}';
}
