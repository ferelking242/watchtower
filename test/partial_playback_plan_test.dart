import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/partial/hls_segment_manifest.dart';
import 'package:watchtower/services/download_manager/partial/partial_playback_plan.dart';
import 'package:watchtower/services/download_manager/partial/partial_playback_resolver.dart';

List<HlsSegmentEntry> _segments(int count, {int durationMs = 4000}) => [
  for (var i = 0; i < count; i++)
    HlsSegmentEntry(name: 'TS_${i + 1}', durationMs: durationMs),
];

void main() {
  group('EXTINF parsing', () {
    test('carries each fragment duration onto the next URI', () {
      const playlist = '''
#EXTM3U
#EXTINF:4.000,
segments/0001.m4s
#EXTINF:6.500,
segments/0002.m4s
''';
      final segments = M3u8Downloader.parseTsListForTesting(
        'https://cdn.example.test/hls/playlist.m3u8',
        playlist,
      );

      expect(segments.map((s) => s.name), ['TS_1', 'TS_2']);
      expect(segments.map((s) => s.durationMs), [4000, 6500]);
    });

    test('leaves the duration unknown when EXTINF is missing', () {
      const playlist = '''
#EXTM3U
segments/0001.m4s
''';
      final segments = M3u8Downloader.parseTsListForTesting(
        'https://cdn.example.test/hls/playlist.m3u8',
        playlist,
      );

      expect(segments.single.durationMs, 0);
    });
  });

  group('PartialPlaybackPlan', () {
    test('maps a fully-available episode with no gaps', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(4),
        available: [true, true, true, true],
      );

      expect(plan.isComplete, isTrue);
      expect(plan.totalDurationMs, 16000);
      expect(plan.availableDurationMs, 16000);
      expect(plan.gapRanges, isEmpty);
      expect(plan.playableRanges, [const PlayableRange(0, 16000)]);
    });

    test('records the missing middle as one gap', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, false, false, true, false],
      );

      expect(plan.isComplete, isFalse);
      expect(plan.totalDurationMs, 20000);
      expect(plan.availableDurationMs, 8000);
      expect(plan.playableRanges, [
        const PlayableRange(0, 4000),
        const PlayableRange(12000, 16000),
      ]);
      expect(plan.gapRanges, [
        const PlayableRange(4000, 12000),
        const PlayableRange(16000, 20000),
      ]);
    });

    test('compressed and real timelines map both ways', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, false, false, true, false],
      );

      // Second available fragment starts at compressed 4s but real 12s.
      expect(plan.compressedToRealMs(4000), 12000);
      expect(plan.compressedToRealMs(6000), 14000);
      expect(plan.realToCompressedMs(12000), 4000);
      // A real position inside the gap collapses to the next fragment start.
      expect(plan.realToCompressedMs(8000), 4000);
    });

    test('a seek inside a gap jumps to the next available fragment', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, false, false, true, false],
      );

      final target = plan.resolveSeek(9000);

      expect(target.jumped, isTrue);
      expect(target.realMs, 12000);
      expect(target.compressedMs, 4000);
    });

    test('a seek inside an available fragment does not jump', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, false, false, true, false],
      );

      final target = plan.resolveSeek(13500);

      expect(target.jumped, isFalse);
      expect(target.realMs, 13500);
      expect(target.compressedMs, 5500);
    });

    test('a seek past the end clamps to the last available fragment', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, true, true, true, false],
      );

      final target = plan.resolveSeek(999999);

      expect(target.realMs, 16000);
      expect(target.compressedMs, 16000);
      expect(target.jumped, isTrue);
    });

    test('a seek before the first available fragment lands on it', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(4),
        available: [false, true, true, true],
      );

      final target = plan.resolveSeek(0);

      expect(target.jumped, isTrue);
      expect(target.realMs, 4000);
      expect(target.compressedMs, 0);
    });

    test('gapCrossedBetween reports the span playback skipped over', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(5),
        available: [true, false, false, true, false],
      );

      expect(
        plan.gapCrossedBetween(3000, 13000),
        const PlayableRange(4000, 12000),
      );
      expect(plan.gapCrossedBetween(3000, 3500), isNull);
    });

    test('no playable content when every fragment is missing', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(3),
        available: [false, false, false],
      );

      expect(plan.hasPlayableContent, isFalse);
      expect(plan.playableRanges, isEmpty);
      expect(plan.gapRanges, [const PlayableRange(0, 12000)]);
    });
  });

  group('buildPartialPlaylistText', () {
    test('lists only the available fragments in order', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(4),
        available: [true, false, true, false],
      );

      final text = buildPartialPlaylistText(plan: plan);

      expect(text, contains('#EXTM3U'));
      expect(text, contains('#EXT-X-PLAYLIST-TYPE:VOD'));
      expect(text, contains('TS_1.ts'));
      expect(text, contains('TS_3.ts'));
      expect(text, isNot(contains('TS_2.ts')));
      expect(text, isNot(contains('TS_4.ts')));
      expect(text, contains('#EXT-X-ENDLIST'));
    });

    test('emits EXT-X-MAP for a CMAF initialization fragment', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(2),
        available: [true, true],
      );

      final text = buildPartialPlaylistText(
        plan: plan,
        initSegmentFileName: 'TS_0.ts',
      );

      expect(text, contains('#EXT-X-MAP:URI="TS_0.ts"'));
    });
  });

  group('HlsSegmentManifest', () {
    test('round-trips through JSON', () {
      const manifest = HlsSegmentManifest(
        initSegmentName: 'TS_0.ts',
        segments: [
          HlsSegmentEntry(name: 'TS_1', durationMs: 4000),
          HlsSegmentEntry(name: 'TS_2', durationMs: 6000),
        ],
      );

      final decoded = HlsSegmentManifest.decode(
        jsonEncode(manifest.toJson()),
      );

      expect(decoded, isNotNull);
      expect(decoded!.initSegmentName, 'TS_0.ts');
      expect(decoded.segments.length, 2);
      expect(decoded.segments[1].name, 'TS_2');
      expect(decoded.segments[1].durationMs, 6000);
    });

    test('returns null for malformed input', () {
      expect(HlsSegmentManifest.decode('not json'), isNull);
      expect(HlsSegmentManifest.decode(''), isNull);
      expect(HlsSegmentManifest.decode(null), isNull);
    });
  });

  group('PartialPlaybackResolver.scanAvailability', () {
    test('counts a fragment only when it is non-empty and marked done',
        () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'watchtower-partial-',
      );
      addTearDown(() => sandbox.delete(recursive: true));

      final ready = File('${sandbox.path}/TS_1.ts');
      await ready.writeAsBytes([1, 2, 3, 4]);
      await File('${ready.path}.done').writeAsBytes(const []);

      // Present but half-written: no `.done` marker.
      await File('${sandbox.path}/TS_2.ts').writeAsBytes([1, 2, 3]);

      // Marked done but empty.
      await File('${sandbox.path}/TS_3.ts').writeAsBytes(const []);
      await File('${sandbox.path}/TS_3.ts.done').writeAsBytes(const []);

      final manifest = HlsSegmentManifest(
        segments: const [
          HlsSegmentEntry(name: 'TS_1', durationMs: 4000),
          HlsSegmentEntry(name: 'TS_2', durationMs: 4000),
          HlsSegmentEntry(name: 'TS_3', durationMs: 4000),
          HlsSegmentEntry(name: 'TS_4', durationMs: 4000),
        ],
      );

      final availability = await PartialPlaybackResolver.scanAvailability(
        sandbox.path,
        manifest,
      );

      expect(availability, [true, false, false, false]);

      final plan = buildPartialPlaybackPlan(
        segments: manifest.segments,
        available: availability,
      );
      expect(plan.hasPlayableContent, isTrue);
      expect(plan.isComplete, isFalse);
    });
  });

  group('shouldBuildPartialPlaylist', () {
    test('plays a partially-downloaded episode', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(4),
        available: [true, true, false, false],
      );

      expect(shouldBuildPartialPlaylist(plan), isTrue);
    });

    test('plays when every fragment is on disk but the merge never ran', () {
      // A failed merge after a full download (e.g. the >600 MB "File name too
      // long" case) leaves all fragments present and no merged `.mp4`. The
      // fragments must still be playable instead of falling back to the
      // network, so a complete-looking plan is not a reason to bail out.
      final plan = buildPartialPlaybackPlan(
        segments: _segments(3),
        available: [true, true, true],
      );

      expect(plan.isComplete, isTrue);
      expect(shouldBuildPartialPlaylist(plan), isTrue);
    });

    test('nothing to play when no fragment is on disk', () {
      final plan = buildPartialPlaybackPlan(
        segments: _segments(3),
        available: [false, false, false],
      );

      expect(shouldBuildPartialPlaylist(plan), isFalse);
    });
  });
}
