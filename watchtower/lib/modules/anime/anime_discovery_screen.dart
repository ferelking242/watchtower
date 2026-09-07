import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';
import 'package:watchtower/models/manga.dart';

/// Anime tab — AniList-powered discover page (trending, popular, upcoming).
class AnimeDiscoveryScreen extends ConsumerWidget {
  const AnimeDiscoveryScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LibraryHeaderBar(itemType: ItemType.anime),
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
                        items: home.trendingAnimes.take(8).toList(),
                        onItemTap: (m) => _openDetail(context, m),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          DiscoveryRow(
                            title: 'Recommended Anime',
                            items: home.trendingAnimes,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME'),
                                'Anime'
                              ),
                            ),
                          ),
                          CategoryRow(
                            title: 'Genres',
                            categories: animeCategories(),
                          ),
                          DiscoveryRow(
                            title: 'Popular Anime',
                            items: home.popularAnimes,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push('/globalSearch',
                                extra: (null, ItemType.anime)),
                          ),
                          DiscoveryRow(
                            title: 'Upcoming Anime',
                            items: home.upcomingAnimes,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push('/globalSearch',
                                extra: (null, ItemType.anime)),
                          ),
                          DiscoveryRow(
                            title: 'Recently Updated',
                            items: home.recentlyUpdatedAnimes,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push('/globalSearch',
                                extra: (null, ItemType.anime)),
                          ),
                          DiscoveryRow(
                            title: 'Recently Completed',
                            items: home.latestAnimes,
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push('/globalSearch',
                                extra: (null, ItemType.anime)),
                          ),
                          DiscoveryRow(
                            title: 'Top Rated',
                            items: _byScore(home.popularAnimes + home.trendingAnimes),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME'),
                                'Top Rated Anime'
                              ),
                            ),
                          ),
                          DiscoveryRow(
                            title: 'Action',
                            items: _byGenre(home.popularAnimes + home.trendingAnimes, 'Action'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME', genre: 'Action'),
                                'Action Anime'
                              ),
                            ),
                          ),
                          DiscoveryRow(
                            title: 'Romance',
                            items: _byGenre(home.popularAnimes + home.trendingAnimes, 'Romance'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME', genre: 'Romance'),
                                'Romance Anime'
                              ),
                            ),
                          ),
                          DiscoveryRow(
                            title: 'Comedy',
                            items: _byGenre(home.popularAnimes + home.trendingAnimes, 'Comedy'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME', genre: 'Comedy'),
                                'Comedy Anime'
                              ),
                            ),
                          ),
                          DiscoveryRow(
                            title: 'Fantasy',
                            items: _byGenre(home.popularAnimes + home.trendingAnimes, 'Fantasy'),
                            onItemTap: (m) => _openDetail(context, m),
                            onSeeAll: () => context.push(
                              '/anilistBrowse',
                              extra: (
                                const AnilistBrowseFilter(mediaType: 'ANIME', genre: 'Fantasy'),
                                'Fantasy Anime'
                              ),
                            ),
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

class AniListErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const AniListErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = error.toString().toLowerCase();
    final isNet = msg.contains('socket') ||
        msg.contains('failed host') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection');
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNet ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              isNet ? 'No internet connection' : 'Could not reach AniList',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isNet
                  ? 'Check your Wi-Fi or mobile data and try again.'
                  : 'AniList is unreachable right now. It may be down or rate-limiting.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
