import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';

/// Manga tab — AniList-powered discover page (trending, popular, latest).
class MangaDiscoveryScreen extends ConsumerWidget {
  const MangaDiscoveryScreen({super.key});

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
                'Manga',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
                    title: 'Recommended Manga',
                    items: home.trendingMangas,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                  DiscoveryRow(
                    title: 'Popular Manga',
                    items: home.popularMangas,
                    onItemTap: (m) => _openDetail(context, m),
                  ),
                  DiscoveryRow(
                    title: 'Latest Manga',
                    items: home.latestMangas,
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
