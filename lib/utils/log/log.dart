import 'dart:async';

bool useLogger = false;

class Logger {
  static final StreamController<(LoggerLevel, String, DateTime)>
  _logStreamController =
      StreamController<(LoggerLevel, String, DateTime)>.broadcast();

  static StreamController<(LoggerLevel, String, DateTime)>
  get logStreamController => _logStreamController;

  static final List<(LoggerLevel, String, DateTime)> _logs = [];

  /// The overlay only ever shows the tail, so keeping the whole session in RAM
  /// (extension consoles can emit tens of thousands of lines) is pure growth.
  static const int maxLogs = 2000;

  static List<(LoggerLevel, String, DateTime)> get logs => _logs;

  static void add(LoggerLevel level, String content) {
    _logStreamController.add((level, content, DateTime.now()));
    _logs.add((level, content, DateTime.now()));
    if (_logs.length > maxLogs) {
      _logs.removeRange(0, _logs.length - maxLogs);
    }
  }

  static void clear() {
    _logs.clear();
  }
}

enum LoggerLevel { error, warning, info }
