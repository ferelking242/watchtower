import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/engine_selector.dart';
import 'package:watchtower/services/download_manager/engines/zeus_runtime.dart';
import 'package:watchtower/services/download_manager/link_download_service.dart';
import 'package:watchtower/services/download_manager/social_media_extractor.dart';
import 'package:watchtower/services/download_manager/social_url_detector.dart';

void main() {
  group('LinkDownloadService.fileNameFor', () {
    test('uses the URL path basename', () {
      expect(
        LinkDownloadService.fileNameFor('https://cdn.example/videos/clip.mp4'),
        'clip.mp4',
      );
    });

    test('sanitises characters the filesystem rejects', () {
      final name =
          LinkDownloadService.fileNameFor('https://cdn.example/a:b*c?.mp4');
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('*')));
      expect(name, isNot(contains('?')));
    });

    test('falls back to a timestamped mp4 when the URL has no name', () {
      final name = LinkDownloadService.fileNameFor('https://cdn.example/');
      expect(name, startsWith('watchtower_'));
      expect(name, endsWith('.mp4'));
    });
  });

  group('EngineSelector', () {
    test('maps every DownloadMode to its engine', () {
      SelectedEngine select(DownloadMode mode) => EngineSelector.select(
            url: 'https://cdn/x.mp4',
            itemType: ItemType.anime,
            mode: mode,
          );
      expect(select(DownloadMode.internalDownloader), SelectedEngine.internal);
      expect(select(DownloadMode.aria2), SelectedEngine.aria2);
      expect(select(DownloadMode.zeus), SelectedEngine.zeus);
      // External hand-off is decided upstream; the selector stays internal.
      expect(select(DownloadMode.external), SelectedEngine.internal);
    });

    test('existing enum indices are preserved and zeus is appended', () {
      // The index is persisted in download_settings.json — reordering breaks
      // every user's saved engine choice.
      expect(DownloadMode.internalDownloader.index, 0);
      expect(DownloadMode.aria2.index, 1);
      expect(DownloadMode.external.index, 2);
      expect(DownloadMode.zeus.index, 3);
    });

    test('badges are stable', () {
      expect(SelectedEngine.internal.badgeLabel, 'HYDRA');
      expect(SelectedEngine.aria2.badgeLabel, 'ARES');
      expect(SelectedEngine.zeus.badgeLabel, 'ZEUS');
      expect(DownloadMode.zeus.badgeLabel, 'ZEUS');
    });
  });

  group('ZeusProtocol.parseLine', () {
    test('parses the four structured prefixes', () {
      expect(ZeusProtocol.parseLine('PROGRESS:42')!.type, ZeusEventType.progress);
      expect(ZeusProtocol.parseLine('PROGRESS:42')!.percent, 42);
      expect(ZeusProtocol.parseLine('STATUS:Downloading…')!.type,
          ZeusEventType.status);
      expect(ZeusProtocol.parseLine('DONE:/tmp/a.mp4')!.payload, '/tmp/a.mp4');
      expect(ZeusProtocol.parseLine('ERROR:boom')!.payload, 'boom');
    });

    test('clamps an out-of-range percentage', () {
      expect(ZeusProtocol.parseLine('PROGRESS:140')!.percent, 100);
      expect(ZeusProtocol.parseLine('PROGRESS:-5')!.percent, 0);
      expect(ZeusProtocol.parseLine('PROGRESS:abc')!.percent, 0);
    });

    test('treats anything else as a log line and skips blanks', () {
      expect(ZeusProtocol.parseLine('just noise')!.type, ZeusEventType.log);
      expect(ZeusProtocol.parseLine('   '), isNull);
      expect(ZeusProtocol.parseLine(''), isNull);
    });

    test('keeps the payload text intact after the prefix', () {
      expect(ZeusProtocol.parseLine('STATUS:3 / 10 segments')!.payload,
          '3 / 10 segments');
    });
  });

  group('ZeusInvocation.buildArguments', () {
    test('always passes the script and the url', () {
      final args = ZeusInvocation.buildArguments(
        scriptPath: '/data/zeusdl/__main__.py',
        params: const ZeusParams(url: 'https://vm.tiktok.com/x'),
      );
      expect(args.first, '/data/zeusdl/__main__.py');
      expect(args, containsAllInOrder(['--url', 'https://vm.tiktok.com/x']));
    });

    test('forwards quality, watermark and audio-only flags', () {
      final args = ZeusInvocation.buildArguments(
        scriptPath: 's.py',
        params: const ZeusParams(
          url: 'u',
          quality: '1080p',
          noWatermark: true,
          audioOnly: true,
        ),
      );
      expect(args, containsAllInOrder(['--quality', '1080p']));
      expect(args, contains('--no_watermark'));
      expect(args, contains('--audio_only'));
    });

    test('omits empty values and the watermark flag when disabled', () {
      final args = ZeusInvocation.buildArguments(
        scriptPath: 's.py',
        params: const ZeusParams(
          url: 'u',
          quality: '',
          noWatermark: false,
          extra: {'empty': '', 'cookie': 'abc'},
        ),
      );
      expect(args, isNot(contains('--quality')));
      expect(args, isNot(contains('--no_watermark')));
      expect(args, isNot(contains('--empty')));
      expect(args, containsAllInOrder(['--cookie', 'abc']));
    });
  });

  group('ZeusInvocation.buildEnvironment', () {
    test('injects the documented WT_ variables', () {
      final env = ZeusInvocation.buildEnvironment(
        pluginId: 'en.tiktok-downloader',
        downloadDir: '/dl',
        cacheDir: '/dl/.zeus_cache',
        action: 'download',
        extra: {'WT_OUTPUT_PATH': '/dl/a.mp4'},
      );
      expect(env['WT_PLUGIN_ID'], 'en.tiktok-downloader');
      expect(env['WT_DOWNLOAD_DIR'], '/dl');
      expect(env['WT_ZEUS_CACHE'], '/dl/.zeus_cache');
      expect(env['WT_ACTION'], 'download');
      expect(env['WT_OUTPUT_PATH'], '/dl/a.mp4');
    });
  });

  group('SocialUrlDetector', () {
    test('detects the supported platforms and their sub-domains', () {
      expect(SocialUrlDetector.detect('https://www.tiktok.com/@x/video/1'),
          SocialPlatform.tiktok);
      expect(SocialUrlDetector.detect('https://vm.tiktok.com/abc/'),
          SocialPlatform.tiktok);
      expect(SocialUrlDetector.detect('https://web.facebook.com/watch?v=1'),
          SocialPlatform.facebook);
      expect(SocialUrlDetector.detect('https://fb.watch/xyz/'),
          SocialPlatform.facebook);
      expect(SocialUrlDetector.detect('https://youtu.be/abc'),
          SocialPlatform.youtube);
    });

    test('accepts a scheme-less link', () {
      expect(SocialUrlDetector.detect('vm.tiktok.com/abc'),
          SocialPlatform.tiktok);
    });

    test('returns null for direct files, HLS and unknown hosts', () {
      expect(SocialUrlDetector.detect('https://cdn.example/x.mp4'), isNull);
      expect(SocialUrlDetector.detect('https://cdn.example/x.m3u8'), isNull);
      expect(SocialUrlDetector.detect('not a url'), isNull);
      expect(SocialUrlDetector.detect(''), isNull);
    });

    test('only TikTok is treated as watermarked', () {
      expect(SocialPlatform.tiktok.hasWatermark, isTrue);
      expect(SocialPlatform.facebook.hasWatermark, isFalse);
    });
  });

  group('SocialMediaExtractor.extractMediaUrl', () {
    test('reads og:video:secure_url in either attribute order', () {
      expect(
        SocialMediaExtractor.extractMediaUrl(
          '<meta property="og:video:secure_url" content="https://cdn/a.mp4">',
        ),
        'https://cdn/a.mp4',
      );
      expect(
        SocialMediaExtractor.extractMediaUrl(
          '<meta content="https://cdn/b.mp4" property="og:video:secure_url">',
        ),
        'https://cdn/b.mp4',
      );
    });

    test('falls back to the embedded playAddr JSON and decodes escapes', () {
      final html =
          '{"item":{"video":{"playAddr":"https:\\u002F\\u002Fv16.tiktokcdn.com\\u002Fx.mp4"}}}';
      expect(
        SocialMediaExtractor.extractMediaUrl(html),
        'https://v16.tiktokcdn.com/x.mp4',
      );
    });

    test('reads Facebook playable_url_quality_hd', () {
      final html = '{"playable_url_quality_hd":"https:\\/\\/video.fbcdn.net\\/v.mp4"}';
      expect(
        SocialMediaExtractor.extractMediaUrl(html),
        'https://video.fbcdn.net/v.mp4',
      );
    });

    test('returns null when nothing matches', () {
      expect(SocialMediaExtractor.extractMediaUrl('<html>no media</html>'),
          isNull);
      expect(SocialMediaExtractor.extractMediaUrl(''), isNull);
    });
  });
}
