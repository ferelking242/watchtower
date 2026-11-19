import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/host_cooldown_registry.dart';

void main() {
  group('parseRetryAfter', () {
    test('reads a seconds value', () {
      expect(parseRetryAfter('120'), const Duration(seconds: 120));
    });

    test('tolerates surrounding whitespace', () {
      expect(parseRetryAfter('  7 '), const Duration(seconds: 7));
    });

    test('treats a past date as no wait', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      expect(
        parseRetryAfter('2026-01-01T11:00:00Z', now: now),
        Duration.zero,
      );
    });

    test('computes the wait from a future date', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      expect(
        parseRetryAfter('2026-01-01T12:02:00Z', now: now),
        const Duration(minutes: 2),
      );
    });

    test('clamps an absurd wait instead of parking the download', () {
      expect(parseRetryAfter('999999'), const Duration(minutes: 5));
    });

    test('returns null when the header is missing or unusable', () {
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter(''), isNull);
      expect(parseRetryAfter('not-a-date'), isNull);
    });
  });

  group('resolvePageTransferOutcome', () {
    test('no failures means the chapter is complete', () {
      expect(
        resolvePageTransferOutcome(failedCount: 0, total: 40),
        PageTransferOutcome.complete,
      );
    });

    test('one bad page keeps the chapter instead of discarding it', () {
      // The regression: page 31 of 40 hit a 429 and the whole chapter was
      // thrown away, so the next attempt re-downloaded 30 pages for nothing.
      expect(
        resolvePageTransferOutcome(failedCount: 1, total: 40),
        PageTransferOutcome.partial,
      );
    });

    test('a handful of bad pages is still partial', () {
      expect(
        resolvePageTransferOutcome(failedCount: 9, total: 40),
        PageTransferOutcome.partial,
      );
    });

    test('every page failing is a real failure', () {
      expect(
        resolvePageTransferOutcome(failedCount: 40, total: 40),
        PageTransferOutcome.failed,
      );
    });

    test('an unknown total never reports a bogus completion', () {
      expect(
        resolvePageTransferOutcome(failedCount: 3, total: 0),
        PageTransferOutcome.partial,
      );
    });

    test('a resumed chapter is judged against its real size', () {
      // A 17-page chapter with 16 pages on disk retries only page 17. Judged
      // against the pending subset (1), that failure looked total: the chapter
      // was marked failed and the 16 verified pages were dropped, so every
      // relaunch died on the same page.
      expect(
        resolvePageTransferOutcome(failedCount: 1, total: 17),
        PageTransferOutcome.partial,
      );
      expect(
        resolvePageTransferOutcome(failedCount: 1, total: 1),
        PageTransferOutcome.failed,
      );
    });
  });

  group('Speed Master throttle', () {
    test('a KB/s setting becomes bytes per second', () {
      // The setting is in kilobytes while the bucket counts bytes. Passing the
      // raw number capped a 500 KB/s limit at 500 B/s, so every page ran past
      // the 30 s image timeout and the chapter died after the first page.
      expect(throttleBytesPerSecond(500), 500 * 1024);
      expect(throttleBytesPerSecond(1), 1024);
    });

    test('zero and negative values mean unlimited', () {
      expect(throttleBytesPerSecond(0), 0);
      expect(throttleBytesPerSecond(-10), 0);
    });

    test('a 120 KB page is not throttled for minutes at 500 KB/s', () {
      final bytesPerSecond = throttleBytesPerSecond(500);
      expect(120 * 1024 / bytesPerSecond, lessThan(1));
    });
  });

  group('page retry passes', () {
    test('a failed pass gets another chance until the budget runs out', () {
      // "One page downloaded, then it fails" came from stopping at the first
      // bad page; a transient failure must not end the chapter.
      expect(shouldRetryPagePass(passIndex: 0), isTrue);
      expect(shouldRetryPagePass(passIndex: 1), isTrue);
      expect(shouldRetryPagePass(passIndex: 2), isFalse);
    });

    test('retries are bounded so a dead host is not hammered', () {
      var passes = 0;
      while (shouldRetryPagePass(passIndex: passes)) {
        passes++;
        expect(passes, lessThan(10));
      }
      expect(passes, 2);
    });
  });

  group('FileDownloadParams chapter denominator', () {
    List<PageUrl> pages(int count) => [
      for (var i = 0; i < count; i++)
        PageUrl('https://cdn.example.com/$i.jpg'),
    ];

    test('defaults to the pending page count', () {
      final params = FileDownloadParams(
        pageUrls: pages(3),
        concurrentDownloads: 2,
        itemType: ItemType.manga,
      );
      expect(params.chapterTotal, 3);
    });

    test('keeps the chapter size on a resume with fewer pending pages', () {
      final params = FileDownloadParams(
        pageUrls: pages(1),
        concurrentDownloads: 2,
        itemType: ItemType.manga,
        chapterTotal: 17,
      );
      expect(params.chapterTotal, 17);
    });

    test('ignores a chapter size smaller than the pending pages', () {
      final params = FileDownloadParams(
        pageUrls: pages(5),
        concurrentDownloads: 2,
        itemType: ItemType.manga,
        chapterTotal: 2,
      );
      expect(params.chapterTotal, 5);
    });
  });

  group('DownloadPoolException.partial', () {
    test('reports a partial chapter without claiming total failure', () {
      final error = DownloadPoolException.partial('3 pages manquantes', null, 3, 40);
      expect(error.isPartial, isTrue);
      expect(error.failedCount, 3);
      expect(error.totalCount, 40);
      expect(error.retryable, isFalse);
    });

    test('a fully failed chapter is not partial', () {
      final error = DownloadPoolException.partial('tout a échoué', null, 40, 40);
      expect(error.isPartial, isFalse);
    });

    test('the default constructors carry no page counts', () {
      final error = DownloadPoolException('boom');
      expect(error.failedCount, 0);
      expect(error.totalCount, 0);
      expect(error.isPartial, isFalse);
      expect(error.retryAfter, isNull);
    });
  });

  group('DownloadPoolFailure', () {
    test('keeps the structured fields across the isolate boundary', () {
      final failure = DownloadPoolFailure(
        '3 pages manquantes',
        retryable: false,
        retryAfter: const Duration(seconds: 30),
        failedCount: 3,
        totalCount: 40,
      );
      expect(failure.isPartial, isTrue);
      expect(failure.retryAfter, const Duration(seconds: 30));
      expect(failure.failedCount, 3);
    });
  });

  group('HostCooldownRegistry', () {
    setUp(() => HostCooldownRegistry.instance.resetForTest());

    test('a host is usable until it fails', () {
      final registry = HostCooldownRegistry.instance;
      expect(registry.isCoolingDown('cdn.example.com'), isFalse);
      expect(registry.remaining('cdn.example.com'), isNull);
    });

    test('a rate limit puts the host into cooldown', () {
      final registry = HostCooldownRegistry.instance;
      final cooldown = registry.registerFailure('cdn.example.com');
      expect(cooldown, greaterThan(Duration.zero));
      expect(registry.isCoolingDown('cdn.example.com'), isTrue);
      expect(registry.remaining('cdn.example.com'), isNotNull);
    });

    test('repeated strikes escalate the cooldown', () {
      final registry = HostCooldownRegistry.instance;
      final first = registry.registerFailure('cdn.example.com');
      final second = registry.registerFailure('cdn.example.com');
      expect(second, greaterThan(first));
    });

    test('the cooldown is capped so a host is never parked indefinitely', () {
      final registry = HostCooldownRegistry.instance;
      Duration last = Duration.zero;
      for (var i = 0; i < 12; i++) {
        last = registry.registerFailure('cdn.example.com');
      }
      expect(last, lessThanOrEqualTo(const Duration(minutes: 15)));
    });

    test('honours a longer Retry-After from the server', () {
      final registry = HostCooldownRegistry.instance;
      final cooldown = registry.registerFailure(
        'cdn.example.com',
        retryAfter: const Duration(minutes: 2),
      );
      expect(cooldown, greaterThanOrEqualTo(const Duration(minutes: 2)));
    });

    test('a success clears both the cooldown and the strike count', () {
      final registry = HostCooldownRegistry.instance;
      registry.registerFailure('cdn.example.com');
      registry.registerFailure('cdn.example.com');
      registry.registerSuccess('cdn.example.com');
      expect(registry.isCoolingDown('cdn.example.com'), isFalse);

      // Strikes were reset, so the next failure starts from the base delay.
      final afterReset = registry.registerFailure('cdn.example.com');
      final fresh = HostCooldownRegistry.instance;
      fresh.resetForTest();
      expect(afterReset, fresh.registerFailure('cdn.example.com'));
    });

    test('cooldowns are per host', () {
      final registry = HostCooldownRegistry.instance;
      registry.registerFailure('a.example.com');
      expect(registry.isCoolingDown('a.example.com'), isTrue);
      expect(registry.isCoolingDown('b.example.com'), isFalse);
    });

    test('an empty host is ignored', () {
      final registry = HostCooldownRegistry.instance;
      expect(registry.registerFailure(''), Duration.zero);
      expect(registry.isCoolingDown(''), isFalse);
    });

    test('the scheduler key and the recorder key are the same value', () {
      // BUG-A: dispatch gated on the page host while failures were recorded
      // against the source name, so no cooldown ever matched and a throttled
      // source kept receiving every queued chapter.
      expect(HostCooldownRegistry.keyForSource('MangaDex'), 'MangaDex');
      expect(HostCooldownRegistry.keyForSource(''), '_unknown');
      final registry = HostCooldownRegistry.instance;
      final key = HostCooldownRegistry.keyForSource('MangaDex');
      registry.registerFailure(key);
      expect(registry.isCoolingDown(HostCooldownRegistry.keyForSource('MangaDex')), isTrue);
    });
  });
}
