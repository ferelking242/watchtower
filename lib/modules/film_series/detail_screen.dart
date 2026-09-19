import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/film_series/services/tmdb_film_series_service.dart';

class FilmSeriesDetailScreen extends ConsumerWidget {
  const FilmSeriesDetailScreen({
    super.key,
    required this.mediaType,
    required this.id,
  });

  final String mediaType;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      tmdbFilmSeriesDetailsProvider((mediaType: mediaType, id: id)),
    );
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailError(
          error: error,
          onRetry: () => ref.invalidate(
            tmdbFilmSeriesDetailsProvider((mediaType: mediaType, id: id)),
          ),
        ),
        data: (data) => _DetailContent(data: data),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.data});

  final TmdbFilmSeriesDetails data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 270,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: _BackdropImage(url: data.backdropUrl),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Poster(url: data.posterUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (data.originalTitle != null &&
                          data.originalTitle != data.title)
                        Text(
                          data.originalTitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Pill(
                            icon: Icons.star_rounded,
                            label: data.voteAverage.toStringAsFixed(1),
                          ),
                          if (data.releaseDate?.isNotEmpty == true)
                            _Pill(
                              icon: Icons.calendar_month_rounded,
                              label: data.releaseDate!.substring(0, 4),
                            ),
                          if (data.runtime != null)
                            _Pill(
                              icon: Icons.schedule_rounded,
                              label: '${data.runtime} min',
                            ),
                        ],
                      ),
                      if (data.genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (
                              var index = 0;
                              index < data.genres.length;
                              index++
                            )
                              ActionChip(
                                label: Text(data.genres[index]),
                                onPressed: index < data.genreIds.length
                                    ? () => context.push(
                                        data.mediaType == 'movie'
                                            ? '/MovieGenre'
                                            : '/SeriesGenre',
                                        extra: {
                                          'genreId': data.genreIds[index],
                                          'genreName': data.genres[index],
                                        },
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data.tagline?.isNotEmpty == true)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                data.tagline!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _Section(
            title: 'Synopsis',
            child: Text(
              data.overview?.trim().isNotEmpty == true
                  ? data.overview!
                  : 'Aucun synopsis fourni par TMDB.',
            ),
          ),
        ),
        if (data.mediaType == 'tv' && data.seasons.isNotEmpty)
          SliverToBoxAdapter(
            child: _Section(
              title: 'Saisons',
              child: SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.seasons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final season = data.seasons[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(
                        '/SeasonDetail',
                        extra: {
                          'tvId': data.id,
                          'seasonNumber': season.seasonNumber,
                          'name': data.title,
                        },
                      ),
                      child: SizedBox(
                        width: 125,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _NetworkImage(
                                  url: season.posterUrl,
                                  icon: Icons.tv,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              season.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('${season.episodeCount} épisodes'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (data.creators.isNotEmpty)
          SliverToBoxAdapter(
            child: _PeopleSection(
              title: 'Créateurs',
              people: data.creators
                  .map(
                    (creator) => TmdbFilmSeriesPerson(
                      id: creator.id,
                      name: creator.name,
                      profilePath: creator.profilePath,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (data.cast.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                _PeopleSection(title: 'Distribution', people: data.cast),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 4),
                    child: TextButton.icon(
                      onPressed: () => context.push(
                        data.mediaType == 'movie'
                            ? '/MovieCastCrew'
                            : '/SeriesCastCrew',
                        extra: {'id': data.id, 'mediaType': data.mediaType},
                      ),
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Voir cast & équipe'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (data.collectionId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/MovieCollection',
                  extra: {'id': data.collectionId},
                ),
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: Text(data.collectionName ?? 'Voir la collection'),
              ),
            ),
          ),
        if (data.recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: _Section(
              title: 'Recommandations',
              child: SizedBox(
                height: 226,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.recommendations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = data.recommendations[index];
                    final type = item.mediaType == 'tv'
                        ? 'SeriesDetail'
                        : 'MovieDetail';
                    return TmdbPosterCard(
                      media: item,
                      onTap: () => context.push(
                        '/$type',
                        extra: {'id': item.id, 'mediaType': item.mediaType},
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.title, required this.people});

  final String title;
  final List<TmdbFilmSeriesPerson> people;

  @override
  Widget build(BuildContext context) => _Section(
    title: title,
    child: SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.take(20).length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final person = people[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/PersonDetail', extra: person.id),
            child: SizedBox(
              width: 90,
              child: Column(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipOval(
                      child: _NetworkImage(
                        url: person.profileUrl,
                        icon: Icons.person,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    person.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (person.character != null)
                    Text(
                      person.character!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 168,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _NetworkImage(url: url, icon: Icons.movie),
    ),
  );
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _NetworkImage(url: url, icon: Icons.movie),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
      ),
    ],
  );
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, required this.icon});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (url == null) {
      return ColoredBox(
        color: color,
        child: Center(child: Icon(icon)),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: color,
        child: Center(child: Icon(icon)),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 48),
        const SizedBox(height: 10),
        const Text('Impossible de charger cette fiche TMDB.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}
