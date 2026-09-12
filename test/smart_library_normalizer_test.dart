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
  });
}