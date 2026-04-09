import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/modals/browser.dart';
import 'package:nds_save_sync/modals/ip_entry.dart';
import 'package:nds_save_sync/modals/onboarding.dart';
import 'package:nds_save_sync/persistence.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/sync.dart';
import 'package:nds_save_sync/widgets/sync_button.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final persisted = await Persistence.load();
    if ((!persisted.onboardingDone && mounted) || kDebugMode) {
      await showDialog<void>(
        context: context,
        builder: (_) => const Onboarding(),
      );
    }
  }

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
        if (!mounted) return;
        final selectedPath = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const Browser(),
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
          unawaited(controller.reset());
        }
        unawaited(controller.reset()); // TODO implement something else here?
        break;

      case SyncState.error: // TODO implement logging
        unawaited(controller.reset());
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
    if (result != null) { // TODO this check is broken (if no ip still passes)
      unawaited(controller.connect(result['ip'] as String, result['port'] as int));
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
    await WakelockPlus.enable();
    try {
      await controller.sync();
    } finally {
      await WakelockPlus.disable();
    }
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
            child: Column(children: [
              const Spacer(flex: 3),
              SyncButton(
                state: appState.syncState,
                onPressed: () => _onPressed(appState),
              ),
              const Flexible(
                child: SizedBox(height: 48),
              ),
              _NotificationsPanel(appState: appState),
              const Spacer(flex: 2),
            ]),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Center(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: _hasContent ? 1.0 : 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                    if (progress.phase == SyncPhase.archiving)
                      const LinearProgressIndicator()
                    else
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: progress.fraction),
                        duration: const Duration(milliseconds: 100),
                        builder: (_, value, _) =>
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
