import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ftpconnect/ftpconnect.dart';
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
    unawaited(_loadDir());
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
    debugPrint('[Browser._navigate] Navigating to "$dir"');
    try {
      final success = await ref.read(appProvider).requireValue.ftp.changeDir(dir);
      if (success) {
        final path = await ref.read(appProvider).requireValue.ftp.currentDir();
        debugPrint('[Browser._navigate] Now at "$path"');
        setState(() => _currentPath = path);
        await _loadDir();
      } else {
        debugPrint('[Browser._navigate] changeDir("$dir") returned false');
      }
    } finally {
      _navigating = false;
    }
  }

  // TODO Is some cleanup w.r.t. FTPConnect needed when this widget is destroyed?
  // TODO Should phone back button be hooked-up to navigating backwards when not at root?
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Backup Folder',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Navigate to the folder containing your .sav files.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
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
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currentPath, style: tt.bodySmall),
                    Text(
                      '$_saveCount saves are here',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
