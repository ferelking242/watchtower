import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';
import 'package:watchtower/modules/media/flixquest_movie_widgets.dart';

class TmdbGenresScreen extends StatelessWidget {
  const TmdbGenresScreen({
    required this.title,
    required this.genres,
    required this.imageSource,
    this.isTv = false,
    super.key,
  });

  final String title;
  final List<TmdbGenre> genres;
  final List<TmdbMedia> imageSource;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final columns = <List<TmdbGenre>>[[], []];
    for (var index = 0; index < genres.length; index++) {
      columns[index.isEven ? 0 : 1].add(genres[index]);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B11),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Broken.arrow_left),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Text(
            'Explore by genre',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every genre, with a fresh selection of covers.',
            style: TextStyle(color: Colors.white.withValues(alpha: .58)),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GenreColumn(
                  genres: columns[0],
                  imageSource: imageSource,
                  isTv: isTv,
                  offset: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenreColumn(
                  genres: columns[1],
                  imageSource: imageSource,
                  isTv: isTv,
                  offset: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreColumn extends StatelessWidget {
  const _GenreColumn({
    required this.genres,
    required this.imageSource,
    required this.isTv,
    required this.offset,
  });

  final List<TmdbGenre> genres;
  final List<TmdbMedia> imageSource;
  final bool isTv;
  final int offset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < genres.length; index++) ...[
          _PinterestGenreCard(
            genre: genres[index],
            imageSource: imageSource,
            isTv: isTv,
            height: [176.0, 224.0, 194.0][(index + offset) % 3],
          ),
          if (index != genres.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PinterestGenreCard extends StatelessWidget {
  const _PinterestGenreCard({
    required this.genre,
    required this.imageSource,
    required this.isTv,
    required this.height,
  });

  final TmdbGenre genre;
  final List<TmdbMedia> imageSource;
  final bool isTv;
  final double height;

  @override
  Widget build(BuildContext context) {
    final matchingImages = imageSource
        .where((media) => media.genreIds.contains(genre.id))
        .expand((media) => [media.bestCover, media.bannerImage])
        .whereType<String>()
        .toSet()
        .take(4)
        .toList(growable: false);
    final images = matchingImages.isNotEmpty
        ? matchingImages
        : imageSource.isEmpty
        ? const <String>[]
        : [
            imageSource[genre.id.abs() % imageSource.length].bestCover ??
                imageSource[genre.id.abs() % imageSource.length].bannerImage,
          ].whereType<String>().toList(growable: false);
    return Material(
      color: const Color(0xFF171820),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TmdbMoviesListScreen(
              title: genre.name,
              path:
                  '/discover/${isTv ? 'tv' : 'movie'}?with_genres=${genre.id}',
              isTv: isTv,
            ),
          ),
        ),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (images.isEmpty)
                const Center(
                  child: Icon(Broken.video, color: Colors.white38, size: 34),
                )
              else
                _GenreCoverMosaic(images: images),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE8000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 12,
                bottom: 13,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        genre.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Broken.arrow_right_3,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreCoverMosaic extends StatelessWidget {
  const _GenreCoverMosaic({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ExtendedImage.network(
        images.first,
        fit: BoxFit.cover,
        cache: true,
      );
    }
    return Row(
      children: [
        Expanded(flex: 5, child: _GenreImage(url: images[0])),
        const SizedBox(width: 2),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(child: _GenreImage(url: images[1])),
              if (images.length > 2) ...[
                const SizedBox(height: 2),
                Expanded(child: _GenreImage(url: images[2])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GenreImage extends StatelessWidget {
  const _GenreImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ExtendedImage.network(
      url,
      fit: BoxFit.cover,
      cache: true,
      width: double.infinity,
      height: double.infinity,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.completed) return null;
        return const AppShimmerBlock(radius: 0);
      },
    );
  }
}
