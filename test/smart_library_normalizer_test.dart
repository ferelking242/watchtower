import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/name_normalizer.dart';

void main() {
  group('Smart Library filename normalization', () {
    test('extracts a standard TV episode without release noise', () {
      final result = NameNormalizer.normalize(
        '/Shows/Breaking.Bad.S01E03.1080p.WEB-DL.x265-GROUP.mkv',
      );

      expect(result.title, 'Breaking Bad');
      expect(result.kind, LocalMediaKind.series);
      expect(result.season, 1);
      expect(result.episode, 3);
      expect(result.quality, '1080p');
      expect(result.codec, 'x265');
    });

    test('supports anime episode numbers and explicit anime folders', () {
      final result = NameNormalizer.normalize(
        '/Anime/One.Piece.1122.mkv',
      );

      expect(result.title, 'One Piece');
      expect(result.kind, LocalMediaKind.anime);
      expect(result.episode, 1122);
    });

    test('does not turn a movie year into an episode', () {
      final result = NameNormalizer.normalize(
        '/Movies/Interstellar.2014.1080p.BluRay.mkv',
      );

      expect(result.title, 'Interstellar');
      expect(result.kind, LocalMediaKind.movie);
      expect(result.episode, isNull);
    });

    test('keeps a numeric movie title such as 1917', () {
      final result = NameNormalizer.normalize(
        '/Movies/1917.2019.1080p.mkv',
      );

      expect(result.title, '1917');
      expect(result.kind, LocalMediaKind.movie);
      expect(result.episode, isNull);
    });

    test('understands 1x01 and Season 1 Episode 2 notation', () {
      final first = NameNormalizer.normalize('/Shows/The.Office.1x01.mkv');
      final second = NameNormalizer.normalize(
        '/Shows/The.Office.Season.1.Episode.2.mkv',
      );

      expect(first.season, 1);
      expect(first.episode, 1);
      expect(second.season, 1);
      expect(second.episode, 2);
    });

    test('recognizes comic archive formats without indexing novels', () {
      expect(
        NameNormalizer.normalize('/Manga/One.Piece.Chapter.001.cb7').kind,
        LocalMediaKind.manga,
      );
      final chapter = NameNormalizer.normalize(
        '/Manga/One Piece/Chapter 12.cbz',
      );
      expect(chapter.title, 'One Piece');
      expect(chapter.chapter, 12);
      expect(chapter.kind, LocalMediaKind.manga);
      final volume = NameNormalizer.normalize(
        '/Manga/Berserk/Vol. 2/page.cbz',
      );
      expect(volume.title, 'Berserk');
      expect(volume.volume, 2);
      expect(
        NameNormalizer.normalize('/Downloads/Berserk Vol 02.zip').kind,
        LocalMediaKind.manga,
      );
      expect(
        NameNormalizer.normalize('/Books/Novel.epub').kind,
        LocalMediaKind.novel,
      );
    });

    test('classifies audio files as music and parses artist/title/album', () {
      final result = NameNormalizer.normalize(
        '/Music/Daft Punk/Random Access Memories/01 - Get Lucky.flac',
      );

      expect(result.kind, LocalMediaKind.music);
      expect(result.title, 'Get Lucky');
      expect(result.artist, 'Daft Punk');
      expect(result.album, 'Random Access Memories');
    });

    test('reads a music artist from the filename when folders are generic', () {
      final result = NameNormalizer.normalize('/storage/emulated/0/Download/Nirvana - Smells Like Teen Spirit.mp3');

      expect(result.kind, LocalMediaKind.music);
      expect(result.title, 'Smells Like Teen Spirit');
      expect(result.artist, 'Nirvana');
    });

    test('strips a leading track number from a plain music filename', () {
      final result = NameNormalizer.normalize('/Music/Album/07 Wonderwall.m4a');

      expect(result.kind, LocalMediaKind.music);
      expect(result.title, 'Wonderwall');
    });

    test('never classifies audio as a movie or series', () {
      for (final ext in ['.mp3', '.flac', '.opus', '.wav', '.m4a']) {
        expect(
          NameNormalizer.normalize('/Media/Some.2020.Song$ext').kind,
          LocalMediaKind.music,
        );
      }
    });
  });
}