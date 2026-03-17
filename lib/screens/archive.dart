import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/constants.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/saf.dart';
import 'package:nds_save_sync/util/save_filename.dart';

class SaveGroup {
  const SaveGroup({
    required this.gameName,
    required this.displayName,
    required this.entries,
  });
  final String gameName;      // e.g. game.sav
  final String displayName;
  final List<String> entries; // timestamped filenames sorted newest first
}

// Loads and groups archived saves from .archive
final FutureProvider<List<SaveGroup>> archiveProvider = FutureProvider.autoDispose<List<SaveGroup>>((ref) async {
  final archiveUri = ref.watch(appProvider).value?.archiveUri;
  if (archiveUri == null) return [];
 
  final files = await SafFolderPicker.listFiles(
    archiveUri: archiveUri,
    subdir: archiveSubdir,
  );
 
  final Map<String, List<String>> grouped = {};
  for (final filename in files) {
    grouped
        .putIfAbsent(SaveFilename.original(filename), () => [])
        .add(filename);
  }
 
  return grouped.entries.map((e) {
    final sorted = List<String>.from(e.value)..sort((a, b) => b.compareTo(a));
    return SaveGroup(
      gameName: e.key,
      displayName: SaveFilename.displayName(e.key),
      entries: sorted,
    );
  }).toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
});

class Archive extends ConsumerWidget {
  const Archive({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveProvider);
    final archiveUri   = ref.watch(appProvider).value?.archiveUri;
 
    return Scaffold(
      body: switch (archiveAsync) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => Center(child: Text('Failed to load: $error')),
        AsyncData(:final value)  => _body(context, archiveUri, value),
      },
    );
  }
 
  Widget _body(BuildContext context, String? archiveUri, List<SaveGroup> groups) {
    if (archiveUri == null) {
      return const Center(child: Text('No archive folder selected yet.\nRun a sync first.', textAlign: TextAlign.center));
    }
    if (groups.isEmpty) {
      return const Center(child: Text('No backups yet.\nRun a sync to start archiving.', textAlign: TextAlign.center));
    }
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) => _GameTile(group: groups[i]),
    );
  }
}
 
class _GameTile extends StatelessWidget {
  const _GameTile({required this.group});
 
  final SaveGroup group;
 
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(group.displayName),
      subtitle: Text(
        '${group.entries.length} backup${group.entries.length == 1 ? '' : 's'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: group.entries
          .map((filename) => _EntryTile(filename: filename))
          .toList(),
    );
  }
}
 
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.filename});
 
  final String filename;
 
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: const Icon(Icons.history),
      title: Text(SaveFilename.formatTimestamp(filename)),
    );
  }
}

