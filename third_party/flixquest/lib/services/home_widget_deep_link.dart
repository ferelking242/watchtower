import '../models/wellness.dart';

/// Every link a home screen widget can hand back to the app, written and read in one place.
///
/// A widget lives outside the app's memory, so a tap can only carry an identity across: an id, and
/// the name and artwork already on screen. The record behind it — rating, vote count, synopsis — is
/// fetched once the app is running, which makes a link's only job naming its target precisely enough
/// to reach the screen the widget was showing. Writing and parsing that identity in the same file is
/// what stops a widget from naming an episode the app can only open as a series.
class HomeWidgetDeepLink {
  const HomeWidgetDeepLink._();

  static const String scheme = 'flixquest';

  /// Screens that need nothing beyond themselves to open.
  static final Uri home = Uri(scheme: scheme, host: 'home');
  static final Uri wellness = Uri(scheme: scheme, host: 'wellness');
  static final Uri myList = Uri(scheme: scheme, host: 'my-list');

  static Uri movie({
    required int id,
    String? title,
    String? posterPath,
    String? backdropPath,
  }) =>
      Uri(
        scheme: scheme,
        host: 'movie',
        queryParameters: _params(<String, String?>{
          'id': id.toString(),
          'title': title,
          'poster': _artwork(posterPath),
          'backdrop': _artwork(backdropPath),
        }),
      );

  static Uri tv({
    required int id,
    String? name,
    String? posterPath,
    String? backdropPath,
  }) =>
      Uri(
        scheme: scheme,
        host: 'tv',
        queryParameters: _params(<String, String?>{
          'id': id.toString(),
          'name': name,
          'poster': _artwork(posterPath),
          'backdrop': _artwork(backdropPath),
        }),
      );

  /// One episode of a series. [seriesId] is the TMDB series id, because that plus the two numbers is
  /// what addresses an episode; the episode's own id cannot be looked up on its own.
  static Uri episode({
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    String? seriesName,
    String? posterPath,
    String? stillPath,
  }) =>
      Uri(
        scheme: scheme,
        host: 'episode',
        queryParameters: _params(<String, String?>{
          'id': seriesId.toString(),
          'season': seasonNumber.toString(),
          'episode': episodeNumber.toString(),
          'name': seriesName,
          'poster': _artwork(posterPath),
          'still': _artwork(stillPath),
        }),
      );

  /// Where a continue-watching entry belongs.
  ///
  /// An episode opens as an episode only when the session recorded which series, season and number
  /// it belonged to. Short of that the series page is the closest thing to the title on the widget,
  /// and the insights screen is the last resort — never a page about some other title.
  static Uri session(WellnessViewingSession? session) {
    if (session == null) return wellness;
    switch (session.mediaType) {
      case WellnessMediaType.movie:
        final id = int.tryParse(session.contentId);
        return id == null
            ? wellness
            : movie(
                id: id,
                title: session.title,
                posterPath: session.posterPath,
                backdropPath: session.backdropPath,
              );
      case WellnessMediaType.episode:
        final seriesId = int.tryParse(session.seriesId ?? '');
        if (seriesId == null) return wellness;
        final seasonNumber = session.seasonNumber;
        final episodeNumber = session.episodeNumber;
        if (seasonNumber == null || episodeNumber == null) {
          return tv(
            id: seriesId,
            name: session.title,
            posterPath: session.posterPath,
            backdropPath: session.backdropPath,
          );
        }
        return episode(
          seriesId: seriesId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          seriesName: session.title,
          posterPath: session.posterPath,
          // An episode session carries the episode still here, not a series backdrop.
          stillPath: session.backdropPath,
        );
      case WellnessMediaType.live:
        return wellness;
    }
  }

  /// Reads a tapped link. Returns null for anything this app did not write.
  static HomeWidgetTarget? parse(Uri uri) {
    if (uri.scheme != scheme) return null;
    final params = uri.queryParameters;
    final id = int.tryParse(params['id'] ?? '');
    switch (uri.host) {
      case 'movie':
        return id == null
            ? null
            : HomeWidgetMovieTarget(
                id: id,
                title: _text(params['title']),
                posterPath: _artwork(params['poster']),
                backdropPath: _artwork(params['backdrop']),
              );
      case 'tv':
        return id == null
            ? null
            : HomeWidgetTvTarget(
                id: id,
                name: _text(params['name']),
                posterPath: _artwork(params['poster']),
                backdropPath: _artwork(params['backdrop']),
              );
      case 'episode':
        if (id == null) return null;
        final seasonNumber = int.tryParse(params['season'] ?? '');
        final episodeNumber = int.tryParse(params['episode'] ?? '');
        // An episode that cannot say which one it is still knows its series, and the series page is
        // a better answer than nothing happening at all.
        if (seasonNumber == null || episodeNumber == null) {
          return HomeWidgetTvTarget(
            id: id,
            name: _text(params['name']),
            posterPath: _artwork(params['poster']),
          );
        }
        return HomeWidgetEpisodeTarget(
          seriesId: id,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          seriesName: _text(params['name']),
          posterPath: _artwork(params['poster']),
          stillPath: _artwork(params['still']),
        );
      case 'wellness':
        return const HomeWidgetWellnessTarget();
      case 'my-list':
        return const HomeWidgetMyListTarget();
      case 'home':
        return const HomeWidgetHomeTarget();
    }
    return null;
  }

  static Map<String, String> _params(Map<String, String?> values) {
    final params = <String, String>{};
    values.forEach((key, value) {
      final text = _text(value);
      if (text != null) params[key] = text;
    });
    return params;
  }

  /// Artwork travels as a TMDB path, the only shape the app can size, cache and store. A session
  /// played from a download records a whole image URL instead, and that cannot stand in for a path:
  /// the screen it opens would build a URL out of a URL, and would save it that way too. Dropping it
  /// leaves the poster to be fetched with the rest of the record.
  static String? _artwork(String? value) {
    final text = _text(value);
    return text == null || !text.startsWith('/') ? null : text;
  }

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// What a tapped widget points at.
///
/// The artwork and name a target carries are the ones the widget was already showing. They are there
/// so the wait for the record looks like the page arriving, and are never a substitute for it.
sealed class HomeWidgetTarget {
  const HomeWidgetTarget();
}

class HomeWidgetMovieTarget extends HomeWidgetTarget {
  const HomeWidgetMovieTarget({
    required this.id,
    this.title,
    this.posterPath,
    this.backdropPath,
  });

  final int id;
  final String? title;
  final String? posterPath;
  final String? backdropPath;
}

class HomeWidgetTvTarget extends HomeWidgetTarget {
  const HomeWidgetTvTarget({
    required this.id,
    this.name,
    this.posterPath,
    this.backdropPath,
  });

  final int id;
  final String? name;
  final String? posterPath;
  final String? backdropPath;
}

class HomeWidgetEpisodeTarget extends HomeWidgetTarget {
  const HomeWidgetEpisodeTarget({
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.seriesName,
    this.posterPath,
    this.stillPath,
  });

  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String? seriesName;

  /// Poster of the series, which is what the episode page shows and what playback is recorded with.
  final String? posterPath;

  /// The episode's own still.
  final String? stillPath;
}

class HomeWidgetWellnessTarget extends HomeWidgetTarget {
  const HomeWidgetWellnessTarget();
}

class HomeWidgetMyListTarget extends HomeWidgetTarget {
  const HomeWidgetMyListTarget();
}

class HomeWidgetHomeTarget extends HomeWidgetTarget {
  const HomeWidgetHomeTarget();
}
