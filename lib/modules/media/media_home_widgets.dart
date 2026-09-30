import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'app_ui_components.dart';
import 'content_cards.dart';
import 'media_content_sections.dart';
import 'tmdb_genres_screen.dart';

/// One feed composition for both Hub destinations. Only the selected data
/// lists and the catalogue paths change between films and series.
class MainMediaDisplay extends StatefulWidget {
  const MainMediaDisplay({
    required this.home,
    required this.isTv,
    this.onSearchPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final TmdbHome home;
  final bool isTv;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onBookmarksPressed;

  @override
  State<MainMediaDisplay> createState() => _MainMediaDisplayState();
}

class _MainMediaDisplayState extends State<MainMediaDisplay> {
  final _feedController = ScrollController();
  bool _showCompactHeader = false;

  List<TmdbMedia> get _trending =>
      widget.isTv ? widget.home.trendingTv : widget.home.trendingMovies;
  List<TmdbMedia> get _popular =>
      widget.isTv ? widget.home.popularTv : widget.home.popularMovies;
  List<TmdbMedia> get _topRated =>
      widget.isTv ? widget.home.topRatedTv : widget.home.topRatedMovies;
  List<TmdbMedia> get _firstLatest =>
      widget.isTv ? widget.home.airingTodayTv : widget.home.nowPlayingMovies;
  List<TmdbMedia> get _secondLatest =>
      widget.isTv ? widget.home.onTheAirTv : widget.home.upcomingMovies;

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!_feedController.hasClients || !mounted) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    // Hero is drawn heroHeight + 36 tall (notch overhang) — match it.
    final shouldShow = _feedController.offset >=
        heroHeight + 36 - MediaQuery.paddingOf(context).top;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
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
    final library =
        widget.onBookmarksPressed ?? () => context.push('/Library');
    final liveTv = () => context.push('/liveTv');
    final kind = widget.isTv ? 'Series' : 'Movies';
    final latestPath = widget.isTv ? null : '/movie/now_playing';
    final upcomingPath = widget.isTv ? null : '/movie/upcoming';

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
                  movies: _trending,
                  onSearchPressed: search,
                  onLiveTVPressed: liveTv,
                  onLibraryPressed: library,
                  onMoviePressed: (media) =>
                      context.push('/flixMediaDetail', extra: media),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate.fixed([
                  ScrollingMovies(
                    title: 'Popular',
                    items: _popular,
                    discoverPath: widget.isTv ? '/tv/popular' : '/movie/popular',
                    isTv: widget.isTv,
                  ),
                  ScrollingMovies(
                    title: 'Trending this week',
                    items: _trending,
                    discoverPath: widget.isTv
                        ? '/trending/tv/week'
                        : '/trending/movie/week',
                    isTv: widget.isTv,
                  ),
                  ScrollingMovies(
                    title: 'Top rated',
                    items: _topRated,
                    discoverPath:
                        widget.isTv ? '/tv/top_rated' : '/movie/top_rated',
                    isTv: widget.isTv,
                  ),
                  RankedMovies(
                    title: 'Top 10 cette semaine',
                    items: _trending.take(10).toList(growable: false),
                  ),
                  ScrollingLandscapeMovies(
                    title: widget.isTv ? 'Airing today' : 'Now playing',
                    items: _firstLatest,
                    discoverPath: latestPath,
                    isTv: widget.isTv,
                  ),
                  ScrollingLandscapeMovies(
                    title: widget.isTv ? 'On the air' : 'Upcoming',
                    items: _secondLatest,
                    discoverPath: upcomingPath,
                    isTv: widget.isTv,
                  ),
                  FeaturedMovieRail(
                    title: 'À découvrir',
                    items: [..._popular, ..._trending],
                  ),
                  TmdbFeaturedStack(
                    title: 'À voir cette semaine',
                    icon: Icons.event_available_rounded,
                    color: const Color(0xFF00B894),
                    items: [
                      ..._trending,
                      ..._firstLatest,
                      ..._secondLatest,
                    ].take(8).toList(growable: false),
                    onTap: (media) =>
                        context.push('/flixMediaDetail', extra: media),
                  ),
                  DocumentarySections(isTv: widget.isTv),
                  const RealityAndTalkSections(),
                  GenreListGrid(
                    isTv: widget.isTv,
                    imageSource: [..._trending, ..._popular, ..._topRated],
                  ),
                  TmdbTagListSection(
                    title: 'Catégories',
                    tags: tmdbCategoryTags,
                    isTv: widget.isTv,
                  ),
                  TmdbTagListSection(
                    title: 'Histoires',
                    tags: tmdbPlotKeywords,
                    isTv: widget.isTv,
                  ),
                  MoviesFromWatchProviders(isTv: widget.isTv),
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
                  title: kind,
                  onSearchPressed: search,
                  actionLabel: 'Live TV',
                  actionIcon: Broken.radio,
                  onActionPressed: liveTv,
                  utilityIcon: Broken.bookmark,
                  utilityTooltip: 'Library',
                  onUtilityPressed: library,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared media home composition for the Movies and Series Hub pages.
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
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
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
                  TmdbFeaturedStack(
                    title: 'À voir cette semaine',
                    icon: Icons.event_available_rounded,
                    color: const Color(0xFF00B894),
                    items: [
                      ...widget.home.trendingMovies,
                      ...widget.home.nowPlayingMovies,
                      ...widget.home.upcomingMovies,
                    ].take(8).toList(growable: false),
                    onTap: (media) => _openMedia(media),
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

/// The same media feed composition used for television series.
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
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
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
                  isTv: true,
                ),
                ScrollingMovies(
                  title: 'Trending this week',
                  items: widget.home.trendingTv,
                  discoverPath: '/trending/tv/week',
                  isTv: true,
                ),
                ScrollingMovies(
                  title: 'Top rated',
                  items: widget.home.topRatedTv,
                  discoverPath: '/tv/top_rated',
                  isTv: true,
                ),
                ScrollingLandscapeMovies(
                  title: 'Airing today',
                  items: widget.home.airingTodayTv,
                  isTv: true,
                ),
                ScrollingLandscapeMovies(
                  title: 'On the air',
                  items: widget.home.onTheAirTv,
                  isTv: true,
                ),
                TmdbFeaturedStack(
                  title: 'À voir cette semaine',
                  icon: Icons.event_available_rounded,
                  color: const Color(0xFF00B894),
                  items: [
                    ...widget.home.trendingTv,
                    ...widget.home.airingTodayTv,
                    ...widget.home.onTheAirTv,
                  ].take(8).toList(growable: false),
                  onTap: _openMedia,
                ),
                DocumentarySections(isTv: true),
                const RealityAndTalkSections(),
                GenreListGrid(
                  isTv: true,
                  imageSource: [
                    ...widget.home.trendingTv,
                    ...widget.home.popularTv,
                    ...widget.home.topRatedTv,
                  ],
                ),
                TmdbTagListSection(
                  title: 'Catégories',
                  tags: tmdbCategoryTags,
                  isTv: true,
                ),
                TmdbTagListSection(
                  title: 'Histoires',
                  tags: tmdbPlotKeywords,
                  isTv: true,
                ),
                const MoviesFromWatchProviders(isTv: true),
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

/// The shared media hero entry point, retaining its cross-fade swipe
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
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    final heroMovies = movies.take(10).toList(growable: false);
    // Extra bottom room lets the notch/play disc overhang the hero edge.
    return SizedBox(
      width: double.infinity,
      height: heroHeight + 36,
      child: heroMovies.isEmpty
          ? const AppShimmerBlock(radius: 0)
          : AppCrossfadeCarousel(
              itemCount: heroMovies.length,
              onItemTap: (index) => onMoviePressed(heroMovies[index]),
              clipRadius: 0,
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
                      bottom: 86,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tags — bottom-left, above the title
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              if ((movie.releaseDate ?? movie.firstAirDate ?? '').length >= 4)
                                _HeroMetaChip(
                                  label: (movie.releaseDate ?? movie.firstAirDate!).substring(0, 4),
                                ),
                              if (movie.voteAverage != null)
                                _HeroMetaChip(
                                  icon: Broken.star,
                                  label: movie.voteAverage!.toStringAsFixed(1),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            movie.displayTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (movie.overview?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              movie.overview!,
                              maxLines: 3,
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
                    // Notch (half-circle cut) at the hero's bottom edge…
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -30,
                      child: Center(
                        child: AppHeroNotch(
                          backgroundColor: const Color(0xFF0B0B11),
                          ringColor: Colors.white.withValues(alpha: .55),
                        ),
                      ),
                    ),
                    // …with the play disc sitting in the cut.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -34,
                      child: Center(
                        child: AppHeroPlayButton(
                          size: 62,
                          onTap: () => onMoviePressed(movie),
                        ),
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
    this.isTv = false,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;
  final String discoverPath;
  final bool isTv;

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
                isTv: isTv,
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
                  child: PosterCard(
                    item: ContentItem.fromTmdb(media),
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
    this.isTv = false,
    super.key,
  });

  final String title;
  final List<TmdbMedia> items;
  final String? discoverPath;
  final bool isTv;

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
                      isTv: isTv,
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
              return LandscapeCard(
                item: ContentItem.fromTmdb(media),
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
/// treatment used by the media Hub: the number is part of the card, not a badge
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
              return RankedCard(
                item: ContentItem.fromTmdb(media),
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
              return LandscapeCard(
                item: ContentItem.fromTmdb(media),
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
    final usedCovers = <String>{};
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
                  // Prefer covers matched to the genre, then rotate through
                  // unused images so no two tiles share the same artwork.
                  final genreImages = imageSource
                      .where((movie) => movie.genreIds.contains(genre.id))
                      .map((movie) => movie.bannerImage ?? movie.bestCover)
                      .whereType<String>()
                      .toList(growable: false);
                  String? image;
                  if (genreImages.isNotEmpty) {
                    image = genreImages[genre.id.abs() % genreImages.length];
                  } else if (imageSource.isNotEmpty) {
                    final used = usedCovers.toSet();
                    final candidate = imageSource
                        .where((movie) =>
                            !used.contains(movie.bannerImage ?? movie.bestCover))
                        .toList(growable: false);
                    final pool = candidate.isNotEmpty ? candidate : imageSource;
                    final picked =
                        pool[(genre.id.abs() + index * 7) % pool.length];
                    image = picked.bannerImage ?? picked.bestCover;
                  }
                  if (image != null) usedCovers.add(image);
                  return AppGenreTile(
                    label: genre.name,
                    imageUrl: image,
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


class MoviesFromWatchProviders extends StatelessWidget {
  const MoviesFromWatchProviders({this.isTv = false, super.key});

  final bool isTv;

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
                              '/discover/${isTv ? 'tv' : 'movie'}?watch_region=US&with_watch_providers=${service.id}&with_watch_monetization_types=flatrate',
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

// ───────────────────────────────────────────────────────────────────────────
// Discover rails & tag sections (documentaires, téléréalité, catégories…)
// ───────────────────────────────────────────────────────────────────────────

/// Horizontal rail backed by any TMDB /discover query, with a shimmer row
/// while the request is in flight and graceful disappearance when it fails.
class AppDiscoverRail extends StatefulWidget {
  const AppDiscoverRail({
    required this.title,
    required this.query,
    this.isTv = false,
    this.landscape = true,
    super.key,
  });

  final String title;
  final String query;
  final bool isTv;
  final bool landscape;

  @override
  State<AppDiscoverRail> createState() => _AppDiscoverRailState();
}

class _AppDiscoverRailState extends State<AppDiscoverRail> {
  late Future<List<TmdbMedia>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchTmdbDiscover(isTv: widget.isTv, query: widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TmdbMedia>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <TmdbMedia>[];
        if (items.isEmpty) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasError) {
            return _DiscoverRailSkeleton(
              title: widget.title,
              landscape: widget.landscape,
            );
          }
          return const SizedBox.shrink();
        }
        final deduped = <int, TmdbMedia>{
          for (final media in items) media.id: media,
        }.values.toList(growable: false);
        final railHeight = widget.landscape
            ? 184.0
            : AppUI.horizontalCardWidth(context) * 1.5 + 62;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: widget.title),
            SizedBox(
              height: railHeight,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: AppUI.pagePadding(context),
                ),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: deduped.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final media = deduped[index];
                  final source = 'discover-${widget.title.hashCode}-$index';
                  final card = widget.landscape
                      ? LandscapeCard(
                          item: ContentItem.fromTmdb(media),
                          heroTag: tmdbHeroTag(media, source),
                          width: 238,
                          onTap: () => pushTmdbMediaDetail(
                            context,
                            media,
                            source: source,
                          ),
                        )
                      : PosterCard(
                          item: ContentItem.fromTmdb(media),
                          heroTag: tmdbHeroTag(media, source),
                          width: AppUI.horizontalCardWidth(context),
                          onTap: () => pushTmdbMediaDetail(
                            context,
                            media,
                            source: source,
                          ),
                        );
                  return SizedBox(
                    width: widget.landscape
                        ? 238
                        : AppUI.horizontalCardWidth(context),
                    child: card,
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

class _DiscoverRailSkeleton extends StatelessWidget {
  const _DiscoverRailSkeleton({required this.title, required this.landscape});

  final String title;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        SizedBox(
          height: landscape ? 184 : 210,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => SizedBox(
              width: landscape ? 238 : AppUI.horizontalCardWidth(context),
              child: const AppShimmerBlock(radius: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hub block: the documentary genre (99) plus TMDB-provided documentary
/// sub-flavours via keywords (nature, musique, sport, espace).
class DocumentarySections extends StatelessWidget {
  const DocumentarySections({this.isTv = false, super.key});

  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDiscoverRail(
          title: 'Documentaires',
          isTv: isTv,
          query: 'with_genres=99&sort_by=popularity.desc',
        ),
        for (final keyword in tmdbDocumentaryKeywords)
          AppDiscoverRail(
            title: 'Docu · ${keyword.name}',
            isTv: isTv,
            query:
                'with_genres=99&with_keywords=${keyword.id}&sort_by=popularity.desc',
          ),
      ],
    );
  }
}

/// Hub block: reality-TV, romance-reality and talk-show rails (TV genres
/// 10764, 10767 + the “love triangle” keyword that TMDB uses for dating shows).
class RealityAndTalkSections extends StatelessWidget {
  const RealityAndTalkSections({this.isTv = true, super.key});

  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDiscoverRail(
          title: 'Téléréalité',
          isTv: isTv,
          query: tmdbRealityTvQuery,
        ),
        AppDiscoverRail(
          title: "Shows d'amour",
          isTv: isTv,
          query: tmdbLoveRealityTvQuery,
        ),
        AppDiscoverRail(
          title: 'Talk-shows',
          isTv: isTv,
          query: tmdbTalkShowQuery,
        ),
      ],
    );
  }
}

/// Horizontal tag grid used by the hub “Catégories” and “Histoires” sections.
/// Each tile resolves its own representative cover from TMDB discover, so no
/// two tiles ever share the same fallback image.
class TmdbTagListSection extends StatefulWidget {
  const TmdbTagListSection({
    required this.title,
    required this.tags,
    required this.isTv,
    this.extraQuery = '',
    super.key,
  });

  final String title;
  final List<TmdbGenre> tags;
  final bool isTv;
  final String extraQuery;

  @override
  State<TmdbTagListSection> createState() => _TmdbTagListSectionState();
}

class _TmdbTagListSectionState extends State<TmdbTagListSection> {
  final Map<int, String?> _covers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCovers());
  }

  Future<void> _loadCovers() async {
    // Fetch every tag cover in parallel so the grid fills quickly.
    await Future.wait([
      for (final tag in widget.tags) _loadCover(tag.id),
    ]);
  }

  Future<void> _loadCover(int tagId) async {
    if (_covers.containsKey(tagId) || !mounted) return;
    final cover = await fetchTmdbTagPoster(
      tagId: tagId,
      isTv: widget.isTv,
      extraQuery: widget.extraQuery,
    );
    if (!mounted) return;
    setState(() => _covers[tagId] = cover);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: widget.title),
        SizedBox(
          height: 168,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: widget.tags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tag = widget.tags[index];
              return TmdbTagTile(
                tag: tag,
                isTv: widget.isTv,
                extraQuery: widget.extraQuery,
                cover: _covers[tag.id],
                onCoverNeeded: () => _loadCover(tag.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One discover tag: its own cover (fetched, never a shared fallback), a
/// deterministic accent gradient while loading, and navigation to the list.
class TmdbTagTile extends StatelessWidget {
  const TmdbTagTile({
    required this.tag,
    required this.isTv,
    required this.extraQuery,
    required this.onCoverNeeded,
    this.cover,
    super.key,
  });

  final TmdbGenre tag;
  final bool isTv;
  final String extraQuery;
  final VoidCallback onCoverNeeded;
  final String? cover;

  static const _accents = <Color>[
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFE84393),
    Color(0xFF2AA198),
    Color(0xFF8E44AD),
    Color(0xFFF39C12),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[tag.id % _accents.length];
    final path =
        '/discover/${isTv ? 'tv' : 'movie'}?with_keywords=${tag.id}${extraQuery.isEmpty ? '' : '&$extraQuery'}';
    return SizedBox(
      width: 148,
      child: Material(
        color: const Color(0xFF14161C),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onCoverNeeded();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TmdbMoviesListScreen(
                  title: tag.name,
                  path: path,
                  isTv: isTv,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                ExtendedImage.network(cover!, fit: BoxFit.cover, cache: true)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: .55),
                        const Color(0xFF0B0D10),
                      ],
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tag.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Broken.arrow_right_3,
                      color: Colors.white70,
                      size: 16,
                    ),
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
                      return PosterCard(
                        item: ContentItem.fromTmdb(media),
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

/// TMDB search kept separate from Watchtower's extension
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
            return PosterCard(
              item: ContentItem.fromTmdb(media),
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
