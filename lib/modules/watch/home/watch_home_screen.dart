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
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_detail.dart';
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
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/eval/model/filter.dart';

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

class _WatchHomeScreenState extends ConsumerState<WatchHomeScreen> {
  Source get source => widget.source;
  bool get isLocal => source.name == 'local' && source.lang == '';

  static const _kHomeIdx    = 0;
  static const _kPopularIdx = 1;
  static const _kLatestIdx  = 2;
  static const _kFilterIdx  = 3;

  late int _selectedIdx = widget.isLatest ? _kLatestIdx : _kHomeIdx;

  bool _isSearching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _expandedChipName;
  final _scrollCtrl = ScrollController();

  // Home catalogue scroll controller (separate from the tab scroll)
  final _homeScrollCtrl = ScrollController();
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

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _homeScrollCtrl.addListener(_onHomeScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _homeScrollCtrl.dispose();
    super.dispose();
  }

  bool get supportsLatest =>
      isLocal ? true : ref.watch(supportsLatestProvider(source: source));

  // ── Filter ──────────────────────────────────────────────────────────────

  Future<void> _openFilterSheet(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterWidget(
        filterList: filters,
        onChanged: (applied) {
          if (mounted) {
            setState(() {
              filters = applied;
              _isFiltering = true;
              _selectedIdx = _kHomeIdx;
              _mangaList.clear();
              _page = 1;
              _hasNextPage = true;
            });
          }
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

  // ── Catalogue scroll (home view bottom) ──────────────────────────────────

  void _onHomeScroll() {
    if (!_homeScrollCtrl.hasClients) return;
    final pos = _homeScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        _catalogueHasNext &&
        !_catalogueLoading) {
      _loadCatalogue();
    }
  }

  Future<void> _loadCatalogue() async {
    if (_catalogueLoading || !_catalogueHasNext) return;
    setState(() => _catalogueLoading = true);
    try {
      final result = await ref
          .read(getPopularProvider(source: source, page: _cataloguePage).future);
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() {
          _cataloguePage++;
          _catalogueHasNext = result.hasNextPage;
          _catalogueItems.addAll(result.list);
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final sourceName = !isLocal ? (source.name ?? '') : 'Local';
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left_rounded, size: 28, color: ctx.primaryColor),
              Text('Browse',
                  style: TextStyle(fontSize: 17, color: ctx.primaryColor,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
              ExtensionIconWidget(
                sourceId: source.id,
                iconUrl: source.iconUrl,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
          Flexible(
            child: Text(sourceName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
          IconButton(
            splashRadius: 20,
            onPressed: () => setState(() => _isSearching = true),
            icon: Icon(Icons.search, color: ctx.primaryColor),
          ),
          Builder(
            builder: (bCtx) => GestureDetector(
              onTap: () => _showMoreMenu(bCtx),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(bCtx).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.75),
                ),
                child: Icon(Icons.more_horiz,
                    size: 18, color: Theme.of(bCtx).hintColor),
              ),
            ),
          ),
        ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: _buildTabBar(ctx),
      ),
      flexibleSpace: LayoutBuilder(builder: (lbCtx, _) {
        return Stack(fit: StackFit.expand, children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: Theme.of(lbCtx).scaffoldBackgroundColor.withValues(alpha: 0.92),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 3),
              painter: _WavePainter(
                Theme.of(lbCtx).dividerColor.withValues(alpha: 0.35),
              ),
            ),          ),
        ]);
      }),
    );
  }

  // ── Tab bar: Accueil · Popular · Latest · [Filter] ───────────────────────

  Widget _buildTabBar(BuildContext ctx) {
    final tabs = <_WatchTab>[
      const _WatchTab(Icons.home_rounded,         'Accueil',  _kHomeIdx),
      const _WatchTab(Icons.local_fire_department_rounded, 'Popular', _kPopularIdx),
      if (supportsLatest)
        const _WatchTab(Icons.update_rounded,     'Latest',   _kLatestIdx),
      if (filterList.isNotEmpty)
        const _WatchTab(Icons.tune_rounded,       'Filter',   _kFilterIdx),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isFilterTab = tab.idx == _kFilterIdx;
          final isActive = isFilterTab
              ? _isFiltering
              : _selectedIdx == tab.idx && !_isFiltering;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () async {
                if (isFilterTab) {
                  if (_isFiltering) {
                    _resetFilters();
                  } else {
                    await _openFilterSheet(ctx);
                  }
                } else {
                  setState(() {
                    _selectedIdx = tab.idx;
                    _isFiltering = false;
                    _mangaList.clear();
                    _page = 1;
                    _hasNextPage = true;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? ctx.primaryColor
                      : ctx.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? ctx.primaryColor
                        : ctx.primaryColor.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 13,
                        color: isActive ? Colors.white
                            : Theme.of(ctx).textTheme.bodyMedium?.color),
                    const SizedBox(width: 5),
                    Text(tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white
                              : Theme.of(ctx).textTheme.bodyMedium?.color,
                        )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body dispatcher ──────────────────────────────────────────────────────

  Widget _buildBody(BuildContext ctx) {
    if (_selectedIdx == _kHomeIdx && !_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ── Home view ────────────────────────────────────────────────────────────

  Widget _buildHomeView(BuildContext ctx) {
    return CustomScrollView(
      controller: _homeScrollCtrl,
      slivers: [
        // ── Hero carousel (À l'affiche) ──────────────────────────────────
        SliverToBoxAdapter(
          child: Consumer(builder: (c, ref, _) {
            final pop = ref.watch(getPopularProvider(source: source, page: 1));
            return pop.when(
              data: (d) {
                final items = d?.list ?? [];
                if (items.isEmpty) return const SizedBox(height: 8);
                return _WatchHero(mangas: items.take(8).toList(), source: source);
              },
              loading: () => _buildHeroSkeleton(ctx),
              error: (_, __) => const SizedBox(height: 8),
            );
          }),
        ),

        // ── Custom sections ──────────────────────────────────────────────
        ..._customLists.asMap().entries.map((entry) {
          final sectionIdx = entry.key;
          final cl = entry.value;
          final listId = cl['id'] as String;
          final listName = cl['name'] as String? ?? listId;
          final isDerniers = sectionIdx == 0;   // → Latest tab
          final isTop15    = sectionIdx == 1;   // → ranked cards, no voir tout

          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(ctx,
                  title: listName,
                  accent: _sectionAccent(sectionIdx),
                  icon:   _sectionIcon(sectionIdx),
                  onSeeAll: isTop15 ? null : () {
                    if (isDerniers) {
                      // "Voir tout" → Latest tab
                      setState(() {
                        _selectedIdx = _kLatestIdx;
                        _mangaList.clear();
                        _page = 1;
                        _hasNextPage = true;
                      });
                    } else {
                      Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => _WatchSectionPage(
                          source: source,
                          title: listName,
                          type: _SectionKind.custom,
                          customListId: listId,
                        ),
                      ));
                    }
                  },
                ),
                Consumer(builder: (c, ref, _) {
                  final data = ref.watch(getCustomListProvider(
                    source: source, listId: listId, page: 1,
                  ));
                  return data.when(
                    data: (d) {
                      final items = d?.list ?? [];
                      if (isTop15) return _buildRankedRow(ctx, items);
                      if (isDerniers) return _buildSpotlightRow(ctx, items);
                      return _buildCompactRow(ctx, items);
                    },
                    loading: () => isTop15
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
                  title: 'Derniers ajouts',
                  accent: ctx.primaryColor,
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

        // ── Catalogue header ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildSectionHeader(ctx,
            title: 'Explorer le catalogue',
            accent: const Color(0xFF607D8B),
            icon: Icons.grid_view_rounded,
            centered: true,
          ),
        ),

        // ── Catalogue grid (infinite scroll) ─────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          sliver: Consumer(builder: (c, ref, _) {
            final pop = ref.watch(getPopularProvider(source: source, page: 1));
            pop.whenData((d) {
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
              return SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  childAspectRatio: 0.65,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, __) {
                    final base = Theme.of(ctx).colorScheme
                        .surfaceContainerHighest.withValues(alpha: 0.6);
                    return Container(
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                  childCount: 12,
                ),
              );
            }

            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio: 0.65,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (c2, i) {
                  if (i >= _catalogueItems.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
    );
  }

  // ── Section accent + icon helpers ────────────────────────────────────────

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
      bool centered = false,
    }) {
      final accentColor = accent ?? ctx.primaryColor;
      final titleRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3, height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, size: 15, color: accentColor),
            const SizedBox(width: 5),
          ],
          Text(title,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2,
              )),
        ],
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 8),
        child: centered
            ? Center(child: titleRow)
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleRow,
                  if (onSeeAll != null)
                    GestureDetector(
                      onTap: onSeeAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Voir tout',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: accentColor)),
                            Icon(Icons.chevron_right_rounded, size: 14, color: accentColor),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );
    }) {
    final accentColor = accent ?? ctx.primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              if (icon != null) ...[
                Icon(icon, size: 15, color: accentColor),
                const SizedBox(width: 5),
              ],
              Text(title,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                  )),
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Voir tout',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: accentColor)),
                    Icon(Icons.chevron_right_rounded, size: 14, color: accentColor),
                  ],
                ),
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
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: capped.length,
        itemBuilder: (_, i) => _RankedCard(
          manga: capped[i], source: source, rank: i + 1,
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
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 46, height: 62,
                      color: base.withValues(alpha: 0.4)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 190,
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

  // ── Spotlight row (Derniers ajouts) ──────────────────────────────────────

  Widget _buildSpotlightRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(10).toList();
    return SizedBox(
      height: 155,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
      height: 142,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                const SizedBox(height: 5),
                Container(width: 120, height: 10,
                    color: base.withValues(alpha: 0.5)),
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
        if (n is ScrollUpdateNotification) _onScroll();
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
    return GridView.builder(
      controller: _scrollCtrl,
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
                child: CircularProgressIndicator(strokeWidth: 2)),
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
    final base = Theme.of(context).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base,
          highlightColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: base,
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
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
                              onChanged: (v) {
                                setState(() {
                                  _query = v;
                                  _mangaList.clear();
                                  _page = 1;
                                  _hasNextPage = true;
                                });
                              },
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
            if (!isLocal)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _WatchFilterIconBtn(
                        activeCount: _countActiveFilters(
                            filters.isEmpty ? filterList : filters),
                        onTap: () => showModalBottomSheet(
                          context: ctx,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => FilterWidget(
                            filterList: filters.isEmpty ? filterList : filters,
                            onChanged: (fl) => setState(() {
                              filters = fl;
                              _mangaList.clear();
                              _page = 1;
                              _hasNextPage = true;
                            }),
                          ),
                        ),
                      ),
                      if (filterList.isNotEmpty)
                        ..._buildFilterChips(ctx, filters.isEmpty ? filterList : filters),
                    ],
                  ),
                ),
              if (!isLocal && _expandedChipName != null)
                _buildChipExpansionPanel(ctx, filters.isEmpty ? filterList : filters),
              const SizedBox(height: 4),
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

    // ── Filter chip helpers ──────────────────────────────────────────────────

    int _countActiveFilters(List<dynamic> fl) {
      int count = 0;
      for (final f in fl) {
        if (f is CheckBoxFilter && f.state) count++;
        else if (f is TriStateFilter && f.state != 0) count++;
        else if (f is SelectFilter && f.state != 0) count++;
        else if (f is GroupFilter) {
          for (final inner in f.state) {
            if (inner is CheckBoxFilter && inner.state) count++;
            else if (inner is TriStateFilter && inner.state != 0) count++;
          }
        }
      }
      return count;
    }

    List<Widget> _buildFilterChips(BuildContext ctx, List<dynamic> fl) {
      return fl
          .where((f) => f is SelectFilter || f is SortFilter || f is GroupFilter)
          .map<Widget>((f) {
        String label;
        String filterName;
        if (f is SortFilter) {
          final val = f.values.isNotEmpty
              ? (f.values[f.state.index] as dynamic).name as String
              : f.name;
          label = '${f.name}: $val';
          filterName = f.name;
        } else if (f is SelectFilter) {
          label = f.name;
          filterName = f.name;
        } else if (f is GroupFilter) {
          label = f.name;
          filterName = f.name;
        } else {
          label = '';
          filterName = '';
        }
        final isExpanded = _expandedChipName == filterName;
        return _WatchFilterChipBtn(
          label: label,
          isExpanded: isExpanded,
          onTap: () => setState(() {
            _expandedChipName = isExpanded ? null : filterName;
          }),
        );
      }).toList();
    }

    void _updateFilterInList(dynamic expandedFilter, dynamic newFilter) {
      if (filters.isEmpty) filters = List<dynamic>.from(filterList);
      final idx = filters.indexWhere((f) {
        if (f is SelectFilter && expandedFilter is SelectFilter) return f.name == expandedFilter.name;
        if (f is GroupFilter && expandedFilter is GroupFilter) return f.name == expandedFilter.name;
        if (f is SortFilter && expandedFilter is SortFilter) return f.name == expandedFilter.name;
        return false;
      });
      if (idx != -1) filters[idx] = newFilter;
    }

    Widget _buildChipExpansionPanel(BuildContext ctx, List<dynamic> fl) {
      if (_expandedChipName == null) return const SizedBox.shrink();
      dynamic expandedFilter;
      for (final f in fl) {
        if (f is SelectFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
        if (f is SortFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
        if (f is GroupFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
      }
      if (expandedFilter == null) return const SizedBox.shrink();
      final cs = Theme.of(ctx).colorScheme;
      List<Widget> options = [];
      if (expandedFilter is SelectFilter) {
        options = expandedFilter.values.asMap().entries.map<Widget>((entry) {
          final idx = entry.key;
          final opt = entry.value;
          final optName = opt is SelectFilterOption ? opt.name : opt.toString();
          final isSelected = expandedFilter.state == idx;
          return InkWell(
            onTap: () => setState(() {
              _updateFilterInList(expandedFilter,
                SelectFilter(expandedFilter.type, expandedFilter.name, idx,
                    expandedFilter.values, expandedFilter.typeName));
              _expandedChipName = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 18,
                    color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Text(optName, style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: cs.onSurface,
                )),
              ]),
            ),
          );
        }).toList();
      } else if (expandedFilter is GroupFilter) {
        options = (expandedFilter.state as List).asMap().entries.map<Widget>((entry) {
          final itemIdx = entry.key;
          final item = entry.value;
          if (item is CheckBoxFilter) {
            return InkWell(
              onTap: () => setState(() {
                final newState = List<dynamic>.from(expandedFilter.state as List);
                newState[itemIdx] = CheckBoxFilter(item.type, item.name, item.value,
                    item.typeName, state: !item.state);
                _updateFilterInList(expandedFilter,
                  GroupFilter(expandedFilter.type, expandedFilter.name,
                      newState, expandedFilter.typeName));
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(item.state ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: item.state ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 12),
                  Text(item.name, style: TextStyle(fontSize: 14, color: cs.onSurface)),
                ]),
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList();
      } else if (expandedFilter is SortFilter) {
        options = expandedFilter.values.asMap().entries.map<Widget>((entry) {
          final idx = entry.key;
          final val = entry.value;
          final valName = (val as dynamic).name as String;
          final isSelected = expandedFilter.state.index == idx;
          return InkWell(
            onTap: () => setState(() {
              final newAsc = isSelected
                  ? !expandedFilter.state.ascending
                  : expandedFilter.state.ascending;
              _updateFilterInList(expandedFilter,
                SortFilter(expandedFilter.type, expandedFilter.name,
                    SortState(idx, newAsc, expandedFilter.state.typeName),
                    expandedFilter.values, expandedFilter.typeName));
              _expandedChipName = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(isSelected
                    ? (expandedFilter.state.ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.remove_rounded,
                    size: 18,
                    color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Text(valName, style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: cs.onSurface,
                )),
              ]),
            ),
          );
        }).toList();
      }
      if (options.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22), topRight: Radius.circular(22),
            bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.12), width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: options),
      );
    }

    void _showMoreMenu(BuildContext ctx) {
      final RenderBox? box = ctx.findRenderObject() as RenderBox?;
      final offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
      showMenu<String>(
        context: ctx,
        position: RelativeRect.fromLTRB(
          MediaQuery.of(ctx).size.width - 48,
          offset.dy + kToolbarHeight - 8,
          8,
          0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        items: [
          PopupMenuItem<String>(
            value: 'settings',
            child: Row(children: [
              Icon(Icons.settings_outlined, size: 18, color: Theme.of(ctx).hintColor),
              const SizedBox(width: 12),
              const Text('Paramètres'),
            ]),
          ),
        ],
      ).then((value) {
        if (value == 'settings' && mounted) {
          context.push('/extension_detail', extra: source);
        }
      });
    }
}

// ── Tab data ──────────────────────────────────────────────────────────────────

class _WatchTab {
  final IconData icon;
  final String label;
  final int idx;
  const _WatchTab(this.icon, this.label, this.idx);
}

  // ── Wave painter ──────────────────────────────────────────────────────────────

  class _WavePainter extends CustomPainter {
    final Color color;
    const _WavePainter(this.color);

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final w = size.width;
      final path = Path();
      path.moveTo(0, 0);
      path.quadraticBezierTo(w * 0.15, 2.2, w * 0.30, 0.6);
      path.quadraticBezierTo(w * 0.45, -0.8, w * 0.60, 1.0);
      path.quadraticBezierTo(w * 0.75, 2.6, w * 0.90, 0.4);
      path.quadraticBezierTo(w * 0.96, -0.2, w, 0.9);
      path.lineTo(w, 3.0);
      path.quadraticBezierTo(w * 0.96, 2.5, w * 0.90, 2.0);
      path.quadraticBezierTo(w * 0.75, 3.4, w * 0.60, 2.0);
      path.quadraticBezierTo(w * 0.45, 0.8, w * 0.30, 2.0);
      path.quadraticBezierTo(w * 0.15, 3.2, 0, 2.0);
      path.close();
      canvas.drawPath(path, paint);
    }

    @override
    bool shouldRepaint(_WavePainter old) => old.color != color;
  }

  // ── Filter chip button (Watch) ────────────────────────────────────────────────

  class _WatchFilterChipBtn extends StatelessWidget {
    final String label;
    final bool isExpanded;
    final VoidCallback onTap;
    const _WatchFilterChipBtn({
      required this.label,
      required this.isExpanded,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isExpanded
                ? cs.primary.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded ? cs.primary : cs.onSurface.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isExpanded ? cs.primary : cs.onSurface,
              )),
              const SizedBox(width: 4),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: isExpanded ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ── Filter icon button (Watch) ────────────────────────────────────────────────

  class _WatchFilterIconBtn extends StatelessWidget {
    final int activeCount;
    final VoidCallback onTap;
    const _WatchFilterIconBtn({required this.activeCount, required this.onTap});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final hasActive = activeCount > 0;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hasActive
                ? cs.primary.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasActive ? cs.primary : cs.onSurface.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14,
                  color: hasActive ? cs.primary : cs.onSurface),
              if (hasActive) ...[
                const SizedBox(width: 4),
                Text('$activeCount', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: cs.primary,
                )),
              ],
            ],
          ),
        ),
      );
    }
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
  final Map<int, MManga> _detailCache = {};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetch(0); _prefetch(1);
    });
    if (widget.mangas.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_ctrl.hasClients) return;
        _page = (_page + 1) % widget.mangas.length;
        _ctrl.animateToPage(_page,
            duration: const Duration(milliseconds: 520), curve: Curves.easeInOut);
      });
    }
  }

  void _prefetch(int index) {
    if (index < 0 || index >= widget.mangas.length) return;
    final manga = widget.mangas[index];
    if (manga.link == null || _detailCache.containsKey(index)) return;
    ref
        .read(getDetailProvider(url: manga.link!, source: widget.source).future)
        .then((d) { if (mounted) setState(() => _detailCache[index] = d); })
        .catchError((_) {});
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final heroH = _heroHeight(context);

    return SizedBox(
      height: heroH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.mangas.length,
            onPageChanged: (p) {
              setState(() => _page = p);
              _prefetch(p + 1);
            },
            itemBuilder: (_, i) => _HeroSlide(
              manga: widget.mangas[i],
              detail: _detailCache[i],
              source: widget.source,
              height: heroH,
            ),
          ),
          // Indicators row
          Positioned(
            bottom: 12, left: 14, right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Slim animated dots
                Row(
                  children: List.generate(widget.mangas.length, (i) {
                    final isActive = _page == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 4),
                      width: isActive ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                // Counter pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_page + 1} / ${widget.mangas.length}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

    final title  = detail?.name  ?? manga.name  ?? '';
    final genres = detail?.genre ?? manga.genre ?? [];

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
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.play_circle_outline_rounded,
                          size: 56, color: Colors.white24),
                    ))
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.play_circle_outline_rounded,
                        size: 56, color: Colors.white24)),
            // Cinematic gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.35, 0.68, 1.0],
                  ),
                ),
              ),
            ),
            // Info
            Positioned(
              bottom: 36, left: 16, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 5,
                      children: genres.take(3).map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(g.toUpperCase(),
                            style: const TextStyle(color: Colors.white70,
                                fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 0.7)),
                      )).toList(),
                    ),
                    const SizedBox(height: 7),
                  ],
                  Text(title,
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.15, letterSpacing: -0.4,
                        shadows: [Shadow(color: Colors.black54,
                            blurRadius: 12, offset: Offset(0, 2))],
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (manga.link != null) {
                          pushToMangaReaderDetail(
                            ref: ref, context: context, getManga: manga,
                            lang: source.lang!, source: source.name!,
                            itemType: source.itemType, sourceId: source.id,
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 17, color: Colors.white),
                      label: const Text('Regarder',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
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

class _RankedCard extends ConsumerWidget {
  final MManga manga;
  final Source source;
  final int rank;
  const _RankedCard({required this.manga, required this.source, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
        source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    // Rank color: gold / silver / bronze / rest
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Theme.of(context).textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.4) ?? Colors.grey.shade600;

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
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(
          width: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Big rank number
              SizedBox(
                width: 46,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: rank < 10 ? 46 : 38,
                    fontWeight: FontWeight.w900,
                    color: rankColor,
                    height: 1.0,
                    letterSpacing: -2,
                    shadows: [
                      Shadow(
                        color: rankColor.withValues(alpha: 0.3),
                        blurRadius: 8, offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 3),
              // Portrait card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imgUrl.isNotEmpty
                            ? Image(image: cover, fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Theme.of(context).colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.movie_outlined,
                                      size: 28, color: Colors.white38),
                                ))
                            : Container(
                                color: Theme.of(context).colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.movie_outlined,
                                    size: 28, color: Colors.white38)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(manga.name ?? '',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600, height: 1.25),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Spotlight card (Derniers ajouts) ─────────────────────────────────────────

class _SpotlightCard extends ConsumerWidget {
  final MManga manga;
  final Source source;
  const _SpotlightCard({required this.manga, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
        source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
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
          width: 230,
          height: 130,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imgUrl.isNotEmpty
                    ? Image(image: cover, fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.play_circle_outline_rounded,
                              size: 36, color: Colors.white24),
                        ))
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_circle_outline_rounded,
                            size: 36, color: Colors.white24)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      size: 34, color: Colors.white60),
                ),
                Positioned(
                  bottom: 7, left: 9, right: 36,
                  child: Text(manga.name ?? '',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700,
                        height: 1.2,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact card (Animations, Docs & Spectacles) ──────────────────────────────

class _CompactCard extends ConsumerWidget {
  final MManga manga;
  final Source source;
  const _CompactCard({required this.manga, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
        source: source.name!, lang: source.lang!, sourceId: source.id));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: GestureDetector(
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
          width: 152,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                                    size: 26),
                              ))
                          : Container(
                              color: Theme.of(context).colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.play_circle_outline_rounded,
                                  size: 26)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.42),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 5, right: 6,
                        child: Icon(Icons.play_circle_fill_rounded,
                            size: 20, color: Colors.white.withValues(alpha: 0.82)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(manga.name ?? '',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      height: 1.25),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
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
  void initState() { super.initState(); _scrollCtrl.addListener(_onScroll); }

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
