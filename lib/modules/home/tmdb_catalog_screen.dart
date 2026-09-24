import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';

enum TmdbCatalogKind { movies, series }

class TmdbCatalogScreen extends ConsumerWidget {
  const TmdbCatalogScreen({super.key, required this.kind});

  final TmdbCatalogKind kind;

  bool get isMovies => kind == TmdbCatalogKind.movies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    final title = isMovies ? 'Films' : 'Séries';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(tmdbHomeProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TmdbCatalogError(
          error: error,
          onRetry: () => ref.invalidate(tmdbHomeProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(tmdbHomeProvider),
          child: _TmdbCatalogList(kind: kind, data: data),
        ),
      ),
    );
  }
}

class _TmdbCatalogList extends StatelessWidget {
  const _TmdbCatalogList({required this.kind, required this.data});

  final TmdbCatalogKind kind;
  final TmdbHome data;

  @override
  Widget build(BuildContext context) {
    final isMovies = kind == TmdbCatalogKind.movies;
    final sections = isMovies
        ? <(String, IconData, List<TmdbMedia>)>[
            ('En ce moment', Icons.theaters_rounded, data.nowPlayingMovies),
            (
              'Tendances de la semaine',
              Icons.local_fire_department_rounded,
              data.trendingMovies,
            ),
            (
              'Les mieux notés',
              Icons.emoji_events_rounded,
              data.topRatedMovies,
            ),
            ('Films populaires', Icons.star_rounded, data.popularMovies),
            ('Prochainement', Icons.upcoming_rounded, data.upcomingMovies),
          ]
        : <(String, IconData, List<TmdbMedia>)>[
            (
              'Tendances de la semaine',
              Icons.local_fire_department_rounded,
              data.trendingTv,
            ),
            ('En cours de diffusion', Icons.live_tv_rounded, data.onTheAirTv),
            (
              'Diffusées aujourd’hui',
              Icons.fiber_new_rounded,
              data.airingTodayTv,
            ),
            (
              'Les mieux notées',
              Icons.workspace_premium_rounded,
              data.topRatedTv,
            ),
            ('Séries populaires', Icons.star_rounded, data.popularTv),
          ];

    final nonEmpty = sections.where((section) => section.$3.isNotEmpty);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          isMovies
              ? 'Les films du moment, avec leurs affiches et informations TMDB.'
              : 'Les séries du moment, avec leurs affiches et informations TMDB.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        for (final section in nonEmpty)
          _TmdbSection(title: section.$1, icon: section.$2, items: section.$3),
        if (nonEmpty.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('Aucun contenu disponible.')),
          ),
      ],
    );
  }
}

class _TmdbSection extends StatelessWidget {
  const _TmdbSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<TmdbMedia> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(20).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 222,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final media = visible[index];
                final source = 'catalog-$index';
                return PosterCard(
                  item: ContentItem.fromTmdb(media),
                  width: 132,
                  heroTag: tmdbHeroTag(media, source),
                  onTap: () =>
                      pushTmdbMediaDetail(context, media, source: source),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, TmdbMedia media) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media.displayTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (media.voteAverage != null)
                Text('Note TMDB : ${media.voteAverage!.toStringAsFixed(1)}/10'),
              if (media.releaseDate != null || media.firstAirDate != null)
                Text('Date : ${media.releaseDate ?? media.firstAirDate}'),
              if (media.overview?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(media.overview!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TmdbCatalogError extends StatelessWidget {
  const _TmdbCatalogError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger les contenus TMDB.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
