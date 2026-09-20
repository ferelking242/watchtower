import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Media model (compatible avec AnilistMedia pour réutiliser les widgets)
// ─────────────────────────────────────────────────────────────────────────────

class TmdbMedia {
  final int id;
  final String? titleEn;
  final String? titleFr;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final double? voteAverage;
  final int? voteCount;
  final String? releaseDate;
  final String? firstAirDate;
  final List<int> genreIds;
  final String mediaType; // 'movie' | 'tv'
  final String? originalLanguage;

  const TmdbMedia({
    required this.id,
    required this.mediaType,
    this.titleEn,
    this.titleFr,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.voteAverage,
    this.voteCount,
    this.releaseDate,
    this.firstAirDate,
    this.genreIds = const [],
    this.originalLanguage,
  });

  String get displayTitle => titleFr ?? titleEn ?? 'Sans titre';

  String? get bestCover =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;

  String? get bannerImage => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : null;

  int? get averageScore =>
      voteAverage != null ? (voteAverage! * 10).round() : null;

  factory TmdbMedia.fromMovieJson(Map<String, dynamic> j) => TmdbMedia(
    id: (j['id'] as num).toInt(),
    mediaType: 'movie',
    titleEn: j['title'] as String?,
    titleFr: j['title'] as String?,
    posterPath: j['poster_path'] as String?,
    backdropPath: j['backdrop_path'] as String?,
    overview: j['overview'] as String?,
    voteAverage: (j['vote_average'] as num?)?.toDouble(),
    voteCount: (j['vote_count'] as num?)?.toInt(),
    releaseDate: j['release_date'] as String?,
    genreIds:
        (j['genre_ids'] as List?)?.whereType<int>().toList(growable: false) ??
        const [],
    originalLanguage: j['original_language'] as String?,
  );

  factory TmdbMedia.fromTvJson(Map<String, dynamic> j) => TmdbMedia(
    id: (j['id'] as num).toInt(),
    mediaType: 'tv',
    titleEn: j['name'] as String?,
    titleFr: j['name'] as String?,
    posterPath: j['poster_path'] as String?,
    backdropPath: j['backdrop_path'] as String?,
    overview: j['overview'] as String?,
    voteAverage: (j['vote_average'] as num?)?.toDouble(),
    voteCount: (j['vote_count'] as num?)?.toInt(),
    firstAirDate: j['first_air_date'] as String?,
    genreIds:
        (j['genre_ids'] as List?)?.whereType<int>().toList(growable: false) ??
        const [],
    originalLanguage: j['original_language'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Home data
// ─────────────────────────────────────────────────────────────────────────────

class TmdbHome {
  final List<TmdbMedia> trendingMovies;
  final List<TmdbMedia> popularMovies;
  final List<TmdbMedia> topRatedMovies;
  final List<TmdbMedia> nowPlayingMovies;
  final List<TmdbMedia> upcomingMovies;
  final List<TmdbMedia> trendingTv;
  final List<TmdbMedia> popularTv;
  final List<TmdbMedia> topRatedTv;
  final List<TmdbMedia> airingTodayTv;
  final List<TmdbMedia> onTheAirTv;

  const TmdbHome({
    this.trendingMovies = const [],
    this.popularMovies = const [],
    this.topRatedMovies = const [],
    this.nowPlayingMovies = const [],
    this.upcomingMovies = const [],
    this.trendingTv = const [],
    this.popularTv = const [],
    this.topRatedTv = const [],
    this.airingTodayTv = const [],
    this.onTheAirTv = const [],
  });
}

class TmdbGenre {
  final int id;
  final String name;

  const TmdbGenre({required this.id, required this.name});

  factory TmdbGenre.fromJson(Map<String, dynamic> json) => TmdbGenre(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? 'Autre',
  );
}

class TmdbWatchProvider {
  final int id;
  final String name;
  final String? logoPath;

  const TmdbWatchProvider({
    required this.id,
    required this.name,
    this.logoPath,
  });

  String? get logoUrl =>
      logoPath == null ? null : 'https://image.tmdb.org/t/p/w185$logoPath';

  factory TmdbWatchProvider.fromJson(Map<String, dynamic> json) =>
      TmdbWatchProvider(
        id: (json['provider_id'] as num).toInt(),
        name: json['provider_name'] as String? ?? 'Service',
        logoPath: json['logo_path'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TMDB API constants
// ─────────────────────────────────────────────────────────────────────────────

const _tmdbBase = 'https://api.themoviedb.org/3';
const _tmdbToken = String.fromEnvironment('TMDB_READ_TOKEN');

const _headers = {
  'Authorization': 'Bearer $_tmdbToken',
  'Accept': 'application/json',
};

// ─────────────────────────────────────────────────────────────────────────────
// Fetch helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<List<TmdbMedia>> _fetchMovies(String path) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase$path?language=fr-FR&page=1');
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final results = data['results'] as List? ?? [];
  return results
      .whereType<Map>()
      .map((e) => TmdbMedia.fromMovieJson(e.cast<String, dynamic>()))
      .where((m) => m.posterPath != null)
      .toList(growable: false);
}

Future<List<TmdbMedia>> _fetchTv(String path) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase$path?language=fr-FR&page=1');
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final results = data['results'] as List? ?? [];
  return results
      .whereType<Map>()
      .map((e) => TmdbMedia.fromTvJson(e.cast<String, dynamic>()))
      .where((m) => m.posterPath != null)
      .toList(growable: false);
}

Future<List<TmdbMedia>> fetchTmdbMoviePage({
  required String path,
  int page = 1,
}) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final baseUri = Uri.parse('$_tmdbBase$path');
  final query = <String, String>{
    ...baseUri.queryParameters,
    'language': 'fr-FR',
    'page': '$page',
  };
  final uri = baseUri.replace(queryParameters: query);
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final results = data['results'] as List? ?? [];
  return results
      .whereType<Map>()
      .map((e) => TmdbMedia.fromMovieJson(e.cast<String, dynamic>()))
      .where((m) => m.posterPath != null)
      .toList(growable: false);
}

Future<List<TmdbMedia>> fetchTmdbTvPage({
  required String path,
  int page = 1,
}) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final baseUri = Uri.parse('$_tmdbBase$path');
  final query = <String, String>{
    ...baseUri.queryParameters,
    'language': 'fr-FR',
    'page': '$page',
  };
  final uri = baseUri.replace(queryParameters: query);
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final results = data['results'] as List? ?? [];
  return results
      .whereType<Map>()
      .map((e) => TmdbMedia.fromTvJson(e.cast<String, dynamic>()))
      .where((media) => media.posterPath != null)
      .toList(growable: false);
}

Future<List<TmdbGenre>> fetchTmdbMovieGenres() async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase/genre/movie/list?language=fr-FR');
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return (data['genres'] as List? ?? [])
      .whereType<Map>()
      .map((e) => TmdbGenre.fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}

Future<List<TmdbGenre>> fetchTmdbTvGenres() async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase/genre/tv/list?language=fr-FR');
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return (data['genres'] as List? ?? [])
      .whereType<Map>()
      .map((e) => TmdbGenre.fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}

Future<List<TmdbWatchProvider>> fetchTmdbWatchProviders() async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse(
    '$_tmdbBase/watch/providers/movie?language=fr-FR&watch_region=US',
  );
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return (data['results'] as List? ?? [])
      .whereType<Map>()
      .map((e) => TmdbWatchProvider.fromJson(e.cast<String, dynamic>()))
      .where((provider) => provider.logoPath != null)
      .take(12)
      .toList(growable: false);
}

Future<TmdbHome> _fetchTmdbHome() async {
  final results = await Future.wait([
    _fetchMovies('/trending/movie/week'),
    _fetchMovies('/movie/popular'),
    _fetchMovies('/movie/top_rated'),
    _fetchMovies('/movie/now_playing'),
    _fetchMovies('/movie/upcoming'),
    _fetchTv('/trending/tv/week'),
    _fetchTv('/tv/popular'),
    _fetchTv('/tv/top_rated'),
    _fetchTv('/tv/airing_today'),
    _fetchTv('/tv/on_the_air'),
  ]);

  return TmdbHome(
    trendingMovies: results[0],
    popularMovies: results[1],
    topRatedMovies: results[2],
    nowPlayingMovies: results[3],
    upcomingMovies: results[4],
    trendingTv: results[5],
    popularTv: results[6],
    topRatedTv: results[7],
    airingTodayTv: results[8],
    onTheAirTv: results[9],
  );
}

final tmdbHomeProvider = FutureProvider.autoDispose<TmdbHome>(
  (_) => _fetchTmdbHome(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Genre name helpers
// ─────────────────────────────────────────────────────────────────────────────

const _movieGenres = {
  28: 'Action',
  12: 'Aventure',
  16: 'Animation',
  35: 'Comédie',
  80: 'Crime',
  99: 'Documentaire',
  18: 'Drame',
  10751: 'Famille',
  14: 'Fantastique',
  36: 'Histoire',
  27: 'Horreur',
  10402: 'Musique',
  9648: 'Mystère',
  10749: 'Romance',
  878: 'Science-Fiction',
  10770: 'Téléfilm',
  53: 'Thriller',
  10752: 'Guerre',
  37: 'Western',
};

const _tvGenres = {
  10759: 'Action & Aventure',
  16: 'Animation',
  35: 'Comédie',
  80: 'Crime',
  99: 'Documentaire',
  18: 'Drame',
  10751: 'Famille',
  10762: 'Enfants',
  9648: 'Mystère',
  10763: 'Actualités',
  10764: 'Réalité',
  10765: 'Sci-Fi & Fantastique',
  10766: 'Soap',
  10767: 'Talk-show',
  10768: 'Guerre & Politique',
  37: 'Western',
};

String tmdbMovieGenreName(int id) => _movieGenres[id] ?? 'Autre';
String tmdbTvGenreName(int id) => _tvGenres[id] ?? 'Autre';

List<String> tmdbMovieGenreNames(List<int> ids) =>
    ids.map(tmdbMovieGenreName).where((g) => g != 'Autre').take(3).toList();

List<String> tmdbTvGenreNames(List<int> ids) =>
    ids.map(tmdbTvGenreName).where((g) => g != 'Autre').take(3).toList();
