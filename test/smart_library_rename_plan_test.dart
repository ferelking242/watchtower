import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/rename/local_rename_service.dart';

LocalIndexedItem _item({
  required String path,
  required String title,
  required LocalMediaKind kind,
  int? season,
  int? episode,
  String? artist,
}) {
  final item = LocalIndexedItem()
    ..filePath = path
    ..rawFilename = path.split('/').last
    ..title = title
    ..kind = kind
    ..season = season
    ..episode = episode
    ..artist = artist;
  return item;
}

void main() {
  group('Smart Library rename plans', () {
    final service = LocalRenameService.instance;

    test('a series episode becomes Title SxxExx', () {
      final plan = service.plan(
        _item(
          path: '/tv/Breaking.Bad.S01E03.1080p.mkv',
          title: 'Breaking Bad',
          kind: LocalMediaKind.series,
          season: 1,
          episode: 3,
        ),
      );

      expect(plan.targetName, 'Breaking Bad S01E03.mkv');
      expect(plan.targetPath, '/tv/Breaking Bad S01E03.mkv');
      expect(plan.isRenameable, isTrue);
    });

    test('an anime episode uses a zero-padded absolute number', () {
      final plan = service.plan(
        _item(
          path: '/anime/frieren_12.mkv',
          title: 'Frieren',
          kind: LocalMediaKind.anime,
          episode: 12,
        ),
      );

      expect(plan.targetName, 'Frieren - 012.mkv');
    });

    test('a music track becomes Artist - Title', () {
      final plan = service.plan(
        _item(
          path: '/music/01 bohemian.mp3',
          title: 'Bohemian Rhapsody',
          kind: LocalMediaKind.music,
          artist: 'Queen',
        ),
      );

      expect(plan.targetName, 'Queen - Bohemian Rhapsody.mp3');
    });

    test('a file already correctly named is not renamed', () {
      final plan = service.plan(
        _item(
          path: '/tv/Breaking Bad S01E03.mkv',
          title: 'Breaking Bad',
          kind: LocalMediaKind.series,
          season: 1,
          episode: 3,
        ),
      );

      expect(plan.isRenameable, isFalse);
    });

    test('an empty title blocks the rename instead of producing ".mkv"', () {
      final plan = service.plan(
        _item(path: '/tv/random.mkv', title: '', kind: LocalMediaKind.movie),
      );

      expect(plan.isRenameable, isFalse);
      expect(plan.blockedReason, 'no_title');
    });

    test('characters illegal on Windows are stripped', () {
      final plan = service.plan(
        _item(
          path: '/tv/x.mkv',
          title: 'Law & Order: SVU',
          kind: LocalMediaKind.series,
          season: 2,
          episode: 7,
        ),
      );

      expect(plan.targetName, 'Law & Order SVU S02E07.mkv');
    });
  });
}
