import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart'
    show AnilistHome, AnilistMedia, AnilistBrowseFilter, anilistHomeProvider;
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab definitions
// ─────────────────────────────────────────────────────────────────────────────
// Must stay in sync with kHomeTabs in home_header.dart.
// 0=Live 1=Film 2=Série 3=Asia 4=Mini série 5=Anime 6=Football 7=Musique 8=Jeux

enum _HomeTab { live, film, serie, asia, miniSerie, anime, football, musique, jeux }

/// MovieBox-style home screen.
///
/// Layout:
///   ┌────────────────────────────────────────┐
///   │  HomeHeader (always visible, floating)  │  opacity 0→1 on scroll
///   ├────────────────────────────────────────┤
///   │  Hero carousel  (starts at y=0)         │  60 % of screen height
///   │  Section rows …                         │
///   └────────────────────────────────────────┘
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});

  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset);
    }
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

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (_scrollController.hasClients && _scrollController.offset > 200) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // Approximate header height: status-bar + search bar + tabs + padding.
  // Used so the header doesn't obscure content when fully opaque.
  static const double _headerHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      // extendBodyBehindAppBar so the carousel fills behind the transparent header
      extendBody: true,
      body: Stack(
        children: [
          // ── Content scroll view ──────────────────────────────────────────
          asyncHome.when(
            loading: () => const SkeletonHomeScreen(),
            error: (e, _) => AniListErrorView(
              error: e,
              onRetry: () => ref.invalidate(anilistHomeProvider),
            ),
            data: (home) => _buildContent(context, home),
          ),

          // ── Sticky floating header (always at top) ───────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeHeader(
              scrollOffset: _scrollOffset,
              selectedTab: _selectedTab,
              onTabChanged: _onTabChanged,
              onSearchTap: () => context.push('/globalSearch'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnilistHome home) {
    final tab =
        _HomeTab.values[_selectedTab.clamp(0, _HomeTab.values.length - 1)];
    final heroItems = _heroItemsForTab(home, tab);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero carousel — starts at scroll offset 0 (behind the transparent
        //    header). No top spacer. ─────────────────────────────────────────
        if (heroItems.isNotEmpty)
          SliverToBoxAdapter(
            child: HeroCarousel(
              items: heroItems.take(10).toList(),
              onItemTap: (m) => _openDetail(context, m),
              forceFullWidth: true,
            ),
          ),

        // ── After carousel: push content below the now-opaque header ────────
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Tab-specific section rows ────────────────────────────────────────
        ..._sliverSectionsForTab(context, home, tab),

        // Bottom padding (nav bar)
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Hero items per tab ────────────────────────────────────────────────────

  List<AnilistMedia> _heroItemsForTab(AnilistHome home, _HomeTab tab) {
    bool withImage(AnilistMedia m) =>
        m.bannerImage != null || m.bestCover != null;

    switch (tab) {
      case _HomeTab.live:
        return home.recentlyUpdatedAnimes.where(withImage).take(10).toList();
      case _HomeTab.film:
        return home.animeMovies.where(withImage).toList();
      case _HomeTab.serie:
        return [
          ...home.trendingAnimes.where(withImage).take(6),
          ...home.popularAnimes.where(withImage).take(4),
        ]..shuffle();
      case _HomeTab.asia:
        return [
          ...home.trendingManhwa.where(withImage).take(5),
          ...home.trendingManhua.where(withImage).take(5),
        ]..shuffle();
      case _HomeTab.miniSerie:
        // Use trending anime shuffled – OVA/mini filtering not available from AniList
        final all = home.trendingAnimes.where(withImage).toList()..shuffle();
        return all.take(10).toList();
      case _HomeTab.anime:
        return [
          ...home.trendingAnimes.where(withImage).take(6),
          ...home.popularAnimes.where(withImage).take(4),
        ]..shuffle();
      case _HomeTab.football:
      case _HomeTab.musique:
      case _HomeTab.jeux:
        // No AniList feed — show trending as backdrop
        return home.trendingAnimes.where(withImage).take(5).toList();
    }
  }

  // ── Section slivers per tab ───────────────────────────────────────────────

  List<Widget> _sliverSectionsForTab(
    BuildContext context,
    AnilistHome home,
    _HomeTab tab,
  ) {
    switch (tab) {
      case _HomeTab.live:
        return _buildLiveTab(context, home);
      case _HomeTab.film:
        return _buildFilmTab(context, home);
      case _HomeTab.serie:
        return _buildSerieTab(context, home);
      case _HomeTab.asia:
        return _buildAsiaTab(context, home);
      case _HomeTab.miniSerie:
        return _buildMiniSerieTab(context, home);
      case _HomeTab.anime:
        return _buildAnimeTab(context, home);
      case _HomeTab.football:
        return _buildPromoTab(
          context,
          icon: Icons.sports_soccer_rounded,
          title: 'Football',
          subtitle: 'Matches & résumés',
          color: Colors.green,
          routePath: '/globalSearch',
        );
      case _HomeTab.musique:
        return _buildPromoTab(
          context,
          icon: Icons.music_note_rounded,
          title: 'Musique',
          subtitle: 'Stream & télécharge',
          color: Colors.purple,
          routePath: '/MusicLibrary',
        );
      case _HomeTab.jeux:
        return _buildPromoTab(
          context,
          icon: Icons.sports_esports_rounded,
          title: 'Jeux',
          subtitle: 'Bibliothèque ROM',
          color: Colors.indigo,
          routePath: '/GameLibrary',
        );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Live tab — currently airing / recently updated anime
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildLiveTab(BuildContext context, AnilistHome home) {
    return [
      if (home.recentlyUpdatedAnimes.isNotEmpty)
        _StandardRow(
          title: 'En cours de diffusion',
          icon: Icons.live_tv_rounded,
          iconColor: Colors.red,
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),
      if (home.trendingAnimes.isNotEmpty)
        _MixedRow(
          title: 'Tendance aujourd\'hui',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'Bientôt disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Film tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildFilmTab(BuildContext context, AnilistHome home) {
    if (home.animeMovies.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text(
                'Aucun film disponible pour le moment',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      _LandscapeRow(
        title: 'Films à l\'affiche',
        icon: Icons.movie_filter_rounded,
        iconColor: Colors.blueAccent,
        items: home.animeMovies,
        onTap: (m) => _openDetail(context, m),
      ),
      _RankedRow(
        title: 'Films les mieux notés',
        icon: Icons.emoji_events_rounded,
        iconColor: Colors.amber,
        items: (List<AnilistMedia>.from(home.animeMovies)
              ..sort((a, b) =>
                  (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
            .take(10)
            .toList(),
        onTap: (m) => _openDetail(context, m),
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Série tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildSerieTab(BuildContext context, AnilistHome home) {
    return [
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Explorer par genre',
          categories: animeCategories(),
          mediaForImages: [...home.trendingAnimes, ...home.popularAnimes],
        ),
      ),
      if (home.trendingAnimes.isNotEmpty)
        _MixedRow(
          title: 'Séries en tendance',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.popularAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),
      if (home.topRatedAnimes.isNotEmpty)
        _RankedRow(
          title: 'Mieux notées de tous les temps',
          icon: Icons.workspace_premium_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Asia tab — K-drama / C-drama / J-drama (Manhwa + Manhua as proxy)
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildAsiaTab(BuildContext context, AnilistHome home) {
    return [
      SliverToBoxAdapter(
        child: _AsiaOriginChips(browseTo: (t, g) => _browseTo(context, t, genre: g)),
      ),
      if (home.trendingManhwa.isNotEmpty)
        _MixedRow(
          title: 'K-Drama en tendance',
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFF3498DB),
          items: home.trendingManhwa,
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'MANGA', genre: 'Romance'),
            child: const Text('Voir tout'),
          ),
        ),
      if (home.trendingManhua.isNotEmpty)
        _StandardRow(
          title: 'C-Drama / Manhua',
          icon: Icons.flag_rounded,
          iconColor: Colors.red,
          items: home.trendingManhua,
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.popularMangas.isNotEmpty)
        _RankedRow(
          title: 'Top Asie',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
          items: home.popularMangas.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mini série tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildMiniSerieTab(BuildContext context, AnilistHome home) {
    final items = [
      ...home.trendingAnimes,
      ...home.popularAnimes,
    ]..shuffle();
    return [
      if (items.isNotEmpty)
        _MixedRow(
          title: 'Mini séries populaires',
          icon: Icons.video_collection_rounded,
          iconColor: Colors.teal,
          items: items.take(20).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'Bientôt disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Anime tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildAnimeTab(BuildContext context, AnilistHome home) {
    return [
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Explorer par genre',
          categories: animeCategories(),
          mediaForImages: [...home.trendingAnimes, ...home.popularAnimes],
        ),
      ),
      if (home.recentlyUpdatedAnimes.isNotEmpty)
        _StandardRow(
          title: 'En cours de diffusion',
          icon: Icons.live_tv_rounded,
          iconColor: Colors.red,
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.trendingAnimes.isNotEmpty)
        _MixedRow(
          title: 'Anime en tendance',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.popularAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),
      if (home.topRatedAnimes.isNotEmpty)
        _RankedRow(
          title: 'Mieux notés',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'Bientôt disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Generic promo tab (Football / Musique / Jeux)
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildPromoTab(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String routePath,
  }) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => context.go(routePath),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir'),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Asia origin chips
// ─────────────────────────────────────────────────────────────────────────────

class _AsiaOriginChips extends StatelessWidget {
  final void Function(String type, String? genre) browseTo;
  const _AsiaOriginChips({required this.browseTo});

  @override
  Widget build(BuildContext context) {
    final chips = [
      ('K-Drama', const Color(0xFF3498DB), 'MANGA', 'Romance'),
      ('C-Drama', Colors.red, 'MANGA', null),
      ('J-Drama', Colors.pink, 'MANGA', 'Slice of Life'),
      ('Manhwa', Colors.indigo, 'MANGA', null),
      ('Manhua', Colors.orange, 'MANGA', null),
      ('Webtoon', Colors.teal, 'MANGA', null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            'Origine',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (label, color, type, genre) = chips[i];
              return ActionChip(
                label: Text(label),
                backgroundColor: color.withValues(alpha: 0.12),
                side: BorderSide(color: color.withValues(alpha: 0.30)),
                labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
                onPressed: () => browseTo(type, genre),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard horizontal row (poster cards)
// ─────────────────────────────────────────────────────────────────────────────

class _StandardRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _StandardRow({
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
          _RowHeader(
              title: title,
              icon: icon,
              iconColor: iconColor,
              trailing: trailing),
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

// ─────────────────────────────────────────────────────────────────────────────
// Mixed row — FEATURED first card + standard rest
// ─────────────────────────────────────────────────────────────────────────────

class _MixedRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _MixedRow({
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
          _RowHeader(
              title: title,
              icon: icon,
              iconColor: iconColor,
              trailing: trailing),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return FeaturedDiscoveryCard(
                    media: items[i],
                    onTap: () => onTap(items[i]),
                  );
                }
                return DiscoveryCard(
                  media: items[i],
                  onTap: () => onTap(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ranked row — cards with rank number
// ─────────────────────────────────────────────────────────────────────────────

class _RankedRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _RankedRow({
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
          _RowHeader(
              title: title,
              icon: icon,
              iconColor: iconColor,
              trailing: trailing),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) => RankedDiscoveryCard(
                media: items[i],
                rank: i + 1,
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape row — wide 16:9 cards
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;

  const _LandscapeRow({
    required this.title,
    required this.items,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowHeader(title: title, icon: icon, iconColor: iconColor),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => LandscapeDiscoveryCard(
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

// ─────────────────────────────────────────────────────────────────────────────
// Row header
// ─────────────────────────────────────────────────────────────────────────────

class _RowHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  const _RowHeader(
      {required this.title, this.icon, this.iconColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
