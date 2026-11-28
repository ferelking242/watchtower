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

/// Manga tab — AniList-powered discover page with origin sub-rows
/// (manga / manhwa / manhua) and genre category cards.
class MangaDiscoveryScreen extends ConsumerWidget {
  const MangaDiscoveryScreen({super.key});

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
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

  void _seeAll(
    BuildContext context,
    String label, {
    String? country,
    String? genre,
  }) {
    context.push(
      '/anilistBrowse',
      extra: (
        AnilistBrowseFilter(mediaType: 'MANGA', country: country, genre: genre),
        label,
      ),
    );
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
                  items: home.trendingMangas.take(10).toList(growable: false),
                  onTap: (index) {
                    final items = home.trendingMangas.take(10).toList(growable: false);
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
                      title: context.l10n.discover_row_trending_manga,
                      items: home.trendingMangas,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(context, 'Manga', country: 'JP'),
                    ),
                    CategoryRow(
                      title: context.l10n.discover_row_origins,
                      categories: mangaOrigins(context.l10n),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_popular_manga,
                      items: home.popularMangas,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () =>
                          _seeAll(context, 'Popular Manga', country: 'JP'),
                    ),
                    CategoryRow(
                      title: context.l10n.discover_row_genres,
                      categories: mangaCategories(),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_trending_manhwa,
                      items: home.trendingManhwa,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(context, 'Manhwa', country: 'KR'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_trending_manhua,
                      items: home.trendingManhua,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(context, 'Manhua', country: 'CN'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_highly_rated,
                      items: home.latestMangas,
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(context, 'Manga', country: 'JP'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_top_rated,
                      items: _byScore(home.popularMangas + home.trendingMangas),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(context, 'Top Rated Manga'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_action,
                      items: _byGenre(
                        home.popularMangas +
                            home.trendingMangas +
                            home.trendingManhwa,
                        'Action',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () =>
                          _seeAll(context, 'Action', genre: 'Action'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_romance,
                      items: _byGenre(
                        home.popularMangas +
                            home.trendingMangas +
                            home.trendingManhwa,
                        'Romance',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () =>
                          _seeAll(context, 'Romance', genre: 'Romance'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_fantasy,
                      items: _byGenre(
                        home.popularMangas +
                            home.trendingMangas +
                            home.trendingManhwa,
                        'Fantasy',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () =>
                          _seeAll(context, 'Fantasy', genre: 'Fantasy'),
                    ),
                    DiscoveryRow(
                      title: context.l10n.discover_row_slice_of_life,
                      items: _byGenre(
                        home.popularMangas + home.trendingMangas,
                        'Slice of Life',
                      ),
                      onItemTap: (m) => _openDetail(context, m),
                      onSeeAll: () => _seeAll(
                        context,
                        'Slice of Life',
                        genre: 'Slice of Life',
                      ),
                    ),
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
