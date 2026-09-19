import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/film_series/services/tmdb_film_series_service.dart';

class FilmSeriesSearchScreen extends StatefulWidget {
  const FilmSeriesSearchScreen({super.key});

  @override
  State<FilmSeriesSearchScreen> createState() => _FilmSeriesSearchScreenState();
}

class _FilmSeriesSearchScreenState extends State<FilmSeriesSearchScreen> {
  final _controller = TextEditingController();
  Future<List<TmdbMedia>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _results = TmdbFilmSeriesService.search(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher dans TMDB')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Film, série ou titre',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _results == null
                ? const Center(
                    child: Text('Saisissez un titre pour commencer.'),
                  )
                : FutureBuilder<List<TmdbMedia>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Recherche impossible : ${snapshot.error}',
                          ),
                        );
                      }
                      final results = snapshot.data ?? const <TmdbMedia>[];
                      if (results.isEmpty) {
                        return const Center(child: Text('Aucun résultat.'));
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              mainAxisExtent: 245,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final media = results[index];
                          final route = media.mediaType == 'tv'
                              ? '/SeriesDetail'
                              : '/MovieDetail';
                          return TmdbPosterCard(
                            media: media,
                            onTap: () => context.push(
                              route,
                              extra: {
                                'id': media.id,
                                'mediaType': media.mediaType,
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FilmSeriesPersonScreen extends StatelessWidget {
  const FilmSeriesPersonScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Personne')),
    body: FutureBuilder<TmdbFilmSeriesPersonDetails>(
      future: TmdbFilmSeriesService.person(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Impossible de charger cette personne.'));
        }
        final person = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _Image(url: person.profileUrl, icon: Icons.person),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (person.birthday != null) ...[
                        const SizedBox(height: 8),
                        Text('Né(e) le ${person.birthday}'),
                      ],
                      if (person.placeOfBirth != null)
                        Text(person.placeOfBirth!),
                    ],
                  ),
                ),
              ],
            ),
            if (person.biography?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 24),
              Text('Biographie', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(person.biography!),
            ],
            if (person.credits.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Filmographie',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: person.credits.take(30).map((media) {
                  final route = media.mediaType == 'tv'
                      ? '/SeriesDetail'
                      : '/MovieDetail';
                  return SizedBox(
                    width: 112,
                    height: 226,
                    child: TmdbPosterCard(
                      media: media,
                      onTap: () => context.push(
                        route,
                        extra: {'id': media.id, 'mediaType': media.mediaType},
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class FilmSeriesPeopleScreen extends StatelessWidget {
  const FilmSeriesPeopleScreen({
    super.key,
    required this.mediaType,
    required this.id,
  });

  final String mediaType;
  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        mediaType == 'movie'
            ? 'Cast & équipe du film'
            : 'Cast & équipe de la série',
      ),
    ),
    body: FutureBuilder<TmdbFilmSeriesDetails>(
      future: TmdbFilmSeriesService.details(mediaType, id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Impossible de charger les crédits.'),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Distribution', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final person in data.cast)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: person.profileUrl == null
                      ? null
                      : NetworkImage(person.profileUrl!),
                  child: person.profileUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(person.name),
                subtitle: Text(person.character ?? 'Interprétation'),
                onTap: () => context.push('/PersonDetail', extra: person.id),
              ),
            const SizedBox(height: 18),
            Text(
              'Équipe technique',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final person in data.crew)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: person.profileUrl == null
                      ? null
                      : NetworkImage(person.profileUrl!),
                  child: person.profileUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(person.name),
                subtitle: Text(person.job ?? 'Équipe'),
                onTap: () => context.push('/PersonDetail', extra: person.id),
              ),
          ],
        );
      },
    ),
  );
}

class FilmSeriesSeasonScreen extends StatelessWidget {
  const FilmSeriesSeasonScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.seriesName,
  });

  final int tvId;
  final int seasonNumber;
  final String seriesName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$seriesName — Saison $seasonNumber')),
    body: FutureBuilder<List<TmdbFilmSeriesEpisode>>(
      future: TmdbFilmSeriesService.episodes(tvId, seasonNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Impossible de charger la saison.'));
        }
        final episodes = snapshot.data ?? const <TmdbFilmSeriesEpisode>[];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: episodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(
                  '/EpisodeDetail',
                  extra: {
                    'tvId': tvId,
                    'seasonNumber': seasonNumber,
                    'episodeNumber': episode.episodeNumber,
                    'seriesName': seriesName,
                  },
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 92,
                      child: _Image(
                        url: episode.stillUrl,
                        icon: Icons.movie_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'E${episode.episodeNumber} · ${episode.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (episode.airDate != null) Text(episode.airDate!),
                            if (episode.overview?.isNotEmpty == true)
                              Text(
                                episode.overview!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class FilmSeriesEpisodeScreen extends StatelessWidget {
  const FilmSeriesEpisodeScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.seriesName,
  });

  final int tvId;
  final int seasonNumber;
  final int episodeNumber;
  final String seriesName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$seriesName · Épisode $episodeNumber')),
    body: FutureBuilder<TmdbFilmSeriesEpisode>(
      future: TmdbFilmSeriesService.episode(tvId, seasonNumber, episodeNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Impossible de charger cet épisode.'),
          );
        }
        final episode = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _Image(url: episode.stillUrl, icon: Icons.movie),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Saison $seasonNumber · Épisode $episodeNumber',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              episode.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  label: Text(episode.voteAverage.toStringAsFixed(1)),
                ),
                if (episode.runtime != null)
                  Chip(label: Text('${episode.runtime} min')),
                if (episode.airDate != null)
                  Chip(label: Text(episode.airDate!)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              episode.overview?.isNotEmpty == true
                  ? episode.overview!
                  : 'Aucun synopsis fourni par TMDB.',
            ),
            if (episode.guestStars.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Guest stars',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: episode.guestStars
                    .map(
                      (person) => ActionChip(
                        label: Text(person.name),
                        onPressed: () =>
                            context.push('/PersonDetail', extra: person.id),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class FilmSeriesCollectionScreen extends StatelessWidget {
  const FilmSeriesCollectionScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Collection')),
    body: FutureBuilder<TmdbFilmSeriesCollection>(
      future: TmdbFilmSeriesService.collection(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
            child: Text('Impossible de charger la collection.'),
          );
        }
        final collection = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (collection.backdropUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: _Image(
                    url: collection.backdropUrl,
                    icon: Icons.collections,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              collection.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (collection.overview?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(collection.overview!),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: collection.parts.map((media) {
                return SizedBox(
                  width: 120,
                  height: 226,
                  child: TmdbPosterCard(
                    media: media,
                    onTap: () => context.push(
                      '/MovieDetail',
                      extra: {'id': media.id, 'mediaType': 'movie'},
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    ),
  );
}

class _Image extends StatelessWidget {
  const _Image({required this.url, required this.icon});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(icon)),
    );
    return url == null
        ? fallback
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
  }
}
