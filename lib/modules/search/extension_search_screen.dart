import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_card_adapter.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/search.dart';

/// Extension search — used by watch extensions AND manga/novel home screens.
///
/// Same chrome as the TMDB search (back, compact field, live mic dictation).
/// Empty state: recent searches, popular & latest of the extension as ranked
/// hot tabs. Results: "Tout" tab plus tabs derived from the extension result
/// (Genres for MangaDex-like sources, Auteur/Langue when present).
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

  List<MManga>? _results;
  bool _loading = false;
  Object? _error;
  int _page = 1;
  bool _hasNext = true;
  bool _loadingMore = false;
  final _seen = <String>{};

  late TabController _tabs;
  List<String> _tabLabels = const ['Tout'];
  int _searchRequestVersion = 0;

  List<dynamic> _filterList = [];
  List<dynamic> _activeFilters = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: initial);
    _query = initial;
    _loadRecent();
    _loadFilterList();
    _tabs = TabController(length: 1, vsync: this);
    if (widget.source.providesHome) {
      unawaited(_loadLayout());
    }
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

  void _showFilterSheet() {
    if (_filterList.isEmpty) return;
    List<dynamic> localFilters = List<dynamic>.from(_filterList);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                child: Row(
                  children: [
                    const Text(
                      'Filtres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          setLocal(() => localFilters = List.from(_filterList)),
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilterWidget(
                    filterList: localFilters,
                    onChanged: (updated) =>
                        setLocal(() => localFilters = updated),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _activeFilters = localFilters);
                          if (_submitted) _runSearch(_query);
                        },
                        child: const Text('Appliquer'),
                      ),
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

  Future<void> _loadLayout() async {
    await LayoutRegistry.instance.load(widget.source);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String get _recentKey => 'extension_recent_searches_${widget.source.id}';

  Future<void> _loadRecent() async {
    final values = await loadRecentSearches(_recentKey);
    if (!mounted) return;
    setState(() => _recent = values);
  }

  void _onTextChanged(String value) {
    if (value.trim().isEmpty && _query.isNotEmpty) {
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
        _setTabLabels(const ['Tout']);
      });
    }
    setState(() {});
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
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final requestVersion = ++_searchRequestVersion;
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
      _setTabLabels(const ['Tout']);
    });
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

  void _retrySearch() {
    if (_query.isEmpty) return;
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
      _setTabLabels(const ['Tout']);
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SharedSearchHeader(
              controller: _controller,
              focusNode: _focus,
              hint: 'Rechercher dans ${widget.source.name ?? 'l’extension'}',
              activeFilterCount: _activeFilterCount,
              onFilter: _filterList.isEmpty ? null : _showFilterSheet,
              onBack: widget.onClose,
              onSubmit: _runSearch,
              onChanged: _onTextChanged,
              onClear: _clearAll,
            ),
            Expanded(child: _submitted ? _resultsArea() : _emptyArea()),
          ],
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
