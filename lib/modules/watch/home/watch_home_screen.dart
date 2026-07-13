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

class _WatchHomeScreenState extends ConsumerState<WatchHomeScreen> {
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
    _loadLayout();
    _initSpeech();
  }

  @override

  void dispose() {
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
                child: _buildNetflixHome(context)),
      ),
    );
  }

  // ── Netflix home view ──────────────────────────────────────────────────────

  Widget _buildNetflixHome(BuildContext ctx) {
    // Partition custom lists
    final categoryLists = _customLists
        .where((cl) => cl['layout'] == 'category')
        .toList();
    final regularLists = _customLists
        .where((cl) =>
            cl['id'] != 'carousel' &&
            cl['layout'] != 'category' &&
            cl['id'] != 'catalogue' &&
            cl['layout'] != '__tab__')
        .toList();
    final newHotLists = regularLists
        .where((cl) => (cl['layout'] as String? ?? '') == 'new_hot')
        .toList();

    // De-duplicate content rows by display title
    final seenTitles = <String>{};
    final contentLists = regularLists
        .where((cl) => (cl['layout'] as String? ?? '') != 'new_hot')
        .where((cl) {
          final title = (cl['name'] as String? ?? cl['id'] as String).trim();
          return seenTitles.add(title);
        })
        .toList();

    final catalogueList =
        _customLists.where((cl) => cl['id'] == 'catalogue').firstOrNull;

    // ── Hero banner is pinned above the scroll area so it never scrolls away
    // during pull-to-refresh.
    return Stack(
      children: [
        // ── Pinned hero banner (does NOT scroll) ───────────────────────────
        Positioned(
          top:   0,
          left:  0,
          right: 0,
          child: _HeroBannerSection(
            key:         ValueKey('hero_$_refreshKey'),
            source:      source,
            customLists: _customLists,
            appBarH:     _appBarH,
            onTap: (manga) {
              if (_tryOpenReel(ctx, manga, source)) return;
              pushToMangaReaderDetail(
                ref:      ref, context: ctx, getManga: manga,
                lang:     source.lang!, source: source.name!,
                itemType: source.itemType, sourceId: source.id,
              );
            },
          ),
        ),

        // ── Scrollable content (with pull-to-refresh) ──────────────────────
        RefreshIndicator(
          onRefresh:       _onRefresh,
          color:           Colors.white,
          backgroundColor: const Color(0xFF1A1A1A),
          // displacement pushes the spinner below status bar
          displacement:    _appBarH + 8,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification ||
                  n is ScrollEndNotification) {
                final px = n.metrics.pixels;
                if ((px - _scrollOffset).abs() > 0.5) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _scrollOffset = px);
                  });
                }
                if (px >= n.metrics.maxScrollExtent - 400 &&
                    _catalogueHasNext &&
                    !_catalogueLoading) {
                  _loadCatalogue();
                }
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics:    const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics()),
              slivers: [
                // ── Spacer that matches hero banner height ────────────────
                // (hero is pinned in Stack above, scrollable area starts below)
                SliverToBoxAdapter(
                  child: _HeroBannerSpacer(
                    source:     source,
                    customLists: _customLists,
                  ),
                ),

                // ── Category chips ────────────────────────────────────────
                if (categoryLists.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(ctx, categoryLists),
                  ),

                // ── Content rows (spotlight / ranked / compact) ───────────
                ...contentLists.map((cl) => SliverToBoxAdapter(
                  child: _NfContentRow(
                    source:  source,
                    listId:  cl['id'] as String,
                    title:   cl['name'] as String? ?? cl['id'] as String,
                    onSeeAll: () => Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => _WatchSectionPage(
                        source:       source,
                        title:        cl['name'] as String? ?? '',
                        type:         _SectionKind.custom,
                        customListId: cl['id'] as String,
                      ),
                    )),
                    onTapManga: (manga) {
                      if (_tryOpenReel(ctx, manga, source)) return;
                      pushToMangaReaderDetail(
                        ref: ref, context: ctx, getManga: manga,
                        lang: source.lang!, source: source.name!,
                        itemType: source.itemType, sourceId: source.id,
                      );
                    },
                  ),
                )),

                // ── New & Hot section ─────────────────────────────────────
                if (newHotLists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          const Text('Nouveau & Populaire',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   18,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          SeeAllButton(
                            color: Colors.white70,
                            onTap: () => Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => _WatchSectionPage(
                                  source:       source,
                                  title:        'Nouveau & Populaire',
                                  type:         _SectionKind.custom,
                                  customListId: newHotLists.first['id'] as String,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...newHotLists.expand((cl) => [
                    SliverToBoxAdapter(
                      child: Consumer(builder: (c, r, _) {
                        final data = r.watch(getCustomListProvider(
                            source: source,
                            listId: cl['id'] as String,
                            page:   1));
                        return data.when(
                          data: (d) {
                            final items = d?.list ?? [];
                            if (items.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: items.take(5).map((m) =>
                                NfNewAndHotTile(manga: m, source: source),
                              ).toList(),
                            );
                          },
                          loading: () => _NfShimmerNewHot(),
                          error:   (_, __) => const SizedBox.shrink(),
                        );
                      }),
                    ),
                  ]),
                ],

                // ── Catalogue header ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        const Text('Catalogue',
                            style: TextStyle(
                                color:      Colors.white,
                                fontSize:   18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        SeeAllButton(
                          color: Colors.white70,
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute(
                              builder: (_) => _WatchSectionPage(
                                source:       source,
                                title:        'Catalogue',
                                type:         catalogueList != null
                                    ? _SectionKind.custom
                                    : _SectionKind.popular,
                                customListId: catalogueList?['id'] as String?,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Catalogue grid ────────────────────────────────────────
                _CatalogueSection(
                  source:         source,
                  items:          _catalogueItems,
                  loading:        _catalogueLoading,
                  hasNext:        _catalogueHasNext,
                  catalogueList:  catalogueList,
                  onFirstLoad: (items, hasNext) {
                    if (mounted && _catalogueItems.isEmpty) {
                      setState(() {
                        _catalogueItems.addAll(items);
                        _cataloguePage    = 2;
                        _catalogueHasNext = hasNext;
                      });
                    }
                  },
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),

        // ── Floating app bar overlay ────────────────────────────────────
        Positioned(
          top:   0,
          left:  0,
          right: 0,
          child: NfWatchAppBarWidget(
            scrollOffset: _scrollOffset,
            sourceName:   source.name ?? source.lang ?? 'Anime',
            onSearchTap:  () => setState(() => _isSearching = true),
            canPop:       context.canPop(),
            onBackTap:    () => context.pop(),
          ),
        ),
      ],
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
