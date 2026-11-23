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
  _separateAudioTests();

  // The playlist cache is process-wide and keyed by URL; these tests reuse a
  // few URLs on purpose, so each one must start from a cold cache.
  setUp(HlsPlaylistCache.clear);

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

  group('HlsPlaylistCache', () {
    test('a second expansion of the same master does not refetch it', () async {
      final adaptive = Video(
        'https://cdn.example/x/master.m3u8',
        'Auto',
        'https://cdn.example/x/master.m3u8',
      );
      var fetches = 0;
      Future<String?> fetch(String _) async {
        fetches++;
        return _xnxxMaster;
      }

      await expandHlsVariants([adaptive], fetchPlaylist: fetch);
      await expandHlsVariants([adaptive], fetchPlaylist: fetch);

      expect(fetches, 1);
    });

    test('a failed fetch is not cached', () async {
      final videos = [
        Video('https://cdn.example/y/master.m3u8', 'Auto', 'https://cdn.example/y/master.m3u8'),
      ];

      await expandHlsVariants(
        videos,
        fetchPlaylist: (_) async => throw Exception('offline'),
      );

      expect(HlsPlaylistCache.get(videos.first.url), isNull);
    });

    test('an expired entry is not served', () async {
      HlsPlaylistCache.put('https://cdn.example/z/master.m3u8', _xnxxMaster);
      HlsPlaylistCache.ttl = Duration.zero;
      addTearDown(() => HlsPlaylistCache.ttl = const Duration(seconds: 30));

      expect(HlsPlaylistCache.get('https://cdn.example/z/master.m3u8'), isNull);
    });

    test('stays bounded under many distinct URLs', () {
      for (var i = 0; i < HlsPlaylistCache.maxEntries * 3; i++) {
        HlsPlaylistCache.put('https://cdn.example/$i/master.m3u8', _xnxxMaster);
      }
      expect(
        HlsPlaylistCache.get('https://cdn.example/${HlsPlaylistCache.maxEntries * 3 - 1}/master.m3u8'),
        isNotNull,
      );
    });
  });
}

/// Real miraculous.now master: the single 1080p variant carries no audio of
/// its own — every language is a separate `#EXT-X-MEDIA` rendition.
const _miraculousMaster = '''
#EXTM3U

#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-1",NAME="English",LANGUAGE="en",AUTOSELECT=YES,DEFAULT=NO,URI="https://internal.example/m3u8.m3u8?action=rewrite&file=ZW4&v=1"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-1",NAME="Français",LANGUAGE="fr",AUTOSELECT=YES,DEFAULT=YES,URI="https://internal.example/m3u8.m3u8?action=rewrite&file=ZnI&v=1"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Français",LANGUAGE="fr",URI="subs/fr.vtt"

#EXT-X-STREAM-INF:BANDWIDTH=4500000,RESOLUTION=1920x1080,AUDIO="audio-1"
https://internal.example/m3u8.m3u8?action=rewrite&file=dmlkZW8&v=1
''';

void _separateAudioTests() {
  group('HlsVariantResolver separate audio renditions', () {
    final masterUrl = Uri.parse(
      'https://internal.example/m3u8.m3u8?lang=fr&s=7&e=701&token=abc',
    );

    test('detects the audio group referenced by a variant', () {
      expect(HlsVariantResolver.hasSeparateAudio(_miraculousMaster), isTrue);
      expect(HlsVariantResolver.hasSeparateAudio(_xnxxMaster), isFalse);
      expect(HlsVariantResolver.hasSeparateAudio(_mediaPlaylist), isFalse);
    });

    test('an unreferenced audio group is not "separate audio"', () {
      final orphan = _miraculousMaster.replaceAll('AUDIO="audio-1"', '');
      expect(HlsVariantResolver.hasSeparateAudio(orphan), isFalse);
    });

    test('lists every audio language with its playlist URL', () {
      final audios = HlsVariantResolver.parseAudioRenditions(
        _miraculousMaster,
        masterUrl: masterUrl,
      );

      expect(audios.map((a) => a.label).toList(), ['English', 'Français']);
      expect(audios[1].file, contains('file=ZnI'));
    });

    test('lists subtitle renditions separately', () {
      final subs = HlsVariantResolver.parseSubtitleRenditions(
        _miraculousMaster,
        masterUrl: masterUrl,
      );

      expect(subs, hasLength(1));
      expect(subs.single.label, 'Français');
      expect(
        subs.single.file,
        'https://internal.example/subs/fr.vtt',
      );
    });

    test('expansion keeps the master entries and attaches the audio', () async {
      final videos = await expandHlsVariants(
        [Video('https://internal.example/m3u8.m3u8?lang=fr&t=1', 'Auto', 'https://internal.example/m3u8.m3u8?lang=fr&t=1')],
        fetchPlaylist: (_) async => _miraculousMaster,
      );

      expect(videos, hasLength(1));
      // The URL must stay the master: only it names the audio rendition.
      expect(videos.single.url, contains('m3u8.m3u8'));
      expect(videos.single.quality, '1080p');
      expect(videos.single.audios, hasLength(2));
      expect(videos.single.subtitles, hasLength(1));
    });

    test('a per-language entry keeps its label and gains the audio list', () async {
      const langUrl = 'https://internal.example/m3u8.m3u8?lang=fr&t=1';
      final videos = await expandHlsVariants(
        [
          Video(langUrl, '1080p · Français', langUrl),
          Video('https://internal.example/m3u8.m3u8?lang=en&t=1', '1080p · English',
              'https://internal.example/m3u8.m3u8?lang=en&t=1'),
        ],
        fetchPlaylist: (_) async => _miraculousMaster,
      );

      expect(videos.map((v) => v.quality).toList(),
          ['1080p · Français', '1080p · English']);
      expect(videos.every((v) => (v.audios ?? []).length == 2), isTrue);
    });

    test('a muxed master still expands into variants', () async {
      final videos = await expandHlsVariants(
        [Video('https://cdn.example/x/y/master.m3u8', 'Auto', 'https://cdn.example/x/y/master.m3u8')],
        fetchPlaylist: (_) async => _xnxxMaster,
      );

      expect(videos.length, 6);
      expect(videos[1].quality, '250p');
    });
  });
}
