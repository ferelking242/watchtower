import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/image_view_vertical.dart';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// A page narrower than the viewport keeps its intrinsic width unless the
/// widget forces the available width: `BoxFit.fitWidth` only picks how the
/// image is painted inside a box whose size the render object derives from the
/// image's own aspect ratio. These tests render the real [ImageViewVertical]
/// and measure the laid-out image box.
Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIsar isar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isar = MockIsar();
    app.isar = isar;
    isar.seed<Settings>(kSettingsId, Settings());
  });

  UChapDataPreload page(Uint8List bytes) =>
      UChapDataPreload(null, null, null, true, bytes, 0, null, 0);

  /// Mirrors the reader: the page sits in a vertically scrollable list, so the
  /// width is tight to the viewport while the height is unbounded.
  Widget host(Widget child, double viewportWidth) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: viewportWidth,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  Future<Size> render(
    WidgetTester tester, {
    required Uint8List bytes,
    required double viewportWidth,
    required bool fitWidth,
  }) async {
    final data = page(bytes);
    await tester.pumpWidget(
      host(
        ImageViewVertical(
          data: data,
          onLongPressData: (_) {},
          failedToLoadImage: (_) {},
          isHorizontal: false,
          fitWidth: fitWidth,
        ),
        viewportWidth,
      ),
    );
    // Decode the memory image outside the fake-async zone, then pump a few
    // frames. `pumpAndSettle` cannot be used: the load-state placeholder runs
    // an endless rotation animation.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MaterialApp));
      await precacheImage(ExtendedMemoryImageProvider(bytes), ctx);
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return tester.getSize(find.byType(ExtendedImage));
  }

  testWidgets('webtoon forces a narrow page to the viewport width', (
    tester,
  ) async {
    // 1:4 aspect ratio, much narrower than the 400px viewport.
    final size = await render(
      tester,
      bytes: _png(50, 200),
      viewportWidth: 400,
      fitWidth: true,
    );

    expect(size.width, 400, reason: 'webtoon pages must fill the width');
    expect(
      size.height,
      1600,
      reason: 'height must follow the source aspect ratio (4x the width)',
    );
  });

  testWidgets('paged mode keeps the natural width', (tester) async {
    final size = await render(
      tester,
      bytes: _png(50, 200),
      viewportWidth: 400,
      fitWidth: false,
    );

    expect(
      size.width,
      50,
      reason: 'the width fix is scoped to webtoon pages',
    );
  });
}
