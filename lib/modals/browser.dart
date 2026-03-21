import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:nds_save_sync/modals/modal.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/util/save_filename.dart';

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

  int get _saveCount => _files.where((f) => SaveFilename.isSave(f.name)).length;

  Future<void> _loadDir() async {
    setState(() => _loading = true);
    try {
      final entries = await ref.read(appProvider).requireValue.ftp.list();
      if (mounted) {
        setState(() {
          _files = entries;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Browser._loadDir] Error loading directory "$_currentPath": $e');
      if (mounted) Navigator.pop(context, 'error');
    }
  }

  bool _navigating = false;

  Future<void> _navigate(String dir) async {
    if (_navigating) return;
    _navigating = true;
    try {
      final success = await ref.read(appProvider).requireValue.ftp.changeDir(dir);
      if (success) {
          final dir = await ref.read(appProvider).requireValue.ftp.currentDir();
  setState(() => _currentPath = dir);
          await _loadDir();
      }
    } finally {
      _navigating = false;
    }
  }

  // TODO Is some cleanup w.r.t. FTPConnect needed when this widget is destroyed?
  // TODO Should phone back button be hooked-up to navigating backwards when not at root?
  @override
  Widget build(BuildContext context) {
    return Modal(
      title: 'Select Backup Folder',
      subtitle: 'Navigate to the folder containing your .sav files.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _files.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          if (_currentPath == '/') return const SizedBox.shrink();
                          return ListTile(
                            leading: const Icon(Icons.arrow_back),
                            title: const Text('..'),
                            onTap: () => _navigate('..'),
                          );
                        }
                        return _entry(_files[index - 1]);
                      },
                    ),
                  ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsetsGeometry.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currentPath),
                      Text(
                        '$_saveCount saves are here',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _currentPath),
                  child: const Text('Use This Folder'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(FTPEntry file) {
    final isSave = SaveFilename.isSave(file.name);
    final dim    = !isSave && _saveCount > 0;
 
    IconData icon() {
      if (file.type == FTPEntryType.dir) return Icons.folder;
      return isSave ? Icons.save : Icons.insert_drive_file;
    }
 
    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: ListTile(
        leading: Icon(icon()),
        title: Text(file.name),
        onTap: file.type == FTPEntryType.dir
            ? () => _navigate(file.name)
            : null,
      ),
    );
  }
}
