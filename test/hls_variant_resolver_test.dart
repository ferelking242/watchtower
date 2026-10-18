import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/hls_variant_resolver.dart';

/// Real xnxx master playlist (video-198uzta3), fetched from the CDN. The
/// extension labels the adaptive entry "Auto" while `mp4_high` actually
/// serves 360p, so the variant list is the only place the real 1080p shows up.
const _xnxxMaster = '''
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

/// A media playlist lists segments and must never be expanded.
const _mediaPlaylist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
seg-1.ts
#EXTINF:10.0,
seg-2.ts
#EXT-X-ENDLIST
''';

void main() {
  group('HlsVariantResolver.parseMaster', () {
    test('detects a master playlist but not a media playlist', () {
      expect(HlsVariantResolver.isMasterPlaylist(_xnxxMaster), isTrue);
      expect(HlsVariantResolver.isMasterPlaylist(_mediaPlaylist), isFalse);
    });

    test('extracts every xnxx rendition, best bitrate first', () {
      final variants = HlsVariantResolver.parseMaster(
        _xnxxMaster,
        masterUrl: Uri.parse('https://cdn.example/x/y/master.m3u8'),
      );

      expect(variants.map((v) => v.label).toList(),
          ['1080p', '720p', '480p', '360p', '250p']);
      expect(variants.first.height, 1080);
      expect(variants.first.bandwidth, 2760704);
    });

    test('resolves relative variant URIs against the master URL', () {
      final variants = HlsVariantResolver.parseMaster(
        _xnxxMaster,
        masterUrl: Uri.parse('https://cdn.example/x/y/master.m3u8'),
      );
      expect(variants.first.url, 'https://cdn.example/x/y/hls-1080p-4a4e2.m3u8');
    });

    test('keeps absolute variant URIs untouched', () {
      const master = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=1280x720\n'
          'https://other.cdn/v/720.m3u8\n';
      final variants = HlsVariantResolver.parseMaster(
        master,
        masterUrl: Uri.parse('https://cdn.example/master.m3u8'),
      );
      expect(variants.single.url, 'https://other.cdn/v/720.m3u8');
    });

    test('falls back to the bitrate when no NAME or RESOLUTION is given', () {
      const master = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1500000\n'
          'v.m3u8\n';
      final variants = HlsVariantResolver.parseMaster(
        master,
        masterUrl: Uri.parse('https://cdn.example/master.m3u8'),
      );
      expect(variants.single.label, '1500 kbps');
      expect(variants.single.height, isNull);
    });

    test('returns nothing for a playlist with no variants', () {
      expect(
        HlsVariantResolver.parseMaster(
          _mediaPlaylist,
          masterUrl: Uri.parse('https://cdn.example/m.m3u8'),
        ),
        isEmpty,
      );
    });
  });

  group('expandHlsVariants', () {
    test('keeps the adaptive entry first and appends every rendition', () async {
      final adaptive = Video(
        'https://cdn.example/x/master.m3u8',
        'Auto',
        'https://cdn.example/x/master.m3u8',
      );

      final expanded = await expandHlsVariants(
        [adaptive],
        fetchPlaylist: (_) async => _xnxxMaster,
      );

      expect(expanded.length, 6); // adaptive + 5 renditions
      expect(expanded.first.quality, 'Auto');
      expect(expanded.first.url, adaptive.url);
      // Ascending bitrate: these entries double as fallbacks for the adaptive
      // master, so a failure steps down instead of retrying something as
      // heavy as what just failed.
      expect(
        expanded.skip(1).map((v) => v.quality).toList(),
        ['250p', '360p', '480p', '720p', '1080p'],
      );
    });

    test('keeps renditions that carry no BANDWIDTH', () async {
      const mixed = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1327104,RESOLUTION=1280x720,NAME="720p"
v-720.m3u8
#EXT-X-STREAM-INF:RESOLUTION=640x360,NAME="360p"
v-360.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=423936,RESOLUTION=640x360,NAME="360p-bw"
v-360bw.m3u8
''';
      final adaptive = Video(
        'https://cdn.example/x/master.m3u8',
        'Auto',
        'https://cdn.example/x/master.m3u8',
      );

      final expanded = await expandHlsVariants(
        [adaptive],
        fetchPlaylist: (_) async => mixed,
      );

      // Bandwidth-known renditions first (ascending), then the unlabelled one.
      expect(
        expanded.skip(1).map((v) => v.url).toList(),
        [
          'https://cdn.example/x/v-360bw.m3u8',
          'https://cdn.example/x/v-720.m3u8',
          'https://cdn.example/x/v-360.m3u8',
        ],
      );
    });

    test('leaves non-HLS sources untouched', () async {
      final videos = [Video('https://cdn.example/v.mp4', '720p', 'https://cdn.example/v.mp4')];
      var fetched = false;

      final expanded = await expandHlsVariants(
        videos,
        fetchPlaylist: (_) async {
          fetched = true;
          return _xnxxMaster;
        },
      );

      expect(expanded, videos);
      expect(fetched, isFalse);
    });

    test('returns the original list when the fetch fails', () async {
      final videos = [Video('https://cdn.example/m.m3u8', 'Auto', 'https://cdn.example/m.m3u8')];

      final expanded = await expandHlsVariants(
        videos,
        fetchPlaylist: (_) async => throw Exception('offline'),
      );

      expect(expanded, videos);
    });

    test('returns the original list when the URL is a media playlist', () async {
      final videos = [Video('https://cdn.example/m.m3u8', 'Auto', 'https://cdn.example/m.m3u8')];

      final expanded = await expandHlsVariants(
        videos,
        fetchPlaylist: (_) async => _mediaPlaylist,
      );

      expect(expanded, videos);
    });

    test('preserves the headers so the CDN still accepts the variants', () async {
      final adaptive = Video(
        'https://cdn.example/x/master.m3u8',
        'Auto',
        'https://cdn.example/x/master.m3u8',
        headers: {'Referer': 'https://www.xnxx.com/video-198uzta3/'},
      );

      final expanded = await expandHlsVariants(
        [adaptive],
        fetchPlaylist: (_) async => _xnxxMaster,
      );

      expect(expanded.every((v) => v.headers?['Referer']?.contains('xnxx') ?? false), isTrue);
    });
  });
}
