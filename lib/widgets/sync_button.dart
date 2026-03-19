import 'package:flutter/material.dart';
import 'package:nds_save_sync/providers.dart';

class SyncButton extends StatefulWidget {
  const SyncButton({required this.state, required this.onPressed, super.key});

  final SyncState state;
  final VoidCallback onPressed;

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _pressed = false;

  bool get _busy => widget.state == SyncState.connecting || widget.state == SyncState.syncing;

  @override
  void initState() {
    super.initState();
    if (_busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(SyncButton old) {
    super.didUpdateWidget(old);
    if (_busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!_busy && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs, widget.state);

    return GestureDetector(
      onTapDown: _busy ? null : (_) => setState(() => _pressed = true),
      onTapCancel: _busy ? null : () => setState(() => _pressed = false),
      onTapUp: _busy
          ? null
          : (_) async {
              setState(() => _pressed = false);
              await Future<void>.delayed(const Duration(milliseconds: 120));
              widget.onPressed();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 192,
          height: 192,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _spin,
                child: Icon(_icon(widget.state), size: 48, color: cs.onPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                _label(widget.state),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onPrimary,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _color(ColorScheme cs, SyncState state) {
  final isDark = cs.brightness == Brightness.dark;
  return switch (state) {
    SyncState.idle => isDark ? Colors.blue[300]! : Colors.blue[700]!,
    SyncState.connecting => cs.primary,
    SyncState.connected => isDark ? Colors.blue[300]! : Colors.blue[700]!,
    SyncState.syncing => cs.primary,
    SyncState.success => isDark ? Colors.green[300]! : Colors.green[700]!,
    SyncState.error => cs.error,
  };
}

IconData _icon(SyncState state) => switch (state) {
  SyncState.idle => Icons.power_settings_new,
  SyncState.connecting => Icons.sync,
  SyncState.connected => Icons.sync,
  SyncState.syncing => Icons.sync,
  SyncState.success => Icons.check_circle_outline,
  SyncState.error => Icons.sync_problem,
};

String _label(SyncState state) => switch (state) {
  SyncState.idle => 'CONNECT',
  SyncState.connecting => 'CONNECTING',
  SyncState.connected => 'TAP TO SYNC',
  SyncState.syncing => 'SYNCING',
  SyncState.success => 'SUCCESS',
  SyncState.error => 'TAP TO RETRY',
};
