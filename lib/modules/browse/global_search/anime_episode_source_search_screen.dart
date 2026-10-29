import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/watch/home/extension_episode_card_adapter.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/language.dart';

class AnimeEpisodeSourceSearchScreen extends ConsumerStatefulWidget {
  final AnilistMedia media;
  final AniZipEpisode episode;

  const AnimeEpisodeSourceSearchScreen({
    required this.media,
    required this.episode,
    super.key,
  });

  @override
  ConsumerState<AnimeEpisodeSourceSearchScreen> createState() =>
      _AnimeEpisodeSourceSearchScreenState();
}

class _AnimeEpisodeSourceSearchScreenState
    extends ConsumerState<AnimeEpisodeSourceSearchScreen> {
  final List<_EpisodeSourceResult> _results = [];
  int _checkedSources = 0;
  int _sourceCount = 0;
  int _failedSources = 0;
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchSources());
  }

  List<String> get _titleQueries {
    final titles = [
      widget.media.titleEnglish,
      widget.media.titleRomaji,
      widget.media.titleNative,
      widget.media.displayTitle,
    ];
    final seen = <String>{};
    return titles
        .whereType<String>()
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty && seen.add(_normalize(title)))
        .take(3)
        .toList(growable: false);
  }

  Future<void> _searchSources() async {
    final showNsfw = ref.read(showNSFWStateProvider);
    final onlyPinned = ref.read(onlyIncludePinnedSourceStateProvider);
    final sources = isar.sources
        .filter()
        .isAddedEqualTo(true)
        .and()
        .isActiveEqualTo(true)
        .and()
        .itemTypeEqualTo(ItemType.anime)
        .findAllSync()
        .where(
          (source) =>
              source.name?.trim().isNotEmpty == true &&
              source.lang?.trim().isNotEmpty == true &&
              source.sourceCodeLanguage != SourceCodeLanguage.unsupported &&
              (!onlyPinned || source.isPinned == true) &&
              (showNsfw || source.isNsfw != true),
        )
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _sourceCount = sources.length;
      _isSearching = sources.isNotEmpty;
    });
    if (sources.isEmpty) return;

    var nextIndex = 0;
    final workers = List.generate(sources.length < 6 ? sources.length : 6, (
      _,
    ) async {
      while (mounted) {
        if (nextIndex >= sources.length) return;
        final source = sources[nextIndex++];
        try {
          final result = await _searchOneSource(source);
          if (mounted && result != null) {
            setState(() => _results.add(result));
          }
        } catch (_) {
          _failedSources++;
        } finally {
          if (mounted) {
            setState(() => _checkedSources++);
          }
        }
      }
    });
    await Future.wait(workers);
    if (mounted) setState(() => _isSearching = false);
  }

  Future<_EpisodeSourceResult?> _searchOneSource(Source source) async {
    final queries = _titleQueries;
    if (queries.isEmpty) return null;

    List<MManga> candidates = [];
    var completedSearches = 0;
    for (final query in queries) {
      try {
        final pages = await ref
            .read(
              searchProvider(
                source: source,
                query: query,
                page: 1,
                filterList: const [],
              ).future,
            )
            .timeout(const Duration(seconds: 25));
        completedSearches++;
        candidates = (pages?.list ?? const <MManga>[])
            .where(
              (item) =>
                  item.link?.trim().isNotEmpty == true &&
                  _matchesTitle(item.name ?? '', _titleQueries),
            )
            .take(4)
            .toList(growable: false);
      } on TimeoutException {
        rethrow;
      } catch (_) {
        continue;
      }
      if (candidates.isNotEmpty) break;
    }
    if (completedSearches == 0) {
      throw StateError('Les recherches de cette extension ont échoué.');
    }

    var failedDetails = 0;
    for (final candidate in candidates) {
      late final MManga detail;
      try {
        detail = await ref
            .read(
              getDetailProvider(source: source, url: candidate.link!).future,
            )
            .timeout(const Duration(seconds: 25));
      } on TimeoutException {
        rethrow;
      } catch (_) {
        // One broken result must not hide other matches from the same source.
        failedDetails++;
        continue;
      }
      final episode = (detail.chapters ?? const <MChapter>[]).where(
        (chapter) =>
            chapter.url?.trim().isNotEmpty == true &&
            _episodeNumber(chapter) == widget.episode.episodeNumber,
      );
      if (episode.isNotEmpty) {
        return _EpisodeSourceResult(
          source: source,
          series: detail,
          episode: episode.first,
        );
      }
    }
    if (candidates.isNotEmpty && failedDetails == candidates.length) {
      throw StateError('Les fiches de cette extension n’ont pas répondu.');
    }
    return null;
  }

  int? _episodeNumber(MChapter chapter) {
    final parsed = ExtensionEpisodeCardAdapter.parseEpisodeNumber(chapter.name);
    if (parsed != null) return parsed;

    final title = _normalize(chapter.name ?? '');
    final episodeTitle = _normalize(widget.episode.displayTitle);
    if (episodeTitle != 'episode ${widget.episode.episodeNumber}' &&
        episodeTitle.length > 3 &&
        title.contains(episodeTitle)) {
      return widget.episode.episodeNumber;
    }
    return null;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'[^a-z0-9\u00c0-\u024f\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+',
        ),
        ' ',
      )
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _matchesTitle(String candidate, List<String> aliases) {
    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate.length < 4) return false;
    for (final alias in aliases) {
      final normalizedAlias = _normalize(alias);
      if (normalizedAlias.length < 4) continue;
      if (normalizedCandidate == normalizedAlias ||
          normalizedCandidate.contains(normalizedAlias) ||
          normalizedAlias.contains(normalizedCandidate)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadVideoTracks(_EpisodeSourceResult result) async {
    if (result.isLoadingVideos || result.videos != null) return;
    setState(() {
      result.isLoadingVideos = true;
      result.videoError = null;
    });
    try {
      final videos = await getIsolateService
          .get<List<Video>>(
            url: result.episode.url,
            source: result.source,
            serviceType: 'getVideoList',
          )
          .timeout(const Duration(seconds: 25));
      if (mounted) setState(() => result.videos = videos);
    } catch (_) {
      if (mounted) {
        setState(() => result.videoError = 'Impossible de charger les pistes.');
      }
    } finally {
      if (mounted) setState(() => result.isLoadingVideos = false);
    }
  }

  Future<void> _playEpisode(_EpisodeSourceResult result) async {
    final source = result.source;
    final series = result.series;
    final extensionEpisode = result.episode;
    final url = extensionEpisode.url?.trim();
    if (url == null || url.isEmpty) return;

    try {
      final existing = isar.mangas
          .filter()
          .sourceIdEqualTo(source.id)
          .and()
          .langEqualTo(source.lang)
          .and()
          .linkEqualTo(series.link)
          .findFirstSync();
      final manga =
          existing ??
          Manga(
            source: source.name,
            author: series.author ?? '',
            artist: series.artist ?? '',
            genre: series.genre ?? const [],
            imageUrl: series.imageUrl,
            lang: source.lang,
            link: series.link,
            name: series.name ?? widget.media.displayTitle,
            status: series.status ?? Status.unknown,
            description: series.description ?? '',
            sourceId: source.id,
            itemType: ItemType.anime,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );

      late final int chapterId;
      await isar.writeTxn(() async {
        final mangaId = await isar.mangas.put(manga);
        final existingChapter = await isar.chapters
            .filter()
            .mangaIdEqualTo(mangaId)
            .and()
            .urlEqualTo(url)
            .findFirst();
        if (existingChapter != null) {
          chapterId = existingChapter.id!;
          return;
        }

        final chapter = Chapter(
          name:
              extensionEpisode.name ??
              'Episode ${widget.episode.episodeNumber}',
          url: url,
          mangaId: mangaId,
          dateUpload: extensionEpisode.dateUpload ?? '',
          scanlator: extensionEpisode.scanlator ?? '',
          thumbnailUrl: extensionEpisode.thumbnailUrl,
          description: extensionEpisode.description,
          duration: extensionEpisode.duration,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        )..manga.value = manga;
        chapterId = await isar.chapters.put(chapter);
        await chapter.manga.save();
      });
      if (mounted) context.push('/animePlayerView', extra: chapterId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lecture impossible : $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.media.displayTitle;
    final episode = widget.episode.episodeNumber;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Broken.arrow_left_2),
        ),
        title: const Text('Sources de l’épisode'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Épisode $episode · ${widget.episode.displayTitle}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (_isSearching) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _sourceCount == 0
                        ? null
                        : _checkedSources / _sourceCount,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Recherche dans $_checkedSources / $_sourceCount sources',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? _emptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _resultCard(context, _results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = _sourceCount == 0
        ? 'Aucune extension anime active n’est installée.'
        : _isSearching
        ? 'Recherche de l’épisode sur les extensions installées…'
        : 'Aucune extension ne propose cet épisode.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSearching ? Broken.search_normal_1 : Broken.video_remove,
              size: 42,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (!_isSearching && _failedSources > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$_failedSources source(s) n’ont pas répondu.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (!_isSearching && _sourceCount > 0) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _results.clear();
                    _checkedSources = 0;
                    _failedSources = 0;
                    _isSearching = true;
                  });
                  unawaited(_searchSources());
                },
                icon: const Icon(Broken.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, _EpisodeSourceResult result) {
    final cs = Theme.of(context).colorScheme;
    final videos = result.videos;
    final qualities =
        videos
            ?.map((video) => video.quality.trim())
            .where((quality) => quality.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    final subtitles =
        videos
            ?.expand((video) => video.subtitles ?? const [])
            .map((track) => track.label?.trim() ?? '')
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    final audioTracks =
        videos
            ?.expand((video) => video.audios ?? const [])
            .map((track) => track.label?.trim() ?? '')
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                    image: result.source.iconUrl?.trim().isNotEmpty == true
                        ? DecorationImage(
                            image: NetworkImage(result.source.iconUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: result.source.iconUrl?.trim().isNotEmpty == true
                      ? null
                      : Icon(Broken.video, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.source.name ?? 'Extension',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${completeLanguageName(result.source.lang ?? '')} · '
                        '${result.episode.name ?? 'Épisode ${widget.episode.episodeNumber}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.isLoadingVideos)
              const LinearProgressIndicator()
            else if (videos == null) ...[
              if (result.videoError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    result.videoError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _loadVideoTracks(result),
                icon: const Icon(Broken.video_play, size: 18),
                label: Text(
                  result.videoError == null
                      ? 'Voir qualité et sous-titres'
                      : 'Réessayer les pistes',
                ),
              ),
            ] else ...[
              if (result.videoError != null)
                Text(
                  result.videoError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.error),
                )
              else if (videos.isEmpty)
                Text(
                  'Aucune piste vidéo détectée.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...[
                if (qualities.isNotEmpty)
                  _metadataLine(
                    context,
                    Broken.video,
                    'Qualité',
                    qualities.join(' · '),
                  ),
                if (audioTracks.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _metadataLine(
                    context,
                    Broken.volume_high,
                    'Audio',
                    audioTracks.join(' · '),
                  ),
                ],
                const SizedBox(height: 5),
                _metadataLine(
                  context,
                  Broken.subtitle,
                  'Sous-titres',
                  subtitles.isEmpty ? 'Non indiqués' : subtitles.join(' · '),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: videos.isEmpty ? null : () => _playEpisode(result),
                  icon: const Icon(Broken.play, size: 18),
                  label: const Text('Lire cet épisode'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metadataLine(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Text('$label : ', style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _EpisodeSourceResult {
  final Source source;
  final MManga series;
  final MChapter episode;
  List<Video>? videos;
  bool isLoadingVideos = false;
  String? videoError;

  _EpisodeSourceResult({
    required this.source,
    required this.series,
    required this.episode,
  });
}
