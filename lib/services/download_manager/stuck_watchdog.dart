import 'dart:async';
import 'package:watchtower/utils/log/logger.dart';

/// Logs a heartbeat for an active download and warns when no progress
/// has been observed for a configurable period — making "stuck" downloads
/// easy to spot in the log viewer.
///
/// Two phases are tracked separately so we don't log false STUCK warnings
/// while the download is still in the fetching/preparation step (which
/// can legitimately take 90s while the source extension resolves the
/// video URL):
///
///   * fetching: only a long [stuckAfterFetching] timeout (default 120s)
///     triggers a STUCK warning, since no progress is expected yet.
///   * downloading: the normal [stuckAfter] timeout applies.
class DownloadStuckWatchdog {
  final String label;
  final Duration heartbeat;
  final Duration stuckAfter;
  final Duration stuckAfterFetching;

  Timer? _timer;
  DateTime _lastProgress = DateTime.now();
  int _lastPercent = 0;
  bool _stuckLogged = false;
  bool _isFetching = true;

  DownloadStuckWatchdog({
    required this.label,
    this.heartbeat = const Duration(seconds: 15),
    this.stuckAfter = const Duration(seconds: 60),
    this.stuckAfterFetching = const Duration(seconds: 120),
  });

  /// Start the watchdog in the *fetching* phase. No STUCK warning will
  /// be emitted until [stuckAfterFetching] has elapsed without any
  /// transition to the downloading phase.
  void start({int Function()? percentGetter}) {
    stop();
    _lastProgress = DateTime.now();
    _lastPercent = 0;
    _stuckLogged = false;
    _isFetching = true;
    AppLogger.log('watchdog start (fetching) | $label', tag: LogTag.download);
    _timer = Timer.periodic(heartbeat, (_) {
      final p = percentGetter?.call();
      final since = DateTime.now().difference(_lastProgress);
      if (p != null && p != _lastPercent && p >= 0) {
        // Real progress observed: switch to downloading phase.
        _lastPercent = p;
        _lastProgress = DateTime.now();
        _stuckLogged = false;
        _isFetching = false;
        AppLogger.log(
          'heartbeat | $label | $p%',
          logLevel: LogLevel.debug,
          tag: LogTag.download,
        );
      } else {
        final threshold = _isFetching ? stuckAfterFetching : stuckAfter;
        if (since >= threshold && !_stuckLogged) {
          _stuckLogged = true;
          AppLogger.log(
            'STUCK | $label | no progress for ${since.inSeconds}s '
            '(phase=${_isFetching ? "fetching" : "downloading"}, '
            'last percent=$_lastPercent)',
            logLevel: LogLevel.warning,
            tag: LogTag.download,
          );
        }
      }
    });
  }

  /// Mark the transition from fetching to actively downloading. Call
  /// this once the source URL has been resolved and the first segment
  /// or page request has been issued. From this point on the shorter
  /// [stuckAfter] threshold applies.
  void markDownloading() {
    if (_isFetching) {
      _isFetching = false;
      _lastProgress = DateTime.now();
      _stuckLogged = false;
      AppLogger.log(
        'watchdog → downloading | $label',
        tag: LogTag.download,
      );
    }
  }

  void notifyProgress(int percent) {
    if (percent < 0) return;
    if (percent != _lastPercent) {
      _lastPercent = percent;
      _lastProgress = DateTime.now();
      _stuckLogged = false;
      _isFetching = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
