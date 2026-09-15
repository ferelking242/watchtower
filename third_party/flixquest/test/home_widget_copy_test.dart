import 'package:flixquest/services/home_widget_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daily pick', () {
    test('subtitle carries the year and the score, separated', () {
      expect(
        HomeWidgetCopy.dailyFacts(date: '2024-03-01', rating: 8.14),
        '2024${HomeWidgetCopy.separator}8.1 rating',
      );
    });

    test('subtitle drops a fact it does not have', () {
      expect(HomeWidgetCopy.dailyFacts(date: '2024-03-01'), '2024');
      expect(HomeWidgetCopy.dailyFacts(rating: 7), '7.0 rating');
      expect(HomeWidgetCopy.dailyFacts(date: 'soon', rating: 0), '');
    });

    test('hook keeps a short synopsis whole and collapses whitespace', () {
      expect(HomeWidgetCopy.hook('  A quiet\n\nfilm.  '), 'A quiet film.');
      expect(HomeWidgetCopy.hook(null), '');
    });

    test('hook cuts a long synopsis at a word boundary', () {
      final hook = HomeWidgetCopy.hook('${'alpha ' * 40}omega');
      expect(hook.endsWith('…'), isTrue);
      expect(hook.length, lessThanOrEqualTo(109));
      expect(hook, isNot(contains('alph…')));
    });
  });

  group('durations', () {
    test('reads as hours and minutes', () {
      expect(HomeWidgetCopy.duration(45 * 60 * 1000), '45m');
      expect(HomeWidgetCopy.duration(2 * 60 * 60 * 1000), '2h');
      expect(HomeWidgetCopy.duration(200 * 60 * 1000), '3h 20m');
      expect(HomeWidgetCopy.duration(0), 'under a minute');
    });
  });

  group('insights', () {
    test('title states the total, subtitle the days, meta the rest', () {
      expect(HomeWidgetCopy.weekTotal(200 * 60 * 1000), '3h 20m watched');
      expect(HomeWidgetCopy.weekActivity(5), '5 of 7 days active');
      expect(
        HomeWidgetCopy.weekHighlights(completedTitles: 3, topGenre: 'Sci-Fi'),
        '3 titles finished${HomeWidgetCopy.separator}Top genre: Sci-Fi',
      );
    });

    test('an empty week never says the same thing twice', () {
      expect(HomeWidgetCopy.weekTotal(0), 'No viewing yet');
      expect(HomeWidgetCopy.weekActivity(0), 'Counted only on this device');
      expect(HomeWidgetCopy.weekHighlights(completedTitles: 0), '');
    });

    test('the bar matches the day count it labels', () {
      expect(HomeWidgetCopy.weekProgress(0), 0);
      expect(HomeWidgetCopy.weekProgress(7), 100);
      expect(HomeWidgetCopy.weekProgress(9), 100);
      expect(HomeWidgetCopy.weekProgress(3), 43);
    });

    test('one finished title is singular', () {
      expect(
        HomeWidgetCopy.weekHighlights(completedTitles: 1),
        '1 title finished',
      );
    });
  });

  group('continue watching', () {
    test('subtitle numbers the episode and names it', () {
      expect(
        HomeWidgetCopy.episodeFacts(
          isEpisode: true,
          season: 2,
          episode: 4,
          episodeTitle: 'Hello, Ms. Cobel',
        ),
        'S2 E4${HomeWidgetCopy.separator}Hello, Ms. Cobel',
      );
    });

    test('missing season and episode numbers arrive as zero, not as text', () {
      expect(
        HomeWidgetCopy.episodeFacts(
          isEpisode: true,
          season: 0,
          episode: 0,
          episodeTitle: 'Pilot',
        ),
        'Pilot',
      );
      expect(
        HomeWidgetCopy.episodeFacts(isEpisode: true, season: 3, episode: 0),
        'Season 3',
      );
    });

    test('a film shows its year instead', () {
      expect(
        HomeWidgetCopy.episodeFacts(isEpisode: false, releaseYear: 2021),
        '2021',
      );
      expect(HomeWidgetCopy.episodeFacts(isEpisode: false), '');
    });

    test('meta is the time left, never the percentage the bar already shows',
        () {
      expect(
        HomeWidgetCopy.remaining(
          durationMs: 60 * 60 * 1000,
          progressEndMs: 42 * 60 * 1000,
          completed: false,
        ),
        '18m left',
      );
      expect(
        HomeWidgetCopy.remaining(
          durationMs: 60 * 60 * 1000,
          progressEndMs: 60 * 60 * 1000,
          completed: true,
        ),
        'Finished — worth another look',
      );
      expect(
        HomeWidgetCopy.remaining(
          durationMs: 0,
          progressEndMs: 0,
          completed: false,
        ),
        '',
      );
    });
  });

  group('my list', () {
    test('the total is stated once, in the eyebrow', () {
      expect(
        HomeWidgetCopy.listEyebrow(12),
        'MY LIST${HomeWidgetCopy.separator}12 SAVED',
      );
      expect(HomeWidgetCopy.listEyebrow(0), 'MY LIST');
    });

    test('the breakdown drops an empty side and is singular-aware', () {
      expect(
        HomeWidgetCopy.listBreakdown(movies: 7, tvShows: 5),
        '7 movies${HomeWidgetCopy.separator}5 TV shows',
      );
      expect(HomeWidgetCopy.listBreakdown(movies: 1, tvShows: 0), '1 movie');
      expect(HomeWidgetCopy.listBreakdown(movies: 0, tvShows: 1), '1 TV show');
      expect(HomeWidgetCopy.listBreakdown(movies: 0, tvShows: 0), '');
    });

    test('meta describes the featured title, not the list', () {
      expect(
        HomeWidgetCopy.titleFacts(isMovie: true, date: '2024-03-01'),
        'Movie${HomeWidgetCopy.separator}2024',
      );
      expect(HomeWidgetCopy.titleFacts(isMovie: false), 'TV show');
    });
  });

  test('no two slots of a widget repeat a fact', () {
    final slots = <String>[
      HomeWidgetCopy.listEyebrow(12),
      'Dune: Part Two',
      HomeWidgetCopy.listBreakdown(movies: 7, tvShows: 5),
      HomeWidgetCopy.titleFacts(isMovie: true, date: '2024-03-01'),
    ];
    expect(slots.toSet().length, slots.length);
    // The saved total belongs to the eyebrow alone.
    expect(slots.where((slot) => slot.contains('12')).length, 1);
  });
}
