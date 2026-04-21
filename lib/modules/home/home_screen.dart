import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';

/// AnymeX-style discovery home: trending / popular / upcoming AniList content
/// shown without requiring any extension. Tapping an item routes to the
/// global search so the user can pick an extension to actually play / read.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openSearch(BuildContext context, AnilistMedia media) {
    final type = media.type == 'MANGA' ? ItemType.manga : ItemType.anime;
    context.push('/globalSearch', extra: (media.displayTitle, type));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(anilistHomeProvider.future),
        child: asyncHome.when(
          loading: () => ListView(
            children: const [
              SizedBox(height: 240),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Could not reach AniList.\n$e',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(anilistHomeProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (home) => ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const SizedBox(height: 8),
              HeroCarousel(
                items: home.trendingAnimes.take(8).toList(),
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Trending Anime',
                items: home.trendingAnimes,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Popular Anime',
                items: home.popularAnimes,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Upcoming Anime',
                items: home.upcomingAnimes,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Recently Updated',
                items: home.recentlyUpdatedAnimes,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Recently Completed',
                items: home.latestAnimes,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Trending Manga',
                items: home.trendingMangas,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Popular Manga',
                items: home.popularMangas,
                onItemTap: (m) => _openSearch(context, m),
              ),
              DiscoveryRow(
                title: 'Latest Manga',
                items: home.latestMangas,
                onItemTap: (m) => _openSearch(context, m),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
