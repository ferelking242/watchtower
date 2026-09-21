import 'package:collection/collection.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';
import 'package:watchtower/modules/media/flixquest_movie_widgets.dart';

enum MediaHubKind { movies, series }

class FlixMediaHomeScreen extends ConsumerWidget {
  final MediaHubKind kind;

  const FlixMediaHomeScreen({super.key, required this.kind});

  bool get isMovies => kind == MediaHubKind.movies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    final title = isMovies ? 'Movies' : 'Series';
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: home.when(
        loading: () => FlixQuestMediaLoading(
          isSeries: !isMovies,
          onSearchPressed: () => context.push('/flixSearch'),
          onLiveTVPressed: () => context.push('/liveTv'),
          onBookmarksPressed: () => context.push('/Library'),
          onRefresh: () async => ref.invalidate(tmdbHomeProvider),
        ),
        error: (error, _) => _MediaError(
          title: title,
          error: error,
          onRetry: () => ref.invalidate(tmdbHomeProvider),
        ),
        data: (data) => isMovies
            ? MainMoviesDisplay(home: data)
            : MainSeriesDisplay(home: data),
      ),
    );
  }
}

class _MediaHomeBody extends StatelessWidget {
  final MediaHubKind kind;
  final TmdbHome home;

  const _MediaHomeBody({required this.kind, required this.home});

  bool get isMovies => kind == MediaHubKind.movies;

  List<TmdbMedia> get trending =>
      isMovies ? home.trendingMovies : home.trendingTv;
  List<TmdbMedia> get popular => isMovies ? home.popularMovies : home.popularTv;
  List<TmdbMedia> get topRated =>
      isMovies ? home.topRatedMovies : home.topRatedTv;
  List<TmdbMedia> get latest =>
      isMovies ? home.nowPlayingMovies : home.airingTodayTv;

  @override
  Widget build(BuildContext context) {
    final hero = trending.firstOrNull ?? popular.firstOrNull;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _MediaHero(
            title: isMovies ? 'Home Movies' : 'Home Series',
            media: hero,
            onOpen: hero == null
                ? null
                : () => context.push('/flixMediaDetail', extra: hero),
          ),
        ),
        SliverToBoxAdapter(child: _MediaTabs(kind: kind)),
        _MediaRow(
          title: 'Trending',
          items: trending,
          accent: const Color(0xFFE50914),
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        ),
        _MediaRow(
          title: isMovies ? 'Films populaires' : 'Séries populaires',
          items: popular,
          accent: const Color(0xFFFFB703),
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        ),
        _MediaRow(
          title: isMovies ? 'Nouveautés' : 'À suivre aujourd’hui',
          items: latest,
          accent: const Color(0xFF4CC9F0),
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        ),
        _MediaRow(
          title: 'Les mieux notés',
          items: topRated,
          accent: const Color(0xFFB5179E),
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 92)),
      ],
    );
  }
}

class _MediaHero extends StatelessWidget {
  final String title;
  final TmdbMedia? media;
  final VoidCallback? onOpen;

  const _MediaHero({required this.title, required this.media, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 450,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media?.bannerImage != null)
            ExtendedImage.network(media!.bannerImage!, fit: BoxFit.cover)
          else
            Container(color: theme.colorScheme.surfaceContainerHighest),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0B0B11)],
                stops: [0.3, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media?.displayTitle ?? title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (media?.overview?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      media!.overview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Broken.info_circle),
                    label: const Text('Voir le détail'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTabs extends StatelessWidget {
  final MediaHubKind kind;

  const _MediaTabs({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Row(
        children: [
          const _TabPill(label: 'Tout', selected: true),
          const SizedBox(width: 8),
          _TabPill(label: kind == MediaHubKind.movies ? 'Films' : 'Séries'),
          const SizedBox(width: 8),
          const _TabPill(label: 'Favoris'),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabPill({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE50914) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: selected ? 1 : 0.65),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final String title;
  final List<TmdbMedia> items;
  final Color accent;
  final ValueChanged<TmdbMedia> onTap;

  const _MediaRow({
    required this.title,
    required this.items,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 204,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (_, index) => TmdbPosterCard(
                  media: items[index],
                  width: 126,
                  onTap: () => onTap(items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;

  const _MediaError({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Broken.wifi, color: Colors.white54, size: 44),
            const SizedBox(height: 14),
            Text(
              '$title est temporairement indisponible',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger le catalogue TMDB. Réessayez lorsque la connexion sera disponible.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
