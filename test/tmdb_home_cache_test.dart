import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_home_cache.dart';

void main() {
  test('hub cover cache window is 72 hours', () {
    expect(TmdbHomeCache.ttl, const Duration(hours: 72));
  });

  test('a hub round-trips through JSON with its media intact', () {
    const movie = TmdbMedia(
      id: 42,
      mediaType: 'movie',
      titleEn: 'A Movie',
      posterPath: '/poster.jpg',
      backdropPath: '/backdrop.jpg',
      overview: 'Plot',
      voteAverage: 7.5,
      voteCount: 100,
      releaseDate: '2024-01-01',
      genreIds: [1, 2],
      originalLanguage: 'en',
      originalTitle: 'A Movie',
      popularity: 12.5,
    );
    const tv = TmdbMedia(
      id: 7,
      mediaType: 'tv',
      titleEn: 'A Show',
      posterPath: '/tv.jpg',
      firstAirDate: '2023-05-05',
      genreIds: [3],
      originalLanguage: 'en',
      originalTitle: 'A Show',
      popularity: 3.25,
    );
    const home = TmdbHome(
      trendingMovies: [movie],
      popularTv: [tv],
    );

    final restored = TmdbHome.fromJson(home.toJson());

    expect(restored.trendingMovies, hasLength(1));
    expect(restored.popularTv, hasLength(1));
    final restoredMovie = restored.trendingMovies.single;
    expect(restoredMovie.id, 42);
    expect(restoredMovie.mediaType, 'movie');
    expect(restoredMovie.titleEn, 'A Movie');
    expect(restoredMovie.posterPath, '/poster.jpg');
    expect(restoredMovie.releaseDate, '2024-01-01');
    expect(restoredMovie.genreIds, [1, 2]);
    expect(restoredMovie.bestCover, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    final restoredTv = restored.popularTv.single;
    expect(restoredTv.id, 7);
    expect(restoredTv.mediaType, 'tv');
    expect(restoredTv.firstAirDate, '2023-05-05');
  });

  test('an empty hub is reported as empty and is not cached', () {
    expect(const TmdbHome().isEmpty, isTrue);
    expect(const TmdbHome(trendingMovies: [
      TmdbMedia(id: 1, mediaType: 'movie'),
    ]).isEmpty, isFalse);
  });
}
