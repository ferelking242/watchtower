import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart'
    show AnilistHome, AnilistMedia, AnilistBrowseFilter, anilistHomeProvider, anilistOfflineNotifier;
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab enum — stays in sync with kHomeTabs / kHomeTabIcons in home_header.dart
// 0=Tout  1=Film  2=Série  3=Asia  4=Football  5=Musique  6=Jeux
// ─────────────────────────────────────────────────────────────────────────────

enum _HomeTab { tout, film, serie, asia, football, musique, jeux }

/// Premium streaming home screen — Disney+ / Netflix / Apple TV+ hybrid.
///
/// Layout (no floating header):
///   ┌──────────────────────────────────┐
///   │ "Pour vous"          [avatar]    │  ← scrolls away
///   │ [Tout][Film][Série]…             │  ← pills, sticky
///   │ ┌──────────────────┐ ┌─┐        │
///   │ │   Hero carousel  │ │ │        │  ← 54 % height, 88 % width, peek
///   │ └──────────────────┘ └─┘        │
///   │ Section rows …                  │
///   └──────────────────────────────────┘
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});
  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final _scroll = ScrollController();
  int _tab = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext ctx, AnilistMedia m) =>
      ctx.push('/anilistDetail', extra: m);

  void _browseTo(BuildContext ctx, String type, {String? genre}) =>
      ctx.push('/anilistBrowse',
          extra: (AnilistBrowseFilter(mediaType: type, genre: genre),
              genre ?? type));

  void _onTabChanged(int i) {
    setState(() => _tab = i);
    if (_scroll.hasClients && _scroll.offset > 60) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: anilistOfflineNotifier,
        builder: (context, isOffline, _) => Column(
          children: [
            if (isOffline)
              Material(
                color: Colors.orange.shade700,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Connexion non disponible — données mises en cache',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => ref.refresh(anilistHomeProvider),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Text(
                                'Réessayer',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ref.watch(anilistHomeProvider).when(
                    loading: () => const SkeletonHomeScreen(),
                    error: (e, _) => AniListErrorView(
                        error: e,
                        onRetry: () => ref.refresh(anilistHomeProvider)),
                    data: (home) => _buildBody(context, home),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AnilistHome home) {
    final tab = _HomeTab.values[_tab.clamp(0, _HomeTab.values.length - 1)];
    final heroItems = _heroItems(home, tab);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(anilistHomeProvider);
        await Future.delayed(const Duration(milliseconds: 700));
      },
      displacement: 80,
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics()),
        slivers: [
          // ── "Pour vous" title ──────────────────────────────────────────
          SliverToBoxAdapter(child: _TitleBar(onAvatarTap: () => showAccountSheet(context))),

          // ── Sticky pill tabs ───────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(tab: _tab, onChanged: _onTabChanged),
          ),

          // ── Spacing ────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Hero carousel ──────────────────────────────────────────────
          if (heroItems.isNotEmpty)
            SliverToBoxAdapter(
              child: HeroCarousel(
                items: heroItems.take(10).toList(),
                onItemTap: (m) => _openDetail(context, m),
                forceFullWidth: true,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          // ── Tab content ────────────────────────────────────────────────
          ..._sections(context, home, tab),

          // Bottom nav padding
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Hero items ─────────────────────────────────────────────────────────────

  List<AnilistMedia> _heroItems(AnilistHome home, _HomeTab tab) {
    bool ok(AnilistMedia m) => m.bannerImage != null || m.bestCover != null;
    switch (tab) {
      case _HomeTab.tout:
        return [
          ...home.recentlyUpdatedAnimes.where(ok).take(5),
          ...home.trendingAnimes.where(ok).take(5),
        ]..shuffle();
      case _HomeTab.film:
        return home.animeMovies.where(ok).toList();
      case _HomeTab.serie:
        return [
          ...home.trendingAnimes.where(ok).take(6),
          ...home.popularAnimes.where(ok).take(4),
        ]..shuffle();
      case _HomeTab.asia:
        return [
          ...home.trendingManhwa.where(ok).take(5),
          ...home.trendingManhua.where(ok).take(5),
        ]..shuffle();
      case _HomeTab.football:
      case _HomeTab.musique:
      case _HomeTab.jeux:
        return home.trendingAnimes.where(ok).take(6).toList();
    }
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  List<Widget> _sections(BuildContext ctx, AnilistHome home, _HomeTab tab) {
    switch (tab) {
      case _HomeTab.tout:    return _toutTab(ctx, home);
      case _HomeTab.film:    return _filmTab(ctx, home);
      case _HomeTab.serie:   return _serieTab(ctx, home);
      case _HomeTab.asia:    return _asiaTab(ctx, home);
      case _HomeTab.football:
        return _promoTab(ctx, icon: Icons.sports_soccer_rounded,
            title: 'Football', subtitle: 'Matchs & résumés',
            color: const Color(0xFF2ECC71), route: '/globalSearch');
      case _HomeTab.musique:
        return _promoTab(ctx, icon: Icons.queue_music_rounded,
            title: 'Musique', subtitle: 'Stream & télécharge',
            color: const Color(0xFF9B59B6), route: '/MusicLibrary');
      case _HomeTab.jeux:
        return _promoTab(ctx, icon: Icons.sports_esports_rounded,
            title: 'Jeux', subtitle: 'Bibliothèque ROM',
            color: const Color(0xFF3498DB), route: '/GameLibrary');
    }
  }

  // ── Tout ───────────────────────────────────────────────────────────────────

  List<Widget> _toutTab(BuildContext ctx, AnilistHome home) => [
        _Row(title: 'Recommandé pour vous',
            icon: Icons.recommend_rounded,
            color: const Color(0xFF3498DB),
            items: home.recentlyUpdatedAnimes,
            onTap: (m) => _openDetail(ctx, m),
            trailing: _SeeAllBtn(() => _browseTo(ctx, 'ANIME'))),
        _MixedRow(title: 'Tendance aujourd\'hui',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE74C3C),
            items: home.trendingAnimes,
            onTap: (m) => _openDetail(ctx, m)),
        _RankedRow(title: 'Top populaires',
            icon: Icons.star_rounded,
            color: const Color(0xFFF39C12),
            items: home.popularAnimes.take(10).toList(),
            onTap: (m) => _openDetail(ctx, m)),
        _Row(title: 'Bientôt disponible',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF27AE60),
            items: home.upcomingAnimes,
            onTap: (m) => _openDetail(ctx, m)),
      ];

  // ── Film ───────────────────────────────────────────────────────────────────

  List<Widget> _filmTab(BuildContext ctx, AnilistHome home) {
    if (home.animeMovies.isEmpty) return [_EmptySliver('Aucun film disponible')];
    return [
      _LandscapeRow(title: 'Films à l\'affiche',
          icon: Icons.theaters_rounded,
          color: const Color(0xFF2980B9),
          items: home.animeMovies,
          onTap: (m) => _openDetail(ctx, m)),
      _RankedRow(title: 'Mieux notés',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFF39C12),
          items: (List<AnilistMedia>.from(home.animeMovies)
                ..sort((a, b) =>
                    (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
              .take(10)
              .toList(),
          onTap: (m) => _openDetail(ctx, m)),
    ];
  }

  // ── Série ──────────────────────────────────────────────────────────────────

  List<Widget> _serieTab(BuildContext ctx, AnilistHome home) => [
        SliverToBoxAdapter(
          child: CategoryRow(
            title: 'Explorer par genre',
            categories: animeCategories(),
            mediaForImages: [...home.trendingAnimes, ...home.popularAnimes],
          ),
        ),
        _MixedRow(title: 'Séries en tendance',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE74C3C),
            items: home.trendingAnimes,
            onTap: (m) => _openDetail(ctx, m)),
        _RankedRow(title: 'Top populaires',
            icon: Icons.star_rounded,
            color: const Color(0xFFF39C12),
            items: home.popularAnimes.take(10).toList(),
            onTap: (m) => _openDetail(ctx, m),
            trailing: _SeeAllBtn(() => _browseTo(ctx, 'ANIME'))),
        _RankedRow(title: 'Mieux notées',
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFF8E44AD),
            items: home.topRatedAnimes.take(10).toList(),
            onTap: (m) => _openDetail(ctx, m)),
      ];

  // ── Asia ───────────────────────────────────────────────────────────────────

  List<Widget> _asiaTab(BuildContext ctx, AnilistHome home) => [
        SliverToBoxAdapter(
            child: _AsiaChips(onBrowse: (t, g) => _browseTo(ctx, t, genre: g))),
        _MixedRow(title: 'K-Drama en tendance',
            icon: Icons.whatshot_rounded,
            color: const Color(0xFF3498DB),
            items: home.trendingManhwa,
            onTap: (m) => _openDetail(ctx, m),
            trailing:
                _SeeAllBtn(() => _browseTo(ctx, 'MANGA', genre: 'Romance'))),
        _Row(title: 'C-Drama / Manhua',
            icon: Icons.flag_rounded,
            color: const Color(0xFFE74C3C),
            items: home.trendingManhua,
            onTap: (m) => _openDetail(ctx, m)),
        _RankedRow(title: 'Top Asie',
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFF39C12),
            items: home.popularMangas.take(10).toList(),
            onTap: (m) => _openDetail(ctx, m)),
      ];

  // ── Promo tab (Football / Musique / Jeux) ──────────────────────────────────

  List<Widget> _promoTab(BuildContext ctx,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required String route}) =>
      [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Icon(icon, color: color, size: 42),
                  ),
                  const SizedBox(height: 22),
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(subtitle,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.60),
                          fontSize: 14)),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => ctx.go(route),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ouvrir',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// "Pour vous" title bar
// ─────────────────────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  final VoidCallback onAvatarTap;
  const _TitleBar({required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pour vous',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.92),
                      cs.tertiary.withValues(alpha: 0.88),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1.5,
                  ),
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
// Sticky pill tabs
// ─────────────────────────────────────────────────────────────────────────────

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final int tab;
  final ValueChanged<int> onChanged;
  const _TabsDelegate({required this.tab, required this.onChanged});

  static const double _h = 52.0;

  @override double get minExtent => _h;
  @override double get maxExtent => _h;
  @override bool shouldRebuild(_TabsDelegate o) =>
      o.tab != tab || o.onChanged != onChanged;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Container(
      height: _h,
      color: Theme.of(ctx).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: kHomeTabs.length,
        itemBuilder: (_, i) {
          final active = tab == i;
          final icon = kHomeTabIcons[i];

          final activeBg = isDark ? Colors.white : cs.onSurface;
          final activeText = isDark ? const Color(0xFF0A0A0F) : cs.surface;
          final inactiveBg = isDark
              ? Colors.white.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.07);
          final inactiveBorder = isDark
              ? Colors.white.withValues(alpha: 0.14)
              : cs.onSurface.withValues(alpha: 0.12);
          final inactiveText = isDark
              ? Colors.white.withValues(alpha: 0.68)
              : cs.onSurface.withValues(alpha: 0.62);

          return GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? activeBg : inactiveBg,
                borderRadius: BorderRadius.circular(999),
                border: active
                    ? null
                    : Border.all(color: inactiveBorder, width: 1),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: (isDark ? Colors.white : cs.onSurface)
                              .withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 13,
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
                      letterSpacing: active ? -0.1 : 0,
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
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  const _SectionHeader(
      {required this.title,
      required this.icon,
      required this.color,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 16, 12),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Voir tout" button
// ─────────────────────────────────────────────────────────────────────────────

class _SeeAllBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllBtn(this.onTap);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Voir tout',
            style: TextStyle(
              color: cs.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: cs.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard poster row
// ─────────────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _Row({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: title, icon: icon, color: color, trailing: trailing),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => AnimatedDiscoveryCard(
                key: ValueKey(items[i].id ?? i),
                media: items[i],
                onTap: () => onTap(items[i]),
                delay: Duration(milliseconds: i * 35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mixed row — featured first card
// ─────────────────────────────────────────────────────────────────────────────

class _MixedRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _MixedRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: title, icon: icon, color: color, trailing: trailing),
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => i == 0
                  ? FeaturedDiscoveryCard(
                      media: items[i], onTap: () => onTap(items[i]))
                  : DiscoveryCard(
                      media: items[i], onTap: () => onTap(items[i])),
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
  final IconData icon;
  final Color color;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _RankedRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              title: title, icon: icon, color: color, trailing: trailing),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => RankedDiscoveryCard(
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
// Landscape row — 16:9 cards
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;

  const _LandscapeRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, icon: icon, color: color),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => LandscapeDiscoveryCard(
                media: items[i], onTap: () => onTap(items[i])),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Asia origin chips
// ─────────────────────────────────────────────────────────────────────────────

class _AsiaChips extends StatelessWidget {
  final void Function(String type, String? genre) onBrowse;
  const _AsiaChips({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    const chips = [
      ('K-Drama',  Color(0xFF3498DB), 'MANGA', 'Romance'),
      ('C-Drama',  Color(0xFFE74C3C), 'MANGA', null),
      ('J-Drama',  Color(0xFFE91E8C), 'MANGA', 'Slice of Life'),
      ('Manhwa',   Color(0xFF3F51B5), 'MANGA', null),
      ('Manhua',   Color(0xFFFF9800), 'MANGA', null),
      ('Webtoon',  Color(0xFF009688), 'MANGA', null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Origine',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (label, color, type, genre) = chips[i];
              return GestureDetector(
                onTap: () => onBrowse(type, genre),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state sliver
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySliver extends StatelessWidget {
  final String message;
  const _EmptySliver(this.message);

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.50))),
        ),
      ),
    );
  }
}
