import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/utils/log/logger.dart';

/// ZeusDL engine — delegates downloads to the ZeusDL binary (fork of yt-dlp).
///
/// ZeusDL specialises in:
///   • M3U8 / HLS streams with signed tokens
///   • Anti-bot protected sources
///   • Automatic retries with refreshed headers
///
/// The binary is bundled in app assets at build time and extracted to internal
/// storage on first use.  Users can also place a custom binary at:
///   Android/data/com.Watchtower.app/files/zeusdl
class ZeusDlEngine implements DownloadEngine {
  final String url;
  final String outputPath;
  final Map<String, String> headers;
  final ItemType itemType;
  final String chapterId;

  Process? _process;
  bool _paused = false;
  bool _cancelled = false;
  final _controller = StreamController<DownloadProgress>.broadcast();

  ZeusDlEngine({
    required this.url,
    required this.outputPath,
    required this.headers,
    required this.itemType,
    required this.chapterId,
  });

  @override
  String get engineId => 'zeus';

  @override
  String get engineName => 'ZeusDL';

  @override
  bool get supportsPause => true;

  @override
  Future<void> start(void Function(DownloadProgress) onProgress) async {
    _cancelled = false;
    _paused = false;

    final args = _buildArgs();

    AppLogger.log(
      'Starting download | chapter=$chapterId | url=$url',
      tag: LogTag.zeus,
    );

    if (kDebugMode) {
      debugPrint('[ZeusDL] Args: ${args.join(' ')}');
    }

    try {
      await _runWithProcess(args, onProgress);
    } on DownloadEngineException {
      rethrow;
    } catch (e, st) {
      AppLogger.log(
        'Unexpected error | chapter=$chapterId',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
        error: e,
        stackTrace: st,
      );
      throw DownloadEngineException('ZeusDL failed', e, true);
    }
  }

  List<String> _buildArgs() {
    final args = <String>[
      '-o', outputPath,
      '--no-playlist',
      '--newline',
      '--progress',
      '--progress-template',
      '%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
    ];

    for (final entry in headers.entries) {
      args.addAll(['--add-header', '${entry.key}:${entry.value}']);
    }

    try {
      final uri = Uri.parse(url);
      args.addAll(['--referer', '${uri.scheme}://${uri.host}']);
    } catch (_) {}

    if (url.contains('.m3u8') || url.contains('.m3u')) {
      args.addAll(['--hls-prefer-native', '--format', 'best']);
    }

    args.add(url);
    return args;
  }

  Future<void> _runWithProcess(
    List<String> args,
    void Function(DownloadProgress) onProgress,
  ) async {
    // Resolve the binary path using the binary manager
    final executable = await ZeusDlBinaryManager.instance.resolveExecutable();

    if (executable == null) {
      AppLogger.log(
        'ZeusDL executable not found | chapter=$chapterId',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
      );
      throw DownloadEngineException(
        'ZeusDL binary not available. '
        'Place a zeusdl binary at '
        'Android/data/com.Watchtower.app/files/zeusdl '
        'or reinstall the app to restore the bundled binary.',
        null,
        false,
      );
    }

    AppLogger.log(
      'Executable resolved: $executable | chapter=$chapterId',
      logLevel: LogLevel.debug,
      tag: LogTag.zeus,
    );

    onProgress(DownloadProgress(0, 100, itemType));

    _process = await Process.start(executable, args);
    final completer = Completer<void>();

    int lastLoggedPercent = -1;

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _parseProgressLine(line, onProgress, (percent) {
        final rounded = (percent / 10).floor() * 10;
        if (rounded > lastLoggedPercent) {
          lastLoggedPercent = rounded;
          AppLogger.log(
            'Progress $rounded% | chapter=$chapterId',
            logLevel: LogLevel.debug,
            tag: LogTag.zeus,
          );
        }
      });
    });

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isEmpty) return;
      AppLogger.log(
        'stderr: $line',
        logLevel: LogLevel.warning,
        tag: LogTag.zeus,
      );
      if (kDebugMode) debugPrint('[ZeusDL stderr] $line');
    });

    _process!.exitCode.then((code) {
      if (completer.isCompleted) return;
      if (code == 0) {
        AppLogger.log(
          'Completed | chapter=$chapterId | out=$outputPath',
          tag: LogTag.zeus,
        );
        onProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
        completer.complete();
      } else if (!_cancelled) {
        AppLogger.log(
          'Exited with code $code | chapter=$chapterId',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
        );
        completer.completeError(
          DownloadEngineException('ZeusDL exited with code $code', null, true),
        );
      } else {
        AppLogger.log(
          'Cancelled by user | chapter=$chapterId',
          tag: LogTag.zeus,
        );
        completer.complete();
      }
    });

    return completer.future;
  }

  void _parseProgressLine(
    String line,
    void Function(DownloadProgress) onProgress,
    void Function(double) onPercent,
  ) {
    final parts = line.split('|');
    if (parts.isNotEmpty) {
      final percentStr = parts[0].trim().replaceAll('%', '');
      final percent = double.tryParse(percentStr);
      if (percent != null) {
        final completed = (percent / 100 * 100).round();
        onProgress(DownloadProgress(completed, 100, itemType));
        onPercent(percent);
      }
    }
  }

  @override
  Future<void> pause() async {
    if (_process != null && !_paused) {
      _paused = true;
      AppLogger.log('Paused | chapter=$chapterId', tag: LogTag.zeus);
      // SIGSTOP works on Android (Linux kernel), macOS, and Linux
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigstop);
      }
    }
  }

  @override
  Future<void> resume() async {
    if (_process != null && _paused) {
      _paused = false;
      AppLogger.log('Resumed | chapter=$chapterId', tag: LogTag.zeus);
      // SIGCONT to resume a suspended process
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigcont);
      }
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    AppLogger.log('Cancel requested | chapter=$chapterId', tag: LogTag.zeus);
    if (_paused && (Platform.isAndroid || Platform.isLinux || Platform.isMacOS)) {
      // Resume first so the process can receive SIGTERM
      _process?.kill(ProcessSignal.sigcont);
    }
    _process?.kill();
    _process = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
