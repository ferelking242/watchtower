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
        policy: const ScanPolicy.videos(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files.map((file) => file.extension), ['.mp4']);
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
        policy: const ScanPolicy.videos(),
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
        policy: const ScanPolicy.videos(),
      ).discover([root.path], additionalFiles: entries)) {
        files.addAll(batch);
      }

      expect(files, hasLength(1));
      expect(files.single.extension, '.mp4');
      expect(files.single.analysisName, 'Film.2020.mp4');
    });
  });
}