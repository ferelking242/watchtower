import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Aria2 engine — downloads via the aria2c binary (multi-connection HTTP/HTTPS,
/// FTP, BitTorrent, Metalink). Best for direct file URLs (mp4, mkv, segments).
///
/// Note: aria2c does not natively understand HLS playlists; for `.m3u8` URLs
/// the engine returns an explicit error so the caller can fall back to the
/// internal HLS downloader (which knows how to fetch and assemble segments).
class Aria2Engine implements DownloadEngine {
  final String url;
  final String outputPath;
  final Map<String, String> headers;
  final ItemType itemType;
  final String chapterId;
  final int connections;

  Process? _process;
  bool _paused = false;
  bool _cancelled = false;

  Aria2Engine({
    required this.url,
    required this.outputPath,
    required this.headers,
    required this.itemType,
    required this.chapterId,
    this.connections = 8,
  });

  @override
  String get engineId => 'aria2';

  @override
  String get engineName => 'Aria2';

  @override
  bool get supportsPause => true;

  @override
  Future<void> start(void Function(DownloadProgress) onProgress) async {
    _cancelled = false;
    _paused = false;

    if (url.contains('.m3u8') || url.contains('.m3u')) {
      AppLogger.log(
        'aria2 cannot handle HLS playlists directly — falling back required '
        '| chapter=$chapterId | url=$url',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      throw DownloadEngineException(
        'aria2 does not support HLS (.m3u8) directly. '
        'Falling back to internal HLS downloader.',
        null,
        true, // retryable / let caller fall back
      );
    }

    final exec = await Aria2BinaryManager.instance.resolveExecutable();
    if (exec == null) {
      AppLogger.log(
        'aria2c executable not found | chapter=$chapterId',
        logLevel: LogLevel.error,
        tag: LogTag.download,
      );
      throw DownloadEngineException(
        'aria2c binary not available. Place an aria2c binary at '
        'Android/data/com.watchtower.app/files/aria2c '
        'or use the "Update binaries" button in Settings > Avancé.',
        null,
        false,
      );
    }

    final outFile = File(outputPath);
    final dir = outFile.parent.path;
    final filename = outFile.uri.pathSegments.isNotEmpty
        ? outFile.uri.pathSegments.last
        : 'download.mp4';

    final args = <String>[
      '--dir=$dir',
      '--out=$filename',
      '--max-connection-per-server=$connections',
      '--split=$connections',
      '--min-split-size=1M',
      '--continue=true',
      '--auto-file-renaming=false',
      '--allow-overwrite=true',
      '--summary-interval=1',
      '--console-log-level=warn',
      '--show-console-readout=true',
    ];

    for (final entry in headers.entries) {
      args.add('--header=${entry.key}: ${entry.value}');
    }
    try {
      final uri = Uri.parse(url);
      args.add('--referer=${uri.scheme}://${uri.host}');
    } catch (_) {}

    args.add(url);

    AppLogger.log(
      'aria2 start | chapter=$chapterId | url=$url | dir=$dir',
      tag: LogTag.download,
    );
    if (kDebugMode) debugPrint('[Aria2] Args: ${args.join(' ')}');

    onProgress(DownloadProgress(0, 100, itemType));

    _process = await Process.start(exec, args);
    final completer = Completer<void>();
    int lastLogged = -1;

    final progressRegex = RegExp(r'\((\d+)%\)');
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = progressRegex.firstMatch(line);
      if (match != null) {
        final percent = int.tryParse(match.group(1)!);
        if (percent != null) {
          onProgress(DownloadProgress(percent, 100, itemType));
          final r = (percent / 10).floor() * 10;
          if (r > lastLogged) {
            lastLogged = r;
            AppLogger.log(
              'aria2 progress $r% | chapter=$chapterId',
              logLevel: LogLevel.debug,
              tag: LogTag.download,
            );
          }
        }
      }
    });

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isEmpty) return;
      AppLogger.log(
        'aria2 stderr: $line',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
    });

    _process!.exitCode.then((code) {
      if (completer.isCompleted) return;
      if (code == 0) {
        AppLogger.log(
          'aria2 completed | chapter=$chapterId | out=$outputPath',
          tag: LogTag.download,
        );
        onProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
        completer.complete();
      } else if (!_cancelled) {
        AppLogger.log(
          'aria2 exited with code $code | chapter=$chapterId',
          logLevel: LogLevel.error,
          tag: LogTag.download,
        );
        completer.completeError(
          DownloadEngineException('aria2 exited with code $code', null, true),
        );
      } else {
        completer.complete();
      }
    });

    return completer.future;
  }

  @override
  Future<void> pause() async {
    if (_process != null && !_paused) {
      _paused = true;
      AppLogger.log('aria2 paused | chapter=$chapterId', tag: LogTag.download);
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigstop);
      }
    }
  }

  @override
  Future<void> resume() async {
    if (_process != null && _paused) {
      _paused = false;
      AppLogger.log('aria2 resumed | chapter=$chapterId', tag: LogTag.download);
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        _process!.kill(ProcessSignal.sigcont);
      }
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    if (_paused && (Platform.isAndroid || Platform.isLinux || Platform.isMacOS)) {
      _process?.kill(ProcessSignal.sigcont);
    }
    _process?.kill();
    _process = null;
  }
}
