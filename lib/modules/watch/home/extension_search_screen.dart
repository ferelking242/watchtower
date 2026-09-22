import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/cached_network.dart';

/// Extension search deliberately mirrors the FlixQuest search layout while
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
        child: DefaultTabController(
          length: 1,
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
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 16),
                tabs: [Tab(text: 'Résultats')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _query.isEmpty
                        ? _ExtensionRecentSearches(
                            searches: _recentSearches,
                            onSearch: _search,
                            onRemove: _removeRecentSearch,
                            onClear: _clearRecentSearches,
                          )
                        : _ExtensionSearchResults(
                            result: result!,
                            onOpen: widget.onOpen,
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
}

class _ExtensionSearchResults extends StatelessWidget {
  final AsyncValue<dynamic> result;
  final ValueChanged<MManga> onOpen;

  const _ExtensionSearchResults({required this.result, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return result.when(
      loading: () => const _ExtensionSearchGridShimmer(),
      error: (error, _) => _ExtensionSearchEmpty(
        title: 'Recherche indisponible',
        message: '$error',
      ),
      data: (pages) {
        final items = (pages?.list as List<MManga>?) ?? const <MManga>[];
        if (items.isEmpty) {
          return const _ExtensionSearchEmpty(
            title: 'Aucun résultat',
            message: 'Aucun contenu ne correspond à cette recherche.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: .56,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => _ExtensionSearchCard(
            item: items[index],
            onTap: () => onOpen(items[index]),
          ),
        );
      },
    );
  }
}

class _ExtensionSearchCard extends StatelessWidget {
  final MManga item;
  final VoidCallback onTap;

  const _ExtensionSearchCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.imageUrl?.isNotEmpty == true
                  ? cachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : const ColoredBox(
                      color: Color(0xFF22242C),
                      child: Center(
                        child: Icon(
                          Broken.video,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name ?? 'Sans titre',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

class _ExtensionSearchGridShimmer extends StatelessWidget {
  const _ExtensionSearchGridShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: .56,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (_, __) => const AppShimmerBlock(radius: 14),
    );
  }
}
