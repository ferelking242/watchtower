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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Tab definitions
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Must stay in sync with kHomeTabs in home_header.dart.
// 0=Live 1=Film 2=SÃ©rie 3=Asia 4=Mini sÃ©rie 5=Anime 6=Football 7=Musique 8=Jeux

enum _HomeTab { live, film, serie, asia, miniSerie, anime, football, musique, jeux }

/// MovieBox-style home screen.
///
/// Layout:
///   ââââââââââââââââââââââââââââââââââââââââââ
///   â  HomeHeader (always visible, floating)  â  opacity 0â1 on scroll
///   ââââââââââââââââââââââââââââââââââââââââââ¤
///   â  Hero carousel  (starts at y=0)         â  60 % of screen height
///   â  Section rows â¦                         â
///   ââââââââââââââââââââââââââââââââââââââââââ
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

  // Mini sÃ©rie filter: 0=DerniÃ¨re  1=Le plus chaud  2=Toute
  int _miniSerieFilter = 0;

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
          // ââ Content scroll view ââââââââââââââââââââââââââââââââââââââââââ
          asyncHome.when(
            loading: () => const SkeletonHomeScreen(),
            error: (e, _) => AniListErrorView(
              error: e,
              onRetry: () => ref.invalidate(anilistHomeProvider),
            ),
            data: (home) => _buildContent(context, home),
          ),

          // ââ Sticky floating header (always at top) âââââââââââââââââââââââ
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeHeader(
              scrollOffset: _scrollOffset,
              selectedTab: _selectedTab,
              onTabChanged: _onTabChanged,
              onSearchTap: () => context.push('/watchtowerSearch'),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(anilistHomeProvider);
        await Future.delayed(const Duration(milliseconds: 700));
      },
      displacement: 80,
      strokeWidth: 2.5,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
        // ââ Hero carousel â starts at scroll offset 0 (behind the transparent
        //    header). No top spacer. âââââââââââââââââââââââââââââââââââââââââ
        if (heroItems.isNotEmpty)
          SliverToBoxAdapter(
            child: HeroCarousel(
              items: heroItems.take(10).toList(),
              onItemTap: (m) => _openDetail(context, m),
              forceFullWidth: true,
            ),
          ),

        // ââ After carousel: push content below the now-opaque header ââââââââ
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ââ Tab-specific section rows ââââââââââââââââââââââââââââââââââââââââ
        ..._sliverSectionsForTab(context, home, tab),

        // Bottom padding (nav bar)
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ââ Hero items per tab ââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
        return home.trendingAnimes.where(withImage).take(5).toList();
    }
  }

  // ââ Section slivers per tab âââââââââââââââââââââââââââââââââââââââââââââââ

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
          subtitle: 'Matches & rÃ©sumÃ©s',
          color: Colors.green,
          routePath: '/globalSearch',
        );
      case _HomeTab.musique:
        return _buildPromoTab(
          context,
          icon: Icons.music_note_rounded,
          title: 'Musique',
          subtitle: 'Stream & tÃ©lÃ©charge',
          color: Colors.purple,
          routePath: '/MusicLibrary',
        );
      case _HomeTab.jeux:
        return _buildPromoTab(
          context,
          icon: Icons.sports_esports_rounded,
          title: 'Jeux',
          subtitle: 'BibliothÃ¨que ROM',
          color: Colors.indigo,
          routePath: '/GameLibrary',
        );
    }
  }

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Live tab â currently airing / recently updated anime
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
          title: 'BientÃ´t disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Film tab
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
        title: 'Films Ã  l\'affiche',
        icon: Icons.movie_filter_rounded,
        iconColor: Colors.blueAccent,
        items: home.animeMovies,
        onTap: (m) => _openDetail(context, m),
      ),
      _RankedRow(
        title: 'Films les mieux notÃ©s',
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

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // SÃ©rie tab
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
          title: 'SÃ©ries en tendance',
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
          title: 'Mieux notÃ©es de tous les temps',
          icon: Icons.workspace_premium_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Asia tab â K-drama / C-drama / J-drama (Manhwa + Manhua as proxy)
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Mini sÃ©rie tab â MovieBox TV Courte style
  // Filter chips: DerniÃ¨re | Le plus chaud | Toute
  // Ma liste section + category rows by origin
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

  List<Widget> _buildMiniSerieTab(BuildContext context, AnilistHome home) {
    // Determine content based on active filter
    final List<AnilistMedia> featured;
    final String featuredTitle;
    switch (_miniSerieFilter) {
      case 0:
        featured = home.recentlyUpdatedAnimes.isNotEmpty
            ? home.recentlyUpdatedAnimes
            : home.trendingAnimes;
        featuredTitle = 'DerniÃ¨res mises Ã  jour';
        break;
      case 1:
        featured = home.trendingAnimes;
        featuredTitle = 'Les plus chaudes';
        break;
      default:
        final all = [...home.trendingAnimes, ...home.popularAnimes];
        featured = all.take(20).toList();
        featuredTitle = 'Toutes les mini-sÃ©ries';
    }

    // Category rows by origin (using AniList data as proxy)
    final japanese = home.trendingAnimes
        .where((m) => m.countryOfOrigin == 'JP' || m.countryOfOrigin == null)
        .take(12)
        .toList();
    final chinese = home.trendingManhua.take(12).toList();
    final american = home.animeMovies.take(12).toList();

    return [
      // ââ Filter chips âââââââââââââââââââââââââââââââââââââââââââââââââââââââ
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              _MiniSerieFilterChip(
                label: 'DerniÃ¨re',
                selected: _miniSerieFilter == 0,
                onTap: () => setState(() => _miniSerieFilter = 0),
              ),
              const SizedBox(width: 8),
              _MiniSerieFilterChip(
                label: 'Le plus chaud',
                selected: _miniSerieFilter == 1,
                onTap: () => setState(() => _miniSerieFilter = 1),
              ),
              const SizedBox(width: 8),
              _MiniSerieFilterChip(
                label: 'Toute',
                selected: _miniSerieFilter == 2,
                onTap: () => setState(() => _miniSerieFilter = 2),
              ),
            ],
          ),
        ),
      ),

      // ââ Ma liste âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
      const SliverToBoxAdapter(child: _MaListeSection()),

      // ââ Featured / filtered row ââââââââââââââââââââââââââââââââââââââââââââ
      if (featured.isNotEmpty)
        _MixedRow(
          title: featuredTitle,
          icon: Icons.video_collection_rounded,
          iconColor: Colors.teal,
          items: featured.take(16).toList(),
          onTap: (m) => _openDetail(context, m),
        ),

      // ââ AmÃ©ricaines ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
      if (american.isNotEmpty)
        _StandardRow(
          title: 'AmÃ©ricaines',
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFF3B5BDB),
          items: american,
          onTap: (m) => _openDetail(context, m),
        ),

      // ââ Japonaises ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
      if (japanese.isNotEmpty)
        _StandardRow(
          title: 'Japonaises',
          icon: Icons.flag_rounded,
          iconColor: Colors.pinkAccent,
          items: japanese,
          onTap: (m) => _openDetail(context, m),
        ),

      // ââ Chinoises âââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
      if (chinese.isNotEmpty)
        _StandardRow(
          title: 'Chinoises',
          icon: Icons.flag_rounded,
          iconColor: Colors.red,
          items: chinese,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Anime tab
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
          title: 'Mieux notÃ©s',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.yellow.shade700,
          items: home.topRatedAnimes.take(10).toList(),
          onTap: (m) => _openDetail(context, m),
        ),
      if (home.upcomingAnimes.isNotEmpty)
        _StandardRow(
          title: 'BientÃ´t disponible',
          icon: Icons.schedule_rounded,
          iconColor: Colors.green,
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(context, m),
        ),
    ];
  }

  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  // Generic promo tab (Football / Musique / Jeux)
  // ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Asia origin chips
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Mini sÃ©rie filter chip (avoids naming conflict with Flutter's FilterChip)
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _MiniSerieFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniSerieFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.50),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.70),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// "Ma liste" section â empty state placeholder for mini sÃ©rie tab
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _MaListeSection extends StatelessWidget {
  const _MaListeSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ma liste',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir tout',
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: cs.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 32, color: cs.primary.withValues(alpha: 0.70)),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoute tes mini-sÃ©ries favorites ici',
                    style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.50)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Standard horizontal row (poster cards)
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
              itemBuilder: (context, i) => AnimatedDiscoveryCard(
                key: ValueKey(items[i].id ?? i),
                media: items[i],
                onTap: () => onTap(items[i]),
                delay: Duration(milliseconds: i * 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Mixed row â FEATURED first card + standard rest
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Ranked row â cards with rank number
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Landscape row â wide 16:9 cards
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Brush stroke painter â paints an organic ink-stroke behind section titles
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _BrushStrokePainter extends CustomPainter {
  final Color color;
  _BrushStrokePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final w = size.width;
    final h = size.height;

    final path = Path();
    // Organic hand-painted stroke shape
    path.moveTo(-3, h * 0.35);
    path.cubicTo(w * 0.05, h * 0.02, w * 0.50, -h * 0.05, w * 0.82, h * 0.10);
    path.cubicTo(w * 0.92, h * 0.14, w + 4, h * 0.20, w + 3, h * 0.28);
    path.lineTo(w + 2, h * 0.75);
    path.cubicTo(w * 0.88, h * 0.96, w * 0.58, h * 1.06, w * 0.28, h * 0.92);
    path.cubicTo(w * 0.14, h * 0.86, w * 0.04, h * 0.98, -4, h * 0.78);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BrushStrokePainter old) => old.color != color;
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Row header â title + optional icon + optional trailing + brush accent
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
    final cs = theme.colorScheme;
    final accentColor = (iconColor ?? cs.primary).withValues(alpha: 0.18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        children: [
          // Brush stroke wrapped around icon + title
          Flexible(
            child: CustomPaint(
              painter: _BrushStrokePainter(accentColor),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon,
                          size: 17,
                          color: iconColor ?? cs.primary),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
