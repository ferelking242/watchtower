import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_detail.dart';
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
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/ui/widgets/see_all_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Accent colours for the novel module
// ─────────────────────────────────────────────────────────────────────────────
const _kNovelGold  = Color(0xFFD4A843); // warm amber-gold accent
const _kNovelBrown = Color(0xFF8B5E3C); // warm brown secondary

// ═════════════════════════════════════════════════════════════════════════════
// NovelHomeScreen
// ═════════════════════════════════════════════════════════════════════════════

class NovelHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isLatest;
  const NovelHomeScreen({required this.source, this.isLatest = false, super.key});

  @override
  ConsumerState<NovelHomeScreen> createState() => _NovelHomeScreenState();
}

class _NovelHomeScreenState extends ConsumerState<NovelHomeScreen> {
  Source get source => widget.source;
  bool get isLocal => source.name == 'local' && source.lang == '';

  static const _kHomeIdx    = 0;
  static const _kPopularIdx = 1;
  static const _kLatestIdx  = 2;
  static const _kFilterIdx  = 3;

  late int _selectedIdx = widget.isLatest ? _kLatestIdx : _kHomeIdx;

  bool   _isSearching = false;
  String _query       = '';
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();

  final _homeScrollCtrl  = ScrollController();
  final List<MManga> _catalogueItems = [];
  int  _cataloguePage    = 1;
  bool _catalogueHasNext = true;
  bool _catalogueLoading = false;

  List<Map<String, dynamic>> _customLists = const [];
  late final List<dynamic> filterList =
      isLocal ? [] : getFilterList(source: source);
  late List<dynamic> filters = List.from(filterList);

  bool _isFiltering   = false;
  bool _isLoadingMore = false;
  bool _hasNextPage   = true;
  int  _page          = 1;
  final List<MManga> _mangaList = [];
  AsyncValue<MPages?>? _getManga;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _homeScrollCtrl.addListener(_onHomeScroll);
    _loadLayout();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _homeScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLayout() async {
    if (isLocal) return;
    await LayoutRegistry.instance.load(source);
    if (!mounted) return;
    setState(() {
      _customLists = LayoutRegistry.instance
          .get(source)
          .home
          .sections
          .map((s) => s.toLegacyMap())
          .toList();
    });
  }

  bool get supportsLatest =>
      isLocal ? true : ref.watch(supportsLatestProvider(source: source));

  // ── filter sheet ───────────────────────────────────────────────────────────

  Future<void> _openFilterSheet(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterWidget(
        filterList: filters,
        onChanged: (applied) {
          if (mounted) setState(() {
            filters      = applied;
            _isFiltering = true;
            _selectedIdx = _kHomeIdx;
            _mangaList.clear();
            _page        = 1;
            _hasNextPage = true;
          });
        },
      ),
    );
  }

  void _resetFilters() => setState(() {
    filters      = List.from(filterList);
    _isFiltering = false;
    _mangaList.clear();
    _page        = 1;
    _hasNextPage = true;
  });

  // ── scroll / load-more (grid tabs) ────────────────────────────────────────

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 && _hasNextPage && !_isLoadingMore) {
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
        result = await ref.read(getLatestUpdatesProvider(source: source, page: next).future);
      } else if (_selectedIdx == _kPopularIdx && !_isSearching) {
        result = await ref.read(getPopularProvider(source: source, page: next).future);
      } else if (_isSearching && _query.isNotEmpty) {
        result = await ref.read(searchProvider(source: source, query: _query, page: next, filterList: filters).future);
      } else if (_isFiltering) {
        result = await ref.read(searchProvider(source: source, query: '', page: next, filterList: filters).future);
      }
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() { _page = next; _hasNextPage = result!.hasNextPage; _mangaList.addAll(result.list); });
      } else if (mounted) {
        setState(() => _hasNextPage = false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── catalogue scroll (home view bottom) ───────────────────────────────────

  void _onHomeScroll() {
    if (!_homeScrollCtrl.hasClients) return;
    final pos = _homeScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 && _catalogueHasNext && !_catalogueLoading) {
      _loadCatalogue();
    }
  }

  Future<void> _loadCatalogue() async {
    if (_catalogueLoading || !_catalogueHasNext) return;
    setState(() => _catalogueLoading = true);
    try {
      final result = await ref.read(getPopularProvider(source: source, page: _cataloguePage).future);
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() { _cataloguePage++; _catalogueHasNext = result.hasNextPage; _catalogueItems.addAll(result.list); });
      } else if (mounted) {
        setState(() => _catalogueHasNext = false);
      }
    } finally {
      if (mounted) setState(() => _catalogueLoading = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSearching && _query.isNotEmpty) {
      _getManga = ref.watch(searchProvider(source: source, query: _query, page: 1, filterList: filters));
    } else if (_isFiltering) {
      _getManga = ref.watch(searchProvider(source: source, query: '', page: 1, filterList: filters));
    } else if (_selectedIdx == _kLatestIdx) {
      _getManga = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    } else {
      _getManga = ref.watch(getPopularProvider(source: source, page: 1));
    }

    if (_isSearching) return _buildSearchScreen(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (ctx, inner) => [_buildSliverAppBar(ctx, inner)],
        body: _buildBody(context),
      ),
    );
  }

  // ── sliver app bar ─────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext ctx, bool forceElevated) {
    final name = !isLocal ? (source.name ?? '') : 'Local';
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      forceElevated: forceElevated,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 90,
      leading: GestureDetector(
        onTap: () => context.pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chevron_left_rounded, size: 28, color: _kNovelGold),
            const Text('Browse', style: TextStyle(fontSize: 17, color: _kNovelGold, fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(source.iconUrl!, width: 20, height: 20, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
      centerTitle: true,
      actions: [
        IconButton(
          splashRadius: 20,
          onPressed: () => setState(() => _isSearching = true),
          icon: const Icon(Icons.search, color: _kNovelGold),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: _buildTabBar(ctx),
      ),
      flexibleSpace: LayoutBuilder(builder: (c, _) => Stack(fit: StackFit.expand, children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Theme.of(c).scaffoldBackgroundColor.withValues(alpha: 0.92)),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0,
            child: Container(height: 0.5, color: _kNovelGold.withValues(alpha: 0.22))),
      ])),
    );
  }

  // ── pill tab bar ───────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext ctx) {
    final tabs = <({IconData icon, String label, int idx})>[
      (icon: Icons.menu_book_rounded,              label: 'Accueil',    idx: _kHomeIdx),
      (icon: Icons.local_fire_department_rounded,  label: 'Populaires', idx: _kPopularIdx),
      if (supportsLatest)
        (icon: Icons.fiber_new_rounded,            label: 'Récents',    idx: _kLatestIdx),
      if (filterList.isNotEmpty)
        (icon: Icons.tune_rounded,                 label: 'Filtres',    idx: _kFilterIdx),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab        = tabs[i];
          final isFilter   = tab.idx == _kFilterIdx;
          final isActive   = isFilter ? _isFiltering : (_selectedIdx == tab.idx && !_isFiltering);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () async {
                if (isFilter) {
                  _isFiltering ? _resetFilters() : await _openFilterSheet(ctx);
                } else {
                  setState(() {
                    _selectedIdx = tab.idx;
                    _isFiltering = false;
                    _mangaList.clear();
                    _page        = 1;
                    _hasNextPage = true;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? _kNovelGold : _kNovelGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? _kNovelGold : _kNovelGold.withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tab.icon, size: 13,
                      color: isActive ? Colors.white : Theme.of(ctx).textTheme.bodyMedium?.color),
                  const SizedBox(width: 5),
                  Text(tab.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Theme.of(ctx).textTheme.bodyMedium?.color)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── body dispatcher ────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext ctx) {
    if (_selectedIdx == _kHomeIdx && !_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HOME VIEW
  // ══════════════════════════════════════════════════════════════════════════

  // ── pull-to-refresh handler ────────────────────────────────────────────────

  Future<void> _onRefreshHome() async {
    // Invalidate all providers that feed the home view so data actually reloads
    ref.invalidate(getPopularProvider(source: source, page: 1));
    ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
    for (final cl in _customLists) {
      final listId = cl['id'] as String;
      ref.invalidate(getCustomListProvider(source: source, listId: listId, page: 1));
    }
    setState(() {
      _catalogueItems.clear();
      _cataloguePage  = 1;
      _catalogueHasNext = true;
    });
    // Let the providers settle
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Widget _buildHomeView(BuildContext ctx) {
    return RefreshIndicator(
      color: _kNovelGold,
      onRefresh: _onRefreshHome,
      // notificationPredicate keeps the refresh trigger only at the very top
      // so it doesn't fire while scrolling inside sections.
      notificationPredicate: (n) => n.depth == 0,
      child: CustomScrollView(
      controller: _homeScrollCtrl,
      slivers: [
        // ── 3-card peeking book carousel ──────────────────────────────────
        SliverToBoxAdapter(
          child: Consumer(builder: (c, ref, _) {
            final pop = ref.watch(getPopularProvider(source: source, page: 1));
            return pop.when(
              data: (d) {
                final items = d?.list ?? [];
                if (items.isEmpty) return const SizedBox(height: 8);
                return _NovelBookCarousel(novels: items.take(10).toList(), source: source);
              },
              loading: () => _buildCarouselSkeleton(ctx),
              error:   (_, __) => const SizedBox(height: 8),
            );
          }),
        ),

        // ── Custom list sections ───────────────────────────────────────────
        ..._customLists.asMap().entries.map((entry) {
          final idx      = entry.key;
          final cl       = entry.value;
          final listId   = cl['id'] as String;
          final listName = cl['name'] as String? ?? listId;
          final isDerniers = idx == 0;
          final isTop      = idx == 1;

          return SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSectionHeader(ctx,
                title:    listName,
                accent:   _sectionAccent(idx),
                icon:     _sectionIcon(idx),
                onSeeAll: isTop ? null : () {
                  if (isDerniers) {
                    setState(() { _selectedIdx = _kLatestIdx; _mangaList.clear(); _page = 1; _hasNextPage = true; });
                  } else {
                    Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => _NovelSectionPage(source: source, title: listName, customListId: listId),
                    ));
                  }
                },
              ),
              Consumer(builder: (c, ref, _) {
                final data = ref.watch(getCustomListProvider(source: source, listId: listId, page: 1));
                return data.when(
                  data:    (d) { final items = d?.list ?? []; return isTop ? _buildRankedRow(ctx, items) : _buildBookRow(ctx, items); },
                  loading: () => isTop ? _buildRankedRowSkeleton(ctx) : _buildBookRowSkeleton(ctx),
                  error:   (_, __) => const SizedBox(height: 8),
                );
              }),
            ]),
          );
        }),

        // ── Fallback: show latest row when no custom lists ─────────────────
        if (_customLists.isEmpty && supportsLatest)
          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSectionHeader(ctx, title: 'Derniers chapitres',
                  accent: const Color(0xFF00BCD4), icon: Icons.fiber_new_rounded,
                  onSeeAll: () => setState(() {
                    _selectedIdx = _kLatestIdx; _mangaList.clear(); _page = 1; _hasNextPage = true;
                  })),
              Consumer(builder: (c, ref, _) {
                final latest = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
                return latest.when(
                  data:    (d) => _buildBookRow(ctx, d?.list ?? []),
                  loading: () => _buildBookRowSkeleton(ctx),
                  error:   (_, __) => const SizedBox(height: 8),
                );
              }),
            ]),
          ),

        // ── Catalogue header ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildSectionHeader(ctx,
            title:  'Explorer le catalogue',
            accent: _kNovelBrown,
            icon:   Icons.collections_bookmark_rounded,
          ),
        ),

        // ── Catalogue grid (portrait 2:3) ──────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          sliver: Consumer(builder: (c, ref, _) {
            final pop = ref.watch(getPopularProvider(source: source, page: 1));
            pop.whenData((d) {
              if (d != null && _catalogueItems.isEmpty && d.list.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _catalogueItems.isEmpty) {
                    setState(() { _catalogueItems.addAll(d.list); _cataloguePage = 2; _catalogueHasNext = d.hasNextPage; });
                  }
                });
              }
            });

            final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

            if (_catalogueItems.isEmpty) {
              return SliverToBoxAdapter(
                child: Skeletonizer(
                  enabled: true,
                  effect: ShimmerEffect(
                      baseColor: base,
                      highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
                      duration: const Duration(milliseconds: 1200)),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: 12,
                    itemBuilder: (_, __) => Container(
                      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              );
            }

            Widget _shimmerCell() => Container(
              decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
            );

            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
              delegate: SliverChildBuilderDelegate(
                (c2, i) {
                  if (i >= _catalogueItems.length) {
                    return Skeletonizer(
                      enabled: true,
                      effect: ShimmerEffect(
                          baseColor: base,
                          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
                          duration: const Duration(milliseconds: 1200)),
                      child: _shimmerCell(),
                    );
                  }
                  return MangaImageCardWidget(
                    getMangaDetail: _catalogueItems[i],
                    source: source,
                    itemType: source.itemType,
                    isComfortableGrid: false,
                  );
                },
                childCount: _catalogueItems.length + (_catalogueLoading ? 3 : 0),
              ),
            );
          }),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
      ),
    );
  }

  // ── section accent / icon helpers ─────────────────────────────────────────

  Color _sectionAccent(int idx) {
    const cs = [Color(0xFF00BCD4), _kNovelGold, Color(0xFF9C27B0), Color(0xFF4CAF50)];
    return cs[idx % cs.length];
  }

  IconData _sectionIcon(int idx) {
    const ic = [Broken.star_1, Broken.cup, Broken.book_1, Broken.bookmark];
    return ic[idx % ic.length];
  }

  // ── section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext ctx, {
    required String title, Color? accent, IconData? icon, VoidCallback? onSeeAll,
  }) {
    final c = accent ?? _kNovelGold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          if (icon != null) ...[Icon(icon, size: 15, color: c), const SizedBox(width: 5)],
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        ]),
        if (onSeeAll != null)
          SeeAllButton(onTap: onSeeAll, color: c),
      ]),
    );
  }

  // ── portrait book row ──────────────────────────────────────────────────────

  Widget _buildBookRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 185,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: items.take(12).length,
        itemBuilder: (_, i) => _NovelBookCard(novel: items[i], source: source),
      ),
    );
  }

  Widget _buildBookRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 185,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 108, height: 152,
                  decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 5),
              Container(width: 90, height: 10, color: base.withValues(alpha: 0.5)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── ranked book row ────────────────────────────────────────────────────────

  Widget _buildRankedRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(15).toList();
    return SizedBox(
      height: 205,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: capped.length,
        itemBuilder: (_, i) => _RankedBookCard(novel: capped[i], source: source, rank: i + 1),
      ),
    );
  }

  Widget _buildRankedRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 205,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SizedBox(width: 115, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 36, height: 52, color: base.withValues(alpha: 0.4)),
              const SizedBox(width: 3),
              Expanded(child: Container(height: 170,
                  decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)))),
            ])),
          ),
        ),
      ),
    );
  }

  // ── carousel skeleton ──────────────────────────────────────────────────────

  Widget _buildCarouselSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1400)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          height: 340,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 110, height: 270, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: base.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14))),
            Container(width: 210, height: 310,
                decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16))),
            Container(width: 110, height: 270, margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(color: base.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14))),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRID / LIST views (Popular / Latest / Filter tabs)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildListView(BuildContext ctx) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n is ScrollUpdateNotification) _onScroll(); return false; },
      child: _getManga?.when(
        data: (data) {
          if (data != null && _mangaList.isEmpty && data.list.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _mangaList.isEmpty) {
                setState(() { _mangaList.addAll(data.list); _hasNextPage = data.hasNextPage; });
              }
            });
          }
          if (_mangaList.isEmpty) {
            return (data?.list.isEmpty ?? true)
                ? Center(child: Text(ctx.l10n.no_result, style: TextStyle(color: Theme.of(ctx).hintColor)))
                : _buildSkeletonGrid();
          }
          return _buildGrid(ctx);
        },
        loading: () => _mangaList.isEmpty ? _buildSkeletonGrid() : _buildGrid(ctx),
        error:   (e, _) => _buildError(ctx, e),
      ) ?? _buildSkeletonGrid(),
    );
  }

  Widget _buildGrid(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: _mangaList.length + (_isLoadingMore ? 3 : 0),
      itemBuilder: (c, i) {
        if (i >= _mangaList.length) {
          return Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(
                baseColor: base,
                highlightColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
                duration: const Duration(milliseconds: 1200)),
            child: Container(
              decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
            ),
          );
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

  Widget _buildSkeletonGrid() {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── search screen ──────────────────────────────────────────────────────────

  Widget _buildSearchScreen(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kNovelGold.withValues(alpha: 0.25), width: 0.8),
                ),
                child: Row(children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, size: 20, color: _kNovelGold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Chercher un roman…',
                        hintStyle: TextStyle(color: Theme.of(ctx).hintColor, fontSize: 16),
                        border: InputBorder.none, isDense: true,
                      ),
                      onChanged: (v) => setState(() { _query = v; _mangaList.clear(); _page = 1; _hasNextPage = true; }),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () { _searchCtrl.clear(); _mangaList.clear(); setState(() => _query = ''); },
                      child: Padding(padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.cancel, size: 18, color: Theme.of(ctx).hintColor)),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _isSearching = false; _query = ''; _mangaList.clear(); _page = 1; _hasNextPage = true; });
              },
              child: const Text('Annuler', style: TextStyle(color: _kNovelGold, fontSize: 16)),
            ),
          ]),
        ),
        Expanded(child: _buildListView(ctx)),
      ])),
    );
  }

  // ── error ──────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext ctx, Object error) {
    void retry() {
      if (_selectedIdx == _kLatestIdx) {
        ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
      } else if (_isSearching && _query.isNotEmpty) {
        ref.invalidate(searchProvider(source: source, query: _query, page: 1, filterList: filters));
      } else {
        ref.invalidate(getPopularProvider(source: source, page: 1));
      }
    }

    if (isCloudflareError(error.toString()) ||
        ((source.hasCloudflare ?? false) && error.toString().toLowerCase().contains('timeout'))) {
      return SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16),
          child: CloudflareErrorWidget(
            errorText: error.toString(),
            url: ref.read(sourceBaseUrlProvider(source: source)),
            onRetry: retry,
          )),
      );
    }

    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.menu_book_outlined, size: 52, color: _kNovelGold),
      const SizedBox(height: 12),
      Text(error.toString(), textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(ctx).hintColor, fontSize: 14)),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: retry,
        style: ElevatedButton.styleFrom(backgroundColor: _kNovelGold, foregroundColor: Colors.white),
        child: const Text('Réessayer'),
      ),
    ])));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3-card peeking book carousel
// ═════════════════════════════════════════════════════════════════════════════

class _NovelBookCarousel extends ConsumerStatefulWidget {
  final List<MManga> novels;
  final Source source;
  const _NovelBookCarousel({required this.novels, required this.source});

  @override
  ConsumerState<_NovelBookCarousel> createState() => _NovelBookCarouselState();
}

class _NovelBookCarouselState extends ConsumerState<_NovelBookCarousel> {
  late final PageController _ctrl = PageController(viewportFraction: 0.72);
  Timer? _timer;
  int _page = 0;
  final Map<int, MManga> _detailCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _prefetch(0); _prefetch(1); });
    if (widget.novels.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_ctrl.hasClients) return;
        _page = (_page + 1) % widget.novels.length;
        _ctrl.animateToPage(_page,
            duration: const Duration(milliseconds: 560), curve: Curves.easeInOutCubic);
      });
    }
  }

  void _prefetch(int i) {
    if (i < 0 || i >= widget.novels.length) return;
    final n = widget.novels[i];
    if (n.link == null || _detailCache.containsKey(i)) return;
    ref.read(getDetailProvider(url: n.link!, source: widget.source).future)
        .then((d) { if (mounted) setState(() => _detailCache[i] = d); })
        .catchError((_) {});
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 16),

      // ── PageView with peeking side cards ──────────────────────────────────
      SizedBox(
        height: 340,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.novels.length,
          onPageChanged: (p) { setState(() => _page = p); _prefetch(p + 1); },
          itemBuilder: (_, i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (ctx, child) {
                double scale = 0.88;
                if (_ctrl.position.haveDimensions) {
                  final diff = (_ctrl.page ?? _page.toDouble()) - i;
                  scale = (1.0 - diff.abs() * 0.12).clamp(0.85, 1.0);
                }
                return Transform.scale(
                  scale: scale,
                  child: _NovelCarouselCard(
                    novel: widget.novels[i],
                    detail: _detailCache[i],
                    source: widget.source,
                    isActive: _page == i,
                  ),
                );
              },
            );
          },
        ),
      ),

      const SizedBox(height: 14),

      // ── Animated dots ─────────────────────────────────────────────────────
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.novels.length, (i) {
          final active = _page == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width:  active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? _kNovelGold : _kNovelGold.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),

      const SizedBox(height: 8),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Carousel card — portrait book cover with gradient overlay
// ═════════════════════════════════════════════════════════════════════════════

class _NovelCarouselCard extends ConsumerWidget {
  final MManga  novel;
  final MManga? detail;
  final Source  source;
  final bool    isActive;
  const _NovelCarouselCard({required this.novel, this.detail, required this.source, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl  = toImgUrl(novel.imageUrl ?? '');
    final cover   = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers) as ImageProvider<Object>
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    final title  = detail?.name  ?? novel.name  ?? '';
    final genres = detail?.genre ?? novel.genre ?? [];

    return GestureDetector(
      onTap: () {
        if (novel.link != null) {
          pushToMangaReaderDetail(ref: ref, context: context, getManga: novel,
              lang: source.lang!, source: source.name!, itemType: source.itemType, sourceId: source.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            // Cover
            imgUrl.isNotEmpty
                ? Image(image: cover, fit: BoxFit.cover, alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => _NoCover(title: title))
                : _NoCover(title: title),

            // Bottom gradient
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent,
                    Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.93)],
                stops: const [0.0, 0.42, 0.66, 1.0],
              ),
            ))),

            // Genre chips — top left
            if (genres.isNotEmpty)
              Positioned(top: 12, left: 12, child: Wrap(spacing: 4,
                children: genres.take(2).map((g) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _kNovelGold.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(g.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                )).toList(),
              )),

            // Bottom info
            Positioned(bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1.2, letterSpacing: -0.3,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1))]),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (novel.link != null) {
                          pushToMangaReaderDetail(ref: ref, context: context, getManga: novel,
                              lang: source.lang!, source: source.name!, itemType: source.itemType, sourceId: source.id);
                        }
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 15, color: Colors.white),
                      label: const Text('Lire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNovelGold,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            // Active amber glow border
            if (isActive)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kNovelGold.withValues(alpha: 0.65), width: 2),
              ))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cover placeholder (no image)
// ─────────────────────────────────────────────────────────────────────────────

class _NoCover extends StatelessWidget {
  final String title;
  const _NoCover({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_kNovelBrown.withValues(alpha: 0.8), _kNovelGold.withValues(alpha: 0.6)],
      )),
      child: Stack(alignment: Alignment.center, children: [
        const Icon(Icons.menu_book_rounded, size: 64, color: Colors.white24),
        Positioned(bottom: 70, left: 12, right: 12,
            child: Text(title, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Portrait book card (section rows)
// ═════════════════════════════════════════════════════════════════════════════

class _NovelBookCard extends ConsumerWidget {
  final MManga novel;
  final Source source;
  const _NovelBookCard({required this.novel, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl  = toImgUrl(novel.imageUrl ?? '');
    final cover   = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers) as ImageProvider<Object>
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return GestureDetector(
      onTap: () {
        if (novel.link != null) {
          pushToMangaReaderDetail(ref: ref, context: context, getManga: novel,
              lang: source.lang!, source: source.name!, itemType: source.itemType, sourceId: source.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 9),
        child: SizedBox(width: 108, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9),
            child: Stack(fit: StackFit.expand, children: [
              imgUrl.isNotEmpty
                  ? Image(image: cover, fit: BoxFit.cover, alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => _coverFallback())
                  : _coverFallback(),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 28,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.42), Colors.transparent],
                  )))),
            ]),
          )),
          const SizedBox(height: 5),
          Text(novel.name ?? '',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ),
    );
  }

  Widget _coverFallback() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [_kNovelBrown.withValues(alpha: 0.7), _kNovelGold.withValues(alpha: 0.5)],
    )),
    child: const Center(child: Icon(Icons.menu_book_rounded, size: 32, color: Colors.white38)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Ranked book card (Top romans section)
// ═════════════════════════════════════════════════════════════════════════════

class _RankedBookCard extends ConsumerWidget {
  final MManga novel;
  final Source source;
  final int    rank;
  const _RankedBookCard({required this.novel, required this.source, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl  = toImgUrl(novel.imageUrl ?? '');
    final cover   = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers) as ImageProvider<Object>
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.35) ?? Colors.grey.shade500;

    return GestureDetector(
      onTap: () {
        if (novel.link != null) {
          pushToMangaReaderDetail(ref: ref, context: context, getManga: novel,
              lang: source.lang!, source: source.name!, itemType: source.itemType, sourceId: source.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(width: 115, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(width: 36,
            child: Text('$rank', textAlign: TextAlign.center,
              style: TextStyle(fontSize: rank < 10 ? 48 : 38, fontWeight: FontWeight.w900,
                  color: rankColor, height: 1.0, letterSpacing: -2,
                  shadows: [Shadow(color: rankColor.withValues(alpha: 0.30),
                      blurRadius: 8, offset: const Offset(1, 2))]),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: imgUrl.isNotEmpty
                  ? Image(image: cover, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => _rankFallback())
                  : _rankFallback(),
            )),
            const SizedBox(height: 4),
            Text(novel.name ?? '',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.25),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ])),
      ),
    );
  }

  Widget _rankFallback() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: [_kNovelBrown.withValues(alpha: 0.7), _kNovelGold.withValues(alpha: 0.5)],
    )),
    child: const Center(child: Icon(Icons.menu_book_rounded, size: 28, color: Colors.white38)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Full-list page (Voir tout)
// ═════════════════════════════════════════════════════════════════════════════

class _NovelSectionPage extends ConsumerStatefulWidget {
  final Source source;
  final String title;
  final String customListId;
  const _NovelSectionPage({required this.source, required this.title, required this.customListId});

  @override
  ConsumerState<_NovelSectionPage> createState() => _NovelSectionPageState();
}

class _NovelSectionPageState extends ConsumerState<_NovelSectionPage> {
  final _scrollCtrl = ScrollController();
  final List<MManga> _items = [];
  int  _page    = 1;
  bool _hasNext = true;
  bool _loading = false;

  @override
  void initState() { super.initState(); _scrollCtrl.addListener(_onScroll); }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 && _hasNext && !_loading) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final next   = _page + 1;
      final result = await ref.read(
          getCustomListProvider(source: widget.source, listId: widget.customListId, page: next).future);
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() { _page = next; _hasNext = result.hasNextPage; _items.addAll(result.list); });
      } else if (mounted) {
        setState(() => _hasNext = false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(getCustomListProvider(source: widget.source, listId: widget.customListId, page: 1));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: data.when(
        data: (d) {
          if (d != null && _items.isEmpty && d.list.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _items.isEmpty) setState(() { _items.addAll(d.list); _hasNext = d.hasNextPage; });
            });
          }
          if (_items.isEmpty) {
            return Center(child: Text(context.l10n.no_result,
                style: TextStyle(color: Theme.of(context).hintColor)));
          }
          return _SectionPageGrid(
            items: _items,
            loading: _loading,
            scrollCtrl: _scrollCtrl,
            source: widget.source,
          );
        },
        loading: () => _SectionPageSkeleton(),
        error:   (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NovelSectionPage helpers — extracted to avoid capturing BuildContext
// ─────────────────────────────────────────────────────────────────────────────

class _SectionPageGrid extends StatelessWidget {
  final List<MManga> items;
  final bool loading;
  final ScrollController scrollCtrl;
  final Source source;
  const _SectionPageGrid({required this.items, required this.loading, required this.scrollCtrl, required this.source});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: items.length + (loading ? 3 : 0),
      itemBuilder: (c, i) {
        if (i >= items.length) {
          return Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(
                baseColor: base,
                highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                duration: const Duration(milliseconds: 1200)),
            child: Container(
              decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        return MangaImageCardWidget(
          getMangaDetail: items[i],
          source: source,
          itemType: source.itemType,
          isComfortableGrid: false,
        );
      },
    );
  }
}

class _SectionPageSkeleton extends StatelessWidget {
  const _SectionPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
          baseColor: base,
          highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120, childAspectRatio: 0.62, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
