import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:nds_save_sync/util/save_filename.dart';
import 'package:path/path.dart' as p;

class FtpClient {
  FTPConnect? _client;
  String? _lastIp;
  int? _lastPort;

  bool get isConnected => _client != null;

  Future<bool> connect(String ip, int port) async {
    final client = FTPConnect(ip, port: port, timeout: 10);
    try {
      await client.connect();
      _client = client;
      _lastIp = ip;
      _lastPort = port;
      return true;
    } catch (e) {
      debugPrint('[FtpClient.connect] Error connecting to $ip:$port: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _client?.disconnect();
    } catch (e) {
      debugPrint('[FtpClient.disconnect] Error during disconnect: $e');
    } // best-effort
    _client = null;
  }

  // Reconnects once if the socket has been dropped. Throws if it fails.
  Future<void> _ensureConnected() async {
    if (_client != null) return;
    if (_lastIp == null || _lastPort == null) throw StateError('Not connected.');
    await Future<void>.delayed(const Duration(seconds: 3));
    final ok = await connect(_lastIp!, _lastPort!);
    if (!ok) throw StateError('Reconnect failed.');
  }

  Future<String> currentDir() async {
    await _ensureConnected();
    try {
      return await _client!.currentDirectory();
    } catch (e) {
      debugPrint('[FtpClient.currentDir] Error getting current directory: $e');
      _client = null;
      return '';
    }
  }

  Future<bool> changeDir(String path) async {
    await _ensureConnected();
    try {
      return await _client!.changeDirectory(path);
    } catch (e) {
      debugPrint('[FtpClient.changeDir] Error changing directory to "$path": $e');
      _client = null;
      return false;
    }
  }

  // Lists contents of CWD (directories first, then files)
  Future<List<FTPEntry>> list() async {
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      await _ensureConnected();
      try {
        var entries = await _client!.listDirectoryContent().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _client = null;
            throw StateError('Timed out listing directory');
          },
        );

        entries = entries
            .where(
              (e) => e.type == FTPEntryType.dir || e.type == FTPEntryType.file,
            )
            .toList();

        // TODO: Is the server returning the CWD path as an entry because of LIST/MLSD behaviour?
        if (entries.isNotEmpty && entries.first.name == await currentDir()) {
          entries = entries.sublist(1);
        }

        entries.sort((a, b) {
          if (a.type != b.type) return a.type == FTPEntryType.dir ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        return entries;
      } catch (e) {
        debugPrint('[FtpClient.list] Attempt $attempt/$_maxRetries failed: $e');
        _client = null;
        if (attempt == _maxRetries) rethrow;
        await Future<void>.delayed(_retryDelay);
      }
    }
    throw StateError('unreachable');
  }

  static const _maxRetries = 7;
  static const _retryDelay = Duration(seconds: 7);
  static const _interFileDelay = Duration(seconds: 1);
  static const _stallThreshold = 7;

  Future<void> _downloadWithStallDetection(String name, File dest) async {
    final completer = Completer<void>();
    var lastProgress = DateTime.now();

    final watchdog = Timer.periodic(const Duration(seconds: 1), (t) {
      if (DateTime.now().difference(lastProgress).inSeconds >= _stallThreshold) {
        t.cancel();
        _client = null;
        if (!completer.isCompleted) {
          completer.completeError(StateError('Stalled on $name'));
        }
      }
    });

    _client!.downloadFile(name, dest, onProgress: (received, total, _) {
      lastProgress = DateTime.now();
    }).then((_) {
      watchdog.cancel();
      if (!completer.isCompleted) completer.complete();
    }).catchError((Object e) {
      debugPrint('[FtpClient._downloadWithStallDetection] Error downloading "$name": $e');
      watchdog.cancel();
      _client = null;
      if (!completer.isCompleted) completer.completeError(e);
    });

    return completer.future;
  }

  Future<DownloadResult> downloadSaves({
    required String remoteDir,
    required Directory stagingDir,
    void Function(String filename, int done, int total)? onProgress,
  }) async {
    await _ensureConnected();

    await _client!.changeDirectory(remoteDir);
    final saves = (await list())
        .where((e) => e.type == FTPEntryType.file && SaveFilename.isSave(e.name))
        .toList();

    if (saves.isEmpty) return const DownloadResult(files: {}, failures: []);

    final downloaded = <String, File>{};
    final failures = <String>[];
    var done = 0;

    for (final entry in saves) {
      final localFile = File(p.join(stagingDir.path, entry.name));
      onProgress?.call(entry.name, done, saves.length);
      var success = false;

      for (var attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          await _ensureConnected();
          await _client!.changeDirectory(remoteDir);
          await _downloadWithStallDetection(entry.name, localFile);
          success = true;
          break;
        } catch (e) {
          debugPrint('[FtpClient.downloadSaves] Attempt $attempt/$_maxRetries failed for "${entry.name}": $e');
          if (await localFile.exists()) await localFile.delete();
          if (attempt == _maxRetries) break;
          await Future<void>.delayed(_retryDelay);
        }
      }

      done++;
      if (success) {
        downloaded[entry.name] = localFile;
        if (done < saves.length) {
          await Future<void>.delayed(_interFileDelay);
        }
      } else {
        failures.add(entry.name);
      }
    }

    return DownloadResult(files: downloaded, failures: failures);
  }
}

class DownloadResult {
  const DownloadResult({
    required this.files,
    required this.failures,
  });

  final Map<String, File> files;
  final List<String> failures;
}
