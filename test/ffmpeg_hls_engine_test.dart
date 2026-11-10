import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/engines/ffmpeg_hls_engine.dart';

/// FFmpeg is the transport that already plays Surrit/MissAV streams, so the
/// download fallback must hand it exactly the headers the extension attached —
/// minus the ones FFmpeg's HTTP layer owns — and keep targeting a `.part` file
/// so a crash never leaves a truncated video in place of the download.
void main() {
  group('FfmpegHlsEngine.buildArguments', () {
    test('forwards the referer, user agent and remaining headers', () {
      final args = FfmpegHlsEngine.buildArguments(
        url: 'https://surrit.com/abc/playlist.m3u8',
        outputPath: '/dl/chapter.mp4',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Chrome)',
          'Referer': 'https://missav.ws/en/dldss-570',
          'Origin': 'https://missav.ws',
          'Cookie': 'cf_clearance=xyz',
          'Accept': '*/*',
          'Host': 'surrit.com',
          'Content-Length': '0',
        },
      );

      expect(_pair(args, '-user_agent'), 'Mozilla/5.0 (Chrome)');
      expect(_pair(args, '-referer'), 'https://missav.ws/en/dldss-570');
      expect(_pair(args, '-i'), 'https://surrit.com/abc/playlist.m3u8');
      expect(args, containsAllInOrder(['-c', 'copy']));
      expect(args, containsAllInOrder(['-f', 'mp4']));

      final headerBlock = _pair(args, '-headers');
      expect(headerBlock, contains('Origin: https://missav.ws'));
      expect(headerBlock, contains('Cookie: cf_clearance=xyz'));
      expect(headerBlock, contains('Accept: */*'));
      // FFmpeg owns these; a duplicate value could break the request.
      expect(headerBlock, isNot(contains('Host:')));
      expect(headerBlock, isNot(contains('Content-Length:')));
      expect(headerBlock, isNot(contains('User-Agent:')));
      expect(headerBlock, isNot(contains('Referer:')));

      // The output is written to `.part`; the caller promotes it on success.
      expect(args.last, '/dl/chapter.mp4.part');
    });

    test('omits options that have no value', () {
      final args = FfmpegHlsEngine.buildArguments(
        url: 'https://cdn.example/stream.m3u8',
        outputPath: '/dl/x.mp4',
        headers: {'Accept': '*/*'},
      );

      expect(args, isNot(contains('-user_agent')));
      expect(args, isNot(contains('-referer')));
      expect(_pair(args, '-headers'), 'Accept: */*');
    });
  });
}

String? _pair(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}
