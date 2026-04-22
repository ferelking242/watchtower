import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';

/// Manga tab — AniList-powered discover page with origin sub-rows
/// (manga / manhwa / manhua) and genre category cards.
class MangaDiscoveryScreen extends ConsumerWidget {
  const MangaDiscoveryScreen({super.key});

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
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
            const LibraryHeaderBar(),
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
