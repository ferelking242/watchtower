import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:watchtower/utils/log/logger.dart' as wt;

// ponytail: Spotube AppLogger = thin forwarder to wt.AppLogger.
// No second Logger instance. getLogsPath() kept for logsProvider/logs.dart.

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
  void log(dynamic level, Object? msg,
      {Object? error, StackTrace? stackTrace, DateTime? time}) =>
      _emit(wt.LogLevel.debug, msg, error, stackTrace);

  void _emit(wt.LogLevel lvl, Object? msg, Object? err, StackTrace? stack) {
    wt.AppLogger.log(msg?.toString() ?? '',
        logLevel: lvl, tag: 'Music', error: err, stackTrace: stack);
  }
}

class AppLogger {
  static final _WtLogForwarder log = _WtLogForwarder();
  static late final File logFile;

  static void initialize(bool verbose) {}

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
    if (kReleaseMode) {
      try {
        await logFile.writeAsString(
          "[${DateTime.now()}]---------------------\n"
          "$error\n$stackTrace\n"
          "----------------------------------------\n",
          mode: FileMode.writeOnlyAppend,
        );
      } catch (_) {}
    }
  }

  static Future<File> getLogsPath() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    if (kIsAndroid) {
      dir = (await getExternalStorageDirectory())?.path ?? '';
    }
    if (kIsMacOS) {
      dir = join((await getLibraryDirectory()).path, 'Logs');
    }
    if (kIsLinux) {
      final home = Platform.environment['HOME'] ?? '';
      dir = join(home, '.local', 'state', 'spotube');
    }
    final file = File(join(dir, '.spotube_logs'));
    if (!await file.exists()) await file.create(recursive: true);
    logFile = file;
    return file;
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
