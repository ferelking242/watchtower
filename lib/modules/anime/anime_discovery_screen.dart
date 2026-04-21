import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';

/// Anime tab — AniList-powered discover page (trending, popular, upcoming).
class AnimeDiscoveryScreen extends ConsumerWidget {
  const AnimeDiscoveryScreen({super.key});

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: asyncHome.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Could not reach AniList',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(anilistHomeProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (home) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Anime',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
                  ),
                  DiscoveryRow(
                    title: 'Popular Anime',
                    items: home.popularAnimes,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                  DiscoveryRow(
                    title: 'Upcoming Anime',
                    items: home.upcomingAnimes,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                  DiscoveryRow(
                    title: 'Recently Updated',
                    items: home.recentlyUpdatedAnimes,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                  DiscoveryRow(
                    title: 'Recently Completed',
                    items: home.latestAnimes,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
