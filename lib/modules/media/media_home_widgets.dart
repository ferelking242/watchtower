import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/search/tmdb_search_screen.dart';
import 'package:watchtower/modules/watch/home/extension_collection_route.dart';
import 'package:watchtower/modules/watch/home/extension_person_route.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:isar_community/isar.dart';

import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/main.dart' show isar;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/media/catalog_filter_sheet.dart';
import 'package:watchtower/modules/media/overlay_filter_menu.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/extension_worker_count.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/utils/cached_network.dart';

import 'app_ui_components.dart';
import 'content_cards.dart';
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
    // Hero is drawn heroHeight tall — match it.
    final shouldShow =
        _feedController.offset >=
        heroHeight - MediaQuery.paddingOf(context).top;
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
    final search =
        widget.onSearchPressed ??
        () => context.push(
          '/flixSearch',
          extra: const FlixSearchPayload(hub: FlixSearchContext.generic),
        );
    final library = widget.onBookmarksPressed ?? () => context.push('/Library');
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
                    discoverPath: widget.isTv
                        ? '/tv/popular'
                        : '/movie/popular',
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
                    discoverPath: widget.isTv
                        ? '/tv/top_rated'
                        : '/movie/top_rated',
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
  void _openSearch(BuildContext context) => context.push(
    '/flixSearch',
    extra: const FlixSearchPayload(hub: FlixSearchContext.movies),
  );
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
    final search = widget.onSearchPressed ?? () => _openSearch(context);
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
  void _openSearch(BuildContext context) => context.push(
    '/flixSearch',
    extra: const FlixSearchPayload(hub: FlixSearchContext.series),
  );
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
    final search = widget.onSearchPressed ?? () => _openSearch(context);
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
    // Hero fills its box fully; the action column sits low but inside it.
    return SizedBox(
      width: double.infinity,
      height: heroHeight,
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
                              Image.asset(
                                'assets/app_icons/icon.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
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
                      bottom: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tags — bottom-left, above the title
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
                          // FlixQuest-style hero: rectangular Play button in
                          // the column, no centered disc/notch.
                          const SizedBox(height: 14),
                          AppHeroPlayPill(
                            onTap: () => onMoviePressed(movie),
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final media = items[index];
              final source = 'flix-landscape-${title.hashCode}-$index';
              return LandscapeCard(
                item: ContentItem.fromTmdb(media),
                heroTag: tmdbHeroTag(media, source),
                width: AppUI.landscapeCardWidth(context),
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
          height: AppUI.rankedRailHeight(context),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final media = items[index];
              final source = 'flix-ranked-${title.hashCode}-$index';
              return RankedCard(
                item: ContentItem.fromTmdb(media),
                heroTag: tmdbHeroTag(media, source),
                width: AppUI.rankedCardWidth(context),
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                        .where(
                          (movie) => !used.contains(
                            movie.bannerImage ?? movie.bestCover,
                          ),
                        )
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
                separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                separatorBuilder: (_, _) => const SizedBox(width: 12),
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => SizedBox(
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
    await Future.wait([for (final tag in widget.tags) _loadCover(tag.id)]);
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
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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

/// Actions du menu 3 points de la page « voir tout »
/// (composant AdaptiveOverlayMenu de la page Librairie).
/// Public : la recherche extension réutilise le même menu.
enum CatalogBulkDownloadAction {
  download,
  downloadAll,
  download5,
  download10,
  download25,
  download50,
  download100,
  download250,
  downloadsSubMenuHeader,
}

/// Composant partagé du menu 3 points « voir tout » : entrées du menu,
/// sélection et téléchargement en masse (progression annulable, récupération
/// des détails en parallèle). Réutilisé par l'écran de recherche extension.
abstract final class CatalogBulkDownload {
  static void handleMenu(
    BuildContext context,
    WidgetRef ref,
    Source? source,
    List<MManga> items,
    CatalogBulkDownloadAction action,
  ) {
    switch (action) {
      case CatalogBulkDownloadAction.download:
        run(context, ref, source, items, count: 10);
      case CatalogBulkDownloadAction.downloadAll:
        run(context, ref, source, items);
      case CatalogBulkDownloadAction.download5:
        run(context, ref, source, items, count: 5);
      case CatalogBulkDownloadAction.download10:
        run(context, ref, source, items, count: 10);
      case CatalogBulkDownloadAction.download25:
        run(context, ref, source, items, count: 25);
      case CatalogBulkDownloadAction.download50:
        run(context, ref, source, items, count: 50);
      case CatalogBulkDownloadAction.download100:
        run(context, ref, source, items, count: 100);
      case CatalogBulkDownloadAction.download250:
        run(context, ref, source, items, count: 250);
      case CatalogBulkDownloadAction.downloadsSubMenuHeader:
        // Titre du groupe, non actionnable.
        break;
    }
  }

  static List<PopupMenuEntry<CatalogBulkDownloadAction>> menuItems() => [
    PopupMenuItem(
      value: CatalogBulkDownloadAction.download,
      child: _menuRow(Broken.document_download, 'Télécharger'),
    ),
    PopupMenuItem(
      value: CatalogBulkDownloadAction.downloadAll,
      child: _menuRow(Broken.folder_add, 'Tout télécharger'),
    ),
    const PopupMenuDivider(),
    // Sous-options « Télécharger nb » : nb premiers éléments chargés.
    const PopupMenuItem(
      enabled: false,
      value: CatalogBulkDownloadAction.downloadsSubMenuHeader,
      child: Padding(
        padding: EdgeInsets.only(left: 26),
        child: Text(
          'Télécharger nb',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    for (final (action, count) in const [
      (CatalogBulkDownloadAction.download5, 5),
      (CatalogBulkDownloadAction.download10, 10),
      (CatalogBulkDownloadAction.download25, 25),
      (CatalogBulkDownloadAction.download50, 50),
      (CatalogBulkDownloadAction.download100, 100),
      (CatalogBulkDownloadAction.download250, 250),
    ])
      PopupMenuItem(
        value: action,
        child: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: _menuRow(Broken.arrow_right_2, '$count éléments'),
        ),
      ),
  ];

  /// Same menu as [menuItems] without the download entries, for surfaces that
  /// show a three-dot button but queue nothing (extension person pages).
  static List<PopupMenuEntry<CatalogBulkDownloadAction>> selectionMenuItems() =>
      [
        PopupMenuItem(
          value: CatalogBulkDownloadAction.downloadsSubMenuHeader,
          enabled: false,
          child: _menuRow(Broken.folder_add, 'Sélection'),
        ),
      ];

  static Widget _menuRow(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(label),
    ],
  );

  /// Récupère les vidéos du lot en parallèle (pool de créateurs), avec une
  /// boîte de progression annulable ; chaque chapitre est mis en file.
  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    Source? source,
    List<MManga> catalogueItems, {
    int? count,
  }) async {
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Téléchargement disponible uniquement pour les catalogues d’extension.',
          ),
        ),
      );
      return;
    }
    final targets = [
      for (final item in count == null ? catalogueItems : catalogueItems.take(count))
        if (item.link?.trim().isNotEmpty == true &&
            ExtensionCollectionRoute.fromItem(item) == null)
          item,
    ];
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élément téléchargeable.')),
      );
      return;
    }

    final progress = ValueNotifier<_BulkDownloadProgress>(
      _BulkDownloadProgress(total: targets.length),
    );
    BuildContext? dialogContext;
    void closeDialog() {
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return _BulkDownloadProgressDialog(
          progress: progress,
          onCancel: () => progress.value = progress.value.cancel(),
        );
      },
    );

    // Pool de travailleurs : récupère les détails de plusieurs items en
    // parallèle, arrête de prendre de nouveaux items dès l'annulation.
    final concurrency = getRecommendedExtensionWorkerCount();
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        if (progress.value.cancelled || nextIndex >= targets.length) return;
        final index = nextIndex++;
        try {
          final chapters = await _enqueueItemDownloads(ref, source, targets[index]);
          progress.value = progress.value.withResult(queued: chapters, done: 1);
        } catch (_) {
          progress.value = progress.value.withResult(failed: 1, done: 1);
        }
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < concurrency; i++) worker(),
      ]);
      ref.read(processDownloadsProvider());
    } finally {
      final finalProgress = progress.value;
      final remaining = targets.length - finalProgress.done;
      closeDialog();
      progress.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalProgress.cancelled
                  ? 'Annulé · ${finalProgress.queued} ajouté(s), '
                      '${finalProgress.failed} échec(s), $remaining restant(s).'
                  : finalProgress.failed == 0
                  ? 'Téléchargements ajoutés à la file : '
                      '${finalProgress.queued}.'
                  : '${finalProgress.queued} téléchargement(s) mis en file, '
                      '${finalProgress.failed} échec(s).',
            ),
          ),
        );
      }
    }
  }

  /// Récupère les vidéos d'un item (getDetail), crée l'entrée Isar
  /// (même chemin que la route « personnes ») et met chaque chapitre en file.
  static Future<int> _enqueueItemDownloads(
    WidgetRef ref,
    Source source,
    MManga item,
  ) async {
    final url = item.link!.trim();
    final detail = await ref.read(
      getDetailProvider(url: url, source: source).future,
    );
    final mangaCandidates = isar.mangas
        .filter()
        .sourceIdEqualTo(source.id)
        .findAllSync();
    Manga? existing;
    for (final candidate in mangaCandidates) {
      if (candidate.link == url) {
        existing = candidate;
        break;
      }
    }
    final name =
        item.name?.trim().isNotEmpty == true
            ? item.name!.trim()
            : (detail.name ?? url);
    final loaded =
        existing ??
        Manga(
          source: source.name ?? '',
          author: detail.author ?? '',
          artist: detail.artist ?? '',
          genre: detail.genre ?? item.genre,
          imageUrl: detail.imageUrl ?? item.imageUrl,
          lang: source.lang ?? '',
          link: url,
          name: name,
          status: Status.unknown,
          description: detail.description ?? '',
          sourceId: source.id,
          itemType: source.itemType,
          isManga: source.itemType == ItemType.manga,
        );
    final existingChapters = loaded.id == Isar.autoIncrement
        ? <Chapter>[]
        : isar.chapters.filter().mangaIdEqualTo(loaded.id).findAllSync();
    final chaptersByUrl = <String, Chapter>{
      for (final chapter in existingChapters)
        if (chapter.url?.trim().isNotEmpty == true)
          chapter.url!.trim(): chapter,
    };
    final queue = <Chapter>[];
    isar.writeTxnSync(() {
      loaded.id = isar.mangas.putSync(loaded);
      for (final video in detail.chapters ?? const <MChapter>[]) {
        final videoUrl = video.url?.trim();
        if (videoUrl == null || videoUrl.isEmpty) continue;
        final chapter =
            chaptersByUrl[videoUrl] ??
            Chapter(
              mangaId: loaded.id,
              name: video.name?.trim().isNotEmpty == true
                  ? video.name!.trim()
                  : videoUrl,
              url: videoUrl,
              thumbnailUrl: video.thumbnailUrl ?? loaded.imageUrl,
              dateUpload: video.dateUpload,
              scanlator: video.scanlator,
            );
        chapter.manga.value = loaded;
        chapter.id = isar.chapters.putSync(chapter);
        queue.add(chapter);
      }
    });
    if (queue.isEmpty) return 0;
    for (final chapter in queue) {
      await ref.read(addDownloadToQueueProvider(chapter: chapter).future);
      if (chapter.id != null) {
        ref
            .read(downloadQueueStateProvider.notifier)
            .setPaused(chapter.id!, false);
      }
    }
    return queue.length;
  }
}

class TmdbMoviesListScreen extends ConsumerStatefulWidget {
  const TmdbMoviesListScreen({
    required this.title,
    required this.path,
    this.initialItems = const [],
    this.isTv = false,
    this.extensionSource,
    this.extensionSectionId,
    this.initialExtensionItems = const [],
    this.cardStyle,
    this.seeAllPage,
    this.anilistFilter,
    this.initialAnilistItems = const [],
    this.onOpenAnilist,
    super.key,
  });

  const TmdbMoviesListScreen.extension({
    required this.title,
    required Source source,
    required String sectionId,
    this.initialExtensionItems = const [],
    this.cardStyle,
    this.seeAllPage,
    super.key,
  }) : path = '',
       initialItems = const [],
       isTv = false,
       extensionSource = source,
       extensionSectionId = sectionId,
       anilistFilter = null,
       initialAnilistItems = const [],
       onOpenAnilist = null;

  /// Paginated destination for an AniList filter. Reuses the same catalogue
  /// shell (sort/filter sheet, infinite scroll, grid) as the film/série
  /// "see all" page so every hub shares one implementation.
  const TmdbMoviesListScreen.anilist({
    required this.title,
    required AnilistBrowseFilter filter,
    this.initialAnilistItems = const [],
    this.cardStyle,
    this.seeAllPage,
    this.onOpenAnilist,
    super.key,
  }) : path = '',
       initialItems = const [],
       isTv = false,
       extensionSource = null,
       extensionSectionId = null,
       initialExtensionItems = const [],
       anilistFilter = filter;

  final String title;
  final String path;
  final List<TmdbMedia> initialItems;
  final bool isTv;
  final Source? extensionSource;
  final String? extensionSectionId;
  final List<MManga> initialExtensionItems;
  final String? cardStyle;

  /// Layout hint for this page, read from the section that opened it (see
  /// `UiSection.seeAllPage`). `tags` renders a two-column grid of large,
  /// cover-first tag cards.
  final String? seeAllPage;

  /// When set, the screen pages through AniList instead of TMDB/extensions.
  final AnilistBrowseFilter? anilistFilter;
  final List<AnilistMedia> initialAnilistItems;

  /// Opens a tapped AniList media. Falls back to the AniList detail route.
  final ValueChanged<AnilistMedia>? onOpenAnilist;

  @override
  ConsumerState<TmdbMoviesListScreen> createState() =>
      _TmdbMoviesListScreenState();
}

class _TmdbMoviesListScreenState extends ConsumerState<TmdbMoviesListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final List<TmdbMedia> _movies;
  late final List<MManga> _extensionItems;
  late final List<AnilistMedia> _anilistItems;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  late CatalogFilterState _filter;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _filter = CatalogFilterState(
      sortMode: switch (widget.anilistFilter?.sort) {
        'SCORE_DESC' => 'rating',
        'TRENDING_DESC' => 'trending',
        'START_DATE_DESC' => 'newest',
        'TITLE_ROMAJI' => 'title',
        'FAVOURITES_DESC' => 'favorites',
        _ => 'popular',
      },
    )..layout = CatalogLayout.grid;
    _movies = [...widget.initialItems];
    _extensionItems = [...widget.initialExtensionItems];
    _anilistItems = [...widget.initialAnilistItems];
    _scrollController.addListener(_onScroll);
    if (_isAnilist) {
      if (_anilistItems.isNotEmpty) {
        _page = 2;
      } else {
        _loadPage();
      }
    } else if (_isExtension) {
      if (_extensionItems.isNotEmpty) {
        _page = 2;
      } else {
        _loadPage();
      }
    } else if (_movies.isEmpty) {
      _loadPage();
    } else {
      _page = 2;
    }
  }

  bool get _isExtension =>
      widget.extensionSource != null && widget.extensionSectionId != null;

  bool get _isAnilist => widget.anilistFilter != null;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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
      if (_isAnilist) {
        final filter = widget.anilistFilter!.copyWith(
          page: _page,
          sort: _anilistSortFor(_filter.sortMode),
        );
        final result = await ref.read(anilistBrowseProvider(filter).future);
        if (!mounted) return;
        final seen = {for (final item in _anilistItems) item.id};
        final nextItems = result.items
            .where((item) => seen.add(item.id))
            .toList(growable: false);
        setState(() {
          _anilistItems.addAll(nextItems);
          _hasMore = result.hasNextPage;
          _page = result.currentPage + 1;
          _loading = false;
        });
        return;
      }
      if (_isExtension) {
        final result = await _fetchExtensionPage(_page);
        if (!mounted) return;
        final seen = {
          for (final item in _extensionItems)
            item.link ?? item.name ?? '${item.hashCode}',
        };
        final nextItems = (result?.list ?? const <MManga>[])
            .where(
              (item) => seen.add(item.link ?? item.name ?? '${item.hashCode}'),
            )
            .toList(growable: false);
        setState(() {
          _extensionItems.addAll(nextItems);
          _hasMore = result?.hasNextPage ?? false;
          if (nextItems.isNotEmpty) _page++;
          _loading = false;
        });
        return;
      }
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

  Future<MPages?> _fetchExtensionPage(int page) {
    final source = widget.extensionSource!;
    final sectionId = widget.extensionSectionId!;
    return switch (sectionId) {
      'popular' => ref.read(
        getPopularProvider(source: source, page: page).future,
      ),
      'latest' => ref.read(
        getLatestUpdatesProvider(source: source, page: page).future,
      ),
      _ => ref.read(
        getCustomListProvider(
          source: source,
          listId: sectionId,
          page: page,
        ).future,
      ),
    };
  }

  String? _anilistSortFor(String sortMode) => switch (sortMode) {
    'rating' => 'SCORE_DESC',
    'title' => 'TITLE_ROMAJI',
    'trending' => 'TRENDING_DESC',
    'newest' => 'START_DATE_DESC',
    'favorites' => 'FAVOURITES_DESC',
    _ => 'POPULARITY_DESC',
  };

  // ── Feuille de filtres multi-niveaux (composant partagé avec la Librairie) ──

  List<CatalogTypeOption> get _typeOptions =>
      _isAnilist
          ? const [
              CatalogTypeOption('Tout', 'all'),
              CatalogTypeOption('Anime', 'anime'),
              CatalogTypeOption('Manga', 'manga'),
            ]
          : const [
              CatalogTypeOption('Tout', 'all'),
              CatalogTypeOption('Film', 'movie'),
              CatalogTypeOption('Série', 'tv'),
              CatalogTypeOption('Animation', 'animation'),
              CatalogTypeOption('Documentaire', 'documentaire'),
              CatalogTypeOption('Téléfilm', 'telefilm'),
            ];

  List<CatalogSortOption> get _sortOptions =>
      _isAnilist
          ? const [
              CatalogSortOption('Populaire', 'popular'),
              CatalogSortOption('Mieux notés', 'rating'),
              CatalogSortOption('Tendance', 'trending'),
              CatalogSortOption('Nouveautés', 'newest'),
              CatalogSortOption('Favoris', 'favorites'),
              CatalogSortOption('A — Z', 'title'),
            ]
          : _isExtension
          ? const [
              CatalogSortOption('Populaire', 'popular'),
              CatalogSortOption('A — Z', 'title'),
            ]
          : const [
              CatalogSortOption('Populaire', 'popular'),
              CatalogSortOption('Mieux notés', 'rating'),
              CatalogSortOption('A — Z', 'title'),
            ];

  List<String> get _fixedGenreOptions {
    if (_isAnilist) {
      return const [
        'Action',
        'Aventure',
        'Comédie',
        'Drame',
        'Ecchi',
        'Fantasy',
        'Horror',
        'Mahou Shoujo',
        'Mecha',
        'Music',
        'Mystery',
        'Psychological',
        'Romance',
        'Sci-Fi',
        'Slice of Life',
        'Sports',
        'Supernatural',
        'Thriller',
      ];
    }
    // TMDB : les libellés FR des maps de genres, films et séries confondus.
    return {...tmdbGenreNamesById.values}.toList()..sort();
  }

  List<String> _extensionGenreOptions() {
    final names = <String>{};
    for (final item in _extensionItems) {
      for (final genre in item.genre ?? const <String>[]) {
        if (genre.trim().isNotEmpty) names.add(genre.trim());
      }
    }
    return names.toList()..sort();
  }

  Widget _buildFilterButton() {
    return AdaptiveOverlayMenuButton(
      menuWidth: 300,
      trigger: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          Broken.filter,
          color: _filter.isDefault ? null : Colors.orange,
        ),
      ),
      contentBuilder: (close) => CatalogFilterOverlay(
        initial: _filter,
        typeOptions: _typeOptions,
        sortOptions: _sortOptions,
        genreOptions:
            _isExtension ? _extensionGenreOptions() : _fixedGenreOptions,
        showTypeSection: !_isExtension,
        showYearsSection: !_isExtension,
        showRatingSection: !_isExtension,
        close: close,
        onChanged: (value) => setState(() => _filter = value),
      ),
    );
  }

  // ── Menu 3 points (même composant que la barre de la page Librairie) ──────

  void _onListMenuAction(CatalogBulkDownloadAction action) {
    CatalogBulkDownload.handleMenu(
      context,
      ref,
      widget.extensionSource,
      _extensionItems,
      action,
    );
  }

  /// Récupère les vidéos du lot en parallèle (pool de créateurs), avec une
  /// boîte de progression annulable ; chaque chapitre est mis en file.
  Future<void> _bulkDownload({int? count}) => CatalogBulkDownload.run(
    context,
    ref,
    widget.extensionSource,
    _extensionItems,
    count: count,
  );

  // ── Filtres appliqués aux items affichés ─────────────────────────────────

  int? _tmdbYearOf(TmdbMedia media) {
    final raw = media.releaseDate ?? media.firstAirDate;
    if (raw == null || raw.length < 4) return null;
    return int.tryParse(raw.substring(0, 4));
  }

  bool _tmdbMatches(TmdbMedia media) {
    final f = _filter;
    if (f.type != 'all' &&
        !(switch (f.type) {
          'movie' => media.mediaType == 'movie',
          'tv' => media.mediaType == 'tv',
          'animation' => media.genreIds.contains(16),
          'documentaire' => media.genreIds.contains(99),
          'telefilm' => media.mediaType == 'movie' &&
              media.genreIds.contains(10770),
          _ => true,
        })) {
      return false;
    }
    if (!f.matchesYears(_tmdbYearOf(media))) return false;
    if (f.minRating > 0 && (media.voteAverage ?? 0) < f.minRating) return false;
    if (f.genres.isNotEmpty) {
      if (!f.matchesGenres([
        for (final id in media.genreIds)
          tmdbMovieGenreName(id) != 'Autre'
              ? tmdbMovieGenreName(id)
              : tmdbTvGenreName(id),
      ])) {
        return false;
      }
    }
    return true;
  }

  bool _anilistMatches(AnilistMedia media) {
    final f = _filter;
    if (f.type != 'all' && f.type != media.type.toLowerCase()) return false;
    if (!f.matchesYears(media.seasonYear)) return false;
    if (f.minRating > 0 && (media.averageScore ?? 0) / 10 < f.minRating) {
      return false;
    }
    if (!f.matchesGenres(media.genres)) return false;
    return true;
  }

  List<TmdbMedia> get _sortedMovies {
    var items = _movies.where(_tmdbMatches).toList();
    switch (_filter.sortMode) {
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

  List<MManga> get _sortedExtensionItems {
    final f = _filter;
    final items = _extensionItems
        .where((item) => f.matchesGenres(item.genre ?? const <String>[]))
        .toList();
    if (f.sortMode == 'title') {
      items.sort(
        (a, b) => (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        ),
      );
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
    final extensionItems = _sortedExtensionItems;
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
          _buildFilterButton(),
          // Menu 3 points, même composant glass que la Librairie.
          AdaptiveOverlayMenu<CatalogBulkDownloadAction>(
            tooltip: isFrench ? 'Options' : 'Options',
            icon: const Icon(Broken.more_2),
            menuWidth: 240,
            onSelected: _onListMenuAction,
            itemBuilder: (_) => CatalogBulkDownload.menuItems(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isAnilist
          ? _buildAnilistBody(_anilistItems)
          : _isExtension
          ? _buildExtensionBody(extensionItems)
          : _error != null && movies.isEmpty
          ? _CatalogError(title: widget.title, onRetry: _loadPage)
          : movies.isEmpty && _loading
          ? const AppMediaGridShimmer()
          : _buildMoviesBody(movies, isFrench),
    );
  }

  Widget _buildMoviesBody(List<TmdbMedia> movies, bool isFrench) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Text(
        isFrench ? 'Les plus populaires' : 'Most Popular',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (_filter.layout == CatalogLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: movies.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= movies.length) {
                  return const AppShimmerBlock(radius: 14);
                }
                final media = movies[index];
                final source = 'flix-catalog-$index';
                return _CatalogListRow(
                  posterUrl: media.bestCover,
                  title: media.displayTitle,
                  metadata: _tmdbRowMetadata(media),
                  onTap: () =>
                      pushTmdbMediaDetail(context, media, source: source),
                );
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            gridDelegate: _catalogGridDelegate(
              context,
              childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
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
    );
  }

  /// Délégation de grille tenant compte du choix « Affichage » : grille
  /// normale, ou grille plus aérée (une colonne de moins) avant la liste.
  SliverGridDelegateWithFixedCrossAxisCount _catalogGridDelegate(
    BuildContext context, {
    required double childAspectRatio,
    double crossAxisSpacing = AppUI.mediaGridCrossAxisSpacing,
    double mainAxisSpacing = 16,
  }) {
    final columns = AppUI.mediaGridColumns(context);
    final count = _filter.layout == CatalogLayout.comfortable
        ? (columns - 1).clamp(1, columns)
        : columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  String? _tmdbRowMetadata(TmdbMedia media) {
    final parts = <String?>[
      _tmdbYearOf(media)?.toString(),
      media.voteAverage != null
          ? '★ ${media.voteAverage!.toStringAsFixed(1)}'
          : null,
    ];
    final line = parts.whereType<String>().join(' · ');
    return line.isEmpty ? null : line;
  }

  String? _anilistRowMetadata(AnilistMedia media) {
    final line = [
      media.seasonYear?.toString(),
      media.averageScore != null
          ? '★ ${(media.averageScore! / 10).toStringAsFixed(1)}'
          : null,
    ].whereType<String>().join(' · ');
    return line.isEmpty ? null : line;
  }

  String? _extensionRowMetadata(MManga item) {
    final line = [
      switch (item.status) {
        Status.ongoing => 'En cours',
        Status.completed => 'Terminé',
        Status.onHiatus => 'En pause',
        Status.canceled => 'Abandonné',
        Status.publishingFinished => 'Terminé',
        _ => null,
      },
      item.genre
          ?.where((g) => g.trim().isNotEmpty)
          .take(3)
          .map((g) => g.trim())
          .join(' · '),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
    return line.isEmpty ? null : line;
  }

  Future<void> _refreshAnilist() async {
    setState(() {
      _anilistItems.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadPage();
  }

  Widget _buildAnilistBody(List<AnilistMedia> items) {
    if (_error != null && items.isEmpty) {
      return _CatalogError(title: widget.title, onRetry: _loadPage);
    }
    if (items.isEmpty && _loading) return const AppMediaGridShimmer();
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun résultat', style: TextStyle(color: Colors.white70)),
      );
    }

    final visible = items.where(_anilistMatches).toList();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Aucun résultat pour ces filtres',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final isTagGrid = widget.cardStyle == 'tag';
    final isLandscapeGrid = widget.cardStyle == 'landscape';
    final open = widget.onOpenAnilist;
    void onTap(AnilistMedia media) {
      if (open != null) {
        open(media);
      } else {
        context.push('/anilistDetail', extra: media);
      }
    }

    if (_filter.layout == CatalogLayout.list) {
      return RefreshIndicator(
        onRefresh: _refreshAnilist,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            12,
            AppUI.pagePadding(context),
            110,
          ),
          itemCount: visible.length + (_loading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= visible.length) {
              return const AppShimmerBlock(radius: AppUI.cardRadius);
            }
            final media = visible[index];
            final item = ContentItem.fromAnilist(media);
            return _CatalogListRow(
              posterUrl: item.posterUrl,
              title: item.title,
              metadata: _anilistRowMetadata(media),
              onTap: () => onTap(media),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAnilist,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          12,
          AppUI.pagePadding(context),
          110,
        ),
        gridDelegate: _catalogGridDelegate(
          context,
          childAspectRatio: isTagGrid
              ? 2.6
              : isLandscapeGrid
              ? 1.25
              : AppUI.mediaGridChildAspectRatio(context),
        ),
        itemCount: visible.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return const AppShimmerBlock(radius: AppUI.cardRadius);
          }
          final media = visible[index];
          final item = ContentItem.fromAnilist(media);
          if (isTagGrid) {
            return TagCard(item: item, onTap: () => onTap(media));
          }
          if (isLandscapeGrid) {
            return LandscapeCard(
              item: item,
              width: double.infinity,
              onTap: () => onTap(media),
            );
          }
          return PosterCard(
            item: item,
            width: double.infinity,
            showMediaMetadata: true,
            onTap: () => onTap(media),
          );
        },
      ),
    );
  }

  Widget _buildExtensionBody(List<MManga> items) {
    if (_error != null && items.isEmpty) {
      return _CatalogError(title: widget.title, onRetry: _loadPage);
    }
    if (items.isEmpty && _loading) return const AppMediaGridShimmer();
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun résultat', style: TextStyle(color: Colors.white70)),
      );
    }

    final isTagGrid =
        widget.cardStyle == 'tag' || widget.cardStyle == 'thumbnail';
    final isLandscapeGrid = widget.cardStyle == 'landscape';

    if (_filter.layout == CatalogLayout.list) {
      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          12,
          AppUI.pagePadding(context),
          110,
        ),
        itemCount: items.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const AppShimmerBlock(radius: AppUI.cardRadius);
          }
          final item = items[index];
          return _CatalogListRow(
            posterUrl: item.imageUrl,
            title: item.name ?? item.link ?? 'Sans titre',
            metadata: _extensionRowMetadata(item),
            onTap: () => _openExtensionItem(item),
          );
        },
      );
    }

    // A tag index opened from a "see all" tile gets its own presentation: two
    // large cards per row so the borrowed cover stays readable, instead of the
    // three narrow tiles the home rail uses. Any extension reaches this page by
    // setting `seeAllPage: "tags"` on the section.
    final tagPage = widget.seeAllPage == 'tags';
    if (tagPage) {
      return GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          12,
          AppUI.pagePadding(context),
          110,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const AppShimmerBlock(radius: AppUI.cardRadius);
          }
          final item = items[index];
          return TagCard(
            item: ContentItem.fromManga(item),
            width: double.infinity,
            height: 132,
            onTap: () => _openExtensionItem(item),
          );
        },
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        110,
      ),
      gridDelegate: _catalogGridDelegate(
        context,
        childAspectRatio: isTagGrid
            ? 2.6
            : isLandscapeGrid
            ? 1.25
            : AppUI.mediaGridChildAspectRatio(context),
      ),
      itemCount: items.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const AppShimmerBlock(radius: AppUI.cardRadius);
        }
        final item = items[index];
        if (isTagGrid) {
          return TagCard(
            item: ContentItem.fromManga(item),
            onTap: () => _openExtensionItem(item),
          );
        }
        if (isLandscapeGrid) {
          return LandscapeCard(
            item: ContentItem.fromManga(item),
            width: double.infinity,
            onTap: () => _openExtensionItem(item),
          );
        }
        return PosterCard(
          item: ContentItem.fromManga(item),
          width: double.infinity,
          onTap: () => _openExtensionItem(item),
        );
      },
    );
  }

  void _openExtensionItem(MManga item) {
    final collection = ExtensionCollectionRoute.fromItem(item);
    if (collection == null && isExtensionPersonItem(item)) {
      openExtensionPersonScreen(
        context: context,
        source: widget.extensionSource!,
        item: item,
      );
      return;
    }
    if (collection != null) {
      if (collection.listId.startsWith('playlist_')) {
        _openFirstFromCollection(collection.listId);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TmdbMoviesListScreen.extension(
            title: item.name?.trim().isNotEmpty == true
                ? item.name!.trim()
                : 'Collection',
            source: widget.extensionSource!,
            sectionId: collection.listId,
            cardStyle: collection.listId.startsWith('search_')
                ? 'landscape'
                : null,
          ),
        ),
      );
      return;
    }
    if (item.link?.trim().isNotEmpty != true) return;
    pushToMangaReaderDetail(
      ref: ref,
      context: context,
      getManga: item,
      lang: widget.extensionSource!.lang ?? '',
      source: widget.extensionSource!.name ?? '',
      sourceId: widget.extensionSource!.id,
      itemType: widget.extensionSource!.itemType,
    );
  }

  Future<void> _openFirstFromCollection(String listId) async {
    final source = widget.extensionSource!;
    final result = await ref.read(
      getCustomListProvider(source: source, listId: listId, page: 1).future,
    );
    if (!mounted) return;
    final first = result?.list.cast<MManga?>().firstWhere(
      (item) => item?.link?.trim().isNotEmpty == true,
      orElse: () => null,
    );
    if (first != null) _openExtensionItem(first);
  }
}

/// État du téléchargement en masse de la page « voir tout » (immuable,
/// chaque étape émet une copie dans le ValueNotifier).
class _BulkDownloadProgress {
  const _BulkDownloadProgress({
    required this.total,
    this.done = 0,
    this.queued = 0,
    this.failed = 0,
    this.cancelled = false,
  });

  final int total;
  final int done;
  final int queued;
  final int failed;
  final bool cancelled;

  _BulkDownloadProgress cancel() => _BulkDownloadProgress(
    total: total,
    done: done,
    queued: queued,
    failed: failed,
    cancelled: true,
  );

  _BulkDownloadProgress withResult({int queued = 0, int failed = 0, int done = 0}) =>
      _BulkDownloadProgress(
        total: total,
        done: this.done + done,
        queued: this.queued + queued,
        failed: this.failed + failed,
        cancelled: cancelled,
      );
}

/// Boîte de progression du téléchargement en masse : barre déterminée,
/// compteurs, et bouton Annuler (les travailleurs s'arrêtent en douceur).
class _BulkDownloadProgressDialog extends StatelessWidget {
  const _BulkDownloadProgressDialog({
    required this.progress,
    required this.onCancel,
  });

  final ValueNotifier<_BulkDownloadProgress> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Mise en file des téléchargements',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ValueListenableBuilder<_BulkDownloadProgress>(
        valueListenable: progress,
        builder: (context, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: p.cancelled || p.total == 0
                    ? null
                    : (p.done / p.total).clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                color: Colors.orange,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.cancelled ? 'Annulation…' : '${p.done}/${p.total} éléments',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (p.queued > 0 || p.failed > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${p.queued} vidéo(s) ajoutée(s)'
                '${p.failed > 0 ? ' · ${p.failed} échec(s)' : ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            'Annuler',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

/// Ligne « affichage liste » de la page « voir tout » (affiche, titre, méta).
class _CatalogListRow extends StatelessWidget {
  const _CatalogListRow({
    required this.posterUrl,
    required this.title,
    required this.metadata,
    required this.onTap,
    super.key,
  });

  final String? posterUrl;
  final String title;
  final String? metadata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: posterUrl == null
                  ? Container(
                      width: 62,
                      height: 92,
                      color: Colors.white10,
                      child: const Icon(
                        Broken.image,
                        color: Colors.white24,
                        size: 22,
                      ),
                    )
                  : cachedNetworkImage(
                      imageUrl: posterUrl!,
                      width: 62,
                      height: 92,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(
                        Broken.image,
                        color: Colors.white24,
                        size: 22,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (metadata != null && metadata!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Broken.arrow_right_2, size: 18, color: Colors.white38),
          ],
        ),
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
