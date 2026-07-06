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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';

// ── 3-dot menu actions ────────────────────────────────────────────────────────
enum _HomeMenuAction { openBrowser, settings, diagnostic }

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
  Timer? _suggestionTimer;
  List<String> _suggestions = [];
  bool _isListView = false;

  // ── MovieBox dock state ──────────────────────────────────────────────────
  int _mbBottomNavIdx = 0; // 0=Home 1=NovelHub 2=FightZone 3=Downloads 4=Me
  int _mbSubTabIdx    = 0; // index into _kMbSubTabs list

  // MovieBox sub-tabs (from appTab.json subTabs in the APK)
  static const _kMbSubTabs = [
    (label: '🤼\u202FFightZone', watchtowerIdx: 0),
    (label: 'Live',              watchtowerIdx: 1),
    (label: 'Trending',          watchtowerIdx: 1),
    (label: 'Movie',             watchtowerIdx: 0),
    (label: 'TV',                watchtowerIdx: 2),
    (label: 'Anime',             watchtowerIdx: 1),
    (label: 'ShortTV',           watchtowerIdx: 1),
    (label: 'Kids',              watchtowerIdx: 1),
    (label: 'Education',         watchtowerIdx: 1),
    (label: 'Football',          watchtowerIdx: 1),
    (label: 'Music',             watchtowerIdx: 1),
    (label: 'Free Novels',       watchtowerIdx: 1),
    (label: 'Western',           watchtowerIdx: 1),
    (label: 'Asian',             watchtowerIdx: 1),
    (label: 'Nollywood',         watchtowerIdx: 1),
    (label: 'Game',              watchtowerIdx: 1),
  ];

  @override
  void initState() {
    super.initState();
    _homeScrollCtrl.addListener(_onHomeScroll);
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _homeScrollCtrl.dispose();
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

  // ── 3-dot menu ───────────────────────────────────────────────────────────

  Future<void> _handleHomeMenuAction(BuildContext ctx, _HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.openBrowser:
        final baseUrl = ref.read(sourceBaseUrlProvider(source: source));
        ctx.push('/mangawebview', extra: {
          'url': baseUrl,
          'sourceId': source.id.toString(),
          'title': '',
        });
      case _HomeMenuAction.settings:
        final res = await ctx.push('/extension_detail', extra: source);
        if (res != null && mounted) setState(() => _source = res as Source);
      case _HomeMenuAction.diagnostic:
        ctx.push('/extensionDiagnostic', extra: source.itemType);
    }
  }

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
      bottomNavigationBar: _mbBottomNavIdx == 0
          ? _buildMbBottomDock(context)
          : null,
      body: _mbBottomNavIdx == 0
          ? NestedScrollView(
              controller: _scrollCtrl,
              headerSliverBuilder: (ctx, innerBoxIsScrolled) =>
                  [_buildSliverAppBar(ctx, innerBoxIsScrolled)],
              body: _buildBody(context),
            )
          : _buildMbStubPage(context, _mbBottomNavIdx),
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
      expandedHeight: 0,
      // ── NO back button ────────────────────────────────────────────────────
      automaticallyImplyLeading: false,
      // ── Leading: MovieBox logo (30×full height) ───────────────────────────
      leadingWidth: 46,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: !isLocal && (source.iconUrl?.isNotEmpty ?? false)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  source.iconUrl!,
                  width: 30, height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.movie_rounded, size: 26, color: Colors.white),
                ))
            : const Icon(Icons.movie_rounded, size: 26, color: Colors.white),
      ),
      // ── Title: MovieBox search bar (rounded, semi-transparent white) ──────
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
      // ── Actions: settings popup only ─────────────────────────────────────
      actions: [
        if (!isLocal)
          Builder(
            builder: (actCtx) => ArrowPopupMenuButton<_HomeMenuAction>(
              padding: const EdgeInsets.all(4),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
              onSelected: (action) => _handleHomeMenuAction(actCtx, action),
              itemBuilder: (menuCtx) => [
                PopupMenuItem(
                  value: _HomeMenuAction.openBrowser,
                  child: Row(children: [
                    const Icon(Icons.open_in_browser_rounded, size: 20),
                    const SizedBox(width: 12),
                    const Text('Ouvrir dans le navigateur', style: TextStyle(fontSize: 14)),
                  ]),
                ),
                PopupMenuItem(
                  value: _HomeMenuAction.diagnostic,
                  child: Row(children: [
                    const Icon(Icons.bug_report_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Diagnostic', style: TextStyle(fontSize: 14)),
                  ]),
                ),
                PopupMenuItem(
                  value: _HomeMenuAction.settings,
                  child: Row(children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Paramètres', style: TextStyle(fontSize: 14)),
                  ]),
                ),
              ],
            ),
          ),
        const SizedBox(width: 4),
      ],
      // ── Bottom: MovieBox MagicIndicator-style sub-tabs ────────────────────
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildMbSubDock(ctx),
      ),
      // ── flexibleSpace: solid dark background (no blur — MovieBox is dark) ─
      flexibleSpace: Container(color: mbBg),
    );
  }

  // ── MovieBox MagicIndicator-style scrollable sub-dock ────────────────────
  // From fragment_home.xml: MagicIndicator height=32dp, marginTop=4dp, marginBottom=8dp
  // Selected tab: white text + green underline. Unselected: white_60 text.

  Widget _buildMbSubDock(BuildContext ctx) {
    const white60 = Color(0x99FFFFFF);
    const brandGreen = Color(0xFF07b84e);

    return SizedBox(
      height: 44, // 32dp indicator + 4dp top + 8dp bottom
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 0),
        itemCount: _kMbSubTabs.length,
        itemBuilder: (_, i) {
          final tab  = _kMbSubTabs[i];
          final active = _mbSubTabIdx == i;
          return GestureDetector(
            onTap: () {
              setState(() {
                _mbSubTabIdx = i;
                _selectedIdx = tab.watchtowerIdx;
                _isFiltering = false;
                _mangaList.clear();
                _page = 1;
                _hasNextPage = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : white60,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Underline indicator (MagicIndicator style)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    width: active ? 20 : 0,
                    decoration: BoxDecoration(
                      color: brandGreen,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
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
      final carouselList  = _customLists.where((cl) => cl['id'] == 'carousel').firstOrNull;
      final categoryLists = _customLists.where((cl) => cl['layout'] == 'category').toList();
      final catalogueList = _customLists.where((cl) => cl['id'] == 'catalogue').firstOrNull;
      final regularLists  = _customLists.where((cl) =>
        cl['id'] != 'carousel' && cl['layout'] != 'category' && cl['id'] != 'catalogue'
      ).toList();

      return CustomScrollView(
        controller: _homeScrollCtrl,
        slivers: [
          // ── Hero carousel (bannerList exact de l'API) ────────────────────
          SliverToBoxAdapter(
            child: Consumer(builder: (c, ref, _) {
              if (carouselList != null) {
                final carouselData = ref.watch(getCustomListProvider(
                    source: source, listId: 'carousel', page: 1));
                return carouselData.when(
                  data: (d) {
                    final items = d?.list ?? [];
                    if (items.isEmpty) return const SizedBox(height: 8);
                    return _WatchHero(mangas: items, source: source);
                  },
                  loading: () => _buildHeroSkeleton(ctx),
                  error: (_, __) {
                    // fallback to popular on error
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
                  },
                );
              }
              // No carousel list — use popular
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
      );
    }

    // ── Category chips strip ─────────────────────────────────────────────────

    Widget _buildCategoryChips(BuildContext ctx, List<Map<String, dynamic>> cats) {
      return SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final cl = cats[i];
            final listId   = cl['id'] as String;
            final listName = cl['name'] as String? ?? listId;
            final Color accent = _parseHexColor(cl['color'] as String?, ctx.primaryColor);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _WatchSectionPage(
                    source: source, title: listName,
                    type: _SectionKind.custom, customListId: listId,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(listName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
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
    final accentColor = accent ?? ctx.primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 14, 10),
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
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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

  // ══════════════════════════════════════════════════════════════════════════
  // ── MovieBox Bottom Dock (from activity_main.xml + tab_bottom.xml) ────────
  // Total height: 80dp. Icons: 24×24dp. Label: 10sp, marginBottom 8dp.
  // Center tab (Fight Zone): big image 72×80dp, no label.
  // Background: #1C1E21 (dark with slight arc shape illusion).
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMbBottomDock(BuildContext ctx) {
    const dockBg   = Color(0xFF1C1E21);
    const activeC  = Colors.white;
    const inactiveC = Color(0x99FFFFFF); // white_60
    const brandG   = Color(0xFF07b84e);

    // Tab definitions matching appTab.json bottomTabs
    // Center tab (Fight Zone idx=2) uses a larger icon (72×80dp equivalent)
    final items = <({IconData icon, String label, bool isCenter, bool hasBadge, String? badge})>[
      (icon: Icons.home_rounded,       label: 'Home',     isCenter: false, hasBadge: false, badge: null),
      (icon: Icons.menu_book_rounded,  label: 'NovelHub', isCenter: false, hasBadge: true,  badge: 'HOT'),
      (icon: Icons.sports_mma_rounded, label: '',         isCenter: true,  hasBadge: false, badge: null),
      (icon: Icons.download_rounded,   label: 'Downloads',isCenter: false, hasBadge: false, badge: null),
      (icon: Icons.person_rounded,     label: 'Me',       isCenter: false, hasBadge: false, badge: null),
    ];

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: dockBg,
        // Subtle top border like MovieBox's arc
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final item   = items[i];
            final active = _mbBottomNavIdx == i;
            final iconColor = active ? activeC : inactiveC;
            final textColor = active ? activeC : inactiveC;

            if (item.isCenter) {
              // ── Center: Fight Zone — bigger icon (72dp equivalent), no label ──
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mbBottomNavIdx = i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 80,
                    child: Center(
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2ECC71), Color(0xFF07b84e)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF07b84e).withValues(alpha: 0.45),
                              blurRadius: 14, spreadRadius: 0, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.sports_mma_rounded,
                            size: 28, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mbBottomNavIdx = i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.icon, size: 24, color: iconColor),
                          // Badge (HOT etc)
                          if (item.hasBadge && item.badge != null)
                            Positioned(
                              top: -4, right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF03930),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(3),
                                    topRight: const Radius.circular(3),
                                    bottomRight: const Radius.circular(3),
                                    bottomLeft: const Radius.circular(1),
                                  ),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: const TextStyle(
                                    fontSize: 7, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: 0.2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Stub page for non-Home bottom tabs ────────────────────────────────────

  Widget _buildMbStubPage(BuildContext ctx, int navIdx) {
    const bgColor = Color(0xFF101114);
    const labels  = ['Home', 'NovelHub', 'Fight Zone', 'Downloads', 'Me'];
    final label   = navIdx < labels.length ? labels[navIdx] : '';
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => setState(() => _mbBottomNavIdx = 0),
            icon: const Icon(Icons.close_rounded, color: Colors.white60),
          ),
        ],
      ),
      bottomNavigationBar: _buildMbBottomDock(ctx),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_rounded, size: 48, color: Color(0x3DFFFFFF)),
            const SizedBox(height: 12),
            Text(
              '$label — bientôt disponible',
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
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
  final int rank;
  const _RankedCard({required this.manga, required this.source, required this.rank});

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

    final rank = widget.rank;
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
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: SizedBox(
            width: 112,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Big rank number
              SizedBox(
                width: 36,
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
                    Text(widget.manga.name ?? '',
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
                  // Play button
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 20, color: Colors.white),
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
  