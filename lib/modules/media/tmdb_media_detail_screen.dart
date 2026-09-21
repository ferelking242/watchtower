import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';

class TmdbMediaDetailScreen extends StatefulWidget {
  final TmdbMedia media;

  const TmdbMediaDetailScreen({super.key, required this.media});

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
            return _DetailError(
              error: snapshot.error,
              onRetry: _retry,
            );
          }
          return _DetailContent(
            media: widget.media,
            details: snapshot.data!,
            isFavorite: _isFavorite,
            tabIndex: _tabIndex,
            onTabChanged: (index) => setState(() => _tabIndex = index),
            onFavoriteChanged: () =>
                setState(() => _isFavorite = !_isFavorite),
            onShare: _shareMedia,
            onDownload: () => context.push(
              '/flixSearch',
              extra: widget.media.displayTitle,
            ),
          );
        },
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  final TmdbMedia media;
  final TmdbMediaDetails details;
  final bool isFavorite;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onFavoriteChanged;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  const _DetailContent({
    required this.media,
    required this.details,
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
    final shouldShow = _scrollController.hasClients &&
        _scrollController.offset > 190;
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
    final double posterWidth = (width * .32).clamp(118.0, 190.0).toDouble();
    final date = media.releaseDate ?? media.firstAirDate;
    final genres = details.genres.isNotEmpty
        ? details.genres.map((genre) => genre.name).toList(growable: false)
        : (media.mediaType == 'movie'
              ? tmdbMovieGenreNames(media.genreIds)
              : tmdbTvGenreNames(media.genreIds));
    final backdrops = <String>[
      if (media.backdropPath != null) media.backdropPath!,
      ...details.backdropPaths.where((path) => path != media.backdropPath),
    ];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: width < 700 ? 330 : 430,
          pinned: true,
          backgroundColor: const Color(0xFF0B0B11),
          leading: const BackButton(color: Colors.white),
          title: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _showCollapsedTitle ? 1 : 0,
            child: Text(
              media.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _BackdropCarousel(
              paths: backdrops,
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
                      tag: 'tmdb-${media.mediaType}-${media.id}',
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
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                if (media.voteAverage != null)
                                  _InfoChip(
                                    icon: Icons.star_rounded,
                                    label: media.voteAverage!.toStringAsFixed(
                                      1,
                                    ),
                                  ),
                                if (date?.isNotEmpty == true)
                                  _InfoChip(
                                    icon: Icons.calendar_month_rounded,
                                    label: date!.split('-').first,
                                  ),
                                if (media.originalLanguage?.isNotEmpty ==
                                    true)
                                  _InfoChip(
                                    label: media.originalLanguage!
                                        .toUpperCase(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: genres.map((genre) => _InfoChip(label: genre)).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                         onPressed: () => context.push(
                           '/flixSearch',
                           extra: media.displayTitle,
                         ),
                        icon: const Icon(Icons.play_arrow_rounded),
                         label: const Text('Watch now'),
                      ),
                    ),
                    const SizedBox(width: 9),
                     Expanded(
                       child: FilledButton.tonalIcon(
                         onPressed: widget.onDownload,
                         icon: const Icon(Icons.download_rounded),
                         label: const Text('Download'),
                       ),
                     ),
                     const SizedBox(width: 9),
                    IconButton.filledTonal(
                      onPressed: onFavoriteChanged,
                      tooltip: 'Ma liste',
                      icon: Icon(
                        isFavorite
                            ? Icons.check_rounded
                            : Icons.add_rounded,
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
                const SizedBox(height: 26),
                _DetailTabs(index: tabIndex, onChanged: onTabChanged),
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
    if (index == 1) {
      return _VideosSection(videos: details.videos);
    }
    if (index == 2) {
      return _DetailsSection(media: media, details: details);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CastSection(media: media, cast: details.cast),
        const SizedBox(height: 28),
        _RecommendationsSection(items: details.recommendations),
        const SizedBox(height: 28),
        _ProvidersSection(providers: details.watchProviders),
      ],
    );
  }
}

class _DetailTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _DetailTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Distribution', 'Bandes-annonces', 'Détails'];
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
                    color: index == i ? Colors.white.withValues(alpha: .14) : null,
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
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
    if (cast.isEmpty) return const _EmptySection(message: 'Distribution indisponible.');
    return _Section(
      title: 'Distribution',
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
                            ? const _PosterPlaceholder(icon: Icons.person)
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

class _VideosSection extends StatelessWidget {
  final List<TmdbVideo> videos;

  const _VideosSection({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const _EmptySection(message: 'Aucune bande-annonce disponible.');
    }
    return _Section(
      title: 'Bandes-annonces et vidéos',
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
                          Icons.play_circle_fill_rounded,
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
      if (media.mediaType.isNotEmpty)
        MapEntry('Type', type),
      if (media.releaseDate?.isNotEmpty == true)
        MapEntry('Date de sortie', media.releaseDate!),
      if (media.firstAirDate?.isNotEmpty == true)
        MapEntry('Première diffusion', media.firstAirDate!),
      if (details.lastAirDate?.isNotEmpty == true)
        MapEntry('Dernier épisode', details.lastAirDate!),
      if (details.type?.isNotEmpty == true) MapEntry('Format', details.type!),
      if (details.status?.isNotEmpty == true)
        MapEntry('Statut', status),
      if (details.runtime != null && details.runtime! > 0)
        MapEntry('Durée', '${details.runtime} min'),
      if (details.episodeRunTimes.isNotEmpty)
        MapEntry(
          'Durée épisode',
          '${details.episodeRunTimes.join('–')} min',
        ),
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
      if (media.voteCount != null)
        MapEntry('Votes TMDB', '${media.voteCount}'),
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
      if (details.imdbId?.isNotEmpty == true)
        MapEntry('IMDb', details.imdbId!),
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
  final List<TmdbMedia> items;

  const _RecommendationsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptySection(message: 'Aucune recommandation disponible.');
    }
    return _Section(
      title: 'Vous aimerez aussi',
      child: SizedBox(
        height: 204,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 11),
          itemBuilder: (_, index) => TmdbPosterCard(
            media: items[index],
            width: 126,
            onTap: () => context.push(
              '/flixMediaDetail',
              extra: items[index],
            ),
          ),
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

  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

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
  final String? fallback;

  const _BackdropCarousel({required this.paths, required this.fallback});

  @override
  State<_BackdropCarousel> createState() => _BackdropCarouselState();
}

class _BackdropCarouselState extends State<_BackdropCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths.isEmpty && widget.fallback != null
        ? <String>[widget.fallback!]
        : widget.paths;
    if (paths.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF181822)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: paths.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (_, index) => ExtendedImage.network(
            'https://image.tmdb.org/t/p/w1280${paths[index]}',
            fit: BoxFit.cover,
            cache: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.completed) {
                return null;
              }
              return const AppShimmerBlock();
            },
          ),
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
        if (paths.length > 1)
          Positioned(
            bottom: 17,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < paths.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
          ),
      ],
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

class _PosterPlaceholder extends StatelessWidget {
  final IconData icon;

  const _PosterPlaceholder({this.icon = Icons.movie_creation_outlined});

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
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 44),
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