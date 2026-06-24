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

// ── Design tokens ────────────────────────────────────────────────────────────

const _kAmber    = Color(0xFFD4A843);
const _kAmberDim = Color(0xFF8C6E28);
const _kCyan     = Color(0xFF00BCD4);
const _kPurple   = Color(0xFF7C3AED);
const _kGreen    = Color(0xFF16A34A);
const _kRose     = Color(0xFFE11D48);

// ── NovelHomeScreen ───────────────────────────────────────────────────────────

class NovelHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isLatest;
  const NovelHomeScreen({
    required this.source,
    this.isLatest = false,
    super.key,
  });

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

  bool _isSearching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
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

  // ── Filter ──────────────────────────────────────────────────────────────────

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

  // ── Scroll / load more ───────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _hasNextPage && !_isLoadingMore) {
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
        result = await ref.read(
            getLatestUpdatesProvider(source: source, page: next).future);
      } else if (_selectedIdx == _kPopularIdx && !_isSearching) {
        result = await ref.read(
            getPopularProvider(source: source, page: next).future);
      } else if (_isSearching && _query.isNotEmpty) {
        result = await ref.read(searchProvider(
          source: source, query: _query, page: next, filterList: filters,
        ).future);
      } else if (_isFiltering) {
        result = await ref.read(searchProvider(
          source: source, query: '', page: next, filterList: filters,
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

  void _onHomeScroll() {
    if (!_homeScrollCtrl.hasClients) return;
    final pos = _homeScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        _catalogueHasNext && !_catalogueLoading) {
      _loadCatalogue();
    }
  }

  Future<void> _loadCatalogue() async {
    if (_catalogueLoading || !_catalogueHasNext) return;
    setState(() => _catalogueLoading = true);
    try {
      final result = await ref.read(
          getPopularProvider(source: source, page: _cataloguePage).future);
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

  // ── Build ────────────────────────────────────────────────────────────────────

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

  // ── Sliver app bar ───────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext ctx, bool forceElevated) {
    final sourceName = !isLocal ? (source.name ?? '') : 'Local';
    return SliverAppBar(
      pinned: true,
      floating: false,
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
              Icon(Icons.chevron_left_rounded, size: 28, color: _kAmber),
              Text('Browse',
                  style: TextStyle(fontSize: 17, color: _kAmber,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Book icon badge for novel sources
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(Icons.auto_stories_rounded, size: 14, color: _kAmber),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(sourceName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
        const SizedBox(width: 4),
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
                color: Theme.of(lbCtx).scaffoldBackgroundColor
                    .withValues(alpha: 0.92),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 0.5,
              color: _kAmber.withValues(alpha: 0.12),
            ),
          ),
        ]);
      }),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext ctx) {
    final tabs = <_NovelTab>[
      const _NovelTab(Icons.home_rounded,               'Accueil',   _kHomeIdx),
      const _NovelTab(Icons.local_fire_department_rounded, 'Populaires', _kPopularIdx),
      if (supportsLatest)
        const _NovelTab(Icons.update_rounded,           'Derniers',  _kLatestIdx),
      if (filterList.isNotEmpty)
        const _NovelTab(Icons.tune_rounded,             'Filtres',   _kFilterIdx),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? _kAmber
                      : _kAmber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? _kAmber
                        : _kAmber.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 13,
                        color: isActive
                            ? Colors.white
                            : Theme.of(ctx).textTheme.bodyMedium?.color),
                    const SizedBox(width: 5),
                    Text(tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
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

  // ── Body dispatcher ──────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext ctx) {
    if (_selectedIdx == _kHomeIdx && !_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ── Home view ────────────────────────────────────────────────────────────────

  Widget _buildHomeView(BuildContext ctx) {
    return CustomScrollView(
      controller: _homeScrollCtrl,
      slivers: [
        // ── 3-Card peeking carousel ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Consumer(builder: (c, ref, _) {
            final pop = ref.watch(getPopularProvider(source: source, page: 1));
            return pop.when(
              data: (d) {
                final items = d?.list ?? [];
                if (items.isEmpty) return const SizedBox(height: 16);
                return _NovelCarousel(
                    books: items.take(10).toList(), source: source);
              },
              loading: () => _buildCarouselSkeleton(ctx),
              error: (_, __) => const SizedBox(height: 8),
            );
          }),
        ),

        // ── Custom sections ─────────────────────────────────────────────────
        ..._customLists.asMap().entries.map((entry) {
          final idx = entry.key;
          final cl  = entry.value;
          final listId   = cl['id'] as String;
          final listName = cl['name'] as String? ?? listId;
          final isFirst  = idx == 0;
          final isRanked = idx == 1;

          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(ctx,
                  title: listName,
                  accent: _sectionAccent(idx),
                  icon:   _sectionIcon(idx),
                  onSeeAll: isRanked ? null : () {
                    if (isFirst) {
                      setState(() {
                        _selectedIdx = _kLatestIdx;
                        _mangaList.clear(); _page = 1; _hasNextPage = true;
                      });
                    } else {
                      Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => _NovelSectionPage(
                          source: source, title: listName,
                          listId: listId,
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
                      if (isRanked) return _buildRankedRow(ctx, items);
                      if (isFirst)  return _buildFeaturedRow(ctx, items);
                      return _buildBookRow(ctx, items);
                    },
                    loading: () => isRanked
                        ? _buildRankedRowSkeleton(ctx)
                        : _buildBookRowSkeleton(ctx),
                    error: (_, __) => const SizedBox(height: 8),
                  );
                }),
              ],
            ),
          );
        }),

        // ── Fallback: no custom lists → show Latest row ─────────────────────
        if (_customLists.isEmpty && supportsLatest)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(ctx,
                  title: 'Dernières mises à jour',
                  accent: _kCyan,
                  icon: Icons.update_rounded,
                  onSeeAll: () => setState(() {
                    _selectedIdx = _kLatestIdx;
                    _mangaList.clear(); _page = 1; _hasNextPage = true;
                  }),
                ),
                Consumer(builder: (c, ref, _) {
                  final latest = ref.watch(
                      getLatestUpdatesProvider(source: source, page: 1));
                  return latest.when(
                    data: (d) => _buildBookRow(ctx, d?.list ?? []),
                    loading: () => _buildBookRowSkeleton(ctx),
                    error: (_, __) => const SizedBox(height: 8),
                  );
                }),
              ],
            ),
          ),

        // ── Catalogue header ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildSectionHeader(ctx,
            title: 'Explorer',
            accent: const Color(0xFF64748B),
            icon: Icons.grid_view_rounded,
          ),
        ),

        // ── Catalogue grid ──────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                  maxCrossAxisExtent: 130,
                  childAspectRatio: 0.62,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, __) {
                    final base = Theme.of(ctx)
                        .colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5);
                    return Container(
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                  childCount: 12,
                ),
              );
            }

            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                childAspectRatio: 0.62,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (c2, i) {
                  if (i >= _catalogueItems.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kAmber),
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
                childCount:
                    _catalogueItems.length + (_catalogueLoading ? 3 : 0),
              ),
            );
          }),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── Section accent + icon ────────────────────────────────────────────────────

  Color _sectionAccent(int idx) {
    const colors = [
      _kCyan,   // Dernières mises à jour
      _kAmber,  // Top / Tendances
      _kPurple, // Fantasy / Fantaisie
      _kGreen,  // Romances
      _kRose,   // Action
    ];
    return colors[idx % colors.length];
  }

  IconData _sectionIcon(int idx) {
    const icons = [
      Icons.fiber_new_rounded,
      Icons.trending_up_rounded,
      Icons.auto_stories_rounded,
      Icons.favorite_rounded,
      Icons.bolt_rounded,
    ];
    return icons[idx % icons.length];
  }

  // ── Section header ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext ctx, {
    required String title,
    Color? accent,
    IconData? icon,
    VoidCallback? onSeeAll,
  }) {
    final color = accent ?? _kAmber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 3, height: 18,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Text(title,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                )),
          ]),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Voir tout',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600, color: color)),
                  Icon(Icons.chevron_right_rounded, size: 14, color: color),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Featured row (Derniers — large portrait cards) ───────────────────────────

  Widget _buildFeaturedRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(12).toList();
    return SizedBox(
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) =>
            _FeaturedBookCard(book: capped[i], source: source),
      ),
    );
  }

  // ── Ranked row (Top tendances) ───────────────────────────────────────────────

  Widget _buildRankedRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(15).toList();
    return SizedBox(
      height: 182,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) =>
            _RankedBookCard(book: capped[i], source: source, rank: i + 1),
      ),
    );
  }

  Widget _buildRankedRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
          baseColor: base,
          highlightColor:
              Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 182,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 110,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(width: 32, height: 48, color: base.withValues(alpha: 0.4)),
                const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 148,
                    decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Standard book row ────────────────────────────────────────────────────────

  Widget _buildBookRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(14).toList();
    return SizedBox(
      height: 162,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) =>
            _BookCard(book: capped[i], source: source),
      ),
    );
  }

  Widget _buildBookRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
          baseColor: base,
          highlightColor:
              Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1200)),
      child: SizedBox(
        height: 162,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 95,
                  height: 130,
                  decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80, height: 10, color: base.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Carousel skeleton ────────────────────────────────────────────────────────

  Widget _buildCarouselSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme
        .surfaceContainerHighest.withValues(alpha: 0.7);
    final size = MediaQuery.sizeOf(ctx);
    final h = _carouselHeight(size);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
          baseColor: base,
          highlightColor:
              Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1400)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        child: SizedBox(
          height: h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _skeletonCard(base, size.width * 0.78 - 16, h - 8, 12),
              const SizedBox(width: 10),
              _skeletonCard(base, size.width * 0.78 - 16, h - 24, 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonCard(Color base, double w, double h, double r) =>
      Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  static double _carouselHeight(Size size) {
    final isLandscape = size.width > size.height;
    if (isLandscape) return (size.height * 0.72).clamp(240.0, 380.0);
    return (size.width * 0.78 * 1.28 + 56.0).clamp(280.0, size.height * 0.58);
  }

  // ── List view (Popular / Latest) ─────────────────────────────────────────────

  Widget _buildListView(BuildContext ctx) {
    if (_getManga == null) return const Center(child: CircularProgressIndicator(color: _kAmber));

    return _getManga!.when(
      data: (d) {
        final initial = d?.list ?? [];
        if (_mangaList.isEmpty && initial.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mangaList.isEmpty) {
              setState(() {
                _mangaList.addAll(initial);
                _hasNextPage = d!.hasNextPage;
              });
            }
          });
        }

        final displayList =
            _mangaList.isNotEmpty ? _mangaList : initial;
        if (displayList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 52, color: _kAmber.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                const Text('Aucun résultat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return GridView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 130,
            childAspectRatio: 0.62,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: displayList.length + (_isLoadingMore ? 3 : 0),
          itemBuilder: (c2, i) {
            if (i >= displayList.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kAmber),
                ),
              );
            }
            return MangaImageCardWidget(
              getMangaDetail: displayList[i],
              source: source,
              itemType: source.itemType,
              isComfortableGrid: false,
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kAmber)),
      error: (e, _) => _buildError(ctx, e),
    );
  }

  Widget _buildError(BuildContext ctx, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 52, color: _kAmber.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text('Réessayer', style: TextStyle(color: _kAmber)),
          ),
        ],
      ),
    );
  }

  // ── Search screen ────────────────────────────────────────────────────────────

  Widget _buildSearchScreen(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Chercher un roman…',
            hintStyle: TextStyle(color: ctx.primaryColor.withValues(alpha: 0.4)),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: _kAmber),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _isSearching = false;
              _query = '';
              _searchCtrl.clear();
            }),
            child:
                const Text('Annuler', style: TextStyle(color: _kAmber)),
          ),
        ],
      ),
      body: _buildListView(ctx),
    );
  }
}

// ── Data model tab ───────────────────────────────────────────────────────────

class _NovelTab {
  final IconData icon;
  final String label;
  final int idx;
  const _NovelTab(this.icon, this.label, this.idx);
}

// ── 3-Card Peeking Carousel ──────────────────────────────────────────────────
//
// Center card: 78% of screen width, portrait 2:3 ratio
// Side cards peek in at ~25% from each edge — no gap between
// Auto-scroll every 4.5 seconds, page snapping

class _NovelCarousel extends StatefulWidget {
  final List<MManga> books;
  final Source source;
  const _NovelCarousel({required this.books, required this.source});

  @override
  State<_NovelCarousel> createState() => _NovelCarouselState();
}

class _NovelCarouselState extends State<_NovelCarousel> {
  late final PageController _ctrl;
  late int _current;
  Timer? _timer;
  static const double _vf = 0.78; // viewport fraction

  @override
  void initState() {
    super.initState();
    _current = 0;
    _ctrl = PageController(viewportFraction: _vf, initialPage: 0);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || widget.books.isEmpty) return;
      final next = (_current + 1) % widget.books.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic);
    });
  }

  void _openDetail(BuildContext ctx, MManga book) {
    context.push('/mangaDetail', extra: (book, widget.source));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardW = size.width * _vf;
    final cardH = _NovelHomeScreenState._carouselHeight(size);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          SizedBox(
            height: cardH,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.books.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (ctx, i) {
                final book = widget.books[i];
                final isCenter = i == _current;
                return AnimatedScale(
                  scale: isCenter ? 1.0 : 0.91,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: GestureDetector(
                      onTap: () => _openDetail(ctx, book),
                      child: _CarouselCard(
                        book: book,
                        source: widget.source,
                        isCenter: isCenter,
                        cardW: cardW - 14,
                        cardH: cardH - 8,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Dot indicators ──────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.books.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18.0 : 6.0,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? _kAmber
                      : _kAmber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Carousel card ────────────────────────────────────────────────────────────

class _CarouselCard extends StatelessWidget {
  final MManga book;
  final Source source;
  final bool isCenter;
  final double cardW;
  final double cardH;

  const _CarouselCard({
    required this.book,
    required this.source,
    required this.isCenter,
    required this.cardW,
    required this.cardH,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = book.imageUrl ?? '';
    final title  = book.name ?? 'Sans titre';

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isCenter
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Cover image ─────────────────────────────────────────────
            if (imgUrl.isNotEmpty)
              Image(
                image: CustomExtendedImageProvider(imgUrl,
                    headers: getSourceHeaders(source)),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1E1A14),
                  child: const Icon(Icons.auto_stories_rounded,
                      size: 48, color: _kAmberDim),
                ),
              )
            else
              Container(
                color: const Color(0xFF1E1A14),
                child: const Icon(Icons.auto_stories_rounded,
                    size: 48, color: _kAmberDim),
              ),

            // ── Gradient overlay ────────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 0.75, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),

            // ── "Novel" badge top-left ───────────────────────────────────
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_rounded,
                        size: 11, color: Colors.white),
                    SizedBox(width: 4),
                    Text('NOVEL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        )),
                  ],
                ),
              ),
            ),

            // ── Title + Read button ─────────────────────────────────────
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black87),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/mangaDetail', extra: (book, source)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 15),
                      label: const Text('Lire',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
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

// ── Featured book card (Derniers — tall portrait) ────────────────────────────

class _FeaturedBookCard extends StatelessWidget {
  final MManga book;
  final Source source;
  const _FeaturedBookCard({required this.book, required this.source});

  @override
  Widget build(BuildContext context) {
    final imgUrl = book.imageUrl ?? '';
    final title  = book.name ?? '';

    return GestureDetector(
      onTap: () => context.push('/mangaDetail', extra: (book, source)),
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  if (imgUrl.isNotEmpty)
                    Image(
                      image: CustomExtendedImageProvider(imgUrl,
                          headers: getSourceHeaders(source)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _bookCoverFallback(title),
                    )
                  else
                    _bookCoverFallback(title),
                  // "New" badge
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kCyan,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('NEW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          )),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _bookCoverFallback(String title) => Container(
        color: const Color(0xFF1E1A14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_rounded,
                size: 30, color: _kAmberDim),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(title,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9,
                      color: _kAmberDim,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

// ── Ranked book card (Top tendances) ────────────────────────────────────────

class _RankedBookCard extends StatelessWidget {
  final MManga book;
  final Source source;
  final int rank;
  const _RankedBookCard(
      {required this.book, required this.source, required this.rank});

  @override
  Widget build(BuildContext context) {
    final imgUrl = book.imageUrl ?? '';
    final title  = book.name ?? '';

    return GestureDetector(
      onTap: () => context.push('/mangaDetail', extra: (book, source)),
      child: SizedBox(
        width: 110,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Big rank number ────────────────────────────────────────
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: rank <= 3 ? 40 : 34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: rank == 1
                        ? _kAmber
                        : rank == 2
                            ? const Color(0xFFB0B0B0)
                            : rank == 3
                                ? const Color(0xFFCD7F32)
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.35),
                  ),
                ),
              ),
              // ── Cover ──────────────────────────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 148,
                    child: imgUrl.isNotEmpty
                        ? Image(
                            image: CustomExtendedImageProvider(imgUrl,
                                headers: getSourceHeaders(source)),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(title),
                          )
                        : _placeholder(title),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(String title) => Container(
        color: const Color(0xFF1E1A14),
        child: Center(
          child: Text(title,
              maxLines: 3,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: _kAmberDim)),
        ),
      );
}

// ── Standard book card ───────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final MManga book;
  final Source source;
  const _BookCard({required this.book, required this.source});

  @override
  Widget build(BuildContext context) {
    final imgUrl = book.imageUrl ?? '';
    final title  = book.name ?? '';

    return GestureDetector(
      onTap: () => context.push('/mangaDetail', extra: (book, source)),
      child: Container(
        width: 95,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 130,
                width: 95,
                child: imgUrl.isNotEmpty
                    ? Image(
                        image: CustomExtendedImageProvider(imgUrl,
                            headers: getSourceHeaders(source)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(title),
                      )
                    : _placeholder(title),
              ),
            ),
            const SizedBox(height: 5),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25)),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String title) => Container(
        color: const Color(0xFF1E1A14),
        child: Center(
          child: Icon(Icons.auto_stories_rounded,
              size: 28, color: _kAmber.withValues(alpha: 0.35)),
        ),
      );
}

// ── Section full-page ────────────────────────────────────────────────────────

class _NovelSectionPage extends ConsumerWidget {
  final Source source;
  final String title;
  final String listId;
  const _NovelSectionPage(
      {required this.source, required this.title, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data =
        ref.watch(getCustomListProvider(source: source, listId: listId, page: 1));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: _kAmber,
        iconTheme: const IconThemeData(color: _kAmber),
      ),
      body: data.when(
        data: (d) {
          final items = d?.list ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Aucun résultat'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              childAspectRatio: 0.62,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => MangaImageCardWidget(
              getMangaDetail: items[i],
              source: source,
              itemType: source.itemType,
              isComfortableGrid: false,
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kAmber)),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
