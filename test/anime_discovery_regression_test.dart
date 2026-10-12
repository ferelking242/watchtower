import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';

AnilistMedia _media({
  required int id,
  String? title,
  List<String> genres = const [],
  String? banner,
  String? cover,
  String? studio,
}) => AnilistMedia.fromJson({
  'id': id,
  'type': 'ANIME',
  'title': {'english': title ?? 'Title $id'},
  'genres': genres,
  if (banner != null) 'bannerImage': banner,
  if (cover != null) 'coverImage': {'large': cover, 'extraLarge': cover},
  if (studio != null)
    'studios': {
      'nodes': [
        {'id': 1, 'name': studio, 'favourites': 10},
      ],
    },
});

void main() {
  group('AniList media parsing', () {
    test('reads extended anime metadata and studio', () {
      final media = AnilistMedia.fromJson({
        'id': 42,
        'type': 'ANIME',
        'format': 'TV',
        'status': 'RELEASING',
        'season': 'FALL',
        'seasonYear': 2026,
        'countryOfOrigin': 'JP',
        'averageScore': 87,
        'popularity': 120000,
        'favourites': 5400,
        'episodes': 24,
        'duration': 24,
        'source': 'MANGA',
        'genres': ['Action', 'Fantasy'],
        'title': {'romaji': 'Romaji', 'english': 'English'},
        'coverImage': {'large': 'cover-l', 'extraLarge': 'cover-xl'},
        'bannerImage': 'banner.jpg',
        'studios': {
          'nodes': [
            {'id': 43, 'name': 'ufotable', 'favourites': 15145},
            {'id': 1, 'name': 'Aniplex', 'favourites': 3},
          ],
        },
        'nextAiringEpisode': {'episode': 5, 'airingAt': 1792333800},
      });

      expect(media.status, 'RELEASING');
      expect(media.seasonYear, 2026);
      expect(media.duration, 24);
      expect(media.popularity, 120000);
      expect(media.source, 'MANGA');
      expect(media.mainStudio, 'ufotable');
      expect(media.studiosLabel, 'ufotable · Aniplex');
      expect(media.nextEpisodeNumber, 5);
      expect(media.nextAiringAt, isNotNull);
      expect(media.bestBackdrop, 'banner.jpg');
    });

    test('bestBackdrop falls back to the portrait cover', () {
      final media = _media(id: 1, cover: 'cover.jpg');
      expect(media.bestBackdrop, 'cover.jpg');
      expect(media.mainStudio, isNull);
    });

    test('parses top studios payload', () {
      final studios = _parseStudiosForTest({
        'studios': [
          {'id': 2, 'name': 'Kyoto Animation', 'favourites': 23511},
          {'id': 11, 'name': 'MADHOUSE', 'favourites': 20043},
        ],
      });
      expect(studios.map((s) => s.name), ['Kyoto Animation', 'MADHOUSE']);
      expect(studios.first.favourites, 23511);
    });
  });

  group('ContentItem', () {
    test('anilist item exposes a wide backdrop image and studio meta', () {
      final media = _media(
        id: 7,
        genres: ['Action'],
        banner: 'b.jpg',
        studio: 'MAPPA',
      );
      final item = ContentItem.fromAnilist(media);
      expect(item.imageUrl, 'b.jpg');
      expect(item.backdropUrl, 'b.jpg');
      expect(item.meta, 'MAPPA');
    });

    test('genre tile keeps its label and artwork', () {
      final tile = ContentItem.genreTile(label: 'Action', imageUrl: 'a.jpg');
      expect(tile.title, 'Action');
      expect(tile.imageUrl, 'a.jpg');
      expect(tile.posterUrl, 'a.jpg');
    });
  });

  group('enrichCategoryImages', () {
    test('matches a genre to a real artwork and de-duplicates tiles', () {
      final categories = animeCategories();
      // Enough distinct artworks for every tile, with two exact genre hits.
      final media = <AnilistMedia>[
        _media(id: 0, genres: ['Action'], banner: 'action.jpg'),
        _media(id: 1, genres: ['Romance'], banner: 'romance.jpg'),
        for (var i = 2; i <= 40; i++)
          _media(id: i, genres: const ['Drama'], banner: 'art-$i.jpg'),
      ];

      final enriched = enrichCategoryImages(categories, media);
      final byLabel = {for (final c in enriched) c.label: c.imageUrl};

      expect(byLabel['Action'], 'action.jpg');
      expect(byLabel['Romance'], 'romance.jpg');
      // Every tile ends up with a real artwork, never a bare gradient.
      expect(byLabel.values.every((v) => v != null), isTrue);
      // No two tiles share the same picture.
      final used = enriched.map((c) => c.imageUrl).whereType<String>().toList();
      expect(used.toSet().length, used.length);
    });

    test('prefers the portrait cover when preferBanner is false', () {
      final categories = [
        const CategoryDef(
          label: 'Action',
          icon: Icons.flash_on_rounded,
          gradient: [Colors.red, Colors.orange],
          mediaType: 'ANIME',
          genre: 'Action',
        ),
      ];
      final media = [
        _media(id: 1, genres: ['Action'], banner: 'banner.jpg', cover: 'cover.jpg'),
      ];
      expect(
        enrichCategoryImages(categories, media).single.imageUrl,
        'banner.jpg',
      );
      expect(
        enrichCategoryImages(categories, media, preferBanner: false)
            .single
            .imageUrl,
        'cover.jpg',
      );
    });

    test('returns the categories untouched when there is no media', () {
      final categories = animeCategories();
      expect(enrichCategoryImages(categories, const []), same(categories));
      expect(enrichCategoryImages(categories, null), same(categories));
    });
  });

  group('TmdbMoviesListScreen.anilist', () {
    testWidgets('renders the catalogue grid from pre-loaded items', (
      tester,
    ) async {
      final items = [
        _media(id: 1, title: 'Alpha', genres: ['Action'], banner: 'a.jpg'),
        _media(id: 2, title: 'Beta', genres: ['Romance'], banner: 'b.jpg'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TmdbMoviesListScreen.anilist(
              title: 'Anime populaires',
              filter: const AnilistBrowseFilter(mediaType: 'ANIME'),
              initialAnilistItems: items,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Anime populaires'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loads the first page from the browse provider', (tester) async {
      final requestedFilters = <AnilistBrowseFilter>[];
      final page = AnilistBrowsePage(
        items: [_media(id: 9, title: 'Loaded Title', genres: ['Action'])],
        hasNextPage: false,
        currentPage: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anilistBrowseProvider.overrideWith((ref, filter) {
              requestedFilters.add(filter);
              return Future.value(page);
            }),
          ],
          child: MaterialApp(
            home: TmdbMoviesListScreen.anilist(
              title: 'Tendances',
              filter: const AnilistBrowseFilter(
                mediaType: 'ANIME',
                sort: 'TRENDING_DESC',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loaded Title'), findsOneWidget);
      expect(requestedFilters.single.sort, 'TRENDING_DESC');
      expect(tester.takeException(), isNull);
    });

    testWidgets('preserves the requested favourites sort', (tester) async {
      final requestedFilters = <AnilistBrowseFilter>[];
      final page = AnilistBrowsePage(
        items: [_media(id: 10, title: 'Favourite Title')],
        hasNextPage: false,
        currentPage: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anilistBrowseProvider.overrideWith((ref, filter) {
              requestedFilters.add(filter);
              return Future.value(page);
            }),
          ],
          child: MaterialApp(
            home: TmdbMoviesListScreen.anilist(
              title: 'Favoris',
              filter: const AnilistBrowseFilter(
                mediaType: 'ANIME',
                sort: 'FAVOURITES_DESC',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favourite Title'), findsOneWidget);
      expect(requestedFilters.single.sort, 'FAVOURITES_DESC');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirrors the private studio parser so the payload shape is covered without
/// exposing the service internals.
List<AnilistStudio> _parseStudiosForTest(Map<String, dynamic> page) {
  final studios = page['studios'];
  if (studios is! List) return const [];
  return studios
      .whereType<Map>()
      .map((e) => AnilistStudio.fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}
