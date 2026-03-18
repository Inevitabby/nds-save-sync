import 'dart:core';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

// Helpers for .sav filename conventions
class SaveFilename {
  SaveFilename._();

  static const _ext = '.sav';
  static const _tsLength = 16; // .YYYY-MM-DD_HHMM
  static final _tsPattern = RegExp(r'^\.\d{4}-\d{2}-\d{2}_\d{4}$');

  // game.sav -> true
  static bool isSave(String name) =>
      p.extension(name.toLowerCase()) == _ext;

  // game.sav -> game.2026-01-01_1200.sav
  static String stamp(String filename) {
    final ts = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    return '${p.basenameWithoutExtension(filename)}.$ts${p.extension(filename)}';
  }

  // game.2026-01-01_1200.sav -> game.sav
  static String original(String filename) {
    final stem = p.basenameWithoutExtension(filename);
    if (stem.length > _tsLength) {
      final suffix = stem.substring(stem.length - _tsLength);
      if (_tsPattern.hasMatch(suffix)) {
        return '${stem.substring(0, stem.length - _tsLength)}${p.extension(filename)}';
      }
    }
    return filename;
  }

  // game.2026-01-01_1200.sav -> 2026-01-01 12:00
  // TODO human-readable relative?
  static String formatTimestamp(String filename) {
    final stem = p.basenameWithoutExtension(filename);
    if (stem.length >= _tsLength) {
      final raw = stem.substring(stem.length - _tsLength + 1); // strip leading dot
      if (raw.length == 15 && raw[10] == '_') {
        return '${raw.substring(0, 10)} ${raw.substring(11, 13)}:${raw.substring(13)}';
      }
    }
    return filename;
  }

  // game.2026-01-01_1200.sav -> DateTime
  DateTime? getTime(String filename) {
    final stem = filename;
    if (stem.length >= _tsLength) {
      final raw = stem.substring(stem.length - _tsLength + 1); // strip leading dot
      if (raw.length == 15) {
        try {
          return DateTime.parse(
            '${raw.substring(0, 10)}T${raw.substring(11, 15)}00',
          );
        } catch (_) {}
      }
    }
    return null;
  }

  // game.sav -> human-readable display name
  // TODO implement
  static String displayName(String filename) => filename;
}
