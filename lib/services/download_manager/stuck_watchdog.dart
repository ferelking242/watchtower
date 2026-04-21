import 'dart:async';
import 'package:watchtower/utils/log/logger.dart';

/// Logs a heartbeat for an active download and warns when no progress
/// has been observed for a configurable period — making "stuck" downloads
/// easy to spot in the log viewer.
class DownloadStuckWatchdog {
  final String label;
  final Duration heartbeat;
  final Duration stuckAfter;

  Timer? _timer;
  DateTime _lastProgress = DateTime.now();
  int _lastPercent = -1;
  bool _stuckLogged = false;

  DownloadStuckWatchdog({
    required this.label,
    this.heartbeat = const Duration(seconds: 15),
    this.stuckAfter = const Duration(seconds: 45),
  });

  void start({int Function()? percentGetter}) {
    stop();
    _lastProgress = DateTime.now();
    _stuckLogged = false;
    AppLogger.log('watchdog start | $label', tag: LogTag.download);
    _timer = Timer.periodic(heartbeat, (_) {
      final p = percentGetter?.call();
      final since = DateTime.now().difference(_lastProgress);
      if (p != null && p != _lastPercent) {
        _lastPercent = p;
        _lastProgress = DateTime.now();
        _stuckLogged = false;
        AppLogger.log(
          'heartbeat | $label | $p%',
          logLevel: LogLevel.debug,
          tag: LogTag.download,
        );
      } else if (since >= stuckAfter && !_stuckLogged) {
        _stuckLogged = true;
        AppLogger.log(
          'STUCK | $label | no progress for ${since.inSeconds}s '
          '(last percent=$_lastPercent)',
          logLevel: LogLevel.warning,
          tag: LogTag.download,
        );
      }
    });
  }

  void notifyProgress(int percent) {
    if (percent != _lastPercent) {
      _lastPercent = percent;
      _lastProgress = DateTime.now();
      _stuckLogged = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
