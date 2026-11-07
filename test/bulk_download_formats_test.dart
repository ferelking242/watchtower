import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/media/widgets/bulk_download_formats.dart';

void main() {
  group('resolutionKey', () {
    test('keeps only the resolution digits', () {
      expect(resolutionKey('1080p'), '1080');
      expect(resolutionKey('1080P60'), '1080');
      expect(resolutionKey('FHD 1080p60'), '1080');
      expect(resolutionKey('2160p (4K)'), '2160');
      expect(resolutionKey('360'), '360');
    });

    test('normalises labels without a resolution', () {
      expect(resolutionKey('Auto'), 'auto');
      expect(resolutionKey('  Haute Qualité  '), 'haute qualité');
    });

    test('matches the same resolution across label formats', () {
      // The point of the key: a quality picked in one surface must compare
      // equal to the same resolution named differently elsewhere.
      expect(resolutionKey('720p'), resolutionKey('720 P'));
      expect(resolutionKey('1080p VOSTFR'), resolutionKey('1080p'));
    });
  });

  group('formatVideoBytes', () {
    test('formats byte counts with a unit', () {
      expect(formatVideoBytes(300 * 1024 * 1024), contains('MB'));
      expect(formatVideoBytes(4 * 1024 * 1024 * 1024), contains('GB'));
    });

    test('returns null for missing or empty values', () {
      expect(formatVideoBytes(null), isNull);
      expect(formatVideoBytes(0), isNull);
      expect(formatVideoBytes(-1), isNull);
    });
  });
}
