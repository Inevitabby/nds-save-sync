import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

      debugPrint('[archiveProvider] Found ${files.length} archived files');

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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      itemCount: groups.length,
      itemBuilder: (context, i) => _GameTile(group: groups[i]),
    );
  }
}

class _GameTile extends StatefulWidget {
  const _GameTile({required this.group});

  final SaveGroup group;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chevronController;
  late final Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _chevronTurns =
        Tween<double>(
          begin: 0,
          end: 0.5,
        ).animate(
          CurvedAnimation(
            parent: _chevronController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = widget.group.entries.length;
    final borderRadius = BorderRadius.circular(12);
    const tileBorder = RoundedRectangleBorder();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: cs.surfaceContainerLow,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        backgroundColor: cs.surfaceContainerHigh,
        shape: tileBorder,
        collapsedShape: tileBorder,
        onExpansionChanged: (expanded) {
          if (expanded) {
            unawaited(_chevronController.forward());
          } else {
            unawaited(_chevronController.reverse());
          }
        },
        title: Text(
          widget.group.displayName,
          style: tt.titleMedium?.copyWith(
            letterSpacing: -0.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          widget.group.entries.isNotEmpty &&
                  SaveFilename.getTimestamp(widget.group.entries.first) != null
              ? 'Last backup ${timeago.format(SaveFilename.getTimestamp(widget.group.entries.first)!)}'
              : widget.group.gameName,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count backup${count == 1 ? '' : 's'}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            RotationTransition(
              turns: _chevronTurns,
              child: Icon(color: cs.onSurfaceVariant, Icons.expand_more),
            ),
          ],
        ),
        children: [
          _TimelineList(entries: widget.group.entries),
        ],
      ),
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

    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: isFirst
                            ? const SizedBox.shrink()
                            : Container(width: 2, color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Center(
                        child: isLast
                            ? const SizedBox.shrink()
                            : Container(width: 2, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final archiveUri = ref
                          .read(appProvider)
                          .value
                          ?.archiveUri;
                      if (archiveUri == null) {
                        debugPrint('[_TimelineEntry.onTap] No archive URI set, cannot share "$filename"');
                        return;
                      }
                      final bytes = await SafFolderPicker.readFile(
                        archiveUri: archiveUri,
                        filename: filename,
                        subdir: archiveSubdir,
                      );
                      if (bytes == null) {
                        debugPrint('[_TimelineEntry.onTap] Failed to read "$filename" from archive');
                        return;
                      }
                      debugPrint('[_TimelineEntry.onTap] Sharing "$filename" (${bytes.length} bytes)');
                      final tmp = await getTemporaryDirectory();
                      final file = XFile('${tmp.path}/$filename');
                      await File(file.path).writeAsBytes(bytes);
                      await SharePlus.instance.share(
                        ShareParams(files: [file]),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timestamp != null
                                      ? timeago.format(timestamp)
                                      : '???',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  // duct-taped character wrapping
                                  filename.characters.join('\u200B'), 
                                  style: GoogleFonts.jetBrainsMono(
                                    textStyle: tt.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // bait and switch (tempt the user to click)
                          Icon(
                            Icons.adaptive.share,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.9),
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
      ],
    );
  }
}
