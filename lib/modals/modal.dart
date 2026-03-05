import 'package:flutter/material.dart';

class Modal extends StatelessWidget {
  const Modal({
    required this.title,
    required this.child,
    super.key,
    this.resizeForKeyboard = false,
  });

  final String title;
  final Widget child;
  final bool resizeForKeyboard;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = resizeForKeyboard
        ? MediaQuery.of(context).viewInsets.bottom
        : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + keyboardInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
