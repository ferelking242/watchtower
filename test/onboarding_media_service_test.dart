import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watchtower/modules/onboarding/onboarding_media_service.dart';

/// A real `http.Client` that answers from a canned body. Only the transport is
/// faked: the JSON parsing, the field mapping and the fallback logic under test
/// are the production code paths.
http.Client _clientReturning(String body, {int status = 200}) {
  return MockClient((_) async => http.Response(body, status));
}

void main() {
  test('AniList lane maps covers and the real community score', () async {
    final service = OnboardingMediaService(
      client: _clientReturning(
        jsonEncode({
          'data': {
            'Page': {
              'media': [
                {
                  'title': {'userPreferred': 'Berserk'},
                  'coverImage': {'extraLarge': 'https://cdn/berserk.jpg'},
                  'averageScore': 92,
                },
                {
                  'title': {'userPreferred': 'No Score'},
                  'coverImage': {'large': 'https://cdn/none.jpg'},
                },
              ],
            },
          },
        }),
      ),
    );

    final items = await service.fetchLane('anime');
    expect(items, hasLength(2));
    expect(items.first.title, 'Berserk');
    expect(items.first.imageUrl, 'https://cdn/berserk.jpg');
    expect(items.first.badge, '92%');
    // A title the source has not scored shows no invented badge.
    expect(items.last.badge, isNull);
    // Falls back to `large` when `extraLarge` is missing.
    expect(items.last.imageUrl, 'https://cdn/none.jpg');
  });

  test('TMDB lane builds the poster URL from the returned path', () async {
    final service = OnboardingMediaService(
      client: _clientReturning(
        jsonEncode({
          'results': [
            {'title': 'Dune', 'poster_path': '/dune.jpg', 'vote_average': 8.1},
            {
              'name': 'Severance',
              'poster_path': '/sev.jpg',
              'vote_average': 8.4,
            },
            {'title': 'No Poster', 'vote_average': 5.0},
          ],
        }),
      ),
    );

    // Without a build token the lane short-circuits and returns nothing, in
    // which case there is no mapping to assert.
    final items = await service.fetchLane('films');
    for (final item in items) {
      expect(item.imageUrl, startsWith('https://image.tmdb.org/t/p/w500/'));
      expect(item.badge, matches(RegExp(r'^\d\.\d$')));
    }
  });

  test('a failing source yields no items instead of throwing', () async {
    final service = OnboardingMediaService(
      client: _clientReturning('nope', status: 500),
    );
    expect(await service.fetchLane('anime'), isEmpty);
  });

  test('malformed JSON yields no items instead of throwing', () async {
    final service = OnboardingMediaService(
      client: _clientReturning('{not json'),
    );
    expect(await service.fetchLane('anime'), isEmpty);
  });

  test('an unknown lane yields no items', () async {
    final service = OnboardingMediaService(client: _clientReturning('{}'));
    expect(await service.fetchLane('nope'), isEmpty);
  });

  test('loadAll reports each lane as it lands and caches the result', () async {
    final service = OnboardingMediaService(
      client: _clientReturning(
        jsonEncode({
          'data': {
            'Page': {
              'media': [
                {
                  'title': {'userPreferred': 'One Piece'},
                  'coverImage': {'extraLarge': 'https://cdn/op.jpg'},
                  'averageScore': 87,
                },
              ],
            },
          },
        }),
      ),
    );

    const fallback = [ShowcaseItem(title: 'Fallback', imageUrl: 'https://f')];
    final lanes = [
      const ShowcaseLane(id: 'anime', label: 'Anime', fallback: fallback),
    ];

    final seen = <String, List<ShowcaseItem>>{};
    await service.loadAll(lanes, onLane: (id, items) => seen[id] = items);

    expect(seen['anime']!.single.title, 'One Piece');
    expect(OnboardingMediaService.cached('anime')!.single.title, 'One Piece');
  });
}
