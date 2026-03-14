import 'package:flutter/services.dart';

class SafFolderPicker {
  static const _channel = MethodChannel('com.inevitabby.nds_save_sync/saf');

  // Open dialog to let user pick a persistent folder (returns URI)
  static Future<String?> pickFolder() async {
    try {
      final result = await _channel.invokeMethod<String>('pickFolder');
      return result;
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
      return null;
    }
  }

  // Writes bytes to filename inside the SAF tree at archiveUri
  static Future<bool> writeFile({
    required String archiveUri,
    required String filename,
    required Uint8List bytes,
    String? subdir,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('writeFile', {
        'archiveUri': archiveUri,
        'filename': filename,
        'bytes': bytes,
        'subdir': ?subdir,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
      return false;
    }
  }

  // Read raw bytes from the file
  static Future<Uint8List?> readFile({
    required String archiveUri,
    required String filename,
    String? subdir,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('readFile', {
        'archiveUri': archiveUri,
        'filename': filename,
        'subdir': ?subdir,
      });
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'FILE_NOT_FOUND') return null;
      print('${e.code}: ${e.message}');
      return null;
    }
  }
}
