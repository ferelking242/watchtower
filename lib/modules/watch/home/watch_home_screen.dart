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


// ── WatchHomeScreen ─────────────────────────────────────────────────────────
// Netflix-style home for ItemType.anime extensions.
// Hero banner auto-carousel → sticky tab chips → horizontal 16:9 rows.

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

  static const _kHomeIdx = 0;
  static const _kLatestIdx = 1;
  static const _kFilterIdx = 2;

  late int _selectedIdx = widget.isLatest ? _kLatestIdx : _kHomeIdx;

  bool _isSearching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Sync data from extension (loaded eagerly via late)
  late final List<Map<String, dynamic>> _customLists =
      isLocal ? [] : getCustomLists(source: source);
  late final List<dynamic> filterList =
      isLocal ? [] : getFilterList(source: source);
  late List<dynamic> filters = List.from(filterList);

  bool _isFiltering = false;

  // For list/search/latest mode
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _page = 1;
  final List<MManga> _mangaList = [];

  AsyncValue<MPages?>? _getManga;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get supportsLatest =>
      isLocal ? true : ref.watch(supportsLatestProvider(source: source));

  // ── Filter sheet ─────────────────────────────────────────────────────────

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

  // ── Scroll / load more ───────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSearching && _query.isNotEmpty) {
      _getManga = ref.watch(searchProvider(
        source: source,
        query: _query,
        page: 1,
        filterList: filters,
      ));
    } else if (_isFiltering) {
      _getManga = ref.watch(searchProvider(
        source: source,
        query: '',
        page: 1,
        filterList: filters,
      ));
    } else if (_selectedIdx == _kLatestIdx) {
      _getManga =
          ref.watch(getLatestUpdatesProvider(source: source, page: 1));
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

  // ── Sliver app bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext ctx, bool forceElevated) {
    final sourceName =
        !isLocal ? (source.name ?? '') : 'Local';
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
              Icon(Icons.chevron_left_rounded, size: 28,
                  color: ctx.primaryColor),
              Text(
                'Browse',
                style: TextStyle(
                  fontSize: 17,
                  color: ctx.primaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                source.iconUrl!,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              sourceName,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                color: Theme.of(lbCtx)
                    .scaffoldBackgroundColor
                    .withValues(alpha: 0.92),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 0.5,
              color: Theme.of(lbCtx).dividerColor.withValues(alpha: 0.25),
            ),
          ),
        ]);
      }),
    );
  }

  // ── Tab chip bar ──────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext ctx) {
    final tabs = <_WatchTab>[
      const _WatchTab(Icons.home_rounded, 'Home', _kHomeIdx),
      if (supportsLatest)
        const _WatchTab(Icons.update_rounded, 'Latest', _kLatestIdx),
      if (filterList.isNotEmpty)
        const _WatchTab(Icons.tune_rounded, 'Filter', _kFilterIdx),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
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
                    Icon(
                      tab.icon,
                      size: 13,
                      color: isActive
                          ? Colors.white
                          : Theme.of(ctx).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : Theme.of(ctx).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body dispatcher ───────────────────────────────────────────────────────

  Widget _buildBody(BuildContext ctx) {
    if (_selectedIdx == _kHomeIdx && !_isFiltering && !_isSearching) {
      return _buildHomeView(ctx);
    }
    return _buildListView(ctx);
  }

  // ── Home view: hero + horizontal rows ─────────────────────────────────────

  Widget _buildHomeView(BuildContext ctx) {
    return CustomScrollView(
      slivers: [
        // ── Hero carousel ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Consumer(builder: (c, ref, _) {
            final pop =
                ref.watch(getPopularProvider(source: source, page: 1));
            return pop.when(
              data: (d) {
                final items = d?.list ?? [];
                if (items.isEmpty) return const SizedBox(height: 8);
                return _WatchHero(
                  mangas: items.take(8).toList(),
                  source: source,
                );
              },
              loading: () => _buildHeroSkeleton(ctx),
              error: (_, __) => const SizedBox(height: 8),
            );
          }),
        ),

        // ── Popular row ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(ctx, title: 'Popular', onSeeAll: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _WatchSectionPage(
                    source: source,
                    title: 'Popular',
                    type: _SectionKind.popular,
                  ),
                ));
              }),
              Consumer(builder: (c, ref, _) {
                final pop = ref.watch(
                    getPopularProvider(source: source, page: 1));
                return pop.when(
                  data: (d) => _buildRow(ctx, d?.list ?? []),
                  loading: () => _buildRowSkeleton(ctx),
                  error: (_, __) => const SizedBox(height: 8),
                );
              }),
            ],
          ),
        ),

        // ── Custom list rows ───────────────────────────────────────────
        ..._customLists.map((cl) {
          final listId = cl['id'] as String;
          String listName = cl['name'] as String? ?? listId;
          if (listName.toLowerCase() == 'new titles') {
            listName = 'New Titles';
          }
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(ctx, title: listName, onSeeAll: () {
                  Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source,
                      title: listName,
                      type: _SectionKind.custom,
                      customListId: listId,
                    ),
                  ));
                }),
                Consumer(builder: (c, ref, _) {
                  final data = ref.watch(getCustomListProvider(
                    source: source,
                    listId: listId,
                    page: 1,
                  ));
                  return data.when(
                    data: (d) => _buildRow(ctx, d?.list ?? []),
                    loading: () => _buildRowSkeleton(ctx),
                    error: (_, __) => const SizedBox(height: 8),
                  );
                }),
              ],
            ),
          );
        }),

        // ── Latest row ─────────────────────────────────────────────────
        if (supportsLatest)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(ctx, title: 'Latest Updates',
                    onSeeAll: () {
                  Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _WatchSectionPage(
                      source: source,
                      title: 'Latest Updates',
                      type: _SectionKind.latest,
                    ),
                  ));
                }),
                Consumer(builder: (c, ref, _) {
                  final latest = ref.watch(
                      getLatestUpdatesProvider(source: source, page: 1));
                  return latest.when(
                    data: (d) => _buildRow(ctx, d?.list ?? []),
                    loading: () => _buildRowSkeleton(ctx),
                    error: (_, __) => const SizedBox(height: 8),
                  );
                }),
              ],
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── List view (latest / filter / search) ──────────────────────────────────

  Widget _buildListView(BuildContext ctx) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) _onScroll();
        return false;
      },
      child: _getManga?.when(
            data: (data) {
              if (data != null &&
                  _mangaList.isEmpty &&
                  data.list.isNotEmpty) {
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
                    child: Text(
                      ctx.l10n.no_result,
                      style: TextStyle(color: Theme.of(ctx).hintColor),
                    ),
                  );
                }
                return _buildSkeletonGrid();
              }
              return _buildGrid(ctx);
            },
            loading: () => _mangaList.isEmpty
                ? _buildSkeletonGrid()
                : _buildGrid(ctx),
            error: (e, _) => _buildError(ctx, e),
          ) ??
          _buildSkeletonGrid(),
    );
  }

  Widget _buildGrid(BuildContext ctx) {
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _mangaList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (c, i) {
        if (i >= _mangaList.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
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
    final base = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: base,
        highlightColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        duration: const Duration(milliseconds: 1200),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ── Search screen ─────────────────────────────────────────────────────────

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
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search,
                              size: 20, color: Theme.of(ctx).hintColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                    color: Theme.of(ctx).hintColor,
                                    fontSize: 16),
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
                                child: Icon(Icons.cancel,
                                    size: 18,
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
                        _isSearching = false;
                        _query = '';
                        _mangaList.clear();
                        _page = 1;
                        _hasNextPage = true;
                      });
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: ctx.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildListView(ctx)),
          ],
        ),
      ),
    );
  }

  // ── Shared builders ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext ctx,
      {required String title, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ctx.primaryColor,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 17, color: ctx.primaryColor),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext ctx, List<MManga> items) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final capped = items.take(12).toList();
    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: capped.length,
        itemBuilder: (_, i) =>
            _WatchCard(manga: capped[i], source: source),
      ),
    );
  }

  Widget _buildRowSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: base,
        highlightColor:
            Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
        duration: const Duration(milliseconds: 1200),
      ),
      child: SizedBox(
        height: 175,
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
                  width: 200,
                  height: 113,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSkeleton(BuildContext ctx) {
    final base = Theme.of(ctx)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    final size = MediaQuery.sizeOf(ctx);
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: base,
        highlightColor:
            Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
        duration: const Duration(milliseconds: 1400),
      ),
      child: Container(
        width: size.width,
        height: size.height * 0.52,
        color: base,
      ),
    );
  }

  Widget _buildError(BuildContext ctx, Object error) {
    void retry() {
      if (_selectedIdx == _kLatestIdx) {
        ref.invalidate(
            getLatestUpdatesProvider(source: source, page: 1));
      } else if (_isSearching && _query.isNotEmpty) {
        ref.invalidate(searchProvider(
          source: source,
          query: _query,
          page: 1,
          filterList: filters,
        ));
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '(╥_╥)',
              style: TextStyle(
                fontSize: 52,
                color: Theme.of(ctx).hintColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab data ──────────────────────────────────────────────────────────────────

class _WatchTab {
  final IconData icon;
  final String label;
  final int idx;
  const _WatchTab(this.icon, this.label, this.idx);
}

// ── Hero carousel (full-bleed, auto-advance) ──────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetch(0);
      _prefetch(1);
    });
    if (widget.mangas.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_ctrl.hasClients) return;
        _page = (_page + 1) % widget.mangas.length;
        _ctrl.animateToPage(
          _page,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _prefetch(int index) {
    if (index < 0 || index >= widget.mangas.length) return;
    final manga = widget.mangas[index];
    if (manga.link == null || _detailCache.containsKey(index)) return;
    ref
        .read(getDetailProvider(url: manga.link!, source: widget.source)
            .future)
        .then((d) {
      if (mounted) setState(() => _detailCache[index] = d);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroH = size.height * 0.52;

    return SizedBox(
      height: heroH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.mangas.length,
            onPageChanged: (p) {
              _page = p;
              _prefetch(p + 1);
            },
            itemBuilder: (_, i) => _HeroSlide(
              manga: widget.mangas[i],
              detail: _detailCache[i],
              source: widget.source,
              height: heroH,
            ),
          ),
          // Dot indicators
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mangas.length, (i) {
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final cur = _ctrl.hasClients
                        ? (_ctrl.page ?? 0).round()
                        : _page;
                    final isActive = cur == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlide extends ConsumerWidget {
  final MManga manga;
  final MManga? detail;
  final Source source;
  final double height;
  const _HeroSlide({
    required this.manga,
    this.detail,
    required this.source,
    required this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
      source: source.name!,
      lang: source.lang!,
      sourceId: source.id,
    ));
    final imgUrl = toImgUrl(manga.imageUrl ?? '');
    final ImageProvider<Object> cover = imgUrl.isNotEmpty
        ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
        : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

    final title = detail?.name ?? manga.name ?? '';
    final genres = detail?.genre ?? manga.genre ?? [];

    return GestureDetector(
      onTap: () {
        if (manga.link != null) {
          pushToMangaReaderDetail(
            ref: ref,
            context: context,
            getManga: manga,
            lang: source.lang!,
            source: source.name!,
            itemType: source.itemType,
            sourceId: source.id,
          );
        }
      },
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imgUrl.isNotEmpty
                ? Image(
                    image: cover,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 64,
                          color: Colors.white30),
                    ),
                  )
                : Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.play_circle_outline_rounded,
                        size: 64, color: Colors.white30),
                  ),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // Info at bottom
            Positioned(
              bottom: 28,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: genres.take(3).map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (manga.link != null) {
                          pushToMangaReaderDetail(
                            ref: ref,
                            context: context,
                            getManga: manga,
                            lang: source.lang!,
                            source: source.name!,
                            itemType: source.itemType,
                            sourceId: source.id,
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 20, color: Colors.white),
                      label: const Text(
                        'Watch Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

// ── 16:9 Watch card ───────────────────────────────────────────────────────────

class _WatchCard extends ConsumerWidget {
  final MManga manga;
  final Source source;
  const _WatchCard({required this.manga, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(headersProvider(
      source: source.name!,
      lang: source.lang!,
      sourceId: source.id,
    ));
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
              ref: ref,
              context: context,
              getManga: manga,
              lang: source.lang!,
              source: source.name!,
              itemType: source.itemType,
              sourceId: source.id,
            );
          }
        },
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imgUrl.isNotEmpty
                          ? Image(
                              image: cover,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 32),
                              ),
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 32),
                            ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 26,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                manga.name ?? '',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
    required this.source,
    required this.title,
    required this.type,
    this.customListId,
  });

  @override
  ConsumerState<_WatchSectionPage> createState() =>
      _WatchSectionPageState();
}

class _WatchSectionPageState extends ConsumerState<_WatchSectionPage> {
  int _page = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  final List<MManga> _items = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
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
      switch (widget.type) {
        case _SectionKind.popular:
          result = await ref.read(
              getPopularProvider(source: widget.source, page: next).future);
        case _SectionKind.latest:
          result = await ref.read(getLatestUpdatesProvider(
              source: widget.source, page: next).future);
        case _SectionKind.custom:
          if (widget.customListId != null) {
            result = await ref.read(getCustomListProvider(
              source: widget.source,
              listId: widget.customListId!,
              page: next,
            ).future);
          }
      }
      if (mounted && result != null && result.list.isNotEmpty) {
        setState(() {
          _page = next;
          _hasNextPage = result!.hasNextPage;
          _items.addAll(result.list);
        });
      } else if (mounted) {
        setState(() => _hasNextPage = false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<MPages?> asyncData;
    switch (widget.type) {
      case _SectionKind.popular:
        asyncData =
            ref.watch(getPopularProvider(source: widget.source, page: 1));
      case _SectionKind.latest:
        asyncData = ref.watch(
            getLatestUpdatesProvider(source: widget.source, page: 1));
      case _SectionKind.custom:
        asyncData = widget.customListId != null
            ? ref.watch(getCustomListProvider(
                source: widget.source,
                listId: widget.customListId!,
                page: 1,
              ))
            : const AsyncValue.data(null);
    }

    asyncData.whenData((data) {
      if (data != null && _items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _items.isEmpty) {
            setState(() {
              _items.addAll(data.list);
              _hasNextPage = data.hasNextPage;
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: asyncData.when(
        loading: () => _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildGrid(context),
        error: (e, _) => _items.isEmpty
            ? Center(
                child: Text('Error: $e',
                    style:
                        TextStyle(color: Theme.of(context).hintColor)))
            : _buildGrid(context),
        data: (_) => _buildGrid(context),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No results',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return MangaImageCardWidget(
          getMangaDetail: _items[i],
          source: widget.source,
          itemType: widget.source.itemType,
          isComfortableGrid: false,
        );
      },
    );
  }
}
