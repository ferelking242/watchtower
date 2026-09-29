import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AniList search provider (auto-dispose, family-keyed by query string)
// ─────────────────────────────────────────────────────────────────────────────

final _anilistSearchProvider =
    FutureProvider.autoDispose.family<List<AnilistMedia>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return [];

    const endpoint = 'https://graphql.anilist.co';
    const gql = r'''
query ($q: String) {
  a: Page(perPage: 15) {
    media(search: $q, type: ANIME, sort: POPULARITY_DESC) {
      id type format countryOfOrigin averageScore episodes
      title { romaji english native }
      coverImage { large extraLarge }
      bannerImage genres
    }
  }
  m: Page(perPage: 8) {
    media(search: $q, type: MANGA, sort: POPULARITY_DESC) {
      id type format countryOfOrigin averageScore chapters
      title { romaji english native }
      coverImage { large extraLarge }
      bannerImage genres
    }
  }
}''';

    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'query': gql, 'variables': {'q': query}}),
    );

    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    List<AnilistMedia> parse(String key) {
      final list = (data[key]?['media'] as List?) ?? [];
      return list
          .map((e) => AnilistMedia.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [...parse('a'), ...parse('m')];
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Main search screen
// ─────────────────────────────────────────────────────────────────────────────

class WatchtowerSearchScreen extends ConsumerStatefulWidget {
  const WatchtowerSearchScreen({super.key});

  @override
  ConsumerState<WatchtowerSearchScreen> createState() =>
      _WatchtowerSearchScreenState();
}

class _WatchtowerSearchScreenState
    extends ConsumerState<WatchtowerSearchScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  // Per-session recent searches (static so they survive hot-reload)
  static final List<String> _recents = [];

  late final TabController _beforeTabs =
      TabController(length: 2, vsync: this);
  late final TabController _afterTabs =
      TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _beforeTabs.dispose();
    _afterTabs.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    if (!_recents.contains(q)) {
      _recents.insert(0, q);
      if (_recents.length > 12) _recents.removeLast();
    }
    setState(() => _query = q);
    _focus.unfocus();
  }

  void _clearQuery() {
    _ctrl.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(cs),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _query.isEmpty
            ? _EmptyState(
                key: const ValueKey('empty'),
                recents: _recents,
                beforeTabs: _beforeTabs,
                onSearch: (q) {
                  _ctrl.text = q;
                  _submit(q);
                },
                onRemoveRecent: (r) => setState(() => _recents.remove(r)),
              )
            : _ResultsState(
                key: ValueKey('results:$_query'),
                query: _query,
                afterTabs: _afterTabs,
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: TextField(
        controller: _ctrl,
        focusNode: _focus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        onChanged: (v) {
          if (v.isEmpty && _query.isNotEmpty) setState(() => _query = '');
        },
        decoration: InputDecoration(
          hintText: 'Film, série, anime, musique…',
          border: InputBorder.none,
          isDense: true,
          hintStyle: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.40),
            fontSize: 15,
          ),
        ),
        style: TextStyle(color: cs.onSurface, fontSize: 15),
      ),
      actions: [
        if (_query.isNotEmpty)
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20, color: cs.onSurface.withValues(alpha: 0.55)),
            onPressed: _clearQuery,
          ),
        IconButton(
          icon: Icon(Icons.mic_rounded,
              color: cs.onSurface.withValues(alpha: 0.55)),
          onPressed: () {},
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
          child: FilledButton(
            onPressed: () => _submit(_ctrl.text),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2DCE6C),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Recherche',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color:
              Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — shown before user types a query
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  final List<String> recents;
  final TabController beforeTabs;
  final void Function(String) onSearch;
  final void Function(String) onRemoveRecent;

  const _EmptyState({
    super.key,
    required this.recents,
    required this.beforeTabs,
    required this.onSearch,
    required this.onRemoveRecent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncHome = ref.watch(anilistHomeProvider);

    return asyncHome.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (home) {
        final trending = home.trendingAnimes.take(14).toList();
        final topFilms = (List<AnilistMedia>.from(home.animeMovies)
              ..sort((a, b) =>
                  (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
            .take(10)
            .toList();
        final topSeries = (List<AnilistMedia>.from(home.popularAnimes)
              ..sort((a, b) =>
                  (b.averageScore ?? 0).compareTo(a.averageScore ?? 0)))
            .take(10)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Recent searches ──────────────────────────────────
                    if (recents.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Récents',
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: recents
                              .map(
                                (r) => _RecentChip(
                                  label: r,
                                  onTap: () => onSearch(r),
                                  onDelete: () => onRemoveRecent(r),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Trending pills ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            'Tout le monde recherche',
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trending.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => onSearch(trending[i].displayTitle),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer
                                  .withValues(alpha: 0.50),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.22),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              trending[i].displayTitle,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Ranked tabs ───────────────────────────────────────
                    TabBar(
                      controller: beforeTabs,
                      tabs: const [Tab(text: 'Film'), Tab(text: 'Série')],
                      indicatorColor: cs.primary,
                      labelColor: cs.primary,
                      unselectedLabelColor:
                          cs.onSurface.withValues(alpha: 0.50),
                      dividerColor: Colors.transparent,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      labelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(
                      height: 480,
                      child: TabBarView(
                        controller: beforeTabs,
                        children: [
                          _RankedTabList(
                            items: topFilms,
                            onTap: (m) => onSearch(m.displayTitle),
                          ),
                          _RankedTabList(
                            items: topSeries,
                            onTap: (m) => onSearch(m.displayTitle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results state — shown after user submits a query
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsState extends ConsumerWidget {
  final String query;
  final TabController afterTabs;

  const _ResultsState({
    super.key,
    required this.query,
    required this.afterTabs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(_anilistSearchProvider(query));

    return Column(
      children: [
        TabBar(
          controller: afterTabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Films'),
            Tab(text: 'Séries'),
            Tab(text: 'Anime'),
            Tab(text: 'Watch'),
          ],
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.50),
          dividerColor: cs.outlineVariant.withValues(alpha: 0.25),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48,
                      color: cs.onSurface.withValues(alpha: 0.30)),
                  const SizedBox(height: 12),
                  Text('Erreur de recherche',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
            data: (all) {
              final films =
                  all.where((m) => m.format == 'MOVIE').toList();
              final series = all
                  .where(
                      (m) => m.type == 'ANIME' && m.format != 'MOVIE')
                  .toList();
              final anime =
                  all.where((m) => m.type == 'ANIME').toList();

              // Always return a TabBarView so Watch tab is always reachable
              Widget anilistEmpty = Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.28)),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun résultat AniList pour "$query"',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.50)),
                    ),
                  ],
                ),
              );

              return TabBarView(
                controller: afterTabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  all.isEmpty ? anilistEmpty : _SearchResultList(items: all),
                  films.isEmpty ? anilistEmpty : _SearchResultList(items: films),
                  series.isEmpty ? anilistEmpty : _SearchResultList(items: series),
                  anime.isEmpty ? anilistEmpty : _SearchResultList(items: anime),
                  _WatchSearchTab(query: query),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Recent chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.40), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close_rounded,
                  size: 13, color: cs.onSurface.withValues(alpha: 0.40)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ranked list shown in Film / Série tabs (before search)
// ─────────────────────────────────────────────────────────────────────────────

class _RankedTabList extends StatelessWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;

  const _RankedTabList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text('Aucune donnée',
            style:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.40))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return InkWell(
          onTap: () => onTap(m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Rank number
                SizedBox(
                  width: 30,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: i < 3
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.30),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: m.bestCover != null
                      ? ExtendedImage.network(
                          m.bestCover!,
                          width: 44,
                          height: 62,
                          fit: BoxFit.cover,
                          cache: true,
                          loadStateChanged: (s) {
                            if (s.extendedImageLoadState ==
                                LoadState.completed) return null;
                            return Container(
                                color:
                                    cs.surfaceContainerHighest);
                          },
                        )
                      : Container(
                          width: 44,
                          height: 62,
                          color: cs.surfaceContainerHighest),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (m.averageScore != null) ...[
                            const Icon(Icons.star_rounded,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              (m.averageScore! / 10).toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (m.format != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.format!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result list (after search)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultList extends StatelessWidget {
  final List<AnilistMedia> items;
  const _SearchResultList({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text('Aucun résultat',
            style:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.40))),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
          height: 1,
          color: cs.outlineVariant.withValues(alpha: 0.18),
          indent: 90),
      itemBuilder: (context, i) => _SearchResultTile(media: items[i]),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final AnilistMedia media;
  const _SearchResultTile({required this.media});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final typeIcon = media.type == 'MANGA'
        ? Icons.menu_book_rounded
        : media.format == 'MOVIE'
            ? Icons.movie_rounded
            : Icons.live_tv_rounded;

    final country = media.countryOfOrigin;
    final flagEmoji = country == 'JP'
        ? '🇯🇵'
        : country == 'KR'
            ? '🇰🇷'
            : country == 'CN'
                ? '🇨🇳'
                : country == 'TW'
                    ? '🇹🇼'
                    : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: media.bestCover != null
                ? ExtendedImage.network(
                    media.bestCover!,
                    width: 60,
                    height: 85,
                    fit: BoxFit.cover,
                    cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed)
                        return null;
                      return Container(
                          color: cs.surfaceContainerHighest);
                    },
                  )
                : Container(
                    width: 60,
                    height: 85,
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: cs.onSurface.withValues(alpha: 0.30)),
                  ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(typeIcon, size: 13, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      media.format ?? media.type,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (media.averageScore != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        (media.averageScore! / 10).toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (flagEmoji.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(flagEmoji,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (media.genres.isNotEmpty)
                  Text(
                    media.genres.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.50),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Play button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: cs.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watch tab — navigates to GlobalSearch for watch extensions (ItemType.anime)
// Shows the same filter chips & source list as the manga global search.
// ─────────────────────────────────────────────────────────────────────────────

class _WatchSearchTab extends StatelessWidget {
  final String query;
  const _WatchSearchTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle_outline_rounded,
                  size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Rechercher dans Watch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cherche « $query » dans toutes tes extensions Watch installées, avec filtres par langue, source et plus.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push(
                '/globalSearch',
                extra: (query, ItemType.anime),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Ouvrir la recherche Watch'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            if (!isDark)
              OutlinedButton.icon(
                onPressed: () => context.push('/globalSearch'),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Recherche globale'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => context.push('/globalSearch'),
                icon: Icon(Icons.search_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.65)),
                label: Text('Recherche globale',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.65))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: cs.outline.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
