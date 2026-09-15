import 'package:better_player_plus/better_player_plus.dart';

/// The manifest determines the live offset; these are only loading ceilings.
const liveBufferingConfiguration = BetterPlayerBufferingConfiguration(
  minBufferMs: 10000,
  maxBufferMs: 30000,
  bufferForPlaybackMs: 1500,
  bufferForPlaybackAfterRebufferMs: 3000,
  backBufferDurationMs: 0,
  retainBackBufferFromKeyframe: false,
  prioritizeTimeOverSizeThresholds: true,
);

/// Detect freezes even when the native player reports no error. Pass a
/// monotonic elapsed time; live timestamps may move backwards with the window.
class LivePlaybackWatchdog {
  Duration? _position;
  Duration _bufferedAhead = Duration.zero;
  Duration? _lastPlaybackAt;
  Duration? _lastActivityAt;

  void reset() {
    _position = null;
    _bufferedAhead = Duration.zero;
    _lastPlaybackAt = null;
    _lastActivityAt = null;
  }

  bool observe({
    required Duration elapsed,
    required Duration position,
    required Duration bufferedAhead,
    required bool shouldPlay,
  }) {
    if (!shouldPlay) {
      reset();
      return false;
    }
    if (_position == null || position != _position) {
      _lastPlaybackAt = elapsed;
      _lastActivityAt = elapsed;
    } else if (bufferedAhead >
        _bufferedAhead + const Duration(milliseconds: 250)) {
      _lastActivityAt = elapsed;
    }
    _position = position;
    _bufferedAhead = bufferedAhead;
    final stalled = elapsed - _lastActivityAt! >= const Duration(seconds: 25) ||
        elapsed - _lastPlaybackAt! >= const Duration(seconds: 60);
    if (stalled) reset();
    return stalled;
  }
}
