import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/image_view_webtoon.dart';

void main() {
  group('readerPageGapExtent', () {
    test('uses the configured gap in continuous readers', () {
      expect(readerPageGapExtent(showPageGaps: true), 6);
      expect(readerPageGapExtent(showPageGaps: false), 0);
    });
  });

  group('shouldUseDoublePageLayout', () {
    test('does not pair pages in webtoon mode', () {
      expect(
        shouldUseDoublePageLayout(
          isDoublePageMode: true,
          readerMode: ReaderMode.webtoon,
          isHorizontalContinuous: false,
        ),
        isFalse,
      );
    });

    test('keeps double pages in vertical continuous mode', () {
      expect(
        shouldUseDoublePageLayout(
          isDoublePageMode: true,
          readerMode: ReaderMode.verticalContinuous,
          isHorizontalContinuous: false,
        ),
        isTrue,
      );
    });

    test('does not pair pages in horizontal continuous mode', () {
      expect(
        shouldUseDoublePageLayout(
          isDoublePageMode: true,
          readerMode: ReaderMode.horizontalContinuous,
          isHorizontalContinuous: true,
        ),
        isFalse,
      );
    });
  });
}
