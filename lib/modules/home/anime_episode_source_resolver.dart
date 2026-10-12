import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/anime_source_matcher.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/language.dart';

class AnimeEpisodeSourceResolver extends ConsumerStatefulWidget {
  final AnilistMedia media;
  final AniZipEpisode episode;

  const AnimeEpisodeSourceResolver({
    super.key,
    required this.media,
    required this.episode,
  });

  @override
  ConsumerState<AnimeEpisodeSourceResolver> createState() =>
      _AnimeEpisodeSourceResolverState();
}

class _AnimeEpisodeSourceResolverState
    extends ConsumerState<AnimeEpisodeSourceResolver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Animation<double> _pulse;
  final List<_ResolvedSource> _matches = [];
  int _scanned = 0;
  int _sourceCount = 0;
  int _failedSources = 0;
  bool _loading = true;
  bool _launchingPlayer = false;
  String _phase = 'Préparation de la recherche…';

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );
    _resolve();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  List<Source> _eligibleSources() {
    final pinnedOnly = ref.read(onlyIncludePinnedSourceStateProvider);
    final showNsfw = ref.read(showNSFWStateProvider);
    return isar.sources
        .filter()
        .itemTypeEqualTo(ItemType.anime)
        .findAllSync()
        .where(
          (source) =>
              (pinnedOnly ? source.isPinned == true : source.isAdded == true) &&
              source.isActive != false &&
              source.sourceCodeLanguage != SourceCodeLanguage.unsupported &&
              (showNsfw || source.isNsfw != true) &&
              (source.name?.trim().isNotEmpty ?? false),
        )
        .toList(growable: false);
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _scanned = 0;
      _sourceCount = 0;
      _failedSources = 0;
      _matches.clear();
      _phase = 'Lecture des titres et de la date de référence…';
    });

    AnilistMediaDetail? metadata;
    try {
      metadata = await ref
          .read(anilistMediaDetailProvider(widget.media.id).future)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // The selected AniList title is still usable if its expanded metadata
      // cannot be refreshed; date and relation checks then remain optional.
    }
    if (!mounted) return;

    final sources = _eligibleSources();
    setState(() {
      _sourceCount = sources.length;
      _phase = sources.isEmpty
          ? 'Aucune extension anime active à interroger'
          : 'Recherche silencieuse dans ${sources.length} extension(s)…';
    });
    if (sources.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    var nextSource = 0;
    final workerCount = math.min(4, sources.length);
    await Future.wait(
      List.generate(workerCount, (_) async {
        while (mounted) {
          final index = nextSource++;
          if (index >= sources.length) return;
          final source = sources[index];
          try {
            final found = await _resolveSource(source, metadata).timeout(
              const Duration(seconds: 42),
              onTimeout: () => <_ResolvedSource>[],
            );
            if (mounted && found.isNotEmpty) {
              setState(() {
                _matches.addAll(found);
                _sortMatches();
                _phase = 'Épisode confirmé · vérification des flux disponibles…';
              });
            }
          } catch (_) {
            if (mounted) setState(() => _failedSources++);
          } finally {
            if (mounted) {
              setState(() {
                _scanned++;
                if (_scanned >= _sourceCount) {
                  _loading = false;
                  _phase = _matches.isEmpty
                      ? 'Aucune source fiable trouvée pour cet épisode'
                      : '${_matches.length} source(s) vérifiée(s)';
                }
              });
            }
          }
        }
      }),
    );
    if (mounted) {
      setState(() {
        _loading = false;
        if (_sourceCount > 0 && _scanned < _sourceCount) {
          _phase = _matches.isEmpty
              ? 'Recherche interrompue'
              : '${_matches.length} source(s) vérifiée(s)';
        }
      });
    }
  }

  Future<List<_ResolvedSource>> _resolveSource(
    Source source,
    AnilistMediaDetail? metadata,
  ) async {
    final queries = _searchTitles(source, metadata);
    final candidates = <String, MManga>{};

    for (final query in queries.take(3)) {
      if (!mounted) return [];
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
            .timeout(const Duration(seconds: 7));

        for (final candidate in pages?.list ?? const <MManga>[]) {
          final link = candidate.link?.trim() ?? '';
          if (link.isEmpty) continue;
          final score = AnimeSourceMatcher.scoreSeries(
            media: widget.media,
            metadata: metadata,
            candidateName: candidate.name,
          );
          if (!score.rejected && score.score >= 65) {
            candidates.putIfAbsent('${source.id}|$link', () => candidate);
          }
        }

        final hasExactCandidate = candidates.values.any((candidate) {
          final score = AnimeSourceMatcher.scoreSeries(
            media: widget.media,
            metadata: metadata,
            candidateName: candidate.name,
          );
          return !score.rejected && score.score >= 95;
        });
        if (hasExactCandidate) break;
      } catch (_) {
        // Continue with the next AniList spelling when this query fails.
      }
    }

    final ordered = candidates.values.toList()
      ..sort((a, b) {
        final aScore = AnimeSourceMatcher.scoreSeries(
          media: widget.media,
          metadata: metadata,
          candidateName: a.name,
        ).score;
        final bScore = AnimeSourceMatcher.scoreSeries(
          media: widget.media,
          metadata: metadata,
          candidateName: b.name,
        ).score;
        return bScore.compareTo(aScore);
      });

    final resolved = <_ResolvedSource>[];
    for (final searchResult in ordered.take(1)) {
      if (!mounted) break;
      final resultLink = searchResult.link?.trim() ?? '';
      if (resultLink.isEmpty) continue;

      MManga details = searchResult;
      if (searchResult.chapters?.isNotEmpty != true) {
        try {
          details = await ref
              .read(getDetailProvider(url: resultLink, source: source).future)
              .timeout(const Duration(seconds: 9));
        } catch (_) {
          continue;
        }
      }

      final verifiedName = details.name?.trim().isNotEmpty == true
          ? details.name
          : searchResult.name;
      final titleMatch = AnimeSourceMatcher.scoreSeries(
        media: widget.media,
        metadata: metadata,
        candidateName: verifiedName,
      );
      if (titleMatch.rejected || titleMatch.score < 75) continue;

      final chapters = details.chapters?.isNotEmpty == true
          ? details.chapters!
          : searchResult.chapters ?? const <MChapter>[];
      final episode = AnimeSourceMatcher.matchEpisode(
        requested: widget.episode,
        chapters: chapters,
        mediaFormat: widget.media.format,
      );
      if (episode == null || (episode.url?.trim().isEmpty ?? true)) continue;

      List<Video> videos = [];
      try {
        videos = await _loadVideos(source, episode.url!.trim()).timeout(
          const Duration(seconds: 10),
        );
      } catch (_) {
        // Keep the exact episode match visible with an explicit unavailable
        // state instead of hiding a source whose video resolver is slow.
      }

      resolved.add(
        _ResolvedSource(
          source: source,
          searchResult: searchResult,
          details: details,
          episode: episode,
          confidence: titleMatch.score,
          matchedYear: titleMatch.candidateYear,
          videos: videos,
        ),
      );
    }
    return resolved;
  }

  List<String> _searchTitles(
    Source source,
    AnilistMediaDetail? metadata,
  ) {
    final isJapaneseExtension =
        (source.lang ?? '').toLowerCase().startsWith('ja');
    final titles = <String>[
      if (isJapaneseExtension) widget.media.titleNative ?? '',
      if (isJapaneseExtension) widget.media.titleRomaji ?? '',
      if (!isJapaneseExtension) widget.media.displayTitle,
      widget.media.titleEnglish ?? '',
      widget.media.titleRomaji ?? '',
      widget.media.titleNative ?? '',
      ...widget.media.synonyms,
      ...?metadata?.base.synonyms,
    ];
    final unique = <String>{};
    for (final title in titles) {
      final trimmed = title.trim();
      if (trimmed.isNotEmpty) unique.add(trimmed);
      if (unique.length == 4) break;
    }
    return unique.toList(growable: false);
  }

  Future<List<Video>> _loadVideos(Source source, String episodeUrl) async {
    if (kIsWeb) {
      if (source.id == null || !RemoteClient.instance.isConfigured) {
        return [];
      }
      final data = await RemoteClient.instance.get(
        '/api/sources/${source.id}/videos',
        params: {'url': episodeUrl},
      );
      final rawVideos = (data['videos'] as List?)
          ?.whereType<Map>()
          .map((video) => Video.fromJson(video.cast<String, dynamic>()))
          .toList(growable: false);
      return (rawVideos ?? [])
          .where((video) => video.url.trim().isNotEmpty)
          .toList(growable: false);
    }
    final videos = await getIsolateService.get<List<Video>>(
      url: episodeUrl,
      source: source,
      serviceType: 'getVideoList',
    );
    return videos
        .where((video) => video.url.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _sortMatches() {
    _matches.sort((a, b) {
      final confidence = b.confidence.compareTo(a.confidence);
      if (confidence != 0) return confidence;
      final playable = b.videos.isNotEmpty.compareTo(a.videos.isNotEmpty);
      if (playable != 0) return playable;
      return (a.source.name ?? '').compareTo(b.source.name ?? '');
    });
  }

  Future<void> _play(_ResolvedSource match) async {
    if (_launchingPlayer || match.videos.isEmpty) return;
    setState(() => _launchingPlayer = true);

    Id? mangaId;
    Id? chapterId;
    try {
      final sourceName = match.source.name ?? '';
      final series = match.details;
      final manga = Manga(
        source: sourceName,
        sourceId: match.source.id,
        lang: match.source.lang ?? '',
        name: (series.name?.trim().isNotEmpty ?? false)
            ? series.name
            : (match.searchResult.name?.trim().isNotEmpty ?? false)
            ? match.searchResult.name
            : widget.media.displayTitle,
        link: series.link ?? match.searchResult.link ?? '',
        imageUrl: series.imageUrl ?? match.searchResult.imageUrl,
        description: series.description ?? match.searchResult.description ?? '',
        author: series.author ?? match.searchResult.author,
        artist: series.artist ?? match.searchResult.artist,
        genre: series.genre ?? match.searchResult.genre ?? const [],
        status: series.status ?? match.searchResult.status ?? Status.unknown,
        favorite: false,
        isManga: false,
        itemType: ItemType.anime,
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      );
      final sourceChapter = match.episode;

      await isar.writeTxn(() async {
        mangaId = await isar.mangas.put(manga);
        final chapter = Chapter(
          mangaId: mangaId,
          name: sourceChapter.name ?? 'EP ${widget.episode.episodeNumber}',
          url: sourceChapter.url ?? '',
          dateUpload: sourceChapter.dateUpload ?? '',
          scanlator: sourceChapter.scanlator ?? '',
          isFiller: sourceChapter.isFiller ?? false,
          thumbnailUrl: sourceChapter.thumbnailUrl,
          description: sourceChapter.description,
          downloadSize: sourceChapter.downloadSize,
          duration: sourceChapter.duration,
        );
        chapterId = await isar.chapters.put(chapter);
        chapter.manga.value = manga;
        await chapter.manga.save();
      });

      if (chapterId != null && mounted) {
        await context.push('/animePlayerView', extra: chapterId);
      }
    } finally {
      if (mangaId != null || chapterId != null) {
        await isar.writeTxn(() async {
          if (mangaId != null) {
            await isar.historys.filter().mangaIdEqualTo(mangaId!).deleteAll();
          }
          if (chapterId != null) await isar.chapters.delete(chapterId!);
          if (mangaId != null) await isar.mangas.delete(mangaId!);
        });
      }
      if (mounted) setState(() => _launchingPlayer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = _sourceCount == 0
        ? null
        : (_scanned / _sourceCount).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche des sources'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => Transform.scale(
                      scale: 0.96 + (_pulse.value * 0.09),
                      child: child,
                    ),
                    child: Container(
                      width: 94,
                      height: 94,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_loading)
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  cs.primary.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          Icon(
                            _loading
                                ? Icons.travel_explore_rounded
                                : _matches.isEmpty
                                ? Icons.search_off_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 34,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.media.displayTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EP ${widget.episode.episodeNumber} · ${widget.episode.displayTitle}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _phase,
                      key: ValueKey(_phase),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _loading ? progress : 1,
                      minHeight: 4,
                    ),
                  ),
                  if (_sourceCount > 0) ...[
                    const SizedBox(height: 7),
                    Text(
                      '$_scanned / $_sourceCount extensions · '
                      '${_matches.length} épisode(s) confirmé(s)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    Text(
                      'Épisodes trouvés',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Classés par correspondance',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _matches.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _matches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _SourceMatchCard(
                        match: _matches[index],
                        launching: _launchingPlayer,
                        onPlay: () => _play(_matches[index]),
                      ),
                    )
                  : _buildEmptyState(cs, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, ThemeData theme) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Les résultats bruts des extensions restent masqués. '
            'La page vérifie le titre, le format et le numéro d’épisode avant '
            'd’afficher une source.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sourceCount == 0
                  ? Icons.extension_off_rounded
                  : Icons.search_off_rounded,
              size: 38,
              color: cs.onSurface.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 12),
            Text(
              _sourceCount == 0
                  ? 'Aucune extension anime active'
                  : 'Aucune source fiable pour cet épisode',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _sourceCount == 0
                  ? 'Installe ou active une extension anime, puis relance la recherche.'
                  : _failedSources > 0
                  ? '$_failedSources extension(s) n’ont pas répondu. '
                      'Vérifie aussi les variantes de titre et le numéro d’épisode.'
                  : 'Aucun résultat ne correspond assez au titre et à l’épisode '
                      'sélectionnés. Essaie une autre extension anime.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
                height: 1.45,
              ),
            ),
            if (_sourceCount > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loading ? null : _resolve,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResolvedSource {
  final Source source;
  final MManga searchResult;
  final MManga details;
  final MChapter episode;
  final int confidence;
  final int? matchedYear;
  final List<Video> videos;

  const _ResolvedSource({
    required this.source,
    required this.searchResult,
    required this.details,
    required this.episode,
    required this.confidence,
    required this.matchedYear,
    required this.videos,
  });
}

class _SourceMatchCard extends StatelessWidget {
  final _ResolvedSource match;
  final bool launching;
  final VoidCallback onPlay;

  const _SourceMatchCard({
    required this.match,
    required this.launching,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sourceLang = match.source.lang?.trim() ?? '';
    final langName = sourceLang.isEmpty
        ? 'Langue non indiquée'
        : completeLanguageName(sourceLang);
    final hasVideos = match.videos.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.extension_rounded,
                    size: 19,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.source.name ?? 'Extension',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$langName · ${match.details.name ?? match.searchResult.name ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    match.confidence >= 95 ? 'Exact' : 'Probable',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              match.episode.name ?? 'Épisode confirmé',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (match.matchedYear != null) ...[
              const SizedBox(height: 3),
              Text(
                'Année détectée dans le titre de la source : ${match.matchedYear}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (hasVideos)
              ...match.videos.map(
                (video) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _VideoMetadataLine(video: video, colorScheme: cs),
                ),
              )
            else
              Text(
                'Épisode trouvé, mais aucun flux vidéo n’a été renvoyé.',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.58),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: hasVideos && !launching ? onPlay : null,
                icon: launching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 19),
                label: Text(hasVideos ? 'Lire avec cette extension' : 'Flux indisponible'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoMetadataLine extends StatelessWidget {
  final Video video;
  final ColorScheme colorScheme;

  const _VideoMetadataLine({
    required this.video,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final audio = _trackLabels(video.audios);
    final subtitles = _trackLabels(video.subtitles);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.quality.trim().isEmpty ? 'Qualité non indiquée' : video.quality,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Audio : ${audio.isEmpty ? 'non indiqué' : audio.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          Text(
            'Sous-titres : ${subtitles.isEmpty ? 'aucun indiqué' : subtitles.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _trackLabels(List<Track>? tracks) => (tracks ?? [])
      .map((track) => track.label?.trim() ?? '')
      .where((label) => label.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
