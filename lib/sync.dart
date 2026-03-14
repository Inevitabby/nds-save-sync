import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:nds_save_sync/saf.dart';
import 'package:path/path.dart' as p;

class SyncResult {
  const SyncResult({
    required this.changed,
    required this.unchanged,
    required this.failures,
  });

  final List<String> changed;   // New or changed
  final List<String> unchanged; // Skipped
  final List<String> failures;  // Failed to save

  bool get hasFailures => failures.isNotEmpty;
  int get totalProcessed => changed.length + unchanged.length + failures.length;
}

// For each entry in stagedFiles:
//  1. Read the latest copy from the archive tree
//  2. Compare against the staged file
//  3. If changed/new, write a timestamped copy to .archive for history and overwrite the root file
Future<SyncResult> archiveChangedFiles({
  required Map<String, File> stagedFiles,
  required String archiveUri,
  void Function(String filename, int done, int total)? onProgress,
}) async {
  final changed = <String>[];
  final unchanged = <String>[];
  final failures = <String>[];

  final total = stagedFiles.length;
  var done = 0;

  for (final MapEntry(:key, :value) in stagedFiles.entries) {
    final filename = key;
    final stagedFile = value;

    try {
      final stagedBytes = await stagedFile.readAsBytes();
      final latestBytes = await SafFolderPicker.readFile(
        archiveUri: archiveUri,
        filename: filename,
      );

      final isNew = latestBytes == null;
      final hasChanged = isNew || !_cmp(stagedBytes, latestBytes);

      if (!hasChanged) {
        unchanged.add(filename);
        done++;
        onProgress?.call(filename, done, total);
        continue;
      }

      final timestampedName = _timestampedFilename(filename);

      // Timestamped copy in .archive/ for history.
      final archiveOk = await SafFolderPicker.writeFile(
        archiveUri: archiveUri,
        filename: timestampedName,
        bytes: stagedBytes,
        subdir: _archiveSubdir,
      );

      // Overwrite root "latest" for clean external access.
      final latestOk = await SafFolderPicker.writeFile(
        archiveUri: archiveUri,
        filename: filename,
        bytes: stagedBytes,
      );

      if (archiveOk && latestOk) {
        changed.add(filename);
      } else {
        failures.add(filename);
      }
    } catch (_) {
      failures.add(filename);
    }

    done++;
    onProgress?.call(filename, done, total);
  }

  return SyncResult(
    changed: changed,
    unchanged: unchanged,
    failures: failures,
  );
}

const _archiveSubdir = '.archive';

// Put timestamp in filename (<name>.<timestamp>.sav)
String _timestampedFilename(String filename) {
  final ext  = p.extension(filename);
  final stem = p.basenameWithoutExtension(filename);
  final ts   = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
  return '$stem.$ts$ext';
}

/// Byte-by-byte equality
bool _cmp(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
