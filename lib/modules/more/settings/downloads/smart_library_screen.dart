import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/local_indexer/engine/indexer_engine.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/providers/local_indexer_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';

enum _SmartLibraryFilter { all, movies, series, unknown }
enum _SmartLibraryAction { refresh, fullRescan }

/// The global, non-destructive media index.
///
/// Local Source remains the explicit Watchtower/local reader. Smart Library
/// only indexes accessible media and keeps the original paths untouched.
class SmartLibraryScreen extends ConsumerStatefulWidget {
  const SmartLibraryScreen({super.key});

  @override
  ConsumerState<SmartLibraryScreen> createState() => _SmartLibraryScreenState();
}

class _SmartLibraryScreenState extends ConsumerState<SmartLibraryScreen> {
  _SmartLibraryFilter _filter = _SmartLibraryFilter.all;
  bool _starting = false;

  Future<List<String>> _scanRoots() async {
    final storage = StorageProvider();
    final base = await storage.getDefaultDirectory();
    final roots = <String>[
      if (base != null) base.path,
    ];

    // MediaStore is the primary Android discovery path. Request its split
    // media permission when the user explicitly starts a scan. The shared
    // filesystem walk remains opt-in and is added only when it is readable.
    if (!kIsWeb && Platform.isAndroid) {
      await storage.requestMediaPermission(requestIfNeeded: true);
    }
    if (!kIsWeb &&
        Platform.isAndroid &&
        await storage.requestPermission(requestIfNeeded: false)) {
      const sharedStorage = '/storage/emulated/0';
      if (Directory(sharedStorage).existsSync()) roots.add(sharedStorage);
    }
    return roots;
  }

  Future<void> _scan({required bool fullRescan}) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final roots = await _scanRoots();
      if (roots.isEmpty) {
        throw StateError('No accessible storage location was found.');
      }
      final scan = ref.read(localIndexerScanProvider.notifier);
      if (fullRescan) {
        await scan.fullRescan(roots);
      } else {
        await scan.refresh(roots);
      }
      await scan.startWatching(roots);
      ref.invalidate(localIndexedCountProvider);
      ref.invalidate(localIndexedCountByKindProvider);
      ref.invalidate(recentlyIndexedProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Smart Library scan failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  List<LocalIndexedItem> _filterItems(List<LocalIndexedItem> items) {
    return items.where((item) {
      switch (_filter) {
        case _SmartLibraryFilter.all:
          return true;
        case _SmartLibraryFilter.movies:
          return item.kind == LocalMediaKind.movie;
        case _SmartLibraryFilter.series:
          return item.kind == LocalMediaKind.series ||
              item.kind == LocalMediaKind.anime;
        case _SmartLibraryFilter.unknown:
          return item.kind == LocalMediaKind.unknown;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = ref.watch(localIndexedCountByKindProvider);
    final recent = ref.watch(recentlyIndexedProvider);
    final status = ref.watch(indexerStatusProvider).asData?.value;
    final isScanning = _starting || (status?.isScanning ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Library'),
        leading: const BackButton(),
        actions: [
          PopupMenuButton<_SmartLibraryAction>(
            tooltip: 'Scan options',
            icon: const Icon(Icons.tune_rounded),
            onSelected: (action) => _scan(
              fullRescan: action == _SmartLibraryAction.fullRescan,
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SmartLibraryAction.refresh,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.sync_rounded),
                  title: Text('Check for changes'),
                ),
              ),
              PopupMenuItem(
                value: _SmartLibraryAction.fullRescan,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.manage_search_rounded),
                  title: Text('Verify all storage'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _scan(fullRescan: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _LibraryHeader(
              colors: colors,
              isScanning: isScanning,
              status: status,
              onScan: () => _scan(fullRescan: false),
            ),
            const SizedBox(height: 18),
            counts.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InlineMessage(
                icon: Icons.error_outline_rounded,
                text: 'Library statistics unavailable: $error',
              ),
              data: (value) => _StatsRow(counts: value),
            ),
            const SizedBox(height: 18),
            SegmentedButton<_SmartLibraryFilter>(
              segments: const [
                ButtonSegment(
                  value: _SmartLibraryFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.apps_rounded),
                ),
                ButtonSegment(
                  value: _SmartLibraryFilter.movies,
                  label: Text('Movies'),
                  icon: Icon(Icons.movie_creation_outlined),
                ),
                ButtonSegment(
                  value: _SmartLibraryFilter.series,
                  label: Text('Series'),
                  icon: Icon(Icons.tv_rounded),
                ),
                ButtonSegment(
                  value: _SmartLibraryFilter.unknown,
                  label: Text('Unknown'),
                  icon: Icon(Icons.help_outline_rounded),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: 20),
            Text(
              'Recently indexed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            recent.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => _InlineMessage(
                icon: Icons.error_outline_rounded,
                text: 'Could not load the index: $error',
              ),
              data: (items) {
                final visible = _filterItems(items);
                if (visible.isEmpty) {
                  return _EmptyLibrary(
                    isScanning: isScanning,
                    onScan: () => _scan(fullRescan: false),
                  );
                }
                return Column(
                  children: visible
                      .map((item) => _MediaIndexTile(item: item))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final ColorScheme colors;
  final bool isScanning;
  final IndexerStatus? status;
  final VoidCallback onScan;

  const _LibraryHeader({
    required this.colors,
    required this.isScanning,
    required this.status,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final discovered = status?.discovered ?? 0;
    final analyzed = status?.analyzed ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.auto_awesome_motion_rounded,
              color: colors.onPrimary,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your media, organized',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isScanning
                      ? 'Scanning storage · $discovered found · $analyzed analyzed'
                      : 'Fast local index · refreshes only what changed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!isScanning)
            IconButton(
              onPressed: onScan,
              tooltip: 'Check for changes',
              icon: const Icon(Icons.refresh_rounded),
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<LocalMediaKind, int> counts;

  const _StatsRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Videos', (counts[LocalMediaKind.movie] ?? 0) +
          (counts[LocalMediaKind.series] ?? 0) +
          (counts[LocalMediaKind.anime] ?? 0)),
      ('Movies', counts[LocalMediaKind.movie] ?? 0),
      ('Series', (counts[LocalMediaKind.series] ?? 0) +
          (counts[LocalMediaKind.anime] ?? 0)),
      ('Unknown', counts[LocalMediaKind.unknown] ?? 0),
    ];
    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stat.$2}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      stat.$1,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MediaIndexTile extends StatelessWidget {
  final LocalIndexedItem item;

  const _MediaIndexTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUnknown = item.kind == LocalMediaKind.unknown;
    final icon = switch (item.kind) {
      LocalMediaKind.movie => Icons.movie_creation_outlined,
      LocalMediaKind.series || LocalMediaKind.anime => Icons.tv_rounded,
      LocalMediaKind.manga => Icons.menu_book_rounded,
      LocalMediaKind.novel => Icons.article_outlined,
      LocalMediaKind.unknown => Icons.help_outline_rounded,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUnknown
              ? colors.errorContainer
              : colors.secondaryContainer,
          child: Icon(
            icon,
            color: isUnknown
                ? colors.onErrorContainer
                : colors.onSecondaryContainer,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (item.episodeKey.isNotEmpty) item.episodeKey,
            if (item.badge.isNotEmpty) item.badge,
            item.filePath,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: item.confidence < 0.5
            ? const Icon(Icons.warning_amber_rounded)
            : Text('${(item.confidence * 100).round()}%'),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onScan;

  const _EmptyLibrary({required this.isScanning, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            isScanning
                ? Icons.hourglass_top_rounded
                : Icons.video_library_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            isScanning ? 'Scanning storage…' : 'No indexed media yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Smart Library never moves or deletes your files.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!isScanning) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.radar_rounded),
              label: const Text('Scan accessible storage'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}