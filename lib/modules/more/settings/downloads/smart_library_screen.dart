import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/metadata/local_media_metadata.dart';
import 'package:watchtower/local_indexer/metadata/local_metadata_resolver.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/models/local_work.dart';
import 'package:watchtower/local_indexer/providers/local_indexer_provider.dart';
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/modules/widgets/animated_empty_state.dart';
import 'package:watchtower/providers/storage_provider.dart';

/// The global, non-destructive media index.
///
/// Local Source remains the explicit Watchtower/local reader. Smart Library
/// only indexes accessible media and keeps the original paths untouched.
class SmartLibraryScreen extends ConsumerStatefulWidget {
  final ItemType? itemType;

  const SmartLibraryScreen({this.itemType, super.key});

  @override
  ConsumerState<SmartLibraryScreen> createState() => _SmartLibraryScreenState();
}

/// Filter applied to the library grid.
enum _SmartLibraryFilter { all, movies, series, review }

class _SmartLibraryScreenState extends ConsumerState<SmartLibraryScreen> {
  _SmartLibraryFilter _filter = _SmartLibraryFilter.all;
  bool _starting = false;

  bool get _isManga => widget.itemType == ItemType.manga;

  /// Directories that are worth walking for media. On Android the shared
  /// storage root is used when "all files" access is granted, which is what
  /// makes a single scan find every movie/series on the device.
  Future<List<String>> _scanRoots() async {
    final storage = StorageProvider();
    final roots = <String>[];

    if (!kIsWeb && Platform.isAndroid) {
      final hasAllFilesAccess = await storage.requestPermission();
      if (hasAllFilesAccess) {
        const sharedStorage = '/storage/emulated/0';
        if (Directory(sharedStorage).existsSync()) roots.add(sharedStorage);
      }
    }

    final base = await storage.getDefaultDirectory();
    if (base != null && !roots.contains(base.path)) roots.add(base.path);

    return roots;
  }

  Future<void> _scan({required bool fullRescan}) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final roots = await _scanRoots();
      if (roots.isEmpty) {
        throw StateError('Aucun emplacement de stockage accessible.');
      }
      final scanMode = _isManga ? LocalScanMode.manga : LocalScanMode.videos;
      final scan = ref.read(localIndexerScanProvider.notifier);
      if (fullRescan) {
        await scan.fullRescan(roots, mode: scanMode);
      } else {
        await scan.refresh(roots, mode: scanMode);
      }
      await scan.startWatching(roots, mode: scanMode);
      _invalidate();
      unawaited(_enrichMetadata());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec du scan : $error')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _invalidate() {
    ref.invalidate(localIndexedCountProvider);
    ref.invalidate(localIndexedCountByKindProvider);
    ref.invalidate(recentlyIndexedProvider);
    ref.invalidate(localWorksProvider);
  }

  Future<void> _enrichMetadata() async {
    try {
      final works = await ref.read(localWorksProvider.future);
      final items = [for (final work in works) work.files.first];
      final summary = await LocalMetadataResolver.instance.enrich(items);
      if (!mounted) return;
      ref.invalidate(localWorksProvider);
      if (summary.tmdbUnavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Les métadonnées TMDB sont indisponibles ; AniList reste utilisé.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('[SmartLibraryScreen] metadata enrichment failed: $error');
    }
  }

  bool _kindAllowed(LocalMediaKind kind) {
    if (kind == LocalMediaKind.novel) return false;
    if (_isManga) {
      return kind == LocalMediaKind.manga || kind == LocalMediaKind.unknown;
    }
    return kind == LocalMediaKind.anime ||
        kind == LocalMediaKind.series ||
        kind == LocalMediaKind.movie ||
        kind == LocalMediaKind.unknown;
  }

  List<LocalWork> _filterWorks(List<LocalWork> works) {
    return works.where((work) {
      if (!_kindAllowed(work.kind)) return false;
      switch (_filter) {
        case _SmartLibraryFilter.all:
          return true;
        case _SmartLibraryFilter.movies:
          return work.kind == LocalMediaKind.movie;
        case _SmartLibraryFilter.series:
          return work.isSeries;
        case _SmartLibraryFilter.review:
          return work.kind == LocalMediaKind.unknown ||
              work.missingEpisodes.isNotEmpty;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(indexerStatusProvider).asData?.value;
    final isScanning = _starting || (status?.isScanning ?? false);
    final works = ref.watch(localWorksProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: _isManga ? 'Smart Library Manga' : 'Smart Library Watch',
              isManga: _isManga,
              isScanning: isScanning,
              discovered: status?.discovered ?? 0,
              onScan: () => _scan(fullRescan: false),
              onFullRescan: () => _scan(fullRescan: true),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _scan(fullRescan: false),
                child: works.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      AnimatedEmptyState(
                        message: 'Index illisible : $error',
                        icon: Broken.danger,
                      ),
                    ],
                  ),
                  data: (allWorks) {
                    final visible = _filterWorks(allWorks);
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _FilterBar(
                            isManga: _isManga,
                            selected: _filter,
                            onChanged: (f) => setState(() => _filter = f),
                          ),
                        ),
                        if (visible.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: AnimatedEmptyState(
                              message: isScanning
                                  ? 'Analyse du stockage…'
                                  : 'Aucun média indexé pour le moment',
                              icon: isScanning
                                  ? Broken.refresh_2
                                  : Broken.folder_open,
                            ),
                          )
                        else
                          _WorkSliverGrid(works: visible, onOpen: _openWork),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWork(LocalWork work) {
    // Local playback wiring is owned by the reader/player modules; until a
    // local player route exists we surface the work so the entry is not a
    // dead end.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          work.files.length == 1
              ? p.basename(work.files.first.filePath)
              : '${work.title} · ${work.episodes.length} épisodes',
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final bool isManga;
  final bool isScanning;
  final int discovered;
  final VoidCallback onScan;
  final VoidCallback onFullRescan;

  const _Header({
    required this.title,
    required this.isManga,
    required this.isScanning,
    required this.discovered,
    required this.onScan,
    required this.onFullRescan,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      child: Row(
        children: [
          Icon(
            isManga ? Broken.book : Broken.video_play,
            size: 22,
            color: cs.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: cs.onSurface,
                  ),
                ),
                if (isScanning)
                  Text(
                    'Analyse du stockage · $discovered fichiers',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else
            IconButton(
              tooltip: 'Rechercher des changements',
              onPressed: onScan,
              icon: const Icon(Broken.refresh_2),
            ),
          IconButton(
            tooltip: 'Vérifier tout le stockage',
            onPressed: isScanning ? null : onFullRescan,
            icon: const Icon(Broken.search_zoom_in),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool isManga;
  final _SmartLibraryFilter selected;
  final ValueChanged<_SmartLibraryFilter> onChanged;

  const _FilterBar({
    required this.isManga,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <(_SmartLibraryFilter, String, IconData)>[
      (_SmartLibraryFilter.all, 'Tout', Broken.element_3),
      if (!isManga) ...[
        (_SmartLibraryFilter.movies, 'Films', Broken.video),
        (_SmartLibraryFilter.series, 'Séries', Broken.monitor),
      ],
      (_SmartLibraryFilter.review, 'À vérifier', Broken.warning_2),
    ];
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: segments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label, icon) = segments[i];
          final isSelected = value == selected;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.16)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
// ── Work grid ─────────────────────────────────────────────────────────────────

/// Grid of indexed works. Each card is one movie or one season of a series,
/// with its poster (from the metadata sidecar when available), the episode
/// count and, when the season is incomplete, the numbers that are missing.
class _WorkSliverGrid extends StatelessWidget {
  final List<LocalWork> works;
  final void Function(LocalWork) onOpen;

  const _WorkSliverGrid({required this.works, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200
        ? 6
        : width >= 900
        ? 5
        : width >= 700
        ? 4
        : 3;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 0.62,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              _WorkCard(work: works[i], onTap: () => onOpen(works[i])),
          childCount: works.length,
        ),
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  final LocalWork work;
  final VoidCallback onTap;

  const _WorkCard({required this.work, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<LocalMediaMetadata?>(
      future: LocalMediaMetadataStore.instance.get(work.files.first),
      builder: (context, snapshot) {
        final metadata = snapshot.data;
        final poster = metadata?.posterUrl;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: cs.surfaceContainerHighest,
                        child: poster != null
                            ? Image.network(
                                poster,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallback(cs),
                              )
                            : _fallback(cs),
                      ),
                      if (work.isSeries)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _Pill(
                            label: '${work.episodeLabel} ép.',
                            color: cs.primary,
                          ),
                        ),
                      if (work.missingEpisodes.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _Pill(
                            label:
                                '${work.missingEpisodes.length} manquant'
                                '${work.missingEpisodes.length == 1 ? '' : 's'}',
                            color: cs.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                metadata?.title ?? work.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                _subtitle(metadata),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(LocalMediaMetadata? metadata) {
    final parts = <String>[
      if (work.isSeries && (work.season ?? 1) > 1) 'Saison ${work.season}',
      if (metadata?.year != null) '${metadata!.year}',
      if (work.isSeries && work.episodes.isNotEmpty)
        'S${work.season ?? 1}E${work.episodes.first}'
            '${work.episodes.length > 1 ? '-E${work.episodes.last}' : ''}',
      if (!work.isSeries && work.kind == LocalMediaKind.movie) 'Film',
    ];
    if (parts.isEmpty) return p.basename(work.files.first.filePath);
    return parts.join(' · ');
  }

  Widget _fallback(ColorScheme cs) => Center(
    child: Icon(
      switch (work.kind) {
        LocalMediaKind.movie => Broken.video,
        LocalMediaKind.series || LocalMediaKind.anime => Broken.monitor,
        LocalMediaKind.manga => Broken.book,
        LocalMediaKind.novel => Broken.document_text,
        LocalMediaKind.unknown => Broken.warning_2,
      },
      size: 30,
      color: cs.onSurface.withValues(alpha: 0.35),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
