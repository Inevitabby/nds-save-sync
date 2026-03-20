import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:nds_save_sync/util/save_filename.dart';
import 'package:path/path.dart' as p;

class FtpClient {
  FTPConnect? _client;
  String? _lastIp;
  int? _lastPort;

  bool get isConnected => _client != null;

  Future<bool> connect(String ip, int port) async {
    final client = FTPConnect(timeout: 10, ip, port: port);
    try {
      await client.connect();
      _client = client;
      _lastIp = ip;
      _lastPort = port;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _client?.disconnect();
    } catch (_) {} // best-effort
    _client = null;
  }

  // Reconnects once if the socket has been dropped. Throws if it fails.
  Future<void> _ensureConnected() async {
    if (_client != null) return;
    if (_lastIp == null || _lastPort == null)
      throw StateError('Not connected.');
    final ok = await connect(_lastIp!, _lastPort!);
    if (!ok) throw StateError('Reconnect failed.');
  }

  Future<String> currentDir() async {
    await _ensureConnected();
    try {
      return await _client!.currentDirectory();
    } catch (e) {
      return '';
    }
  }

  Future<bool> changeDir(String path) async {
    await _ensureConnected();
    try {
      return await _client!.changeDirectory(path);
    } catch (e) {
      return false;
    }
  }

  // Lists contents of CWD (directories first, then files)
  Future<List<FTPEntry>> list() async {
    await _ensureConnected();
    try {
      var entries = await _client!.listDirectoryContent();

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
      return [];
    }
  }

  static const int _maxRetries = 5;

  // Download save files from remoteDir to stagingDir
  Future<DownloadResult> downloadSaves({
    required String remoteDir,
    required Directory stagingDir,
    void Function(String filename, int done, int total)? onProgress,
  }) async {
    await _ensureConnected();

    await _client!.changeDirectory(remoteDir);
    final saves = (await list())
        .where(
          (e) => e.type == FTPEntryType.file && SaveFilename.isSave(e.name),
        )
        .toList();

    if (saves.isEmpty) {
      return const DownloadResult(files: {}, failures: []);
    }

    final downloaded = <String, File>{};
    final failures = <String>[];
    var done = 0;

    for (final entry in saves) {
      final localFile = File(p.join(stagingDir.path, entry.name));
      var success = false;

      for (var attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          await _client!.downloadFile(entry.name, localFile);
          success = true;
          break;
        } catch (e) {
          if (await localFile.exists()) await localFile.delete();
          if (attempt == _maxRetries) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      done++;
      if (success) {
        downloaded[entry.name] = localFile;
      } else {
        failures.add(entry.name);
      }
      onProgress?.call(entry.name, done, saves.length);
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
