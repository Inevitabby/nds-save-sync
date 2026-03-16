import 'package:flutter/services.dart';

class SafFolderPicker {
  static const _channel = MethodChannel('com.inevitabby.nds_save_sync/saf');

  // Open system folder picker to let user pick a folder (returns persistent tree URI)
  static Future<String?> pickFolder() async {
    try {
      return await _channel.invokeMethod<String>('pickFolder');
    } on PlatformException catch (_) {
      return null;
    }
  }

  // Writes a file to archiveUri (optionally, under subdir)
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
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Read a file inside archiveUri (optionally, under subdir)
  static Future<Uint8List?> readFile({
    required String archiveUri,
    required String filename,
    String? subdir,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('readFile', {
        'archiveUri': archiveUri,
        'filename': filename,
        'subdir': ?subdir,
      });
    } on PlatformException catch (e) {
      if (e.code == 'FILE_NOT_FOUND') return null;
      return null;
    }
  }

  // Lists filenames inside archiveUri (optionally, under subdir)
  static Future<List<String>> listFiles({
    required String archiveUri,
    String? subdir,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('listFiles', {
        'archiveUri': archiveUri,
        'subdir': ?subdir,
      });
      return result?.cast<String>() ?? [];
    } on PlatformException catch (_) {
      return [];
    }
  }
}
