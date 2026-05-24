import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/providers/home_sections_provider.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart'
    show AnilistHome, AnilistMedia, AnilistBrowseFilter, anilistHomeProvider, anilistOfflineNotifier;
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/episode_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/sea_command.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';
import 'package:watchtower/modules/main_view/widgets/glass_button.dart';

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

  void _showSectionsConfig(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HomeSectionsSheet(),
    );
  }

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
          SliverToBoxAdapter(child: _TitleBar(
            onAvatarTap: () => showAccountSheet(context),
            onCommandTap: () => showSeaCommand(context),
            onConfigureTap: () => _showSectionsConfig(context),
          )),

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

          // ── Continue Watching ──────────────────────────────────────────
          if (_tab == 0 &&
              ref.watch(homeSectionsProvider.notifier).isEnabled('continue'))
            SliverToBoxAdapter(
              child: _ContinueWatchingSection(
                items: _continueItems(home),
                onTap: (m) => _openDetail(context, m),
              ),
            ),

          // ── Tab content ────────────────────────────────────────────────
          ..._sections(context, home, tab),

          // Bottom nav padding
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Continue-watching items (Sprint 1 placeholder from recently-updated) ────

  List<AnilistMedia> _continueItems(AnilistHome home) {
    return home.recentlyUpdatedAnimes
        .where((m) => m.bestCover != null)
        .take(12)
        .toList();
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

  // ── Saga items ─────────────────────────────────────────────────────────────

  List<AnilistMedia> _sagaItems(AnilistHome home) {
    final seen = <int>{};
    final out  = <AnilistMedia>[];
    for (final m in [
      ...home.popularAnimes,
      ...home.trendingAnimes,
      ...home.recentlyUpdatedAnimes,
    ]) {
      if (m.format == 'TV' && (m.episodes ?? 0) >= 24 && seen.add(m.id ?? out.length)) {
        out.add(m);
      }
    }
    out.sort((a, b) => (b.averageScore ?? 0).compareTo(a.averageScore ?? 0));
    return out;
  }

  // ── Tout ───────────────────────────────────────────────────────────────────

  List<Widget> _toutTab(BuildContext ctx, AnilistHome home) {
    final sagas = _sagaItems(home);
    // Editorial spotlight — top trending pick with a banner image
    final spotlightItems = [
      ...home.trendingAnimes,
      ...home.popularAnimes,
    ].where((m) => m.bannerImage != null).toList();

    return [
      // ── Spotlight (editorial pick) ──────────────────────────────────────
      if (spotlightItems.isNotEmpty)
        _SpotlightSection(
          items: spotlightItems.take(6).toList(),
          onTap: (m) => _openDetail(ctx, m),
        ),

      // ── Sorties récentes ────────────────────────────────────────────────
      _Row(
          title: 'Sorties récentes',
          icon: Icons.fiber_new_rounded,
          color: const Color(0xFF00B894),
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(ctx, m),
          trailing: _SeeAllBtn(() => _browseTo(ctx, 'ANIME'))),

      // ── En ce moment ────────────────────────────────────────────────────
      _MixedRow(
          title: 'En ce moment',
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFE17055),
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(ctx, m)),

      // ── Sagas & longues séries ───────────────────────────────────────────
      if (sagas.isNotEmpty)
        _SagaRow(
          title: 'Sagas & Longues Séries',
          icon: Icons.collections_bookmark_rounded,
          color: const Color(0xFF6C5CE7),
          items: sagas.take(15).toList(),
          onTap: (m) => _openDetail(ctx, m),
        ),

      // ── Top du moment ───────────────────────────────────────────────────
      _RankedRow(
          title: 'Top du moment',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFFE84393),
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(ctx, m)),

      // ── Prochainement ───────────────────────────────────────────────────
      _Row(
          title: 'Prochainement',
          icon: Icons.upcoming_rounded,
          color: const Color(0xFF0984E3),
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(ctx, m)),
    ];
  }

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

  List<Widget> _serieTab(BuildContext ctx, AnilistHome home) {
    final sagas = _sagaItems(home);
    return [
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
      if (sagas.isNotEmpty)
        _SagaRow(
          title: 'Sagas & Longues Séries',
          icon: Icons.collections_bookmark_rounded,
          color: const Color(0xFF9B59B6),
          items: sagas.take(15).toList(),
          onTap: (m) => _openDetail(ctx, m),
        ),
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
  }

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

class _TitleBar extends StatefulWidget {
  final VoidCallback onAvatarTap;
  final VoidCallback? onCommandTap;
  final VoidCallback? onConfigureTap;
  const _TitleBar({
    required this.onAvatarTap,
    this.onCommandTap,
    this.onConfigureTap,
  });

  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

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
            // Sea Command + Configure buttons
            if (widget.onCommandTap != null)
              Tooltip(
                message: 'Sea Command  (Ctrl+K)',
                child: GestureDetector(
                  onTap: widget.onCommandTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.22),
                        width: 0.8),
                    ),
                    child: Icon(Icons.search_rounded, size: 17, color: cs.primary),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            if (widget.onConfigureTap != null)
              Tooltip(
                message: 'Personnaliser l’accueil',
                child: GestureDetector(
                  onTap: widget.onConfigureTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tune_rounded, size: 17,
                        color: cs.onSurface.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Animated 3D holographic avatar
            GestureDetector(
              onTap: widget.onAvatarTap,
              child: AnimatedBuilder(
                animation: _ring,
                builder: (_, __) => SizedBox(
                  width: 50,
                  height: 50,
                  child: CustomPaint(
                    painter: _HoloRingPainter(
                      progress: _ring.value,
                      primary: cs.primary,
                      tertiary: cs.tertiary,
                    ),
                    child: Center(
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
                              color: cs.primary.withValues(alpha: 0.40),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotating holographic ring painter — used by _TitleBar avatar
// ─────────────────────────────────────────────────────────────────────────────

class _HoloRingPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color tertiary;

  const _HoloRingPainter({
    required this.progress,
    required this.primary,
    required this.tertiary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final angle = progress * 6.2832; // 2π

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 6.2832,
      colors: [
        primary.withValues(alpha: 0.0),
        primary,
        tertiary,
        primary.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.30, 0.70, 1.0],
      transform: GradientRotation(angle),
    );

    final paint = Paint()
      ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_HoloRingPainter old) => old.progress != progress;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gradient accent bar
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.30)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Icon with gradient background
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.07)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.4,
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
// Spotlight section — editorial pick carousel (auto-cycles, full-bleed)
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightSection extends StatefulWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  const _SpotlightSection({required this.items, required this.onTap});

  @override
  State<_SpotlightSection> createState() => _SpotlightSectionState();
}

class _SpotlightSectionState extends State<_SpotlightSection> {
  int _current = 0;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── PC grid (2 or 3 columns, landscape aspect) ──────────────────────────

  Widget _buildPcGrid(double width) {
    final crossCount = width >= 1100 ? 3 : 2;
    final maxItems =
        widget.items.length > crossCount * 2 ? crossCount * 2 : widget.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 16 / 9,
        ),
        itemCount: maxItems,
        itemBuilder: (_, i) => SpotlightDiscoveryCard(
          media: widget.items[i],
          onTap: () => widget.onTap(widget.items[i]),
        ),
      ),
    );
  }

  // ── Mobile horizontal carousel ──────────────────────────────────────────

  Widget _buildMobileCarousel(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: SpotlightDiscoveryCard(
                media: widget.items[i],
                onTap: () => widget.onTap(widget.items[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Coup de cœur',
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFE84393),
              ),
              if (isWide)
                _buildPcGrid(constraints.maxWidth)
              else
                _buildMobileCarousel(cs),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saga row — wide 16:10 cards for long-running / multi-episode series
// ─────────────────────────────────────────────────────────────────────────────

class _SagaRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;

  const _SagaRow({
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
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SagaDiscoveryCard(
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
// Continue Watching section
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueWatchingSection extends StatelessWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;

  const _ContinueWatchingSection({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Continuer à regarder',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              GlassButton(
                label: 'Tout voir',
                intent: GlassButtonIntent.gray,
                height: 28,
                fontSize: 12,
                onPressed: () {},
              ),
            ],
          ),
        ),

        // ── Horizontal scroll ─────────────────────────────────────────────────
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final media = items[index];
              final progress = 0.15 + (index % 7) * 0.12;
              return EpisodeCard(
                data: EpisodeCardData(
                  thumbnailUrl: media.bannerImage,
                  animeCoverUrl: media.bestCover,
                  animeTitle: media.displayTitle ?? 'Unknown',
                  episodeNumber: (index % 24) + 1,
                  progress: EpisodeProgress(
                    value: progress.clamp(0.0, 1.0),
                  ),
                ),
                onTap: () => onTap(media),
                width: 200,
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Section divider ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
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

// ─────────────────────────────────────────────────────────────────────────────
// Home sections configuration sheet (H-04)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSectionsSheet extends ConsumerWidget {
  const _HomeSectionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = ref.watch(homeSectionsProvider);
    final notifier = ref.read(homeSectionsProvider.notifier);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1020) : cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.18), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Personnaliser l’accueil',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.reset(),
                    child: Text('Réinitialiser',
                        style: TextStyle(
                            fontSize: 12, color: cs.primary)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18,
                        color: cs.onSurface.withValues(alpha: 0.50)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.20)),
            // Reorderable sections list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sections.length,
                onReorder: notifier.reorder,
                itemBuilder: (_, i) {
                  final (id, enabled) = sections[i];
                  final meta = kDefaultHomeSections.firstWhere(
                    (s) => s.id == id,
                    orElse: () => HomeSection(id: id, label: id),
                  );
                  return ListTile(
                    key: ValueKey(id),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Icon(Icons.drag_handle_rounded,
                          color: cs.onSurface.withValues(alpha: 0.35)),
                    ),
                    title: Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.40),
                      ),
                    ),
                    trailing: Switch(
                      value: enabled,
                      onChanged: (_) => notifier.toggle(id),
                      thumbColor: WidgetStateProperty.resolveWith((s) =>
                          s.contains(WidgetState.selected)
                              ? cs.primary
                              : cs.outline),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
