import 'dart:async';
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
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.93).animate(
    CurvedAnimation(
      parent: _press,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ),
  );

  bool get _busy =>
      widget.state == SyncState.connecting ||
      widget.state == SyncState.syncing;

  @override
  void initState() {
    super.initState();
    if (_busy) unawaited(_spin.repeat());
  }

  @override
  void didUpdateWidget(SyncButton old) {
    super.didUpdateWidget(old);
    if (_busy && !_spin.isAnimating) {
      unawaited(_spin.repeat());
    } else if (!_busy && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _press.dispose();
    super.dispose();
  }

  Future<void> _onTapDown(_) async {
    if (_busy) return;
    unawaited(_press.forward());
  }

  Future<void> _onTapUp(_) async {
    if (_busy) return;
    await _press.reverse();
    widget.onPressed();
  }

  Future<void> _onTapCancel() async {
    if (_busy) return;
    await _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs, widget.state);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 192,
          height: 192,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 2,
                spreadRadius: 2,
              ),
            ],
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
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _color(ColorScheme cs, SyncState state) => switch (state) {
  SyncState.idle       => Colors.blue[300]!,
  SyncState.connecting => cs.primary,
  SyncState.connected  => Colors.blue[300]!,
  SyncState.syncing    => cs.primary,
  SyncState.success    => const Color(0xFFA6E3A1),
  SyncState.error      => cs.error,
};

IconData _icon(SyncState state) => switch (state) {
  SyncState.idle       => Icons.sync,
  SyncState.connecting => Icons.sync,
  SyncState.connected  => Icons.sync,
  SyncState.syncing    => Icons.sync,
  SyncState.success    => Icons.emoji_emotions,
  SyncState.error      => Icons.sync_problem,
};

String _label(SyncState state) => switch (state) {
  SyncState.idle       => 'CONNECT',
  SyncState.connecting => 'CONNECTING',
  SyncState.connected  => 'TAP TO SYNC',
  SyncState.syncing    => 'SYNCING',
  SyncState.success    => 'SUCCESS!',
  SyncState.error      => 'TAP TO RETRY',
};
