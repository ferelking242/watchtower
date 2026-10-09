import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';

/// Context that customises the search page per hub:
/// - movie hub → Films-first tab order and movie rails,
/// - series hub → Séries-first and TV rails.
enum FlixSearchContext { movies, series, generic }

/// Route payload for /flixSearch: optional preset query + hub context.
class FlixSearchPayload {
  final String? initialQuery;
  final FlixSearchContext? hub;

  const FlixSearchPayload({this.initialQuery, this.hub});
}

/// TMDB hub search page.
///
/// Header  : back + compact field + live mic dictation.
/// Empty   : recent searches → hot searches → ranked hot tabs
///           (Films chauds / Séries chaudes / genres…), adapting to the hub.
/// Results : scrollable tabs — Tout, [context-first tab], then
///           the other kind, Célébrités, Collections.
class TmdbSearchScreen extends StatefulWidget {
  const TmdbSearchScreen({super.key, this.initialQuery, this.hub});

  final String? initialQuery;

  /// Hub that opened the search; drives hint + default tab + rails.
  final FlixSearchContext? hub;

  @override
  State<TmdbSearchScreen> createState() => _TmdbSearchScreenState();
}

class _TmdbSearchScreenState extends State<TmdbSearchScreen>
    with TickerProviderStateMixin {
  static const _recentKey = 'tmdb_recent_searches_v2';

  late final FlixSearchContext _context;
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  List<String> _recent = [];
  String _query = '';
  bool _submitted = false;

  List<TmdbMultiResult>? _multiResults;
  bool _multiLoading = false;
  Object? _multiError;
  int _multiPage = 1;
  bool _multiHasMore = true;
  bool _loadingMore = false;
  final _seenKeys = <String>{};

  late final TabController _tabs;

  static const _tabLabels = [
    'Tout',
    'Films',
    'Séries',
    'Célébrités',
    'Collections',
  ];

  @override
  void initState() {
    super.initState();
    _context = widget.hub ?? FlixSearchContext.generic;
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _loadRecent();
    _tabs = TabController(length: _tabLabels.length, vsync: this);

    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(initial));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final values = await loadRecentSearches(_recentKey);
    if (!mounted) return;
    setState(() => _recent = values);
  }

  void _onTextChanged(String value) {
    if (value.trim().isEmpty && _query.isNotEmpty) {
      setState(() {
        _query = '';
        _submitted = false;
        _multiResults = null;
        _multiError = null;
      });
    }
    setState(() {});
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _focus.unfocus();
    await saveRecentSearch(_recentKey, query);
    final recent = await loadRecentSearches(_recentKey);
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _query = query;
      _submitted = true;
      _multiResults = null;
      _multiError = null;
      _multiPage = 1;
      _multiHasMore = true;
      _seenKeys.clear();
      _multiLoading = true;
      _tabs.index = 0;
    });
    try {
      final results = await fetchTmdbMultiSearch(query: query, page: 1);
      if (!mounted) return;
      for (final r in results) {
        _seenKeys.add(_keyOf(r));
      }
      setState(() {
        _multiResults = results;
        _multiLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _multiError = error;
        _multiLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_multiHasMore || _multiResults == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = await fetchTmdbMultiSearch(
        query: _query,
        page: _multiPage + 1,
      );
      if (!mounted) return;
      final fresh = <TmdbMultiResult>[];
      for (final r in next) {
        if (_seenKeys.add(_keyOf(r))) fresh.add(r);
      }
      setState(() {
        _multiResults = [...?_multiResults, ...fresh];
        _multiPage += 1;
        _multiHasMore = fresh.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _keyOf(TmdbMultiResult r) => switch (r.kind) {
    TmdbMultiKind.person => 'p:${r.person?.id}',
    TmdbMultiKind.tv => 't:${r.media?.id}',
    TmdbMultiKind.movie => 'm:${r.media?.id}',
  };

  void _clearAll() {
    _controller.clear();
    setState(() {
      _query = '';
      _submitted = false;
      _multiResults = null;
      _multiError = null;
    });
    _focus.requestFocus();
  }

  String get _hint => switch (_context) {
    FlixSearchContext.movies => 'Rechercher un film…',
    FlixSearchContext.series => 'Rechercher une série…',
    FlixSearchContext.generic => 'Film, série ou célébrité…',
  };

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty && _submitted;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SharedSearchHeader(
              controller: _controller,
              focusNode: _focus,
              hint: _hint,
              onBack: () => context.pop(),
              onSubmit: _runSearch,
              onChanged: _onTextChanged,
              onClear: _clearAll,
            ),
            Expanded(child: hasQuery ? _resultsArea() : _emptyArea()),
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
      hintText: 'Que veux-tu regarder ?',
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  Widget _resultsArea() {
    if (_multiLoading) {
      return const SharedSearchShimmerList();
    }
    if (_multiError != null) {
      return _SearchMessage(
        icon: Broken.warning_2,
        title: 'Recherche indisponible',
        message: '$_multiError',
        onRetry: () => _runSearch(_query),
      );
    }
    if (_multiResults == null || _multiResults!.isEmpty) {
      return SharedSearchEmptyAnimation(
        title: 'Aucun résultat',
        message: 'Rien ne correspond à « $_query ».',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 420) _loadMore();
        return false;
      },
      child: Column(
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
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AllResultsList(
                  results: _multiResults!,
                  onLoadMore: _loadMore,
                  loadingMore: _loadingMore,
                ),
                _MediaResultsList(media: _mediaOf(TmdbMultiKind.movie)),
                _MediaResultsList(media: _mediaOf(TmdbMultiKind.tv)),
                _PeopleResultsList(people: _peopleOf()),
                _CollectionsResultsList(query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TmdbMedia> _mediaOf(TmdbMultiKind kind) => [
    for (final r in _multiResults!)
      if (r.kind == kind && r.media != null) r.media!,
  ];

  List<TmdbPersonRef> _peopleOf() => [
    for (final r in _multiResults!)
      if (r.kind == TmdbMultiKind.person && r.person != null) r.person!,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Result lists
// ─────────────────────────────────────────────────────────────────────────────

class _AllResultsList extends StatelessWidget {
  final List<TmdbMultiResult> results;
  final VoidCallback onLoadMore;
  final bool loadingMore;

  const _AllResultsList({
    required this.results,
    required this.onLoadMore,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemCount: results.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final r = results[index];
        return switch (r.kind) {
          TmdbMultiKind.person => _PersonRow(person: r.person!),
          _ => _MediaRow(
            media: r.media!,
            badge: r.kind == TmdbMultiKind.tv ? 'Série' : 'Film',
            accent: accent,
          ),
        };
      },
    );
  }
}

class _MediaRow extends StatelessWidget {
  final TmdbMedia media;
  final String badge;
  final Color accent;

  const _MediaRow({
    required this.media,
    required this.badge,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final year = media.releaseDate ?? media.firstAirDate ?? '';
    final y = year.length >= 4 ? year.substring(0, 4) : '';
    final genres = media.mediaType == 'tv'
        ? tmdbTvGenreNames(media.genreIds)
        : tmdbMovieGenreNames(media.genreIds);
    return Material(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => pushTmdbMediaDetail(
          context,
          media,
          source: 'search-${media.mediaType}-${media.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: media.posterPath == null
                    ? Container(
                        width: 58,
                        height: 84,
                        color: Colors.white10,
                        child: const Icon(Broken.image, color: Colors.white24),
                      )
                    : Image.network(
                        'https://image.tmdb.org/t/p/w185${media.posterPath}',
                        width: 58,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 58,
                          height: 84,
                          color: Colors.white10,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            media.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (media.voteAverage != null)
                          '★ ${media.voteAverage!.toStringAsFixed(1)}',
                        if (y.isNotEmpty) y,
                        ...genres,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaResultsList extends StatelessWidget {
  final List<TmdbMedia> media;

  const _MediaResultsList({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const _SearchMessage(
        title: 'Aucun résultat',
        message: 'Essaie un autre titre.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: .62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final m = media[index];
        return PosterCard(
          item: ContentItem.fromTmdb(m),
          width: double.infinity,
          heroTag: 'search-${m.mediaType}-${m.id}-$index',
          onTap: () => pushTmdbMediaDetail(
            context,
            m,
            source: 'search-${m.mediaType}-${m.id}',
          ),
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  final TmdbPersonRef person;

  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/flixPerson', extra: person),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundImage: person.profileUrl == null
                    ? null
                    : NetworkImage(person.profileUrl!),
                child: person.profileUrl == null
                    ? const Icon(Broken.user, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (person.knownForDepartment?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          person.knownForDepartment!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .55),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleResultsList extends StatelessWidget {
  final List<TmdbPersonRef> people;

  const _PeopleResultsList({required this.people});

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const _SearchMessage(
        title: 'Aucune célébrité',
        message: 'Essaie un autre nom.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _PersonRow(person: people[index]),
    );
  }
}

class _CollectionsResultsList extends StatefulWidget {
  final String query;

  const _CollectionsResultsList({required this.query});

  @override
  State<_CollectionsResultsList> createState() =>
      _CollectionsResultsListState();
}

class _CollectionsResultsListState extends State<_CollectionsResultsList> {
  List<TmdbCollectionRef>? _collections;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CollectionsResultsList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _load();
  }

  Future<void> _load() async {
    try {
      final items = await fetchTmdbCollections(query: widget.query);
      if (!mounted) return;
      setState(() => _collections = items);
    } catch (_) {
      if (mounted) setState(() => _collections = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = _collections;
    if (collections == null) return const SharedSearchShimmerList(rows: 5);
    if (collections.isEmpty) {
      return const _SearchMessage(
        title: 'Aucune collection',
        message: 'Aucune sagas ou collections ne correspondent.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemCount: collections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = collections[index];
        return Material(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openCollection(context, c),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: c.posterUrl == null
                        ? Container(
                            width: 58,
                            height: 84,
                            color: Colors.white10,
                            child: const Icon(
                              Broken.box,
                              color: Colors.white24,
                            ),
                          )
                        : Image.network(
                            c.posterUrl!,
                            width: 58,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 58,
                              height: 84,
                              color: Colors.white10,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.collections_bookmark_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (c.overview?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              c.overview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .55),
                                fontSize: 11.5,
                              ),
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
      },
    );
  }

  Future<void> _openCollection(
    BuildContext context,
    TmdbCollectionRef c,
  ) async {
    final accent = Theme.of(context).colorScheme.primary;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .95,
        builder: (sheetContext, scrollController) =>
            FutureBuilder<List<TmdbMedia>>(
              future: fetchTmdbCollectionItems(c.id),
              builder: (sheetContext, snapshot) {
                final items = snapshot.data;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.collections_bookmark_outlined,
                            color: accent,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Broken.close_circle,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const SharedSearchShimmerList()
                          : GridView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 140,
                                    childAspectRatio: .62,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 14,
                                  ),
                              itemCount: items?.length ?? 0,
                              itemBuilder: (gridContext, index) {
                                final m = items![index];
                                return PosterCard(
                                  item: ContentItem.fromTmdb(m),
                                  width: double.infinity,
                                  heroTag: 'collection-${c.id}-$index',
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    pushTmdbMediaDetail(
                                      gridContext,
                                      m,
                                      source: 'collection-${c.id}-$index',
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message state
// ─────────────────────────────────────────────────────────────────────────────

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _SearchMessage({
    this.icon = Broken.search_status,
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
            Icon(icon, size: 54, color: accent.withValues(alpha: .8)),
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
