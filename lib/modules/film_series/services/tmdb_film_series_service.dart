import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';

const _tmdbFilmSeriesBase = 'https://api.themoviedb.org/3';
const _tmdbFilmSeriesToken = String.fromEnvironment('TMDB_READ_TOKEN');

class TmdbFilmSeriesDetails {
  final int id;
  final String mediaType;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final int? runtime;
  final List<String> genres;
  final List<int> genreIds;
  final List<TmdbFilmSeriesPerson> cast;
  final List<TmdbFilmSeriesPerson> crew;
  final List<TmdbMedia> recommendations;
  final List<TmdbFilmSeriesSeason> seasons;
  final List<TmdbFilmSeriesCreator> creators;
  final int? collectionId;
  final String? collectionName;
  final String? tagline;

  const TmdbFilmSeriesDetails({
    required this.id,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0,
    this.runtime,
    this.genres = const [],
    this.genreIds = const [],
    this.cast = const [],
    this.crew = const [],
    this.recommendations = const [],
    this.seasons = const [],
    this.creators = const [],
    this.collectionId,
    this.collectionName,
    this.tagline,
  });

  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w500$posterPath';
  String? get backdropUrl => backdropPath == null
      ? null
      : 'https://image.tmdb.org/t/p/w1280$backdropPath';

  factory TmdbFilmSeriesDetails.fromJson(
    Map<String, dynamic> json,
    String mediaType,
  ) {
    final isMovie = mediaType == 'movie';
    final rawGenres = json['genres'] as List? ?? const [];
    final credits = (json['credits'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawRecommendations =
        ((json['recommendations'] as Map?)?['results'] as List?) ?? const [];
    final rawSeasons = json['seasons'] as List? ?? const [];
    final rawCreators = json['created_by'] as List? ?? const [];
    final episodeRunTimes = json['episode_run_time'] as List?;

    return TmdbFilmSeriesDetails(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mediaType: mediaType,
      title:
          (isMovie ? json['title'] : json['name']) as String? ?? 'Sans titre',
      originalTitle:
          (isMovie ? json['original_title'] : json['original_name']) as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate:
          (isMovie ? json['release_date'] : json['first_air_date']) as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      runtime: isMovie
          ? (json['runtime'] as num?)?.toInt()
          : episodeRunTimes != null && episodeRunTimes.isNotEmpty
          ? (episodeRunTimes.first as num?)?.toInt()
          : null,
      genres: rawGenres
          .whereType<Map>()
          .map((g) => g['name'] as String?)
          .whereType<String>()
          .toList(growable: false),
      genreIds: rawGenres
          .whereType<Map>()
          .map((g) => (g['id'] as num?)?.toInt())
          .whereType<int>()
          .toList(growable: false),
      cast: _people(credits['cast']),
      crew: _people(credits['crew']),
      recommendations: rawRecommendations
          .whereType<Map>()
          .map((item) {
            final map = item.cast<String, dynamic>();
            final recommendationType =
                map['media_type'] as String? ?? mediaType;
            return recommendationType == 'tv'
                ? TmdbMedia.fromTvJson(map)
                : TmdbMedia.fromMovieJson(map);
          })
          .toList(growable: false),
      seasons: rawSeasons
          .whereType<Map>()
          .map(
            (season) =>
                TmdbFilmSeriesSeason.fromJson(season.cast<String, dynamic>()),
          )
          .where((season) => season.seasonNumber > 0)
          .toList(growable: false),
      creators: rawCreators
          .whereType<Map>()
          .map(
            (creator) =>
                TmdbFilmSeriesCreator.fromJson(creator.cast<String, dynamic>()),
          )
          .toList(growable: false),
      collectionId: (json['belongs_to_collection'] as Map?)?['id'] as int?,
      collectionName:
          (json['belongs_to_collection'] as Map?)?['name'] as String?,
      tagline: json['tagline'] as String?,
    );
  }
}

class TmdbFilmSeriesPerson {
  final int id;
  final String name;
  final String? character;
  final String? job;
  final String? profilePath;

  const TmdbFilmSeriesPerson({
    required this.id,
    required this.name,
    this.character,
    this.job,
    this.profilePath,
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';

  factory TmdbFilmSeriesPerson.fromJson(Map<String, dynamic> json) =>
      TmdbFilmSeriesPerson(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Inconnu',
        character: json['character'] as String?,
        job: json['job'] as String?,
        profilePath: json['profile_path'] as String?,
      );
}

class TmdbFilmSeriesCreator {
  final int id;
  final String name;
  final String? profilePath;

  const TmdbFilmSeriesCreator({
    required this.id,
    required this.name,
    this.profilePath,
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';

  factory TmdbFilmSeriesCreator.fromJson(Map<String, dynamic> json) =>
      TmdbFilmSeriesCreator(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Inconnu',
        profilePath: json['profile_path'] as String?,
      );
}

class TmdbFilmSeriesSeason {
  final int id;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? posterPath;
  final int episodeCount;

  const TmdbFilmSeriesSeason({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.posterPath,
    this.episodeCount = 0,
  });

  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w300$posterPath';

  factory TmdbFilmSeriesSeason.fromJson(Map<String, dynamic> json) =>
      TmdbFilmSeriesSeason(
        id: (json['id'] as num?)?.toInt() ?? 0,
        seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Saison',
        overview: json['overview'] as String?,
        posterPath: json['poster_path'] as String?,
        episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      );
}

class TmdbFilmSeriesEpisode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final int? runtime;
  final double voteAverage;
  final List<TmdbFilmSeriesPerson> guestStars;

  const TmdbFilmSeriesEpisode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtime,
    this.voteAverage = 0,
    this.guestStars = const [],
  });

  String? get stillUrl =>
      stillPath == null ? null : 'https://image.tmdb.org/t/p/w500$stillPath';

  factory TmdbFilmSeriesEpisode.fromJson(Map<String, dynamic> json) =>
      TmdbFilmSeriesEpisode(
        id: (json['id'] as num?)?.toInt() ?? 0,
        episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
        seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Épisode',
        overview: json['overview'] as String?,
        stillPath: json['still_path'] as String?,
        airDate: json['air_date'] as String?,
        runtime: (json['runtime'] as num?)?.toInt(),
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
        guestStars: (json['guest_stars'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (person) =>
                  TmdbFilmSeriesPerson.fromJson(person.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
}

class TmdbFilmSeriesPersonDetails {
  final int id;
  final String name;
  final String? biography;
  final String? profilePath;
  final String? birthday;
  final String? placeOfBirth;
  final List<TmdbMedia> credits;

  const TmdbFilmSeriesPersonDetails({
    required this.id,
    required this.name,
    this.biography,
    this.profilePath,
    this.birthday,
    this.placeOfBirth,
    this.credits = const [],
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w500$profilePath';

  factory TmdbFilmSeriesPersonDetails.fromJson(Map<String, dynamic> json) {
    final credits = (json['combined_credits'] as Map?)?.cast<String, dynamic>();
    final items = credits?['cast'] as List? ?? const [];
    return TmdbFilmSeriesPersonDetails(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Personne',
      biography: json['biography'] as String?,
      profilePath: json['profile_path'] as String?,
      birthday: json['birthday'] as String?,
      placeOfBirth: json['place_of_birth'] as String?,
      credits: items
          .whereType<Map>()
          .map((item) {
            final map = item.cast<String, dynamic>();
            return map['media_type'] == 'tv'
                ? TmdbMedia.fromTvJson(map)
                : TmdbMedia.fromMovieJson(map);
          })
          .where((item) => item.posterPath != null)
          .toList(growable: false),
    );
  }
}

class TmdbFilmSeriesCollection {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final List<TmdbMedia> parts;

  const TmdbFilmSeriesCollection({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.parts = const [],
  });

  String? get backdropUrl => backdropPath == null
      ? null
      : 'https://image.tmdb.org/t/p/w1280$backdropPath';

  factory TmdbFilmSeriesCollection.fromJson(Map<String, dynamic> json) =>
      TmdbFilmSeriesCollection(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Collection',
        overview: json['overview'] as String?,
        posterPath: json['poster_path'] as String?,
        backdropPath: json['backdrop_path'] as String?,
        parts: (json['parts'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => TmdbMedia.fromMovieJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
}

class TmdbFilmSeriesService {
  static Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> parameters = const {},
  ]) async {
    if (_tmdbFilmSeriesToken.isEmpty) {
      throw StateError(
        'TMDB_READ_TOKEN est absent. Le build doit fournir le secret TMDB_READ_TOKEN.',
      );
    }
    final query = <String, String>{'language': 'fr-FR', ...parameters};
    final response = await http
        .get(
          Uri.parse(
            '$_tmdbFilmSeriesBase$path',
          ).replace(queryParameters: query),
          headers: const {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_tmdbFilmSeriesToken',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('TMDB a répondu avec le statut ${response.statusCode}.');
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  static Future<TmdbFilmSeriesDetails> details(String mediaType, int id) async {
    final json = await _get('/$mediaType/$id', const {
      'append_to_response': 'credits,recommendations,watch/providers',
    });
    return TmdbFilmSeriesDetails.fromJson(json, mediaType);
  }

  static Future<List<TmdbMedia>> catalog(
    String mediaType, {
    int? genreId,
    int page = 1,
  }) async {
    final endpoint = mediaType == 'movie' ? '/discover/movie' : '/discover/tv';
    final json = await _get(endpoint, {
      'page': '$page',
      'sort_by': 'popularity.desc',
      if (genreId != null) 'with_genres': '$genreId',
    });
    final results = json['results'] as List? ?? const [];
    return results
        .whereType<Map>()
        .map((item) {
          final map = item.cast<String, dynamic>();
          return mediaType == 'movie'
              ? TmdbMedia.fromMovieJson(map)
              : TmdbMedia.fromTvJson(map);
        })
        .where((item) => item.posterPath != null)
        .toList(growable: false);
  }

  static Future<List<TmdbFilmSeriesSeason>> seasons(int tvId) async {
    final json = await _get('/tv/$tvId');
    return (json['seasons'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (season) =>
              TmdbFilmSeriesSeason.fromJson(season.cast<String, dynamic>()),
        )
        .where((season) => season.seasonNumber > 0)
        .toList(growable: false);
  }

  static Future<List<TmdbFilmSeriesEpisode>> episodes(
    int tvId,
    int seasonNumber,
  ) async {
    final json = await _get('/tv/$tvId/season/$seasonNumber');
    return (json['episodes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (episode) =>
              TmdbFilmSeriesEpisode.fromJson(episode.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  static Future<TmdbFilmSeriesEpisode> episode(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final json = await _get(
      '/tv/$tvId/season/$seasonNumber/episode/$episodeNumber',
    );
    return TmdbFilmSeriesEpisode.fromJson(json);
  }

  static Future<TmdbFilmSeriesPersonDetails> person(int id) async {
    final json = await _get('/person/$id', const {
      'append_to_response': 'combined_credits',
    });
    return TmdbFilmSeriesPersonDetails.fromJson(json);
  }

  static Future<TmdbFilmSeriesCollection> collection(int id) async {
    final json = await _get('/collection/$id');
    return TmdbFilmSeriesCollection.fromJson(json);
  }

  static Future<List<TmdbMedia>> search(String query) async {
    final json = await _get('/search/multi', {'query': query});
    final results = json['results'] as List? ?? const [];
    return results
        .whereType<Map>()
        .where((item) {
          final type = item['media_type'];
          return type == 'movie' || type == 'tv';
        })
        .map((item) {
          final map = item.cast<String, dynamic>();
          return map['media_type'] == 'tv'
              ? TmdbMedia.fromTvJson(map)
              : TmdbMedia.fromMovieJson(map);
        })
        .where((item) => item.posterPath != null)
        .toList(growable: false);
  }
}

List<TmdbFilmSeriesPerson> _people(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map(
        (person) =>
            TmdbFilmSeriesPerson.fromJson(person.cast<String, dynamic>()),
      )
      .toList(growable: false);
}

final tmdbFilmSeriesDetailsProvider = FutureProvider.autoDispose
    .family<TmdbFilmSeriesDetails, ({String mediaType, int id})>(
      (ref, key) => TmdbFilmSeriesService.details(key.mediaType, key.id),
    );

final tmdbFilmSeriesCatalogProvider = FutureProvider.autoDispose
    .family<List<TmdbMedia>, ({String mediaType, int? genreId})>(
      (ref, key) =>
          TmdbFilmSeriesService.catalog(key.mediaType, genreId: key.genreId),
    );
