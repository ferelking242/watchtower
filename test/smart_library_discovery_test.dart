import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';

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
  });
}