import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/services/update_notification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('seriesKeyFor', () {
    test('groups every chapter of one work under the same key', () {
      final first = seriesKeyFor(seriesTitle: 'Berserk', itemType: 'manga');
      final second = seriesKeyFor(seriesTitle: '  berserk ', itemType: 'MANGA');
      expect(first, second);
    });

    test('keeps a manga and an anime sharing a title apart', () {
      expect(
        seriesKeyFor(seriesTitle: 'Berserk', itemType: 'manga'),
        isNot(seriesKeyFor(seriesTitle: 'Berserk', itemType: 'anime')),
      );
    });

    test('an empty title still yields a stable key', () {
      expect(
        seriesKeyFor(seriesTitle: '   ', itemType: 'anime'),
        seriesKeyFor(seriesTitle: '', itemType: 'anime'),
      );
    });
  });

  group('cover path resolution', () {
    test('a missing or blank URL never yields a path', () async {
      expect(
        await WatchtowerNotificationService.instance.coverFilePath(null),
        isNull,
      );
      expect(
        await WatchtowerNotificationService.instance.coverFilePath('  '),
        isNull,
      );
    });

    test('the progress path primes without blocking', () {
      // The hot path cannot await, so the first tick returns null and the
      // resolution is kicked off in the background.
      expect(
        WatchtowerNotificationService.instance.primeCoverPath(null),
        isNull,
      );
    });
  });

  group('restoring persisted notices', () {
    test('a finished chapter is never restored', () {
      expect(
        mediaNoticeShouldBeRestored(
          isCompleted: true,
          isFailed: false,
        ),
        isFalse,
      );
    });

    test('a failed chapter is never restored', () {
      expect(
        mediaNoticeShouldBeRestored(
          isCompleted: false,
          isFailed: true,
        ),
        isFalse,
      );
    });

    test('a live transfer is restored', () {
      expect(
        mediaNoticeShouldBeRestored(
          isCompleted: false,
          isFailed: false,
        ),
        isTrue,
      );
    });

    test('a paused transfer is restored so it can be resumed', () {
      // A paused row is neither completed nor failed, so it survives.
      expect(
        mediaNoticeShouldBeRestored(isCompleted: false, isFailed: false),
        isTrue,
      );
    });
  });

  group('terminal state signature', () {
    test('identical outcomes share a signature', () {
      expect(
        seriesTerminalSignature(
          chapterIds: [1, 2, 3],
          done: 3,
          total: 3,
          failed: 0,
          paused: 0,
        ),
        seriesTerminalSignature(
          chapterIds: [1, 2, 3],
          done: 3,
          total: 3,
          failed: 0,
          paused: 0,
        ),
      );
    });

    test('chapter order does not change the signature', () {
      expect(
        seriesTerminalSignature(
          chapterIds: [3, 1, 2],
          done: 3,
          total: 3,
          failed: 0,
          paused: 0,
        ),
        seriesTerminalSignature(
          chapterIds: [1, 2, 3],
          done: 3,
          total: 3,
          failed: 0,
          paused: 0,
        ),
      );
    });

    test('a different outcome changes the signature', () {
      expect(
        seriesTerminalSignature(
          chapterIds: [1, 2, 3],
          done: 2,
          total: 3,
          failed: 1,
          paused: 0,
        ),
        isNot(
          seriesTerminalSignature(
            chapterIds: [1, 2, 3],
            done: 3,
            total: 3,
            failed: 0,
            paused: 0,
          ),
        ),
      );
    });

    test('a pause changes the signature', () {
      expect(
        seriesTerminalSignature(
          chapterIds: [1, 2, 3],
          done: 1,
          total: 3,
          failed: 0,
          paused: 2,
        ),
        isNot(
          seriesTerminalSignature(
            chapterIds: [1, 2, 3],
            done: 1,
            total: 3,
            failed: 0,
            paused: 0,
          ),
        ),
      );
    });

    test('a new batch with the same outcome is a different signature', () {
      // Otherwise a second batch ending 2/2 would be swallowed by the card the
      // user already saw for the first one.
      expect(
        seriesTerminalSignature(
          chapterIds: [7, 8],
          done: 2,
          total: 2,
          failed: 0,
          paused: 0,
        ),
        isNot(
          seriesTerminalSignature(
            chapterIds: [4, 5],
            done: 2,
            total: 2,
            failed: 0,
            paused: 0,
          ),
        ),
      );
    });
  });

  group('series card counts', () {
    test('a lone download shows no "1/1" counter', () {
      expect(seriesShowsUnitCounts(1), isFalse);
      expect(seriesShowsUnitCounts(0), isFalse);
    });

    test('a batch of several items reports its count', () {
      expect(seriesShowsUnitCounts(3), isTrue);
    });

    test('the unit noun follows the item type', () {
      expect(seriesUnitLabel('manga', 3), 'chapitres');
      expect(seriesUnitLabel('manga', 1), 'chapitre');
      expect(seriesUnitLabel('anime', 3), 'épisodes');
      expect(seriesUnitLabel('anime', 1), 'épisode');
      expect(seriesUnitLabel('music', 2), 'pistes');
      expect(seriesUnitLabel('game', 1), 'jeu');
    });

    test('the type is matched case-insensitively', () {
      expect(seriesUnitLabel('ANIME', 2), 'épisodes');
    });
  });

  group('title abbreviation', () {
    test('a short title is left untouched', () {
      expect(abbreviateNotificationTitle('Berserk'), 'Berserk');
    });

    test('surrounding whitespace is dropped', () {
      expect(abbreviateNotificationTitle('  Berserk  '), 'Berserk');
    });

    test('a long title is cut at a word boundary with an ellipsis', () {
      final result = abbreviateNotificationTitle(
        'Resigning and Healing in Another World Because I Am Reincarnated',
      );
      expect(result.endsWith('…'), isTrue);
      expect(result.length, lessThanOrEqualTo(39));
      expect(result, isNot(contains('  ')));
      expect(result.startsWith('Resigning and Healing'), isTrue);
    });

    test('a single long word is hard-cut instead of being dropped', () {
      final result = abbreviateNotificationTitle('A' * 60, maxLength: 10);
      expect(result, '${'A' * 10}…');
    });
  });

  group('pending retry queue', () {
    test('a queued retry survives until it is drained', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_media_download_retries', [
        jsonEncode(<String, dynamic>{
          'seriesKey': 'manga:berserk',
          'ids': [4, 9],
          'at': 0,
        }),
      ]);

      final replayed = <String, List<int>>{};
      WatchtowerNotificationService.instance.registerMediaSeriesActionHandler(
        (seriesKey, ids) async => replayed[seriesKey] = ids,
      );

      await WatchtowerNotificationService.instance.drainPendingRetries();

      expect(replayed, {
        'manga:berserk': [4, 9],
      });
      expect(prefs.getStringList('pending_media_download_retries'), isNull);
    });

    test('draining an empty queue does nothing', () async {
      var calls = 0;
      WatchtowerNotificationService.instance.registerMediaSeriesActionHandler(
        (seriesKey, ids) async => calls++,
      );

      await WatchtowerNotificationService.instance.drainPendingRetries();

      expect(calls, 0);
    });

    test('a malformed entry is skipped without dropping the others', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_media_download_retries', [
        'not json',
        jsonEncode(<String, dynamic>{
          'seriesKey': 'anime:one piece',
          'ids': [12],
          'at': 0,
        }),
      ]);

      final replayed = <String, List<int>>{};
      WatchtowerNotificationService.instance.registerMediaSeriesActionHandler(
        (seriesKey, ids) async => replayed[seriesKey] = ids,
      );

      await WatchtowerNotificationService.instance.drainPendingRetries();

      expect(replayed, {
        'anime:one piece': [12],
      });
    });
  });
}
