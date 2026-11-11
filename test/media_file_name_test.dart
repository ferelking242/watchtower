import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Coherence: the downloader writes `<title> [360p].mp4`, but share and delete
/// rebuilt the name from the title alone and looked for `<title>.mp4`. The MP4
/// was therefore never found again — it could not be shared, and deleting the
/// download left the file orphaned on disk. Writer and readers now share
/// [animeMp4BaseName].
void main() {
  group('animeMp4BaseName', () {
    test('appends the quality tag from the resolution digits', () {
      expect(animeMp4BaseName(chapterName: 'Ep 1', quality: '360p'), 'Ep 1 [360p]');
      expect(animeMp4BaseName(chapterName: 'Ep 1', quality: '1080p'), 'Ep 1 [1080p]');
      // Matches the provider's `_qualityDigits`: the first 3–4 digit run wins,
      // so the stored name is stable no matter how the label is formatted.
      expect(animeMp4BaseName(chapterName: 'Ep 1', quality: '1280x720'), 'Ep 1 [1280p]');
    });

    test('omits the tag when the quality carries no resolution', () {
      expect(animeMp4BaseName(chapterName: 'Ep 1', quality: null), 'Ep 1');
      expect(animeMp4BaseName(chapterName: 'Ep 1', quality: 'auto'), 'Ep 1');
    });

    test('replaces forbidden characters', () {
      expect(
        animeMp4BaseName(chapterName: 'Ep: 1/2', quality: '360p'),
        'Ep  1 2 [360p]',
      );
    });

    test('keeps the quality tag whole under the byte budget', () {
      final long = 'x' * 400;
      final name = animeMp4BaseName(chapterName: long, quality: '360p');

      expect(utf8.encode(name).length, lessThanOrEqualTo(kMaxDownloadNameBytes));
      expect(name.endsWith(' [360p]'), isTrue);
    });

    test('never splits a multi-byte rune when truncating', () {
      final name = animeMp4BaseName(chapterName: 'é' * 200, quality: '360p');
      expect(utf8.encode(name).length, lessThanOrEqualTo(kMaxDownloadNameBytes));
      expect(name.endsWith(' [360p]'), isTrue);
    });
  });

  group('safeChapterBaseName', () {
    test('uses the chapter title when present', () {
      expect(safeChapterBaseName(chapterName: 'Ep 1', chapterId: 7), 'Ep 1');
    });

    test('falls back to the chapter id for a null title (no null-check crash)', () {
      expect(safeChapterBaseName(chapterName: null, chapterId: 42), 'chapter_42');
    });

    test('falls back for an empty title', () {
      expect(safeChapterBaseName(chapterName: '', chapterId: 42), 'chapter_42');
    });

    test('an id-less null title still yields a usable name', () {
      expect(safeChapterBaseName(chapterName: null, chapterId: null), 'chapter_unknown');
    });
  });
}
