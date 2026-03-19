import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nds_save_sync/constants.dart';
import 'package:nds_save_sync/providers.dart';
import 'package:nds_save_sync/saf.dart';
import 'package:nds_save_sync/util/save_filename.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

class SaveGroup {
  const SaveGroup({
    required this.gameName,
    required this.displayName,
    required this.entries,
  });
  final String gameName;
  final String displayName;
  final List<String> entries; // timestamped filenames sorted newest first
}

final FutureProvider<List<SaveGroup>> archiveProvider =
    FutureProvider.autoDispose<List<SaveGroup>>((ref) async {
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
        final sorted = List<String>.from(e.value)
          ..sort((a, b) => b.compareTo(a));
        return SaveGroup(
          gameName: e.key,
          displayName: SaveFilename.displayName(e.key),
          entries: sorted,
        );
      }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
    });

class Archive extends ConsumerWidget {
  const Archive({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveProvider);
    final archiveUri = ref.watch(appProvider).value?.archiveUri;

    return Scaffold(
      body: switch (archiveAsync) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => Center(
          child: Text('Failed to load: $error'),
        ),
        AsyncData(:final value) => _body(context, archiveUri, value),
      },
    );
  }

  Widget _body(
    BuildContext context,
    String? archiveUri,
    List<SaveGroup> groups,
  ) {
    if (archiveUri == null) {
      return const Center(
        child: Text(
          'No archive folder selected yet.\nRun a sync first.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (groups.isEmpty) {
      return const Center(
        child: Text(
          'No backups yet.\nRun a sync to start archiving.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _GameTile(group: groups[i]),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.group});

  final SaveGroup group;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = group.entries.length;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        group.displayName,
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        group.entries.isNotEmpty &&
                SaveFilename.getTimestamp(group.entries.first) != null
            ? 'Last backup ${timeago.format(SaveFilename.getTimestamp(group.entries.first)!)}'
            : group.gameName,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count backup${count == 1 ? '' : 's'}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [_TimelineList(entries: group.entries)],
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _TimelineEntry(
              filename: entries[i],
              isFirst: i == 0,
              isLast: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends ConsumerWidget {
  const _TimelineEntry({
    required this.filename,
    required this.isFirst,
    required this.isLast,
  });

  final String filename;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final timestamp = SaveFilename.getTimestamp(filename);
    final dimColor = cs.onSurfaceVariant.withValues(alpha: 0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: isFirst
                        ? const SizedBox.shrink()
                        : Container(width: 2, color: dimColor),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dimColor,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: isLast
                        ? const SizedBox.shrink()
                        : Container(width: 2, color: dimColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final archiveUri = ref.read(appProvider).value?.archiveUri;
                    if (archiveUri == null) return;
                    final bytes = await SafFolderPicker.readFile(
                      archiveUri: archiveUri,
                      filename: filename,
                      subdir: archiveSubdir,
                    );
                    if (bytes == null) return;
                    final tmp = await getTemporaryDirectory();
                    final file = XFile('${tmp.path}/$filename');
                    await File(file.path).writeAsBytes(bytes);
                    await SharePlus.instance.share(ShareParams(files: [file]));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timestamp != null ? timeago.format(timestamp) : '???',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          filename,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
