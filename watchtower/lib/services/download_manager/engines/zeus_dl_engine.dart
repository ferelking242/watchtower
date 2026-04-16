import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/models/manga.dart';

/// ZeusDL engine — delegates downloads to the ZeusDL Python backend.
///
/// ZeusDL is a fork of yt-dlp that specialises in:
///   • M3U8 / HLS streams with signed tokens
///   • Anti-bot protected sources
///   • Automatic retries with refreshed headers
///
/// This engine calls a local ZeusDL subprocess (if bundled) or the
/// app's API server acting as a ZeusDL proxy.
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

    // Build ZeusDL command arguments
    final args = _buildArgs();

    if (kDebugMode) {
      debugPrint('[ZeusDL] Starting download: $url');
      debugPrint('[ZeusDL] Args: ${args.join(' ')}');
    }

    try {
      await _runWithProcess(args, onProgress);
    } on DownloadEngineException {
      rethrow;
    } catch (e) {
      throw DownloadEngineException('ZeusDL failed', e, true);
    }
  }

  List<String> _buildArgs() {
    final args = <String>[
      '-o', outputPath,
      '--no-playlist',
      '--newline',
      '--progress',
      '--progress-template', '%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
    ];

    // Inject headers
    for (final entry in headers.entries) {
      args.addAll(['--add-header', '${entry.key}:${entry.value}']);
    }

    // Add Referer if available
    try {
      final uri = Uri.parse(url);
      args.addAll(['--referer', '${uri.scheme}://${uri.host}']);
    } catch (_) {}

    // Force protocol for m3u8
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
    final executable = await _findZeusDlExecutable();
    if (executable == null) {
      throw DownloadEngineException(
        'ZeusDL executable not found. Please ensure it is installed.',
        null,
        false,
      );
    }

    onProgress(DownloadProgress(0, 100, itemType));

    _process = await Process.start(executable, args);
    final completer = Completer<void>();

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _parseProgressLine(line, onProgress);
    });

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (kDebugMode) debugPrint('[ZeusDL stderr] $line');
    });

    _process!.exitCode.then((code) {
      if (!completer.isCompleted) {
        if (code == 0) {
          onProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
          completer.complete();
        } else if (!_cancelled) {
          completer.completeError(
            DownloadEngineException('ZeusDL exited with code $code', null, true),
          );
        } else {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  void _parseProgressLine(String line, void Function(DownloadProgress) onProgress) {
    // Format: "75.3%|1.23MiB/s|00:12"
    final parts = line.split('|');
    if (parts.isNotEmpty) {
      final percentStr = parts[0].trim().replaceAll('%', '');
      final percent = double.tryParse(percentStr);
      if (percent != null) {
        final completed = (percent / 100 * 100).round();
        onProgress(DownloadProgress(completed, 100, itemType));
      }
    }
  }

  Future<String?> _findZeusDlExecutable() async {
    // 1. Check for bundled zeusdl in app assets / documents
    const bundledNames = ['zeusdl', 'zeusdl.sh', 'yt-dlp'];
    for (final name in bundledNames) {
      try {
        final result = await Process.run('which', [name]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return name;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> pause() async {
    if (_process != null && !_paused) {
      _paused = true;
      if (Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigstop);
      }
    }
  }

  @override
  Future<void> resume() async {
    if (_process != null && _paused) {
      _paused = false;
      if (Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigcont);
      }
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _process?.kill();
    _process = null;
    await _controller.close();
  }
}
