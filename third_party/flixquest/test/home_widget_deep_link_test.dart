import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/services/home_widget_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('links a widget can write', () {
    test('a movie link survives the round trip', () {
      final uri = HomeWidgetDeepLink.movie(
        id: 27205,
        title: 'Inception',
        posterPath: '/poster.jpg',
        backdropPath: '/backdrop.jpg',
      );
      final target = HomeWidgetDeepLink.parse(uri);
      expect(target, isA<HomeWidgetMovieTarget>());
      final movie = target as HomeWidgetMovieTarget;
      expect(movie.id, 27205);
      expect(movie.title, 'Inception');
      expect(movie.posterPath, '/poster.jpg');
      expect(movie.backdropPath, '/backdrop.jpg');
    });

    test('a series link survives the round trip', () {
      final target = HomeWidgetDeepLink.parse(
        HomeWidgetDeepLink.tv(id: 1396, name: 'Breaking Bad'),
      );
      expect(target, isA<HomeWidgetTvTarget>());
      final show = target as HomeWidgetTvTarget;
      expect(show.id, 1396);
      expect(show.name, 'Breaking Bad');
      expect(show.posterPath, isNull);
    });

    test('an episode link keeps both of its numbers', () {
      final target = HomeWidgetDeepLink.parse(HomeWidgetDeepLink.episode(
        seriesId: 1396,
        seasonNumber: 4,
        episodeNumber: 13,
        seriesName: 'Breaking Bad',
        posterPath: '/series-poster.jpg',
        stillPath: '/still.jpg',
      ));
      expect(target, isA<HomeWidgetEpisodeTarget>());
      final episode = target as HomeWidgetEpisodeTarget;
      expect(episode.seriesId, 1396);
      expect(episode.seasonNumber, 4);
      expect(episode.episodeNumber, 13);
      expect(episode.seriesName, 'Breaking Bad');
      expect(episode.posterPath, '/series-poster.jpg');
      expect(episode.stillPath, '/still.jpg');
    });

    test('the screens that need no target parse to themselves', () {
      expect(
        HomeWidgetDeepLink.parse(HomeWidgetDeepLink.wellness),
        isA<HomeWidgetWellnessTarget>(),
      );
      expect(
        HomeWidgetDeepLink.parse(HomeWidgetDeepLink.myList),
        isA<HomeWidgetMyListTarget>(),
      );
      expect(
        HomeWidgetDeepLink.parse(HomeWidgetDeepLink.home),
        isA<HomeWidgetHomeTarget>(),
      );
    });

    test('blank names and artwork are left out rather than written empty', () {
      final uri = HomeWidgetDeepLink.movie(id: 5, title: '   ', posterPath: '');
      expect(uri.queryParameters.keys, <String>['id']);
      final movie =
          HomeWidgetDeepLink.parse(uri)! as HomeWidgetMovieTarget;
      expect(movie.title, isNull);
      expect(movie.posterPath, isNull);
    });

    test('a whole image URL is not carried as a path', () {
      // A session played from a download records the URL it displayed, not the path behind it.
      final uri = HomeWidgetDeepLink.episode(
        seriesId: 1396,
        seasonNumber: 4,
        episodeNumber: 13,
        posterPath: 'https://image.tmdb.org/t/p/w500/series-poster.jpg',
        stillPath: '/still.jpg',
      );
      final episode =
          HomeWidgetDeepLink.parse(uri)! as HomeWidgetEpisodeTarget;
      expect(episode.posterPath, isNull);
      expect(episode.stillPath, '/still.jpg');
    });

    test('a link written by an older build still parses', () {
      final target = HomeWidgetDeepLink.parse(
        Uri.parse('flixquest://movie?id=27205&title=Inception&date=2010-07-15'),
      );
      expect((target! as HomeWidgetMovieTarget).id, 27205);
    });
  });

  group('links this app did not write', () {
    test('another scheme is not ours to open', () {
      expect(
        HomeWidgetDeepLink.parse(Uri.parse('https://movie?id=1')),
        isNull,
      );
    });

    test('an unknown screen is refused', () {
      expect(
        HomeWidgetDeepLink.parse(Uri.parse('flixquest://podcast?id=1')),
        isNull,
      );
    });

    test('a title that cannot be identified is refused', () {
      expect(HomeWidgetDeepLink.parse(Uri.parse('flixquest://movie')), isNull);
      expect(
        HomeWidgetDeepLink.parse(Uri.parse('flixquest://tv?id=later')),
        isNull,
      );
      expect(
        HomeWidgetDeepLink.parse(Uri.parse('flixquest://episode?id=x&season=1&episode=2')),
        isNull,
      );
    });

    test('an episode missing its numbers opens the series it belongs to', () {
      final target = HomeWidgetDeepLink.parse(
        Uri.parse('flixquest://episode?id=1396&name=Breaking%20Bad'),
      );
      expect(target, isA<HomeWidgetTvTarget>());
      expect((target! as HomeWidgetTvTarget).id, 1396);
    });
  });

  group('where a continue-watching entry points', () {
    test('a movie session opens that movie', () {
      final target = HomeWidgetDeepLink.parse(
        HomeWidgetDeepLink.session(_session(
          contentId: '27205',
          title: 'Inception',
          posterPath: '/poster.jpg',
        )),
      )!;
      expect(target, isA<HomeWidgetMovieTarget>());
      final movie = target as HomeWidgetMovieTarget;
      expect(movie.id, 27205);
      expect(movie.title, 'Inception');
      expect(movie.posterPath, '/poster.jpg');
    });

    test('an episode session opens that episode, not its series', () {
      final target = HomeWidgetDeepLink.parse(
        HomeWidgetDeepLink.session(_session(
          mediaType: WellnessMediaType.episode,
          contentId: '62161',
          seriesId: '1396',
          title: 'Breaking Bad',
          seasonNumber: 4,
          episodeNumber: 13,
          posterPath: '/series-poster.jpg',
          backdropPath: '/still.jpg',
        )),
      )!;
      expect(target, isA<HomeWidgetEpisodeTarget>());
      final episode = target as HomeWidgetEpisodeTarget;
      expect(episode.seriesId, 1396);
      expect(episode.seasonNumber, 4);
      expect(episode.episodeNumber, 13);
      expect(episode.seriesName, 'Breaking Bad');
      // The series poster is what the episode page and playback need; the still is the artwork.
      expect(episode.posterPath, '/series-poster.jpg');
      expect(episode.stillPath, '/still.jpg');
    });

    test('an episode that never recorded its numbers falls back to the series',
        () {
      final target = HomeWidgetDeepLink.parse(
        HomeWidgetDeepLink.session(_session(
          mediaType: WellnessMediaType.episode,
          contentId: '1396:0:0',
          seriesId: '1396',
          title: 'Breaking Bad',
        )),
      )!;
      expect(target, isA<HomeWidgetTvTarget>());
      expect((target as HomeWidgetTvTarget).name, 'Breaking Bad');
    });

    test('a session with nowhere to point falls back to the week', () {
      expect(HomeWidgetDeepLink.session(null), HomeWidgetDeepLink.wellness);
      expect(
        HomeWidgetDeepLink.session(_session(
          mediaType: WellnessMediaType.episode,
          contentId: 'unknown:1:2',
          title: 'Something',
          seasonNumber: 1,
          episodeNumber: 2,
        )),
        HomeWidgetDeepLink.wellness,
      );
      expect(
        HomeWidgetDeepLink.session(_session(
          mediaType: WellnessMediaType.live,
          contentId: 'channel-4',
          title: 'Channel 4',
        )),
        HomeWidgetDeepLink.wellness,
      );
      expect(
        HomeWidgetDeepLink.session(_session(
          contentId: 'not-a-tmdb-id',
          title: 'Mystery',
        )),
        HomeWidgetDeepLink.wellness,
      );
    });
  });
}

WellnessViewingSession _session({
  required String contentId,
  required String title,
  WellnessMediaType mediaType = WellnessMediaType.movie,
  String? seriesId,
  int? seasonNumber,
  int? episodeNumber,
  String? posterPath,
  String? backdropPath,
}) {
  final start = DateTime.utc(2026, 3, 1, 20);
  final end = start.add(const Duration(minutes: 40));
  return WellnessViewingSession(
    id: 'session-$contentId',
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: mediaType,
    source: WellnessPlaybackSource.streaming,
    contentId: contentId,
    seriesId: seriesId,
    title: title,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    posterPath: posterPath,
    backdropPath: backdropPath,
    startedAtUtc: start,
    endedAtUtc: end,
    timezoneOffsetMinutes: 0,
    watchedMs: end.difference(start).inMilliseconds,
    durationMs: end.difference(start).inMilliseconds,
    progressEndMs: end.difference(start).inMilliseconds,
    completed: false,
    segments: <WellnessPlaybackSegment>[
      WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end),
    ],
    updatedAtUtc: end,
  );
}
