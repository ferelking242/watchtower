import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

Map<String, dynamic> _mediaJson({
  required int id,
  String? title,
  String type = 'ANIME',
  String? format = 'TV',
  int? popularity,
  String country = 'JP',
  List<String> genres = const ['Action'],
  List<Map<String, dynamic>> relatedNodes = const [],
  List<String> relationTypes = const [],
}) => {
  'id': id,
  'type': type,
  'format': format,
  'countryOfOrigin': country,
  'popularity': popularity,
  'title': {'english': title ?? 'Title $id'},
  'coverImage': {'large': 'https://images.test/$id.jpg'},
  'genres': genres,
  if (relatedNodes.isNotEmpty)
    'relations': {
      'nodes': relatedNodes,
      'edges': [
        for (final relationType in relationTypes)
          {'relationType': relationType},
      ],
    },
};

Map<String, dynamic> _relationNode({
  required int id,
  String type = 'ANIME',
  String? title,
}) => {
  'id': id,
  'type': type,
  'format': 'TV',
  'title': {'english': title ?? 'Related $id'},
  'coverImage': {'large': 'https://images.test/$id.jpg'},
};

void main() {
  group('AniList browse requests', () {
    test('builds Anime and Manga requests with each supported filter', () {
      final anime = buildAnilistBrowseRequest(
        const AnilistBrowseFilter(
          mediaType: 'ANIME',
          genre: 'Action',
          format: 'TV',
          country: 'JP',
          sort: 'TRENDING_DESC',
          page: 2,
        ),
      );
      final animeVariables = anime['variables'] as Map<String, dynamic>;

      expect(anime['query'], contains(r'Page(page: $page'));
      expect(anime['query'], isNot(contains('studioId')));
      expect(animeVariables, containsPair('type', 'ANIME'));
      expect(animeVariables, containsPair('genre', 'Action'));
      expect(animeVariables, containsPair('format', 'TV'));
      expect(animeVariables, containsPair('country', 'JP'));
      expect(animeVariables, containsPair('sort', ['TRENDING_DESC']));
      expect(animeVariables, containsPair('page', 2));

      final manga = buildAnilistBrowseRequest(
        const AnilistBrowseFilter(
          mediaType: 'MANGA',
          genre: 'Drama',
          format: 'NOVEL',
          country: 'JP',
          mediaIds: [7, 8],
          sort: 'FAVOURITES_DESC',
        ),
      );
      final mangaVariables = manga['variables'] as Map<String, dynamic>;
      expect(mangaVariables, containsPair('type', 'MANGA'));
      expect(mangaVariables, containsPair('genre', 'Drama'));
      expect(mangaVariables, containsPair('format', 'NOVEL'));
      expect(mangaVariables, containsPair('country', 'JP'));
      expect(mangaVariables, containsPair('ids', [7, 8]));
      expect(mangaVariables, containsPair('sort', ['FAVOURITES_DESC']));
      expect(manga['query'], contains(r'id_in: $ids'));
    });

    test('routes studio requests through Studio.media', () {
      final request = buildAnilistBrowseRequest(
        const AnilistBrowseFilter(
          mediaType: 'ANIME',
          studioId: 17,
          sort: 'SCORE_DESC',
          page: 3,
        ),
      );
      final query = request['query'] as String;
      final variables = request['variables'] as Map<String, dynamic>;

      expect(query, contains(r'Studio(id: $studioId)'));
      expect(query, contains(r'media(page: $page, perPage: $perPage'));
      expect(query, isNot(contains('Page(page:')));
      expect(
        query,
        isNot(
          contains(
            r'media(page: $page, perPage: $perPage, sort: $sort, isMain:',
          ),
        ),
      );
      expect(variables, containsPair('studioId', 17));
      expect(variables, containsPair('sort', ['SCORE_DESC']));
      expect(variables, containsPair('page', 3));
    });

    test('filters studio media by type and selected fields across pages', () async {
      final requestedPages = <int>[];
      final client = MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final query = payload['query'] as String;
        final variables = payload['variables'] as Map<String, dynamic>;
        final page = variables['page'] as int;
        requestedPages.add(page);
        expect(query, contains(r'Studio(id: $studioId)'));

        final nodes = page == 3
            ? [
                _mediaJson(id: 31),
                _mediaJson(id: 32, genres: ['Romance']),
                _mediaJson(id: 33, type: 'MANGA'),
                _mediaJson(id: 34, format: 'MOVIE'),
                _mediaJson(id: 35, country: 'KR'),
              ]
            : [_mediaJson(id: 36)];
        return http.Response(
          jsonEncode({
            'data': {
              'Studio': {
                'media': {
                  'pageInfo': {
                    'currentPage': page,
                    'hasNextPage': page == 3,
                  },
                  'nodes': nodes,
                },
              },
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      const filter = AnilistBrowseFilter(
        mediaType: 'ANIME',
        studioId: 17,
        genre: 'Action',
        format: 'TV',
        country: 'JP',
        sort: 'POPULARITY_DESC',
        page: 3,
      );

      final firstPage = await fetchAnilistBrowsePage(filter, client: client);
      final secondPage = await fetchAnilistBrowsePage(
        filter.copyWith(page: firstPage.currentPage + 1),
        client: client,
      );
      final mangaPage = await fetchAnilistBrowsePage(
        filter.copyWith(mediaType: 'MANGA'),
        client: client,
      );

      expect(firstPage.items.map((item) => item.id), [31]);
      expect(firstPage.currentPage, 3);
      expect(firstPage.hasNextPage, isTrue);
      expect(secondPage.items.map((item) => item.id), [36]);
      expect(secondPage.currentPage, 4);
      expect(secondPage.hasNextPage, isFalse);
      expect(mangaPage.items.map((item) => item.id), [33]);
      expect(mangaPage.items.single.type, 'MANGA');
      expect(requestedPages, [3, 4, 3]);
    });

    test(
      'surfaces AniList GraphQL errors rather than returning an empty page',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'errors': [
                {'message': 'Unknown argument studioId'},
              ],
            }),
            200,
          ),
        );
        addTearDown(client.close);

        await expectLater(
          fetchAnilistBrowsePage(
            const AnilistBrowseFilter(mediaType: 'ANIME'),
            client: client,
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('Unknown argument studioId'),
            ),
          ),
        );
      },
    );
  });

  group('verified AniList groupings', () {
    test(
      'franchises come from connected Anime relations, not title matches',
      () {
        final first = AnilistMedia.fromJson(
          _mediaJson(
            id: 1,
            popularity: 100,
            relatedNodes: [
              _relationNode(id: 2, title: 'A Completely Different Name'),
            ],
            relationTypes: ['SEQUEL'],
          ),
        );
        final second = AnilistMedia.fromJson(
          _mediaJson(
            id: 2,
            title: 'Second installment',
            popularity: 50,
            relatedNodes: [_relationNode(id: 3)],
            relationTypes: ['SIDE_STORY'],
          ),
        );
        final unsupported = AnilistMedia.fromJson(
          _mediaJson(id: 99, title: 'Dragon Ball Z'),
        );
        final mangaAdaptation = AnilistMedia.fromJson(
          _mediaJson(
            id: 4,
            relatedNodes: [
              _relationNode(id: 5, type: 'MANGA', title: 'Source manga'),
            ],
            relationTypes: ['ADAPTATION'],
          ),
        );

        final groups = buildAnilistFranchiseGroups([
          first,
          second,
          unsupported,
          mangaAdaptation,
        ]);

        expect(groups, hasLength(1));
        expect(groups.single.mediaIds, [1, 2, 3]);
        expect(groups.single.representative.title, 'Title 1');
        expect(first.relations.single.relationType, 'SEQUEL');
      },
    );

    test('collections require compilation or contains relations', () {
      final compilation = AnilistMedia.fromJson(
        _mediaJson(
          id: 10,
          relatedNodes: [_relationNode(id: 11)],
          relationTypes: ['COMPILATION'],
        ),
      );
      final titleOnly = AnilistMedia.fromJson(
        _mediaJson(id: 12, title: 'One Piece'),
      );
      final adaptation = AnilistMedia.fromJson(
        _mediaJson(
          id: 13,
          relatedNodes: [
            _relationNode(id: 14, type: 'MANGA'),
          ],
          relationTypes: ['ADAPTATION'],
        ),
      );

      final collections = buildAnilistCollectionGroups([
        compilation,
        titleOnly,
        adaptation,
      ]);

      expect(collections, hasLength(1));
      expect(collections.single.mediaIds, [10, 11]);
      expect(buildAnilistFranchiseGroups([compilation]), isEmpty);
      expect(buildAnilistCollectionGroups([titleOnly, adaptation]), isEmpty);
    });
  });
}
