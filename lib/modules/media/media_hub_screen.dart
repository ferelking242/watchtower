import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';

enum MediaHubKind { movies, series }

class FlixMediaHomeScreen extends ConsumerWidget {
  final MediaHubKind kind;

  const FlixMediaHomeScreen({super.key, required this.kind});

  bool get isMovies => kind == MediaHubKind.movies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    final title = isMovies ? 'Movies' : 'Series';
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MediaError(title: title, error: error),
        data: (data) => isMovies
            ? _MovieHomeBody(home: data)
            : _MediaHomeBody(kind: kind, home: data),
      ),
    );
  }
}

class _MediaHomeBody extends StatelessWidget {
  final MediaHubKind kind;
  final TmdbHome home;

  const _MediaHomeBody({required this.kind, required this.home});

  bool get isMovies => kind == MediaHubKind.movies;

  List<TmdbMedia> get trending =>
      isMovies ? home.trendingMovies : home.trendingTv;
  List<TmdbMedia> get popular => isMovies ? home.popularMovies : home.popularTv;
  List<TmdbMedia> get topRated =>
      isMovies ? home.topRatedMovies : home.topRatedTv;
  List<TmdbMedia> get latest =>
      isMovies ? home.nowPlayingMovies : home.airingTodayTv;

  @override
  Widget build(BuildContext context) {
    final hero = trending.firstOrNull ?? popular.firstOrNull;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _MediaHero(
            title: isMovies ? 'Home Movies' : 'Home Series',
            media: hero,
            onOpen: hero == null
                ? null
                : () => context.push('/flixMediaDetail', extra: hero),
          ),
        ),
        SliverToBoxAdapter(child: _MediaTabs(kind: kind)),
        _MediaRow(
          title: 'Trending',
          items: trending,
          accent: const Color(0xFFE50914),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: isMovies ? 'Films populaires' : 'Séries populaires',
          items: popular,
          accent: const Color(0xFFFFB703),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: isMovies ? 'Nouveautés' : 'À suivre aujourd’hui',
          items: latest,
          accent: const Color(0xFF4CC9F0),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: 'Les mieux notés',
          items: topRated,
          accent: const Color(0xFFB5179E),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 92)),
      ],
    );
  }
}

class _MovieHomeBody extends ConsumerStatefulWidget {
  final TmdbHome home;

  const _MovieHomeBody({required this.home});

  @override
  ConsumerState<_MovieHomeBody> createState() => _MovieHomeBodyState();
}

class _MovieHomeBodyState extends ConsumerState<_MovieHomeBody> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _bookmarkedIds = <int>{};
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!mounted) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .48)
        .clamp(410.0, 500.0)
        .toDouble();
    final threshold = heroHeight - MediaQuery.paddingOf(context).top;
    final shouldShow = _scrollController.offset >= threshold;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  void _openMedia(TmdbMedia media) {
    context.push('/flixMediaDetail', extra: media);
  }

  void _toggleBookmark(TmdbMedia media) {
    setState(() {
      if (!_bookmarkedIds.add(media.id)) {
        _bookmarkedIds.remove(media.id);
      }
    });
  }

  List<TmdbMedia> _heroItems() {
    final result = <TmdbMedia>[];
    final seen = <int>{};
    for (final media in [...widget.home.trendingMovies, ...widget.home.popularMovies]) {
      if ((media.bannerImage != null || media.bestCover != null) &&
          seen.add(media.id)) {
        result.add(media);
      }
      if (result.length == 10) break;
    }
    return result;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroItems = _heroItems();
    final sections = <Widget>[
      _MovieRow(
        title: 'Popular',
        items: widget.home.popularMovies,
        onTap: _openMedia,
      ),
      _MovieRow(
        title: 'Tendances cette semaine',
        items: widget.home.trendingMovies,
        onTap: _openMedia,
      ),
      _MovieRow(
        title: 'Les mieux notés',
        items: widget.home.topRatedMovies,
        onTap: _openMedia,
      ),
      _MovieRow(
        title: 'Films en cours',
        items: widget.home.nowPlayingMovies,
        onTap: _openMedia,
      ),
      _MovieRow(
        title: 'Prochainement',
        items: widget.home.upcomingMovies,
        onTap: _openMedia,
      ),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tmdbHomeProvider);
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          color: const Color(0xFFFF7A00),
          backgroundColor: const Color(0xFF171717),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _MovieHeroCarousel(
                  items: heroItems,
                  bookmarkedIds: _bookmarkedIds,
                  onOpen: _openMedia,
                  onToggleBookmark: _toggleBookmark,
                ),
              ),
              ...sections,
              const SliverToBoxAdapter(child: SizedBox(height: 112)),
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
                child: const _MovieCompactHeader(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MovieHeroCarousel extends StatefulWidget {
  final List<TmdbMedia> items;
  final Set<int> bookmarkedIds;
  final ValueChanged<TmdbMedia> onOpen;
  final ValueChanged<TmdbMedia> onToggleBookmark;

  const _MovieHeroCarousel({
    required this.items,
    required this.bookmarkedIds,
    required this.onOpen,
    required this.onToggleBookmark,
  });

  @override
  State<_MovieHeroCarousel> createState() => _MovieHeroCarouselState();
}

class _MovieHeroCarouselState extends State<_MovieHeroCarousel> {
  PageController? _pageController;
  Timer? _autoPlayTimer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.items.length > 1) {
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!mounted || !_pageController!.hasClients) return;
        final next = (_page + 1) % widget.items.length;
        _pageController!.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .48)
        .clamp(410.0, 500.0)
        .toDouble();
    if (widget.items.isEmpty) {
      return SizedBox(
        height: heroHeight,
        child: const ColoredBox(color: Color(0xFF111111)),
      );
    }

    return SizedBox(
      height: heroHeight,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (value) => setState(() => _page = value),
        itemBuilder: (context, index) {
          final media = widget.items[index];
          final year = media.releaseDate ?? media.firstAirDate;
          final isBookmarked = widget.bookmarkedIds.contains(media.id);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (media.bannerImage != null)
                ExtendedImage.network(
                  media.bannerImage!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  cache: true,
                )
              else if (media.bestCover != null)
                ExtendedImage.network(
                  media.bestCover!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  cache: true,
                )
              else
                const ColoredBox(color: Color(0xFF111111)),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/moviebox-logo.svg',
                            width: 28,
                            height: 28,
                          ),
                          const Spacer(),
                          _MovieHeroLiveButton(
                            onPressed: () => context.push('/liveTv'),
                          ),
                          const SizedBox(width: 8),
                          _MovieHeroIconButton(
                            icon: isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            onPressed: () => widget.onToggleBookmark(media),
                            tooltip: 'Bookmark',
                          ),
                          const SizedBox(width: 8),
                          _MovieHeroIconButton(
                            icon: Icons.search_rounded,
                            onPressed: () => context.push('/globalSearch'),
                            tooltip: 'Search',
                          ),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                media.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                [
                                  if (year != null && year.isNotEmpty)
                                    year.split('-').first,
                                  if (media.voteAverage != null)
                                    '★ ${media.voteAverage!.toStringAsFixed(1)}',
                                  if (media.originalLanguage?.isNotEmpty == true)
                                    media.originalLanguage!.toUpperCase(),
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
                                    onPressed: () => widget.onOpen(media),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('WATCH NOW'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF7A00),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        widget.onToggleBookmark(media),
                                    icon: Icon(
                                      isBookmarked
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                    ),
                                    label: const Text('Bookmark'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white70,
                                      ),
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
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.items.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.items.length,
                      (dot) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: dot == _page ? 18 : 6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dot == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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

class _MovieHeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _MovieHeroIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

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

class _MovieHeroLiveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MovieHeroLiveButton({required this.onPressed});

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

class _MovieRow extends StatelessWidget {
  final String title;
  final List<TmdbMedia> items;
  final ValueChanged<TmdbMedia> onTap;

  const _MovieRow({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final cardWidth = ((MediaQuery.sizeOf(context).width - 60) / 4)
        .clamp(86.0, 112.0)
        .toDouble();
    final rowHeight = cardWidth * 1.5 + 54;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: null,
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFFFF8A24),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _MoviePosterCard(
                media: items[index],
                width: cardWidth,
                onTap: () => onTap(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  final TmdbMedia media;
  final double width;
  final VoidCallback onTap;

  const _MoviePosterCard({
    required this.media,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media.bestCover != null)
                      ExtendedImage.network(
                        media.bestCover!,
                        fit: BoxFit.cover,
                        cache: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.completed) {
                            return null;
                          }
                          return const ColoredBox(color: Color(0xFF292929));
                        },
                      )
                    else
                      const ColoredBox(color: Color(0xFF292929)),
                    if (media.voteAverage != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            child: Text(
                              media.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              media.displayTitle,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieCompactHeader extends StatelessWidget {
  const _MovieCompactHeader();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0B11).withValues(alpha: .96),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/moviebox-logo.svg',
                  width: 26,
                  height: 26,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Movies',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/globalSearch'),
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaHero extends StatelessWidget {
  final String title;
  final TmdbMedia? media;
  final VoidCallback? onOpen;

  const _MediaHero({required this.title, required this.media, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 450,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media?.bannerImage != null)
            ExtendedImage.network(media!.bannerImage!, fit: BoxFit.cover)
          else
            Container(color: theme.colorScheme.surfaceContainerHighest),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0B0B11)],
                stops: [0.3, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media?.displayTitle ?? title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (media?.overview?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      media!.overview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Voir le détail'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTabs extends StatelessWidget {
  final MediaHubKind kind;

  const _MediaTabs({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Row(
        children: [
          _TabPill(label: 'Tout', selected: true),
          const SizedBox(width: 8),
          _TabPill(label: kind == MediaHubKind.movies ? 'Films' : 'Séries'),
          const SizedBox(width: 8),
          const _TabPill(label: 'Favoris'),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabPill({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE50914) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: selected ? 1 : 0.65),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final String title;
  final List<TmdbMedia> items;
  final Color accent;
  final ValueChanged<TmdbMedia> onTap;

  const _MediaRow({
    required this.title,
    required this.items,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 204,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (_, index) => TmdbPosterCard(
                  media: items[index],
                  width: 126,
                  onTap: () => onTap(items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final String title;
  final Object error;

  const _MediaError({required this.title, required this.error});

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
            Text(
              '$title est temporairement indisponible',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger le catalogue TMDB. Réessayez lorsque la connexion sera disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class TmdbMediaDetailScreen extends StatelessWidget {
  final TmdbMedia media;

  const TmdbMediaDetailScreen({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final genres = media.mediaType == 'movie'
        ? tmdbMovieGenreNames(media.genreIds)
        : tmdbTvGenreNames(media.genreIds);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 370,
            pinned: true,
            backgroundColor: const Color(0xFF0B0B11),
            leading: const BackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.bannerImage != null)
                    ExtendedImage.network(
                      media.bannerImage!,
                      fit: BoxFit.cover,
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0B0B11)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (media.voteAverage != null)
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: media.voteAverage!.toStringAsFixed(1),
                        ),
                      if (media.releaseDate != null ||
                          media.firstAirDate != null)
                        _InfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: (media.releaseDate ?? media.firstAirDate!)
                              .split('-')
                              .first,
                        ),
                      ...genres.map((genre) => _InfoChip(label: genre)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showSourceMessage(context),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Rechercher une source'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ajouté à votre liste locale'),
                              ),
                            ),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Ma liste',
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    media.overview?.isNotEmpty == true
                        ? media.overview!
                        : 'Aucun synopsis disponible.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSourceMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171720),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sources Watchtower',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La fiche utilise les données TMDB. Ouvrez Recherche pour choisir une source Watchtower installée.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/globalSearch');
                },
                child: const Text('Ouvrir Recherche'),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
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
