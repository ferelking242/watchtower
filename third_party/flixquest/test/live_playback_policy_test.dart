import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/live_playback_policy.dart';

void main() {
  test('live startup and refill thresholds fit a bounded forward-only buffer',
      () {
    expect(liveBufferingConfiguration.bufferForPlaybackMs, 1500);
    expect(liveBufferingConfiguration.bufferForPlaybackAfterRebufferMs, 3000);
    expect(liveBufferingConfiguration.minBufferMs, 10000);
    expect(liveBufferingConfiguration.maxBufferMs, 30000);
    expect(liveBufferingConfiguration.backBufferDurationMs, 0);
  });

  test(
      'silent stalled playback triggers after 25 seconds without useful progress',
      () {
    final watchdog = LivePlaybackWatchdog();
    bool sample(int seconds) => watchdog.observe(
          elapsed: Duration(seconds: seconds),
          position: const Duration(seconds: 10),
          bufferedAhead: Duration.zero,
          shouldPlay: true,
        );
    expect(sample(0), isFalse);
    expect(sample(24), isFalse);
    expect(sample(25), isTrue);
    expect(sample(26), isFalse);
  });

  test('growing startup buffer gets time but cannot suppress recovery forever',
      () {
    final watchdog = LivePlaybackWatchdog();
    for (var seconds = 0; seconds <= 60; seconds += 10) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration.zero,
            bufferedAhead: Duration(milliseconds: seconds * 50),
            shouldPlay: true,
          ),
          seconds == 60);
    }
  });

  test(
      'intentional pause resets the watchdog and resume starts a fresh interval',
      () {
    final watchdog = LivePlaybackWatchdog();
    for (final seconds in [0, 20, 100, 120]) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration.zero,
            bufferedAhead: Duration.zero,
            shouldPlay: seconds != 20,
          ),
          isFalse);
    }
  });

  test('a moving live window and source changes do not cause false stalls', () {
    final watchdog = LivePlaybackWatchdog();
    for (var seconds = 0; seconds < 100; seconds += 10) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration(seconds: seconds % 30),
            bufferedAhead: const Duration(seconds: 3),
            shouldPlay: true,
          ),
          isFalse);
    }
    watchdog.reset();
    expect(
        watchdog.observe(
          elapsed: const Duration(seconds: 200),
          position: Duration.zero,
          bufferedAhead: Duration.zero,
          shouldPlay: true,
        ),
        isFalse);
  });
}
