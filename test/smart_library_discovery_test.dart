import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';

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
      await File('${root.path}/Movies/Film.mp4').create(recursive: true);
      await File('${root.path}/Manga/One Piece/Chapter 1.cbz')
          .create(recursive: true);
      await File('${root.path}/Books/Novel.epub').create(recursive: true);

      final files = <DiscoveredFile>[];
      await for (final batch in DiscoveryStage(
        policy: const ScanPolicy.videos(),
      ).discover([root.path])) {
        files.addAll(batch);
      }

      expect(files.map((file) => file.extension), ['.mp4']);
    });

    test('Manga mode keeps one page representative per chapter folder', () async {
      await File(
        '${root.path}/Manga/One Piece/Chapter 12/page-001.jpg',
      ).create(recursive: true);
      await File(
        '${root.path}/Manga/One Piece/Chapter 12/page-002.jpg',
      ).create();
      await File('${root.path}/Manga/One Piece/Chapter 13.cbz').create();
      await File('${root.path}/Movies/Film.mp4').create(recursive: true);
      await File('${root.path}/Books/Novel.epub').create(recursive: true);

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