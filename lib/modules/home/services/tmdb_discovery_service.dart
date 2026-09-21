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
  final String? originalTitle;
  final double? popularity;

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
    this.originalTitle,
    this.popularity,
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
    originalTitle: j['original_title'] as String? ?? j['title'] as String?,
    popularity: (j['popularity'] as num?)?.toDouble(),
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
    originalTitle: j['original_name'] as String? ?? j['name'] as String?,
    popularity: (j['popularity'] as num?)?.toDouble(),
  );

  factory TmdbMedia.fromCreditJson(Map<String, dynamic> j) {
    final type =
        j['media_type'] as String? ??
        (j.containsKey('title') || j.containsKey('release_date')
            ? 'movie'
            : 'tv');
    return type == 'movie'
        ? TmdbMedia.fromMovieJson(j)
        : TmdbMedia.fromTvJson(j);
  }
}

/// Payload used by the media detail route.
///
/// The tag is created by the card that opened the page so repeated titles
/// across different rails can still animate independently.
class TmdbMediaDetailRoute {
  final TmdbMedia media;
  final String heroTag;

  const TmdbMediaDetailRoute({required this.media, required this.heroTag});
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

class TmdbCastMember {
  final int id;
  final String name;
  final String character;
  final String? profilePath;

  const TmdbCastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';

  factory TmdbCastMember.fromJson(Map<String, dynamic> json) => TmdbCastMember(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Artiste',
    character: json['character'] as String? ?? '',
    profilePath: json['profile_path'] as String?,
  );
}

class TmdbCrewMember {
  final int id;
  final String name;
  final String department;
  final String job;
  final String? profilePath;

  const TmdbCrewMember({
    required this.id,
    required this.name,
    required this.department,
    required this.job,
    this.profilePath,
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';

  factory TmdbCrewMember.fromJson(Map<String, dynamic> json) => TmdbCrewMember(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Artiste',
    department: json['department'] as String? ?? '',
    job: json['job'] as String? ?? '',
    profilePath: json['profile_path'] as String?,
  );
}

class TmdbPersonRef {
  final int id;
  final String name;
  final String? profilePath;
  final String? knownForDepartment;

  const TmdbPersonRef({
    required this.id,
    required this.name,
    this.profilePath,
    this.knownForDepartment,
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';
}

class TmdbPersonDetails {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? knownForDepartment;
  final String? profilePath;
  final String? homepage;
  final String? imdbId;
  final String? facebookId;
  final String? instagramId;
  final String? twitterId;
  final double? popularity;
  final List<String> alsoKnownAs;
  final List<String> profilePaths;
  final List<TmdbMedia> credits;

  const TmdbPersonDetails({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.knownForDepartment,
    this.profilePath,
    this.homepage,
    this.imdbId,
    this.facebookId,
    this.instagramId,
    this.twitterId,
    this.popularity,
    this.alsoKnownAs = const [],
    this.profilePaths = const [],
    this.credits = const [],
  });

  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w500$profilePath';

  List<TmdbMedia> get movies =>
      credits.where((credit) => credit.mediaType == 'movie').toList();

  List<TmdbMedia> get tvShows =>
      credits.where((credit) => credit.mediaType == 'tv').toList();

  factory TmdbPersonDetails.fromJson(Map<String, dynamic> json) {
    final combined = (json['combined_credits'] as Map?)
        ?.cast<String, dynamic>();
    final cast = (combined?['cast'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => TmdbMedia.fromCreditJson(item.cast<String, dynamic>()))
        .where((item) => item.posterPath != null)
        .toList(growable: false);
    final crew = (combined?['crew'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => TmdbMedia.fromCreditJson(item.cast<String, dynamic>()))
        .where((item) => item.posterPath != null)
        .toList(growable: false);
    final credits = <TmdbMedia>[
      ...cast,
      ...crew.where(
        (item) => cast.every(
          (castItem) =>
              castItem.id != item.id || castItem.mediaType != item.mediaType,
        ),
      ),
    ];
    final imageProfiles = ((json['images'] as Map?)?['profiles'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['file_path'] as String?)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
    if (json['profile_path'] is String &&
        (json['profile_path'] as String).isNotEmpty &&
        !imageProfiles.contains(json['profile_path'])) {
      imageProfiles.insert(0, json['profile_path'] as String);
    }
    final externalIds = (json['external_ids'] as Map?)?.cast<String, dynamic>();
    return TmdbPersonDetails(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Artiste',
      biography: json['biography'] as String?,
      birthday: json['birthday'] as String?,
      deathday: json['deathday'] as String?,
      placeOfBirth: json['place_of_birth'] as String?,
      knownForDepartment: json['known_for_department'] as String?,
      profilePath: json['profile_path'] as String?,
      homepage: json['homepage'] as String?,
      imdbId: json['imdb_id'] as String? ?? externalIds?['imdb_id'] as String?,
      facebookId: externalIds?['facebook_id'] as String?,
      instagramId: externalIds?['instagram_id'] as String?,
      twitterId: externalIds?['twitter_id'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      alsoKnownAs:
          (json['also_known_as'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      profilePaths: imageProfiles,
      credits: credits,
    );
  }
}

class TmdbVideo {
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;
  final String languageCode;

  const TmdbVideo({
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    required this.official,
    this.languageCode = '',
  });

  bool get isYoutube => site.toLowerCase() == 'youtube';

  String get watchUrl => isYoutube
      ? 'https://www.youtube.com/watch?v=$key'
      : 'https://$site.com/watch?v=$key';

  factory TmdbVideo.fromJson(Map<String, dynamic> json) => TmdbVideo(
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? 'Vidéo',
    site: json['site'] as String? ?? '',
    type: json['type'] as String? ?? 'Video',
    official: json['official'] as bool? ?? false,
    languageCode: json['iso_639_1'] as String? ?? '',
  );
}

class TmdbSeason {
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? airDate;
  final String? posterPath;
  final int episodeCount;

  const TmdbSeason({
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.airDate,
    this.posterPath,
    this.episodeCount = 0,
  });

  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w500$posterPath';

  factory TmdbSeason.fromJson(Map<String, dynamic> json) => TmdbSeason(
    seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Saison',
    overview: json['overview'] as String?,
    airDate: json['air_date'] as String?,
    posterPath: json['poster_path'] as String?,
    episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
  );
}

class TmdbEpisode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? airDate;
  final String? stillPath;
  final double? voteAverage;
  final int? voteCount;
  final int? runtime;

  const TmdbEpisode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.airDate,
    this.stillPath,
    this.voteAverage,
    this.voteCount,
    this.runtime,
  });

  String? get stillUrl =>
      stillPath == null ? null : 'https://image.tmdb.org/t/p/w500$stillPath';

  factory TmdbEpisode.fromJson(Map<String, dynamic> json) => TmdbEpisode(
    id: (json['id'] as num?)?.toInt() ?? 0,
    episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
    seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Épisode',
    overview: json['overview'] as String?,
    airDate: json['air_date'] as String?,
    stillPath: json['still_path'] as String?,
    voteAverage: (json['vote_average'] as num?)?.toDouble(),
    voteCount: (json['vote_count'] as num?)?.toInt(),
    runtime: (json['runtime'] as num?)?.toInt(),
  );
}

class TmdbMediaDetails {
  final int? runtime;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<int> episodeRunTimes;
  final String? tagline;
  final String? status;
  final List<TmdbGenre> genres;
  final List<TmdbCastMember> cast;
  final List<TmdbCrewMember> crew;
  final List<TmdbVideo> videos;
  final List<String> backdropPaths;
  final List<TmdbMedia> recommendations;
  final List<TmdbMedia> similar;
  final List<TmdbSeason> seasons;
  final List<TmdbWatchProvider> watchProviders;
  final String? originalTitle;
  final double? popularity;
  final int? budget;
  final int? revenue;
  final String? homepage;
  final String? imdbId;
  final List<String> productionCountries;
  final List<String> productionCompanies;
  final List<String> networks;
  final List<String> originCountries;
  final List<String> spokenLanguages;
  final List<String> createdBy;
  final String? type;
  final String? lastAirDate;
  final String? inProduction;

  const TmdbMediaDetails({
    this.runtime,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.episodeRunTimes = const [],
    this.tagline,
    this.status,
    this.genres = const [],
    this.cast = const [],
    this.crew = const [],
    this.videos = const [],
    this.backdropPaths = const [],
    this.recommendations = const [],
    this.similar = const [],
    this.seasons = const [],
    this.watchProviders = const [],
    this.originalTitle,
    this.popularity,
    this.budget,
    this.revenue,
    this.homepage,
    this.imdbId,
    this.productionCountries = const [],
    this.productionCompanies = const [],
    this.networks = const [],
    this.originCountries = const [],
    this.spokenLanguages = const [],
    this.createdBy = const [],
    this.type,
    this.lastAirDate,
    this.inProduction,
  });

  factory TmdbMediaDetails.fromJson(
    Map<String, dynamic> json,
    String mediaType,
  ) {
    final genres = (json['genres'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TmdbGenre.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    final credits = json['credits'] as Map?;
    final cast = (credits?['cast'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TmdbCastMember.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
    final crew = (credits?['crew'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TmdbCrewMember.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
    final videos =
        ((json['videos'] as Map?)?['results'] as List? ?? [])
            .whereType<Map>()
            .map((item) => TmdbVideo.fromJson(item.cast<String, dynamic>()))
            .where((item) => item.key.isNotEmpty && item.isYoutube)
            .toList()
          ..sort((a, b) {
            int rank(TmdbVideo video) {
              final typeRank = switch (video.type) {
                'Trailer' => 0,
                'Teaser' => 1,
                'Featurette' => 2,
                _ => 3,
              };
              final languageRank = switch (video.languageCode) {
                'fr' => 0,
                'en' => 1,
                _ => 2,
              };
              return typeRank * 10 + languageRank;
            }

            return rank(a).compareTo(rank(b));
          });
    final selectedVideos = videos.take(20).toList(growable: false);
    final images = (json['images'] as Map?)?['backdrops'] as List? ?? [];
    final backdropPaths = images
        .whereType<Map>()
        .map((item) => item['file_path'] as String?)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    final recommendations =
        ((json['recommendations'] as Map?)?['results'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) => mediaType == 'movie'
                  ? TmdbMedia.fromMovieJson(item.cast<String, dynamic>())
                  : TmdbMedia.fromTvJson(item.cast<String, dynamic>()),
            )
            .where((item) => item.posterPath != null)
            .take(20)
            .toList(growable: false);
    final similar = ((json['similar'] as Map?)?['results'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => mediaType == 'movie'
              ? TmdbMedia.fromMovieJson(item.cast<String, dynamic>())
              : TmdbMedia.fromTvJson(item.cast<String, dynamic>()),
        )
        .where((item) => item.posterPath != null)
        .take(20)
        .toList(growable: false);
    final seasons = (json['seasons'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TmdbSeason.fromJson(item.cast<String, dynamic>()))
        .where((season) => season.seasonNumber >= 0)
        .toList(growable: false);
    final providerRegion =
        ((json['watch/providers'] as Map?)?['results'] as Map?)?['US'] as Map?;
    final providerGroups = [
      providerRegion?['flatrate'],
      providerRegion?['free'],
      providerRegion?['ads'],
      providerRegion?['rent'],
      providerRegion?['buy'],
    ];
    final watchProviders = providerGroups
        .expand((group) => group is List ? group : const [])
        .whereType<Map>()
        .map((item) => TmdbWatchProvider.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.logoPath != null)
        .fold<List<TmdbWatchProvider>>(<TmdbWatchProvider>[], (
          items,
          provider,
        ) {
          if (items.every((item) => item.id != provider.id)) {
            items.add(provider);
          }
          return items;
        });

    final episodeRunTimes =
        (json['episode_run_time'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value > 0)
            .toList(growable: false) ??
        const [];
    final originCountries =
        (json['origin_country'] as List?)
            ?.whereType<String>()
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const [];
    final spokenLanguages =
        (json['spoken_languages'] as List?)
            ?.whereType<Map>()
            .map(
              (item) =>
                  item['name'] as String? ?? item['iso_639_1'] as String? ?? '',
            )
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const [];
    final createdBy =
        (json['created_by'] as List?)
            ?.whereType<Map>()
            .map((item) => item['name'] as String? ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const [];

    return TmdbMediaDetails(
      runtime: (json['runtime'] as num?)?.toInt(),
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
      episodeRunTimes: episodeRunTimes,
      tagline: json['tagline'] as String?,
      status: json['status'] as String?,
      genres: genres,
      cast: cast,
      crew: crew,
      videos: selectedVideos,
      backdropPaths: backdropPaths,
      recommendations: recommendations,
      similar: similar,
      seasons: seasons,
      watchProviders: watchProviders,
      originalTitle:
          json['original_title'] as String? ?? json['original_name'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      budget: (json['budget'] as num?)?.toInt(),
      revenue: (json['revenue'] as num?)?.toInt(),
      homepage: json['homepage'] as String?,
      imdbId:
          json['imdb_id'] as String? ??
          ((json['external_ids'] as Map?)?['imdb_id'] as String?),
      productionCountries:
          (json['production_countries'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    item['name'] as String? ??
                    item['iso_3166_1'] as String? ??
                    '',
              )
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const [],
      productionCompanies:
          (json['production_companies'] as List?)
              ?.whereType<Map>()
              .map((item) => item['name'] as String? ?? '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const [],
      networks:
          (json['networks'] as List?)
              ?.whereType<Map>()
              .map((item) => item['name'] as String? ?? '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const [],
      originCountries: originCountries,
      spokenLanguages: spokenLanguages,
      createdBy: createdBy,
      type: json['type'] as String?,
      lastAirDate: json['last_air_date'] as String?,
      inProduction: (json['in_production'] as bool?) == null
          ? null
          : ((json['in_production'] as bool) ? 'Oui' : 'Non'),
    );
  }
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

Future<List<TmdbPersonRef>> fetchTmdbPeoplePage({
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
      .map(
        (item) => TmdbPersonRef(
          id: (item['id'] as num?)?.toInt() ?? 0,
          name: item['name'] as String? ?? 'Artiste',
          profilePath: item['profile_path'] as String?,
          knownForDepartment: item['known_for_department'] as String?,
        ),
      )
      .where((person) => person.id != 0 && person.name.isNotEmpty)
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

Future<TmdbMediaDetails> fetchTmdbMediaDetails(TmdbMedia media) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase/${media.mediaType}/${media.id}').replace(
    queryParameters: {
      'language': 'fr-FR',
      'append_to_response':
          'credits,videos,images,recommendations,similar,seasons,watch/providers,external_ids',
      'include_image_language': 'fr,null',
      'include_video_language': 'fr-FR,en-US,null',
      'watch_region': 'US',
    },
  );
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw StateError('TMDB detail request failed (${res.statusCode}).');
  }
  final json = jsonDecode(res.body);
  if (json is! Map) {
    throw const FormatException('TMDB returned an invalid detail payload.');
  }
  return TmdbMediaDetails.fromJson(
    json.cast<String, dynamic>(),
    media.mediaType,
  );
}

Future<List<TmdbEpisode>> fetchTmdbSeasonEpisodes(
  TmdbMedia media,
  int seasonNumber,
) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse(
    '$_tmdbBase/tv/${media.id}/season/$seasonNumber',
  ).replace(queryParameters: const {'language': 'fr-FR'});
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw StateError('TMDB season request failed (${res.statusCode}).');
  }
  final json = jsonDecode(res.body);
  if (json is! Map) {
    throw const FormatException('TMDB returned an invalid season payload.');
  }
  return (json['episodes'] as List? ?? [])
      .whereType<Map>()
      .map((item) => TmdbEpisode.fromJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}

Future<TmdbPersonDetails> fetchTmdbPersonDetails(TmdbPersonRef person) async {
  if (_tmdbToken.isEmpty) {
    throw StateError(
      'TMDB_READ_TOKEN is missing from this build. '
      'Configure the GitHub Actions secret and dart-define.',
    );
  }
  final uri = Uri.parse('$_tmdbBase/person/${person.id}').replace(
    queryParameters: const {
      'language': 'fr-FR',
      'append_to_response': 'combined_credits,external_ids,images',
      'include_image_language': 'fr,null,en',
    },
  );
  final res = await http
      .get(uri, headers: _headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw StateError('TMDB person request failed (${res.statusCode}).');
  }
  final json = jsonDecode(res.body);
  if (json is! Map) {
    throw const FormatException('TMDB returned an invalid person payload.');
  }
  return TmdbPersonDetails.fromJson(json.cast<String, dynamic>());
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
