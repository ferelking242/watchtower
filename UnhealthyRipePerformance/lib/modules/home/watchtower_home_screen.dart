import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart'
    show AnilistHome, AnilistMedia, AnilistBrowseFilter, anilistHomeProvider, anilistOfflineNotifier;
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart'
    show TmdbHome, TmdbMedia, tmdbHomeProvider;
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/episode_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/main_view/widgets/glass_button.dart';
import 'package:watchtower/modules/music/music_discovery_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab enum — stays in sync with kHomeTabs / kHomeTabIcons in home_header.dart
// 0=Tout 1=Film 2=Série 3=Musique 4=Anime 5=Asia 6=Enfant 7=Occidental 8=Africa 9=TV Court 10=Football 11=Jeux
// ─────────────────────────────────────────────────────────────────────────────

enum _HomeTab { tout, film, serie, musique, anime, asia, enfant, occidental, africa, tvCourt, football, jeux }

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
    final _carouselColor = ValueNotifier<Color>(Colors.transparent);
    final _headerOpacity = ValueNotifier<double>(0.15);
    double _carouselH = 300.0;
    double _headerH = 56.0;
    int _tab = 0;

    @override
    void initState() {
      super.initState();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ));
      _scroll.addListener(_updateOpacity);
    }

    void _updateOpacity() {
      if (!_scroll.hasClients) return;
      final v = 0.15 + (_scroll.offset / _carouselH).clamp(0.0, 0.85);
      if ((v - _headerOpacity.value).abs() > 0.005) _headerOpacity.value = v;
    }

    @override
    void dispose() {
      _scroll.removeListener(_updateOpacity);
      _scroll.dispose();
      _carouselColor.dispose();
      _headerOpacity.dispose();
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
      final _topPad = MediaQuery.of(context).padding.top;
      _headerH = _topPad + 56 + 36; // +36 for pills row
      _carouselH = _headerH + MediaQuery.sizeOf(context).height * 0.34;
      return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: anilistOfflineNotifier,
        builder: (context, isOffline, _) => Stack(
          children: [
            Column(
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
                                onTap: () =>
                                    ref.refresh(anilistHomeProvider),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Text(
                                    'Réessayer',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        decoration:
                                            TextDecoration.underline,
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
                            onRetry: () =>
                                ref.refresh(anilistHomeProvider)),
                        data: (home) => _buildBody(context, home),
                      ),
                ),
              ],
            ),

            // ── Persistent MovieBox-style header (always on top) ──────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HomeHeader(
                tab: _tab,
                onTabChanged: _onTabChanged,
                headerOpacity: _headerOpacity,
                onSearchTap: () => context.push('/globalSearch'),
                onAvatarTap: () => showAccountSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AnilistHome home) {
    final tab = _HomeTab.values[_tab.clamp(0, _HomeTab.values.length - 1)];

    // Film & Série tabs use TMDB — load asynchronously
    final isTmdbTab = tab == _HomeTab.film || tab == _HomeTab.serie;
    if (isTmdbTab) {
      return ref.watch(tmdbHomeProvider).when(
        loading: () => const SkeletonHomeScreen(),
        error: (e, _) => _buildBodyWithAnilist(context, home),
        data: (tmdb) => _buildBodyTmdb(context, tmdb, tab),
      );
    }

    return _buildBodyWithAnilist(context, home);
  }

  Widget _buildBodyTmdb(BuildContext context, TmdbHome tmdb, _HomeTab tab) {
    final heroItems = tab == _HomeTab.film
        ? tmdb.trendingMovies.where((m) => m.bannerImage != null).take(10).toList()
        : tmdb.trendingTv.where((m) => m.bannerImage != null).take(10).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tmdbHomeProvider);
        await Future.delayed(const Duration(milliseconds: 700));
      },
      displacement: 80,
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          if (heroItems.isNotEmpty)
            SliverToBoxAdapter(
              child: TmdbHeroCarousel(
                items: heroItems,
                onTap: (_) {},
                topPadding: _headerH,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ...(tab == _HomeTab.film ? _tmdbFilmTab(context, tmdb) : _tmdbSerieTab(context, tmdb)),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildBodyWithAnilist(BuildContext context, AnilistHome home) {
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
          // ── Hero carousel (full bleed, at the very top) ────────────────
          if (heroItems.isNotEmpty)
            SliverToBoxAdapter(
              child: HeroCarousel(
                items: heroItems.take(10).toList(),
                onItemTap: (m) => _openDetail(context, m),
                forceFullWidth: true,
                onColorExtracted: (c) => _carouselColor.value = c,
                topPadding: _headerH,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          // ── Continue Watching ──────────────────────────────────────────
          if (_tab == 0)
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

  // ── Continue-watching items — hidden until real Isar history is plugged in ──

  List<AnilistMedia> _continueItems(AnilistHome home) {
    return [];
  }

  // ── Hero items ─────────────────────────────────────────────────────────────

  List<AnilistMedia> _heroItems(AnilistHome home, _HomeTab tab) {
    bool ok(AnilistMedia m) => m.bannerImage != null || m.bestCover != null;
    switch (tab) {
      case _HomeTab.tout:
        return [
          ...home.trendingAnimes.where(ok).take(4),
          ...home.animeMovies.where(ok).take(3),
          ...home.popularAnimes.where(ok).take(3),
        ]..shuffle();
      case _HomeTab.film:
        return home.animeMovies.where(ok).toList();
      case _HomeTab.serie:
        return [
          ...home.trendingAnimes.where((m) => ok(m) && m.format != 'MOVIE').take(6),
          ...home.popularAnimes.where((m) => ok(m) && m.format != 'MOVIE').take(4),
        ]..shuffle();
      case _HomeTab.anime:
        return [
          ...home.recentlyUpdatedAnimes.where(ok).take(5),
          ...home.trendingAnimes.where(ok).take(5),
        ]..shuffle();
      case _HomeTab.asia:
        return [
          ...home.trendingManhwa.where(ok).take(5),
          ...home.trendingManhua.where(ok).take(5),
        ]..shuffle();
      case _HomeTab.tvCourt:
        final shorts = [
          ...home.recentlyUpdatedAnimes.where((m) => ok(m) && m.format == 'TV_SHORT'),
          ...home.trendingAnimes.where((m) => ok(m) && (m.episodes ?? 99) <= 13),
        ];
        return shorts.isEmpty ? home.trendingAnimes.where(ok).take(6).toList() : shorts.take(8).toList();
      case _HomeTab.musique:
        return [];
      case _HomeTab.enfant:
      case _HomeTab.occidental:
      case _HomeTab.africa:
      case _HomeTab.football:
      case _HomeTab.jeux:
        return home.trendingAnimes.where(ok).take(6).toList();
    }
  }

  // ── TMDB Film tab ──────────────────────────────────────────────────────────

  List<Widget> _tmdbFilmTab(BuildContext ctx, TmdbHome tmdb) {
    return [
      _TmdbLandscapeRow(
        title: 'Films en ce moment',
        icon: Icons.theaters_rounded,
        color: const Color(0xFF2980B9),
        items: tmdb.nowPlayingMovies,
        onTap: (_) {},
      ),
      _TmdbRow(
        title: 'Tendances de la semaine',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFE17055),
        items: tmdb.trendingMovies,
        onTap: (_) {},
      ),
      _TmdbRankedRow(
        title: 'Les mieux notés',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFF39C12),
        items: tmdb.topRatedMovies.take(10).toList(),
        onTap: (_) {},
      ),
      _TmdbRow(
        title: 'Films populaires',
        icon: Icons.star_rounded,
        color: const Color(0xFF8E44AD),
        items: tmdb.popularMovies,
        onTap: (_) {},
      ),
      _TmdbRow(
        title: 'Prochainement',
        icon: Icons.upcoming_rounded,
        color: const Color(0xFF0984E3),
        items: tmdb.upcomingMovies,
        onTap: (_) {},
      ),
    ];
  }

  // ── TMDB Série tab ─────────────────────────────────────────────────────────

  List<Widget> _tmdbSerieTab(BuildContext ctx, TmdbHome tmdb) {
    return [
      _TmdbRow(
        title: 'Tendances TV de la semaine',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFE74C3C),
        items: tmdb.trendingTv,
        onTap: (_) {},
      ),
      _TmdbLandscapeRow(
        title: 'En cours de diffusion',
        icon: Icons.live_tv_rounded,
        color: const Color(0xFF2980B9),
        items: tmdb.onTheAirTv,
        onTap: (_) {},
      ),
      _TmdbRow(
        title: 'Diffusées aujourd\'hui',
        icon: Icons.fiber_new_rounded,
        color: const Color(0xFF00B894),
        items: tmdb.airingTodayTv,
        onTap: (_) {},
      ),
      _TmdbRankedRow(
        title: 'Les mieux notées',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF6C5CE7),
        items: tmdb.topRatedTv.take(10).toList(),
        onTap: (_) {},
      ),
      _TmdbRow(
        title: 'Séries populaires',
        icon: Icons.star_rounded,
        color: const Color(0xFFF39C12),
        items: tmdb.popularTv,
        onTap: (_) {},
      ),
    ];
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  List<Widget> _sections(BuildContext ctx, AnilistHome home, _HomeTab tab) {
    switch (tab) {
      case _HomeTab.tout:       return _toutAllTab(ctx, home);
      case _HomeTab.film:       return _filmTab(ctx, home);
      case _HomeTab.serie:      return _serieTab(ctx, home);
      case _HomeTab.anime:      return _animeTab(ctx, home);
      case _HomeTab.asia:       return _asiaTab(ctx, home);
      case _HomeTab.tvCourt:    return _tvCourtTab(ctx, home);
      case _HomeTab.enfant:
        return _promoTab(ctx, icon: Icons.child_care_rounded,
            title: 'Enfant', subtitle: 'Dessins animés & contenus jeunesse',
            color: const Color(0xFFFF9800), route: '/globalSearch');
      case _HomeTab.occidental:
        return _promoTab(ctx, icon: Icons.public_rounded,
            title: 'Occidental', subtitle: 'Séries & films US/EU',
            color: const Color(0xFF2980B9), route: '/globalSearch');
      case _HomeTab.africa:
        return _promoTab(ctx, icon: Icons.flag_rounded,
            title: 'Africa', subtitle: 'Contenus africains',
            color: const Color(0xFF27AE60), route: '/globalSearch');
      case _HomeTab.football:
        return _promoTab(ctx, icon: Icons.sports_soccer_rounded,
            title: 'Football', subtitle: 'Matchs & résumés',
            color: const Color(0xFF2ECC71), route: '/globalSearch');
      case _HomeTab.musique:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: MusicDiscoveryScreen(initialRoute: 'search'),
          ),
        ];
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

  // ── Tout (nouveau — tout type de contenu mixé) ────────────────────────────

  List<Widget> _toutAllTab(BuildContext ctx, AnilistHome home) {
    final spotlightItems = [
      ...home.trendingAnimes,
      ...home.popularAnimes,
    ].where((m) => m.bannerImage != null).toList();

    return [
      if (spotlightItems.isNotEmpty)
        _SpotlightSection(
          items: spotlightItems.take(6).toList(),
          onTap: (m) => _openDetail(ctx, m),
        ),
      _Row(
          title: 'Sorties récentes',
          icon: Icons.fiber_new_rounded,
          color: const Color(0xFF00B894),
          items: home.recentlyUpdatedAnimes,
          onTap: (m) => _openDetail(ctx, m)),
      _MixedRow(
          title: 'En ce moment',
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFE17055),
          items: home.trendingAnimes,
          onTap: (m) => _openDetail(ctx, m)),
      _LandscapeRow(
          title: 'Films populaires',
          icon: Icons.theaters_rounded,
          color: const Color(0xFF2980B9),
          items: home.animeMovies,
          onTap: (m) => _openDetail(ctx, m)),
      _RankedRow(
          title: 'Top du moment',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFFE84393),
          items: home.popularAnimes.take(10).toList(),
          onTap: (m) => _openDetail(ctx, m)),
      _Row(
          title: 'Prochainement',
          icon: Icons.upcoming_rounded,
          color: const Color(0xFF0984E3),
          items: home.upcomingAnimes,
          onTap: (m) => _openDetail(ctx, m)),
    ];
  }

  // ── Anime (ancien Tout — contenu anime pur) ────────────────────────────────

  List<Widget> _animeTab(BuildContext ctx, AnilistHome home) {
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

  // ── TV Court ──────────────────────────────────────────────────────────────

  List<Widget> _tvCourtTab(BuildContext ctx, AnilistHome home) {
    final shorts = [
      ...home.recentlyUpdatedAnimes.where((m) => m.format == 'TV_SHORT'),
      ...home.trendingAnimes.where((m) => (m.episodes ?? 99) <= 13 && m.format != 'MOVIE'),
    ].toSet().toList();

    if (shorts.isEmpty) {
      return _promoTab(ctx,
          icon: Icons.timer_rounded,
          title: 'TV Court',
          subtitle: 'Mini-séries, shorts & drama courts',
          color: const Color(0xFF00CEC9),
          route: '/globalSearch');
    }

    return [
      _Row(
          title: 'Mini-dramas & courts',
          icon: Icons.timer_rounded,
          color: const Color(0xFF00CEC9),
          items: shorts.take(20).toList(),
          onTap: (m) => _openDetail(ctx, m)),
      _RankedRow(
          title: 'Les mieux notés (court)',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFFFD79A8),
          items: (List<AnilistMedia>.from(shorts)
                ..sort((a, b) => (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
              .take(10)
              .toList(),
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
          items: home.trendingAnimes.where((m) => m.format != 'MOVIE').toList(),
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
          items: home.popularAnimes.where((m) => m.format != 'MOVIE').take(10).toList(),
          onTap: (m) => _openDetail(ctx, m),
          trailing: _SeeAllBtn(() => _browseTo(ctx, 'ANIME'))),
      _RankedRow(title: 'Mieux notées',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF8E44AD),
          items: home.topRatedAnimes.where((m) => m.format != 'MOVIE').take(10).toList(),
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
  const _TitleBar({required this.onAvatarTap});

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
    final scaffoldBg = Theme.of(ctx).scaffoldBackgroundColor;
    return Container(
      height: _h,
      color: overlaps ? scaffoldBg.withValues(alpha: 0.95) : Colors.transparent,
      child: _SlidingTabRow(tab: tab, onChanged: onChanged),
    );
  }
}

/// Tab row where the active tab uses a fine-bordered card with bold white text.
class _SlidingTabRow extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const _SlidingTabRow({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = cs.primary;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : cs.onSurface.withValues(alpha: 0.35);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: kHomeTabs.length,
      itemBuilder: (_, i) {
        final active = tab == i;
        return GestureDetector(
          onTap: () => onChanged(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(right: i < kHomeTabs.length - 1 ? 16 : 0),
            child: Center(
              child: AnimatedScale(
                scale: active ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: active
                      ? const EdgeInsets.symmetric(horizontal: 11, vertical: 4)
                      : EdgeInsets.zero,
                  decoration: active
                      ? BoxDecoration(
                          border: Border.all(
                            color: activeColor.withValues(alpha: 0.78),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : const BoxDecoration(),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      color: active ? activeColor : inactiveColor,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                      letterSpacing: active ? -0.1 : 0,
                      decoration: TextDecoration.none,
                    ),
                    child: Text(kHomeTabs[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // flag · label · type · genre
    const chips = [
      ('🇰🇷', 'K-Drama',  'MANGA', 'Romance'),
      ('🇨🇳', 'C-Drama',  'MANGA', null),
      ('🇯🇵', 'J-Drama',  'MANGA', 'Slice of Life'),
      ('🇰🇷', 'Manhwa',   'MANGA', null),
      ('🇨🇳', 'Manhua',   'MANGA', null),
      ('🇰🇷', 'Webtoon',  'MANGA', null),
    ];

    final bg = isDark
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerLow;
    final fg = cs.onSurface.withValues(alpha: 0.80);
    final border = cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text(
            'Origine',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (flag, label, type, genre) = chips[i];
              return GestureDetector(
                onTap: () => onBrowse(type, genre),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 0),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
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
// MovieBox-style persistent header: logo icon + search bar + tab row.
// Transparent when the carousel is fully visible; fades to opaque on scroll.
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatefulWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  final ValueNotifier<double> headerOpacity;
  final VoidCallback onSearchTap;
  final VoidCallback onAvatarTap;

  const _HomeHeader({
    required this.tab,
    required this.onTabChanged,
    required this.headerOpacity,
    required this.onSearchTap,
    required this.onAvatarTap,
  });

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
    @override
    Widget build(BuildContext context) {
      final topPad = MediaQuery.paddingOf(context).top;
      final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

      return ValueListenableBuilder<double>(
        valueListenable: widget.headerOpacity,
        builder: (context, opacity, _) {
          final bgColor = scaffoldBg.withValues(alpha: opacity);

          return Container(
            color: bgColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Safe-area scrim — dark gradient behind status bar icons ──
                // Ensures white battery/clock stay readable over bright images.
                Container(
                  height: topPad,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: (1.0 - opacity) * 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // ── Row 1: Logo + Search bar ──────────────────────────────
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: Image.asset(
                            'assets/app_icons/icon.png',
                            width: 56,
                            height: 56,
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onSearchTap,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 14),
                                  Icon(
                                    Icons.search_rounded,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Rechercher un titre...',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Recherche',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Row 2: Tab pills — tighter gap vs Row 1 ──────────────
                SizedBox(
                  height: 36,
                  child: _SlidingTabRow(
                    tab: widget.tab,
                    onChanged: widget.onTabChanged,
                  ),
                ),
              ],
            ),
          );
        },
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
// TMDB poster row — horizontal scroll of TmdbPosterCard
// ─────────────────────────────────────────────────────────────────────────────

class _TmdbRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<TmdbMedia> items;
  final void Function(TmdbMedia) onTap;

  const _TmdbRow({
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
            height: 195,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => TmdbPosterCard(
                media: items[i],
                onTap: () => onTap(items[i]),
                width: 120,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TMDB landscape row — 16:9 cards
// ─────────────────────────────────────────────────────────────────────────────

class _TmdbLandscapeRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<TmdbMedia> items;
  final void Function(TmdbMedia) onTap;

  const _TmdbLandscapeRow({
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
              itemBuilder: (_, i) => TmdbLandscapeCard(
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
// TMDB ranked row — top-10 with big rank numbers
// ─────────────────────────────────────────────────────────────────────────────

class _TmdbRankedRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<TmdbMedia> items;
  final void Function(TmdbMedia) onTap;

  const _TmdbRankedRow({
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
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => TmdbRankedCard(
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
