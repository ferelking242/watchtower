import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'flixquest_app_ui_components.dart';
import 'tmdb_genres_screen.dart';

/// FlixQuest's original Movies home composition, adapted only at the
/// Watchtower data and navigation boundaries.
class MainMoviesDisplay extends StatefulWidget {
  const MainMoviesDisplay({
    required this.home,
    this.onSearchPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final TmdbHome home;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onBookmarksPressed;

  @override
  State<MainMoviesDisplay> createState() => _MainMoviesDisplayState();
}

class _MainMoviesDisplayState extends State<MainMoviesDisplay> {
  final ScrollController _feedController = ScrollController();
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!mounted) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final threshold = heroHeight - MediaQuery.paddingOf(context).top;
    final shouldShow = _feedController.offset >= threshold;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  void _openMedia(TmdbMedia media) {
    context.push('/flixMediaDetail', extra: media);
  }

  void _openLibrary() {
    context.push('/Library');
  }

  @override
  void dispose() {
    _feedController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.onSearchPressed ?? () => context.push('/flixSearch');
    final openLibrary = widget.onBookmarksPressed ?? _openLibrary;
    final openLiveTv = () => context.push('/liveTv');

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {},
          child: CustomScrollView(
            controller: _feedController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: DiscoverMovies(
                  movies: widget.home.trendingMovies,
                  onSearchPressed: search,
                  onLiveTVPressed: openLiveTv,
                  onLibraryPressed: openLibrary,
                  onMoviePressed: _openMedia,
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate.fixed([
                  ScrollingMovies(
                    title: 'Popular',
                    items: widget.home.popularMovies,
                    discoverPath: '/movie/popular',
                  ),
                  ScrollingMovies(
                    title: 'Trending this week',
                    items: widget.home.trendingMovies,
                    discoverPath: '/trending/movie/week',
                  ),
                  ScrollingMovies(
                    title: 'Top rated',
                    items: widget.home.topRatedMovies,
                    discoverPath: '/movie/top_rated',
                  ),
                  RankedMovies(
                    title: 'Top 10 cette semaine',
                    items: widget.home.trendingMovies
                        .take(10)
                        .toList(growable: false),
                  ),
                  ScrollingLandscapeMovies(
                    title: 'Now playing',
                    items: widget.home.nowPlayingMovies,
                    discoverPath: '/movie/now_playing',
                  ),
                  ScrollingLandscapeMovies(
                    title: 'Upcoming',
                    items: widget.home.upcomingMovies,
                    discoverPath: '/movie/upcoming',
                  ),
                  FeaturedMovieRail(
                    title: 'À découvrir',
                    items: [
                      ...widget.home.popularMovies,
                      ...widget.home.trendingMovies,
                    ],
                  ),
                  FullWidthMovieBanners(
                    title: 'À voir ce soir',
                    items: [
                      ...widget.home.nowPlayingMovies,
                      ...widget.home.upcomingMovies,
                    ],
                  ),
                  GenreListGrid(
                    imageSource: [
                      ...widget.home.trendingMovies,
                      ...widget.home.popularMovies,
                      ...widget.home.topRatedMovies,
                    ],
                  ),
                  const MoviesFromWatchProviders(),
                  const SizedBox(height: 112),
                ]),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showCompactHeader,
            child: AnimatedSlide(
              offset: _showCompactHeader ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showCompactHeader ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AppFeedOverlayHeader(
                  title: 'Movies',
                  onSearchPressed: search,
                  actionLabel: 'Live TV',
                  actionIcon: Broken.radio,
                  onActionPressed: openLiveTv,
                  utilityIcon: Broken.bookmark,
                  utilityTooltip: 'Library',
                  onUtilityPressed: openLibrary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The same FlixQuest feed composition used for television series.
class MainSeriesDisplay extends StatefulWidget {
  const MainSeriesDisplay({
    required this.home,
    this.onSearchPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final TmdbHome home;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onBookmarksPressed;

  @override
  State<MainSeriesDisplay> createState() => _MainSeriesDisplayState();
}

class _MainSeriesDisplayState extends State<MainSeriesDisplay> {
  final ScrollController _feedController = ScrollController();
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!mounted) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final shouldShow =
        _feedController.offset >=
        heroHeight - MediaQuery.paddingOf(context).top;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  void _openMedia(TmdbMedia media) =>
      context.push('/flixMediaDetail', extra: media);

  void _openLibrary() {
    context.push('/Library');
  }

  @override
  void dispose() {
    _feedController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.onSearchPressed ?? () => context.push('/flixSearch');
    final openLibrary = widget.onBookmarksPressed ?? _openLibrary;
    final liveTv = () => context.push('/liveTv');

    return Stack(
      children: [
        CustomScrollView(
          controller: _feedController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: DiscoverMovies(
                movies: widget.home.trendingTv,
                onSearchPressed: search,
                onLiveTVPressed: liveTv,
                onLibraryPressed: openLibrary,
                onMoviePressed: _openMedia,
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                ScrollingMovies(
                  title: 'Popular',
                  items: widget.home.popularTv,
                  discoverPath: '/tv/popular',
                ),
                ScrollingMovies(
                  title: 'Trending this week',
                  items: widget.home.trendingTv,
                  discoverPath: '/trending/tv/week',
                ),
                ScrollingMovies(
                  title: 'Top rated',
                  items: widget.home.topRatedTv,
                  discoverPath: '/tv/top_rated',
                ),
                ScrollingLandscapeMovies(
                  title: 'Airing today',
                  items: widget.home.airingTodayTv,
                ),
                ScrollingLandscapeMovies(
                  title: 'On the air',
                  items: widget.home.onTheAirTv,
                ),
                FullWidthMovieBanners(
                  title: 'À voir bientôt',
                  items: [
                    ...widget.home.airingTodayTv,
                    ...widget.home.onTheAirTv,
                  ],
                ),
                GenreListGrid(
                  isTv: true,
                  imageSource: [
                    ...widget.home.trendingTv,
                    ...widget.home.popularTv,
                    ...widget.home.topRatedTv,
                  ],
                ),
                const SizedBox(height: 112),
              ]),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showCompactHeader,
            child: AnimatedSlide(
              offset: _showCompactHeader ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showCompactHeader ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AppFeedOverlayHeader(
                  title: 'Series',
                  onSearchPressed: search,
                  actionLabel: 'Live TV',
                  actionIcon: Broken.radio,
                  onActionPressed: liveTv,
                  utilityIcon: Broken.bookmark,
                  utilityTooltip: 'Library',
                  onUtilityPressed: openLibrary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The original FlixQuest hero entry point, retaining its cross-fade swipe
/// transition while receiving Watchtower's TmdbMedia objects.
class DiscoverMovies extends StatelessWidget {
  const DiscoverMovies({
    required this.movies,
    required this.onSearchPressed,
    required this.onLiveTVPressed,
    required this.onLibraryPressed,
    required this.onMoviePressed,
    super.key,
  });

  final List<TmdbMedia> movies;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTVPressed;
  final VoidCallback onLibraryPressed;
  final ValueChanged<TmdbMedia> onMoviePressed;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final heroMovies = movies.take(10).toList(growable: false);
    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: heroMovies.isEmpty
          ? const AppShimmerBlock(radius: 0)
          : AppCrossfadeCarousel(
              itemCount: heroMovies.length,
              onItemTap: (index) => onMoviePressed(heroMovies[index]),
              itemBuilder: (context, index) {
                final movie = heroMovies[index];
                final imagePath = movie.bannerImage ?? movie.bestCover;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imagePath != null)
                      ExtendedImage.network(
                        imagePath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        cache: true,
                      )
                    else
                      const AppShimmerBlock(radius: 0),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .42, 1],
                          colors: [
                            Color(0x52000000),
                            Color(0x15000000),
                            Color(0xE6000000),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/fq_svg.svg',
                                width: 28,
                                height: 28,
                                placeholderBuilder: (_) => const Icon(
                                  Broken.video,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const Spacer(),
                              _HeroIconButton(
                                icon: Broken.bookmark,
                                onPressed: onLibraryPressed,
                                tooltip: 'Library',
                              ),
                              const SizedBox(width: 8),
                              if (onLiveTVPressed != null) ...[
                                _HeroLiveButton(onPressed: onLiveTVPressed!),
                                const SizedBox(width: 8),
                              ],
                              const SizedBox(width: 8),
                              _HeroIconButton(
                                icon: Broken.search_normal,
                                onPressed: onSearchPressed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              if ((movie.releaseDate ??
                                          movie.firstAirDate ??
                                          '')
                                      .length >=
                                  4)
                                _HeroMetaChip(
                                  label:
                                      (movie.releaseDate ?? movie.firstAirDate!)
                                          .substring(0, 4),
                                ),
                              if (movie.voteAverage != null)
                                _HeroMetaChip(
                                  icon: Broken.star,
                                  label: movie.voteAverage!.toStringAsFixed(1),
                                ),
                            ],
                          ),
                          if (movie.overview?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(
                              movie.overview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.3,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Center(
                      child: _HeroWatchButton(
                        onPressed: () => onMoviePressed(movie),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeroWatchButton extends StatelessWidget {
  const _HeroWatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .74)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Broken.play, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.amberAccent, size: 12),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLiveButton extends StatelessWidget {
  const _HeroLiveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Broken.radio, color: Colors.white, size: 19),
              SizedBox(width: 7),
              Text(
                'Live TV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScrollingMovies extends StatelessWidget {
  const ScrollingMovies({
    required this.title,
    required this.items,
    required this.discoverPath,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;
  final String discoverPath;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TmdbMoviesListScreen(
                title: title,
                path: discoverPath,
                initialItems: items,
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: cardWidth * 1.5 + 62,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final media = items[index];
              final source = 'flix-poster-${title.hashCode}-$index';
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? AppUI.pagePadding(context) : 10,
                  top: 8,
                  bottom: 8,
                ),
                child: SizedBox(
                  width: cardWidth,
                  child: TmdbPosterCard(
                    media: media,
                    heroTag: tmdbHeroTag(media, source),
                    width: cardWidth,
                    onTap: () =>
                        pushTmdbMediaDetail(context, media, source: source),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ScrollingLandscapeMovies extends StatelessWidget {
  const ScrollingLandscapeMovies({
    required this.title,
    required this.items,
    this.discoverPath,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;
  final String? discoverPath;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: discoverPath == null ? null : 'All >',
          onAction: discoverPath == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TmdbMoviesListScreen(
                      title: title,
                      path: discoverPath!,
                      initialItems: items,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final media = items[index];
              final source = 'flix-landscape-${title.hashCode}-$index';
              return TmdbLandscapeCard(
                media: media,
                heroTag: tmdbHeroTag(media, source),
                width: 238,
                onTap: () =>
                    pushTmdbMediaDetail(context, media, source: source),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A ranked rail breaks up the repeated poster rows and mirrors the Top 10
/// treatment used by FlixQuest: the number is part of the card, not a badge
/// hidden below the image.
class RankedMovies extends StatelessWidget {
  const RankedMovies({required this.title, required this.items, super.key});

  final String title;
  final List<TmdbMedia> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        SizedBox(
          height: 208,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final media = items[index];
              final source = 'flix-ranked-${title.hashCode}-$index';
              return TmdbRankedCard(
                media: media,
                heroTag: tmdbHeroTag(media, source),
                rank: index + 1,
                onTap: () =>
                    pushTmdbMediaDetail(context, media, source: source),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A second landscape treatment with larger cards is useful for films whose
/// backdrop is more informative than their poster.
class FeaturedMovieRail extends StatelessWidget {
  const FeaturedMovieRail({
    required this.title,
    required this.items,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;

  @override
  Widget build(BuildContext context) {
    final uniqueItems = <int, TmdbMedia>{
      for (final item in items) item.id: item,
    }.values.toList(growable: false);
    if (uniqueItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        SizedBox(
          height: 204,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: uniqueItems.take(10).length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final media = uniqueItems[index];
              final source = 'flix-featured-$index';
              return TmdbLandscapeCard(
                media: media,
                width: 280,
                heroTag: tmdbHeroTag(media, source),
                onTap: () =>
                    pushTmdbMediaDetail(context, media, source: source),
              );
            },
          ),
        ),
      ],
    );
  }
}

class GenreListGrid extends StatelessWidget {
  const GenreListGrid({
    this.imageSource = const [],
    this.isTv = false,
    super.key,
  });

  final List<TmdbMedia> imageSource;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbGenre>>(
      future: isTv ? fetchTmdbTvGenres() : fetchTmdbMovieGenres(),
      builder: (context, snapshot) {
        final genres = snapshot.data ?? const <TmdbGenre>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            genres.isEmpty) {
          return AppGenreGridShimmer(isTv: isTv);
        }
        if (genres.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: isTv ? 'TV genres' : 'Genres',
              actionLabel: 'All >',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TmdbGenresScreen(
                    title: isTv ? 'TV genres' : 'Genres',
                    genres: genres,
                    imageSource: imageSource,
                    isTv: isTv,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 186,
              child: GridView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: AppUI.pagePadding(context),
                ),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                ),
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final genreImages = imageSource
                      .where((movie) => movie.genreIds.contains(genre.id))
                      .map((movie) => movie.bannerImage ?? movie.bestCover)
                      .whereType<String>()
                      .toList(growable: false);
                  final image = genreImages.isNotEmpty
                      ? genreImages.first
                      : imageSource.isEmpty
                      ? null
                      : (imageSource[index % imageSource.length].bannerImage ??
                            imageSource[index % imageSource.length].bestCover);
                  return AppGenreTile(
                    label: genre.name,
                    imageUrl: image,
                    fallbackImageUrl: image,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TmdbMoviesListScreen(
                          title: genre.name,
                          path:
                              '/discover/${isTv ? 'tv' : 'movie'}?with_genres=${genre.id}',
                          isTv: isTv,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class FullWidthMovieBanners extends StatelessWidget {
  const FullWidthMovieBanners({
    required this.title,
    required this.items,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;

  @override
  Widget build(BuildContext context) {
    final banners = items
        .where((movie) => movie.bannerImage != null)
        .take(8)
        .toList(growable: false);
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        ...banners.map(
          (movie) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              0,
              AppUI.pagePadding(context),
              12,
            ),
            child: _FullWidthMovieBanner(movie: movie),
          ),
        ),
      ],
    );
  }
}

class _FullWidthMovieBanner extends StatelessWidget {
  const _FullWidthMovieBanner({required this.movie});

  final TmdbMedia movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/flixMediaDetail', extra: movie),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 2.05,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExtendedImage.network(
                movie.bannerImage!,
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
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(
                  movie.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoviesFromWatchProviders extends StatelessWidget {
  const MoviesFromWatchProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbWatchProvider>>(
      future: fetchTmdbWatchProviders(),
      builder: (context, snapshot) {
        final services = snapshot.data ?? const <TmdbWatchProvider>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            services.isEmpty) {
          return const AppStreamingServicesShimmer();
        }
        if (services.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(title: 'Streaming services'),
            SizedBox(
              height: 132,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: AppUI.pagePadding(context),
                  vertical: 2,
                ),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _StreamingServiceCard(
                    service: service,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TmdbMoviesListScreen(
                          title: service.name,
                          path:
                              '/discover/movie?watch_region=US&with_watch_providers=${service.id}&with_watch_monetization_types=flatrate',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StreamingServiceCard extends StatelessWidget {
  const _StreamingServiceCard({required this.service, required this.onTap});

  final TmdbWatchProvider service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111216),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .4),
                ),
              ),
              child: service.logoUrl == null
                  ? const Icon(Broken.video, color: Colors.white54)
                  : ExtendedImage.network(
                      service.logoUrl!,
                      fit: BoxFit.contain,
                      cache: true,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              service.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class TmdbMoviesListScreen extends StatefulWidget {
  const TmdbMoviesListScreen({
    required this.title,
    required this.path,
    this.initialItems = const [],
    this.isTv = false,
    super.key,
  });

  final String title;
  final String path;
  final List<TmdbMedia> initialItems;
  final bool isTv;

  @override
  State<TmdbMoviesListScreen> createState() => _TmdbMoviesListScreenState();
}

class _TmdbMoviesListScreenState extends State<TmdbMoviesListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final List<TmdbMedia> _movies;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _sortMode = 'popular';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _movies = [...widget.initialItems];
    _scrollController.addListener(_onScroll);
    if (_movies.isEmpty) {
      _loadPage();
    } else {
      _page = 2;
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = widget.isTv
          ? await fetchTmdbTvPage(path: widget.path, page: _page)
          : await fetchTmdbMoviePage(path: widget.path, page: _page);
      if (!mounted) return;
      setState(() {
        _movies.addAll(page);
        _hasMore = page.isNotEmpty;
        if (page.isNotEmpty) _page++;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _chooseSort() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort and filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _SortChoice(
              title: 'Most Popular',
              value: 'popular',
              selected: _sortMode,
              onTap: () => Navigator.pop(sheetContext, 'popular'),
            ),
            _SortChoice(
              title: 'Highest rated',
              value: 'rating',
              selected: _sortMode,
              onTap: () => Navigator.pop(sheetContext, 'rating'),
            ),
            _SortChoice(
              title: 'A — Z',
              value: 'title',
              selected: _sortMode,
              onTap: () => Navigator.pop(sheetContext, 'title'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _sortMode = selected);
    }
  }

  List<TmdbMedia> get _sortedMovies {
    final items = [..._movies];
    switch (_sortMode) {
      case 'rating':
        items.sort(
          (a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0),
        );
        break;
      case 'title':
        items.sort(
          (a, b) => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
        );
        break;
    }
    return items;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = _sortedMovies;
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: isFrench ? 'Retour' : 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Broken.arrow_left),
        ),
        actions: [
          IconButton(
            tooltip: isFrench ? 'Filtrer' : 'Filter',
            onPressed: _chooseSort,
            icon: const Icon(Broken.filter),
          ),
        ],
      ),
      body: _error != null && movies.isEmpty
          ? _CatalogError(title: widget.title, onRetry: _loadPage)
          : movies.isEmpty && _loading
          ? const AppMediaGridShimmer()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Text(
                    isFrench ? 'Les plus populaires' : 'Most Popular',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: AppUI.mediaGridColumns(context),
                      childAspectRatio: AppUI.mediaGridChildAspectRatio(
                        context,
                      ),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: movies.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= movies.length) {
                        return const AppShimmerBlock(radius: 14);
                      }
                      final media = movies[index];
                      final source = 'flix-catalog-$index';
                      return TmdbPosterCard(
                        media: media,
                        heroTag: tmdbHeroTag(media, source),
                        onTap: () =>
                            pushTmdbMediaDetail(context, media, source: source),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SortChoice extends StatelessWidget {
  const _SortChoice({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String value;
  final String selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        value == 'popular'
            ? Broken.star
            : value == 'rating'
            ? Broken.star
            : Broken.sort,
        color: Colors.white70,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Icon(
        selected == value ? Broken.tick_circle : Broken.radio,
        color: selected == value ? Colors.orange : Colors.white38,
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        title: 'Catalogue indisponible',
        message: 'Impossible de charger $title pour le moment.',
        icon: Broken.wifi,
        actionLabel: 'Réessayer',
        onAction: onRetry,
      ),
    );
  }
}

/// FlixQuest-style TMDB search kept separate from Watchtower's extension
/// search. It searches the movie/series catalogue and never opens the
/// extension global-search route.
class TmdbSearchScreen extends StatefulWidget {
  const TmdbSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<TmdbSearchScreen> createState() => _TmdbSearchScreenState();
}

class _TmdbSearchScreenState extends State<TmdbSearchScreen> {
  static const _recentSearchesKey = 'tmdb_recent_searches';

  final TextEditingController _controller = TextEditingController();
  final List<String> _recentSearches = <String>[];
  String _query = '';
  Future<List<TmdbMedia>>? _movies;
  Future<List<TmdbMedia>>? _series;
  Future<List<TmdbPersonRef>>? _people;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search(initialQuery);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search([String? raw]) {
    final query = (raw ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    final encoded = Uri.encodeQueryComponent(query);
    setState(() {
      _query = query;
      _movies = fetchTmdbMoviePage(path: '/search/movie?query=$encoded');
      _series = fetchTmdbTvPage(path: '/search/tv?query=$encoded');
      _people = fetchTmdbPeoplePage(path: '/search/person?query=$encoded');
    });
    _rememberSearch(query);
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _rememberSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final next = <String>[
      query,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ].take(12).toList(growable: false);
    await prefs.setStringList(_recentSearchesKey, next);
    if (mounted) {
      setState(() {
        _recentSearches
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final next = _recentSearches.where((item) => item != query).toList();
    await prefs.setStringList(_recentSearchesKey, next);
    if (mounted) {
      setState(() {
        _recentSearches
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (mounted) {
      setState(() {
        _recentSearches.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _SearchCopy.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: copy.back,
                      onPressed: () => context.pop(),
                      icon: const Icon(Broken.arrow_left),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: copy.hint,
                          prefixIcon: const Icon(Broken.search_normal),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: copy.clear,
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Broken.close_circle),
                                ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.6,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: copy.search,
                      onPressed: _search,
                      icon: const Icon(Broken.search_normal),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: [
                  Tab(text: copy.movies),
                  Tab(text: copy.tvShows),
                  Tab(text: copy.celebrities),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _query.isEmpty
                        ? _RecentSearches(
                            searches: _recentSearches,
                            copy: copy,
                            onSearch: _search,
                            onRemove: _removeRecentSearch,
                            onClear: _clearRecentSearches,
                          )
                        : _TmdbSearchResults(future: _movies!),
                    _query.isEmpty
                        ? _RecentSearches(
                            searches: _recentSearches,
                            copy: copy,
                            onSearch: _search,
                            onRemove: _removeRecentSearch,
                            onClear: _clearRecentSearches,
                          )
                        : _TmdbSearchResults(future: _series!),
                    _query.isEmpty
                        ? _RecentSearches(
                            searches: _recentSearches,
                            copy: copy,
                            onSearch: _search,
                            onRemove: _removeRecentSearch,
                            onClear: _clearRecentSearches,
                          )
                        : _TmdbPeopleResults(future: _people!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TmdbSearchResults extends StatelessWidget {
  const _TmdbSearchResults({required this.future});

  final Future<List<TmdbMedia>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbMedia>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppMediaGridShimmer();
        }
        if (snapshot.hasError || snapshot.data?.isEmpty != false) {
          return const AppEmptyState(
            title: 'Aucun résultat',
            message: 'Aucun film ou série ne correspond à cette recherche.',
            icon: Broken.search_status,
          );
        }
        final items = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: .66,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final media = items[index];
            final source = 'flix-search-$index';
            return TmdbPosterCard(
              media: media,
              width: double.infinity,
              heroTag: tmdbHeroTag(media, source),
              onTap: () => pushTmdbMediaDetail(context, media, source: source),
            );
          },
        );
      },
    );
  }
}

class _TmdbPeopleResults extends StatelessWidget {
  const _TmdbPeopleResults({required this.future});

  final Future<List<TmdbPersonRef>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbPersonRef>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PeopleSearchShimmer();
        }
        if (snapshot.hasError || snapshot.data?.isEmpty != false) {
          return const _SearchNoResults();
        }
        final people = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          itemCount: people.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final person = people[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: person.profileUrl == null
                      ? null
                      : NetworkImage(person.profileUrl!),
                  child: person.profileUrl == null
                      ? const Icon(Broken.people)
                      : null,
                ),
                title: Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: person.knownForDepartment == null
                    ? null
                    : Text(person.knownForDepartment!),
                trailing: const Icon(Broken.arrow_right_3),
                onTap: () => context.push('/flixPerson', extra: person),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.copy,
    required this.onSearch,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> searches;
  final _SearchCopy copy;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return _SearchNoResults(
        title: copy.startTitle,
        message: copy.startMessage,
        icon: Broken.search_status,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 12, 8),
          child: Row(
            children: [
              Text(
                copy.recent,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(onPressed: onClear, child: Text(copy.clearAll)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
            itemCount: searches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final search = searches[index];
              return ListTile(
                leading: const Icon(Broken.clock),
                title: Text(search),
                trailing: IconButton(
                  tooltip: copy.remove,
                  onPressed: () => onRemove(search),
                  icon: const Icon(Broken.close_circle),
                ),
                onTap: () => onSearch(search),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults({
    this.title = 'No results',
    this.message = 'Try another search.',
    this.icon = Broken.search_status,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: colors.primary.withValues(alpha: .8)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSearchShimmer extends StatelessWidget {
  const _PeopleSearchShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) =>
          const SizedBox(height: 76, child: AppShimmerBlock(radius: 18)),
    );
  }
}

class _SearchCopy {
  const _SearchCopy({
    required this.back,
    required this.clear,
    required this.search,
    required this.hint,
    required this.movies,
    required this.tvShows,
    required this.celebrities,
    required this.recent,
    required this.clearAll,
    required this.remove,
    required this.startTitle,
    required this.startMessage,
  });

  final String back;
  final String clear;
  final String search;
  final String hint;
  final String movies;
  final String tvShows;
  final String celebrities;
  final String recent;
  final String clearAll;
  final String remove;
  final String startTitle;
  final String startMessage;

  static _SearchCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'fr') {
      return const _SearchCopy(
        back: 'Retour',
        clear: 'Effacer',
        search: 'Rechercher',
        hint: 'Rechercher un film, une série ou une célébrité',
        movies: 'Films',
        tvShows: 'Séries',
        celebrities: 'Célébrités',
        recent: 'Recherches récentes',
        clearAll: 'Tout effacer',
        remove: 'Supprimer',
        startTitle: 'Que veux-tu regarder ?',
        startMessage:
            'Recherche dans le catalogue Films, Séries et Célébrités.',
      );
    }
    return const _SearchCopy(
      back: 'Back',
      clear: 'Clear',
      search: 'Search',
      hint: 'Search for a movie, series or celebrity',
      movies: 'Movies',
      tvShows: 'TV Shows',
      celebrities: 'Celebrities',
      recent: 'Recent searches',
      clearAll: 'Clear all',
      remove: 'Remove',
      startTitle: 'What do you want to watch?',
      startMessage: 'Search the Movies, TV Shows and Celebrities catalog.',
    );
  }
}
