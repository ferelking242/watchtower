import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/gallery_component_palette.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/collection_cards.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/episode_cards.dart';
import 'package:watchtower/modules/media/manga_chapter_cards.dart';
import 'package:watchtower/modules/media/manga_volume_cards.dart';
import 'package:watchtower/modules/media/rich_media_cards.dart';
import 'package:watchtower/modules/media/streaming_cards.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

const _items = [
  ContentItem(key: 'a', title: 'Alpha', badge: 'Série', rating: 8.1),
  ContentItem(key: 'b', title: 'Beta', description: 'Résumé'),
  ContentItem(key: 'c', title: 'Gamma'),
];

GalleryComponentContext _ctx(String id) => GalleryComponentContext(
  componentId: id,
  items: _items,
  onOpen: (_) {},
);

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
      await tester.pumpWidget(_app(GalleryComponentRenderer.rail(_ctx(entry.key))));
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

  testWidgets('every catalog component renders without a layout error', (
    tester,
  ) async {
    for (final descriptor in GalleryComponentCatalog.descriptors) {
      await tester.pumpWidget(
        _app(GalleryComponentRenderer.rail(_ctx(descriptor.id))),
      );
      // Let finite entrance animations (e.g. AnimatedDiscoveryCard) finish so
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
    expect(
      (section.toLegacyMap()['params'] as Map)['items'],
      5,
    );
  });
}
