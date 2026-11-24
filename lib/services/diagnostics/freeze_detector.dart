/// Turns a periodic timer's arrival times into UI-stall measurements.
///
/// A timer that fires late is the cheapest signal that the isolate was busy:
/// the callback cannot run while something else blocks the event loop, so the
/// lateness is a lower bound of the stall. Kept separate from the service so
/// the arithmetic can be tested without real timers.
library;

class FreezeDetector {
  FreezeDetector({
    this.tick = const Duration(milliseconds: 250),
    this.threshold = const Duration(milliseconds: 1500),
  }) : _next = tick;

  /// Expected interval between two callbacks.
  final Duration tick;

  /// Lateness at or above this value is reported as a freeze.
  final Duration threshold;

  Duration _next;

  /// Feeds one callback arrival, measured on a monotonic clock started before
  /// the first tick. Returns the stall duration when it crossed [threshold],
  /// null otherwise. Each stall is reported once: the schedule is re-based on
  /// the arrival so a long block does not report the same lateness twice.
  Duration? addSample(Duration elapsed) {
    final drift = elapsed - _next;
    _next = elapsed + tick;
    return drift >= threshold ? drift : null;
  }

  /// Forgets the schedule, for when the app comes back from the background and
  /// the elapsed clock is no longer meaningful.
  void reset(Duration elapsed) {
    _next = elapsed + tick;
  }
}
