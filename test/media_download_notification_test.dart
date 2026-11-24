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
