import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/m3u8/ffmpeg_merge_service.dart';

/// Regression: an HLS download of an episode with a very long title used to
/// fail at the merge step with `File name too long` (errno 36), after the whole
/// episode had already been downloaded.
///
/// The assembler wrote its transient joined stream as `<output>.joined`, i.e.
/// it inherited the (already NAME_MAX-bounded) final name and pushed it 7 bytes
/// past the 255-byte limit. The intermediate must not depend on the title.
void main() {
  const longTitle =
      'MIDA-517 A Divine Fingering Technique That Always Makes A Serious '
      'Female Teacher Climax - A Molester Train Who Has Become A Premature '
      'Ejaculator Due To An Abnormal Sexual Desire, And Has Derailed Her '
      'Teaching Profession - Sakura Miura';

  group('merge intermediate path', () {
    test('does not inherit the (long) output name', () {
      final output = '/storage/emulated/0/watchtower/$longTitle [360p].mp4.part';
      final segments = ['/storage/emulated/0/watchtower/temp/TS_0001.ts'];
      final intermediate = FfmpegMergeService.intermediatePathFor(
        output,
        segments,
      );

      final name = intermediate.split('/').last;
      expect(utf8.encode(name).length, lessThan(255));
      expect(name.contains('MIDA-517'), isFalse);
    });

    test('sits in the segments temp directory', () {
      final output = '/data/dl/Episode.mp4.part';
      final segments = [
        '/data/dl/temp/TS_0001.ts',
        '/data/dl/temp/TS_0002.ts',
      ];
      final intermediate = FfmpegMergeService.intermediatePathFor(
        output,
        segments,
      );

      expect(intermediate.startsWith('/data/dl/temp/'), isTrue);
    });

    test('is unique per output and stable for the same output', () {
      final a = FfmpegMergeService.intermediatePathFor('/x/A.mp4.part', const [
        '/x/temp/TS_0001.ts',
      ]);
      final b = FfmpegMergeService.intermediatePathFor('/x/B.mp4.part', const [
        '/x/temp/TS_0001.ts',
      ]);
      final a2 = FfmpegMergeService.intermediatePathFor('/x/A.mp4.part', const [
        '/x/temp/TS_0001.ts',
      ]);

      expect(a, isNot(b));
      expect(a, a2);
    });

    test('the filesystem accepts the intermediate name', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'watchtower-merge-path-test-',
      );
      addTearDown(() => sandbox.delete(recursive: true));

      final output = '${sandbox.path}/$longTitle [360p].mp4.part';
      final intermediate = FfmpegMergeService.intermediatePathFor(output, [
        '${sandbox.path}/TS_0001.ts',
      ]);
      await File(intermediate).writeAsString('x'); // errno 36 if too long
      expect(await File(intermediate).exists(), isTrue);
    });
  });
}
