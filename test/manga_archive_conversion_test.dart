import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:watchtower/modules/manga/download/providers/convert_to_cbz.dart';

void main() {
  group('convertToMangaArchive', () {
    late Directory root;
    late Directory chapterDir;
    late Directory mangaDir;

    setUp(() {
      root = Directory.systemTemp.createTempSync('wt-archive-');
      chapterDir = Directory(p.join(root.path, 'chapter'))..createSync();
      mangaDir = Directory(p.join(root.path, 'manga'))..createSync();
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    /// Writes [count] real JPEG pages into the chapter directory and returns
    /// their paths in the same order the downloader produces them (zero-padded
    /// so the lexical sort inside the converter matches the page order).
    List<String> writePages(int count) {
      final paths = <String>[];
      for (var i = 0; i < count; i++) {
        final image = img.Image(width: 240 + i, height: 320 + i);
        img.fill(image, color: img.ColorRgb8(30 + i * 20, 90, 200 - i * 10));
        final file = File(p.join(chapterDir.path, '${i.toString().padLeft(3, '0')}.jpg'));
        file.writeAsBytesSync(img.encodeJpg(image, quality: 95));
        paths.add(file.path);
      }
      return paths;
    }

    test('recompressing pages keeps their order and yields a readable archive',
        () async {
      final pages = writePages(12);

      final included = await convertToMangaArchive(
        chapterDir: chapterDir.path,
        mangaDir: mangaDir.path,
        chapterName: 'Chapter 1',
        pageList: pages,
        formatExtension: '.cbz',
        compressionLevel: 6,
      );

      expect(included, pages);

      final archivePath = p.join(mangaDir.path, 'Chapter 1.cbz');
      final archive = ZipDecoder().decodeBytes(
        File(archivePath).readAsBytesSync(),
      );
      final names = archive.files.map((f) => f.name).toList();
      expect(
        names.where((n) => n.endsWith('.jpg')).toList(),
        [for (final page in pages) p.basename(page)],
      );

      // Every stored page is still a decodable JPEG, so the parallel
      // recompression cannot have corrupted a page's bytes.
      for (final file in archive.files.where((f) => f.name.endsWith('.jpg'))) {
        expect(img.decodeJpg(Uint8List.fromList(file.content as List<int>)), isNotNull);
      }
    });

    test('level 0 stores the original bytes without recompressing', () async {
      final pages = writePages(5);
      final originals = [for (final page in pages) File(page).readAsBytesSync()];

      await convertToMangaArchive(
        chapterDir: chapterDir.path,
        mangaDir: mangaDir.path,
        chapterName: 'Chapter 2',
        pageList: pages,
        formatExtension: '.cbz',
        compressionLevel: 0,
      );

      final archive = ZipDecoder().decodeBytes(
        File(p.join(mangaDir.path, 'Chapter 2.cbz')).readAsBytesSync(),
      );
      final stored = {
        for (final file in archive.files.where((f) => f.name.endsWith('.jpg')))
          file.name: file.content as List<int>,
      };
      for (final page in pages) {
        expect(stored[p.basename(page)], equals(originals[pages.indexOf(page)]));
      }
    });
  });
}
