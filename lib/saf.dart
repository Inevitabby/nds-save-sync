import 'package:flutter/services.dart';

class SafFolderPicker {
  static const _channel = MethodChannel('com.inevitabby.nds_save_sync/saf');

  static Future<String?> pickFolder() async {
    try {
      final result = await _channel.invokeMethod<String>('pickFolder');
      return result;
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
      return null;
    }
  }
}
