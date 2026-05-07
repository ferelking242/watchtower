import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab definitions
// ─────────────────────────────────────────────────────────────────────────────

enum _HomeTab { tendance, anime, film, manga, romans }

const _tabLabels = ['Tendance', 'Anime', 'Film', 'Manga', 'Romans'];

/// MovieBox-style home screen with category tabs in the header.
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});

  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _headerVisible = true;
  double _lastScrollPos = 0;
  static const _showThreshold = 12.0;

  int _selectedTab = 0;

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
      newVisible = true;
    } else if (delta > _showThreshold && _headerVisible) {
      newVisible = false;
    } else if (delta < -_showThreshold && !_headerVisible) {
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

  void _onTabChanged(int index) {
    setState(() {
      _selectedTab = index;
    });
    // Scroll back near top when changing tabs
    if (_scrollController.hasClients && _scrollController.offset > 200) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // Approximate header height: logo row (~78px) + tabs row (~36px) + padding
  double get _headerHeight => 126.0;

  @override
  Widget build(BuildContext context) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: Stack(
        children: [
          asyncHome.when(
            loading: () => const SkeletonHomeScreen(),
            error: (e, _) => AniListErrorView(
              error: e,
              onRetry: () => ref.invalidate(anilistHomeProvider),
            ),
            data: (home) => _buildContent(context, home),
          ),

          // Floating frosted header
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            top: _headerVisible ? 0 : -(_headerHeight + 20),
            left: 0,
            right: 0,
            child: HomeHeader(
              scrollOffset: _scrollOffset,
              selectedTab: _selectedTab,
              onTabChanged: _onTabChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnilistHomeData home) {
    final tab = _HomeTab.values[_selectedTab.clamp(0, _HomeTab.values.length - 1)];

    // ── Hero items based on tab ───────────────────────────────────────────────
    final heroItems = _heroItemsForTab(home, tab);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Space for the fixed header
        SliverToBoxAdapter(child: SizedBox(height: _headerHeight + 4)),

        // ── Full-width Hero carousel ──────────────────────────────────────────
        if (heroItems.isNotEmpty)
          SliverToBoxAdapter(
            child: HeroCarousel(
              items: heroItems.take(10).toList(),
              onItemTap: (m) => _openDetail(context, m),
              forceFullWidth: true,
            ),
          ),

        // ── Tab-specific content ──────────────────────────────────────────────
        ..._sliverSectionsForTab(context, home, tab),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Hero items per tab ────────────────────────────────────────────────────

  List<AnilistMedia> _heroItemsForTab(AnilistHomeData home, _HomeTab tab) {
    final withImage = (AnilistMedia m) => m.bannerImage != null || m.bestCover != null;
    switch (tab) {
      case _HomeTab.tendance:
        return [
          ...home.trendingAnimes.where(withImage).take(5),
          ...home.trendingMangas.where(withImage).take(3),
          ...home.animeMovies.where(withImage).take(2),
        ]..shuffle();
      case _HomeTab.anime:
        return [
          ...home.trendingAnimes.where(withImage).take(6),
          ...home.popularAnimes.where(withImage).take(4),
        ]..shuffle();
      case _HomeTab.film:
        return home.animeMovies.where(withImage).toList();
      case _HomeTab.manga:
        return [
          ...home.trendingMangas.where(withImage).take(5),
          ...home.popularMangas.where(withImage).take(5),
        ]..shuffle();
      case _HomeTab.romans:
        return [
          ...home.trendingNovels.where(withImage).take(5),
          ...home.popularNovels.where(withImage).take(5),
        ]..shuffle();
    }
  }

  // ── Section slivers per tab ───────────────────────────────────────────────

  List<Widget> _sliverSectionsForTab(
    BuildContext context,
    AnilistHomeData home,
    _HomeTab tab,
  ) {
    switch (tab) {
      case _HomeTab.tendance:
        return _buildTendanceTab(context, home);
      case _HomeTab.anime:
        return _buildAnimeTab(context, home);
      case _HomeTab.film:
        return _buildFilmTab(context, home);
      case _HomeTab.manga:
        return _buildMangaTab(context, home);
      case _HomeTab.romans:
        return _buildRomansTab(context, home);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tendance tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildTendanceTab(BuildContext context, AnilistHomeData home) {
    final trendingAll = [
      ...home.trendingAnimes.take(10),
      ...home.trendingMangas.take(6),
    ]..sort((a, b) => (b.averageScore ?? 0).compareTo(a.averageScore ?? 0));

    return [
      // Quick genre chips
      _GenreChipsSliver(browseTo: (type, genre) => _browseTo(context, type, genre: genre)),

      // Currently Airing — standard cards
      if (home.recentlyUpdatedAnimes.isNotEmpty)
        _StandardRow(
          title: 'En ce moment',
          icon: Icons.live_tv_rounded,
          iconColor: Colors.red,
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),

      // Trending Today — FEATURED first card + standard rest
      if (trendingAll.isNotEmpty)
        _MixedRow(
          title: 'Tendance Aujourd\'hui',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: trendingAll.take(20).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      // Anime Categories
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Catégories Anime',
          categories: animeCategories(),
          mediaForImages: home.trendingAnimes,
        ),
      ),

      // Popular Anime — RANKED cards
      if (home.popularAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top Populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),

      // Top Rated — ranked cards
      if (home.topRatedAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top Noté de Tous les Temps',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      // Anime Movies — LANDSCAPE cards
      if (home.animeMovies.isNotEmpty)
        _LandscapeRow(
          title: 'Films Anime',
          icon: Icons.movie_filter_rounded,
          iconColor: Colors.blueAccent,
          items: home.animeMovies,
          onTap: (m) => _openDetail(context, m),
        ),

      // Coming Soon — standard
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'Bientôt Disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),

      // Manga divider
      _SectionDivider(title: 'Manga & Comics', color: Colors.teal),

      // Trending Manga — standard
      if (home.trendingMangas.isNotEmpty)
        _StandardRow(
          title: 'Manga en Tendance',
          items: home.trendingMangas,
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'MANGA'),
            child: const Text('Voir tout'),
          ),
        ),

      // Manga Categories
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Catégories Manga',
          categories: mangaCategories(),
          mediaForImages: home.trendingMangas,
        ),
      ),

      // Popular Manga — ranked
      if (home.popularMangas.isNotEmpty)
        _RankedRow(
          title: 'Manga Populaires',
          items: home.popularMangas.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      // Manhwa/Manhua
      if (home.trendingManhwa.isNotEmpty)
        _StandardRow(
          title: 'Manhwa en Tendance',
          icon: Icons.flag_rounded,
          iconColor: Colors.blue,
          items: home.trendingManhwa,
          onTap: (m) => _openDetail(context, m),
        ),

      // Novels divider
      _SectionDivider(title: 'Light Novels', color: Colors.purple),

      if (home.trendingNovels.isNotEmpty)
        _StandardRow(
          title: 'Romans en Tendance',
          items: home.trendingNovels,
          onTap: (m) => _openDetail(context, m),
        ),

      // Games & Music promo
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _PromoCard(
                  icon: Icons.sports_esports_rounded,
                  title: 'Jeux',
                  subtitle: 'Bibliothèque ROM',
                  color: Colors.indigo,
                  onTap: () => context.go('/GameLibrary'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PromoCard(
                  icon: Icons.music_note_rounded,
                  title: 'Musique',
                  subtitle: 'Stream & télécharge',
                  color: Colors.purple,
                  onTap: () => context.go('/MusicLibrary'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Anime tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildAnimeTab(BuildContext context, AnilistHomeData home) {
    return [
      // Category row with images
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Explorer par Genre',
          categories: animeCategories(),
          mediaForImages: [...home.trendingAnimes, ...home.popularAnimes],
        ),
      ),

      // Currently Airing
      if (home.recentlyUpdatedAnimes.isNotEmpty)
        _StandardRow(
          title: 'En Cours de Diffusion',
          icon: Icons.live_tv_rounded,
          iconColor: Colors.red,
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(context, m),
        ),

      // Trending
      if (home.trendingAnimes.isNotEmpty)
        _MixedRow(
          title: 'Anime en Tendance',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),

      // Top Populaires — ranked
      if (home.popularAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top Populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
          trailing: TextButton(
            onPressed: () => _browseTo(context, 'ANIME'),
            child: const Text('Voir tout'),
          ),
        ),

      // Top Rated
      if (home.topRatedAnimes.isNotEmpty)
        _RankedRow(
          title: 'Mieux Notés',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      // Upcoming
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'Bientôt Disponible',
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

  List<Widget> _buildFilmTab(BuildContext context, AnilistHomeData home) {
    return [
      if (home.animeMovies.isNotEmpty) ...[
        // Landscape movies
        _LandscapeRow(
          title: 'Films à l\'Affiche',
          icon: Icons.movie_filter_rounded,
          iconColor: Colors.blueAccent,
          items: home.animeMovies,
          onTap: (m) => _openDetail(context, m),
        ),
        // Top movies ranked
        _RankedRow(
          title: 'Films les Mieux Notés',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
          items: (List<AnilistMedia>.from(home.animeMovies)
                ..sort((a, b) => (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
              .take(10)
              .toList(),
          onTap: (m) => _openDetail(context, m),
        ),
      ],
      if (home.animeMovies.isEmpty)
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

  // ──────────────────────────────────────────────────────────────────────────
  // Manga tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildMangaTab(BuildContext context, AnilistHomeData home) {
    return [
      // Origins row
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Origine',
          categories: mangaOrigins(),
        ),
      ),
      // Genres
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Explorer par Genre',
          categories: mangaCategories(),
          mediaForImages: [...home.trendingMangas, ...home.popularMangas],
        ),
      ),

      if (home.trendingMangas.isNotEmpty)
        _MixedRow(
          title: 'Manga en Tendance',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingMangas,
          onTap: (m) => _openDetail(context, m),
        ),

      if (home.popularMangas.isNotEmpty)
        _RankedRow(
          title: 'Manga Populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularMangas.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      if (home.trendingManhwa.isNotEmpty)
        _StandardRow(
          title: 'Manhwa (Corée)',
          icon: Icons.flag_rounded,
          iconColor: Colors.blue,
          items: home.trendingManhwa,
          onTap: (m) => _openDetail(context, m),
        ),

      if (home.trendingManhua.isNotEmpty)
        _StandardRow(
          title: 'Manhua (Chine)',
          items: home.trendingManhua,
          onTap: (m) => _openDetail(context, m),
        ),

      if (home.latestMangas.isNotEmpty)
        _RankedRow(
          title: 'Top Manga de Tous les Temps',
          icon: Icons.workspace_premium_rounded,
          iconColor: Colors.amber,
          items: home.latestMangas.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Romans tab
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildRomansTab(BuildContext context, AnilistHomeData home) {
    return [
      SliverToBoxAdapter(
        child: CategoryRow(
          title: 'Genres',
          categories: novelCategories(),
          mediaForImages: [...home.trendingNovels, ...home.popularNovels],
        ),
      ),

      if (home.trendingNovels.isNotEmpty)
        _MixedRow(
          title: 'Romans en Tendance',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          items: home.trendingNovels,
          onTap: (m) => _openDetail(context, m),
        ),

      if (home.popularNovels.isNotEmpty)
        _RankedRow(
          title: 'Romans Populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularNovels.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genre chips sliver
// ─────────────────────────────────────────────────────────────────────────────

class _GenreChipsSliver extends StatelessWidget {
  final void Function(String type, String? genre) browseTo;
  const _GenreChipsSliver({required this.browseTo});

  @override
  Widget build(BuildContext context) {
    final chips = [
      ('Anime', Colors.indigo, 'ANIME', null),
      ('Manga', Colors.teal, 'MANGA', null),
      ('Action', Colors.red, 'ANIME', 'Action'),
      ('Romance', Colors.pink, 'ANIME', 'Romance'),
      ('Fantasy', Colors.purple, 'ANIME', 'Fantasy'),
      ('Sci-Fi', Colors.cyan, 'ANIME', 'Sci-Fi'),
      ('Comedy', Colors.amber, 'ANIME', 'Comedy'),
      ('Thriller', Colors.deepOrange, 'ANIME', 'Thriller'),
      ('Horror', Colors.red.shade900, 'ANIME', 'Horror'),
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              'Parcourir',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                  labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                  onPressed: () => browseTo(type, genre),
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
          _RowHeader(title: title, icon: icon, iconColor: iconColor, trailing: trailing),
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
          _RowHeader(title: title, icon: icon, iconColor: iconColor, trailing: trailing),
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
          _RowHeader(title: title, icon: icon, iconColor: iconColor, trailing: trailing),
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
// Section divider
// ─────────────────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionDivider({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
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

  const _RowHeader({required this.title, this.icon, this.iconColor, this.trailing});

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
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Promo card (Games / Music)
// ─────────────────────────────────────────────────────────────────────────────

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.22), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.65),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.50)),
            ],
          ),
        ),
      ),
    );
  }
}
