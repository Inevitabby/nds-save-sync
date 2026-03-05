import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nds_save_sync/modals/modal.dart';

class IpEntry extends HookWidget {
  const IpEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final ipController = useTextEditingController(
      text: kDebugMode
          ? '10.0.2.2'
          : '', // TODO What if the user makes a typo? They won't see it.
    );
    final portController = useTextEditingController(text: '5000');

    return Modal(
      title: 'Connect to FTP Server',
      resizeForKeyboard: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ipController,
            decoration: const InputDecoration(
              labelText: 'IP Address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'ip': ipController.text,
              'port': int.tryParse(portController.text) ?? 5000,
            }),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
