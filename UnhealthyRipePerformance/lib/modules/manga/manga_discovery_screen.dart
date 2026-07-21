import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';

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

  void _seeAll(BuildContext context, String label,
      {String? country, String? genre}) {
    context.push(
      '/anilistBrowse',
      extra: (
        AnilistBrowseFilter(
          mediaType: 'MANGA',
          country: country,
          genre: genre,
        ),
        label
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LibraryHeaderBar(itemType: ItemType.manga),
            Expanded(
              child: asyncHome.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => AniListErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(anilistHomeProvider),
                ),
                data: (home) => CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: HeroCarousel(
                        items: home.trendingMangas.take(8).toList(),
                        onItemTap: (m) => _openDetail(context, m),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          DiscoveryRow(
                            title: 'Trending Manga',
                            items: home.trendingMangas,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () =>
                                _seeAll(context, 'Manga', country: 'JP'),
                          ),
                          CategoryRow(
                            title: 'Origines',
                            categories: mangaOrigins(),
                          ),
                          DiscoveryRow(
                            title: 'Popular Manga',
                            items: home.popularMangas,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () =>
                                _seeAll(context, 'Popular Manga', country: 'JP'),
                          ),
                          CategoryRow(
                            title: 'Genres',
                            categories: mangaCategories(),
                          ),
                          DiscoveryRow(
                            title: 'Trending Manhwa',
                            items: home.trendingManhwa,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () =>
                                _seeAll(context, 'Manhwa', country: 'KR'),
                          ),
                          DiscoveryRow(
                            title: 'Trending Manhua',
                            items: home.trendingManhua,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () =>
                                _seeAll(context, 'Manhua', country: 'CN'),
                          ),
                          DiscoveryRow(
                            title: 'Highly Rated Completed',
                            items: home.latestMangas,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () =>
                                _seeAll(context, 'Manga', country: 'JP'),
                          ),
                          DiscoveryRow(
                            title: 'Top Rated',
                            items: _byScore(home.popularMangas + home.trendingMangas),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => _seeAll(context, 'Top Rated Manga'),
                          ),
                          DiscoveryRow(
                            title: 'Action',
                            items: _byGenre(home.popularMangas + home.trendingMangas + home.trendingManhwa, 'Action'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => _seeAll(context, 'Action', genre: 'Action'),
                          ),
                          DiscoveryRow(
                            title: 'Romance',
                            items: _byGenre(home.popularMangas + home.trendingMangas + home.trendingManhwa, 'Romance'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => _seeAll(context, 'Romance', genre: 'Romance'),
                          ),
                          DiscoveryRow(
                            title: 'Fantasy',
                            items: _byGenre(home.popularMangas + home.trendingMangas + home.trendingManhwa, 'Fantasy'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => _seeAll(context, 'Fantasy', genre: 'Fantasy'),
                          ),
                          DiscoveryRow(
                            title: 'Slice of Life',
                            items: _byGenre(home.popularMangas + home.trendingMangas, 'Slice of Life'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => _seeAll(context, 'Slice of Life', genre: 'Slice of Life'),
                          ),
                        ]),
                      ),
                    ),
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
