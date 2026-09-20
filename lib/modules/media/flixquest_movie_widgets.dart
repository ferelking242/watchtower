import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'flixquest_app_ui_components.dart';

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
  final Set<int> _bookmarkedMovieIds = <int>{};
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!mounted) return;
    final heroHeight =
        (MediaQuery.sizeOf(context).height * .48).clamp(410.0, 500.0);
    final threshold = heroHeight - MediaQuery.paddingOf(context).top;
    final shouldShow = _feedController.offset >= threshold;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  void _openMedia(TmdbMedia media) {
    context.push('/flixMediaDetail', extra: media);
  }

  void _toggleBookmark(TmdbMedia media) {
    setState(() {
      if (!_bookmarkedMovieIds.add(media.id)) {
        _bookmarkedMovieIds.remove(media.id);
      }
    });
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
    final search = widget.onSearchPressed ??
        () => context.push('/globalSearch');
    final openBookmarks = widget.onBookmarksPressed ??
        () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Liste locale des favoris')),
            );
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
                  bookmarkedMovieIds: _bookmarkedMovieIds,
                  onSearchPressed: search,
                  onLiveTVPressed: openLiveTv,
                  onBookmarksPressed: openBookmarks,
                  onBookmarkToggled: _toggleBookmark,
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
                  ScrollingLandscapeMovies(
                    title: 'Now playing',
                    items: widget.home.nowPlayingMovies,
                  ),
                  ScrollingLandscapeMovies(
                    title: 'Upcoming',
                    items: widget.home.upcomingMovies,
                  ),
                  const GenreListGrid(),
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
                  actionIcon: Icons.podcasts_rounded,
                  onActionPressed: openLiveTv,
                  utilityIcon: Icons.bookmark_border_rounded,
                  utilityTooltip: 'Bookmarks',
                  onUtilityPressed: openBookmarks,
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
    required this.bookmarkedMovieIds,
    required this.onSearchPressed,
    required this.onLiveTVPressed,
    required this.onBookmarksPressed,
    required this.onBookmarkToggled,
    required this.onMoviePressed,
    super.key,
  });

  final List<TmdbMedia> movies;
  final Set<int> bookmarkedMovieIds;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTVPressed;
  final VoidCallback? onBookmarksPressed;
  final ValueChanged<TmdbMedia> onBookmarkToggled;
  final ValueChanged<TmdbMedia> onMoviePressed;

  @override
  Widget build(BuildContext context) {
    final heroHeight =
        (MediaQuery.sizeOf(context).height * .48).clamp(410.0, 500.0);
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
                final isBookmarked = bookmarkedMovieIds.contains(movie.id);
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
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/fq_svg.svg',
                              width: 28,
                              height: 28,
                              placeholderBuilder: (_) => const Icon(
                                Icons.movie_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const Spacer(),
                            if (onLiveTVPressed != null) ...[
                              _HeroLiveButton(onPressed: onLiveTVPressed!),
                              const SizedBox(width: 8),
                            ],
                            _HeroIconButton(
                              icon: isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              tooltip: 'Bookmarks',
                              onPressed: () => onBookmarkToggled(movie),
                            ),
                            const SizedBox(width: 8),
                            _HeroIconButton(
                              icon: Icons.search_rounded,
                              onPressed: onSearchPressed,
                            ),
                          ],
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
                              fontSize: 30,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              if ((movie.releaseDate ?? '').length >= 4)
                                movie.releaseDate!.substring(0, 4),
                              if (movie.voteAverage != null)
                                '★ ${movie.voteAverage!.toStringAsFixed(1)}',
                              if ((movie.originalLanguage ?? '').isNotEmpty)
                                movie.originalLanguage!.toUpperCase(),
                            ].join('  •  '),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () => onMoviePressed(movie),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Watch now'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => onBookmarkToggled(movie),
                                icon: Icon(
                                  isBookmarked
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                ),
                                label: const Text('Bookmark'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
              Icon(Icons.podcasts_rounded, color: Colors.white, size: 19),
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
          actionLabel: 'View all',
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
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AppUI.pagePadding(context) : 10,
                top: 8,
                bottom: 8,
              ),
              child: SizedBox(
                width: cardWidth,
                child: TmdbPosterCard(
                  media: items[index],
                  width: cardWidth,
                  onTap: () => context.push(
                    '/flixMediaDetail',
                    extra: items[index],
                  ),
                ),
              ),
            ),
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
    super.key,
  });

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
          height: 158,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => TmdbLandscapeCard(
              media: items[index],
              width: 238,
              onTap: () => context.push(
                '/flixMediaDetail',
                extra: items[index],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GenreListGrid extends StatelessWidget {
  const GenreListGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbGenre>>(
      future: fetchTmdbMovieGenres(),
      builder: (context, snapshot) {
        final genres = snapshot.data ?? const <TmdbGenre>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            genres.isEmpty) {
          return const SizedBox(height: 154, child: AppShimmerBlock());
        }
        if (genres.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(title: 'Genres'),
            SizedBox(
              height: 126,
              child: GridView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: AppUI.pagePadding(context),
                ),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 184,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  return AppGenreTile(
                    label: genre.name,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TmdbMoviesListScreen(
                          title: genre.name,
                          path: '/discover/movie?with_genres=${genre.id}',
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
          return const SizedBox(height: 154, child: AppShimmerBlock());
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
  const _StreamingServiceCard({
    required this.service,
    required this.onTap,
  });

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
                  ? const Icon(Icons.live_tv_rounded, color: Colors.white54)
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
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
    super.key,
  });

  final String title;
  final String path;
  final List<TmdbMedia> initialItems;

  @override
  State<TmdbMoviesListScreen> createState() => _TmdbMoviesListScreenState();
}

class _TmdbMoviesListScreenState extends State<TmdbMoviesListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final List<TmdbMedia> _movies;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
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
      final page = await fetchTmdbMoviePage(path: widget.path, page: _page);
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

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null && _movies.isEmpty
          ? Center(child: Text('Impossible de charger ${widget.title}'))
          : GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                12,
                AppUI.pagePadding(context),
                32,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppUI.mediaGridColumns(context),
                childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
                crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
                mainAxisSpacing: 16,
              ),
              itemCount: _movies.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _movies.length) {
                  return const AppShimmerBlock();
                }
                final media = _movies[index];
                return TmdbPosterCard(
                  media: media,
                  onTap: () => context.push(
                    '/flixMediaDetail',
                    extra: media,
                  ),
                );
              },
            ),
    );
  }
}