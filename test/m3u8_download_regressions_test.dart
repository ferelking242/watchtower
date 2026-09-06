import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';

void main() {
  group('HLS playlist resolution', () {
    test('resolves nested variant, key, and segment URLs', () {
      const masterUrl = 'https://cdn.example.test/hls/master/index.m3u8';
      const masterPlaylist = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=100000
../video/low/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=200000
../video/high/playlist.m3u8
''';

      expect(
        M3u8Downloader.pickBestVariantForTesting(masterUrl, masterPlaylist),
        'https://cdn.example.test/hls/video/high/playlist.m3u8',
      );

      const variantUrl =
          'https://cdn.example.test/hls/video/high/playlist.m3u8';
      const variantPlaylist = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="../keys/segment.key",IV=0x00000000000000000000000000000001
#EXTINF:4,
../segments/0001.m4s
''';

      final segments = M3u8Downloader.parseTsListForTesting(
        variantUrl,
        variantPlaylist,
      );
      final (keyUrl, iv) = M3u8Downloader.extractKeyAttributesForTesting(
        variantPlaylist,
        variantUrl,
      );

      expect(
        segments.single.url,
        'https://cdn.example.test/hls/video/segments/0001.m4s',
      );
      expect(keyUrl, 'https://cdn.example.test/hls/video/keys/segment.key');
      expect(iv, isNotNull);
      expect(iv!.toList(), [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
      ]);
    });

    test('puts EXT-X-MAP before every media fragment', () {
      const playlistUrl =
          'https://cdn.example.test/hls/video/high/playlist.m3u8';
      const playlist = '''
#EXTM3U
#EXT-X-MAP:URI="../init/init.mp4"
#EXTINF:4,
segments/0001.m4s
#EXTINF:4,
segments/0002.m4s
''';

      final segments = M3u8Downloader.parseTsListForTesting(
        playlistUrl,
        playlist,
      );

      expect(segments.map((segment) => segment.name), ['TS_0', 'TS_1', 'TS_2']);
      expect(segments.first.isInitialization, isTrue);
      expect(
        segments.first.url,
        'https://cdn.example.test/hls/video/init/init.mp4',
      );
      expect(
        segments.skip(1).every((segment) => !segment.isInitialization),
        isTrue,
      );
    });
  });

  test('HLS progress keeps the byte denominator unknown until merge', () {
    final progress = m3u8ProgressForTesting(
      segment: null,
      completed: 1,
      total: 3,
      itemType: ItemType.anime,
      downloadedBytes: 4096,
    );

    expect(progress.downloadedBytes, 4096);
    expect(progress.total, 3);
    expect(progress.totalBytes, isNull);
  });

  group('HLS merge cleanup', () {
    late Directory sandbox;
    late M3u8Downloader downloader;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('watchtower-hls-test-');
      final chapter = Chapter(id: 1, mangaId: 1, name: 'Test chapter');
      chapter.manga.value = Manga(
        source: 'test',
        author: '',
        artist: '',
        genre: const [],
        imageUrl: '',
        lang: 'en',
        link: '',
        name: 'Test manga',
        status: Status.ongoing,
        sourceId: 1,
        itemType: ItemType.anime,
      );
      downloader = M3u8Downloader(
        m3u8Url: 'https://cdn.example.test/video.m3u8',
        downloadDir: sandbox.path,
        fileName: '${sandbox.path}/video.mp4',
        chapter: chapter,
        subtitles: null,
        refererUrl: null,
      );
    });

    tearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    test('removes temporary fragments after a successful merge', () async {
      final tempDir = Directory('${sandbox.path}/temp')..createSync();
      await File('${tempDir.path}/TS_1.ts').writeAsBytes([3, 4]);
      await File('${tempDir.path}/TS_2.ts').writeAsBytes([5, 6]);
      final progress = <DownloadProgress>[];

      await downloader.mergeSegmentsAndCleanTempForTesting(
        '${sandbox.path}/video.mp4',
        tempDir.path,
        progress.add,
      );

      expect(await File('${sandbox.path}/video.mp4').readAsBytes(), [
        3,
        4,
        5,
        6,
      ]);
      expect(await tempDir.exists(), isFalse);
      expect(progress.single.downloadedBytes, 4);
      expect(progress.single.totalBytes, 4);
    });

    test('keeps fragments after a failed merge so it can be resumed', () async {
      final tempDir = Directory('${sandbox.path}/temp')..createSync();
      final fragment = File('${tempDir.path}/TS_1.ts');
      await fragment.writeAsBytes(const []);
      // A stale output must not make a failed merge look successful.
      await File('${sandbox.path}/video.mp4').writeAsBytes([99]);

      await expectLater(
        downloader.mergeSegmentsAndCleanTempForTesting(
          '${sandbox.path}/video.mp4',
          tempDir.path,
          (_) {},
        ),
        throwsA(isA<M3u8DownloaderException>()),
      );

      expect(await tempDir.exists(), isTrue);
      expect(await fragment.exists(), isTrue);
      expect(await File('${sandbox.path}/video.mp4').readAsBytes(), [99]);
    });
  });
}
