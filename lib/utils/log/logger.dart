import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:path/path.dart' as path;

class AppLogger {
  static final _logQueue = StreamController<String>();
  static late File _logFile;
  static late IOSink _sink;
  static bool _initialized = false;

  static Future<void> init() async {
    final enabled = isar.settings.getSync(227)?.enableLogs ?? false;
    if (!enabled) return;
    final storage = StorageProvider();
    final directory = await storage.getDefaultDirectory();
    _logFile = File(path.join(directory!.path, 'logs.txt'));

    if (await _logFile.exists() && await _logFile.length() > 200 * 1024) {
      final backup = File(path.join(directory.path, 'logs.bak.txt'));
      if (await backup.exists()) await backup.delete();
      await _logFile.rename(backup.path);
    }

    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }

    _sink = _logFile.openWrite(mode: FileMode.append);
    _initialized = true;

    _logQueue.stream.listen((entry) {
      _sink.writeln(entry);
    });

    await _writeSessionHeader();
  }

  static Future<void> _writeSessionHeader() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.operatingSystem;
      final now = _timestamp();
      final header = '''
══════════════════════════════════════════
  WATCHTOWER SESSION STARTED
  Date   : $now
  Version: ${info.version} (build ${info.buildNumber})
  OS     : $platform
══════════════════════════════════════════''';
      _logQueue.add(header);
    } catch (_) {
      _logQueue.add('[${ _timestamp()}][INFO] Logger initialized');
    }
  }

  static void log(
    String message, {
    LogLevel logLevel = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_initialized) return;

    final tagPart = tag != null ? '[$tag] ' : '';
    final entry = StringBuffer(
      '[${_timestamp()}][${logLevel.label}] $tagPart$message',
    );

    if (error != null) {
      entry.write('\n  Error: $error');
    }

    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n');
      final limited = lines.take(12).join('\n  ');
      entry.write('\n  Stack:\n  $limited');
      if (lines.length > 12) {
        entry.write('\n  ... (${lines.length - 12} more lines hidden)');
      }
    }

    if (kDebugMode) debugPrint(entry.toString());
    _logQueue.add(entry.toString());
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static Future<void> dispose() async {
    if (!_initialized) return;
    await _logQueue.close();
    await _sink.flush();
    await _sink.close();
    _initialized = false;
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() => label;
}

abstract final class LogTag {
  static const extension_ = 'EXT';
  static const zeus = 'ZEUS';
  static const download = 'DL';
  static const network = 'NET';
  static const repo = 'REPO';
  static const ui = 'UI';
}
