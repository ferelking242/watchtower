import 'package:flixquest/models/external_id_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reply TMDB sends to `/find`: one list per kind of record, only one of them filled in.
Map<String, dynamic> _reply({
  List<Object?> movies = const <Object?>[],
  List<Object?> series = const <Object?>[],
  List<Object?> people = const <Object?>[],
  List<Object?> episodes = const <Object?>[],
  List<Object?> seasons = const <Object?>[],
}) =>
    <String, dynamic>{
      'movie_results': movies,
      'person_results': people,
      'tv_results': series,
      'tv_episode_results': episodes,
      'tv_season_results': seasons,
    };

void main() {
  group('what TMDB found under an outside id', () {
    test('a film comes back with what the wait can show', () {
      final lookup = ExternalIdLookup.fromJson(_reply(movies: <Object?>[
        <String, dynamic>{
          'id': 550,
          'title': 'Fight Club',
          'poster_path': '/poster.jpg',
          'backdrop_path': '/backdrop.jpg',
        },
      ]));
      expect(lookup.isEmpty, isFalse);
      expect(lookup.movie?.id, 550);
      expect(lookup.movie?.title, 'Fight Club');
      expect(lookup.movie?.posterPath, '/poster.jpg');
      expect(lookup.movie?.backdropPath, '/backdrop.jpg');
      expect(lookup.match, same(lookup.movie));
    });

    test(
        'a series is read from its own key, which spells the title differently',
        () {
      final lookup = ExternalIdLookup.fromJson(_reply(series: <Object?>[
        <String, dynamic>{'id': 1396, 'name': 'Breaking Bad'},
      ]));
      expect(lookup.tv?.id, 1396);
      expect(lookup.tv?.title, 'Breaking Bad');
      expect(lookup.movie, isNull);
      expect(lookup.match, same(lookup.tv));
    });

    test('an episode arrives already addressed by series and number', () {
      final lookup = ExternalIdLookup.fromJson(_reply(episodes: <Object?>[
        <String, dynamic>{
          'id': 62161,
          'show_id': 1396,
          'season_number': 5,
          'episode_number': 14,
          'name': 'Ozymandias',
          'still_path': '/still.jpg',
        },
      ]));
      expect(lookup.episode?.seriesId, 1396);
      expect(lookup.episode?.seasonNumber, 5);
      expect(lookup.episode?.episodeNumber, 14);
      expect(lookup.episode?.name, 'Ozymandias');
      expect(lookup.episode?.stillPath, '/still.jpg');
    });

    test('an episode outranks the series it belongs to', () {
      final lookup = ExternalIdLookup.fromJson(_reply(
        series: <Object?>[
          <String, dynamic>{'id': 1396, 'name': 'Breaking Bad'},
        ],
        episodes: <Object?>[
          <String, dynamic>{
            'show_id': 1396,
            'season_number': 5,
            'episode_number': 14,
          },
        ],
      ));
      expect(lookup.match, same(lookup.episode));
    });

    test('a season outranks the series but not an episode', () {
      final seasonOnly = ExternalIdLookup.fromJson(_reply(
        series: <Object?>[
          <String, dynamic>{'id': 1396, 'name': 'Breaking Bad'},
        ],
        seasons: <Object?>[
          <String, dynamic>{
            'show_id': 1396,
            'season_number': 5,
            'name': 'Season 5',
            'poster_path': '/season.jpg',
          },
        ],
      ));
      expect(seasonOnly.match, same(seasonOnly.season));
      expect(seasonOnly.season?.seasonNumber, 5);
      expect(seasonOnly.season?.name, 'Season 5');

      final withEpisode = ExternalIdLookup.fromJson(_reply(
        seasons: <Object?>[
          <String, dynamic>{'show_id': 1396, 'season_number': 5},
        ],
        episodes: <Object?>[
          <String, dynamic>{
            'show_id': 1396,
            'season_number': 5,
            'episode_number': 14,
          },
        ],
      ));
      expect(withEpisode.match, same(withEpisode.episode));
    });

    test('a person keeps the flag the app gates adult work on', () {
      final lookup = ExternalIdLookup.fromJson(_reply(people: <Object?>[
        <String, dynamic>{
          'id': 1245,
          'name': 'Scarlett Johansson',
          'profile_path': '/profile.jpg',
          'adult': false,
        },
      ]));
      expect(lookup.person?.id, 1245);
      expect(lookup.person?.name, 'Scarlett Johansson');
      expect(lookup.person?.profilePath, '/profile.jpg');
      expect(lookup.person?.adult, isFalse);
      expect(lookup.match, same(lookup.person));
    });

    test('specials are season zero, which is not the same as no season', () {
      final lookup = ExternalIdLookup.fromJson(_reply(seasons: <Object?>[
        <String, dynamic>{'show_id': 1396, 'season_number': 0},
      ]));
      expect(lookup.season?.seasonNumber, 0);
      expect(lookup.isEmpty, isFalse);
    });

    test('nothing found is an answer, not a failure', () {
      final lookup = ExternalIdLookup.fromJson(_reply());
      expect(lookup.isEmpty, isTrue);
      expect(lookup.match, isNull);
    });

    test('a reply missing its keys altogether reads as nothing found', () {
      final lookup = ExternalIdLookup.fromJson(<String, dynamic>{});
      expect(lookup.isEmpty, isTrue);
    });

    test('a row that cannot be addressed is skipped, not guessed at', () {
      final lookup = ExternalIdLookup.fromJson(_reply(
        movies: <Object?>[
          'not a row',
          <String, dynamic>{'title': 'No id here'},
          <String, dynamic>{'id': 550, 'title': 'Fight Club'},
        ],
        episodes: <Object?>[
          <String, dynamic>{'show_id': 1396, 'season_number': 5},
        ],
      ));
      expect(lookup.movie?.id, 550);
      expect(lookup.episode, isNull);
      expect(lookup.match, same(lookup.movie));
    });

    test('an id sent as text is still an id', () {
      final lookup = ExternalIdLookup.fromJson(_reply(movies: <Object?>[
        <String, dynamic>{'id': '550', 'title': '   '},
      ]));
      expect(lookup.movie?.id, 550);
      expect(lookup.movie?.title, isNull);
    });
  });
}
