import 'dart:async';
import 'dart:convert';
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
import 'package:watchtower/modules/home/widgets/home_header.dart';
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

  // ── Sub-tab state (tabs provided by extension, not hardcoded) ──────────────
  int _mbSubTabIdx    = 0; // index into tab list from extension
  final _headerOpacity = ValueNotifier<double>(0.15);
  double _headerH = 100.0;

  @override
    void initState() {
      super.initState();
      _scrollCtrl.addListener(_onHomeScroll);
    }

    void _onHomeScroll() {
      if (!_scrollCtrl.hasClients) return;
      final v = (0.15 + _scrollCtrl.offset / _headerH.clamp(1.0, double.infinity)).clamp(0.0, 1.0);
      if ((v - _headerOpacity.value).abs() > 0.005) _headerOpacity.value = v;
    }

  @override
    void dispose() {
      _suggestionTimer?.cancel();
      _scrollCtrl.removeListener(_onHomeScroll);
      _headerOpacity.dispose();
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

    final topPad = MediaQuery.paddingOf(context).top;
    // No header — carousel extends to top, _headerH = safe-area only
    _headerH = topPad;

    return Scaffold(
      backgroundColor: mbBg,
      extendBody: true,
      body: _buildBody(context),
    );
  }

  // ── Body dispatcher ──────────────────────────────────────────────────────
  // When sub-tab 0 (FightZone/Home) or 3 (Movie in home) is active → home view.
  // Otherwise → list view (popular, latest, etc.)

  Widget _buildBody(BuildContext ctx) {
    // Sans subtabs hardcodés : home view tant que pas de filtre/recherche actif
    if (!_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ── Home view ────────────────────────────────────────────────────────────

  Widget _buildHomeView(BuildContext ctx) {
      // Partition custom lists into their roles
      final categoryLists = _customLists.where((cl) => cl['layout'] == 'category').toList();
      final catalogueList = _customLists.where((cl) => cl['id'] == 'catalogue').firstOrNull;
      // Sections dynamiques — le nombre est contrôlé par _prefMaxSections()
      // dans l'extension (compact:12, standard:25, confort:42). Plus de cap app-side.
      final regularLists  = _customLists.where((cl) =>
        cl['id'] != 'carousel' && cl['layout'] != 'category' && cl['id'] != 'catalogue'
      ).toList();

      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
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
          // ── Hero carousel ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Consumer(builder: (c, r, _) {
              final carouselListDef = _customLists
                  .where((cl) => cl['id'] == 'carousel')
                  .firstOrNull;
              if (carouselListDef != null) {
                final data = r.watch(getCustomListProvider(
                    source: source, listId: 'carousel', page: 1));
                return data.when(
                  data: (d) {
                    final items = d?.list ?? [];
                    if (items.isEmpty) return _buildHeroSkeleton(c);
                    return RepaintBoundary(child: _WatchHeroCarousel(
                        mangas: items, source: source, topPadding: _headerH,
                        onSearchTap: () => setState(() => _isSearching = true)));
                  },
                  loading: () => _buildHeroSkeleton(c),
                  error: (_, __) {
                    final pop = r.watch(getPopularProvider(source: source, page: 1));
                    return pop.when(
                      data: (d) {
                        final items = d?.list ?? [];
                        if (items.isEmpty) return _buildHeroSkeleton(c);
                        return RepaintBoundary(child: _WatchHeroCarousel(
                            mangas: items.take(8).toList(), source: source, topPadding: _headerH,
                        onSearchTap: () => setState(() => _isSearching = true)));
                      },
                      loading: () => _buildHeroSkeleton(c),
                      error: (_, __) => _buildHeroSkeleton(c),
                    );
                  },
                );
              }
              final pop = r.watch(getPopularProvider(source: source, page: 1));
              return pop.when(
                data: (d) {
                  final items = d?.list ?? [];
                  if (items.isEmpty) return _buildHeroSkeleton(c);
                  return RepaintBoundary(child: _WatchHeroCarousel(
                      mangas: items.take(8).toList(), source: source, topPadding: _headerH,
                        onSearchTap: () => setState(() => _isSearching = true)));
                },
                loading: () => _buildHeroSkeleton(c),
                error: (_, __) => _buildHeroSkeleton(c),
              );
            }),
          ),

          // ── Tab pills — driven by extension (layout:'__tab__') ──────────
          Builder(builder: (ctx) {
            final dynTabs = _customLists
                .where((cl) => cl['layout'] == '__tab__')
                .map((cl) => cl['name'] as String? ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            if (dynTabs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverToBoxAdapter(
              child: _WatchHomeTabPills(
                selectedIdx: _mbSubTabIdx,
                tabs: dynTabs,
                onChanged: (i) => setState(() {
                  _mbSubTabIdx = i;
                  _isFiltering = false;
                  _mangaList.clear(); _page = 1; _hasNextPage = true;
                }),
              ),
            );
          }),

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
              onSeeAllCb = () => Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source, title: 'Derniers ajouts',
                      type: _SectionKind.latest,
                    ),
                  ));
            } else if (seeAll == 'popular') {
              onSeeAllCb = () => Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source, title: 'Populaire',
                      type: _SectionKind.popular,
                    ),
                  ));
            } else {
              onSeeAllCb = () => Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source, title: listName,
                      type: _SectionKind.custom, customListId: listId,
                    ),
                  ));
            }

            return SliverToBoxAdapter(
              child: Consumer(builder: (c, ref, _) {
                final sData = ref.watch(getCustomListProvider(
                  source: source, listId: listId, page: 1,
                ));
                return sData.when(
                  data: (d) {
                    final items = d?.list ?? [];
                    // Section entière masquée si vide — pas de header orphelin
                    if (items.isEmpty) return const SizedBox.shrink();
                    final content = isRanked
                        ? _buildRankedRow(ctx, items)
                        : isSpotlight
                            ? _buildSpotlightRow(ctx, items)
                            : _buildCompactRow(ctx, items);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(ctx,
                          title: listName, accent: accent, icon: icon,
                          onSeeAll: onSeeAllCb,
                        ),
                        content,
                      ],
                    );
                  },
                  // Skeleton léger — pas d'animation shimmer (trop lourd)
                  loading: () => _buildSectionPlaceholder(ctx),
                  error: (_, __) => const SizedBox.shrink(),
                );
              }),
            );
          }),

          // ── If no custom lists → show standard Latest row ────────────────
          if (_customLists.isEmpty && supportsLatest)
            SliverToBoxAdapter(
              child: Consumer(builder: (c, ref, _) {
                final latest = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
                return latest.when(
                  data: (d) {
                    final items = d?.list ?? [];
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(ctx,
                          title: 'Derniers ajouts', accent: ctx.primaryColor,
                          icon: Icons.update_rounded,
                          onSeeAll: () => Navigator.of(ctx).push(MaterialPageRoute(
                            builder: (_) => _WatchSectionPage(
                              source: source, title: 'Derniers ajouts',
                              type: _SectionKind.latest,
                            ),
                          )),
                        ),
                        _buildCompactRow(ctx, items),
                      ],
                    );
                  },
                  loading: () => _buildSectionPlaceholder(ctx),
                  error: (_, __) => const SizedBox.shrink(),
                );
              }),
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
                        color: Theme.of(ctx).colorScheme.onSurface,
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
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140, childAspectRatio: 0.65,
                        mainAxisSpacing: 8, crossAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                height: 56,
                                color: Colors.black45,
                                alignment: Alignment.bottomLeft,
                                padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                                child: Container(
                                  height: 9, width: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white30,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
      ), // NotificationListener

        ],
      ); // Stack
    }

    // ── Category chips strip ─────────────────────────────────────────────────
    // Style MovieBox : tuiles 120×68 avec l'affiche du premier item chargé
    // via Consumer en fond, dégradé sombre + nom centré.
    // Si aucune image n'est disponible → fallback couleur de la section.

    Widget _buildCategoryChips(BuildContext ctx, List<Map<String, dynamic>> cats) {
      return SizedBox(
        height: 76,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final cl       = cats[i];
            final listId   = cl['id']       as String;
            final listName = cl['name']     as String? ?? listId;
            final hexColor = cl['color']    as String? ?? '#1E2126';
            final extImg   = cl['imageUrl'] as String? ?? '';

            // Couleur de fallback parsée depuis l'extension
            Color fallbackColor;
            try {
              final h = hexColor.replaceAll('#', '');
              fallbackColor = h.length == 6
                  ? Color(int.parse('FF$h', radix: 16))
                  : const Color(0xFF1E2126);
            } catch (_) {
              fallbackColor = const Color(0xFF1E2126);
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _WatchSectionPage(
                    source: source, title: listName,
                    type: _SectionKind.custom, customListId: listId,
                  ),
                )),
                // Consumer : charge le 1er item de la section pour son affiche
                child: Consumer(
                  builder: (c, ref, _) {
                    String bgUrl = extImg;
                    if (bgUrl.isEmpty) {
                      final snap = ref.watch(
                          getCustomListProvider(source: source, listId: listId, page: 1));
                      bgUrl = snap.maybeWhen(
                        data: (d) {
                          final first = d?.list.firstOrNull;
                          return first?.imageUrl ?? '';
                        },
                        orElse: () => '',
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 120, height: 68,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ── Fond : affiche ou couleur de la section ─────────
                            if (bgUrl.isNotEmpty)
                              Image.network(
                                bgUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    ColoredBox(color: fallbackColor),
                              )
                            else
                              ColoredBox(color: fallbackColor),

                            // ── Dégradé sombre — lisibilité du label ────────────
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.30),
                                    Colors.black.withValues(alpha: 0.72),
                                  ],
                                ),
                              ),
                            ),

                            // ── Label centré ────────────────────────────────────
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  listName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black,
                                          blurRadius: 10),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    return Skeletonizer(
      child: SizedBox(
        height: 196,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: List.generate(6, (_) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 116, height: 172,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          )),
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
    return Skeletonizer(
      child: SizedBox(
        height: 168,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: List.generate(6, (_) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 116, height: 150,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )),
        ),
      ),
    );
  }

  // ── List view (Popular / Latest / Filter / Search tabs) ──────────────────

  Widget _buildListView(BuildContext ctx) {
    final topSafe = MediaQuery.paddingOf(ctx).top;
    return Padding(
      padding: EdgeInsets.only(top: topSafe),
      child: NotificationListener<ScrollNotification>(
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
      ),
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

  /// Single skeleton card — Skeletonizer handles shimmer + theme automatically.
  Widget _buildSkeletonCardItem(BuildContext ctx) {
    return Skeletonizer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 56,
                color: Colors.black45,
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                child: Container(
                  height: 9, width: 72,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Skeletonizer(
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 56,
                  color: Colors.black45,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                  child: Container(
                    height: 9, width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  /// Section placeholder — 5 portrait cards identiques aux _SpotlightCard (116×172)
  Widget _buildSectionPlaceholder(BuildContext ctx) {
    return Skeletonizer(
      child: SizedBox(
        height: 196,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 116,
              height: 172,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 56,
                        color: Colors.black45,
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                        child: Container(
                          height: 9, width: 72,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildHeroSkeleton(BuildContext ctx) {
    final size   = MediaQuery.sizeOf(ctx);
    final cardH  = (size.width > size.height) ? size.height * 0.70 : size.height * 0.34;
    final totalH = cardH + _headerH;
    return Skeletonizer(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: SizedBox(
          width: size.width,
          height: totalH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fake image area
              Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
              // Fake title + dots at bottom (mirrors real carousel)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 16, width: size.width * 0.55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10, width: size.width * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == 0 ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            if (_tryOpenReel(context, widget.manga, widget.source)) return;
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
            if (_tryOpenReel(context, widget.manga, widget.source)) return;
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
            if (_tryOpenReel(context, widget.manga, widget.source)) return;
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

// ── Reel intercept helper ─────────────────────────────────────────────────────
// Detects type='reel' in manga.link and opens ReelScreen (TikTok tabs).
// Returns true if navigation was handled (caller should skip pushToMangaReaderDetail).
// ReelScreen tabs: Explorer / Suivis / Pour toi — opens on Pour toi by default.

bool _tryOpenReel(BuildContext context, MManga manga, Source source) {
  final link = manga.link;
  if (link == null || !link.startsWith('{')) return false;
  try {
    final data = jsonDecode(link) as Map<String, dynamic>;
    if (data['type'] != 'reel') return false;
    context.pushNamed('reel', extra: {
      'source': source,
      'listId': (data['listId'] as String?) ?? 'trending',
      'startGifId': data['gifId'] as String?,
    });
    return true;
  } catch (_) {
    return false;
  }
}

// ── Section kind ──────────────────────────────────────────────────────────────

enum _SectionKind { popular, latest, custom }

// ── Full-page section drill-down ──────────────────────────────────────────────


// ── Floating home header (accueil style) ─────────────────────────────────────

class _WatchHomeHeader extends StatelessWidget {
  final Source source;
  final ValueNotifier<double> headerOpacity;
  final int mbSubTabIdx;
  final ValueChanged<int> onSubTabChanged;
  final VoidCallback onSearchTap;

  const _WatchHomeHeader({
    required this.source,
    required this.headerOpacity,
    required this.mbSubTabIdx,
    required this.onSubTabChanged,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPad     = MediaQuery.paddingOf(context).top;
    const scaffoldBg = Color(0xFF101114);
    const brandGreen = Color(0xFF07b84e);

    return ValueListenableBuilder<double>(
      valueListenable: headerOpacity,
      builder: (context, opacity, _) {
        return Container(
          color: scaffoldBg.withValues(alpha: opacity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status-bar scrim
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
              // Row 1: App logo + search bar
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => showAccountSheet(context),
                        child: Image.asset(
                          'assets/app_icons/icon.png',
                          width: 56,
                          height: 56,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: onSearchTap,
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
                                Icon(Icons.search_rounded,
                                    color: Colors.white54, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rechercher un titre...',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Recherche',
                                  style: TextStyle(
                                    color: brandGreen,
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
              // Row 2: Sub-tab pills
              SizedBox(
                height: 44,
                child: _WatchSubTabRow(
                  selectedIdx: mbSubTabIdx,
                  onChanged: onSubTabChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-tab pill row ──────────────────────────────────────────────────────────

class _WatchSubTabRow extends StatelessWidget {
  final int selectedIdx;
  final ValueChanged<int> onChanged;
  static const _tabs = ['FightZone', 'Movie', 'TV Shows', 'Popular'];
  const _WatchSubTabRow({required this.selectedIdx, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const white60    = Color(0x99FFFFFF);
    const brandGreen = Color(0xFF07b84e);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
      itemCount: _tabs.length,
      itemBuilder: (_, i) {
        final active = selectedIdx == i;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? brandGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _tabs[i],
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
    );
  }
}

// ── Home tab pill row (below carousel) ───────────────────────────────────────

class _WatchHomeTabPills extends StatelessWidget {
  final int selectedIdx;
  final List<String> tabs;
  final ValueChanged<int> onChanged;
  const _WatchHomeTabPills({
    required this.selectedIdx,
    required this.tabs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final active = selectedIdx == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: active ? 1.06 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: active
                        ? Border.all(color: Colors.white, width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.50),
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Cinematic hero carousel (accueil style, adapted for MManga) ───────────────

class _WatchHeroCarousel extends ConsumerStatefulWidget {
  final List<MManga> mangas;
  final Source source;
  final double topPadding;
  final VoidCallback? onSearchTap;
  const _WatchHeroCarousel({
    required this.mangas,
    required this.source,
    this.topPadding = 0,
    this.onSearchTap,
  });

  @override
  ConsumerState<_WatchHeroCarousel> createState() => _WatchHeroCarouselState();
}

class _WatchHeroCarouselState extends ConsumerState<_WatchHeroCarousel> {
  static const _kInterval = Duration(seconds: 6);
  static const _kDuration = Duration(milliseconds: 520);
  static const _kCurve    = Curves.easeOutCubic;

  late PageController _ctrl;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.mangas.length <= 1) return;
    _timer = Timer.periodic(_kInterval, (_) {
      if (!mounted) return;
      _ctrl.animateToPage(
        (_page + 1) % widget.mangas.length,
        duration: _kDuration,
        curve: _kCurve,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double _cardH(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height) return size.height * 0.70;
    return size.height * 0.34;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mangas.isEmpty) return const SizedBox.shrink();

    final cardH  = _cardH(context);
    final totalH = cardH + widget.topPadding;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: totalH,
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.mangas.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (ctx, i) {
          final manga   = widget.mangas[i];
          final headers = ref.watch(headersProvider(
              source: widget.source.name!,
              lang: widget.source.lang!,
              sourceId: widget.source.id));
          final imgUrl = toImgUrl(manga.imageUrl ?? '');

          return GestureDetector(
            onTap: () {
              if (manga.link != null) {
                if (_tryOpenReel(ctx, manga, widget.source)) return;
                pushToMangaReaderDetail(
                  ref: ref,
                  context: ctx,
                  getManga: manga,
                  lang: widget.source.lang!,
                  source: widget.source.name!,
                  itemType: widget.source.itemType,
                  sourceId: widget.source.id,
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Banner image
                imgUrl.isNotEmpty
                    ? Image(
                        image: CustomExtendedNetworkImageProvider(imgUrl,
                            headers: headers),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: Color(0xFF1A1A2E)),
                      )
                    : const ColoredBox(color: Color(0xFF1A1A2E)),

                // Gradient: dark at top (header legibility) + fade to bg at bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.transparent,
                          bgColor,
                        ],
                        stops: const [0.0, 0.30, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // Info overlay
                Positioned(
                  bottom: 20, left: 16, right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        manga.name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                        ),
                      ),
                      if ((manga.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          manga.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.4,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Dot indicators
                      Row(
                        children: List.generate(widget.mangas.length, (d) {
                          final active = _page == d;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 5),
                            width: active ? 20 : 6,
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
              },
            ),
            // ── Back button (←) ──────────────────────────────────────────────
            Positioned(
              top: widget.topPadding + 10,
              left: 14,
              child: _CarouselIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            // ── Search button (🔍) — replaces ··· ──────────────────────────
            Positioned(
              top: widget.topPadding + 10,
              right: 14,
              child: _CarouselIconButton(
                icon: Icons.search_rounded,
                onTap: () => widget.onSearchTap?.call(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carousel icon button (frosted circle) ─────────────────────────────────────

class _CarouselIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CarouselIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

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
  bool _isListView = false;
  final List<MManga> _items = [];
  late List<dynamic> _filterList;
  late List<dynamic> _filters;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _filterList = (widget.source.isLocal == true) ? [] : getFilterList(source: widget.source);
    _filters = List.from(_filterList);
    _scrollCtrl.addListener(_onScroll);
  }

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

  Future<void> _openSettings(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSS) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surface
                      .withValues(alpha: isDark ? 0.82 : 0.92),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                setState(() {
                                  _filters = List.from(_filterList);
                                  _items.clear(); _page = 1; _hasNextPage = true;
                                });
                              },
                              child: Text('Réinitialiser',
                                  style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error, fontSize: 14)),
                            ),
                            Expanded(child: Text(widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            TextButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              child: const Text('Fermer', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Display mode
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Text('Affichage', style: TextStyle(
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
                                    onTap: () { setSS(() {}); setState(() => _isListView = false); },
                                  ),
                                  _ViewToggleBtn(
                                    icon: Icons.view_list_rounded,
                                    selected: _isListView,
                                    onTap: () { setSS(() {}); setState(() => _isListView = true); },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Extension filters (if any)
                      if (_filterList.isNotEmpty) ...[
                        const Divider(height: 1),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            child: FilterWidget(
                              filterList: _filters,
                              onChanged: (applied) {
                                setSS(() => _filters = applied);
                                setState(() {
                                  _filters = applied;
                                  _items.clear(); _page = 1; _hasNextPage = true;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
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

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      // Transparent AppBar with back ← + title + settings ⚙
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
            ),
          ),
        ),
        title: Text(widget.title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _openSettings(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: cs.onSurface),
              ),
            ),
          ),
        ],
      ),
      body: data.when(
        data: (_) {
          if (_items.isEmpty) {
            return Skeletonizer(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 120),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140, childAspectRatio: 0.65,
                  mainAxisSpacing: 10, crossAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            );
          }
          if (_isListView) {
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              itemCount: _items.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= _items.length) {
                  return const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2)));
                }
                return MangaImageCardWidget(
                  getMangaDetail: _items[i], source: widget.source,
                  itemType: widget.source.itemType, isComfortableGrid: true,
                );
              },
            );
          }
          return GridView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 120),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140, childAspectRatio: 0.65,
              mainAxisSpacing: 10, crossAxisSpacing: 10,
            ),
            itemCount: _items.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (ctx, i) {
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
        loading: () => Skeletonizer(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 120),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140, childAspectRatio: 0.65,
              mainAxisSpacing: 10, crossAxisSpacing: 10,
            ),
            itemCount: 12,
            itemBuilder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
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
  