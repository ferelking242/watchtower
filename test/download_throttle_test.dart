import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';

void main() {
  group('throttleBytesPerSecond', () {
    test('converts kilobytes to bytes', () {
      expect(throttleBytesPerSecond(500), 500 * 1024.0);
    });

    test('zero means unlimited', () {
      expect(throttleBytesPerSecond(0), 0);
    });
  });

  group('DownloadThrottle', () {
    test('unlimited never withholds tokens', () async {
      final throttle = DownloadThrottle.fromKiloBytesPerSecond(0);
      await throttle.acquire(10 * 1024 * 1024);
      expect(throttle.tryTake(10 * 1024 * 1024), isTrue);
    });

    test('charges what it grants instead of letting the limit leak', () {
      // 1 KB/s → a 1 KB bucket. The buggy version slept for the deficit and
      // returned without charging, so the cap effectively doubled.
      final throttle = DownloadThrottle.fromKiloBytesPerSecond(1);

      expect(throttle.tryTake(1024), isTrue);
      expect(throttle.remainingTokens, closeTo(0, 1));

      // Nothing left: the next request must be refused, not granted for free.
      expect(throttle.tryTake(1024), isFalse);
    });

    test('refuses a request larger than the burst budget', () {
      final throttle = DownloadThrottle.fromKiloBytesPerSecond(1);
      // The bucket caps at 2 s of budget = 2 KB.
      expect(throttle.tryTake(4096), isFalse);
    });

    test('acquire actually waits for the deficit', () async {
      final throttle = DownloadThrottle.fromKiloBytesPerSecond(1);
      // Drain the bucket first.
      throttle.tryTake(1024);

      final started = DateTime.now();
      await throttle.acquire(1024);
      final elapsed = DateTime.now().difference(started);

      // 1 KB at 1 KB/s is about a second of waiting.
      expect(elapsed.inMilliseconds, greaterThan(700));
      // And it was charged: the bucket is empty again.
      expect(throttle.remainingTokens, lessThan(200));
    });
  });
}
