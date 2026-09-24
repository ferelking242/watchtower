import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';

class TmdbMediaDetailScreen extends StatefulWidget {
  final TmdbMedia media;
  final String heroTag;

  const TmdbMediaDetailScreen({
    super.key,
    required this.media,
    this.heroTag = '',
  });

  @override
  State<TmdbMediaDetailScreen> createState() => _TmdbMediaDetailScreenState();
}

class _TmdbMediaDetailScreenState extends State<TmdbMediaDetailScreen> {
  late Future<TmdbMediaDetails> _details;
  bool _isFavorite = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _details = fetchTmdbMediaDetails(widget.media);
  }

  void _retry() {
    setState(() => _details = fetchTmdbMediaDetails(widget.media));
  }

  String get _heroTag =>
      widget.heroTag.isEmpty ? tmdbHeroTag(widget.media) : widget.heroTag;

  Future<void> _shareMedia() {
    return Share.share(
      '${widget.media.displayTitle}\n'
      'https://www.themoviedb.org/${widget.media.mediaType}/${widget.media.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: FutureBuilder<TmdbMediaDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DetailSkeleton();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _DetailError(error: snapshot.error, onRetry: _retry);
          }
          return _DetailContent(
            media: widget.media,
            details: snapshot.data!,
            heroTag: _heroTag,
            isFavorite: _isFavorite,
            tabIndex: _tabIndex,
            onTabChanged: (index) => setState(() => _tabIndex = index),
            onFavoriteChanged: () => setState(() => _isFavorite = !_isFavorite),
            onShare: _shareMedia,
            onDownload: () =>
                context.push('/flixSearch', extra: widget.media.displayTitle),
          );
        },
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  final TmdbMedia media;
  final TmdbMediaDetails details;
  final String heroTag;
  final bool isFavorite;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onFavoriteChanged;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  const _DetailContent({
    required this.media,
    required this.details,
    required this.heroTag,
    required this.isFavorite,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onFavoriteChanged,
    required this.onShare,
    required this.onDownload,
  });

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  late final ScrollController _scrollController;
  bool _showCollapsedTitle = false;

  TmdbMedia get media => widget.media;
  TmdbMediaDetails get details => widget.details;
  bool get isFavorite => widget.isFavorite;
  int get tabIndex => widget.tabIndex;
  ValueChanged<int> get onTabChanged => widget.onTabChanged;
  VoidCallback get onFavoriteChanged => widget.onFavoriteChanged;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 220;
    if (shouldShow != _showCollapsedTitle && mounted) {
      setState(() => _showCollapsedTitle = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final expandedHeight = width < 700 ? 330.0 : 430.0;
    final double posterWidth = (width * .32).clamp(118.0, 190.0).toDouble();
    final date = media.releaseDate ?? media.firstAirDate;
    final genreNames = <String>{};
    genreNames.addAll(
      details.genres
          .map((genre) => genre.name.trim())
          .where((genre) => genre.isNotEmpty),
    );
    genreNames.addAll(
      (media.mediaType == 'movie'
              ? tmdbMovieGenreNames(media.genreIds)
              : tmdbTvGenreNames(media.genreIds))
          .where((genre) => genre.isNotEmpty),
    );
    final genres = genreNames.toList(growable: false);
    final backdrops = <String>[
      if (media.backdropPath != null) media.backdropPath!,
      ...details.backdropPaths.where((path) => path != media.backdropPath),
    ];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: expandedHeight,
          pinned: true,
          toolbarHeight: 64,
          backgroundColor: const Color(0xFF0B0B11),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () => context.pop(),
            icon: const Icon(Broken.arrow_left, color: Colors.white),
          ),
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .18),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _showCollapsedTitle
                ? Text(
                    media.displayTitle,
                    key: const ValueKey('collapsed-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('empty-title'),
                    width: 1,
                    height: 1,
                  ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: _BackdropCarousel(
              paths: backdrops,
              videos: details.videos,
              fallback: media.backdropPath,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: widget.heroTag,
                      child: SizedBox(
                        width: posterWidth,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: media.bestCover == null
                                ? const _PosterPlaceholder()
                                : ExtendedImage.network(
                                    media.bestCover!,
                                    fit: BoxFit.cover,
                                    cache: true,
                                    loadStateChanged: (state) {
                                      if (state.extendedImageLoadState ==
                                          LoadState.completed) {
                                        return null;
                                      }
                                      return const AppShimmerBlock();
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.displayTitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (details.tagline?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Text(
                                details.tagline!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontStyle: FontStyle.italic,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 13),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                if (media.voteAverage != null)
                                  _InfoChip(
                                    icon: Broken.star_1,
                                    label: media.voteAverage!.toStringAsFixed(
                                      1,
                                    ),
                                  ),
                                if (date?.isNotEmpty == true)
                                  _InfoChip(
                                    icon: Broken.calendar_1,
                                    label: date!.split('-').first,
                                  ),
                                if (media.originalLanguage?.isNotEmpty == true)
                                  _InfoChip(
                                    label: _shortLanguage(
                                      media.originalLanguage!,
                                    ),
                                  ),
                                if (media.voteCount != null)
                                  _InfoChip(
                                    icon: Broken.message_text,
                                    label: '${media.voteCount} avis',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: genres
                                  .map((genre) => _InfoChip(label: genre))
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Voir les statistiques',
                      onPressed: () => _showDetailsSheet(context),
                      icon: const Icon(
                        Broken.arrow_right_3,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            '/flixSearch',
                            extra: media.displayTitle,
                          ),
                          icon: const Icon(Broken.play, size: 20),
                          label: const Text('Regarder'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: widget.onDownload,
                          icon: const Icon(Broken.document_download, size: 20),
                          label: const Text('Télécharger'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: .07,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: IconButton(
                        onPressed: onFavoriteChanged,
                        tooltip: isFavorite
                            ? 'Retirer de ma liste'
                            : 'Ajouter à ma liste',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: .10),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isFavorite ? Broken.tick_circle : Broken.add_circle,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                _ExpandableSynopsis(
                  text: media.overview?.isNotEmpty == true
                      ? media.overview!
                      : 'Aucun synopsis disponible.',
                ),
                const SizedBox(height: 25),
                _CastSection(media: media, cast: details.cast),
                if (media.mediaType == 'tv' && details.seasons.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SeasonsSummary(seasons: details.seasons),
                ],
                const SizedBox(height: 28),
                _DetailTabs(
                  index: tabIndex,
                  isTv: media.mediaType == 'tv',
                  onChanged: onTabChanged,
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(tabIndex),
                    child: _TabBody(
                      index: tabIndex,
                      media: media,
                      details: details,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141D),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _DetailsSection(media: media, details: details),
        ),
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  final int index;
  final TmdbMedia media;
  final TmdbMediaDetails details;

  const _TabBody({
    required this.index,
    required this.media,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    if (index == 0) {
      return _MediaSection(details: details);
    }
    if (index == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecommendationsSection(items: details.recommendations),
          const SizedBox(height: 28),
          _RecommendationsSection(
            title: 'Similaires',
            emptyMessage: 'Aucun titre similaire disponible.',
            items: details.similar,
          ),
          const SizedBox(height: 28),
          _ProvidersSection(providers: details.watchProviders),
        ],
      );
    }
    return media.mediaType == 'tv'
        ? _EpisodesSection(media: media, seasons: details.seasons)
        : _DetailsSection(media: media, details: details);
  }
}

class _DetailTabs extends StatelessWidget {
  final int index;
  final bool isTv;
  final ValueChanged<int> onChanged;

  const _DetailTabs({
    required this.index,
    required this.isTv,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Média', 'Recommandations', isTv ? 'Épisodes' : 'Détails'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: index == i
                        ? Colors.white.withValues(alpha: .14)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: index == i ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: index == i
                          ? FontWeight.w800
                          : FontWeight.w500,
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

class _ExpandableSynopsis extends StatefulWidget {
  final String text;

  const _ExpandableSynopsis({required this.text});

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.55,
              fontSize: 15,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _expanded ? 'Réduire' : 'Lire plus',
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: AnimatedRotation(
                turns: _expanded ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Broken.arrow_down_1, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final TmdbMediaDetails details;

  const _MediaSection({required this.details});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Wallpapers',
          trailing: details.backdropPaths.length > 3
              ? TextButton(
                  onPressed: () => context.push(
                    '/flixWallpapers',
                    extra: details.backdropPaths,
                  ),
                  child: Text('Tout  ›'),
                )
              : null,
          child: details.backdropPaths.isEmpty
              ? const _EmptySection(message: 'Aucun wallpaper disponible.')
              : SizedBox(
                  height: 154,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: details.backdropPaths.take(3).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) =>
                        _WallpaperCard(path: details.backdropPaths[index]),
                  ),
                ),
        ),
        const SizedBox(height: 28),
        _VideosSection(videos: details.videos),
      ],
    );
  }
}

class _WallpaperCard extends StatelessWidget {
  final String path;

  const _WallpaperCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ExtendedImage.network(
        'https://image.tmdb.org/t/p/w780$path',
        width: 238,
        height: 142,
        fit: BoxFit.cover,
        cache: true,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
            return null;
          }
          return const AppShimmerBlock();
        },
      ),
    );
  }
}

class TmdbWallpaperGalleryScreen extends StatelessWidget {
  final List<String> paths;

  const TmdbWallpaperGalleryScreen({super.key, required this.paths});

  @override
  Widget build(BuildContext context) {
    final rows = (paths.length / 2).ceil();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        title: Text('Wallpapers (${paths.length})'),
        backgroundColor: const Color(0xFF0B0B11),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: paths.isEmpty
          ? const _EmptySection(message: 'Aucun wallpaper disponible.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              itemCount: rows,
              itemBuilder: (_, rowIndex) {
                final firstIndex = rowIndex * 2;
                final secondIndex = firstIndex + 1;
                final first = paths[firstIndex];
                final second = secondIndex < paths.length
                    ? paths[secondIndex]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _WallpaperGalleryTile(
                            path: first,
                            seed: firstIndex,
                          ),
                        ),
                        if (second != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WallpaperGalleryTile(
                              path: second,
                              seed: secondIndex,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _WallpaperGalleryTile extends StatelessWidget {
  final String path;
  final int seed;

  const _WallpaperGalleryTile({required this.path, required this.seed});

  @override
  Widget build(BuildContext context) {
    final aspectRatio = seed.isEven ? 1.42 : 0.86;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ExtendedImage.network(
          'https://image.tmdb.org/t/p/w780$path',
          fit: BoxFit.cover,
          cache: true,
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.completed) {
              return null;
            }
            return const AppShimmerBlock(radius: 0);
          },
        ),
      ),
    );
  }
}

class _SeasonsSummary extends StatelessWidget {
  final List<TmdbSeason> seasons;

  const _SeasonsSummary({required this.seasons});

  @override
  Widget build(BuildContext context) {
    final visibleSeasons = seasons
        .where((season) => season.seasonNumber > 0)
        .toList(growable: false);
    if (visibleSeasons.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Saisons',
      child: SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: visibleSeasons.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final season = visibleSeasons[index];
            return SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 112,
                      height: 126,
                      child: season.posterUrl == null
                          ? const _PosterPlaceholder(icon: Broken.video)
                          : ExtendedImage.network(
                              season.posterUrl!,
                              fit: BoxFit.cover,
                              cache: true,
                              loadStateChanged: (state) {
                                if (state.extendedImageLoadState ==
                                    LoadState.completed) {
                                  return null;
                                }
                                return const AppShimmerBlock();
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    season.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${season.episodeCount} épisodes',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CastSection extends StatelessWidget {
  final TmdbMedia media;
  final List<TmdbCastMember> cast;

  const _CastSection({required this.media, required this.cast});

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty)
      return const _EmptySection(message: 'Acteurs indisponibles.');
    return _Section(
      title: 'Acteurs',
      trailing: TextButton(
        onPressed: () => context.push('/flixCastCrew', extra: media),
        child: const Text('Voir tout'),
      ),
      child: SizedBox(
        height: 174,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cast.take(12).length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final person = cast[index];
            return GestureDetector(
              onTap: () => context.push(
                '/flixPerson',
                extra: TmdbPersonRef(
                  id: person.id,
                  name: person.name,
                  profilePath: person.profilePath,
                ),
              ),
              child: SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 92,
                        height: 112,
                        child: person.profileUrl == null
                            ? const _PosterPlaceholder(icon: Broken.user)
                            : ExtendedImage.network(
                                person.profileUrl!,
                                fit: BoxFit.cover,
                                cache: true,
                                loadStateChanged: (state) {
                                  if (state.extendedImageLoadState ==
                                      LoadState.completed) {
                                    return null;
                                  }
                                  return const AppShimmerBlock();
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      person.character,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodesSection extends StatefulWidget {
  final TmdbMedia media;
  final List<TmdbSeason> seasons;

  const _EpisodesSection({required this.media, required this.seasons});

  @override
  State<_EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<_EpisodesSection> {
  late final List<TmdbSeason> _seasons;
  late int _selectedSeason;
  late Future<List<TmdbEpisode>> _episodes;

  @override
  void initState() {
    super.initState();
    _seasons = widget.seasons
        .where((season) => season.seasonNumber > 0)
        .toList(growable: false);
    _selectedSeason = _seasons.isEmpty ? 1 : _seasons.first.seasonNumber;
    _episodes = _loadEpisodes();
  }

  Future<List<TmdbEpisode>> _loadEpisodes() {
    return fetchTmdbSeasonEpisodes(widget.media, _selectedSeason);
  }

  void _selectSeason(int seasonNumber) {
    if (seasonNumber == _selectedSeason) return;
    setState(() {
      _selectedSeason = seasonNumber;
      _episodes = _loadEpisodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seasons.isEmpty) {
      return const _EmptySection(message: 'Aucun épisode disponible.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Épisodes',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final season in _seasons) ...[
                  ChoiceChip(
                    selected: season.seasonNumber == _selectedSeason,
                    label: Text(season.name),
                    onSelected: (_) => _selectSeason(season.seasonNumber),
                    avatar: const Icon(Broken.video, size: 15),
                    labelStyle: TextStyle(
                      color: season.seasonNumber == _selectedSeason
                          ? Colors.white
                          : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    selectedColor: Colors.white.withValues(alpha: .18),
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<TmdbEpisode>>(
          future: _episodes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Column(
                children: [
                  SizedBox(height: 120, child: AppShimmerBlock()),
                  SizedBox(height: 10),
                  SizedBox(height: 120, child: AppShimmerBlock()),
                ],
              );
            }
            if (snapshot.hasError) {
              return const _EmptySection(
                message: 'Impossible de charger les épisodes.',
              );
            }
            final episodes = snapshot.data ?? const <TmdbEpisode>[];
            if (episodes.isEmpty) {
              return const _EmptySection(message: 'Aucun épisode disponible.');
            }
            return Column(
              children: episodes
                  .map(
                    (episode) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EpisodeCard(episode: episode),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final TmdbEpisode episode;

  const _EpisodeCard({required this.episode});

  @override
  Widget build(BuildContext context) {
    final date = episode.airDate?.split('-').take(2).join('/');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 142,
              height: 84,
              child: episode.stillUrl == null
                  ? const _PosterPlaceholder(icon: Broken.video)
                  : ExtendedImage.network(
                      episode.stillUrl!,
                      fit: BoxFit.cover,
                      cache: true,
                      loadStateChanged: (state) {
                        if (state.extendedImageLoadState ==
                            LoadState.completed) {
                          return null;
                        }
                        return const AppShimmerBlock(radius: 0);
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E${episode.episodeNumber} · ${episode.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                if (episode.overview?.trim().isNotEmpty == true)
                  Text(
                    episode.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      height: 1.35,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 9,
                  runSpacing: 4,
                  children: [
                    if (episode.voteAverage != null)
                      _EpisodeMeta(
                        icon: Broken.star_1,
                        label: episode.voteAverage!.toStringAsFixed(1),
                      ),
                    if (date?.isNotEmpty == true)
                      _EpisodeMeta(icon: Broken.calendar_1, label: date!),
                    if (episode.runtime != null && episode.runtime! > 0)
                      _EpisodeMeta(
                        icon: Broken.clock,
                        label: '${episode.runtime} min',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EpisodeMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _VideosSection extends StatelessWidget {
  final List<TmdbVideo> videos;

  const _VideosSection({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const _EmptySection(message: 'Aucune bande-annonce disponible.');
    }
    return _Section(
      title: 'Trailers et vidéos',
      child: SizedBox(
        height: 166,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: videos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final video = videos[index];
            return SizedBox(
              width: 246,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => launchUrl(
                  Uri.parse(video.watchUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ExtendedImage.network(
                        'https://img.youtube.com/vi/${video.key}/hqdefault.jpg',
                        fit: BoxFit.cover,
                        cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.completed) {
                            return null;
                          }
                          return const AppShimmerBlock();
                        },
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Broken.video_play,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 9,
                        child: Text(
                          video.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final TmdbMedia media;
  final TmdbMediaDetails details;

  const _DetailsSection({required this.media, required this.details});

  @override
  Widget build(BuildContext context) {
    final type = media.mediaType == 'movie' ? 'Film' : 'Série';
    final status = _formatTmdbStatus(details.status);
    final rows = <MapEntry<String, String>>[
      MapEntry('Titre', media.displayTitle),
      if (details.originalTitle?.isNotEmpty == true)
        MapEntry('Titre original', details.originalTitle!),
      if (media.mediaType.isNotEmpty) MapEntry('Type', type),
      if (media.releaseDate?.isNotEmpty == true)
        MapEntry('Date de sortie', media.releaseDate!),
      if (media.firstAirDate?.isNotEmpty == true)
        MapEntry('Première diffusion', media.firstAirDate!),
      if (details.lastAirDate?.isNotEmpty == true)
        MapEntry('Dernier épisode', details.lastAirDate!),
      if (details.type?.isNotEmpty == true) MapEntry('Format', details.type!),
      if (details.status?.isNotEmpty == true) MapEntry('Statut', status),
      if (details.runtime != null && details.runtime! > 0)
        MapEntry('Durée', '${details.runtime} min'),
      if (details.episodeRunTimes.isNotEmpty)
        MapEntry('Durée épisode', '${details.episodeRunTimes.join('–')} min'),
      if (details.numberOfSeasons != null)
        MapEntry('Saisons', '${details.numberOfSeasons}'),
      if (details.numberOfEpisodes != null)
        MapEntry('Épisodes', '${details.numberOfEpisodes}'),
      if (media.originalLanguage?.isNotEmpty == true)
        MapEntry('Langue originale', media.originalLanguage!.toUpperCase()),
      if (details.spokenLanguages.isNotEmpty)
        MapEntry('Langues parlées', details.spokenLanguages.join(', ')),
      if (details.originCountries.isNotEmpty)
        MapEntry('Pays d’origine', details.originCountries.join(', ')),
      if (media.voteCount != null) MapEntry('Votes TMDB', '${media.voteCount}'),
      if (media.voteAverage != null)
        MapEntry('Note TMDB', media.voteAverage!.toStringAsFixed(1)),
      if (media.popularity != null || details.popularity != null)
        MapEntry(
          'Popularité',
          (details.popularity ?? media.popularity)!.toStringAsFixed(2),
        ),
      if (details.budget != null && details.budget! > 0)
        MapEntry('Budget', _formatMoney(details.budget!)),
      if (details.revenue != null && details.revenue! > 0)
        MapEntry('Recettes', _formatMoney(details.revenue!)),
      if (details.inProduction?.isNotEmpty == true)
        MapEntry('En production', details.inProduction!),
      if (details.homepage?.isNotEmpty == true)
        MapEntry('Site officiel', details.homepage!),
      if (details.imdbId?.isNotEmpty == true) MapEntry('IMDb', details.imdbId!),
      if (details.productionCountries.isNotEmpty)
        MapEntry('Pays', details.productionCountries.join(', ')),
      if (details.productionCompanies.isNotEmpty)
        MapEntry('Production', details.productionCompanies.join(', ')),
      if (details.networks.isNotEmpty)
        MapEntry('Réseaux', details.networks.join(', ')),
      if (details.createdBy.isNotEmpty)
        MapEntry('Créé par', details.createdBy.join(', ')),
    ];
    if (rows.isEmpty) {
      return const _EmptySection(message: 'Détails indisponibles.');
    }
    return _Section(
      title: 'Informations',
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.key,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatTmdbStatus(String? value) {
  return switch (value) {
    'Released' => 'Sorti',
    'Returning Series' => 'En cours',
    'Ended' => 'Terminée',
    'Canceled' || 'Cancelled' => 'Annulée',
    'In Production' => 'En production',
    'Planned' => 'Prévue',
    _ => value ?? '—',
  };
}

String _formatMoney(int value) {
  if (value >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(1)} M';
  }
  return '\$${value.toString()}';
}

class _RecommendationsSection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<TmdbMedia> items;

  const _RecommendationsSection({
    required this.items,
    this.title = 'Recommandations',
    this.emptyMessage = 'Aucune recommandation disponible.',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptySection(message: emptyMessage);
    }
    return _Section(
      title: title,
      child: SizedBox(
        height: 204,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 11),
          itemBuilder: (_, index) {
            final media = items[index];
            final source = 'recommendation-$index';
            return PosterCard(
              item: ContentItem.fromTmdb(media),
              heroTag: tmdbHeroTag(media, source),
              width: 126,
              onTap: () => pushTmdbMediaDetail(context, media, source: source),
            );
          },
        ),
      ),
    );
  }
}

class _ProvidersSection extends StatelessWidget {
  final List<TmdbWatchProvider> providers;

  const _ProvidersSection({required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Où regarder',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: providers
            .map(
              (provider) => Tooltip(
                message: provider.name,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ExtendedImage.network(
                    provider.logoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cache: true,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 11),
        child,
      ],
    );
  }
}

class _BackdropCarousel extends StatefulWidget {
  final List<String> paths;
  final List<TmdbVideo> videos;
  final String? fallback;

  const _BackdropCarousel({
    required this.paths,
    required this.videos,
    required this.fallback,
  });

  @override
  State<_BackdropCarousel> createState() => _BackdropCarouselState();
}

class _BackdropCarouselState extends State<_BackdropCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _itemCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  int get _itemCount {
    final paths = widget.paths.isEmpty && widget.fallback != null
        ? <String>[widget.fallback!]
        : widget.paths;
    return paths.length + (widget.videos.isEmpty ? 0 : 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths.isEmpty && widget.fallback != null
        ? <String>[widget.fallback!]
        : widget.paths;
    if (paths.isEmpty) {
      if (widget.videos.isEmpty) {
        return const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF181822)),
        );
      }
    }
    final itemCount = paths.length + (widget.videos.isEmpty ? 0 : 1);
    if (itemCount == 0) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF181822)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          pageSnapping: true,
          allowImplicitScrolling: true,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: itemCount,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (_, index) {
            if (widget.videos.isNotEmpty && index == 0) {
              return _TrailerHeroSlide(video: widget.videos.first);
            }
            final pathIndex = index - (widget.videos.isEmpty ? 0 : 1);
            return ExtendedImage.network(
              'https://image.tmdb.org/t/p/w1280${paths[pathIndex]}',
              fit: BoxFit.cover,
              cache: true,
              loadStateChanged: (state) {
                if (state.extendedImageLoadState == LoadState.completed) {
                  return null;
                }
                return const AppShimmerBlock();
              },
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Color(0xFF0B0B11)],
              stops: [.2, 1],
            ),
          ),
        ),
        if (itemCount > 1)
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                for (var i = 0; i < itemCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsetsDirectional.only(start: 5),
                    width: i == _index ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == _index ? .95 : .45,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrailerHeroSlide extends StatelessWidget {
  final TmdbVideo video;

  const _TrailerHeroSlide({required this.video});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(video.watchUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExtendedImage.network(
            'https://img.youtube.com/vi/${video.key}/maxresdefault.jpg',
            fit: BoxFit.cover,
            cache: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.completed) {
                return null;
              }
              return const AppShimmerBlock(radius: 0);
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          const Center(
            child: Icon(Broken.video_play, color: Colors.white, size: 54),
          ),
          Positioned(
            left: 18,
            bottom: 28,
            right: 18,
            child: Text(
              'Trailer · ${video.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _InfoChip({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.amber, size: 15),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _shortLanguage(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized.isEmpty) return '';
  if (normalized.length == 1) return normalized.toUpperCase();
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

class _PosterPlaceholder extends StatelessWidget {
  final IconData icon;

  const _PosterPlaceholder({this.icon = Broken.video});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF272733),
      child: Center(child: Icon(icon, color: Colors.white38, size: 34)),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: Color(0xFF0B0B11),
          leading: BackButton(color: Colors.white),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 118, height: 176, child: AppShimmerBlock()),
                  SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(height: 126, child: AppShimmerBlock()),
                  ),
                ],
              ),
              SizedBox(height: 18),
              SizedBox(height: 88, child: AppShimmerBlock()),
              SizedBox(height: 18),
              SizedBox(height: 42, child: AppShimmerBlock()),
              SizedBox(height: 22),
              SizedBox(height: 170, child: AppShimmerBlock()),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _DetailError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Broken.wifi, color: Colors.white54, size: 44),
            const SizedBox(height: 14),
            const Text(
              'Impossible de charger cette fiche',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Réessayez lorsque la connexion sera disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
