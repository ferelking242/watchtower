import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Regression: an HLS download of an episode with a very long title used to
/// fail at the *merge* step with `File name too long` (errno 36), after the
/// whole episode had already been downloaded.
///
/// The assembler writes `<name>.mp4.part.joined` next to the final file, and
/// Linux/Android/iOS cap one path component at 255 bytes (`NAME_MAX`). For the
/// reported episode the base name alone was 234 bytes, so
/// `234 + " [360p]" + ".mp4" + ".part" + ".joined"` = 257 bytes overflowed the
/// limit. Names must now be truncated to keep that intermediate within 255.
void main() {
  // The exact title from the failing download (234 UTF-8 bytes).
  const mida517 =
      'MIDA-517 A Divine Fingering Technique That Always Makes A Serious '
      'Female Teacher Climax - A Molester Train Who Has Become A Premature '
      'Ejaculator Due To An Abnormal Sexual Desire, And Has Derailed Her '
      'Teaching Profession - Sakura Miura';

  group('truncateToBytes', () {
    test('leaves a short name untouched', () {
      expect('short'.truncateToBytes(239), 'short');
    });

    test('bounds an ASCII name to the byte budget', () {
      final long = 'a' * 400;
      final out = long.truncateToBytes(kMaxDownloadNameBytes);
      expect(utf8.encode(out).length, lessThanOrEqualTo(kMaxDownloadNameBytes));
      expect(out.length, kMaxDownloadNameBytes);
    });

    test('never splits a multi-byte rune', () {
      // 'é' is two bytes; cutting at an odd budget must drop the whole rune.
      final out = 'é' * 10;
      final truncated = out.truncateToBytes(5);
      expect(utf8.encode(truncated).length, lessThanOrEqualTo(5));
      expect(truncated, 'éé');
    });
  });

  group('long episode title keeps the HLS intermediates within NAME_MAX', () {
    test('the raw title really would overflow', () {
      // Guards the regression: the pre-fix derivation produced 257 bytes.
      final raw = '$mida517 [360p].mp4.part.joined';
      expect(utf8.encode(raw).length, greaterThan(255));
    });

    test('the bounded derivation fits NAME_MAX and keeps the quality tag', () {
      const qualitySuffix = ' [360p]';
      // Mirrors downloadChapter's `chapterName` derivation.
      final base = mida517
          .replaceForbiddenCharacters(' ')
          .truncateToBytes(kMaxDownloadNameBytes - qualitySuffix.length);
      final chapterName = '$base$qualitySuffix';

      expect(utf8.encode(chapterName).length, lessThanOrEqualTo(239));
      expect(chapterName.endsWith(qualitySuffix), isTrue);

      final mp4 = '$chapterName.mp4';
      final part = '$mp4.part';
      final joined = '$mp4.part.joined';
      for (final name in [mp4, part, joined]) {
        expect(
          utf8.encode(name).length,
          lessThanOrEqualTo(255),
          reason: 'NAME_MAX overflow for "$name"',
        );
      }
    });

    test('the filesystem accepts every derived name', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'watchtower-longname-test-',
      );
      addTearDown(() => sandbox.delete(recursive: true));

      const qualitySuffix = ' [360p]';
      final base = mida517
          .replaceForbiddenCharacters(' ')
          .truncateToBytes(kMaxDownloadNameBytes - qualitySuffix.length);
      final chapterName = '$base$qualitySuffix';

      for (final name in [
        '$chapterName.mp4',
        '$chapterName.mp4.part',
        '$chapterName.mp4.part.joined',
      ]) {
        final file = File('${sandbox.path}/$name');
        await file.writeAsString('x'); // throws errno 36 if too long
        expect(await file.exists(), isTrue);
      }
    });
  });
}
