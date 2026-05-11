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
// Tab enum — must stay in sync with kHomeTabs in home_header.dart.
// 0=Watchtower 1=Film 2=Série 3=Asia 4=Football 5=Musique 6=Jeux
// ─────────────────────────────────────────────────────────────────────────────

enum _HomeTab { tout, film, serie, asia, football, musique, jeux }

/// Disney+-style home screen.
///
/// Layout (no floating header):
///   ┌─────────────────────────────────────────┐
///   │  "Pour vous"  title  +  account icon    │  ← scrolls
///   │  Pill tabs (Watchtower / Film / …)      │  ← sticky (SliverPersistentHeader)
///   ├─────────────────────────────────────────┤
///   │  Hero carousel  (rounded, peek effect)  │
///   │  Section rows …                         │
///   └─────────────────────────────────────────┘
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});

  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 0;

  @override
  void dispose() {
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
    if (_scrollController.hasClients && _scrollController.offset > 60) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: asyncHome.when(
        loading: () => const SkeletonHomeScreen(),
        error: (e, _) => AniListErrorView(
          error: e,
          onRetry: () => ref.invalidate(anilistHomeProvider),
        ),
        data: (home) => _buildContent(context, home),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnilistHome home) {
    final tab = _HomeTab.values[_selectedTab.clamp(0, _HomeTab.values.length - 1)];
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
        physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics()),
        slivers: [
          // ── "Pour vous" title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ForYouTitle(onAccountTap: () => showAccountSheet(context)),
          ),

          // ── Pill tabs — sticky ────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(
              selectedTab: _selectedTab,
              onTabChanged: _onTabChanged,
            ),
          ),

          // ── Spacing before carousel ───────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // ── Hero carousel ─────────────────────────────────────────────────
          if (heroItems.isNotEmpty)
            SliverToBoxAdapter(
              child: HeroCarousel(
                items: heroItems.take(10).toList(),
                onItemTap: (m) => _openDetail(context, m),
                forceFullWidth: true,
              ),
            ),

          // ── Spacing ───────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          // ── Tab-specific sections ─────────────────────────────────────────
          ..._sliverSectionsForTab(context, home, tab),

          // Bottom padding (nav bar)
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Hero items per tab ───────────────────────────────────────────────────

  List<AnilistMedia> _heroItemsForTab(AnilistHome home, _HomeTab tab) {
    bool withImage(AnilistMedia m) =>
        m.bannerImage != null || m.bestCover != null;

    switch (tab) {
      case _HomeTab.tout:
        return [
          ...home.recentlyUpdatedAnimes.where(withImage).take(5),
          ...home.trendingAnimes.where(withImage).take(5),
        ]..shuffle();
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
      case _HomeTab.football:
      case _HomeTab.musique:
      case _HomeTab.jeux:
        return home.trendingAnimes.where(withImage).take(6).toList();
    }
  }

  // ── Section slivers per tab ──────────────────────────────────────────────

  List<Widget> _sliverSectionsForTab(
    BuildContext context,
    AnilistHome home,
    _HomeTab tab,
  ) {
    switch (tab) {
      case _HomeTab.tout:
        return _buildToutTab(context, home);
      case _HomeTab.film:
        return _buildFilmTab(context, home);
      case _HomeTab.serie:
        return _buildSerieTab(context, home);
      case _HomeTab.asia:
        return _buildAsiaTab(context, home);
      case _HomeTab.football:
        return _buildPromoTab(
          context,
          icon: Icons.sports_soccer_rounded,
          title: 'Football',
          subtitle: 'Matchs & résumés',
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

  // ── Tout tab — "Pour vous" mix ───────────────────────────────────────────

  List<Widget> _buildToutTab(BuildContext context, AnilistHome home) {
    return [
      if (home.recentlyUpdatedAnimes.isNotEmpty)
        _StandardRow(
          title: 'Recommandé pour vous',
          icon: Icons.recommend_rounded,
          iconColor: Colors.blueAccent,
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
      if (home.popularAnimes.isNotEmpty)
        _RankedRow(
          title: 'Top populaires',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          items: home.popularAnimes.take(10).toList(),
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

  // ── Film tab ─────────────────────────────────────────────────────────────

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

  // ── Série tab ────────────────────────────────────────────────────────────

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

  // ── Asia tab ─────────────────────────────────────────────────────────────

  List<Widget> _buildAsiaTab(BuildContext context, AnilistHome home) {
    return [
      SliverToBoxAdapter(
        child: _AsiaOriginChips(
            browseTo: (t, g) => _browseTo(context, t, genre: g)),
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

  // ── Generic promo tab (Football / Musique / Jeux) ────────────────────────

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
// "Pour vous" title widget (scrolls with content)
// ─────────────────────────────────────────────────────────────────────────────

class _ForYouTitle extends StatelessWidget {
  final VoidCallback onAccountTap;
  const _ForYouTitle({required this.onAccountTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Pour vous',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ),
            // Account avatar button
            GestureDetector(
              onTap: onAccountTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.90),
                      cs.tertiary.withValues(alpha: 0.85),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22), width: 1.2),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky pill tabs — SliverPersistentHeader delegate
// ─────────────────────────────────────────────────────────────────────────────

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _TabsDelegate({
    required this.selectedTab,
    required this.onTabChanged,
  });

  static const double _height = 50.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabsDelegate old) =>
      old.selectedTab != selectedTab || old.onTabChanged != onTabChanged;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solid background so tabs are always readable over content
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: kHomeTabs.length,
        itemBuilder: (context, i) {
          final active = selectedTab == i;
          // Icons map (mirrors home_header.dart)
          const iconMap = <int, IconData>{
            0: Icons.play_circle_filled_rounded,
            1: Icons.movie_rounded,
            2: Icons.live_tv_rounded,
            3: Icons.public_rounded,
            4: Icons.sports_soccer_rounded,
            5: Icons.music_note_rounded,
            6: Icons.sports_esports_rounded,
          };
          final icon = iconMap[i];

          // Active: white bg + dark text | inactive: translucent pill
          final activeBg = isDark ? Colors.white : cs.onSurface;
          final activeText = isDark ? Colors.black : cs.surface;
          final inactiveBg = isDark
              ? Colors.white.withValues(alpha: 0.10)
              : cs.onSurface.withValues(alpha: 0.08);
          final inactiveText = isDark
              ? Colors.white.withValues(alpha: 0.72)
              : cs.onSurface.withValues(alpha: 0.65);

          return GestureDetector(
            onTap: () => onTabChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: icon != null ? 12 : 16,
                vertical: 0,
              ),
              decoration: BoxDecoration(
                color: active ? activeBg : inactiveBg,
                borderRadius: BorderRadius.circular(999),
                border: active
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : cs.onSurface.withValues(alpha: 0.14),
                        width: 1,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 14,
                        color: active ? activeText : inactiveText),
                    const SizedBox(width: 5),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      color: active ? activeText : inactiveText,
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                    child: Text(kHomeTabs[i]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
// Brush stroke painter
// ─────────────────────────────────────────────────────────────────────────────

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
    final cs = theme.colorScheme;
    final accentColor = (iconColor ?? cs.primary).withValues(alpha: 0.18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        children: [
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
                      Icon(icon, size: 17, color: iconColor ?? cs.primary),
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
