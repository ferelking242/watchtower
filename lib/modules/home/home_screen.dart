import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Could not reach AniList.\n$e',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(anilistHomeProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (home) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Floating header (hides on scroll down, reappears on scroll up) ──
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/app_icons/icon.png',
                      width: 36,
                      height: 36,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/more'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.8),
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Greeting ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                        children: [
                          const TextSpan(text: 'Hey '),
                          TextSpan(
                            text: 'Guest',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                          const TextSpan(
                              text: ', what are we\ndoing today?'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find your favourite anime or manga,\nmanhwa or whatever you like!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Hero carousel ──
            SliverToBoxAdapter(
              child: HeroCarousel(
                items: home.trendingAnimes.take(8).toList(),
                onItemTap: (m) => _openDetail(context, m),
              ),
            ),

            // ── Discovery rows ──
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
