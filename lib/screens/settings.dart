import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nds_save_sync/modals/onboarding.dart';
import 'package:nds_save_sync/providers.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appProvider).value;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text('Settings', style: tt.headlineSmall),
            const SizedBox(height: 24),
            _Section(
              label: 'Device',
              children: [
                _IpPortTile(
                  initialIp: appState?.lastIp,
                  initialPort: appState?.lastPort,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              label: 'Storage',
              children: [
                _ResetTile(
                  title: 'Remote save folder',
                  subtitle:
                      appState?.saveDir ?? 'Connect via dashboard to configure',
                  onTap: () => _snack(
                    context,
                    'Remote folder must be configured from the Dashboard while connected.',
                  ),
                  onReset: appState?.saveDir == null
                      ? null
                      : () {
                          ref.read(appProvider.notifier).resetSaveDir();
                          _snack(context, 'Remote folder cleared');
                        },
                ),
                const Divider(height: 1, indent: 16),
                _ResetTile(
                  title: 'Local backup folder',
                  subtitle: appState?.archiveUri ?? 'Tap to select folder',
                  textDirection: appState?.archiveUri != null
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  onTap: () => ref.read(appProvider.notifier).pickArchiveUri(),
                  onReset: appState?.archiveUri == null
                      ? null
                      : () {
                          ref.read(appProvider.notifier).resetArchiveUri();
                          _snack(context, 'Backup folder cleared');
                        },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              label: 'Help',
              children: [
                ListTile(
                  title: const Text('Show setup guide'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const Onboarding(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 48, left: 16, right: 16),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _IpPortTile extends HookConsumerWidget {
  const _IpPortTile({this.initialIp, this.initialPort});

  final String? initialIp;
  final int? initialPort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipCtrl = useTextEditingController(text: initialIp ?? '');
    final portCtrl = useTextEditingController(
      text: initialPort?.toString() ?? '5000',
    );
    final dirty = useState(false);

    void checkDirty() {
      final ipChanged = ipCtrl.text != (initialIp ?? '');
      final portChanged = portCtrl.text != (initialPort?.toString() ?? '5000');
      dirty.value = ipChanged || portChanged;
    }

    useEffect(() {
      ipCtrl.addListener(checkDirty);
      portCtrl.addListener(checkDirty);
      return () {
        ipCtrl.removeListener(checkDirty);
        portCtrl.removeListener(checkDirty);
      };
    }, []);

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (dirty.value) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text) ?? 5000;
                ref.read(appProvider.notifier).setDevice(ip, port);
                dirty.value = false;
                FocusScope.of(context).unfocus();
                _snack(context, 'Device updated');
              },
              child: const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  const _ResetTile({
    required this.title,
    required this.subtitle,
    this.textDirection = TextDirection.ltr,
    this.onTap,
    this.onReset,
  });

  final String title;
  final String subtitle;
  final TextDirection textDirection;
  final VoidCallback? onTap;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: textDirection,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      onTap: onTap,
      trailing: onReset == null
          ? null
          : TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('RESET'),
            ),
    );
  }
}
