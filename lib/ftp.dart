import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;

class FtpClient {
  FTPConnect? _client;

  bool get isConnected => _client != null;
  
  Future<bool> connect(String ip, int port) async {
    final client = FTPConnect(ip, port: port);
    try {
      await client.connect();
      _client = client;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  Future<String> currentDir() async {
    if (_client == null) return '';
    try {
      return await _client!.currentDirectory();
    } catch (e) {
      return '';
    }
  }

  Future<bool> changeDir(String path) async {
    if (_client == null) return false;
    try {
      return await _client!.changeDirectory(path);
    } catch (e) {
      return false;
    }
  }

  Future<List<FTPEntry>> list() async {
    if (_client == null) return [];
    try {
      var entries = await _client!.listDirectoryContent();

      // 1. Filter for directories and files
      entries = entries.where((entry) {
        return entry.type == FTPEntryType.dir || entry.type == FTPEntryType.file;
      }).toList();

      // 2. Remove absolute path entry
      // TODO Is FTP server returning the absolute path to the CWD because that's just how LIST or MSLD works?
      if (entries.isNotEmpty && entries.first.name == await currentDir()) {
        entries = entries.sublist(1);
      }

      // 3. Sort directories above files
      entries.sort((a, b) {
        if (a.type != b.type) return a.type == FTPEntryType.dir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      // 4.
      // TODO Consider sorting saves over other files?

      return entries;
    } catch (e) {
      return [];
    }
  }

  static const int _maxRetries = 5;

  // Download files to a local staging folder.
  Future<DownloadResult> downloadSaves({
    required String remoteDir,
    required Directory stagingDir,
    void Function(String filename, int done, int total)? onProgress,
  }) async {
    if (_client == null) {
      return const DownloadResult(files: {}, failures: []);
    }
 
    // 1. Navigate to the remote dir and list .sav files.
    await _client!.changeDirectory(remoteDir);
    final entries = await list();
    final saves = entries
        .where((e) =>
            e.type == FTPEntryType.file &&
            p.extension(e.name.toLowerCase()) == '.sav')
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
