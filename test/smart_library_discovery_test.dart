import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/engine/watcher/android_media_store.dart';

/// Crée un fichier non vide : `File.create` produit 0 octet, ce qui est
/// rejeté par `minimumFileSize` (1) et ferait échouer la découverte.
Future<void> _writeFile(String path) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsBytes([1, 2, 3, 4]);
}

/// Watch policy with the real 24 MB / 4-minute quality gates relaxed so a
/// handful of byte-sized fixtures can exercise the discovery mechanics.
/// The gates themselves are covered by their own test below.
ScanPolicy _relaxedVideoPolicy() => ScanPolicy.videos(minimumFileSize: 1);

void main() {
  group('Smart Library scan policies', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('watchtower-smart-library-');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('Watch mode discovers videos but never manga or novels', () async {
      await _writeFile('${root.path}/Movies/Film.mp4');
      await _writeFile('${root.path}/Manga/One Piece/Chapter 1.cbz');
      await _writeFile('${root.path}/Books/Novel.epub');

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: _relaxedVideoPolicy(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files.map((file) => file.extension), ['.mp4']);
    });

    test('Watch mode drops files below the size and duration gates', () async {
      await _writeFile('${root.path}/Movies/Tiny.mp4');

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: ScanPolicy.videos(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files, isEmpty);
    });

    test('Watch mode drops extras such as samples and trailers', () async {
      await _writeFile('${root.path}/Movies/Film.sample.mp4');
      await _writeFile('${root.path}/Movies/Film.trailer.mp4');

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: _relaxedVideoPolicy(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files, isEmpty);
    });

    test('Manga mode keeps one page representative per chapter folder', () async {
      await _writeFile('${root.path}/Manga/One Piece/Chapter 12/page-001.jpg');
      await _writeFile('${root.path}/Manga/One Piece/Chapter 12/page-002.jpg');
      await _writeFile('${root.path}/Manga/One Piece/Chapter 13.cbz');
      await _writeFile('${root.path}/Movies/Film.mp4');
      await _writeFile('${root.path}/Books/Novel.epub');

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: const ScanPolicy.manga(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files, hasLength(2));
      expect(files.map((file) => file.extension), contains('.jpg'));
      expect(files.map((file) => file.extension), contains('.cbz'));
      expect(files.singleWhere((file) => file.extension == '.jpg').analysisName,
          'One Piece Chapter 12.cbz');
    });

    test('Music mode discovers audio but never video or manga', () async {
      await _writeFile('${root.path}/Music/Album/Track.mp3');
      await _writeFile('${root.path}/Music/Album/Other.flac');
      await _writeFile('${root.path}/Movies/Film.mp4');
      await _writeFile('${root.path}/Manga/One Piece/Chapter 1.cbz');

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: const ScanPolicy.music(minimumFileSize: 1),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(
        files.map((file) => file.extension).toSet(),
        {'.mp3', '.flac'},
      );
    });

    test('an unreadable subdirectory does not abort the whole walk', () async {
      await _writeFile('${root.path}/Movies/Film.mp4');
      final blocked = Directory('${root.path}/Movies/Private')..createSync();
      await _writeFile('${root.path}/Movies/Private/Hidden.mp4');
      await _writeFile('${root.path}/Shows/Episode.mp4');

      // Simulate the Android "/storage/emulated/0/Android/data" case: the
      // directory exists but its contents cannot be listed.
      await Process.run('chmod', ['000', blocked.path]);

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: _relaxedVideoPolicy(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      await Process.run('chmod', ['755', blocked.path]);

      expect(files.map((file) => file.basename), containsAll(['Film.mp4', 'Episode.mp4']));
    });

    test('content:// MediaStore entries keep a real extension', () async {
      // Android 10+ returns a URI whose last segment is the numeric row id.
      final entry = MediaStoreEntry(
        path: 'content://media/external/video/media/1234',
        size: 42,
        modifiedAt: 0,
        mimeType: 'video/x-matroska',
        displayName: 'Naruto.S01E01.mkv',
      );

      expect(AndroidMediaStore.extensionOf(entry), '.mkv');
      expect(DiscoveryStage.videoExtensions, contains('.mkv'));

      final withoutName = MediaStoreEntry(
        path: 'content://media/external/video/media/99',
        size: 42,
        modifiedAt: 0,
        mimeType: 'video/mp4',
      );
      expect(AndroidMediaStore.extensionOf(withoutName), '.mp4');
    });

    test('MediaStore entries with a resolved extension are discovered', () async {
      // Empty extension = what a raw content:// URI produces; the engine now
      // resolves it from the display name/MIME before discovery.
      final entries = [
        const DiscoveredFile(
          path: 'content://media/external/video/media/1',
          size: 100,
          modifiedAt: 0,
          extension: '',
          analysisName: 'Naruto.S01E01.mkv',
        ),
        const DiscoveredFile(
          path: 'content://media/external/video/media/2',
          size: 100,
          modifiedAt: 0,
          extension: '.mp4',
          analysisName: 'Film.2020.mp4',
        ),
      ];

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: _relaxedVideoPolicy(),
      ).discover([root.path], additionalFiles: entries)) {
        files.addAll(batch);
      }

      expect(files, hasLength(1));
      expect(files.single.extension, '.mp4');
      expect(files.single.analysisName, 'Film.2020.mp4');
    });

    test('MediaStore rows pass the same size, duration and name gates',
        () async {
      // MediaStore returns thumbnails, ringtones and screen recordings too.
      // A 2 MB clip, a 30-second video and a "sample" are not films.
      final entries = [
        MediaStoreEntry(
          path: 'content://media/external/video/media/1',
          size: 2 * 1024 * 1024,
          modifiedAt: 0,
          displayName: 'TinyClip.mp4',
          duration: 90 * 60 * 1000,
        ),
        MediaStoreEntry(
          path: 'content://media/external/video/media/2',
          size: 800 * 1024 * 1024,
          modifiedAt: 0,
          displayName: 'ShortClip.mp4',
          duration: 30 * 1000,
        ),
        MediaStoreEntry(
          path: 'content://media/external/video/media/3',
          size: 800 * 1024 * 1024,
          modifiedAt: 0,
          displayName: 'Film.sample.mkv',
          duration: 90 * 60 * 1000,
        ),
        MediaStoreEntry(
          path: 'content://media/external/video/media/4',
          size: 800 * 1024 * 1024,
          modifiedAt: 0,
          displayName: 'Interstellar.2014.1080p.mkv',
          duration: 169 * 60 * 1000,
        ),
      ];

      final policy = ScanPolicy.videos();
      final kept = entries.where((entry) {
        if (entry.size < policy.minimumFileSize) return false;
        if (policy.minimumDurationMs > 0 &&
            entry.duration != null &&
            entry.duration! < policy.minimumDurationMs) {
          return false;
        }
        return !policy.rejectsName(entry.displayName ?? entry.path);
      }).toList();

      expect(kept, hasLength(1));
      expect(kept.single.displayName, 'Interstellar.2014.1080p.mkv');
    });

    test('the shared gate rejects the same MediaStore rows the walk rejects',
        () async {
      // Guards the refactor: MediaStore rows are handed to DiscoveryStage as
      // additionalFiles, so both sources go through one gate. If the gate ever
      // moves back into the engine these expectations break.
      const thumbnail = DiscoveredFile(
        path: 'content://media/external/video/media/11',
        size: 3 * 1024 * 1024,
        modifiedAt: 0,
        extension: '.mp4',
        durationMs: 5 * 1000,
      );
      const fullFilm = DiscoveredFile(
        path: 'content://media/external/video/media/12',
        size: 4 * 1024 * 1024 * 1024,
        modifiedAt: 0,
        extension: '.mkv',
        analysisName: 'Dune.Part.Two.2024.mkv',
        durationMs: 166 * 60 * 1000,
      );

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: ScanPolicy.videos(),
      ).discover(const [], additionalFiles: [thumbnail, fullFilm])) {
        files.addAll(batch);
      }

      expect(files, hasLength(1));
      expect(files.single.analysisName, 'Dune.Part.Two.2024.mkv');
    });

    test('video discovery does not need a filesystem walk when MediaStore '
        'already returned rows', () async {
      // The whole point of the MediaStore-first path: an empty root list must
      // still surface the rows instead of throwing or scanning the device.
      final entries = [
        const DiscoveredFile(
          path: 'content://media/external/video/media/7',
          size: 900 * 1024 * 1024,
          modifiedAt: 0,
          extension: '.mkv',
          analysisName: 'Breaking.Bad.S01E03.mkv',
        ),
      ];

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: ScanPolicy.videos(),
      ).discover(const [], additionalFiles: entries)) {
        files.addAll(batch);
      }

      expect(files, hasLength(1));
      expect(files.single.analysisName, 'Breaking.Bad.S01E03.mkv');
    });
  });
}