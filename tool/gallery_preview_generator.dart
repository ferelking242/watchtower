// Generates one PNG preview per gallery component.
//
// Run with:
//   flutter test tool/gallery_preview_generator.dart
//
// The images are written under `build/gallery_previews/<id>.png` and are
// consumed by the documentation website (`watchtower-website`), which ships
// them as static assets so every component can show a real preview.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

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

void main() {
  final outDir = Directory('build/gallery_previews');

  testWidgets('render every gallery component preview', (tester) async {
    tester.view.physicalSize = const Size(520, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      outDir.createSync(recursive: true);
    });

    for (final descriptor in GalleryComponentCatalog.descriptors) {
      final key = ValueKey('preview-${descriptor.id}');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: const Color(0xFF0B0B0F),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 460,
                  child: RepaintBoundary(
                    key: key,
                    child: GalleryComponentRenderer.section(
                      GalleryComponentContext(
                        componentId: descriptor.id,
                        items: _items,
                        onOpen: (_) {},
                        title: descriptor.label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final overflow = tester.takeException();
      if (overflow != null) {
        // ignore: avoid_print
        print('OVERFLOW_ID ${descriptor.id} :: $overflow');
      }

      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final ByteData? cropped = await _cropToContent(image);
        image.dispose();
        if (cropped == null) return;
        File('${outDir.path}/${descriptor.id}.png')
            .writeAsBytesSync(cropped.buffer.asUint8List());
      });
    }
    expect(outDir.listSync().length, greaterThan(0));
  });
}

/// Trims the empty (transparent/black) margins around the rendered section so
/// the PNG only contains the component itself.
Future<ByteData?> _cropToContent(ui.Image image) async {
  final ByteData? raw = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (raw == null) return null;
  final int width = image.width;
  final int height = image.height;
  final Uint8List bytes = raw.buffer.asUint8List();
  bool visible(int x, int y) {
    final int i = (y * width + x) * 4;
    return bytes[i] > 26 || bytes[i + 1] > 26 || bytes[i + 2] > 26;
  }

  int minX = width, minY = height, maxX = -1, maxY = -1;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (!visible(x, y)) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < minX || maxY < minY) return null;

  const int pad = 8;
  minX = (minX - pad).clamp(0, width - 1);
  minY = (minY - pad).clamp(0, height - 1);
  maxX = (maxX + pad).clamp(0, width - 1);
  maxY = (maxY + pad).clamp(0, height - 1);
  final int cropW = maxX - minX + 1;
  final int cropH = maxY - minY + 1;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFF0B0B0F), BlendMode.src);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(
      minX.toDouble(),
      minY.toDouble(),
      cropW.toDouble(),
      cropH.toDouble(),
    ),
    Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
    Paint(),
  );
  final ui.Image out = await recorder.endRecording().toImage(cropW, cropH);
  final ByteData? png = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  return png;
}
