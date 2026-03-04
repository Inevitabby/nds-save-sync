import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:nds_save_sync/providers/dashboard_controller.dart';
import 'package:path/path.dart' as p;
import 'modal.dart';

class Browser extends ConsumerStatefulWidget {
  const Browser({super.key});

  @override
  ConsumerState<Browser> createState() => _BrowserState();
}

class _BrowserState extends ConsumerState<Browser> {
  List<FTPEntry> _files = [];
  bool _loading = true;
  String _currentPath = '/';

  @override
  void initState() {
    super.initState();
    _loadDir();
  }

  Future<void> _loadDir() async {
    setState(() => _loading = true);
    final entries = await ref.read(dashboardProvider.notifier).list();
    if (mounted) {
      setState(() {
        _files = entries;
        _loading = false;
      });
    }
  }

  Future<void> _navigate(String dir) async {
    final success = await ref.read(dashboardProvider.notifier).changeDir(dir);
    if (success) {
        final dir = await ref.read(dashboardProvider.notifier).currentDir();
setState(() => _currentPath = dir);
        await _loadDir();
    }
  }

  // TODO Display count of detected save files in current folder.
  // TODO Is some cleanup w.r.t. FTPConnect needed when this widget is destroyed?
  // TODO Early on, when I only did .connect() and .list() I managed to freeze the FTP server, no idea why.
  // TODO Add a ".." entry, and also hook up the phone's back button to it
  @override
  Widget build(BuildContext context) {
    return Modal(
      title: "Select Save Directory",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _files.length,
                    itemBuilder: (context, index) => _entry(_files[index]),
                  ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _currentPath,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _currentPath),
                child: const Text("Select Here"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entry(FTPEntry file) {
    IconData getIcon(FTPEntry file) {
      if (file.type == FTPEntryType.dir) return Icons.folder;
      switch (p.extension(file.name.toLowerCase())) {
        case ".sav": // Saves
          return Icons.videogame_asset;
        default: 
          return Icons.insert_drive_file;
      }
    } 

    return ListTile(
      leading: Icon(getIcon(file)),
      title: Text(file.name),
      onTap: file.type == FTPEntryType.dir ? () => _navigate(file.name) : null,
    );
  }
}
