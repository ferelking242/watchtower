import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/gallery_component_palette.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/catalogue_cards.dart';
import 'package:watchtower/modules/media/collection_cards.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_content_sections.dart';
import 'package:watchtower/modules/media/episode_cards.dart';
import 'package:watchtower/modules/media/home_hero_cards.dart';
import 'package:watchtower/modules/media/manga_chapter_cards.dart';
import 'package:watchtower/modules/media/manga_volume_cards.dart';
import 'package:watchtower/modules/media/rich_media_cards.dart';
import 'package:watchtower/modules/media/ranking_cards.dart';
import 'package:watchtower/modules/media/streaming_cards.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart'
    as manga_home;

const _items = [
  ContentItem(key: 'a', title: 'Alpha', badge: 'Série', rating: 8.1),
  ContentItem(key: 'b', title: 'Beta', description: 'Résumé'),
  ContentItem(key: 'c', title: 'Gamma'),
];

GalleryComponentContext _ctx(String id) =>
    GalleryComponentContext(componentId: id, items: _items, onOpen: (_) {});

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('every catalog component resolves to a renderer definition', () {
    final home = LayoutComponentRegistry.forContext(
      LayoutComponentContext.home,
      selectableOnly: true,
    );
    for (final descriptor in GalleryComponentCatalog.descriptors) {
      expect(
        LayoutComponentRegistry.resolve(descriptor.id),
        isNotNull,
        reason: 'missing definition for ${descriptor.id}',
      );
    }
    expect(home.map((d) => d.id), contains('manga-spotlight'));
    expect(home.map((d) => d.id), contains('manga-chapter'));
  });

  test('palette exposes configurable parameters per family', () {
    final rich = GalleryComponentPalette.forFamily(
      GalleryComponentFamily.richMedia,
    );
    expect(rich.map((p) => p.key), containsAll(['title', 'items', 'columns']));

    final reader = GalleryComponentPalette.forFamily(
      GalleryComponentFamily.mangaReader,
    );
    expect(
      reader.any((p) => p.key == 'readingDirection'),
      isTrue,
      reason: 'manga reader exposes its reading direction parameter',
    );
  });

  test('duplicate gallery variants are not offered for new layouts', () {
    const retiredIds = [
      'poster-card-compact',
      'discovery',
      'animated-discovery',
      'landscape',
      'episode',
      'movie-collection',
      'home-airecommender',
      'home-mini-player',
      'expandable-movie',
      'hover-movie',
      'movie-quick-view',
      'media-quick-view',
      'media-preview',
      'movie-details-modal',
      'media-details-modal',
      'top-movies',
      'top-series',
      'top-anime',
      'top-by-genre',
      'top-by-country',
      'global-ranking',
      'top-rated-ranking',
      'trending-ranking',
      'top-by-decade',
      'must-watch',
      'season-detail',
      'home-genre-tile',
      'home-popular-rail',
      'home-read-rail',
      'landscape-discovery',
    ];
    for (final id in retiredIds) {
      expect(
        LayoutComponentRegistry.resolve(id)?.selectable,
        isFalse,
        reason: '$id must stay resolvable for old layouts but leave the picker',
      );
    }
  });

  testWidgets('family renderers build the expected production widgets', (
    tester,
  ) async {
    final families = <String, Type>{
      'movie-details': MovieDetailsCard,
      'continue-watching': ContinueWatchingCard,
      'collection': CollectionCard,
      'episode-preview': EpisodePreviewCard,
      'manga-chapter': MangaChapterCard,
      'manga-volume': MangaVolumeCard,
    };

    for (final entry in families.entries) {
      await tester.pumpWidget(
        _app(GalleryComponentRenderer.rail(_ctx(entry.key))),
      );
      await tester.pump();
      expect(
        find.byType(entry.value),
        findsWidgets,
        reason: '${entry.key} should render ${entry.value}',
      );
    }
  });

  testWidgets('items parameter limits the rendered cards', (tester) async {
    final ctx = GalleryComponentContext(
      componentId: 'manga-chapter',
      items: _items,
      params: const {'items': 2},
      onOpen: (_) {},
    );
    await tester.pumpWidget(_app(GalleryComponentRenderer.rail(ctx)));
    await tester.pump();
    expect(find.byType(MangaChapterCard), findsNWidgets(2));
  });

  testWidgets(
    'poster card keeps compact mode as a parameter on the shared card',
    (tester) async {
      final ctx = GalleryComponentContext(
        componentId: 'poster',
        items: [_items.first],
        params: const {'compact': true},
        onOpen: (_) {},
      );
      await tester.pumpWidget(_app(GalleryComponentRenderer.rail(ctx)));
      await tester.pump();

      expect(find.byType(PosterCard), findsOneWidget);
      expect(
        tester.widget<PosterCard>(find.byType(PosterCard)).compact,
        isTrue,
      );
    },
  );

  testWidgets('expanded movie selection uses the working auto-toggle card', (
    tester,
  ) async {
    final ctx = GalleryComponentContext(
      componentId: 'expanded-movie',
      items: [_items.first],
      params: const {'cast': 'Actor One'},
      onOpen: (_) {},
    );
    await tester.pumpWidget(_app(GalleryComponentRenderer.rail(ctx)));
    await tester.pumpAndSettle();

    expect(find.byType(ExpandableMovieCard), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
  });

  testWidgets('country grid shows flag emoji instead of country code', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const HomeLanguageGridCard(
          chips: [
            HomeCountryChip(label: 'Japon', code: 'JP', backgroundUrl: ''),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('🇯🇵'), findsOneWidget);
    expect(find.text('JP'), findsNothing);
  });

  testWidgets('every catalog component renders without a layout error', (
    tester,
  ) async {
    for (final descriptor in GalleryComponentCatalog.descriptors) {
      await tester.pumpWidget(
        _app(GalleryComponentRenderer.rail(_ctx(descriptor.id))),
      );
      // Let finite entrance animations (e.g. ExpandableMovieCard) finish so
      // no pending timer leaks into the next iteration.
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(
        tester.takeException(),
        isNull,
        reason: '${descriptor.id} failed to render',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('every catalog component renders on phone and desktop widths', (
    tester,
  ) async {
    for (final size in const [Size(360, 740), Size(1280, 900)]) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final descriptor in GalleryComponentCatalog.descriptors) {
        await tester.pumpWidget(
          _app(GalleryComponentRenderer.rail(_ctx(descriptor.id))),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${descriptor.id} failed to render at ${size.width.toInt()}px',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('gallery-backed definitions expose their palette parameters', () {
    final definition = LayoutComponentRegistry.resolve('media-grid');
    expect(definition, isNotNull);
    expect(
      definition!.configurableProperties,
      containsAll(['columns', 'rows', 'items', 'width', 'height']),
      reason: 'a grid definition should surface the palette parameters',
    );
  });

  test('params survive a UiSection round trip', () {
    final section = UiSection.fromJson({
      'id': 'chapters',
      'component': 'manga-chapter',
      'params': {'items': 5, 'subtitle': 'Nouveaux'},
    });
    expect(section.params['items'], 5);
    expect(section.params['subtitle'], 'Nouveaux');
    expect((section.toLegacyMap()['params'] as Map)['items'], 5);
  });

  test('every renderer parameter is configurable from layout.json', () {
    // Keys the shared renderer reads from `GalleryComponentContext`. If a card
    // starts reading a new key, it must also be exposed by the palette so a
    // layout author can set it.
    const rendererKeys = {
      'actionLabel', 'badge', 'cast', 'columns', 'compact', 'fill', 'genres',
      'hd', 'height', 'items', 'layout', 'numbered', 'period', 'progress',
      'rank', 'rankLabel', 'readingDirection', 'remaining', 'rows', 'runtime',
      'scrollDirection', 'seriesMeta', 'showCount', 'spacing', 'stats',
      'subtitle', 'tags', 'time', 'title', 'width',
    };
    final exposed = {
      for (final parameter in GalleryComponentPalette.common) parameter.key,
      for (final family in GalleryComponentFamily.values)
        for (final parameter in GalleryComponentPalette.forFamily(family))
          parameter.key,
    };
    expect(
      rendererKeys.difference(exposed),
      isEmpty,
      reason: 'renderer params missing from the palette',
    );
  });

  test('every component exposes a unique, non-empty parameter set', () {
    for (final descriptor in GalleryComponentCatalog.descriptors) {
      final parameters = GalleryComponentPalette.forDescriptor(descriptor);
      expect(parameters, isNotEmpty, reason: descriptor.id);
      final keys = parameters.map((p) => p.key).toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason: '${descriptor.id} exposes a duplicate parameter key',
      );
    }
  });

  test('every catalog component exposes a gallery family', () {
    // A gallery-backed definition always carries a `galleryFamily`, which is
    // what lets the production home screen delegate to the shared gallery
    // renderer instead of maintaining a divergent implementation.
    final missing = <String>[];
    for (final descriptor in GalleryComponentCatalog.descriptors) {
      final definition = LayoutComponentRegistry.resolve(descriptor.id);
      if (definition?.galleryFamily == null) {
        missing.add(descriptor.id);
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'these catalog components would not render in production: '
          '$missing',
    );
  });

  testWidgets('production extension preview matches the gallery renderer', (
    tester,
  ) async {
    final source = Source(name: 'Test', itemType: ItemType.manga);
    final items = [
      MManga(name: 'Alpha', imageUrl: 'https://example.test/a.jpg'),
      MManga(name: 'Beta', imageUrl: 'https://example.test/b.jpg'),
    ];

    // The extension preview must delegate to the shared gallery renderer for
    // every gallery-backed component instead of maintaining its own visuals.
    Future<void> check(String component, Type expected) async {
      await tester.pumpWidget(
        _app(
          ExtensionLayoutPreview(
            title: 'Section',
            component: component,
            source: source,
            items: items,
            onOpen: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byType(expected),
        findsWidgets,
        reason: '$component should render through $expected',
      );
      expect(tester.takeException(), isNull);
    }

    await check('media-grid', MediaGridSection);
    await check('manga-featured', manga_home.MangaFeaturedCard);
    await check('manga-chapter', MangaChapterCard);
  });

  testWidgets('ranking cards accept per-component title and subtitle', (
    tester,
  ) async {
    final ctx = GalleryComponentContext(
      componentId: 'top-movies',
      items: _items,
      params: const {'title': 'Mon top', 'subtitle': 'Cette semaine'},
      onOpen: (_) {},
    );
    await tester.pumpWidget(_app(GalleryComponentRenderer.section(ctx)));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    final card = tester.widget<TopMoviesCard>(find.byType(TopMoviesCard));
    expect(card.title, 'Mon top');
    expect(card.subtitle, 'Cette semaine');
  });

  testWidgets('genre grid and provider rail use the genres parameter', (
    tester,
  ) async {
    final ctx = GalleryComponentContext(
      componentId: 'genre-grid-section',
      items: _items,
      params: const {'genres': 'Action, Comédie', 'title': 'Genres'},
      onOpen: (_) {},
    );
    await tester.pumpWidget(_app(GalleryComponentRenderer.section(ctx)));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(find.text('Genres'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Comédie'), findsOneWidget);
  });

  testWidgets('manga ranking card reads its period parameter', (tester) async {
    final ctx = GalleryComponentContext(
      componentId: 'manga-ranking',
      items: _items,
      params: const {'period': 'monthly', 'rankLabel': 'Mon classement'},
      onOpen: (_) {},
    );
    await tester.pumpWidget(_app(GalleryComponentRenderer.section(ctx)));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    final card = tester.widget<manga_home.MangaRankingCard>(
      find.byType(manga_home.MangaRankingCard),
    );
    expect(card.title, 'Mon classement');
    expect(card.initialPeriod, 2);
  });

  testWidgets('production path has no overflow on phone and desktop', (
    tester,
  ) async {
    final source = Source(name: 'Test', itemType: ItemType.manga);
    final items = List.generate(
      12,
      (i) => MManga(
        name: 'Titre $i assez long pour tester la troncature des cartes',
        link: 'https://example.com/$i',
        imageUrl: 'https://example.com/$i.jpg',
        description: 'Description $i',
        status: Status.ongoing,
      ),
    );
    final failures = <String>[];
    final original = FlutterError.onError;

    for (final size in const [Size(360, 740), Size(1280, 900)]) {
      await tester.binding.setSurfaceSize(size);
      for (final descriptor in GalleryComponentCatalog.descriptors) {
        final errors = <String>[];
        FlutterError.onError = (details) =>
            errors.add(details.exceptionAsString());
        try {
          await tester.pumpWidget(
            _app(
              ExtensionLayoutPreview(
                title: descriptor.label,
                component: descriptor.id,
                source: source,
                items: items,
                onOpen: (_) {},
                onSeeAll: () {},
                params: const {'items': 6},
              ),
            ),
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 60));
          }
        } finally {
          FlutterError.onError = original;
        }
        if (errors.isNotEmpty) {
          failures.add(
            '${descriptor.id} @${size.width.toInt()}px: ${errors.first}',
          );
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
