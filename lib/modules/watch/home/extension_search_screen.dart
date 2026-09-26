import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/cached_network.dart';

/// Extension search deliberately mirrors the shared media search layout while
/// keeping its data and preferences isolated from the TMDB search screen.
class ExtensionSearchScreen extends ConsumerStatefulWidget {
  final Source source;
  final VoidCallback onClose;
  final ValueChanged<MManga> onOpen;

  const ExtensionSearchScreen({
    required this.source,
    required this.onClose,
    required this.onOpen,
    super.key,
  });

  @override
  ConsumerState<ExtensionSearchScreen> createState() =>
      _ExtensionSearchScreenState();
}

class _ExtensionSearchScreenState extends ConsumerState<ExtensionSearchScreen> {
  late final TextEditingController _controller;
  final List<String> _recentSearches = [];
  String _query = '';

  String get _recentKey => 'extension_recent_searches_${widget.source.id}';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(prefs.getStringList(_recentKey) ?? const []);
    });
  }

  Future<void> _rememberSearch(String query) async {
    final next = <String>[
      query,
      ..._recentSearches.where(
        (value) => value.toLowerCase() != query.toLowerCase(),
      ),
    ].take(12).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _removeRecentSearch(String query) async {
    final next = _recentSearches.where((value) => value != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);
    if (!mounted) return;
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
    if (mounted) setState(_recentSearches.clear);
  }

  void _search([String? raw]) {
    final query = (raw ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    FocusScope.of(context).unfocus();
    setState(() => _query = query);
    _rememberSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final result = _query.isEmpty
        ? null
        : ref.watch(
            searchProvider(
              source: widget.source,
              query: _query,
              page: 1,
              filterList: const [],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Retour',
                      onPressed: widget.onClose,
                      icon: const Icon(Broken.arrow_left),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'Rechercher dans ${widget.source.name ?? 'l’extension'}',
                          prefixIcon: const Icon(Broken.search_normal),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Broken.close_circle),
                                ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.6,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Rechercher',
                      onPressed: _search,
                      icon: const Icon(Broken.search_normal),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _query.isEmpty
                  ? _ExtensionRecentSearches(
                      searches: _recentSearches,
                      onSearch: _search,
                      onRemove: _removeRecentSearch,
                      onClear: _clearRecentSearches,
                    )
                  : _ExtensionSearchResults(
                      key: ValueKey(_query),
                      source: widget.source,
                      query: _query,
                      result: result!,
                      onOpen: widget.onOpen,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ExtensionSearchResults extends ConsumerStatefulWidget {
  final Source source;
  final String query;
  final AsyncValue<MPages?> result;
  final ValueChanged<MManga> onOpen;

  const _ExtensionSearchResults({
    required this.source,
    required this.query,
    required this.result,
    required this.onOpen,
    super.key,
  });

  @override
  ConsumerState<_ExtensionSearchResults> createState() =>
      _ExtensionSearchResultsState();
}

class _ExtensionSearchResultsState
    extends ConsumerState<_ExtensionSearchResults> {
  final _scrollController = ScrollController();
  final _additionalItems = <MManga>[];
  int _page = 1;
  bool _loadingMore = false;
  bool? _hasNextPage;
  bool _initialFillScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 420) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final firstPage = widget.result.value;
    if (_loadingMore || (_hasNextPage ?? firstPage?.hasNextPage) != true) {
      return;
    }
    setState(() => _loadingMore = true);

    final nextPage = _page + 1;
    try {
      final result = await ref.read(
        searchProvider(
          source: widget.source,
          query: widget.query,
          page: nextPage,
          filterList: const [],
        ).future,
      );
      if (!mounted) return;
      final seen = {
        for (final item in [...?firstPage?.list, ..._additionalItems])
          item.link ?? item.name ?? '${item.hashCode}',
      };
      final newItems = (result?.list ?? const <MManga>[])
          .where(
            (item) => seen.add(item.link ?? item.name ?? '${item.hashCode}'),
          )
          .toList(growable: false);
      setState(() {
        _additionalItems.addAll(newItems);
        _page = nextPage;
        _hasNextPage = newItems.isNotEmpty && result?.hasNextPage == true;
        _initialFillScheduled = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstPage = widget.result.value;
    final items = [...?firstPage?.list, ..._additionalItems];
    if (widget.result.isLoading && items.isEmpty) {
      return const AppMediaGridShimmer();
    }
    if (widget.result.hasError && items.isEmpty) {
      return _ExtensionSearchEmpty(
        title: 'Recherche indisponible',
        message: '${widget.result.error}',
      );
    }
    if (items.isEmpty) {
      return const _ExtensionSearchEmpty(
        title: 'Aucun résultat',
        message: 'Aucun contenu ne correspond à cette recherche.',
      );
    }
    if (!_initialFillScheduled &&
        (_hasNextPage ?? firstPage?.hasNextPage) == true) {
      _initialFillScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });
    }
    return GridView.builder(
      controller: _scrollController,
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
      itemCount: items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index >= items.length) {
          return const AppShimmerBlock(radius: AppUI.cardRadius);
        }
        return PosterCard(
          item: ContentItem.fromManga(items[index]),
          width: double.infinity,
          onTap: () => widget.onOpen(items[index]),
        );
      },
    );
  }
}

class _ExtensionRecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _ExtensionRecentSearches({
    required this.searches,
    required this.onSearch,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return const _ExtensionSearchEmpty(
        title: 'Rechercher dans cette extension',
        message: 'Les résultats apparaîtront ici.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 12, 8),
          child: Row(
            children: [
              Text(
                'Recherches récentes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(onPressed: onClear, child: const Text('Tout effacer')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
            itemCount: searches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, index) {
              final search = searches[index];
              return ListTile(
                leading: const Icon(Broken.clock),
                title: Text(search),
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => onRemove(search),
                  icon: const Icon(Broken.close_circle),
                ),
                onTap: () => onSearch(search),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionSearchEmpty extends StatelessWidget {
  final String title;
  final String message;

  const _ExtensionSearchEmpty({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Broken.search_status,
              size: 58,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .8),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
