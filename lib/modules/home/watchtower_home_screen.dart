import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart'
    show AniListErrorView;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';

/// MovieBox-style home screen — AnymeX-style header + hero banner + curated rows.
/// Le header devient progressivement un frosted-glass quand on scrolle.
class WatchtowerHomeScreen extends ConsumerStatefulWidget {
  const WatchtowerHomeScreen({super.key});

  @override
  ConsumerState<WatchtowerHomeScreen> createState() =>
      _WatchtowerHomeScreenState();
}

class _WatchtowerHomeScreenState extends ConsumerState<WatchtowerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if ((offset - _scrollOffset).abs() > 1) {
        setState(() => _scrollOffset = offset.clamp(0.0, double.infinity));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  void _browseTo(BuildContext context, String mediaType, {String? genre}) {
    context.push(
      '/anilistBrowse',
      extra: (
        AnilistBrowseFilter(mediaType: mediaType, genre: genre),
        genre ?? mediaType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncHome = ref.watch(anilistHomeProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────────────
          asyncHome.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AniListErrorView(
              error: e,
              onRetry: () => ref.invalidate(anilistHomeProvider),
            ),
            data: (home) {
              final heroItems = [
                ...home.trendingAnimes.take(4),
                ...home.trendingMangas.take(4),
              ]..shuffle();

              final trendingAll = [
                ...home.trendingAnimes.take(10),
                ...home.trendingMangas.take(10),
              ]..sort((a, b) =>
                  (b.averageScore ?? 0).compareTo(a.averageScore ?? 0));

              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Space reserved for the floating header ────────────
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),

                  // ── Hero carousel ─────────────────────────────────────
                  if (heroItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: HeroCarousel(
                        items: heroItems.take(8).toList(),
                        onItemTap: (m) => _openDetail(context, m),
                      ),
                    ),

                // ── Explore chips ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      'Explore',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      children: [
                        _GenreChip(
                          label: 'All Anime',
                          color: Colors.indigo,
                          onTap: () => _browseTo(context, 'ANIME'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'All Manga',
                          color: Colors.teal,
                          onTap: () => _browseTo(context, 'MANGA'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'Action',
                          color: Colors.red,
                          onTap: () =>
                              _browseTo(context, 'ANIME', genre: 'Action'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'Romance',
                          color: Colors.pink,
                          onTap: () =>
                              _browseTo(context, 'ANIME', genre: 'Romance'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'Fantasy',
                          color: Colors.purple,
                          onTap: () =>
                              _browseTo(context, 'ANIME', genre: 'Fantasy'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'Sci-Fi',
                          color: Colors.cyan,
                          onTap: () =>
                              _browseTo(context, 'ANIME', genre: 'Sci-Fi'),
                        ),
                        const SizedBox(width: 8),
                        _GenreChip(
                          label: 'Comedy',
                          color: Colors.amber,
                          onTap: () =>
                              _browseTo(context, 'ANIME', genre: 'Comedy'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Trending Today ──────────────────────────────────────────
                if (trendingAll.isNotEmpty)
                  _MediaRow(
                    title: 'Trending Today',
                    items: trendingAll.take(15).toList(),
                    onTap: (m) => _openDetail(context, m),
                  ),

                // ── Trending Anime ──────────────────────────────────────────
                if (home.trendingAnimes.isNotEmpty)
                  _MediaRow(
                    title: 'Trending Anime',
                    items: home.trendingAnimes,
                    onTap: (m) => _openDetail(context, m),
                    trailing: TextButton(
                      onPressed: () => _browseTo(context, 'ANIME'),
                      child: const Text('See all'),
                    ),
                  ),

                // ── Popular Manga ───────────────────────────────────────────
                if (home.popularMangas.isNotEmpty)
                  _MediaRow(
                    title: 'Popular Manga',
                    items: home.popularMangas,
                    onTap: (m) => _openDetail(context, m),
                    trailing: TextButton(
                      onPressed: () => _browseTo(context, 'MANGA'),
                      child: const Text('See all'),
                    ),
                  ),

                // ── Trending Manhwa ─────────────────────────────────────────
                if (home.trendingManhwa.isNotEmpty)
                  _MediaRow(
                    title: 'Trending Manhwa',
                    items: home.trendingManhwa,
                    onTap: (m) => _openDetail(context, m),
                  ),

                // ── Light Novels ────────────────────────────────────────────
                if (home.trendingNovels.isNotEmpty)
                  _MediaRow(
                    title: 'Light Novels',
                    items: home.trendingNovels,
                    onTap: (m) => _openDetail(context, m),
                  ),

                // ── Games & Music promo ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PromoCard(
                            icon: Icons.sports_esports_rounded,
                            title: 'Games',
                            subtitle: 'ROM library',
                            color: Colors.indigo,
                            onTap: () => context.go('/GameLibrary'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PromoCard(
                            icon: Icons.music_note_rounded,
                            title: 'Music',
                            subtitle: 'Stream & download',
                            color: Colors.purple,
                            onTap: () => context.go('/MusicLibrary'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),

          // ── Floating frosted header — always on top ───────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeHeader(scrollOffset: _scrollOffset),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal media row ─────────────────────────────────────────────────────

class _MediaRow extends StatelessWidget {
  final String title;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onTap;
  final Widget? trailing;

  const _MediaRow({
    required this.title,
    required this.items,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => DiscoveryCard(
                media: items[i],
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Genre chip ───────────────────────────────────────────────────────────────

class _GenreChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Promo card (Games / Music) ───────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PromoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.55),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
