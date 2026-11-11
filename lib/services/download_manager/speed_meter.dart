/// Recent transfer rate, measured over a sliding window of cumulative byte
/// samples.
///
/// The queue used to derive its speed from a single-exponential moving average
/// fed by whatever interval the download engine happened to report. That made
/// the readout lie in two ways:
///
///  * one fast burst primed the EMA and, because progress callbacks can be many
///    seconds apart on a throttled CDN, the inflated value lingered long after
///    the transfer had slowed down;
///  * a resumed download reports a cumulative byte count that starts at the
///    on-disk offset, so a backward or oversized jump produced a nonsense rate.
///
/// Averaging the bytes actually transferred across the last few seconds is
/// immune to both: a lone spike is spread over the window, and a backwards jump
/// (a resume reset) yields no rate instead of a negative one.
class SpeedMeter {
  SpeedMeter({this.window = const Duration(seconds: 5)});

  /// How far back the rate is measured. Long enough to ride out one slow
  /// callback, short enough that a genuine slowdown is reflected within a few
  /// seconds.
  final Duration window;

  final List<(int ms, int bytes)> _samples = [];

  /// Feeds the cumulative [bytes] observed at [nowMs] and returns the recent
  /// rate in MB/s. Returns 0 until two samples span a positive interval, and 0
  /// after a backward jump (a resume reset) so a stale offset never inflates
  /// the reading.
  double sample(int bytes, int nowMs) {
    if (bytes < 0) return 0;
    _samples.add((nowMs, bytes));

    // Keep the newest sample that predates the window so the measured span
    // still covers the whole window rather than shrinking to the last pair.
    while (_samples.length > 2 &&
        nowMs - _samples.first.$1 > window.inMilliseconds) {
      _samples.removeAt(0);
    }
    if (_samples.length < 2) return 0;

    final (t0, b0) = _samples.first;
    final dtSeconds = (nowMs - t0) / 1000.0;
    final deltaBytes = bytes - b0;
    if (dtSeconds <= 0 || deltaBytes < 0) return 0;
    return (deltaBytes / (1024 * 1024)) / dtSeconds;
  }

  /// Drops every sample, e.g. when a transfer is paused and resumed.
  void reset() => _samples.clear();
}
