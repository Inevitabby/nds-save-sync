import 'package:flutter/material.dart';
import 'package:nds_save_sync/persistence.dart';

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  Future<void> _dismiss(BuildContext context) async {
    await Persistence.setOnboardingDone();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme   = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Before you connect',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Wirelessly back up saves from your NDS to your phone over Wi-Fi.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            const _CheckRow(text: 'Your console is on the same network as your phone'),
            const _CheckRow(text: 'FTP server is running on your console'),
            const _CheckRow(text: 'Your console is showing an IP address'),
            const SizedBox(height: 12),
            Text('Network setup', style: textTheme.labelMedium),
            const SizedBox(height: 6),
            _NetworkRow(
              label: 'Gen 4:',
              detail: 'Android Settings → Mobile Hotspot. Set Security to None, Band to 2.4 GHz.',
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 4),
            _NetworkRow(
              label: 'Gen 5:',
              detail: 'Connect both devices to the same Wi-Fi network.',
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _dismiss(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.label,
    required this.detail,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String detail;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final style = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(label, style: style)),
        Expanded(child: Text(detail, style: style)),
      ],
    );
  }
}
