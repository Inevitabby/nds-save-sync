import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nds_save_sync/constants.dart';
import 'package:nds_save_sync/saf.dart';
import 'package:nds_save_sync/util/save_filename.dart';
 
/*
 * State
 */

class SyncResult {
  const SyncResult({
    required this.changed,
    required this.unchanged,
    required this.failures,
  });

  final List<String> changed;   // New or changed saves that were archived
  final List<String> unchanged; // Skipped (identical to latest copy)
  final List<String> failures;  // Couldn't be read or written

  bool get hasFailures => failures.isNotEmpty;
  int get totalProcessed => changed.length + unchanged.length + failures.length;
}

class SyncProgress {
  const SyncProgress({
    required this.currentFile,
    required this.done,
    required this.total,
    this.phase = SyncPhase.downloading,
  });
 
  final String currentFile;
  final int done;
  final int total;
  final SyncPhase phase;

  int get fileIndex => done;

  double get fraction => total == 0 ? 0.0 : done / total;
}

enum SyncPhase { downloading, archiving }

/*
 * Logic
 */

// For each staged file:
//  1. Read the latest copy from the archive root
//  2. Skip if identical; otherwise, write a timestamped copy to .archive/
Future<SyncResult> syncToArchive({
  required Map<String, File> stagedFiles,
  required String archiveUri,
  void Function(String filename, int done, int total)? onProgress,
}) async {
  final changed   = <String>[];
  final unchanged = <String>[];
  final failures  = <String>[];
 
  final total = stagedFiles.length;
  var done = 0;
 
  for (final MapEntry(:key, :value) in stagedFiles.entries) {
    final filename   = key;
    final stagedFile = value;
 
    try {
      final stagedBytes = await stagedFile.readAsBytes();
      final latestBytes = await SafFolderPicker.readFile(
        archiveUri: archiveUri,
        filename: filename,
      );
 
      if (latestBytes != null && _cmp(stagedBytes, latestBytes)) {
        debugPrint('[syncToArchive] "$filename" unchanged, skipping');
        unchanged.add(filename);
        done++;
        onProgress?.call(filename, done, total);
        continue;
      }
 
      final archiveOk = await SafFolderPicker.writeFile(
        archiveUri: archiveUri,
        filename: SaveFilename.stamp(filename),
        bytes: stagedBytes,
        subdir: archiveSubdir,
      );
 
      final latestOk = await SafFolderPicker.writeFile(
        archiveUri: archiveUri,
        filename: filename,
        bytes: stagedBytes,
      );
 
      if (archiveOk && latestOk) {
        debugPrint('[syncToArchive] "$filename" archived successfully');
        changed.add(filename);
      } else {
        debugPrint('[syncToArchive] "$filename" write failed (archiveOk=$archiveOk, latestOk=$latestOk)');
        failures.add(filename);
      }
    } catch (e) {
      debugPrint('[syncToArchive] "$filename" threw an error: $e');
      failures.add(filename);
    }
 
    done++;
    onProgress?.call(filename, done, total);
  }
 
  debugPrint('[syncToArchive] Done: ${changed.length} changed, ${unchanged.length} unchanged, ${failures.length} failures');
  return SyncResult(
    changed: changed,
    unchanged: unchanged,
    failures: failures,
  );
}
 
bool _cmp(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
