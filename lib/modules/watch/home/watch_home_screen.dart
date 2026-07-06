import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/modules/widgets/inline_filter_chips_mixin.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_custom_lists.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/get_source_baseurl.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/services/supports_latest.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';

// ── WatchHomeScreen ──────────────────────────────────────────────────────────

class WatchHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isLatest;
  const WatchHomeScreen({
    required this.source,
    this.isLatest = false,
    super.key,
  });

  @override
  ConsumerState<WatchHomeScreen> createState() => _WatchHomeScreenState();
}

class _WatchHomeScreenState extends ConsumerState<WatchHomeScreen>
    with InlineFilterChipsMixin<WatchHomeScreen> {
  late Source _source = widget.source;
  Source get source => _source;
  bool get isLocal => source.name == 'local' && source.lang == '';

  static const _kHomeIdx    = 0;
  static const _kPopularIdx = 1;
  static const _kLatestIdx  = 2;
  // ignore: unused_field
  static const _kFilterIdx  = 3;

  // _selectedIdx: start on Home only when custom lists exist
  late int _selectedIdx = widget.isLatest
      ? _kLatestIdx
      : (_customLists.isNotEmpty ? _kHomeIdx : _kPopularIdx);

  bool _isSearching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<MManga> _catalogueItems = [];
  int _cataloguePage = 1;
  bool _catalogueHasNext = true;
  bool _catalogueLoading = false;

  late final List<Map<String, dynamic>> _customLists =
      isLocal ? [] : getCustomLists(source: source);
  late final List<dynamic> filterList =
      isLocal ? [] : getFilterList(source: source);
  late List<dynamic> filters = List.from(filterList);

  bool _isFiltering = false;

  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _page = 1;
  final List<MManga> _mangaList = [];

  AsyncValue<MPages?>? _getManga;
  Timer? _suggestionTimer;
  List<String> _suggestions = [];
  bool _isListView = false;

  // ── Extension sub-tab state ──────────────────────────────────────────────
  int _mbSubTabIdx    = 0; // index into _kMbSubTabs list

  // MovieBox sub-tabs — only distinct views (no duplicate Popular tabs)
  static const _kMbSubTabs = [
    (label: '🤼\u202FFightZone', watchtowerIdx: 0),
    (label: 'Movie',             watchtowerIdx: 0),
    (label: 'TV Shows',          watchtowerIdx: 2),
    (label: 'Popular',           watchtowerIdx: 1),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void onFilterChanged() {
    // Called inside setState by InlineFilterChipsMixin: clears results so
    // the next build() re-fetches with the updated filter selection.
    _mangaList.clear();
    _page = 1;
    _hasNextPage = true;
    _isFiltering = true;
  }

  bool get supportsLatest =>
      isLocal ? true : ref.watch(supportsLatestProvider(source: source));

  // ── Filter ──────────────────────────────────────────────────────────────

  Future<void> _openFilterSheet(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surface
                      .withValues(alpha: isDark ? 0.82 : 0.90),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              if (mounted) setState(() {
                                filters = List.from(filterList);
                                _isFiltering = false;
                                _mangaList.clear();
                                _page = 1;
                                _hasNextPage = true;
                              });
                            },
                            child: Text('Réinitialiser',
                                style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error, fontSize: 14)),
                          ),
                          const Expanded(
                            child: Text('Filtres',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('Fermer', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text('Vue', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: Theme.of(sheetCtx).colorScheme.onSurface)),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ViewToggleBtn(
                                  icon: Icons.grid_view_rounded,
                                  selected: !_isListView,
                                  onTap: () { setSheetState((){}); if (mounted) setState(() => _isListView = false); },
                                ),
                                _ViewToggleBtn(
                                  icon: Icons.view_list_rounded,
                                  selected: _isListView,
                                  onTap: () { setSheetState((){}); if (mounted) setState(() => _isListView = true); },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        child: FilterWidget(
                          filterList: filters,
                          onChanged: (applied) {
                            setSheetState(() => filters = applied);
                            if (mounted) setState(() {
                              filters = applied;
                              _isFiltering = true;
                              _selectedIdx = _kHomeIdx;
                              _mangaList.clear();
                              _page = 1;
                              _hasNextPage = true;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(sheetCtx).viewPadding.bottom),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      filters = List.from(filterList);
      _isFiltering = false;
      _mangaList.clear();
      _page = 1;
      _hasNextPage = true;
    });
  }

  // ── Scroll / load more (tab list views) ─────────────────────────────────

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _hasNextPage &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    try {
      MPages? result;
      final next = _page + 1;
      if (_selectedIdx == _kLatestIdx && !_isSearching) {
        result = await ref
            .read(getLatestUpdatesProvider(source: source, page: next).future);
      } else if (_selectedIdx == _kPopularIdx && !_isSearching) {
        result = await ref
            .read(getPopularProvider(source: source, page: next).future);
      } else if (_isSearching && _query.isNotEmpty) {
        result = await ref.read(searchProvider(
          source: source,
          query: _query,
          page: next,
          filterList: filters,
        ).future);
      } else if (_isFiltering) {
        result = await ref.read(searchProvider(
          source: source,
          query: '',
          page: next,
          filterList: filters,
        ).future);
      }
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() {
          _page = next;
          _hasNextPage = result!.hasNextPage;
          _mangaList.addAll(result.list);
        });
      } else if (mounted) {
        setState(() => _hasNextPage = false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Catalogue infinite scroll (driven by NotificationListener in _buildHomeView) ──

  Future<void> _loadCatalogue() async {
      if (_catalogueLoading || !_catalogueHasNext) return;
      setState(() => _catalogueLoading = true);
      try {
        final hasCatList = _customLists.any((cl) => cl['id'] == 'catalogue');
        MPages? result;
        if (hasCatList) {
          result = await ref.read(getCustomListProvider(
            source: source, listId: 'catalogue', page: _cataloguePage).future);
        } else {
          result = await ref.read(getPopularProvider(source: source, page: _cataloguePage).future);
        }
      if (mounted && result != null && result.list.isNotEmpty) {
        final r = result!;
        setState(() {
          _cataloguePage++;
          _catalogueHasNext = r.hasNextPage;
          _catalogueItems.addAll(r.list);
        });
      } else if (mounted) {
        setState(() => _catalogueHasNext = false);
      }
    } finally {
      if (mounted) setState(() => _catalogueLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSearching && _query.isNotEmpty) {
      _getManga = ref.watch(searchProvider(
        source: source, query: _query, page: 1, filterList: filters,
      ));
    } else if (_isFiltering) {
      _getManga = ref.watch(searchProvider(
        source: source, query: '', page: 1, filterList: filters,
      ));
    } else if (_selectedIdx == _kLatestIdx) {
      _getManga = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    } else if (_selectedIdx == _kPopularIdx) {
      _getManga = ref.watch(getPopularProvider(source: source, page: 1));
    } else {
      _getManga = ref.watch(getPopularProvider(source: source, page: 1));
    }

    if (_isSearching) return _buildSearchScreen(context);

    // ── MovieBox dark background ─────────────────────────────────────────────
    const mbBg = Color(0xFF101114);

    return Scaffold(
      backgroundColor: mbBg,
      extendBody: true,
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (ctx, innerBoxIsScrolled) =>
            [_buildSliverAppBar(ctx, innerBoxIsScrolled)],
        body: _buildBody(context),
      ),
    );
  }

  // ── Sliver app bar ───────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext ctx, bool forceElevated) {
    // ── MovieBox exact AppBar: logo left + search bar center + icons right ──
    const mbBg    = Color(0xFF101114);
    // ignore: unused_local_variable
    const white10 = Color(0x1AFFFFFF);
    const white60 = Color(0x99FFFFFF);

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      forceElevated: forceElevated,
      // Transparent so our flexibleSpace shows through
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: _computeCarouselExpandedHeight(ctx),
      // ── Extension logo on the left ───────────────────────────────────────
      automaticallyImplyLeading: false,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: Padding(
        padding: const EdgeInsets.all(9),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: source.iconUrl != null && (source.iconUrl!).isNotEmpty
              ? Image.network(
                  source.iconUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.movie_outlined, color: Colors.white, size: 22),
                )
              : const Icon(Icons.movie_outlined, color: Colors.white, size: 22),
        ),
      ),
      // ── Title: search bar ────────────────────────────────────────────────
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () => setState(() => _isSearching = true),
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Search movies, TV shows…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // "Search" button (brand green — #07b84e)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: const Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF07b84e),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // ── No actions (menu removed per design) ─────────────────────────────
      actions: const [],
      // ── Bottom: MovieBox MagicIndicator-style sub-tabs ────────────────────
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildMbSubDock(ctx),
      ),
      // ── flexibleSpace: carousel (home) or solid dark bg ─────────────────
      flexibleSpace: _buildFlexibleSpaceCarousel(ctx),
    );
  }

  /// Returns the expanded height of the SliverAppBar.
  /// Home tab with lists → toolbar + carousel + tab dock.
  /// Any other tab → 0 (collapsed only).
  double _computeCarouselExpandedHeight(BuildContext ctx) {
    final isHomeView = (_mbSubTabIdx == 0 || _mbSubTabIdx == 3) &&
        _customLists.isNotEmpty && !_isFiltering && !_isSearching;
    if (!isHomeView) return 0;
    final size = MediaQuery.sizeOf(ctx);
    final isLandscape = size.width > size.height;
    final bannerH = isLandscape
        ? (size.height * 0.72).clamp(240.0, 420.0)
        : (size.width * (9.0 / 16.0) + 88.0).clamp(220.0, size.height * 0.52);
    return kToolbarHeight + bannerH + 92.0 + 44.0;
  }

  /// Background for the SliverAppBar's flexible space.
  /// Shows the hero carousel when on the home tab, otherwise a solid dark fill.
  Widget _buildFlexibleSpaceCarousel(BuildContext ctx) {
    const mbBg = Color(0xFF101114);
    final isHomeView = (_mbSubTabIdx == 0 || _mbSubTabIdx == 3) &&
        _customLists.isNotEmpty && !_isFiltering && !_isSearching;
    if (!isHomeView) return Container(color: mbBg);

    final carouselList =
        _customLists.where((cl) => cl['id'] == 'carousel').firstOrNull;

    final Widget carousel = Consumer(builder: (c, r, _) {
      if (carouselList != null) {
        final data = r.watch(
            getCustomListProvider(source: source, listId: 'carousel', page: 1));
        return data.when(
          data: (d) {
            final items = d?.list ?? [];
            if (items.isEmpty) return _buildHeroSkeleton(ctx);
            return _WatchHero(mangas: items, source: source);
          },
          loading: () => _buildHeroSkeleton(ctx),
          error: (_, __) {
            final pop = r.watch(getPopularProvider(source: source, page: 1));
            return pop.when(
              data: (d) {
                final items = d?.list ?? [];
                if (items.isEmpty) return _buildHeroSkeleton(ctx);
                return _WatchHero(mangas: items.take(8).toList(), source: source);
              },
              loading: () => _buildHeroSkeleton(ctx),
              error: (_, __) => _buildHeroSkeleton(ctx),
            );
          },
        );
      }
      final pop = r.watch(getPopularProvider(source: source, page: 1));
      return pop.when(
        data: (d) {
          final items = d?.list ?? [];
          if (items.isEmpty) return _buildHeroSkeleton(ctx);
          return _WatchHero(mangas: items.take(8).toList(), source: source);
        },
        loading: () => _buildHeroSkeleton(ctx),
        error: (_, __) => _buildHeroSkeleton(ctx),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Space for toolbar (search bar overlaid here via SliverAppBar title)
        Container(height: kToolbarHeight + 8, color: mbBg),
        Expanded(child: carousel),
        // Space for tab dock (overlaid by SliverAppBar's `bottom:`)
        Container(height: 44, color: mbBg),
      ],
    );
  }

  // ── MovieBox MagicIndicator-style scrollable sub-dock ────────────────────
  // From fragment_home.xml: MagicIndicator height=32dp, marginTop=4dp, marginBottom=8dp
  // Selected tab: white text + green underline. Unselected: white_60 text.

  Widget _buildMbSubDock(BuildContext ctx) {
    // MovieBox exact: active tab = GREEN FILLED PILL, inactive = plain text
    const white60 = Color(0x99FFFFFF);
    const brandGreen = Color(0xFF07b84e);

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
        itemCount: _kMbSubTabs.length,
        itemBuilder: (_, i) {
          final tab    = _kMbSubTabs[i];
          final active = _mbSubTabIdx == i;
          return GestureDetector(
            onTap: () => setState(() {
              _mbSubTabIdx = i;
              _selectedIdx = tab.watchtowerIdx;
              _isFiltering = false;
              _mangaList.clear();
              _page = 1;
              _hasNextPage = true;
            }),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? brandGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : white60,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body dispatcher ──────────────────────────────────────────────────────
  // When sub-tab 0 (FightZone/Home) or 3 (Movie in home) is active → home view.
  // Otherwise → list view (popular, latest, etc.)

  Widget _buildBody(BuildContext ctx) {
    // Home-style tabs show the carousel+sections page
    final isHomeSubTab = (_mbSubTabIdx == 0 || _mbSubTabIdx == 3);
    if (isHomeSubTab && _customLists.isNotEmpty && !_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ── Home view ────────────────────────────────────────────────────────────

  Widget _buildHomeView(BuildContext ctx) {
      // Partition custom lists into their roles
      final categoryLists = _customLists.where((cl) => cl['layout'] == 'category').toList();
      final catalogueList = _customLists.where((cl) => cl['id'] == 'catalogue').firstOrNull;
      // Cap to 8 sections to avoid flooding the JS isolate with simultaneous requests
      final regularLists  = _customLists.where((cl) =>
        cl['id'] != 'carousel' && cl['layout'] != 'category' && cl['id'] != 'catalogue'
      ).take(8).toList();

      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400 &&
                _catalogueHasNext && !_catalogueLoading) {
              _loadCatalogue();
            }
          }
          return false;
        },
        child: CustomScrollView(
        slivers: [
          // ── Carousel is now in the SliverAppBar flexibleSpace ───────────

          // ── Catégories chips ─────────────────────────────────────────────
          if (categoryLists.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildCategoryChips(ctx, categoryLists),
            ),

          // ── Sections dynamiques (operatingList) ──────────────────────────
          ...regularLists.asMap().entries.map((entry) {
            final sectionIdx = entry.key;
            final cl = entry.value;
            final listId = cl['id'] as String;
            final listName = cl['name'] as String? ?? listId;

            final String layout  = cl['layout'] as String? ?? '';
            final Color accent   = _parseHexColor(cl['color'] as String?, _sectionAccent(sectionIdx));
            final IconData icon  = _kIconMap[cl['icon'] as String?] ?? _sectionIcon(sectionIdx);
            final dynamic seeAll = cl['seeAll'];

            final bool isRanked    = layout == 'ranked';
            final bool isSpotlight = layout == 'spotlight' || (!isRanked && layout.isNotEmpty);

            VoidCallback? onSeeAllCb;
            if (seeAll == false || (seeAll == null && isRanked)) {
              onSeeAllCb = null;
            } else if (seeAll == 'latest') {
              onSeeAllCb = () => setState(() {
                    _selectedIdx = _kLatestIdx;
                    _mangaList.clear(); _page = 1; _hasNextPage = true;
                  });
            } else if (seeAll == 'popular') {
              onSeeAllCb = () => setState(() {
                    _selectedIdx = _kPopularIdx;
                    _mangaList.clear(); _page = 1; _hasNextPage = true;
                  });
            } else {
              onSeeAllCb = () => Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source, title: listName,
                      type: _SectionKind.custom, customListId: listId,
                    ),
                  ));
            }

            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(ctx,
                    title: listName, accent: accent, icon: icon, onSeeAll: onSeeAllCb,
                  ),
                  Consumer(builder: (c, ref, _) {
                    final sData = ref.watch(getCustomListProvider(
                      source: source, listId: listId, page: 1,
                    ));
                    return sData.when(
                      data: (d) {
                        final items = d?.list ?? [];
                        if (isRanked)         return _buildRankedRow(ctx, items);
                        else if (isSpotlight) return _buildSpotlightRow(ctx, items);
                        else                  return _buildCompactRow(ctx, items);
                      },
                      loading: () => isRanked
                          ? _buildRankedRowSkeleton(ctx)
                          : _buildCompactRowSkeleton(ctx),
                      error: (_, __) => const SizedBox(height: 8),
                    );
                  }),
                ],
              ),
            );
          }),

          // ── If no custom lists → show standard Latest row ────────────────
          if (_customLists.isEmpty && supportsLatest)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(ctx,
                    title: 'Derniers ajouts', accent: ctx.primaryColor,
                    icon: Icons.update_rounded,
                    onSeeAll: () => setState(() {
                      _selectedIdx = _kLatestIdx;
                      _mangaList.clear(); _page = 1; _hasNextPage = true;
                    }),
                  ),
                  Consumer(builder: (c, ref, _) {
                    final latest = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
                    return latest.when(
                      data: (d) => _buildCompactRow(ctx, d?.list ?? []),
                      loading: () => _buildCompactRowSkeleton(ctx),
                      error: (_, __) => const SizedBox(height: 8),
                    );
                  }),
                ],
              ),
            ),

          // ── Catalogue header — SVG lauriers, centré, typo pro ────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/left-laurel.svg',
                      width: 22, height: 38,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withValues(alpha: 0.80),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'CATALOGUE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: Theme.of(ctx).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    SvgPicture.asset(
                      'assets/icons/right-laurel.svg',
                      width: 22, height: 38,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withValues(alpha: 0.80),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Catalogue grid (infinite scroll) ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            sliver: Consumer(builder: (c, ref, _) {
              final hasCatList = catalogueList != null;
              final initial = hasCatList
                  ? ref.watch(getCustomListProvider(source: source, listId: 'catalogue', page: 1))
                  : ref.watch(getPopularProvider(source: source, page: 1));
              initial.whenData((d) {
                if (d != null && _catalogueItems.isEmpty && d.list.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _catalogueItems.isEmpty) {
                      setState(() {
                        _catalogueItems.addAll(d.list);
                        _cataloguePage = 2;
                        _catalogueHasNext = d.hasNextPage;
                      });
                    }
                  });
                }
              });

              if (_catalogueItems.isEmpty) {
                return SliverToBoxAdapter(
                  child: Skeletonizer(
                    enabled: true,
                    effect: ShimmerEffect(
                      baseColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      highlightColor: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.white.withValues(alpha: 0.85),
                      duration: const Duration(milliseconds: 900),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140, childAspectRatio: 0.65,
                        mainAxisSpacing: 8, crossAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (_, __) => _buildSkeletonCardItem(ctx),
                    ),
                  ),
                );
              }

              return SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140, childAspectRatio: 0.65,
                  mainAxisSpacing: 8, crossAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c2, i) {
                    if (i >= _catalogueItems.length) {
                      return const Center(
                        child: Padding(padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    return MangaImageCardWidget(
                      getMangaDetail: _catalogueItems[i], source: source,
                      itemType: source.itemType, isComfortableGrid: false,
                    );
                  },
                  childCount: _catalogueItems.length + (_catalogueLoading ? 3 : 0),
                ),
              );
            }),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ), // CustomScrollView
      ); // NotificationListener
    }

    // ── Category chips strip ─────────────────────────────────────────────────

    Widget _buildCategoryChips(BuildContext ctx, List<Map<String, dynamic>> cats) {
      // MovieBox exact: rectangular image-background tiles, dark overlay, text at bottom
      return SizedBox(
        height: 68,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final cl = cats[i];
            final listId   = cl['id'] as String;
            final listName = cl['name'] as String? ?? listId;
            final imgUrl   = cl['imageUrl'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _WatchSectionPage(
                    source: source, title: listName,
                    type: _SectionKind.custom, customListId: listId,
                  ),
                )),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 115, height: 60,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imgUrl.isNotEmpty)
                          Image.network(imgUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E2126)))
                        else
                          const ColoredBox(color: Color(0xFF1E2126)),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.black.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.70)],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 7, left: 10, right: 4,
                          child: Text(listName,
                              style: const TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // ── Section accent + icon helpers (index fallbacks kept for retro-compat) ──

  static const _kIconMap = <String, IconData>{
    'fiber_new':              Icons.fiber_new_rounded,
    'trending_up':            Icons.trending_up_rounded,
    'animation':              Icons.animation_rounded,
    'theaters':               Icons.theaters_rounded,
    'star':                   Icons.star_rounded,
    'bolt':                   Icons.bolt_rounded,
    'movie':                  Icons.movie_rounded,
    'live_tv':                Icons.live_tv_rounded,
    'history':                Icons.history_rounded,
    'category':               Icons.category_rounded,
    'new_releases':           Icons.new_releases_rounded,
    'local_movies':           Icons.local_movies_rounded,
    'tv':                     Icons.tv_rounded,
    'sports':                 Icons.sports_rounded,
    'music_note':             Icons.music_note_rounded,
    // ── Extra icons used by extensions ─────────────────────────────────
    'apps':                   Icons.apps_rounded,
    'local_fire_department':  Icons.local_fire_department_rounded,
    'dark_mode':              Icons.dark_mode_rounded,
    'sentiment_very_satisfied': Icons.sentiment_very_satisfied_rounded,
    'favorite':               Icons.favorite_rounded,
    'language':               Icons.language_rounded,
    'flag':                   Icons.flag_rounded,
    'public':                 Icons.public_rounded,
    'home':                   Icons.home_rounded,
    'explore':                Icons.explore_rounded,
    'whatshot':               Icons.whatshot_rounded,
    'grade':                  Icons.grade_rounded,
    'thumb_up':               Icons.thumb_up_rounded,
    'auto_awesome':           Icons.auto_awesome_rounded,
    'child_care':             Icons.child_care_rounded,
    'comedy':                 Icons.sentiment_satisfied_rounded,
    'romance':                Icons.favorite_border_rounded,
    'horror':                 Icons.remove_red_eye_rounded,
    'drama':                  Icons.theater_comedy_rounded,
  };

  /// Parse a CSS hex color string like "#FF0000" → Color.
  /// Falls back to [fallback] if parsing fails.
  Color _parseHexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return fallback;
  }

  Color _sectionAccent(int idx) {
    const colors = [
      Color(0xFF00BCD4), // Derniers ajouts — cyan
      Color(0xFFFFB300), // Top 15 — amber
      Color(0xFF9C27B0), // Animations — purple
      Color(0xFF4CAF50), // Docs & Spectacles — green
    ];
    return colors[idx % colors.length];
  }

  IconData _sectionIcon(int idx) {
    const icons = [
      Icons.fiber_new_rounded,
      Icons.trending_up_rounded,
      Icons.animation_rounded,
      Icons.theaters_rounded,
    ];
    return icons[idx % icons.length];
  }

  // ── Section header ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext ctx, {
    required String title,
    Color? accent,
    IconData? icon,
    VoidCallback? onSeeAll,
  }) {
    // MovieBox exact: plain white bold title left, grey "Tous >" right — NO colored bar, NO icon
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skeleton.ignore: protect section title from any ancestor Skeletonizer
          Skeleton.ignore(
            child: Text(title,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                )),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tous',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0x99FFFFFF))),
                  Icon(Icons.chevron_right_rounded, size: 16, color: Color(0x99FFFFFF)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Ranked row (Top 15) ──────────────────────────────────────────────────

  Widget _buildRankedRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(15).toList();
    return SizedBox(
      height: 196,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) => _RankedCard(
          manga: capped[i], source: source,
        ),
      ),
    );
  }

  Widget _buildRankedRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 190,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 105,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 36, height: 52,
                      color: base.withValues(alpha: 0.4)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 155,
                      decoration: BoxDecoration(
                          color: base, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Spotlight / Carousel row ──────────────────────────────────────────────

  Widget _buildSpotlightRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(20).toList();
    return SizedBox(
      height: 196,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) => _SpotlightCard(manga: capped[i], source: source),
      ),
    );
  }

  // ── Compact row (Animations, Docs & Spectacles, etc.) ────────────────────

  Widget _buildCompactRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(12).toList();
    return SizedBox(
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) => _CompactCard(manga: capped[i], source: source),
      ),
    );
  }

  Widget _buildCompactRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 142,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 152, height: 86,
                  decoration: BoxDecoration(color: base,
                      borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── List view (Popular / Latest / Filter / Search tabs) ──────────────────

  Widget _buildListView(BuildContext ctx) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
              _hasNextPage && !_isLoadingMore) {
            _loadMore();
          }
        }
        return false;
      },
      child: _getManga?.when(
            data: (data) {
              if (data != null && _mangaList.isEmpty && data.list.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _mangaList.isEmpty) {
                    setState(() {
                      _mangaList.addAll(data.list);
                      _hasNextPage = data.hasNextPage;
                    });
                  }
                });
              }
              if (_mangaList.isEmpty) {
                if (data?.list.isEmpty ?? true) {
                  return Center(
                    child: Text(ctx.l10n.no_result,
                        style: TextStyle(color: Theme.of(ctx).hintColor)),
                  );
                }
                return _buildSkeletonGrid();
              }
              return _buildGrid(ctx);
            },
            loading: () => _mangaList.isEmpty ? _buildSkeletonGrid() : _buildGrid(ctx),
            error: (e, _) => _buildError(ctx, e),
          ) ??
          _buildSkeletonGrid(),
    );
  }

  Widget _buildGrid(BuildContext ctx) {
    if (_isListView) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
        itemCount: _mangaList.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= _mangaList.length) {
            return const Center(
              child: Padding(padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: MangaImageCardWidget(
              getMangaDetail: _mangaList[i],
              source: source,
              itemType: source.itemType,
              isComfortableGrid: true,
            ),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 0.65,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _mangaList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (c, i) {
        if (i >= _mangaList.length) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return MangaImageCardWidget(
          getMangaDetail: _mangaList[i],
          source: source,
          itemType: source.itemType,
          isComfortableGrid: false,
        );
      },
    );
  }

  /// Single skeleton card — matches the look of a compact-grid card:
  /// image area fills the card, dark gradient + text stub overlaid at bottom.
  /// This means ONE visual element per card (no separate name row below).
  Widget _buildSkeletonCardItem(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.surfaceContainerHighest;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // image area
          Container(color: base),
          // gradient + title stub — mirrors BottomTextWidget in non-comfortable mode
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (isDark ? Colors.black : Colors.black54)
                        .withValues(alpha: 0.65),
                  ],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
              child: Container(
                height: 9,
                width: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.white.withValues(alpha: 0.85),
        duration: const Duration(milliseconds: 900),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => _buildSkeletonCardItem(context),
      ),
    );
  }

  // ── Search suggestions ──────────────────────────────────────────────────

  void _onSearchQueryChanged(String v) {
    setState(() {
      _query = v;
      _mangaList.clear();
      _page = 1;
      _hasNextPage = true;
      if (v.isEmpty) _suggestions = [];
    });
    _suggestionTimer?.cancel();
    if (v.trim().length >= 2) {
      _suggestionTimer = Timer(const Duration(milliseconds: 450), () {
        _fetchSuggestions(v);
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    try {
      final result = await getIsolateService.get<dynamic>(
        query: query,
        source: source,
        serviceType: 'getSuggestions',
        proxyServer: ref.read(androidProxyServerStateProvider),
      );
      if (!mounted || _query != query) return;
      final suggestions = result is List
          ? result.map((e) => e.toString()).take(8).toList()
          : <String>[];
      setState(() => _suggestions = suggestions);
    } catch (_) {
      // Extension does not support getSuggestions — silent no-op
    }
  }

  // ── Search screen ────────────────────────────────────────────────────────

  Widget _buildSearchScreen(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme
                            .surfaceContainerHighest.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search, size: 20, color: Theme.of(ctx).hintColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                    color: Theme.of(ctx).hintColor, fontSize: 16),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: _onSearchQueryChanged,
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _mangaList.clear();
                                setState(() => _query = '');
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.cancel, size: 18,
                                    color: Theme.of(ctx).hintColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _isSearching = false; _query = '';
                        _mangaList.clear(); _page = 1; _hasNextPage = true;
                      });
                    },
                    child: Text('Cancel',
                        style: TextStyle(color: ctx.primaryColor, fontSize: 16)),
                  ),
                ],
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(ctx).dividerColor.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.map((s) => InkWell(
                    onTap: () {
                      _searchCtrl.text = s;
                      setState(() { _query = s; _suggestions = []; _mangaList.clear(); _page = 1; _hasNextPage = true; });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: Theme.of(ctx).hintColor),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s, style: const TextStyle(fontSize: 14))),
                          Icon(Icons.north_west, size: 14, color: Theme.of(ctx).hintColor),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),
            if (filterList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      FilterIconBtn(
                        activeCount: countActiveFilters(
                            filters.isEmpty ? filterList : filters),
                        onTap: () => _openFilterSheet(ctx),
                      ),
                      ...buildFilterChips(
                          ctx, filters.isEmpty ? filterList : filters),
                    ],
                  ),
                ),
              ),
            if (filterList.isNotEmpty && expandedChipName != null)
              buildChipExpansionPanel(
                  ctx, filters.isEmpty ? filterList : filters),
            Expanded(child: _buildListView(ctx)),
          ],
        ),
      ),
    );
  }

  // ── Skeletons & error ────────────────────────────────────────────────────

  Widget _buildHeroSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    final size = MediaQuery.sizeOf(ctx);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1400)),
      child: Container(
        width: size.width,
        height: _heroHeight(size),
        color: base,
      ),
    );
  }

  double _heroHeight(Size size) {
    final isLandscape = size.width > size.height;
    if (isLandscape) {
      return (size.height * 0.72).clamp(240.0, 420.0);
    }
    final target = size.width * (9.0 / 16.0) + 88.0;
    return target.clamp(220.0, size.height * 0.52);
  }

  Widget _buildError(BuildContext ctx, Object error) {
    void retry() {
      if (_selectedIdx == _kLatestIdx) {
        ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
      } else if (_selectedIdx == _kPopularIdx) {
        ref.invalidate(getPopularProvider(source: source, page: 1));
      } else if (_isSearching && _query.isNotEmpty) {
        ref.invalidate(searchProvider(
            source: source, query: _query, page: 1, filterList: filters));
      } else {
        ref.invalidate(getPopularProvider(source: source, page: 1));
      }
    }

    if (isCloudflareError(error.toString()) ||
        ((source.hasCloudflare ?? false) &&
            error.toString().toLowerCase().contains('timeout'))) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CloudflareErrorWidget(
            errorText: error.toString(),
            url: ref.read(sourceBaseUrlProvider(source: source)),
            onRetry: retry,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48,
                color: Theme.of(ctx).hintColor),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(ctx).hintColor, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

}

// ── Small grid/list toggle button (used in filter sheet) ────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggleBtn({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 18,
            color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.55)),
      ),
    );
  }
}

// ── Tab data ──────────────────────────────────────────────────────────────────

class _WatchTab {
  final IconData? icon;     // Material icon (null if using emoji)
  final String? emojiStr;   // emoji / texte court (null si icône Material)
  final String label;
  final int idx;
  const _WatchTab(this.icon, this.label, this.idx, {this.emojiStr});
}

// ── Hero carousel ─────────────────────────────────────────────────────────────

class _WatchHero extends ConsumerStatefulWidget {
  final List<MManga> mangas;
  final Source source;
  const _WatchHero({required this.mangas, required this.source});

  @override
  ConsumerState<_WatchHero> createState() => _WatchHeroState();
}

class _WatchHeroState extends ConsumerState<_WatchHero> {
  late final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;

  double _heroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    if (isLandscape) {
      return (size.height * 0.72).clamp(240.0, 420.0);
    }
    final target = size.width * (9.0 / 16.0) + 88.0;
    return target.clamp(220.0, size.height * 0.52);
  }

  @override
  void initState() {
    super.initState();
    if (widget.mangas.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_ctrl.hasClients) return;
        _page = (_page + 1) % widget.mangas.length;
        _ctrl.animateToPage(_page,
            duration: const Duration(milliseconds: 520), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  // MovieBox hero: banner image height + 92dp content cards strip
  static const double _kCardsH = 92.0;

  @override
  Widget build(BuildContext context) {
    final bannerH = _heroHeight(context);
    final totalH  = bannerH + _kCardsH;

    final curr = widget.mangas[_page];
    final next = _page + 1 < widget.mangas.length
        ? widget.mangas[_page + 1]
        : (widget.mangas.length > 1 ? widget.mangas[0] : null);

    return SizedBox(
      height: totalH,
      child: Column(
        children: [
          // ── Banner image ────────────────────────────────────────────────
          SizedBox(
            height: bannerH,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _ctrl,
                  itemCount: widget.mangas.length,
                  onPageChanged: (p) {
                    setState(() => _page = p);
                  },
                  itemBuilder: (_, i) => _HeroSlide(
                    manga: widget.mangas[i],
                    source: widget.source,
                    height: bannerH,
                  ),
                ),
                // Slim dot indicators — bottom of banner
                Positioned(
                  bottom: 10, left: 14,
                  child: Row(
                    children: List.generate(widget.mangas.length, (i) {
                      final isActive = _page == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 4),
                        width: isActive ? 16 : 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // ── Content cards strip (2 cards) — MovieBox exact ──────────────
          Container(
            height: _kCardsH,
            color: const Color(0xFF101114),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _HeroContentCard(manga: curr, source: widget.source)),
                const SizedBox(width: 8),
                if (next != null)
                  Expanded(child: _HeroContentCard(manga: next, source: widget.source)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero content card (bottom strip under the banner) ─────────────────────────
// MovieBox exact: thumbnail left | title+genre middle | green play circle right
class _HeroContentCard extends ConsumerWidget {
  final MManga manga;
  final Source source;
  const _HeroContentCard({required this.manga, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
        source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> thumb = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return GestureDetector(
      onTap: () {
        if (manga.link != null) {
          pushToMangaReaderDetail(
            ref: ref, context: context, getManga: manga,
            lang: source.lang!, source: source.name!,
            itemType: source.itemType, sourceId: source.id,
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C20),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 52,
              child: imgUrl.isNotEmpty
                  ? Image(image: thumb, fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF252830),
                        child: Center(child: Icon(Icons.movie_outlined,
                            size: 20, color: Colors.white24))))
                  : const ColoredBox(color: Color(0xFF252830),
                      child: Center(child: Icon(Icons.movie_outlined,
                          size: 20, color: Colors.white24))),
            ),
            // Title + genre
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(manga.name ?? '',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    if ((manga.genre ?? []).isNotEmpty)
                      Text(manga.genre!.first,
                          style: const TextStyle(color: Color(0x80FFFFFF),
                              fontSize: 9, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
            // Green play circle
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF07b84e), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero slide ────────────────────────────────────────────────────────────────

class _HeroSlide extends ConsumerWidget {
  final MManga manga;
  final MManga? detail;
  final Source source;
  final double height;
  const _HeroSlide({required this.manga, this.detail, required this.source,
      required this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
        source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    // MovieBox: banner image only — no title overlay (info is in the content cards strip)
    return GestureDetector(
      onTap: () {
        if (manga.link != null) {
          pushToMangaReaderDetail(
            ref: ref, context: context, getManga: manga,
            lang: source.lang!, source: source.name!,
            itemType: source.itemType, sourceId: source.id,
          );
        }
      },
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imgUrl.isNotEmpty
                ? Image(image: cover, fit: BoxFit.cover, alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF1A1C22),
                      child: Center(child: Icon(Icons.play_circle_outline_rounded,
                          size: 56, color: Colors.white24))))
                : const ColoredBox(color: Color(0xFF1A1C22),
                    child: Center(child: Icon(Icons.play_circle_outline_rounded,
                        size: 56, color: Colors.white24))),
            // Subtle vignette to blend into content cards below
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.12)],
                    stops: const [0.6, 1.0],
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

// ── Ranked card (Top 15 Tendances) ───────────────────────────────────────────
// Big rank number on the left side, portrait image on the right

class _RankedCard extends ConsumerStatefulWidget {
  final MManga manga;
  final Source source;
  const _RankedCard({required this.manga, required this.source});

  @override
  ConsumerState<_RankedCard> createState() => _RankedCardState();
}

class _RankedCardState extends ConsumerState<_RankedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 100),
    lowerBound: 0.0, upperBound: 1.0,
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.92)
      .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(headersProvider(
        source: widget.source.name!, lang: widget.source.lang!, sourceId: widget.source.id));
    final imgUrl = toImgUrl(widget.manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) async {
          await _pressCtrl.reverse();
          if (widget.manga.link != null && mounted) {
            pushToMangaReaderDetail(
              ref: ref, context: context, getManga: widget.manga,
              lang: widget.source.lang!, source: widget.source.name!,
              itemType: widget.source.itemType, sourceId: widget.source.id,
            );
          }
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 116,
            height: 172,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imgUrl.isNotEmpty
                      ? Image(image: cover, fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.play_circle_outline_rounded,
                                size: 42, color: Colors.white24),
                          ))
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.play_circle_outline_rounded,
                              size: 42, color: Colors.white24)),
                  // Gradient for title legibility
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.78),
                          ],
                          stops: const [0.42, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Title at bottom
                  Positioned(
                    bottom: 9, left: 10, right: 10,
                    child: Text(widget.manga.name ?? '',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                          height: 1.3,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Spotlight card (Derniers ajouts / Carousel) ───────────────────────────────

class _SpotlightCard extends ConsumerStatefulWidget {
  final MManga manga;
  final Source source;
  const _SpotlightCard({required this.manga, required this.source});

  @override
  ConsumerState<_SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends ConsumerState<_SpotlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 110),
    lowerBound: 0.0, upperBound: 1.0,
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.93)
      .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(headersProvider(
        source: widget.source.name!, lang: widget.source.lang!, sourceId: widget.source.id));
    final imgUrl = toImgUrl(widget.manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) async {
          await _pressCtrl.reverse();
          if (widget.manga.link != null && mounted) {
            pushToMangaReaderDetail(
              ref: ref, context: context, getManga: widget.manga,
              lang: widget.source.lang!, source: widget.source.name!,
              itemType: widget.source.itemType, sourceId: widget.source.id,
            );
          }
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 116,
            height: 172,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imgUrl.isNotEmpty
                      ? Image(image: cover, fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.play_circle_outline_rounded,
                                size: 42, color: Colors.white24),
                          ))
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.play_circle_outline_rounded,
                              size: 42, color: Colors.white24)),
                  // Top-to-bottom gradient for title legibility
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.78),
                          ],
                          stops: const [0.42, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // "En français" language badge — MovieBox exact (top-left)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('En français',
                          style: TextStyle(color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w700, letterSpacing: 0.1)),
                    ),
                  ),
                  // Title at bottom
                  Positioned(
                    bottom: 9, left: 10, right: 10,
                    child: Text(widget.manga.name ?? '',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                          height: 1.3,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact card (Animations, Docs & Spectacles) ──────────────────────────────

class _CompactCard extends ConsumerStatefulWidget {
  final MManga manga;
  final Source source;
  const _CompactCard({required this.manga, required this.source});

  @override
  ConsumerState<_CompactCard> createState() => _CompactCardState();
}

class _CompactCardState extends ConsumerState<_CompactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 100),
    lowerBound: 0.0, upperBound: 1.0,
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.92)
      .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(headersProvider(
        source: widget.source.name!, lang: widget.source.lang!, sourceId: widget.source.id));
    final imgUrl = toImgUrl(widget.manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) async {
          await _pressCtrl.reverse();
          if (widget.manga.link != null && mounted) {
            pushToMangaReaderDetail(
              ref: ref, context: context, getManga: widget.manga,
              lang: widget.source.lang!, source: widget.source.name!,
              itemType: widget.source.itemType, sourceId: widget.source.id,
            );
          }
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 164,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imgUrl.isNotEmpty
                            ? Image(image: cover, fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Theme.of(context).colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.play_circle_outline_rounded,
                                      size: 28, color: Colors.white38),
                                ))
                            : Container(
                                color: Theme.of(context).colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.play_circle_outline_rounded,
                                    size: 28, color: Colors.white38)),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                                stops: const [0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6, right: 7,
                          child: Icon(Icons.play_circle_fill_rounded,
                              size: 22, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(widget.manga.name ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        height: 1.25),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section kind ──────────────────────────────────────────────────────────────

enum _SectionKind { popular, latest, custom }

// ── Full-page section drill-down ──────────────────────────────────────────────

class _WatchSectionPage extends ConsumerStatefulWidget {
  final Source source;
  final String title;
  final _SectionKind type;
  final String? customListId;

  const _WatchSectionPage({
    required this.source, required this.title, required this.type,
    this.customListId,
  });

  @override
  ConsumerState<_WatchSectionPage> createState() => _WatchSectionPageState();
}

class _WatchSectionPageState extends ConsumerState<_WatchSectionPage> {
  int _page = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  final List<MManga> _items = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() { super.initState(); }

  @override
  void dispose() { _scrollCtrl.removeListener(_onScroll); _scrollCtrl.dispose(); super.dispose(); }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && _hasNextPage && !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    try {
      MPages? result;
      final next = _page + 1;
      switch (widget.type) {
        case _SectionKind.popular:
          result = await ref.read(getPopularProvider(source: widget.source, page: next).future);
        case _SectionKind.latest:
          result = await ref.read(getLatestUpdatesProvider(source: widget.source, page: next).future);
        case _SectionKind.custom:
          if (widget.customListId != null) {
            result = await ref.read(getCustomListProvider(
                source: widget.source, listId: widget.customListId!, page: next).future);
          }
      }
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() { _page = next; _hasNextPage = result!.hasNextPage; _items.addAll(result.list); });
      } else if (mounted) {
        setState(() => _hasNextPage = false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  AsyncValue<MPages?> get _provider {
    switch (widget.type) {
      case _SectionKind.popular:
        return ref.watch(getPopularProvider(source: widget.source, page: 1));
      case _SectionKind.latest:
        return ref.watch(getLatestUpdatesProvider(source: widget.source, page: 1));
      case _SectionKind.custom:
        return ref.watch(getCustomListProvider(
            source: widget.source, listId: widget.customListId ?? '', page: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _provider;
    data.whenData((d) {
      if (d != null && _items.isEmpty && d.list.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _items.isEmpty) {
            setState(() { _items.addAll(d.list); _hasNextPage = d.hasNextPage; });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.title),
          backgroundColor: Colors.transparent, elevation: 0),
      body: data.when(
        data: (_) {
          if (_items.isEmpty) return const Center(child: CircularProgressIndicator());
          return GridView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140, childAspectRatio: 0.65,
              mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemCount: _items.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (c, i) {
              if (i >= _items.length) {
                return const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return MangaImageCardWidget(
                getMangaDetail: _items[i], source: widget.source,
                itemType: widget.source.itemType, isComfortableGrid: false,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

  // ── Catalogue ornament line ───────────────────────────────────────────────────

  class _CatalogueOrnamentLine extends StatelessWidget {
    final Color color;
    final bool flip;
    const _CatalogueOrnamentLine({required this.color, this.flip = false});

    @override
    Widget build(BuildContext context) {
      return CustomPaint(
        painter: _OrnamentPainter(color: color, flip: flip),
        child: const SizedBox(height: 20),
      );
    }
  }

  class _OrnamentPainter extends CustomPainter {
    final Color color;
    final bool flip;
    const _OrnamentPainter({required this.color, required this.flip});

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final cx = size.width / 2;
      final cy = size.height / 2;

      // Main line
      final lineStart = flip ? size.width : 0.0;
      final lineEnd   = flip ? cx + 18 : cx - 18;
      canvas.drawLine(Offset(lineStart, cy), Offset(lineEnd, cy), paint);

      // Diamond ornament at the inner end
      final dx = flip ? cx + 18 : cx - 18;
      final path = Path()
        ..moveTo(dx, cy - 5)
        ..lineTo(dx + (flip ? -7 : 7), cy)
        ..lineTo(dx, cy + 5)
        ..lineTo(dx + (flip ? 7 : -7), cy)
        ..close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.40));

      // Small dot at outer tip
      canvas.drawCircle(Offset(flip ? cx + 26 : cx - 26, cy), 2.0,
          paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.65));
    }

    @override
    bool shouldRepaint(_OrnamentPainter old) => old.color != color || old.flip != flip;
  }
  