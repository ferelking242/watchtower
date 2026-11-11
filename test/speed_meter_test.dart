import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/speed_meter.dart';

/// Regression: the queue reported a wildly inflated speed for a throttled
/// MissAV download. The old EMA was primed by one fast burst and, because the
/// progress callbacks arrive several seconds apart, kept reporting the burst
/// rate long after the transfer had slowed to a crawl.
void main() {
  group('SpeedMeter', () {
    test('is zero until two samples span a positive interval', () {
      final meter = SpeedMeter();
      expect(meter.sample(0, 1000), 0);
      expect(meter.sample(1024 * 1024, 1000), 0); // same instant
    });

    test('measures the average rate across the window', () {
      final meter = SpeedMeter();
      meter.sample(0, 0);
      // 4 MB over 4 s = 1 MB/s.
      final rate = meter.sample(4 * 1024 * 1024, 4000);
      expect(rate, closeTo(1.0, 0.01));
    });

    test('a fast burst is spread over the window, not reported as-is', () {
      final meter = SpeedMeter();
      meter.sample(0, 0);
      // 50 MB in 1 s (50 MB/s instant) then nothing for 4 s.
      meter.sample(50 * 1024 * 1024, 1000);
      final rate = meter.sample(50 * 1024 * 1024, 5000);
      // Averaged over ~5 s the burst reads ~10 MB/s, not 50.
      expect(rate, lessThan(15.0));
      expect(rate, greaterThan(0.0));
    });

    test('a backwards jump (resume reset) yields no rate', () {
      final meter = SpeedMeter();
      meter.sample(100 * 1024 * 1024, 0);
      // The resumed download restarts its cumulative counter from a lower value.
      expect(meter.sample(1 * 1024 * 1024, 1000), 0);
    });

    test('reports zero when the transfer stalls', () {
      final meter = SpeedMeter();
      meter.sample(0, 0);
      meter.sample(4 * 1024 * 1024, 2000);
      // No new bytes for another 6 s → the window drains to a 0 rate.
      expect(meter.sample(4 * 1024 * 1024, 8000), 0);
    });

    test('reset drops the history', () {
      final meter = SpeedMeter();
      meter.sample(0, 0);
      meter.sample(8 * 1024 * 1024, 2000);
      meter.reset();
      expect(meter.sample(8 * 1024 * 1024, 4000), 0);
    });
  });
}
