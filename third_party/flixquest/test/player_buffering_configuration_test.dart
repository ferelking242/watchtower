import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/player_buffering_configuration.dart';

void main() {
  test(
      'old six-minute preference is bounded and refills before reserve runs out',
      () {
    final configuration = buildPlayerBufferingConfiguration(
      maximumDurationMs: 360000,
      television: false,
    );
    expect(configuration.maxBufferMs, 180000);
    expect(configuration.minBufferMs, 60000);
    expect(configuration.bufferForPlaybackMs, 1500);
    expect(configuration.bufferForPlaybackAfterRebufferMs, 5000);
    expect(configuration.backBufferDurationMs, 60000);
    expect(configuration.retainBackBufferFromKeyframe, isTrue);
  });

  test('TV keeps a smaller rewind window with a decoding keyframe', () {
    final configuration = buildPlayerBufferingConfiguration(
      maximumDurationMs: 360000,
      television: true,
    );
    expect(configuration.maxBufferMs, 60000);
    expect(configuration.minBufferMs, 30000);
    expect(configuration.backBufferDurationMs, 15000);
    expect(configuration.retainBackBufferFromKeyframe, isTrue);
  });

  test(
      'every supported ceiling and corrupt persisted values produce valid native durations',
      () {
    for (final television in [false, true]) {
      for (final maximum in [
        -1,
        0,
        1000,
        15000,
        30000,
        45000,
        60000,
        120000,
        600000
      ]) {
        final configuration = buildPlayerBufferingConfiguration(
          maximumDurationMs: maximum,
          television: television,
        );
        expect(configuration.maxBufferMs,
            greaterThanOrEqualTo(configuration.minBufferMs));
        expect(
            configuration.minBufferMs,
            greaterThanOrEqualTo(
                configuration.bufferForPlaybackAfterRebufferMs));
        expect(configuration.minBufferMs,
            greaterThanOrEqualTo(configuration.bufferForPlaybackMs));
      }
    }
  });
}
