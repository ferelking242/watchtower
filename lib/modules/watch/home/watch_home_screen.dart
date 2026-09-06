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
import 'package:isar_community/isar.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:extended_image/extended_image.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
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
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'nf_widgets/nf_app_bar.dart';
import 'nf_widgets/nf_highlight_banner.dart';
import 'nf_widgets/nf_menu_panel.dart';
import 'nf_widgets/nf_movie_box.dart';
import 'nf_widgets/nf_new_and_hot_tile.dart';
import 'nf_widgets/nf_poster_image.dart';
import 'nf_widgets/nf_utils.dart';
import 'nf_widgets/nf_watch_history_row.dart';
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

  // ── Search view state ──────────────────────────────────────────────────
  bool   _isSearching  = false;
  String _query        = '';

  // ── Sidebar menu (hamburger, right edge) ────────────────────────────────
  bool _menuOpen = false;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Search / suggestions ──────────────────────────────────────────────────
  // _query        → live text in the field (drives debounced suggestions)
  // _committedQuery → query actually submitted (drives the results grid)
  Timer? _suggestionTimer;
  List<MManga> _suggestions = [];
  String _committedQuery = '';

  // ── Search content-type tabs ───────────────────────────────────────────────
  // Tabs come from the extension manifest (contentSubtype: movie/series/reel…).
  // null = "Tout" — no type filter sent to the extension.
  String? _selectedType;

  // ── Voice search ──────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening     = false;

  // ── Scroll offset (drives app bar scrim — NO setState, see app bar) ────────
  final ValueNotifier<double> _scrollOffsetNotifier =
      ValueNotifier<double>(0);

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
    _loadLayout();
    _initSpeech();
  }

  @override

  void dispose() {
    _suggestionTimer?.cancel();
    _speech.stop();
    _scrollOffsetNotifier.dispose();
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
          _searchCtrl.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );
          _onQueryChanged(words);
        }
      },
      listenFor:         const Duration(seconds: 10),
      pauseFor:          const Duration(seconds: 3),
      localeId:          'fr_FR',
    );
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

  // ── Search ────────────────────────────────────────────────────────────────

  /// Live typing → debounced suggestions only (fast). Results are committed
  /// on keyboard "search" action or suggestion tap — no lag while typing.
  void _onQueryChanged(String q) {
    _suggestionTimer?.cancel();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _suggestions    = [];
        _committedQuery = '';
      }
    });
    if (q.trim().isEmpty) return;

    _suggestionTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final snap = await ref.read(searchProvider(
          source: source, query: q.trim(), page: 1, filterList: const [],
        ).future);
        if (!mounted) return;
        // Stale-response guard — the user may have kept typing.
        if (_searchCtrl.text.trim() != q.trim()) return;
        final items = (snap?.list ?? [])
            .where((m) => (m.name ?? '').isNotEmpty)
            .toList();
        // Dedupe by title, keep order, max 5.
        final seen = <String>{};
        final suggestions =
            items.where((m) => seen.add(m.name!)).take(5).toList();
        setState(() => _suggestions = suggestions);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  /// Commits a query: closes the keyboard, hides suggestions, runs the search.
  void _commitSearch(String q) {
    _suggestionTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _query          = q;
      _committedQuery = q.trim();
      _suggestions    = [];
    });
  }

  /// Content types declared by this extension (movie / series / reel …).
  List<String> get _contentTypes => source.contentSubtype ?? const [];

  /// Filter payload sent to the extension when a type tab is active.
  /// Extensions that support filters receive a SelectFilter whose value is the
  /// raw subtype string; unsupported extensions simply ignore it.
  /// Memoized: Riverpod families key providers by argument identity, so a
  /// freshly-built list per call would re-create the provider every rebuild.
  List<dynamic> _searchFiltersCache = const [];
  String? _searchFiltersKey;

  List<dynamic> get _searchFilters {
    if (_searchFiltersKey != _selectedType) {
      final type = _selectedType;
      _searchFiltersKey = _selectedType;
      _searchFiltersCache = (type != null && _contentTypes.contains(type))
          ? [
              SelectFilter(
                'content_type',
                'Type',
                _contentTypes.indexOf(type),
                _contentTypes
                    .map((t) => SelectFilterOption(t.capitalize(), t, null))
                    .toList(),
                null,
              ),
            ]
          : const [];
    }
    return _searchFiltersCache;
  }

  void _onTypeTabTap(String? type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    // Re-run the current query under the new type filter.
    if (_committedQuery.isNotEmpty) {
      ref.invalidate(searchProvider(
        source:     source,
        query:      _committedQuery,
        page:       1,
        filterList: _searchFilters,
      ));
    }
  }

  void _onSuggestionTap(MManga manga) {
    final title = manga.name ?? '';
    if (title.isEmpty) return;
    _searchCtrl.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
    _commitSearch(title);
  }

  void _clearSearch() {
    _suggestionTimer?.cancel();
    setState(() {
      _query          = '';
      _committedQuery = '';
      _suggestions    = [];
    });
    _searchCtrl.clear();
  }

  // ── Sidebar menu ────────────────────────────────────────────────────────────

  void _openMenu() {
    HapticFeedback.selectionClick();
    if (!_menuOpen) setState(() => _menuOpen = true);
  }

  void _closeMenu() {
    if (_menuOpen) setState(() => _menuOpen = false);
  }

  void _openSourcePicker() {
    showModalBottomSheet<Source>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchSourcePickerSheet(current: source),
    ).then((next) {
      if (!mounted || next == null || next.id == source.id) return;
      isar.writeTxnSync(() {
        final sources = isar.sources
            .filter()
            .idIsNotNull()
            .itemTypeEqualTo(source.itemType)
            .findAllSync();
        for (final candidate in sources) {
          isar.sources.putSync(candidate
            ..lastUsed = candidate.id == next.id
            ..updatedAt = DateTime.now().millisecondsSinceEpoch);
        }
      });
      context.pushReplacement('/watchHome', extra: (next, false));
    });
  }

  void _menuGoHome() {
    _closeMenu();
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve:    Curves.easeOutCubic,
      );
    }
  }

  /// Search lives inside the menu → full-page search view (same one the old
  /// top-right magnifier opened).
  void _menuOpenSearch() {
    _suggestionTimer?.cancel();
    setState(() {
      _menuOpen       = false;
      _isSearching    = true;
      _query          = '';
      _committedQuery = '';
      _suggestions    = [];
      _selectedType   = null;
    });
    _searchCtrl.clear();
  }

  void _menuOpenSection({
    required String      title,
    required _SectionKind kind,
    String?              customListId,
  }) {
    _closeMenu();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _WatchSectionPage(
        source:       source,
        title:        title,
        type:         kind,
        customListId: customListId,
      ),
    ));
  }

  void _menuOpenCategories(List<Map<String, dynamic>> cats) {
    _closeMenu();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CategoryGridPage(source: source, categories: cats),
    ));
  }

  /// Builds the ordered list of menu groups from the extension's home layout:
  /// Explorer (Accueil / Recherche / Catégories) → playlists (each content
  /// row) → Nouveau & Populaire → Catalogue.
  List<NfMenuGroup> _menuGroups() {
    final cats = _customLists
        .where((cl) => cl['layout'] == 'category')
        .toList();
    final regulars = _customLists
        .where((cl) =>
            cl['id'] != 'carousel' &&
            cl['layout'] != 'category' &&
            cl['id'] != 'catalogue' &&
            cl['layout'] != '__tab__')
        .toList();
    final newHot = regulars
        .where((cl) => (cl['layout'] as String? ?? '') == 'new_hot')
        .toList();
    final seenTitles = <String>{};
    final rows = regulars
        .where((cl) => (cl['layout'] as String? ?? '') != 'new_hot')
        .where((cl) => seenTitles
            .add((cl['name'] as String? ?? cl['id'] as String).trim()))
        .toList();
    final catalogueList =
        _customLists.where((cl) => cl['id'] == 'catalogue').firstOrNull;
    final hasCustomHistory =
        _customLists.any((cl) => cl['id'] == 'history');
    final hasCustomHistory =
        _customLists.any((cl) => cl['id'] == 'history');

    final groups = <NfMenuGroup>[];

    final explorer = <NfMenuTile>[
      NfMenuTile(
        icon:  Broken.home_1,
        label: 'Accueil',
        onTap: _menuGoHome,
      ),
      NfMenuTile(
        icon:  Broken.search_normal_1,
        label: 'Recherche',
        onTap: _menuOpenSearch,
        accent: true,
      ),
    ];
    if (cats.isNotEmpty) {
      explorer.add(NfMenuTile(
        icon:  Broken.category_2,
        label: 'Catégories',
        onTap: () => _menuOpenCategories(cats),
      ));
    }
    groups.add(NfMenuGroup(title: 'Explorer', tiles: explorer));

    final playlists = <NfMenuTile>[
      for (final row in rows)
        NfMenuTile(
          icon:  Broken.play_circle,
          label: row['name'] as String? ?? row['id'] as String,
          onTap: () => _menuOpenSection(
            title:        row['name'] as String? ?? row['id'] as String,
            kind:         _SectionKind.custom,
            customListId: row['id'] as String,
          ),
        ),
    ];
    if (newHot.isNotEmpty) {
      playlists.add(NfMenuTile(
        icon:  Broken.diamonds,
        label: 'Nouveau & Populaire',
        onTap: () => _menuOpenSection(
          title:        'Nouveau & Populaire',
          kind:         _SectionKind.custom,
          customListId: newHot.first['id'] as String,
        ),
      ));
    }
    if (playlists.isNotEmpty) {
      groups.add(NfMenuGroup(title: 'Playlists', tiles: playlists));
    }

    groups.add(NfMenuGroup(
      title: 'Catalogue',
      tiles: [
        NfMenuTile(
          icon:  Broken.grid_1,
          label: 'Tout le catalogue',
          onTap: () => _menuOpenSection(
            title:        'Catalogue',
            kind:         catalogueList != null
                ? _SectionKind.custom
                : _SectionKind.popular,
            customListId: catalogueList?['id'] as String?,
          ),
        ),
      ],
    ));

    return groups;
  }

  /// Right-edge menu overlay: dim barrier + frosted panel that slides in.
  Widget _buildMenuOverlay() {
    final screenW = MediaQuery.sizeOf(context).width;
    final panelW = (screenW * 0.86).clamp(280.0, 372.0).toDouble();

    return IgnorePointer(
      ignoring: !_menuOpen,
      child: Stack(
        fit:        StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Dim barrier ────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _menuOpen ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve:    Curves.easeOut,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:    _closeMenu,
              child:    ColoredBox(
                  color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          // ── Panel ──────────────────────────────────────────────────────
          Positioned(
            top:    0,
            bottom: 0,
            right:  0,
            width:  panelW,
            child: AnimatedSlide(
              offset:  _menuOpen ? Offset.zero : const Offset(1, 0),
              duration: const Duration(milliseconds: 320),
              curve:    Curves.easeOutCubic,
              child: NfWatchMenuPanel(
                source:  source,
                groups:  _menuGroups(),
                onClose: _closeMenu,
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    _appBarH = topPad + kToolbarHeight;

    // While the sidebar menu is open the system back gesture only closes the
    // menu instead of popping the whole extension screen.
    return PopScope(
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _menuOpen) _closeMenu();
      },
      child: Scaffold(
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
            cl['layout'] != 'banner' &&
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

    // ── Everything scrolls in ONE CustomScrollView: the hero is the first
    // sliver, so content can never overlap it (fixes items-over-carousel)
    // and it scrolls away naturally, Netflix / Disney+ style.
    return Stack(
      children: [
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
                // ValueNotifier only — no setState per scroll frame (jank fix).
                if ((px - _scrollOffsetNotifier.value).abs() > 0.5) {
                  _scrollOffsetNotifier.value = px;
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
                // ── Hero carousel (first sliver — scrolls with content) ───
                SliverToBoxAdapter(
                  child: _HeroSection(
                    key: ValueKey('hero_$_refreshKey'),
                    source:      source,
                    customLists: _customLists,
                    onTapManga: (manga) {
                      if (_tryOpenReel(ctx, manga, source)) return;
                      pushToMangaReaderDetail(
                        ref: ref, context: ctx, getManga: manga,
                        lang: source.lang!, source: source.name!,
                        itemType: source.itemType, sourceId: source.id,
                      );
                    },
                  ),
                ),

                // Keep the built-in continue-watching row only when the
                // extension has not declared its own history section.
                if (!hasCustomHistory)
                  SliverToBoxAdapter(
                      child: NfWatchHistoryRow(source: source)),

                // ── Category widgets ──────────────────────────────────────
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
                    component: cl['component'] as String? ??
                        cl['layout'] as String? ??
                        'spotlight',
                    columns: cl['columns'] as int?,
                    cardStyle: cl['cardStyle'] as String?,
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

                // ── Catalogue header — golden-leaf divider + ALL at right ─
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 16, 14),
                    child: Row(
                      children: [
                        const Expanded(child: _GoldenDivider()),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFFF6E27A),
                                Color(0xFFCBA135),
                                Color(0xFFF6E27A),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'CATALOGUE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(child: _GoldenDivider()),
                        const SizedBox(width: 12),
                        SeeAllButton(
                          color: const Color(0xFFCBA135),
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
            scrollOffsetNotifier: _scrollOffsetNotifier,
            sourceName:   source.name ?? source.lang ?? 'Anime',
            sourceIconUrl: source.iconUrl,
            onSourceTap:  _openSourcePicker,
            onMenuTap:    _openMenu,
            canPop:       context.canPop(),
            onBackTap:    () => context.pop(),
          ),
        ),

        // ── Sidebar menu (hamburger) overlay ─────────────────────────────
        Positioned.fill(child: _buildMenuOverlay()),
      ],
    );
  }  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildCategoryChips(
      BuildContext ctx, List<Map<String, dynamic>> cats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — title + ALL (opens the 2-column category grid).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Row(
            children: [
              const Text(
                'Catégories',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SeeAllButton(
                color: Colors.white70,
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _CategoryGridPage(
                    source: source,
                    categories: cats,
                  ),
                )),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.fromLTRB(14, 4, 14, 8),
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
                padding: const EdgeInsets.only(right: 10),
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
                       return _CategoryCard(
                         name: listName,
                         imageUrl: bgUrl,
                         fallback: fallback,
                         width: 182,
                         height: 104,
                       );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Search view ────────────────────────────────────────────────────────────

  Widget _buildSearchView(BuildContext ctx) {
    final topPad = MediaQuery.paddingOf(ctx).top;
    final hasText = _query.trim().isNotEmpty;

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        Container(
          color:   Colors.black,
          padding: EdgeInsets.only(top: topPad + 4, left: 8, right: 8, bottom: 8),
          child: Row(
            children: [
              // Back — chevron "<" like every other screen
              NfCircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 20,
                onTap: () {
                  _suggestionTimer?.cancel();
                  setState(() {
                    _isSearching    = false;
                    _query          = '';
                    _committedQuery = '';
                    _suggestions    = [];
                  });
                  _searchCtrl.clear();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller:      _searchCtrl,
                  autofocus:       true,
                  style:           const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted:     (_) => _commitSearch(_query),
                  decoration:  InputDecoration(
                    hintText:  _isListening
                        ? 'Je vous écoute…'
                        : 'Rechercher…',
                    hintStyle: TextStyle(
                        color: _isListening
                            ? Colors.redAccent.shade100
                            : Colors.white54),
                    border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:   BorderSide.none,
                    ),
                    filled:      true,
                    fillColor:   Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    // Right side of the field: mic when empty, X once typing.
                    suffixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _isListening
                          ? IconButton(
                              key: const ValueKey('stop'),
                              icon: const Icon(Icons.stop_rounded,
                                  size: 22, color: Colors.redAccent),
                              onPressed: _startVoiceSearch,
                            )
                          : hasText
                              ? IconButton(
                                  key: const ValueKey('clear'),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20, color: Colors.white70),
                                  onPressed: _clearSearch,
                                )
                              : IconButton(
                                  key: const ValueKey('mic'),
                                  icon: Icon(
                                      _speechAvailable
                                          ? Icons.mic_none_rounded
                                          : Icons.mic_off_outlined,
                                      size: 21,
                                      color: Colors.white70),
                                  onPressed: _startVoiceSearch,
                                ),
                    ),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // ── Content-type tabs (movie / series / reel … from the ext) ──────
        if (_contentTypes.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:         const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                _SearchTypeTab(
                  label:    'Tout',
                  selected: _selectedType == null,
                  onTap:    () => _onTypeTabTap(null),
                ),
                for (final t in _contentTypes)
                  _SearchTypeTab(
                    label:    t.capitalize(),
                    selected: _selectedType == t,
                    onTap:    () => _onTypeTabTap(t),
                  ),
              ],
            ),
          ),

        // ── Results + floating suggestions overlay ────────────────────
        Expanded(
          child: Stack(
            children: [
              // Results grid (behind)
              Positioned.fill(
                child: _committedQuery.isEmpty
                    ? _buildPopularGrid(ctx)
                    : _buildSearchResults(ctx),
              ),

              // Suggestions — clean dropdown box attached under the field.
              if (_suggestions.isNotEmpty)
                Positioned(
                  top: 6,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: const Color(0xFF161616),
                    elevation: 14,
                    shadowColor: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 5 * 58),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding:    EdgeInsets.zero,
                            itemCount:  _suggestions.length,
                            itemBuilder: (_, i) {
                              final m = _suggestions[i];
                              return InkWell(
                                onTap: () => _onSuggestionTap(m),
                                child: Container(
                                  height: 58,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: i == _suggestions.length - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: Colors.white
                                                  .withValues(alpha: 0.06)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(5),
                                        child: ExtendedImage.network(
                                          m.imageUrl ?? '',
                                          width:    32,
                                          height:   46,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          m.name ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const Icon(
                                          Icons.north_west_rounded,
                                          size: 15,
                                          color: Colors.white30),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
        if (_committedQuery.isEmpty) return const SizedBox.shrink();
        final snap = r.watch(
            searchProvider(source: source, query: _committedQuery, page: 1,
                filterList: _searchFilters));
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
// ── Hero section ────────────────────────────────────────────────────────────
// Watches the 'banner' custom list (falls back to popular), feeds the first
// few items to the auto-rotating NfHeroCarousel. Lives INSIDE the scroll view.

class _HeroSection extends ConsumerWidget {
  final Source                     source;
  final List<Map<String, dynamic>> customLists;
  final void Function(MManga)      onTapManga;

  const _HeroSection({
    super.key,
    required this.source,
    required this.customLists,
    required this.onTapManga,
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
          return _buildCarousel(items);
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
        return _buildCarousel(items);
      },
      loading: () => _buildShimmerHero(ctx),
      error:   (_, __) => _buildShimmerHero(ctx),
    );
  }

  Widget _buildCarousel(List<MManga> items) {
    return NfHeroCarousel(
      items:     items.take(5).toList(),
      source:    source,
      onTapManga: onTapManga,
    );
  }

  Widget _buildShimmerHero(BuildContext ctx) {
    return NfHeroShimmerPlaceholder(
      width:  MediaQuery.of(ctx).size.width,
      height: heroCarouselHeight(ctx),
    );
  }
}

// ── Hero loading placeholder ─────────────────────────────────────────────────
// Pure shimmer matching the carousel frame — no logo, no icon: the content
// rows below also shimmer so the whole screen reads as one loading skeleton.

class NfHeroShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const NfHeroShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        width:  width,
        height: height,
        color:  Colors.grey[900],
      ),
    );
  }
}

// ── Horizontal content row ───────────────────────────────────────────────────
// One section: title + SeeAllButton + horizontal ListView of NfMovieBox.

class _NfContentRow extends ConsumerWidget {
  final Source                 source;
  final String                 listId;
  final String                 title;
  final String                 component;
  final int?                   columns;
  final String?                cardStyle;
  final VoidCallback?          onSeeAll;
  final void Function(MManga)? onTapManga;

  const _NfContentRow({
    required this.source,
    required this.listId,
    required this.title,
    this.component = 'spotlight',
    this.columns,
    this.cardStyle,
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
        if (component == 'masonry') {
          return _NfMasonryRow(
            title: title,
            items: items,
            columns: columns ?? 2,
            cardStyle: cardStyle,
            onSeeAll: onSeeAll,
            onTapManga: onTapManga,
          );
        }
        if (component == 'grid' || component == 'catalogue') {
          return _NfInlineGrid(
            title: title,
            items: items,
            columns: columns ?? 3,
            source: source,
            onSeeAll: onSeeAll,
            onTapManga: onTapManga,
          );
        }
        if (component == 'ranked') {
          return _NfRankedRow(
            title: title,
            items: items,
            source: source,
            onSeeAll: onSeeAll,
            onTapManga: onTapManga,
          );
        }
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
              const Spacer(),
              if (onSeeAll != null)
                SeeAllButton(
                  color: Colors.white70,
                  onTap: onSeeAll!,
                ),
            ],
          ),
        ),

         // The JSON chooses the presentation: compact rows stay dense while
         // spotlight/carousel rows get larger cards.
        SizedBox(
           height: component == 'compact' ? 166.0 : 220.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.only(left: 8, right: 8),
            itemCount:       items.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onTapManga?.call(items[i]),
               child: NfMovieBox(
                manga:  items[i],
                source: source,
                 compact: component == 'compact',
                 cardStyle: cardStyle,
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

/// Declarative masonry presentation used by layouts such as XNXX Tags.
/// It deliberately has no extension-specific drawing logic: the JSON selects
/// the component and the generic card only consumes MManga data.
class _NfMasonryRow extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final int columns;
  final String? cardStyle;
  final VoidCallback? onSeeAll;
  final void Function(MManga)? onTapManga;

  const _NfMasonryRow({
    required this.title,
    required this.items,
    required this.columns,
    required this.cardStyle,
    required this.onSeeAll,
    required this.onTapManga,
  });

  @override
  Widget build(BuildContext context) {
    final count = columns.clamp(2, 3).toInt();
    final buckets = List.generate(count, (_) => <MManga>[]);
    for (var i = 0; i < items.length; i++) {
      buckets[i % count].add(items[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 4, 8),
          child: Row(
            children: [
              Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
              )),
              const Spacer(),
              if (onSeeAll != null)
                SeeAllButton(color: Colors.white70, onTap: onSeeAll!),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < count; column++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: column == 0 ? 0 : 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < buckets[column].length; i++)
                          _NfMasonryCard(
                            manga: buckets[column][i],
                            height: 82.0 + ((i + column) % 3) * 24.0,
                            accent: cardStyle == 'tag'
                                ? const Color(0xFF00B8D4)
                                : nfRedColor,
                            onTap: () =>
                                onTapManga?.call(buckets[column][i]),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NfMasonryCard extends StatelessWidget {
  final MManga manga;
  final double height;
  final Color accent;
  final VoidCallback onTap;

  const _NfMasonryCard({
    required this.manga,
    required this.height,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((manga.imageUrl ?? '').isNotEmpty)
                  NfPosterImage(
                    imageUrl: manga.imageUrl,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.cover,
                  )
                else
                  ColoredBox(color: accent.withValues(alpha: 0.16)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 9,
                  child: Text(
                    manga.name ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
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

class _NfInlineGrid extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final int columns;
  final Source source;
  final VoidCallback? onSeeAll;
  final void Function(MManga)? onTapManga;

  const _NfInlineGrid({
    required this.title,
    required this.items,
    required this.columns,
    required this.source,
    required this.onSeeAll,
    required this.onTapManga,
  });

  @override
  Widget build(BuildContext context) {
    final count = columns.clamp(2, 4).toInt();
    final visible = items.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 4, 8),
          child: Row(
            children: [
              Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
              )),
              const Spacer(),
              if (onSeeAll != null)
                SeeAllButton(color: Colors.white70, onTap: onSeeAll!),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.66,
          ),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => onTapManga?.call(visible[i]),
            child: MangaImageCardWidget(
              getMangaDetail: visible[i],
              source: source,
              itemType: source.itemType,
              isComfortableGrid: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _NfRankedRow extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final Source source;
  final VoidCallback? onSeeAll;
  final void Function(MManga)? onTapManga;

  const _NfRankedRow({
    required this.title,
    required this.items,
    required this.source,
    required this.onSeeAll,
    required this.onTapManga,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 4, 8),
          child: Row(
            children: [
              Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
              )),
              const Spacer(),
              if (onSeeAll != null)
                SeeAllButton(color: Colors.white70, onTap: onSeeAll!),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length,
            itemBuilder: (_, i) => SizedBox(
              width: 128,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => onTapManga?.call(items[i]),
                      child: NfMovieBox(
                        manga: items[i],
                        source: source,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: nfRedColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer loading row ────────────────────────────────────────────────────────

class _NfShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200.0,
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
      loading: () => _buildGrid(context, const [], shimmerOnly: true),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  /// Centred catalogue grid — gutters on both sides, rounded poster cards
  /// with a subtle border + shadow (the "spotlight" effect), unlike the
  /// edge-to-edge rows above.
  Widget _buildGrid(BuildContext ctx, List<MManga> list,
      {bool shimmerOnly = false}) {
    final all = shimmerOnly ? const <MManga>[] : (items.isNotEmpty ? items : list);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 122,
          childAspectRatio:   0.66,
          mainAxisSpacing:    14,
          crossAxisSpacing:   12,
        ),
        delegate: SliverChildBuilderDelegate(
          (c2, i) {
            if (i >= all.length) return _NfShimmerPosterTile();
            return _CatalogueCard(
              child: MangaImageCardWidget(
                getMangaDetail:    all[i],
                source:            source,
                itemType:          source.itemType,
                isComfortableGrid: false,
              ),
            );
          },
          childCount: shimmerOnly
              ? 12
              : all.length + (loading ? 3 : 0),
        ),
      ),
    );
  }
}

// ── Catalogue poster card — rounded frame + soft shadow + hairline border ────

class _CatalogueCard extends StatelessWidget {
  final Widget child;
  const _CatalogueCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: child,
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

// ── Golden catalogue divider ────────────────────────────────────────────────
// Ornamental hairline with a small leaf/diamond flourish at the inner end.
// Used to flank the gold-gradient CATALOGUE title.

class _GoldenDivider extends StatelessWidget {
  const _GoldenDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFCBA135).withValues(alpha: 0.0),
                    const Color(0xFFCBA135).withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            transform: Matrix4.rotationZ(0.785398), // 45° diamond
            decoration: const BoxDecoration(
              color: Color(0xFFE7C66B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category grid page — ALL categories on a clean 2-column grid ────────────

class _CategoryGridPage extends StatelessWidget {
  final Source                     source;
  final List<Map<String, dynamic>> categories;

  const _CategoryGridPage({
    required this.source,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: nfBackgroundColor,
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
                Text(
                  'Catégories',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.85,
        ),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cl       = categories[i];
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

          return Consumer(
            builder: (context, ref, _) {
              var imageUrl = extImg;
              if (imageUrl.isEmpty) {
                final snap = ref.watch(getCustomListProvider(
                    source: source, listId: listId, page: 1));
                imageUrl = snap.maybeWhen(
                  data: (d) => d?.list.firstOrNull?.imageUrl ?? '',
                  orElse: () => '',
                );
              }
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _WatchSectionPage(
                    source: source,
                    title: listName,
                    type: _SectionKind.custom,
                    customListId: listId,
                  ),
                )),
                child: _CategoryCard(
                  name: listName,
                  imageUrl: imageUrl,
                  fallback: fallback,
                  width: double.infinity,
                  height: double.infinity,
                  large: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Shared category tile. When an extension does not provide an explicit image,
/// callers pass the first item from its list as [imageUrl].
class _CategoryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final Color fallback;
  final double width;
  final double height;
  final bool large;

  const _CategoryCard({
    required this.name,
    required this.imageUrl,
    required this.fallback,
    required this.width,
    required this.height,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: large ? 14 : 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? ExtendedImage.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadStateChanged: (state) =>
                        state.extendedImageLoadState == LoadState.failed
                            ? ColoredBox(color: fallback)
                            : null,
                  )
                : ColoredBox(color: fallback),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            Positioned(
              left: large ? 14 : 10,
              right: large ? 14 : 10,
              bottom: large ? 14 : 10,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: large ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: large ? 15 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchSourcePickerSheet extends StatelessWidget {
  final Source current;

  const _WatchSourcePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sources = isar.sources
        .filter()
        .idIsNotNull()
        .isAddedEqualTo(true)
        .isActiveEqualTo(true)
        .itemTypeEqualTo(current.itemType)
        .findAllSync()
        .where((s) => s.name != 'local')
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.34,
        maxChildSize: 0.86,
        expand: false,
        builder: (_, controller) => Material(
          color: nfBottomSheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Changer d’extension',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${sources.length}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sources.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune autre extension disponible',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: sources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final candidate = sources[i];
                          final selected = candidate.id == current.id;
                          return Material(
                            color: selected
                                ? cs.primary.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.of(context).pop(candidate),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: (candidate.iconUrl ?? '').isEmpty
                                          ? const Icon(Icons.extension_rounded,
                                              color: Colors.white70)
                                          : ExtendedImage.network(
                                              candidate.iconUrl!,
                                              fit: BoxFit.cover,
                                              loadStateChanged: (state) =>
                                                  state.extendedImageLoadState ==
                                                          LoadState.failed
                                                      ? const Icon(
                                                          Icons.extension_rounded,
                                                          color: Colors.white70)
                                                      : null,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.name ?? 'Extension',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (candidate.lang ?? '').toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(Icons.check_circle_rounded,
                                          color: cs.primary, size: 21),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search content-type tab pill ───────────────────────────────────────────────
// Netflix-style segmented pills under the search bar. Values come from the
// extension manifest's contentSubtype list.

class _SearchTypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchTypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white12,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

extension _StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
