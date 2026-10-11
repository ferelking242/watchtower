import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

/// Widths that map to the four `AppUI` device kinds: phone (<600),
/// tablet (600–1023), desktop (1024–1599) and TV (>=1600).
const _breakpoints = <String, double>{
  'phone': 360,
  'tablet': 900,
  'desktop': 1400,
  'tv': 1920,
};

const _items = <ContentItem>[
  ContentItem(
    key: 'a',
    title: 'Alpha',
    badge: 'Serie',
    rating: 8.1,
    description: 'Resume du contenu Alpha',
  ),
  ContentItem(key: 'b', title: 'Beta', badge: 'Film', description: 'Resume'),
  ContentItem(key: 'c', title: 'Gamma', badge: 'Anime'),
  ContentItem(key: 'd', title: 'Delta', badge: 'Manga'),
  ContentItem(key: 'e', title: 'Epsilon', badge: 'Roman'),
  ContentItem(key: 'f', title: 'Zeta', badge: 'Top'),
];

Widget _host(double width, String componentId, String title) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: const Color(0xFF0B0B0F),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: GalleryComponentRenderer.section(
            GalleryComponentContext(
              componentId: componentId,
              items: _items,
              onOpen: (_) {},
              title: title,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  final descriptors = GalleryComponentCatalog.descriptors;

  test('catalog is not empty', () {
    expect(descriptors, isNotEmpty);
  });

  for (final entry in _breakpoints.entries) {
    testWidgets('every component lays out without overflow on ${entry.key} '
        '(${entry.value.toInt()}px)', (tester) async {
      tester.view.physicalSize = Size(entry.value, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final overflows = <String>[];
      for (final descriptor in descriptors) {
        await tester.pumpWidget(
          _host(entry.value, descriptor.id, descriptor.label),
        );
        await tester.pump(const Duration(milliseconds: 20));
        final exception = tester.takeException();
        if (exception != null) {
          overflows.add('${descriptor.id} :: $exception');
        }
      }

      expect(
        overflows,
        isEmpty,
        reason:
            'Components overflow at ${entry.value.toInt()}px:\n'
            '${overflows.join('\n')}',
      );
    });
  }
}
