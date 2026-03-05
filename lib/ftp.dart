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
    if (_client == null) return "";
    try {
      return await _client!.currentDirectory();
    } catch (e) {
      return "";
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
      List<FTPEntry> entries = await _client!.listDirectoryContent();

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

  // TODO Download files to a local staging folder.
  //      It's very finicky, best bet is to copy behavior of https://github.com/Inevitabby/DS-OTA-Backup
  //      Due to NDS FTP server limitations, we must download every SAV file to a temporary
  //      staging directory, then compare against last-downloaded versions to find changes.
  Future<void> downloadSaves(String remoteDir, String stagingDir) async {
    if (_client == null) return;
    // TODO Implement
  }
}
