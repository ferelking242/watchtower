import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/film_series/services/tmdb_film_series_service.dart';

class FilmSeriesCatalogScreen extends ConsumerWidget {
  const FilmSeriesCatalogScreen({super.key, required this.mediaType});

  final String mediaType;

  bool get isMovie => mediaType == 'movie';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(
      tmdbFilmSeriesCatalogProvider((mediaType: mediaType, genreId: null)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(isMovie ? 'Catalogue films' : 'Catalogue séries'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/FilmSeriesSearch'),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CatalogError(
          error: error,
          onRetry: () => ref.invalidate(
            tmdbFilmSeriesCatalogProvider((
              mediaType: mediaType,
              genreId: null,
            )),
          ),
        ),
        data: (items) => _CatalogGrid(items: items, mediaType: mediaType),
      ),
    );
  }
}

class FilmSeriesGenreScreen extends ConsumerWidget {
  const FilmSeriesGenreScreen({
    super.key,
    required this.mediaType,
    required this.genreId,
    required this.genreName,
  });

  final String mediaType;
  final int genreId;
  final String genreName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(
      tmdbFilmSeriesCatalogProvider((mediaType: mediaType, genreId: genreId)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(genreName)),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CatalogError(
          error: error,
          onRetry: () => ref.invalidate(
            tmdbFilmSeriesCatalogProvider((
              mediaType: mediaType,
              genreId: genreId,
            )),
          ),
        ),
        data: (items) => _CatalogGrid(items: items, mediaType: mediaType),
      ),
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.items, required this.mediaType});

  final List<TmdbMedia> items;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucun contenu disponible.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 245,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final media = items[index];
        return TmdbPosterCard(
          media: media,
          width: 160,
          onTap: () => context.push(
            mediaType == 'movie' ? '/MovieDetail' : '/SeriesDetail',
            extra: {'id': media.id, 'mediaType': mediaType},
          ),
        );
      },
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          const Text('Le catalogue TMDB est indisponible.'),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
