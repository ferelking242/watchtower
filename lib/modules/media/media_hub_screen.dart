import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MediaError(title: title, error: error),
        data: (data) => _MediaHomeBody(kind: kind, home: data),
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
  List<TmdbMedia> get popular =>
      isMovies ? home.popularMovies : home.popularTv;
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
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: isMovies ? 'Films populaires' : 'Séries populaires',
          items: popular,
          accent: const Color(0xFFFFB703),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: isMovies ? 'Nouveautés' : 'À suivre aujourd’hui',
          items: latest,
          accent: const Color(0xFF4CC9F0),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
        ),
        _MediaRow(
          title: 'Les mieux notés',
          items: topRated,
          accent: const Color(0xFFB5179E),
          onTap: (m) => context.push('/flixMediaDetail', extra: m),
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.info_outline_rounded),
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
          _TabPill(label: 'Tout', selected: true),
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
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
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

  const _MediaError({required this.title, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 44),
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            Text('$error', style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class TmdbMediaDetailScreen extends StatelessWidget {
  final TmdbMedia media;

  const TmdbMediaDetailScreen({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final genres = media.mediaType == 'movie'
        ? tmdbMovieGenreNames(media.genreIds)
        : tmdbTvGenreNames(media.genreIds);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 370,
            pinned: true,
            backgroundColor: const Color(0xFF0B0B11),
            leading: const BackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.bannerImage != null)
                    ExtendedImage.network(media.bannerImage!, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0B0B11)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (media.voteAverage != null)
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: media.voteAverage!.toStringAsFixed(1),
                        ),
                      if (media.releaseDate != null || media.firstAirDate != null)
                        _InfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: (media.releaseDate ?? media.firstAirDate!).split('-').first,
                        ),
                      ...genres.map((genre) => _InfoChip(label: genre)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showSourceMessage(context),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Rechercher une source'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ajouté à votre liste locale')),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Ma liste',
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Synopsis',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    media.overview?.isNotEmpty == true
                        ? media.overview!
                        : 'Aucun synopsis disponible.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                      fontSize: 15,
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

  void _showSourceMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171720),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sources Watchtower',
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'La fiche utilise les données TMDB. Ouvrez Recherche pour choisir une source Watchtower installée.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/globalSearch');
                },
                child: const Text('Ouvrir Recherche'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _InfoChip({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.amber, size: 15),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}