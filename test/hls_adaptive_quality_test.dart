import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/hls_adaptive_quality.dart';
import 'package:watchtower/services/hls_variant_resolver.dart';

/// The real xnxx master (video-198uzta3). Renditions peak at
/// 0.156 / 0.424 / 0.764 / 1.327 / 2.761 Mbps.
const _master = '''
#EXTM3U
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=763904,RESOLUTION=854x480,NAME="480p"
hls-480p-b22c2.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1327104,RESOLUTION=1280x720,NAME="720p"
hls-720p-fc0ef.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2760704,RESOLUTION=1920x1080,NAME="1080p"
hls-1080p-4a4e2.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=423936,RESOLUTION=640x360,NAME="360p"
hls-360p-3e86c.m3u8
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=155648,RESOLUTION=444x250,NAME="250p"
hls-250p-9b84f.m3u8
''';

void main() {
  final variants = HlsVariantResolver.parseMaster(
    _master,
    masterUrl: Uri.parse('https://cdn.example/x/master.m3u8'),
  );

  AdaptiveQualityPlan at(double mbps) => AdaptiveQualityController.plan(
        variants: variants,
        throughputBitsPerSecond: (mbps * 1000000).round(),
      );

  group('AdaptiveQualityController.plan', () {
    test('picks the heaviest rendition that fits the measured budget', () {
      expect(at(10).variant?.label, '1080p');
      expect(at(10).bitrate, 2760704);
      expect(at(2).variant?.label, '720p');
      expect(at(1.2).variant?.label, '480p');
      expect(at(0.8).variant?.label, '360p');
      expect(at(0.25).variant?.label, '250p');
    });

    test('never exceeds the safety margin', () {
      // 2.761 Mbps is the 1080p peak; at 3 Mbps the budget (2.25) still
      // excludes it, which is what keeps a peaky stream from stalling.
      expect(at(3).variant?.label, '720p');
    });

    test('forces the lightest rendition when nothing fits', () {
      final plan = at(0.1);
      expect(plan.variant?.label, '250p');
      expect(plan.bitrate, 155648);
    });

    test('leaves mpv alone when the connection is unknown', () {
      final plan = AdaptiveQualityController.plan(
        variants: variants,
        throughputBitsPerSecond: null,
      );
      expect(plan.bitrate, isNull);
      expect(plan.variant, isNull);
    });

    test('leaves mpv alone on a non-positive measurement', () {
      expect(
        AdaptiveQualityController.plan(
          variants: variants,
          throughputBitsPerSecond: 0,
        ).bitrate,
        isNull,
      );
    });

    test('ignores variants with no usable bandwidth metadata', () {
      final noBandwidth = HlsVariantResolver.parseMaster(
        '#EXTM3U\n#EXT-X-STREAM-INF:RESOLUTION=1280x720\nv.m3u8\n',
        masterUrl: Uri.parse('https://cdn.example/m.m3u8'),
      );
      expect(
        AdaptiveQualityController.plan(
          variants: noBandwidth,
          throughputBitsPerSecond: 10000000,
        ).bitrate,
        isNull,
      );
    });

    test('ignores implausibly low bandwidth values', () {
      final tiny = HlsVariantResolver.parseMaster(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=320x240\nv.m3u8\n',
        masterUrl: Uri.parse('https://cdn.example/m.m3u8'),
      );
      expect(
        AdaptiveQualityController.plan(
          variants: tiny,
          throughputBitsPerSecond: 10000000,
        ).bitrate,
        isNull,
      );
    });
  });

  group('measureThroughput', () {
    test('returns a positive rate for a real transfer', () async {
      final rate = await measureThroughput(
        'https://cdn.example/seg.ts',
        fetchRange: (url, maxBytes, headers) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const HttpRangeResponse(bytes: 256 * 1024);
        },
      );
      expect(rate, isNotNull);
      expect(rate!, greaterThan(1000000));
    });

    test('returns null when the transfer fails', () async {
      expect(
        await measureThroughput(
          'https://cdn.example/seg.ts',
          fetchRange: (url, maxBytes, headers) async => null,
        ),
        isNull,
      );
    });

    test('returns null when no byte arrived', () async {
      expect(
        await measureThroughput(
          'https://cdn.example/seg.ts',
          fetchRange: (url, maxBytes, headers) async =>
              const HttpRangeResponse(bytes: 0),
        ),
        isNull,
      );
    });

    test('rejects an instantaneous read instead of reporting a huge rate', () async {
      expect(
        await measureThroughput(
          'https://cdn.example/seg.ts',
          fetchRange: (url, maxBytes, headers) async =>
              const HttpRangeResponse(bytes: 256 * 1024),
        ),
        isNull,
      );
    });
  });
}
