import 'package:flutter_test/flutter_test.dart';
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
  });
}
