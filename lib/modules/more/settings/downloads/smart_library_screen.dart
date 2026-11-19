import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/engine/watcher/android_media_store.dart';
import 'package:watchtower/local_indexer/metadata/local_media_metadata.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/models/local_work.dart';
import 'package:watchtower/local_indexer/providers/local_indexer_provider.dart';
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/modules/more/settings/downloads/local_work_detail_sheet.dart';
import 'package:watchtower/modules/widgets/animated_empty_state.dart';
import 'package:watchtower/providers/l10n_providers.dart';
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

/// Well-known shared-storage folders that hold media. Used as a fallback when
/// the storage root itself cannot be listed.
const _androidMediaDirectories = [
  'Movies',
  'Download',
  'Downloads',
  'DCIM',
  'Pictures',
  'Videos',
  'watchtower',
  'Watchtower',
];

/// Music-specific fallback folders. Kept separate so the Watch scan does not
/// pick up ringtones or notification sounds under /Audio.
const _androidMusicDirectories = [
  'Music',
  'Podcasts',
  'Recordings',
  'Download',
  'Downloads',
  'watchtower',
  'Watchtower',
];

/// Well-known media folders inside the user's home directory, used on desktop
/// (Windows/macOS/Linux) and iOS so a scan covers the whole device and not just
/// the app's own documents folder.
class _SmartLibraryScreenState extends ConsumerState<SmartLibraryScreen> {
  _SmartLibraryFilter _filter = _SmartLibraryFilter.all;
  bool _starting = false;

  /// Which scanner this screen drives. The route may pin it (opened from the
  /// Music tab), otherwise the user picks between Watch, Manga and Music here
  /// — previously the screen was always in Watch mode, so music and manga
  /// could never be scanned from the Smart Library entry point.
  late ItemType _itemType;

  @override
  void initState() {
    super.initState();
    _itemType = widget.itemType ?? ItemType.anime;
    // Opening the library used to leave the grid empty until the user found
    // the refresh button, which read as "the scan does nothing". Kick off an
    // incremental scan once on first build; the cache makes it cheap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_scan(fullRescan: false));
    });
  }

  bool get _isManga => _itemType == ItemType.manga;
  bool get _isMusic => _itemType == ItemType.music;

  /// Directories that are worth walking for media.
  ///
  /// The scan must not depend on "all files" access: on Android 13+ the app can
  /// read every video with READ_MEDIA_VIDEO alone, and MediaStore already knows
  /// where they are. Requesting the video permission and walking the shared
  /// storage root (plus the well-known media folders) finds the library even
  /// when MANAGE_EXTERNAL_STORAGE was never granted — the previous code only
  /// ever added `/storage/emulated/0` in that one case, so without it the scan
  /// saw just the app's own folder and reported nothing.
  Future<List<String>> _scanRoots() async {
    final storage = StorageProvider();
    final roots = <String>[];

    if (!kIsWeb && Platform.isAndroid) {
      if (_isMusic) {
        await storage.requestAudioPermission();
      } else if (_isManga) {
        await storage.requestMediaPermission();
      } else {
        await storage.requestVideoPermission();
      }
      // Every mounted volume, not just the internal shared storage: a library
      // kept on an SD card or a USB stick is exactly what a media player is
      // expected to find. MediaStore reports those files too, so the walk must
      // cover the same ground.
      final volumes = await AndroidMediaStore.storageVolumes();
      final androidRoots = volumes.isEmpty
          ? const ['/storage/emulated/0']
          : volumes;
      for (final volume in androidRoots) {
        if (Directory(volume).existsSync()) roots.add(volume);
      }
      if (roots.isEmpty) {
        final fallback = _isMusic
            ? _androidMusicDirectories
            : _androidMediaDirectories;
        for (final name in fallback) {
          final path = '/storage/emulated/0/$name';
          if (Directory(path).existsSync()) roots.add(path);
        }
      }
    }

    final base = await storage.getDefaultDirectory();
    if (base != null && !roots.contains(base.path)) roots.add(base.path);

    // On desktop and iOS there is no MediaStore and no shared-storage root:
    // the user's library lives somewhere under their home folder. Walking the
    // home folder is what makes the scan cover "the whole device" there, and
    // the ignored-directory list keeps caches, node_modules and friends out.
    if (!kIsWeb && !Platform.isAndroid) {
      final home = _userHomeDirectory();
      if (home != null && !roots.contains(home)) roots.add(home);
    }

    return roots;
  }

  /// The current user's home directory, or null when it cannot be determined.
  String? _userHomeDirectory() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home != null && home.isNotEmpty && Directory(home).existsSync()) {
      return home;
    }
    return null;
  }

  /// Starts a scan through the keep-alive scan provider.
  ///
  /// The actual work runs in [LocalIndexerScan], not in this widget, so it
  /// survives the user leaving the page and so nothing touches `ref`/`context`
  /// after the widget is unmounted (which used to throw
  /// `Bad state: Using "ref" when a widget is about to or has been unmounted`).
  Future<void> _scan({required bool fullRescan}) async {
    if (_starting) return;
    setState(() => _starting = true);
    final scanMode = _isMusic
        ? LocalScanMode.music
        : _isManga
        ? LocalScanMode.manga
        : LocalScanMode.videos;
    final locale = Localizations.localeOf(context);
    final noStorageRoot = context.l10n.smart_no_storage_root;
    try {
      final roots = await _scanRoots();
      if (roots.isEmpty) {
        throw StateError(noStorageRoot);
      }
      final scan = ref.read(localIndexerScanProvider.notifier);
      if (fullRescan) {
        await scan.fullRescan(roots, mode: scanMode, locale: locale);
      } else {
        await scan.refresh(roots, mode: scanMode, locale: locale);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.smart_scan_failed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Switches the scanner and rescans with the new mode.
  Future<void> _switchType(ItemType type) async {
    if (type == _itemType) return;
    setState(() {
      _itemType = type;
      _filter = _SmartLibraryFilter.all;
    });
    await _scan(fullRescan: false);
  }

  bool _kindAllowed(LocalMediaKind kind) {
    if (kind == LocalMediaKind.novel) return false;
    if (_isMusic) {
      return kind == LocalMediaKind.music || kind == LocalMediaKind.unknown;
    }
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
          // Music reuses this slot for "Albums": a multi-track release.
          if (_isMusic) return work.fileCount > 1;
          return work.kind == LocalMediaKind.movie;
        case _SmartLibraryFilter.series:
          // Music reuses this slot for "Singles": a lone track.
          if (_isMusic) return work.fileCount == 1;
          return work.isSeries;
        case _SmartLibraryFilter.review:
          return work.kind == LocalMediaKind.unknown ||
              work.missingEpisodes.isNotEmpty;
      }
    }).toList();
  }

  String get _libraryTitle {
    if (_isMusic) return context.l10n.smart_library_music_title;
    if (_isManga) return context.l10n.smart_library_manga_title;
    return context.l10n.smart_library_watch_title;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(indexerStatusProvider).asData?.value;
    final scan = ref.watch(localIndexerScanProvider);
    final isScanning = _starting || scan.isBusy || (status?.isScanning ?? false);
    final works = ref.watch(localWorksProvider);

    // Surface enrichment notices that used to be shown from the widget's async
    // callback (which could fire after unmount).
    ref.listen(localIndexerScanProvider, (previous, next) {
      if (next.phase == SmartLibraryScanPhase.error &&
          previous?.phase != SmartLibraryScanPhase.error &&
          next.error != null &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.smart_scan_failed(next.error!))),
        );
      }
      if (next.tmdbUnavailable &&
          previous?.tmdbUnavailable != true &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.smart_tmdb_unavailable)),
        );
      }
    });

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: _libraryTitle,
              isManga: _isManga,
              isMusic: _isMusic,
              isScanning: isScanning,
              discovered: scan.discovered > 0
                  ? scan.discovered
                  : (status?.discovered ?? 0),
              progress: scan.progress,
              onScan: () => _scan(fullRescan: false),
              onFullRescan: () => _scan(fullRescan: true),
            ),
            if (widget.itemType == null)
              _TypeSelector(
                selected: _itemType,
                onChanged: _switchType,
              ),
            if (scan.isBusy)
              _ScanProgressBar(
                phase: scan.phase,
                progress: scan.progress,
                processed: scan.processed,
                total: scan.total,
                discovered: scan.discovered,
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
                        message: context.l10n.smart_index_unreadable('$error'),
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
                            isMusic: _isMusic,
                            selected: _filter,
                            onChanged: (f) => setState(() => _filter = f),
                          ),
                        ),
                        if (visible.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: AnimatedEmptyState(
                              message: isScanning
                                  ? context.l10n.smart_scanning_storage
                                  : context.l10n.smart_no_media_indexed,
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
    LocalWorkDetailSheet.show(context, work);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

/// Segmented Watch / Manga / Music selector.
///
/// Without it the Smart Library entry point was hard-wired to Watch, so music
/// and manga were unreachable from the plugin page.
class _TypeSelector extends StatelessWidget {
  final ItemType selected;
  final ValueChanged<ItemType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: SegmentedButton<ItemType>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: [
          ButtonSegment(
            value: ItemType.anime,
            icon: const Icon(Broken.video_play, size: 16),
            label: Text(l10n.watch),
          ),
          ButtonSegment(
            value: ItemType.manga,
            icon: const Icon(Broken.book, size: 16),
            label: Text(l10n.manga),
          ),
          ButtonSegment(
            value: ItemType.music,
            icon: const Icon(Broken.musicnote, size: 16),
            label: Text(l10n.catalog_tab_music),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final bool isManga;
  final bool isMusic;
  final bool isScanning;
  final int discovered;
  final double? progress;
  final VoidCallback onScan;
  final VoidCallback onFullRescan;

  const _Header({
    required this.title,
    required this.isManga,
    required this.isMusic,
    required this.isScanning,
    required this.discovered,
    required this.progress,
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
            isMusic
                ? Broken.musicnote
                : isManga
                ? Broken.book
                : Broken.video_play,
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
                    progress != null
                        ? context.l10n.smart_scanning_storage_percent(
                            (progress! * 100).clamp(0, 100).floor(),
                          )
                        : context.l10n.smart_scanning_storage_count(discovered),
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
              tooltip: context.l10n.smart_search_changes,
              onPressed: onScan,
              icon: const Icon(Broken.refresh_2),
            ),
          IconButton(
            tooltip: context.l10n.smart_verify_storage,
            onPressed: isScanning ? null : onFullRescan,
            icon: const Icon(Broken.search_zoom_in),
          ),
        ],
      ),
    );
  }
}

// ── Scan progress bar ───────────────────────────────────────────────────────

/// Thin determinate/indeterminate bar shown under the header during a scan.
///
/// Discovery has no denominator yet, so it animates; the analysis and
/// enrichment phases have a real total and show a percentage.
class _ScanProgressBar extends StatelessWidget {
  final SmartLibraryScanPhase phase;
  final double? progress;
  final int processed;
  final int total;
  final int discovered;

  const _ScanProgressBar({
    required this.phase,
    required this.progress,
    required this.processed,
    required this.total,
    required this.discovered,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final label = switch (phase) {
      SmartLibraryScanPhase.discovering =>
        l10n.smart_scan_notif_discovering(discovered),
      SmartLibraryScanPhase.analyzing =>
        l10n.smart_scan_notif_progress_percent(
          ((progress ?? 0) * 100).clamp(0, 100).floor(),
          processed,
          total,
        ),
      // Enrichment is one lookup at a time with a rate-limit pause between
      // calls, so a fixed label looks frozen. Show the real counter.
      SmartLibraryScanPhase.enriching => total > 0
          ? l10n.smart_scan_notif_progress_percent(
              ((progress ?? 0) * 100).clamp(0, 100).floor(),
              processed,
              total,
            )
          : l10n.smart_scanning_storage,
      _ => l10n.smart_scan_notif_starting,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null)
          LinearProgressIndicator(value: progress, minHeight: 3)
        else
          const LinearProgressIndicator(minHeight: 3),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool isManga;
  final bool isMusic;
  final _SmartLibraryFilter selected;
  final ValueChanged<_SmartLibraryFilter> onChanged;

  const _FilterBar({
    required this.isManga,
    required this.isMusic,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final segments = <(_SmartLibraryFilter, String, IconData)>[
      (_SmartLibraryFilter.all, l10n.home_tab_all, Broken.element_3),
      if (!isManga && !isMusic) ...[
        (_SmartLibraryFilter.movies, l10n.home_movies, Broken.video),
        (_SmartLibraryFilter.series, l10n.home_series, Broken.monitor),
      ],
      if (isMusic) ...[
        (_SmartLibraryFilter.movies, l10n.smart_filter_albums, Broken.music),
        (
          _SmartLibraryFilter.series,
          l10n.smart_filter_singles,
          Broken.musicnote,
        ),
      ],
      (_SmartLibraryFilter.review, l10n.smart_to_review, Broken.warning_2),
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
                            label: context.l10n.media_ep_short(
                              work.episodeLabel,
                            ),
                            color: cs.primary,
                          ),
                        ),
                      if (work.missingEpisodes.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _Pill(
                            label: context.l10n.smart_missing_episodes(
                              work.missingEpisodes.length,
                            ),
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
                _subtitle(context, metadata),
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

  String _subtitle(BuildContext context, LocalMediaMetadata? metadata) {
    if (work.isMusic) {
      final artist = work.files.first.artist;
      final parts = <String>[
        if (artist != null && artist.isNotEmpty) artist,
        context.l10n.smart_track_count(work.fileCount),
      ];
      return parts.join(' · ');
    }
    final parts = <String>[
      if (work.isSeries && (work.season ?? 1) > 1)
        context.l10n.media_season_n(work.season!),
      if (metadata?.year != null) '${metadata!.year}',
      if (work.isSeries && work.episodes.isNotEmpty)
        'S${work.season ?? 1}E${work.episodes.first}'
            '${work.episodes.length > 1 ? '-E${work.episodes.last}' : ''}',
      if (!work.isSeries && work.kind == LocalMediaKind.movie)
        context.l10n.media_movie,
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
        LocalMediaKind.music => Broken.music,
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
