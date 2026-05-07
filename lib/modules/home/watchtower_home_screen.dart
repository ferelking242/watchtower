import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';

/// MovieBox-style home screen — AnymeX-style header + hero banner + curated rows.
/// Le header devient progressivement un frosted-glass quand on scrolle.
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});

  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  // ── Auto-hide header state ────────────────────────────────────────────────
  bool _headerVisible = true;
  double _lastScrollPos = 0;
  static const _showThreshold = 12.0;   // px scrolled up/down before header toggles

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    final delta = offset - _lastScrollPos;

    bool newVisible = _headerVisible;

    if (offset <= 10) {
      // always show at very top
      newVisible = true;
    } else if (delta > _showThreshold && _headerVisible) {
      // scrolling down quickly → hide
      newVisible = false;
    } else if (delta < -_showThreshold && !_headerVisible) {
      // scrolling up → reveal
      newVisible = true;
    }

    if (newVisible != _headerVisible || (offset - _scrollOffset).abs() > 1) {
      setState(() {
        _headerVisible = newVisible;
        _scrollOffset = offset;
      });
    }
    _lastScrollPos = offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  void _browseTo(BuildContext context, String mediaType, {String? genre}) {
    context.push(
      '/anilistBrowse',
      extra: (
        AnilistBrowseFilter(mediaType: mediaType, genre: genre),
        genre ?? mediaType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncHome = ref.watch(anilistHomeProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────────────
          asyncHome.when(
            loading: () => const SkeletonHomeScreen(),
            error: (e, _) => AniListErrorView(
              error: e,
              onRetry: () => ref.invalidate(anilistHomeProvider),
            ),
            data: (home) {
              // Hero banner: trending anime + trending manga mixed, banner images preferred
              final heroItems = [
                ...home.trendingAnimes
                    .where((m) => m.bannerImage != null || m.bestCover != null)
                    .take(5),
                ...home.trendingMangas
                    .where((m) => m.bannerImage != null || m.bestCover != null)
                    .take(4),
                ...home.animeMovies
                    .where((m) => m.bannerImage != null || m.bestCover != null)
                    .take(3),
              ]..shuffle();

              // Mixed trending (anime + manga) sorted by score
              final trendingAll = [
                ...home.trendingAnimes.take(10),
                ...home.trendingMangas.take(6),
              ]..sort((a, b) =>
                  (b.averageScore ?? 0).compareTo(a.averageScore ?? 0));

              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Space under the auto-hiding header (no padding — hero starts at 0)
                  const SliverToBoxAdapter(child: SizedBox(height: 0)),

                  // ── Full-width Hero carousel ──────────────────────────────
                  if (heroItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: HeroCarousel(
                        items: heroItems.take(10).toList(),
                        onItemTap: (m) => _openDetail(context, m),
                        forceFullWidth: true,
                      ),
                    ),

                  // ── Quick genre chips ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            'Browse',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        children: [
                          _GenreChip(
                            label: 'Anime',
                            color: Colors.indigo,
                            onTap: () => _browseTo(context, 'ANIME'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Manga',
                            color: Colors.teal,
                            onTap: () => _browseTo(context, 'MANGA'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Action',
                            color: Colors.red,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Action'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Romance',
                            color: Colors.pink,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Romance'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Fantasy',
                            color: Colors.purple,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Fantasy'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Sci-Fi',
                            color: Colors.cyan,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Sci-Fi'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Comedy',
                            color: Colors.amber,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Comedy'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Thriller',
                            color: Colors.deepOrange,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Thriller'),
                          ),
                          const SizedBox(width: 8),
                          _GenreChip(
                            label: 'Horror',
                            color: Colors.red.shade900,
                            onTap: () =>
                                _browseTo(context, 'ANIME', genre: 'Horror'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Currently Airing ──────────────────────────────────────
                  if (home.recentlyUpdatedAnimes.isNotEmpty)
                    _MediaRow(
                      title: 'Currently Airing',
                      icon: Icons.live_tv_rounded,
                      iconColor: Colors.red,
                      items: home.recentlyUpdatedAnimes,
                      onTap: (m) => _openDetail(context, m),
                      trailing: TextButton(
                        onPressed: () => _browseTo(context, 'ANIME'),
                        child: const Text('See all'),
                      ),
                    ),

                  // ── Trending Today (mixed) ────────────────────────────────
                  if (trendingAll.isNotEmpty)
                    _MediaRow(
                      title: 'Trending Today',
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Colors.orange,
                      items: trendingAll.take(20).toList(),
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Popular Anime ─────────────────────────────────────────
                  if (home.popularAnimes.isNotEmpty)
                    _MediaRow(
                      title: 'Popular Anime',
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber,
                      items: home.popularAnimes,
                      onTap: (m) => _openDetail(context, m),
                      trailing: TextButton(
                        onPressed: () => _browseTo(context, 'ANIME'),
                        child: const Text('See all'),
                      ),
                    ),

                  // ── Top Rated All-Time ────────────────────────────────────
                  if (home.topRatedAnimes.isNotEmpty)
                    _MediaRow(
                      title: 'Top Rated All-Time',
                      icon: Icons.emoji_events_rounded,
                      iconColor: Colors.yellow.shade700,
                      items: home.topRatedAnimes,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Anime Movies ──────────────────────────────────────────
                  if (home.animeMovies.isNotEmpty)
                    _MediaRow(
                      title: 'Anime Movies',
                      icon: Icons.movie_filter_rounded,
                      iconColor: Colors.blueAccent,
                      items: home.animeMovies,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Coming Soon ───────────────────────────────────────────
                  if (home.upcomingAnimes.isNotEmpty)
                    _MediaRow(
                      title: 'Coming Soon',
                      icon: Icons.schedule_rounded,
                      iconColor: Colors.green,
                      items: home.upcomingAnimes,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Divider: Manga ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Manga & Comics',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Trending Manga ────────────────────────────────────────
                  if (home.trendingMangas.isNotEmpty)
                    _MediaRow(
                      title: 'Trending Manga',
                      items: home.trendingMangas,
                      onTap: (m) => _openDetail(context, m),
                      trailing: TextButton(
                        onPressed: () => _browseTo(context, 'MANGA'),
                        child: const Text('See all'),
                      ),
                    ),

                  // ── Popular Manga ─────────────────────────────────────────
                  if (home.popularMangas.isNotEmpty)
                    _MediaRow(
                      title: 'Popular Manga',
                      items: home.popularMangas,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Trending Manhwa ───────────────────────────────────────
                  if (home.trendingManhwa.isNotEmpty)
                    _MediaRow(
                      title: 'Trending Manhwa',
                      icon: Icons.flag_rounded,
                      iconColor: Colors.blue,
                      items: home.trendingManhwa,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Trending Manhua ───────────────────────────────────────
                  if (home.trendingManhua.isNotEmpty)
                    _MediaRow(
                      title: 'Trending Manhua',
                      items: home.trendingManhua,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Top Manga ─────────────────────────────────────────────
                  if (home.latestMangas.isNotEmpty)
                    _MediaRow(
                      title: 'Top Manga of All Time',
                      icon: Icons.workspace_premium_rounded,
                      iconColor: Colors.amber,
                      items: home.latestMangas,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Divider: Novels ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Light Novels',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Trending Novels ───────────────────────────────────────
                  if (home.trendingNovels.isNotEmpty)
                    _MediaRow(
                      title: 'Trending Novels',
                      items: home.trendingNovels,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Popular Novels ────────────────────────────────────────
                  if (home.popularNovels.isNotEmpty)
                    _MediaRow(
                      title: 'Popular Novels',
                      items: home.popularNovels,
                      onTap: (m) => _openDetail(context, m),
                    ),

                  // ── Games & Music promo ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PromoCard(
                              icon: Icons.sports_esports_rounded,
                              title: 'Games',
                              subtitle: 'ROM library',
                              color: Colors.indigo,
                              onTap: () => context.go('/GameLibrary'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PromoCard(
                              icon: Icons.music_note_rounded,
                              title: 'Music',
                              subtitle: 'Stream & download',
                              color: Colors.purple,
                              onTap: () => context.go('/MusicLibrary'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),

          // ── Floating frosted header — auto-hides on scroll ────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            top: _headerVisible ? 0 : -90,
            left: 0,
            right: 0,
            child: HomeHeader(scrollOffset: _scrollOffset),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal media row ─────────────────────────────────────────────────────

class _MediaRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _MediaRow({
    required this.title,
    required this.items,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 8, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => DiscoveryCard(
                media: items[i],
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Genre chip ───────────────────────────────────────────────────────────────

class _GenreChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Promo card (Games / Music) ───────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PromoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.55),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
