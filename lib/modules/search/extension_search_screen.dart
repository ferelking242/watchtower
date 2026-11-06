import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/media/overlay_filter_menu.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_card_adapter.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';
import 'package:watchtower/modules/search/extension_search_preview.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/media/extension_image_headers.dart';

/// Extension search — used by watch extensions AND manga/novel home screens.
///
/// Same chrome as the TMDB search (chevron back, compact field with the mic
/// inside, filter + three-dots outside). Empty state: recent searches, popular
/// & latest of the extension as ranked hot tabs. Results use tabs declared by
/// the extension when present; otherwise the screen keeps its legacy "Tout"
/// tab plus result-derived tabs (genres, author/language, etc.).
class ExtensionSearchScreen extends ConsumerStatefulWidget {
  final Source source;
  final VoidCallback onClose;
  final ValueChanged<MManga> onOpen;
  final String? initialQuery;

  const ExtensionSearchScreen({
    required this.source,
    required this.onClose,
    required this.onOpen,
    this.initialQuery,
    super.key,
  });

  @override
  ConsumerState<ExtensionSearchScreen> createState() =>
      _ExtensionSearchScreenState();
}

class _ExtensionSearchScreenState extends ConsumerState<ExtensionSearchScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  List<String> _recent = [];
  String _query = '';
  bool _submitted = false;
  Timer? _filterSearchDebounce;
  Timer? _previewDebounce;
  Future<void>? _layoutFuture;
  bool _searchPreviewEnabled = false;
  bool _previewLoading = false;
  List<MManga> _previewResults = const [];
  Object? _previewError;
  int _previewRequestVersion = 0;

  List<MManga>? _results;
  bool _loading = false;
  Object? _error;
  int _page = 1;
  bool _hasNext = true;
  bool _loadingMore = false;
  final _seen = <String>{};

  late TabController _tabs;
  List<String> _tabLabels = const ['Tout'];
  List<SearchTabLayout> _searchTabs = const [];
  String? _activeSearchTabId;
  final Map<String, List<MManga>> _searchTabResults = {};
  final Map<String, int> _searchTabPages = {};
  final Map<String, bool> _searchTabHasNext = {};
  final Set<String> _loadedSearchTabs = {};
  int _searchRequestVersion = 0;

  List<dynamic> _filterList = [];
  List<dynamic> _activeFilters = [];
  final ValueNotifier<List<dynamic>> _filterNotifier =
      ValueNotifier<List<dynamic>>(const []);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: initial);
    _query = initial;
    _loadRecent();
    _loadFilterList();
    _tabs = TabController(length: 1, vsync: this);
    if (widget.source.id != null) _layoutFuture = _loadLayout();
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(initial));
    }
  }

  void _loadFilterList() {
    try {
      _filterList = getFilterList(source: widget.source);
    } catch (_) {
      _filterList = [];
    }
    _activeFilters = List.from(_filterList);
    _filterNotifier.value = _activeFilters;
  }

  int get _activeFilterCount {
    var count = 0;
    for (final f in _activeFilters) {
      if (f is CheckBoxFilter && f.state) {
        count++;
      } else if (f is TriStateFilter && f.state != 0) {
        count++;
      } else if (f is SelectFilter && f.state != 0) {
        count++;
      } else if (f is GroupFilter) {
        count += _countGroup(f.state);
      }
    }
    return count;
  }

  int _countGroup(List<dynamic> filters) {
    var count = 0;
    for (final f in filters) {
      if (f is CheckBoxFilter && f.state) {
        count++;
      } else if (f is TriStateFilter && f.state != 0) {
        count++;
      } else if (f is SelectFilter && f.state != 0) {
        count++;
      } else if (f is GroupFilter) {
        count += _countGroup(f.state);
      }
    }
    return count;
  }

  void _onFiltersChanged(List<dynamic> filters) {
    _activeFilters = filters;
    _filterNotifier.value = filters;
    if (_submitted) _runSearch(_query);
  }

  void _onFilterSearchChanged(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _onTextChanged(value);
    _filterSearchDebounce?.cancel();
    if (value.trim().isNotEmpty) {
      _filterSearchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) unawaited(_runSearch(value));
      });
    }
  }

  Future<void> _loadLayout() async {
    await LayoutRegistry.instance.load(widget.source);
    if (!mounted) return;
    final searchLayout = LayoutRegistry.instance
        .get(widget.source)
        .browse
        ?.search;
    final searchPreview = searchLayout?.searchPreview ?? false;
    setState(() {
      _searchPreviewEnabled = searchPreview;
      _searchTabs = searchLayout?.tabs ?? const [];
    });
    if (searchPreview && _controller.text.trim().length >= 2) {
      _scheduleSearchPreview(_controller.text);
    }
  }

  @override
  void dispose() {
    _filterSearchDebounce?.cancel();
    _previewDebounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _tabs.dispose();
    _filterNotifier.dispose();
    super.dispose();
  }

  String get _recentKey => 'extension_recent_searches_${widget.source.id}';

  Future<void> _loadRecent() async {
    final values = await loadRecentSearches(_recentKey);
    if (!mounted) return;
    setState(() => _recent = values);
  }

  void _onTextChanged(String value) {
    _filterSearchDebounce?.cancel();
    final query = value.trim();
    if (_searchPreviewEnabled && (query != _query || _submitted)) {
      setState(() {
        _searchRequestVersion++;
        _query = query;
        _submitted = false;
        _results = null;
        _error = null;
        _loading = false;
        _previewError = null;
        _loadingMore = false;
        _page = 1;
        _hasNext = true;
        _seen.clear();
        _searchTabResults.clear();
        _searchTabPages.clear();
        _searchTabHasNext.clear();
        _loadedSearchTabs.clear();
        _setTabLabels(const ['Tout']);
      });
    } else if (!_searchPreviewEnabled && query.isEmpty && _query.isNotEmpty) {
      setState(() {
        _searchRequestVersion++;
        _query = '';
        _submitted = false;
        _results = null;
        _error = null;
        _loading = false;
        _loadingMore = false;
        _page = 1;
        _hasNext = true;
        _seen.clear();
        _searchTabResults.clear();
        _searchTabPages.clear();
        _searchTabHasNext.clear();
        _loadedSearchTabs.clear();
        _setTabLabels(const ['Tout']);
      });
    } else {
      setState(() {});
    }
    _scheduleSearchPreview(value);
  }

  void _scheduleSearchPreview(String raw) {
    _previewDebounce?.cancel();
    final requestVersion = ++_previewRequestVersion;
    final query = raw.trim();
    if (!_searchPreviewEnabled || query.length < 2 || _submitted) {
      if (_previewLoading ||
          _previewResults.isNotEmpty ||
          _previewError != null) {
        setState(() {
          _previewLoading = false;
          _previewResults = const [];
          _previewError = null;
        });
      }
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadSearchPreview(query, requestVersion));
    });
  }

  Future<void> _loadSearchPreview(String query, int requestVersion) async {
    if (!mounted || requestVersion != _previewRequestVersion) return;
    setState(() {
      _previewLoading = true;
      _previewResults = const [];
      _previewError = null;
    });
    try {
      final page = await ref.read(
        getCustomListProvider(
          source: widget.source,
          listId: 'search_preview:${Uri.encodeComponent(query)}',
          page: 1,
        ).future,
      );
      if (!mounted || requestVersion != _previewRequestVersion) return;
      setState(() {
        _previewLoading = false;
        _previewResults = page?.list ?? const <MManga>[];
        _previewError = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _previewRequestVersion) return;
      setState(() {
        _previewLoading = false;
        _previewResults = const [];
        _previewError = error;
      });
    }
  }

  void _retrySearchPreview() {
    final query = _controller.text.trim();
    if (query.length < 2 || _submitted) return;
    _previewDebounce?.cancel();
    ref.invalidate(
      getCustomListProvider(
        source: widget.source,
        listId: 'search_preview:${Uri.encodeComponent(query)}',
        page: 1,
      ),
    );
    final requestVersion = ++_previewRequestVersion;
    unawaited(_loadSearchPreview(query, requestVersion));
  }

  void _setTabLabels(List<String> labels) {
    final nextLabels = labels.isEmpty ? const ['Tout'] : labels;
    if (_tabs.length != nextLabels.length) {
      final previous = _tabs;
      _tabs = TabController(length: nextLabels.length, vsync: this);
      previous.dispose();
    } else if (_tabs.index != 0) {
      _tabs.index = 0;
    }
    _tabLabels = nextLabels;
    _activeSearchTabId = null;
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final requestVersion = ++_searchRequestVersion;
    _previewDebounce?.cancel();
    _previewRequestVersion++;
    setState(() {
      _previewLoading = false;
      _previewResults = const [];
      _previewError = null;
    });
    await (_layoutFuture ?? Future<void>.value());
    if (!mounted || requestVersion != _searchRequestVersion) return;
    _previewDebounce?.cancel();
    _previewRequestVersion++;
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _focus.unfocus();
    await saveRecentSearch(_recentKey, query);
    final recent = await loadRecentSearches(_recentKey);
    if (!mounted || requestVersion != _searchRequestVersion) return;
    setState(() {
      _recent = recent;
      _query = query;
      _submitted = true;
      _results = null;
      _error = null;
      _page = 1;
      _hasNext = true;
      _loadingMore = false;
      _seen.clear();
      _loading = true;
      _searchTabResults.clear();
      _searchTabPages.clear();
      _searchTabHasNext.clear();
      _loadedSearchTabs.clear();
      _setTabLabels(
        _searchTabs.isEmpty
            ? const ['Tout']
            : _searchTabs.map((tab) => tab.title).toList(growable: false),
      );
    });
    if (_searchTabs.isNotEmpty) {
      final firstTab = _searchTabs.first;
      _activeSearchTabId = firstTab.id;
      await _loadDeclaredSearchTab(firstTab, 1, requestVersion);
      return;
    }
    try {
      final page = await ref.read(
        searchProvider(
          source: widget.source,
          query: query,
          page: 1,
          filterList: _activeFilters,
        ).future,
      );
      if (!mounted || requestVersion != _searchRequestVersion) return;
      final items = page?.list ?? const <MManga>[];
      for (final item in items) {
        _seen.add(item.link ?? item.name ?? '${item.hashCode}');
      }
      setState(() {
        _results = items;
        _loading = false;
        _hasNext = page?.hasNextPage ?? false;
        _setTabLabels(_deriveTabs(items));
      });
    } catch (error) {
      if (!mounted || requestVersion != _searchRequestVersion) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool _matchesDeclaredResult(MManga item, SearchTabLayout tab) {
    final kind = tab.resultType?.toLowerCase();
    if (kind == null || kind.isEmpty) return true;
    final path = Uri.tryParse(item.link ?? '')?.path.toLowerCase() ?? '';
    return switch (kind) {
      'video' => path.contains('/video.') || path.contains('/video/'),
      'actress' || 'actresses' =>
        path.contains('/pornstars/') || path.contains('/actresses/'),
      'channel' || 'channels' => path.contains('/channels/'),
      _ => true,
    };
  }

  Future<void> _loadDeclaredSearchTab(
    SearchTabLayout tab,
    int page,
    int requestVersion, {
    bool append = false,
  }) async {
    try {
      final result = tab.source == 'search'
          ? await ref.read(
              searchProvider(
                source: widget.source,
                query: _query,
                page: page,
                filterList: _activeFilters,
              ).future,
            )
          : await ref.read(
              getCustomListProvider(
                source: widget.source,
                listId: 'search_tab:${tab.id}:${Uri.encodeComponent(_query)}',
                page: page,
              ).future,
            );
      if (!mounted || requestVersion != _searchRequestVersion) return;

      final matches = (result?.list ?? const <MManga>[]).where(
        (item) => _matchesDeclaredResult(item, tab),
      );
      final fresh = matches
          .where(
            (item) => _seen.add(item.link ?? item.name ?? '${item.hashCode}'),
          )
          .toList(growable: false);
      final items = append ? [...?_results, ...fresh] : fresh;
      final hasNext = fresh.isNotEmpty && (result?.hasNextPage ?? false);
      _searchTabResults[tab.id] = items;
      _searchTabPages[tab.id] = page;
      _searchTabHasNext[tab.id] = hasNext;
      _loadedSearchTabs.add(tab.id);
      setState(() {
        _results = items;
        _page = page;
        _hasNext = hasNext;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _searchRequestVersion) return;
      setState(() {
        if (!append) {
          _error = error;
          _loading = false;
        }
        _loadingMore = false;
      });
    }
  }

  Future<void> _selectSearchTab(int index) async {
    if (index < 0 || index >= _searchTabs.length) return;
    final tab = _searchTabs[index];
    if (tab.id == _activeSearchTabId) return;
    _activeSearchTabId = tab.id;
    final requestVersion = ++_searchRequestVersion;
    _seen.clear();
    final cached = _searchTabResults[tab.id];
    if (_loadedSearchTabs.contains(tab.id) && cached != null) {
      _seen.addAll(
        cached.map((item) => item.link ?? item.name ?? '${item.hashCode}'),
      );
      setState(() {
        _results = cached;
        _page = _searchTabPages[tab.id] ?? 1;
        _hasNext = _searchTabHasNext[tab.id] ?? false;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _results = null;
      _error = null;
      _loading = true;
      _loadingMore = false;
      _page = 1;
      _hasNext = true;
    });
    await _loadDeclaredSearchTab(tab, 1, requestVersion);
  }

  void _retrySearch() {
    if (_query.isEmpty) return;
    if (_searchTabs.isNotEmpty) {
      final index = _searchTabs.indexWhere(
        (tab) => tab.id == _activeSearchTabId,
      );
      final tab = _searchTabs[index < 0 ? 0 : index];
      if (tab.source == 'custom') {
        ref.invalidate(
          getCustomListProvider(
            source: widget.source,
            listId: 'search_tab:${tab.id}:${Uri.encodeComponent(_query)}',
            page: 1,
          ),
        );
      } else {
        ref.invalidate(
          searchProvider(
            source: widget.source,
            query: _query,
            page: 1,
            filterList: _activeFilters,
          ),
        );
      }
      _searchTabResults.remove(tab.id);
      _searchTabPages.remove(tab.id);
      _searchTabHasNext.remove(tab.id);
      _loadedSearchTabs.remove(tab.id);
      _seen.clear();
      final requestVersion = ++_searchRequestVersion;
      setState(() {
        _results = null;
        _error = null;
        _loading = true;
        _loadingMore = false;
        _page = 1;
        _hasNext = true;
      });
      unawaited(_loadDeclaredSearchTab(tab, 1, requestVersion));
      return;
    }
    ref.invalidate(
      searchProvider(
        source: widget.source,
        query: _query,
        page: 1,
        filterList: _activeFilters,
      ),
    );
    _runSearch(_query);
  }

  /// Tabs derived from what the extension actually returned. MangaDex-style
  /// sources expose genres → one tab per top genre; others get
  /// "En cours" (latest) vs "Populaires" style groupings only when data
  /// supports it.
  List<String> _deriveTabs(List<MManga> items) {
    final tabs = <String>['Tout'];
    final genres = <String>{};
    for (final item in items) {
      for (final g in item.genre ?? const <String>[]) {
        if (g.trim().isNotEmpty && genres.length < 4) genres.add(g.trim());
      }
    }
    tabs.addAll(genres);
    return tabs;
  }

  bool _matchesTab(MManga item, String tab) {
    if (tab == 'Tout') return true;
    return (item.genre ?? const <String>[]).any(
      (g) => g.trim().toLowerCase() == tab.toLowerCase(),
    );
  }

  String? get _searchCardComponent {
    final component = LayoutRegistry.instance
        .get(widget.source)
        .browse
        ?.search
        ?.results
        ?.cardComponent;
    return component != null &&
            LayoutComponentRegistry.supports(
              component,
              LayoutComponentContext.search,
            )
        ? component
        : null;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext || _results == null) return;
    final requestVersion = _searchRequestVersion;
    final query = _query;
    if (_searchTabs.isNotEmpty) {
      final index = _searchTabs.indexWhere(
        (tab) => tab.id == _activeSearchTabId,
      );
      if (index < 0) return;
      setState(() => _loadingMore = true);
      await _loadDeclaredSearchTab(
        _searchTabs[index],
        _page + 1,
        requestVersion,
        append: true,
      );
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(
        searchProvider(
          source: widget.source,
          query: query,
          page: _page + 1,
          filterList: _activeFilters,
        ).future,
      );
      if (!mounted || requestVersion != _searchRequestVersion) return;
      final fresh = (next?.list ?? const <MManga>[])
          .where(
            (item) => _seen.add(item.link ?? item.name ?? '${item.hashCode}'),
          )
          .toList(growable: false);
      setState(() {
        _results = [...?_results, ...fresh];
        _page += 1;
        _hasNext = fresh.isNotEmpty && (next?.hasNextPage ?? false);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && requestVersion == _searchRequestVersion) {
        setState(() => _loadingMore = false);
      }
    }
  }

  /// Clears the field and keeps the keyboard open. Used as the first step of
  /// the back gesture (see [handleSearchBack]).
  void _clearAll() {
    _controller.clear();
    setState(() {
      _searchRequestVersion++;
      _query = '';
      _submitted = false;
      _results = null;
      _error = null;
      _loading = false;
      _loadingMore = false;
      _page = 1;
      _hasNext = true;
      _seen.clear();
      _searchTabResults.clear();
      _searchTabPages.clear();
      _searchTabHasNext.clear();
      _loadedSearchTabs.clear();
      _setTabLabels(const ['Tout']);
    });
    _focus.requestFocus();
  }

  void _onBack() {
    handleSearchBack(
      controller: _controller,
      onClearQuery: _clearAll,
      onExit: widget.onClose,
    );
  }

  void _startVoiceSearch() {
    unawaited(
      startVoiceSearch(
        onResult: (words) {
          if (!mounted) return;
          _controller.text = words;
          _controller.selection = TextSelection.collapsed(offset: words.length);
          _runSearch(words);
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    final accent = Theme.of(context).colorScheme.primary;
    final activeCount = _activeFilterCount;
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _filterNotifier,
      builder: (context, _, _) => AdaptiveOverlayMenuButton(
        menuWidth: 300,
        trigger: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            backgroundColor: accent,
            child: Icon(
              Broken.filter,
              size: 20,
              color: activeCount > 0 ? accent : Colors.white70,
            ),
          ),
        ),
        contentBuilder: (close) => ExtensionFilterOverlay(
          filterList: _activeFilters,
          onChanged: _onFiltersChanged,
          close: close,
          searchValue: _query,
          onSearchChanged: _onFilterSearchChanged,
        ),
      ),
    );
  }

  bool get _showFilterButton {
    if (_searchTabs.isEmpty) return true;
    final index = _searchTabs.indexWhere((tab) => tab.id == _activeSearchTabId);
    return _searchTabs[index < 0 ? 0 : index].source == 'search';
  }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(
      headersProvider(
        source: widget.source.name ?? '',
        lang: widget.source.lang ?? '',
        sourceId: widget.source.id,
      ),
    );
    return ExtensionImageHeaders(
      headers: headers,
      sourceId: widget.source.id,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B11),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SharedSearchHeader(
                      controller: _controller,
                      focusNode: _focus,
                      hint:
                          'Rechercher dans ${widget.source.name ?? 'l’extension'}',
                      onBack: _onBack,
                      onMic: _startVoiceSearch,
                      onSubmit: _runSearch,
                      onChanged: _onTextChanged,
                    ),
                  ),
                  // Filtre d'extension : hors de la box, à côté des 3 points,
                  // via le composant partagé de la Librairie. Présent pour
                  // toutes les extensions, même sans filtre déclaré.
                  if (_showFilterButton) _buildFilterButton(),
                  // Menu 3 points, même composant glass que la Librairie.
                  if (_results != null && _results!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CatalogDownloadMenuButton(
                        onSelected: (action) => CatalogBulkDownload.handleMenu(
                          context,
                          ref,
                          widget.source,
                          _results!,
                          action,
                        ),
                      ),
                    ),
                ],
              ),
              // Séparateur léger sous la barre de recherche.
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              Expanded(
                child: _submitted
                    ? _resultsArea()
                    : Column(
                        children: [
                          ExtensionSearchPreview(
                            enabled: _searchPreviewEnabled,
                            query: _controller.text,
                            loading: _previewLoading,
                            items: _previewResults,
                            errorMessage: _previewError == null
                                ? null
                                : extensionRequestFailureMessage(
                                        _previewError,
                                      ) ??
                                      'La recherche d’aperçu est momentanément indisponible.',
                            onRetry: _retrySearchPreview,
                            onOpen: widget.onOpen,
                          ),
                          Expanded(child: _emptyArea()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyArea() {
    return SharedSearchEmptyState(
      recentSearches: _recent,
      hotSearches: const [],
      hotTabs: const [],
      onSearch: _runSearch,
      onClearRecents: () async {
        await clearRecentSearches(_recentKey);
        if (mounted) setState(() => _recent = []);
      },
      hintText: 'Que veux-tu lire ?',
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  Widget _resultsArea() {
    if (_searchTabs.isNotEmpty) return _declaredResultsArea();
    if (_loading) return const SharedSearchShimmerList();
    if (_error != null) {
      final statusCode = extensionHttpStatusCode(_error);
      return _ExtensionSearchMessage(
        title: statusCode == null
            ? 'Recherche indisponible'
            : 'Erreur HTTP $statusCode',
        message:
            extensionRequestFailureMessage(_error) ??
            'La source est momentanément indisponible. Réessaie dans quelques instants.',
        onRetry: _retrySearch,
      );
    }
    if (_results == null || _results!.isEmpty) {
      return SharedSearchEmptyAnimation(
        title: 'Aucun résultat',
        message: 'Rien ne correspond à « $_query ».',
      );
    }
    return Column(
      children: [
        if (_tabLabels.length > 1)
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.white10,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final label in _tabLabels)
                _ExtensionResultsGrid(
                  items: _results!.where((i) => _matchesTab(i, label)).toList(),
                  onLoadMore: _loadMore,
                  loadingMore: _loadingMore,
                  onOpen: widget.onOpen,
                  cardComponent: _searchCardComponent,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _declaredResultsArea() {
    Widget content;
    if (_loading) {
      content = const SharedSearchShimmerList();
    } else if (_error != null) {
      final statusCode = extensionHttpStatusCode(_error);
      content = _ExtensionSearchMessage(
        title: statusCode == null
            ? 'Recherche indisponible'
            : 'Erreur HTTP $statusCode',
        message:
            extensionRequestFailureMessage(_error) ??
            'La source est momentanément indisponible. Réessaie dans quelques instants.',
        onRetry: _retrySearch,
      );
    } else if (_results == null || _results!.isEmpty) {
      content = SharedSearchEmptyAnimation(
        title: 'Aucun résultat',
        message: 'Rien ne correspond à « $_query ».',
      );
    } else {
      content = _ExtensionResultsGrid(
        items: _results!,
        onLoadMore: _loadMore,
        loadingMore: _loadingMore,
        onOpen: widget.onOpen,
        cardComponent: _searchCardComponent,
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.white10,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: (index) => unawaited(_selectSearchTab(index)),
          tabs: [for (final label in _tabLabels) Tab(text: label)],
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _ExtensionResultsGrid extends StatelessWidget {
  final List<MManga> items;
  final VoidCallback onLoadMore;
  final bool loadingMore;
  final ValueChanged<MManga> onOpen;
  final String? cardComponent;

  const _ExtensionResultsGrid({
    required this.items,
    required this.onLoadMore,
    required this.loadingMore,
    required this.onOpen,
    required this.cardComponent,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 420) onLoadMore();
        return false;
      },
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          14,
          AppUI.pagePadding(context),
          120,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppUI.mediaGridColumns(context),
          childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const AppShimmerBlock(radius: AppUI.cardRadius);
          }
          final item = items[index];
          final contentItem = ContentItem.fromManga(item);
          final onTap = () => onOpen(item);
          final configuredCard = cardComponent == null
              ? null
              : MangaHomeCardAdapter.build(
                  component: cardComponent!,
                  componentContext: LayoutComponentContext.search,
                  item: contentItem,
                  width: double.infinity,
                  onTap: onTap,
                );
          if (configuredCard != null) return configuredCard;
          return PosterCard(
            item: contentItem,
            width: double.infinity,
            onTap: onTap,
          );
        },
      ),
    );
  }
}

class _ExtensionSearchMessage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _ExtensionSearchMessage({
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Broken.search_status,
              size: 54,
              color: accent.withValues(alpha: .8),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
