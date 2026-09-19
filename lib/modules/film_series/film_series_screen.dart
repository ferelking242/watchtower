import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/film_series/services/tmdb_film_series_service.dart';

class FilmSeriesHomeScreen extends ConsumerWidget {
  const FilmSeriesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Films & Séries'),
          actions: [
            IconButton(
              tooltip: 'Rechercher',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/FilmSeriesSearch'),
            ),
            IconButton(
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(tmdbHomeProvider),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Films', icon: Icon(Icons.movie_outlined)),
              Tab(text: 'Séries', icon: Icon(Icons.tv_outlined)),
            ],
          ),
        ),
        body: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(tmdbHomeProvider),
          ),
          data: (data) => TabBarView(
            children: [
              _HomeTab(
                rows: [
                  ('Tendances', data.trendingMovies),
                  ('En salle', data.nowPlayingMovies),
                  ('Les mieux notés', data.topRatedMovies),
                  ('Populaires', data.popularMovies),
                  ('Prochainement', data.upcomingMovies),
                ],
                mediaType: 'movie',
              ),
              _HomeTab(
                rows: [
                  ('Tendances', data.trendingTv),
                  ('En diffusion', data.onTheAirTv),
                  ('Aujourd’hui', data.airingTodayTv),
                  ('Les mieux notées', data.topRatedTv),
                  ('Populaires', data.popularTv),
                ],
                mediaType: 'tv',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.rows, required this.mediaType});

  final List<(String, List<TmdbMedia>)> rows;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = rows.where((row) => row.$2.isNotEmpty).toList();
    return RefreshIndicator(
      onRefresh: () async {
        final container = ProviderScope.containerOf(context);
        container.invalidate(tmdbHomeProvider);
        await container.read(tmdbHomeProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          _IntroBanner(mediaType: mediaType),
          const SizedBox(height: 20),
          for (final row in nonEmpty)
            _MediaRow(title: row.$1, items: row.$2, mediaType: mediaType),
          if (nonEmpty.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('Aucun contenu TMDB disponible.')),
            ),
        ],
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.mediaType});

  final String mediaType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.surfaceContainerHighest],
          ),
        ),
        child: Row(
          children: [
            Icon(
              mediaType == 'movie' ? Icons.local_movies : Icons.live_tv,
              size: 38,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mediaType == 'movie'
                    ? 'Découvrez les films suivis par TMDB.'
                    : 'Retrouvez les séries, saisons et épisodes TMDB.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.title,
    required this.items,
    required this.mediaType,
  });

  final String title;
  final List<TmdbMedia> items;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.push(
                mediaType == 'movie' ? '/MoviesCatalog' : '/SeriesCatalog',
              ),
              child: const Text('Tout voir'),
            ),
          ],
        ),
        SizedBox(
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final media = items[index];
              return TmdbPosterCard(
                media: media,
                onTap: () => context.push(
                  mediaType == 'movie' ? '/MovieDetail' : '/SeriesDetail',
                  extra: {'id': media.id, 'mediaType': mediaType},
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('Impossible de charger TMDB.'),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}
