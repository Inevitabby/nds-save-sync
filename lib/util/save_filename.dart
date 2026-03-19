import 'dart:core';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

// Helpers for .sav filename conventions
class SaveFilename {
  SaveFilename._();

  static const _ext = '.sav';
  static const _tsLength = 16; // .YYYY-MM-DD_HHMM
  static final _tsPattern = RegExp(r'^\.\d{4}-\d{2}-\d{2}_\d{4}$');

  static final _tag = RegExp(r'\(([^)]*)\)');
  static const _regions = { 'australia', 'canada', 'cn region lock', 'europe', 'france', 'germany', 'italy', 'japan', 'korea', 'netherlands', 'spain', 'taiwan', 'tw', 'usa', 'united kingdom', 'world', };
  static const _languages = { 'ar', 'ca', 'da', 'de', 'en', 'es', 'fi', 'fr', 'fr-ca', 'it', 'ja', 'ko', 'nl', 'no', 'pt', 'ru', 'sv', 'tr', 'zh', 'zh-hans', 'zh-hant', };
  static const _keywords = { 'e', 'jp', 'legacy', 'patched', 'squirrels', 'tengen', 'u', 'xenophobia', };

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

  // game.2026-01-01_1200.sav -> DateTime
  static DateTime? getTimestamp(String filename) {
    final stem = p.basenameWithoutExtension(filename);
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
  static String displayName(String orig) => p.basenameWithoutExtension(orig)
      .replaceAllMapped(_tag, (m) => _isNoise(m.group(1)!) ? '' : m.group(0)!)
      .trim();

  static bool _isNoise(String inner) {
    final parts = inner.split(',').map((s) => s.trim().toLowerCase()).toList();
    if (_regions.containsAll(parts)) return true;
    if (_languages.containsAll(parts)) return true;
    if (_keywords.contains(inner.trim().toLowerCase())) return true;
    if (inner.startsWith('Rev ') && int.tryParse(inner.substring(4)) != null)
      return true;
    return false;
  }
}
