import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/anime/anime_discovery_feed.dart'
    show AnimeDiscoveryLoadingScreen;
import 'package:watchtower/modules/anime/anilist_cinematic_hero.dart';
import 'package:watchtower/modules/media/widgets/wave_pull_refresh.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';

/// Novel tab — AniList-powered light-novel discover page (trending, popular,
/// latest) plus genre & origin category cards.
class NovelDiscoveryScreen extends ConsumerWidget {
  const NovelDiscoveryScreen({super.key});

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  void _seeAllNovels(BuildContext context, {String? genre}) {
    context.push(
      '/anilistBrowse',
      extra: (
        AnilistBrowseFilter(mediaType: 'MANGA', format: 'NOVEL', genre: genre),
        genre == null ? 'Light Novels' : '$genre Novels',
      ),
    );
  }

  List<AnilistMedia> _byGenre(List<AnilistMedia> all, String genre) {
    final seen = <int>{};
    final out = <AnilistMedia>[];
    for (final m in all) {
      if (seen.contains(m.id)) continue;
      if (m.genres.any((g) => g.toLowerCase() == genre.toLowerCase())) {
        seen.add(m.id);
        out.add(m);
      }
    }
    return out;
  }

  List<AnilistMedia> _byScore(List<AnilistMedia> all) {
    final seen = <int>{};
    final out = <AnilistMedia>[];
    for (final m in all) {
      if (seen.add(m.id)) out.add(m);
    }
    out.sort((a, b) => (b.averageScore ?? 0).compareTo(a.averageScore ?? 0));
    return out.take(15).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: asyncHome.when(
          loading: () => const AnimeDiscoveryLoadingScreen(),
          error: (e, _) => AniListErrorView(
            error: e,
            onRetry: () => ref.invalidate(anilistHomeProvider),
          ),
          data: (home) => WavePullRefresh(
            onRefresh: () async {
              ref.invalidate(anilistHomeProvider);
              await ref.read(anilistHomeProvider.future);
            },
            child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AnilistCinematicHero(
                  items: home.trendingNovels.take(10).toList(growable: false),
                  onTap: (index) {
                    final items = home.trendingNovels.take(10).toList(growable: false);
                    if (index < items.length) {
                      _openDetail(context, items[index]);
                    }
                  },
                  onLibraryPressed: () => context.push('/Library'),
                  onSearchPressed: () => context.push('/globalSearch'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    DiscoveryRow(
                      title: context.l10n.discover_row_trending_novels,
                      items: home.trendingNovels,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context),
                    ),
                    CategoryRow(
                      title: context.l10n.discover_row_genres,
                      categories: novelCategories(),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_popular_novels,
                      items: home.popularNovels,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_highly_rated,
                      items: home.latestNovels,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_top_rated,
                      items: _byScore(home.popularNovels + home.trendingNovels),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_fantasy,
                      items: _byGenre(
                        home.popularNovels + home.trendingNovels,
                        'Fantasy',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context, genre: 'Fantasy'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_romance,
                      items: _byGenre(
                        home.popularNovels + home.trendingNovels,
                        'Romance',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context, genre: 'Romance'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_action,
                      items: _byGenre(
                        home.popularNovels + home.trendingNovels,
                        'Action',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAllNovels(context, genre: 'Action'),
                    ),
                    const _NovelSourcesHint(),
                  ]),
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

class _NovelSourcesHint extends StatelessWidget {
  const _NovelSourcesHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sources de lecture',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AniList alimente le catalogue. Pour lire le texte complet '
                    'des web novels (Novel Updates, Royal Road, Scribble Hub, '
                    'Wattpad…), installez les extensions de novel dans Browse.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
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
}
