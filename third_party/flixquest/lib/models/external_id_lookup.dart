/// What TMDB found when asked about an id from another site.
///
/// An IMDb id says nothing about what it names, so this is the answer to the question the id cannot
/// answer for itself: TMDB replies with one list per kind of record and fills in the one that
/// matched. Reading all five is what lets an episode link open the episode and a season link open
/// the season, instead of everything with a `tt` id being guessed at as a film.
class ExternalIdLookup {
  const ExternalIdLookup({
    this.movie,
    this.tv,
    this.person,
    this.episode,
    this.season,
  });

  ExternalIdLookup.fromJson(Map<String, dynamic> json)
      : movie = ExternalTitleMatch._first(json['movie_results'], 'title'),
        tv = ExternalTitleMatch._first(json['tv_results'], 'name'),
        person = ExternalPersonMatch._first(json['person_results']),
        episode = ExternalEpisodeMatch._first(json['tv_episode_results']),
        season = ExternalSeasonMatch._first(json['tv_season_results']);

  final ExternalTitleMatch? movie;
  final ExternalTitleMatch? tv;
  final ExternalPersonMatch? person;
  final ExternalEpisodeMatch? episode;
  final ExternalSeasonMatch? season;

  /// True when TMDB holds nothing under that id, which is a real answer and not a failure: IMDb
  /// carries records TMDB has never had.
  bool get isEmpty =>
      movie == null &&
      tv == null &&
      person == null &&
      episode == null &&
      season == null;

  /// The one field that matched, most specific first.
  ///
  /// A single id only ever fills one of these, but the order matters anyway: an episode result also
  /// names its series, and answering with the series would be answering a narrower question with a
  /// broader page.
  Object? get match => episode ?? season ?? movie ?? tv ?? person;

  static List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// A film or a series: an id, and the little TMDB volunteers about it for the wait that follows.
class ExternalTitleMatch {
  const ExternalTitleMatch({
    required this.id,
    this.title,
    this.posterPath,
    this.backdropPath,
  });

  static ExternalTitleMatch? _first(Object? rows, String titleKey) {
    for (final row in ExternalIdLookup._rows(rows)) {
      final id = ExternalIdLookup._int(row['id']);
      if (id == null) continue;
      return ExternalTitleMatch(
        id: id,
        title: ExternalIdLookup._text(row[titleKey]),
        posterPath: ExternalIdLookup._text(row['poster_path']),
        backdropPath: ExternalIdLookup._text(row['backdrop_path']),
      );
    }
    return null;
  }

  final int id;
  final String? title;
  final String? posterPath;
  final String? backdropPath;
}

class ExternalPersonMatch {
  const ExternalPersonMatch({
    required this.id,
    this.name,
    this.profilePath,
    this.adult,
  });

  static ExternalPersonMatch? _first(Object? rows) {
    for (final row in ExternalIdLookup._rows(rows)) {
      final id = ExternalIdLookup._int(row['id']);
      if (id == null) continue;
      return ExternalPersonMatch(
        id: id,
        name: ExternalIdLookup._text(row['name']),
        profilePath: ExternalIdLookup._text(row['profile_path']),
        adult: row['adult'] is bool ? row['adult'] as bool : null,
      );
    }
    return null;
  }

  final int id;
  final String? name;
  final String? profilePath;

  /// Whether TMDB files this person under adult work, which the app gates on.
  final bool? adult;
}

/// One episode, which TMDB returns already addressed the way the app addresses episodes: by series
/// and by its two numbers.
class ExternalEpisodeMatch {
  const ExternalEpisodeMatch({
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.name,
    this.stillPath,
  });

  static ExternalEpisodeMatch? _first(Object? rows) {
    for (final row in ExternalIdLookup._rows(rows)) {
      final seriesId = ExternalIdLookup._int(row['show_id']);
      final seasonNumber = ExternalIdLookup._int(row['season_number']);
      final episodeNumber = ExternalIdLookup._int(row['episode_number']);
      if (seriesId == null || seasonNumber == null || episodeNumber == null) {
        continue;
      }
      return ExternalEpisodeMatch(
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        name: ExternalIdLookup._text(row['name']),
        stillPath: ExternalIdLookup._text(row['still_path']),
      );
    }
    return null;
  }

  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;

  /// The episode's own name, not the series'.
  final String? name;
  final String? stillPath;
}

class ExternalSeasonMatch {
  const ExternalSeasonMatch({
    required this.seriesId,
    required this.seasonNumber,
    this.name,
    this.posterPath,
  });

  static ExternalSeasonMatch? _first(Object? rows) {
    for (final row in ExternalIdLookup._rows(rows)) {
      final seriesId = ExternalIdLookup._int(row['show_id']);
      final seasonNumber = ExternalIdLookup._int(row['season_number']);
      if (seriesId == null || seasonNumber == null) continue;
      return ExternalSeasonMatch(
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        name: ExternalIdLookup._text(row['name']),
        posterPath: ExternalIdLookup._text(row['poster_path']),
      );
    }
    return null;
  }

  final int seriesId;
  final int seasonNumber;
  final String? name;
  final String? posterPath;
}
