// WatchHomeScreen — Netflix-styled source home screen.
// Layout inspired by flutter_netflix (angjelkom/flutter_netflix).
// Data: extension providers (getCustomLists / getCustomListProvider).
// Widgets: nf_widgets/ folder — direct adaptations of flutter_netflix originals.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/ui/widgets/see_all_button.dart';
import 'nf_widgets/nf_app_bar.dart';
import 'nf_widgets/nf_highlight_banner.dart';
import 'nf_widgets/nf_movie_box.dart';
import 'nf_widgets/nf_new_and_hot_tile.dart';
import 'nf_widgets/nf_utils.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/services/layout_registry.dart';

// ── WatchHomeScreen ───────────────────────────────────────────────────────────

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
    with TickerProviderStateMixin {
  late Source _source = widget.source;
  Source get source => _source;
  bool get isLocal => source.name == 'local' && source.lang == '';

  // ── Catalogue state ───────────────────────────────────────────────────────
  final List<MManga> _catalogueItems  = [];
  int  _cataloguePage    = 1;
  bool _catalogueHasNext = true;
  bool _catalogueLoading = false;

  // ── List-view state (search / filter / popular / latest) ──────────────────
  bool   _isSearching  = false;
  bool   _isFiltering  = false;
  String _query        = '';
  bool   _isListView   = false;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<MManga> _mangaList   = [];
  bool _isLoadingMore  = false;
  bool _hasNextPage    = true;
  int  _page           = 1;

  AsyncValue<MPages?>? _getManga;
  Timer? _suggestionTimer;
  List<String> _suggestions = [];

  // ── Voice search ──────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening     = false;

  // ── Scroll offset (drives app bar opacity) ────────────────────────────────
  double _scrollOffset = 0.0;

  // ── Extension data ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _customLists = const [];
  // ── App-bar height (filled in build, used for padding) ────────────────────
  double _appBarH = kToolbarHeight;

  // ── Refresh key — incremented on each pull-to-refresh to force hero rebuild
  int _refreshKey = 0;

  // ── Aidoku-style tab controller ───────────────────────────────────────────
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      statusBarBrightness:      Brightness.dark,
    ));
    _scrollCtrl.addListener(_onScroll);
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (mounted) setState(() {}); });
    _loadLayout();
    _initSpeech();
  }

  @override

  void dispose() {
    _tabCtrl.dispose();
    _suggestionTimer?.cancel();
    _speech.stop();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
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


  // ── Voice search helpers ──────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == stt.SpeechToText.notListeningStatus) {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _startVoiceSearch() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconnaissance vocale indisponible')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (words.isNotEmpty) {
          _searchCtrl.text = words;
          _onQueryChanged(words);
        }
      },
      listenFor:         const Duration(seconds: 10),
      pauseFor:          const Duration(seconds: 3),
      localeId:          'fr_FR',
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    // Update opacity value
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset);
    }
    // Trigger catalogue load near bottom
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        _catalogueHasNext &&
        !_catalogueLoading) {
      _loadCatalogue();
    }
  }

  // ── Pull-to-refresh ───────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    ref.invalidate(getPopularProvider(source: source, page: 1));
    ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
    for (final cl in _customLists) {
      ref.invalidate(getCustomListProvider(
          source: source, listId: cl['id'] as String, page: 1));
    }
    if (mounted) {
      setState(() {
        _catalogueItems.clear();
        _cataloguePage    = 1;
        _catalogueHasNext = true;
        _catalogueLoading = false;
        _refreshKey++;
      });
    }
    // Allow providers to start rebuilding
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  // ── Catalogue pagination ──────────────────────────────────────────────────

  Future<void> _loadCatalogue() async {
    if (_catalogueLoading || !_catalogueHasNext) return;
    setState(() => _catalogueLoading = true);
    try {
      final hasCatList =
          _customLists.any((cl) => cl['id'] == 'catalogue');
      MPages? result;
      if (hasCatList) {
        result = await ref.read(getCustomListProvider(
            source: source,
            listId: 'catalogue',
            page:   _cataloguePage)
            .future);
      } else {
        result = await ref.read(
            getPopularProvider(source: source, page: _cataloguePage).future);
      }
      if (result != null) {
        _cataloguePage++;
        _catalogueHasNext = result.hasNextPage;
        _catalogueItems.addAll(result.list);
      }
    } catch (_) {
      setState(() => _catalogueHasNext = false);
    }
    if (mounted) setState(() => _catalogueLoading = false);
  }

  // ── List-view (search / filter / popular) pagination ──────────────────────

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    try {
      final next   = _page + 1;
      MPages? result;
      if (_isSearching && _query.isNotEmpty) {
        result = await ref.read(searchProvider(
          source: source, query: _query, page: next,
          filterList: const []).future);
      } else {
        result = await ref.read(
            getPopularProvider(source: source, page: next).future);
      }
      if (result != null && mounted) {
        setState(() {
          _page++;
          _hasNextPage = result!.hasNextPage;
          _mangaList.addAll(result.list);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onQueryChanged(String q) {
    _suggestionTimer?.cancel();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _suggestions = [];
        _mangaList.clear();
      }
    });
    if (q.isEmpty) return;

    _suggestionTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() { _mangaList.clear(); _page = 1; _hasNextPage = true; });

      // Populate autocomplete suggestions
      try {
        final snap = await ref.read(searchProvider(
          source: source, query: q, page: 1, filterList: const [],
        ).future);
        if (!mounted) return;
        final titles = (snap?.list ?? [])
            .map((m) => m.name ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .take(6)
            .toList();
        setState(() => _suggestions = titles);
      } catch (_) {}
    });
  }

  void _onSuggestionTap(String title) {
    _searchCtrl.text = title;
    _suggestionTimer?.cancel();
    setState(() {
      _query       = title;
      _suggestions = [];
      _mangaList.clear();
      _page        = 1;
      _hasNextPage = true;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    _appBarH = topPad + kToolbarHeight;

    return Scaffold(
      backgroundColor: nfBackgroundColor,
      extendBody:      true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(
            begin: const Offset(0, -0.06),
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
          return FadeTransition(
            opacity: anim,
            child:   SlideTransition(position: slide, child: child),
          );
        },
        child: _isSearching
            ? KeyedSubtree(
                key: const ValueKey('search'),
                child: _buildSearchView(context))
            : KeyedSubtree(
                key: const ValueKey('home'),
                child: _buildAidokuHome(context)),
      ),
    );
  }

  // ── Aidoku-style home view ─────────────────────────────────────────────────

  Widget _buildAidokuHome(BuildContext ctx) {
    return NestedScrollView(
      controller: _scrollCtrl,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // ── Collapsing SliverAppBar ───────────────────────────────────────
        SliverAppBar(
          expandedHeight:  104,
          collapsedHeight: kToolbarHeight,
          pinned:          true,
          floating:        false,
          backgroundColor: nfBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          forceElevated:   innerBoxIsScrolled,
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => setState(() => _isSearching = true),
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
            title: Text(
              source.name ?? source.lang ?? 'Anime',
              style: const TextStyle(
                color:         Colors.white,
                fontSize:      17,
                fontWeight:    FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            expandedTitleScale: 1.9,
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    nfBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Sticky pill tab bar ───────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _PillTabBarDelegate(
            tabController: _tabCtrl,
            tabs:          const ['Accueil', 'Populaire', 'Récents'],
          ),
        ),
      ],

      // ── Tab body ─────────────────────────────────────────────────────────
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAccueilTab(ctx),
          _buildPopularTab(ctx),
          _buildRecentsTab(ctx),
        ],
      ),
    );
  }

  // ── Accueil tab ────────────────────────────────────────────────────────────

  Widget _buildAccueilTab(BuildContext ctx) {
    return RefreshIndicator(
      onRefresh:       _onRefresh,
      color:           Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics()),
        slivers: [
          // ── "Popular New Titles" section ──────────────────────────────
          SliverToBoxAdapter(
            child: _AidokuSectionHeader(title: 'Popular New Titles'),
          ),
          SliverToBoxAdapter(
            child: _PopularBigCarousel(
              source: source,
              onTap: (manga) {
                if (_tryOpenReel(ctx, manga, source)) return;
                pushToMangaReaderDetail(
                  ref: ref, context: ctx, getManga: manga,
                  lang: source.lang!, source: source.name!,
                  itemType: source.itemType, sourceId: source.id,
                );
              },
            ),
          ),

          // ── "Latest Updates" section ──────────────────────────────────
          SliverToBoxAdapter(
            child: _AidokuSectionHeader(
              title: 'Latest Updates',
              hasArrow: true,
              onArrow: () => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => _WatchSectionPage(
                  source: source,
                  title:  'Latest Updates',
                  type:   _SectionKind.latest,
                ),
              )),
            ),
          ),
          _LatestUpdatesSliver(
            source: source,
            onTap: (manga) {
              if (_tryOpenReel(ctx, manga, source)) return;
              pushToMangaReaderDetail(
                ref: ref, context: ctx, getManga: manga,
                lang: source.lang!, source: source.name!,
                itemType: source.itemType, sourceId: source.id,
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── Populaire tab ──────────────────────────────────────────────────────────

  Widget _buildPopularTab(BuildContext ctx) {
    return RefreshIndicator(
      onRefresh:       _onRefresh,
      color:           Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: Consumer(
        builder: (c, r, _) {
          final snap = r.watch(getPopularProvider(source: source, page: 1));
          return snap.when(
            data: (d) => _buildGrid(ctx, d?.list ?? []),
            loading: () => _buildShimmerGrid(),
            error:   (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: Colors.white60))),
          );
        },
      ),
    );
  }

  // ── Récents tab ────────────────────────────────────────────────────────────

  Widget _buildRecentsTab(BuildContext ctx) {
    return RefreshIndicator(
      onRefresh:       _onRefresh,
      color:           Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: Consumer(
        builder: (c, r, _) {
          final snap =
              r.watch(getLatestUpdatesProvider(source: source, page: 1));
          return snap.when(
            data: (d) {
              final items = d?.list ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text('Aucun résultat',
                      style: TextStyle(color: Colors.white60)),
                );
              }
              return ListView.builder(
                padding:   const EdgeInsets.fromLTRB(0, 8, 0, 120),
                itemCount: items.length,
                itemBuilder: (_, i) => _LatestUpdateTile(
                  manga:  items[i],
                  source: source,
                  onTap:  () {
                    if (_tryOpenReel(ctx, items[i], source)) return;
                    pushToMangaReaderDetail(
                      ref: ref, context: ctx, getManga: items[i],
                      lang: source.lang!, source: source.name!,
                      itemType: source.itemType, sourceId: source.id,
                    );
                  },
                ),
              );
            },
            loading: () => _buildShimmerList(),
            error:   (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: Colors.white60))),
          );
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding:   const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: 8,
      itemBuilder: (_, __) => _LatestUpdateTile.shimmer(),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildCategoryChips(
      BuildContext ctx, List<Map<String, dynamic>> cats) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.fromLTRB(14, 4, 14, 4),
        itemCount:       cats.length,
        itemBuilder: (_, i) {
          final cl       = cats[i];
          final listId   = cl['id']       as String;
          final listName = cl['name']     as String? ?? listId;
          final hexColor = cl['color']    as String? ?? '#1E2126';
          final extImg   = cl['imageUrl'] as String? ?? '';

          Color fallback;
          try {
            final h = hexColor.replaceAll('#', '');
            fallback = h.length == 6
                ? Color(int.parse('FF$h', radix: 16))
                : const Color(0xFF1E2126);
          } catch (_) {
            fallback = const Color(0xFF1E2126);
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => _WatchSectionPage(
                  source:       source,
                  title:        listName,
                  type:         _SectionKind.custom,
                  customListId: listId,
                ),
              )),
              child: Consumer(
                builder: (c, r, _) {
                  String bgUrl = extImg;
                  if (bgUrl.isEmpty) {
                    final snap = r.watch(getCustomListProvider(
                        source: source, listId: listId, page: 1));
                    bgUrl = snap.maybeWhen(
                      data: (d) => d?.list.firstOrNull?.imageUrl ?? '',
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
                          bgUrl.isNotEmpty
                              ? Image.network(bgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        ColoredBox(color: fallback))
                              : ColoredBox(color: fallback),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin:  Alignment.topLeft,
                                end:    Alignment.bottomRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.30),
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                listName,
                                style: const TextStyle(
                                  color:         Colors.white,
                                  fontSize:      13,
                                  fontWeight:    FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines:  2,
                                overflow:  TextOverflow.ellipsis,
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

  // ── Search view ────────────────────────────────────────────────────────────

  Widget _buildSearchView(BuildContext ctx) {
    final topPad = MediaQuery.paddingOf(ctx).top;

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        Container(
          color:   Colors.black,
          padding: EdgeInsets.only(top: topPad + 4, left: 8, right: 8, bottom: 8),
          child: Row(
            children: [
              // Back button — circular translucent backdrop
              NfCircleIconButton(
                icon:  Icons.arrow_back_rounded,
                onTap: () => setState(() {
                  _isSearching = false;
                  _query       = '';
                  _searchCtrl.clear();
                  _suggestions = [];
                  _mangaList.clear();
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller:  _searchCtrl,
                  autofocus:   true,
                  style:       const TextStyle(color: Colors.white),
                  decoration:  InputDecoration(
                    hintText:  _isListening
                        ? 'Je vous écoute…'
                        : 'Rechercher…',
                    hintStyle: TextStyle(
                        color: _isListening
                            ? Colors.redAccent.shade100
                            : Colors.white54),
                    border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   BorderSide.none,
                    ),
                    filled:      true,
                    fillColor:   Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              // Voice search mic
              NfCircleIconButton(
                icon: _isListening
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                onTap: _startVoiceSearch,
                size: 20,
              ),
            ],
          ),
        ),

        // ── Autocomplete suggestions ──────────────────────────────────────
        if (_suggestions.isNotEmpty)
          Container(
            color: const Color(0xFF0D0D0D),
            child: Column(
              children: _suggestions.map((title) => InkWell(
                onTap: () => _onSuggestionTap(title),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 16, color: Colors.white38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),

        // ── Results ──────────────────────────────────────────────────────
        Expanded(
          child: _query.isEmpty
              ? _buildPopularGrid(ctx)
              : _buildSearchResults(ctx),
        ),
      ],
    );
  }

  Widget _buildPopularGrid(BuildContext ctx) {
    return Consumer(
      builder: (c, r, _) {
        final pop = r.watch(getPopularProvider(source: source, page: 1));
        return pop.when(
          data: (d) => _buildGrid(ctx, d?.list ?? []),
          loading: () => _buildShimmerGrid(),
          error:   (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: Colors.white60))),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext ctx) {
    return Consumer(
      builder: (c, r, _) {
        if (_query.isEmpty) return const SizedBox.shrink();
        final snap = r.watch(
            searchProvider(source: source, query: _query, page: 1,
                filterList: const []));
        return snap.when(
          data: (d) {
            final items = d?.list ?? [];
            if (items.isEmpty) {
              return Center(
                child: Text(ctx.l10n.no_result,
                    style: const TextStyle(color: Colors.white60)),
              );
            }
            return _buildGrid(ctx, items);
          },
          loading: () => _buildShimmerGrid(),
          error:   (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: Colors.white60))),
        );
      },
    );
  }

  /// Shimmer grid for search/popular loading states — replaces plain spinner.
  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio:   0.65,
        mainAxisSpacing:    8,
        crossAxisSpacing:   8,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => _NfShimmerPosterTile(),
    );
  }

  Widget _buildGrid(BuildContext ctx, List<MManga> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio:   0.65,
        mainAxisSpacing:    8,
        crossAxisSpacing:   8,
      ),
      itemCount: items.length,
      itemBuilder: (c, i) => MangaImageCardWidget(
        getMangaDetail: items[i],
        source:         source,
        itemType:       source.itemType,
        isComfortableGrid: false,
      ),
    );
  }
}

// ── Hero banner spacer ─────────────────────────────────────────────────────────
// A transparent box that reserves the same vertical space as the pinned hero
// banner so the scrollable list starts below it.

class _HeroBannerSpacer extends ConsumerWidget {
  final Source                     source;
  final List<Map<String, dynamic>> customLists;

  const _HeroBannerSpacer({
    required this.source,
    required this.customLists,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final height = width + (width * .6);
    return SizedBox(width: width, height: height);
  }
}

// ── Hero banner section ────────────────────────────────────────────────────────
// Picks first item from 'banner' list, falls back to first popular item.

class _HeroBannerSection extends ConsumerWidget {
  final Source                 source;
  final List<Map<String, dynamic>> customLists;
  final double                 appBarH;
  final void Function(MManga)  onTap;

  const _HeroBannerSection({
    super.key,
    required this.source,
    required this.customLists,
    required this.appBarH,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerDef = customLists
        .where((cl) => cl['layout'] == 'banner' || cl['id'] == 'banner')
        .firstOrNull;

    if (bannerDef != null) {
      final data = ref.watch(getCustomListProvider(
          source: source,
          listId: bannerDef['id'] as String,
          page:   1));
      return data.when(
        data: (d) {
          final items = d?.list ?? [];
          if (items.isEmpty) return _buildFallback(context, ref);
          return _buildBanner(context, items.first);
        },
        loading: () => _buildShimmerHero(context),
        error:   (_, __) => _buildFallback(context, ref),
      );
    }
    return _buildFallback(context, ref);
  }

  Widget _buildFallback(BuildContext ctx, WidgetRef ref) {
    final pop = ref.watch(getPopularProvider(source: source, page: 1));
    return pop.when(
      data: (d) {
        final items = d?.list ?? [];
        if (items.isEmpty) return _buildShimmerHero(ctx);
        return _buildBanner(ctx, items.first);
      },
      loading: () => _buildShimmerHero(ctx),
      error:   (_, __) => _buildShimmerHero(ctx),
    );
  }

  Widget _buildBanner(BuildContext ctx, MManga manga) {
    return NfHighlightBanner(
      manga:      manga,
      onPlayTap:  () => onTap(manga),
      onMyListTap: () {},
    );
  }

  Widget _buildShimmerHero(BuildContext ctx) {
    final width = MediaQuery.of(ctx).size.width;
    return Skeletonizer(
      enabled: true,
      child: Container(
        color:  Colors.grey[900],
        width:  width,
        height: width + (width * .6),
      ),
    );
  }
}

// ── Horizontal content row ─────────────────────────────────────────────────────
// One section: title + SeeAllButton + horizontal ListView of NfMovieBox.

class _NfContentRow extends ConsumerWidget {
  final Source                 source;
  final String                 listId;
  final String                 title;
  final VoidCallback?          onSeeAll;
  final void Function(MManga)? onTapManga;

  const _NfContentRow({
    required this.source,
    required this.listId,
    required this.title,
    this.onSeeAll,
    this.onTapManga,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
        getCustomListProvider(source: source, listId: listId, page: 1));

    return data.when(
      data: (d) {
        final items = d?.list ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _buildRow(context, items);
      },
      loading: () => _buildShimmerRow(context),
      error:   (_, __) => _buildShimmerRow(context),
    );
  }

  Widget _buildRow(BuildContext ctx, List<MManga> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Item count badge
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    color:      Colors.white60,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (onSeeAll != null)
                SeeAllButton(
                  color: Colors.white70,
                  onTap: onSeeAll!,
                ),
            ],
          ),
        ),

        // Horizontal card list — exact flutter_netflix home.dart row height
        SizedBox(
          height: 200.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.only(left: 8, right: 8),
            itemCount:       items.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onTapManga?.call(items[i]),
              child: NfMovieBox(
                manga:  items[i],
                source: source,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerRow(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Skeletonizer(
            enabled: true,
            child: Container(
              width:  140, height: 16,
              decoration: BoxDecoration(
                color:        Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        _NfShimmerRow(),
      ],
    );
  }
}

// ── Shimmer loading row ────────────────────────────────────────────────────────

class _NfShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180.0,
      child: Skeletonizer(
        enabled: true,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics:         const NeverScrollableScrollPhysics(),
          padding:         const EdgeInsets.symmetric(horizontal: 8),
          children: List.generate(
            6,
            (_) => Container(
              width:  110,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color:        Colors.grey[900],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer new & hot placeholder ──────────────────────────────────────────────

class _NfShimmerNewHot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(color: Colors.black, width: width, height: width * 0.56),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width:  200, height: 18,
                    decoration: BoxDecoration(
                      color:        Colors.black,
                      borderRadius: BorderRadius.circular(4),
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
}

// ── Shimmer poster tile (catalogue & section-page loading cells) ───────────────

class _NfShimmerPosterTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ── Catalogue sliver section ───────────────────────────────────────────────────

class _CatalogueSection extends ConsumerWidget {
  final Source               source;
  final List<MManga>         items;
  final bool                 loading;
  final bool                 hasNext;
  final Map<String, dynamic>? catalogueList;
  final void Function(List<MManga> items, bool hasNext) onFirstLoad;

  const _CatalogueSection({
    required this.source,
    required this.items,
    required this.loading,
    required this.hasNext,
    required this.catalogueList,
    required this.onFirstLoad,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If catalogue items already loaded by parent, use them.
    if (items.isNotEmpty) return _buildGrid(context, items);

    // Initial load via provider — hand off to parent state
    final snap = catalogueList != null
        ? ref.watch(getCustomListProvider(
            source: source,
            listId: catalogueList!['id'] as String,
            page:   1))
        : ref.watch(getPopularProvider(source: source, page: 1));

    return snap.when(
      data: (d) {
        final list = d?.list ?? [];
        if (list.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onFirstLoad(list, d?.hasNextPage ?? false);
          });
          return _buildGrid(context, list);
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
      loading: () => SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio:   0.65,
          mainAxisSpacing:    8,
          crossAxisSpacing:   8,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => _NfShimmerPosterTile(),
          childCount: 12,
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildGrid(BuildContext ctx, List<MManga> list) {
    final all = items.isNotEmpty ? items : list;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio:   0.65,
        mainAxisSpacing:    8,
        crossAxisSpacing:   8,
      ),
      delegate: SliverChildBuilderDelegate(
        (c2, i) {
          if (i >= all.length) return _NfShimmerPosterTile();
          return MangaImageCardWidget(
            getMangaDetail:    all[i],
            source:            source,
            itemType:          source.itemType,
            isComfortableGrid: false,
          );
        },
        childCount: all.length + (loading ? 3 : 0),
      ),
    );
  }
}

// ── Reel helper ────────────────────────────────────────────────────────────────
// Returns true if reel navigation was handled (skip pushToMangaReaderDetail).

bool _tryOpenReel(BuildContext context, MManga manga, Source source) {
  final link = manga.link;
  if (link == null || !link.startsWith('{')) return false;
  try {
    final data = jsonDecode(link) as Map<String, dynamic>;
    if (data['type'] != 'reel') return false;
    context.pushNamed('reel', extra: {
      'source':      source,
      'listId':      (data['listId'] as String?) ?? 'trending',
      'startGifId':  data['gifId'] as String?,
    });
    return true;
  } catch (_) {
    return false;
  }
}

// ── Section kind ───────────────────────────────────────────────────────────────

enum _SectionKind { popular, latest, custom }

// ── Full-page section drill-down ───────────────────────────────────────────────

class _WatchSectionPage extends ConsumerStatefulWidget {
  final Source        source;
  final String        title;
  final _SectionKind  type;
  final String?       customListId;

  const _WatchSectionPage({
    required this.source,
    required this.title,
    required this.type,
    this.customListId,
  });

  @override
  ConsumerState<_WatchSectionPage> createState() => _WatchSectionPageState();
}

class _WatchSectionPageState extends ConsumerState<_WatchSectionPage> {
  final List<MManga> _items    = [];
  int  _page     = 1;
  bool _loading  = true;
  bool _hasNext  = true;
  Object? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 &&
          _hasNext && !_loading) {
        _loadPage();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (_loading && _items.isNotEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      MPages? result;
      switch (widget.type) {
        case _SectionKind.custom:
          result = await ref.read(getCustomListProvider(
            source: widget.source,
            listId: widget.customListId!,
            page:   _page,
          ).future);
          break;
        case _SectionKind.popular:
          result = await ref.read(
              getPopularProvider(source: widget.source, page: _page).future);
          break;
        case _SectionKind.latest:
          result = await ref.read(
              getLatestUpdatesProvider(source: widget.source, page: _page).future);
          break;
      }
      if (!mounted) return;
      setState(() {
        _items.addAll(result?.list ?? []);
        _hasNext = result?.hasNextPage ?? false;
        _page++;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Scaffold(
      backgroundColor: nfBackgroundColor,
      // ── Redesigned header: pill title + filter icon ──────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                NfCircleIconButton(
                  icon:  Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                  size:  20,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                NfCircleIconButton(
                  icon:  Icons.tune_rounded,
                  onTap: () {},
                  size:  20,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _items.isEmpty && _loading
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio:   0.65,
                mainAxisSpacing:    8,
                crossAxisSpacing:   8,
              ),
              itemCount: 12,
              itemBuilder: (_, __) => _NfShimmerPosterTile(),
            )
          : _items.isEmpty && _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error.toString(),
                          style: const TextStyle(color: Colors.white60)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadPage,
                          child: const Text('Réessayer')),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    childAspectRatio:   0.65,
                    mainAxisSpacing:    8,
                    crossAxisSpacing:   8,
                  ),
                  itemCount: _items.length + (_loading ? 3 : 0),
                  itemBuilder: (c, i) {
                    if (i >= _items.length) return _NfShimmerPosterTile();
                    return MangaImageCardWidget(
                      getMangaDetail:    _items[i],
                      source:            widget.source,
                      itemType:          widget.source.itemType,
                      isComfortableGrid: false,
                    );
                  },
                ),
    );
  }
}

// ── Aidoku pill tab bar delegate ───────────────────────────────────────────────

class _PillTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController         tabController;
  final List<String>          tabs;

  const _PillTabBarDelegate({
    required this.tabController,
    required this.tabs,
  });

  static const double _h = 46.0;

  @override double get minExtent => _h;
  @override double get maxExtent => _h;

  @override
  bool shouldRebuild(_PillTabBarDelegate old) =>
      old.tabController != tabController || old.tabs != tabs;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs    = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return Container(
      height:     _h,
      color:      nfBackgroundColor,
      alignment:  Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = tabController.index == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => tabController.animateTo(i),
                child: AnimatedContainer(
                  duration:    const Duration(milliseconds: 180),
                  padding:     const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color:        selected
                        ? accent
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color:      selected ? Colors.white : Colors.white70,
                      fontSize:   13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Aidoku section header ──────────────────────────────────────────────────────

class _AidokuSectionHeader extends StatelessWidget {
  final String       title;
  final bool         hasArrow;
  final VoidCallback? onArrow;

  const _AidokuSectionHeader({
    required this.title,
    this.hasArrow  = false,
    this.onArrow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (hasArrow && onArrow != null)
            GestureDetector(
              onTap: onArrow,
              child: Container(
                width:  32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                  size:  20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Popular big card carousel ──────────────────────────────────────────────────

class _PopularBigCarousel extends ConsumerWidget {
  final Source                 source;
  final void Function(MManga)? onTap;

  const _PopularBigCarousel({
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(getPopularProvider(source: source, page: 1));
    return snap.when(
      data: (d) {
        final items = d?.list ?? [];
        if (items.isEmpty) return _shimmer(context);
        return SizedBox(
          height: 208,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.symmetric(horizontal: 12),
            itemCount:       items.length,
            itemBuilder:     (_, i) => _PopularBigCard(
              manga:  items[i],
              source: source,
              onTap:  () => onTap?.call(items[i]),
            ),
          ),
        );
      },
      loading: () => _shimmer(context),
      error:   (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _shimmer(BuildContext context) {
    return SizedBox(
      height: 208,
      child: Skeletonizer(
        enabled: true,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 12),
          physics:         const NeverScrollableScrollPhysics(),
          children: List.generate(
            4,
            (_) => Container(
              width:  290,
              height: 192,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color:        Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Popular big card ───────────────────────────────────────────────────────────

class _PopularBigCard extends StatelessWidget {
  final MManga        manga;
  final Source        source;
  final VoidCallback? onTap;

  const _PopularBigCard({
    required this.manga,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const coverW = 113.0;
    const coverH = 170.0;

    final genres = manga.genre ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  290,
        height: 192,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color:        const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width:  coverW,
                height: double.infinity,
                child: manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                    ? Image.network(
                        manga.imageUrl!,
                        fit:          BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderCover(),
                      )
                    : _placeholderCover(),
              ),
            ),

            // ── Text content ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      manga.name ?? '—',
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        height:     1.25,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Description
                    Expanded(
                      child: Text(
                        manga.description ?? '',
                        maxLines:  4,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:    Colors.white54,
                          fontSize: 11.5,
                          height:   1.4,
                        ),
                      ),
                    ),

                    // Genre chips
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 22,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: genres.take(3).map((g) {
                            return Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:        Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  color:    Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 32),
      ),
    );
  }
}

// ── Latest updates sliver ──────────────────────────────────────────────────────

class _LatestUpdatesSliver extends ConsumerWidget {
  final Source                 source;
  final void Function(MManga)? onTap;

  const _LatestUpdatesSliver({
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    return snap.when(
      data: (d) {
        final items = (d?.list ?? []).take(8).toList();
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _LatestUpdateTile(
              manga:  items[i],
              source: source,
              onTap:  () => onTap?.call(items[i]),
            ),
            childCount: items.length,
          ),
        );
      },
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => _LatestUpdateTile.shimmer(),
          childCount: 5,
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Latest update tile ─────────────────────────────────────────────────────────

class _LatestUpdateTile extends StatelessWidget {
  final MManga?       manga;
  final Source?       source;
  final VoidCallback? onTap;
  final bool          _isShimmer;

  // ignore: use_super_parameters
  const _LatestUpdateTile({
    required MManga manga,
    required Source source,
    this.onTap,
  }) : manga      = manga,
       source     = source,
       _isShimmer = false;

  const _LatestUpdateTile.shimmer()
      : manga      = null,
        source     = null,
        onTap      = null,
        _isShimmer = true;

  @override
  Widget build(BuildContext context) {
    if (_isShimmer) {
      return Skeletonizer(
        enabled: true,
        child: _buildTileContent(
          imageUrl:    null,
          title:       '████████████',
          subtitle:    'Chapter 42 • 2h',
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: _buildTileContent(
        imageUrl: manga?.imageUrl,
        title:    manga?.name ?? '—',
        subtitle: '',
      ),
    );
  }

  Widget _buildTileContent({
    required String?  imageUrl,
    required String   title,
    required String   subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width:  56,
              height: 80,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit:          BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    height:     1.3,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:    Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Arrow
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size:  18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 18),
      ),
    );
  }
}

// ── View-toggle button (filter sheet) ─────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final IconData  icon;
  final bool      selected;
  final VoidCallback onTap;

  const _ViewToggleBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon,
            size:  18,
            color: selected
                ? Colors.white
                : cs.onSurface.withValues(alpha: 0.55)),
      ),
    );
  }
}
