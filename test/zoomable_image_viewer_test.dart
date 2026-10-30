import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:watchtower/modules/widgets/zoomable_image_viewer.dart';

/// A 1x1 PNG, so the viewer has a provider that resolves without a network
/// fetch in the widget test.
final _kPixel = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('viewer shows the title and a close control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZoomableImageViewer(
          imageProvider: MemoryImage(_kPixel),
          title: 'Une scène',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Une scène'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
    // The reset control only appears once the user has zoomed in.
    expect(find.byTooltip('Taille réelle'), findsNothing);
  });

  testWidgets('double tap cycles to the native 1:1 scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZoomableImageViewer(imageProvider: MemoryImage(_kPixel)),
      ),
    );
    await tester.pump();

    final viewer = tester.widget<PhotoView>(find.byType(PhotoView));
    var state = PhotoViewScaleState.initial;

    // initial → covering → originalSize (1:1) → initial
    state = viewer.scaleStateCycle!(state);
    expect(state, PhotoViewScaleState.covering);

    state = viewer.scaleStateCycle!(state);
    expect(state, PhotoViewScaleState.originalSize);

    state = viewer.scaleStateCycle!(state);
    expect(state, PhotoViewScaleState.initial);
  });

  testWidgets('pinch ceiling is 8x the covered scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZoomableImageViewer(imageProvider: MemoryImage(_kPixel)),
      ),
    );
    await tester.pump();

    final viewer = tester.widget<PhotoView>(find.byType(PhotoView));
    expect(viewer.maxScale, PhotoViewComputedScale.covered * 8);
    expect(viewer.minScale, PhotoViewComputedScale.contained);
  });

  testWidgets('tapping the close control pops the viewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showZoomableImage(
                  context,
                  imageProvider: MemoryImage(_kPixel),
                  title: 'Zoom',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ZoomableImageViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(ZoomableImageViewer), findsNothing);
  });
}
