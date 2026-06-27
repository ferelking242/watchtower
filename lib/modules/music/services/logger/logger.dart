import 'package:flutter/foundation.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:watchtower/utils/log/logger.dart' as wt;

  // ponytail: Spotube's AppLogger replaced entirely by a thin forwarder to
  // Watchtower's AppLogger. No second Logger instance, no second log file.
  // Ceiling: maps logger-package levels to wt.LogLevel (trace/debug→debug,
  // info→info, warning→warning, error/fatal→error).

  class _WtLogForwarder {
    void t(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.debug, msg, error, stackTrace);
    void d(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.debug, msg, error, stackTrace);
    void i(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.info, msg, error, stackTrace);
    void w(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.warning, msg, error, stackTrace);
    void e(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.error, msg, error, stackTrace);
    void f(Object? msg, {Object? error, StackTrace? stackTrace}) =>
        _emit(wt.LogLevel.error, msg, error, stackTrace);

    // Generic log() used in a few spots: level is unused, treated as debug.
    void log(dynamic level, Object? msg,
        {Object? error, StackTrace? stackTrace, DateTime? time}) =>
        _emit(wt.LogLevel.debug, msg, error, stackTrace);

    void _emit(wt.LogLevel level, Object? msg, Object? error, StackTrace? stack) {
      wt.AppLogger.log(
        msg?.toString() ?? '',
        logLevel: level,
        tag: 'Music',
        error: error,
        stackTrace: stack,
      );
    }
  }

  class AppLogger {
    // Single forwarder instance — drop-in for Logger from the logger package.
    static final _WtLogForwarder log = _WtLogForwarder();

    // No-op: Watchtower's logger is already initialised by main.dart.
    static void initialize(bool verbose) {}

    // Keep setBridge as no-op for any leftover call sites.
    static void setBridge(void Function(dynamic, StackTrace?) cb) {}

    static Future<void> reportError(
      dynamic error, [
      StackTrace? stackTrace,
      message = "",
    ]) async {
      wt.AppLogger.log(
        message.toString().isNotEmpty ? message.toString() : error.toString(),
        logLevel: wt.LogLevel.error,
        tag: 'Music',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  base class AppLoggerProviderObserver extends ProviderObserver {
    const AppLoggerProviderObserver();

    @override
    void providerDidFail(
      ProviderObserverContext context,
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.reportError(error, stackTrace);
    }
  }
  