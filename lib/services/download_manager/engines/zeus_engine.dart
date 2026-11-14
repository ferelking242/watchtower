import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/zeus_runtime.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/utils/log/logger.dart';

/// ZeusDL engine — runs a plugin's Python extractor (yt-dlp-style) through the
/// bundled Python runtime to resolve and download media that is not a plain
/// file URL: TikTok, Facebook, Instagram reels, etc.
///
/// Where [Aria2Engine] and the internal HLS downloader expect a media URL the
/// app already knows, ZeusDL starts from a *page* URL and lets the script find
/// the media. Progress is read from the script's stdout protocol
/// ([ZeusProtocol]).
class ZeusEngine implements DownloadEngine {
  final String url;
  final String outputPath;
  final Map<String, String> headers;
  final ItemType itemType;
  final String chapterId;

  /// Plugin id used for `WT_PLUGIN_ID` and the log line, e.g. `en.tiktok-downloader`.
  final String pluginId;

  /// Action id (`download`) forwarded as `WT_ACTION`.
  final String action;

  /// Extractor options (quality, watermark, audio-only, …).
  final ZeusParams params;

  /// Optional plugin script (`scripts/main.py`) to run. When null the bundled
  /// `zeusdl/__main__.py` runtime entry point is used instead.
  final String? pluginScriptPath;

  /// Hard ceiling so a stalled extractor cannot pin the queue forever.
  final Duration totalTimeout;

  Process? _process;
  bool _cancelled = false;

  ZeusEngine({
    required this.url,
    required this.outputPath,
    required this.headers,
    required this.itemType,
    required this.chapterId,
    this.pluginId = 'en.media-downloader',
    this.action = 'download',
    this.pluginScriptPath,
    ZeusParams? params,
    this.totalTimeout = const Duration(minutes: 30),
  }) : params = params ?? ZeusParams(url: url);

  @override
  String get engineId => 'zeus';

  @override
  String get engineName => 'ZeusDL';

  /// ZeusDL drives a single process and reports percentage progress; it does not
  /// expose a pause/resume protocol.
  @override
  bool get supportsPause => false;

  @override
  Future<void> start(void Function(DownloadProgress) onProgress) async {
    _cancelled = false;

    final runtimeScript = await ZeusBinaryManager.instance.resolveRuntime();
    if (runtimeScript == null) {
      throw DownloadEngineException(
        'ZeusDL runtime not available. Install it from '
        'Settings > Avancé > Binaires, or ensure the bundled zeusdl.zip asset '
        'is present.',
        null,
        false,
      );
    }

    final python = await ZeusBinaryManager.instance.pythonExecutable();
    if (python == null) {
      throw DownloadEngineException(
        'Bundled Python (libpython) not found in nativeLibraryDir. ZeusDL '
        'cannot run on this build.',
        null,
        false,
      );
    }

    // A plugin ships its own `scripts/main.py`; otherwise run the runtime entry.
    final scriptPath = pluginScriptPath ?? runtimeScript;
    final runtimeDir = await ZeusBinaryManager.instance.runtimeDir();

    final outFile = File(outputPath);
    final outDir = outFile.parent.path;
    await outFile.parent.create(recursive: true);
    final cacheDir = '${outFile.parent.path}/.zeus_cache';

    final args = ZeusInvocation.buildArguments(
      scriptPath: scriptPath,
      params: params,
    );
    final env = ZeusInvocation.buildEnvironment(
      pluginId: pluginId,
      downloadDir: outDir,
      cacheDir: cacheDir,
      action: action,
      runtimeDir: runtimeDir.path,
      extra: {
        // The script writes the final file here so the caller can promote it.
        'WT_OUTPUT_PATH': outputPath,
        if (headers.isNotEmpty) 'WT_HEADERS': jsonEncode(headers),
      },
    );

    AppLogger.log(
      'ZeusDL start | plugin=$pluginId | chapter=$chapterId | '
      'host=${Uri.tryParse(url)?.host ?? "unknown"}',
      tag: LogTag.download,
    );

    onProgress(DownloadProgress(0, 100, itemType));

    var lastPercent = 0;

    _process = await Process.start(python, args, environment: env);
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final event = ZeusProtocol.parseLine(line);
      if (event == null) return;
      switch (event.type) {
        case ZeusEventType.progress:
          lastPercent = event.percent ?? lastPercent;
          onProgress(DownloadProgress(lastPercent, 100, itemType));
          break;
        case ZeusEventType.done:
          onProgress(
            DownloadProgress(100, 100, itemType, isCompleted: true),
          );
          break;
        case ZeusEventType.error:
          AppLogger.log(
            'ZeusDL ERROR | chapter=$chapterId | ${event.payload}',
            logLevel: LogLevel.error,
            tag: LogTag.download,
          );
          break;
        case ZeusEventType.status:
        case ZeusEventType.log:
          AppLogger.log(
            'ZeusDL[${event.type.name}] | chapter=$chapterId | ${event.payload}',
            tag: LogTag.download,
          );
          break;
      }
    });
    // Drain stderr so the pipe never fills and deadlocks the child.
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isEmpty) return;
      AppLogger.log(
        'ZeusDL[stderr] | chapter=$chapterId | $line',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
    });

    final exitCode = await _process!.exitCode.timeout(
      totalTimeout,
      onTimeout: () {
        _process?.kill();
        return -1;
      },
    );

    if (_cancelled) {
      throw DownloadEngineException('ZeusDL download cancelled', null, false);
    }

    if (exitCode != 0) {
      throw DownloadEngineException(
        'ZeusDL exited with code $exitCode',
        null,
        true,
      );
    }

    // Promote `.part` outputs the script may have written, and verify a file
    // actually landed where the queue expects it.
    if (!await outFile.exists() || await outFile.length() == 0) {
      final part = File('$outputPath.part');
      if (await part.exists() && await part.length() > 0) {
        await part.rename(outputPath);
      }
    }

    if (!await outFile.exists() || await outFile.length() == 0) {
      throw DownloadEngineException(
        'ZeusDL finished but produced no file at $outputPath',
        null,
        false,
      );
    }

    AppLogger.log(
      'ZeusDL completed | chapter=$chapterId | bytes=${await outFile.length()}',
      tag: LogTag.download,
    );
    onProgress(DownloadProgress(100, 100, itemType, isCompleted: true));
  }

  @override
  Future<void> pause() async {
    // Not supported: the extractor runs to completion. Reported via supportsPause.
  }

  @override
  Future<void> resume() async {
    // Not supported: the extractor runs to completion.
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final process = _process;
    if (process != null) {
      try {
        process.kill();
      } catch (_) {}
    }
  }
}
