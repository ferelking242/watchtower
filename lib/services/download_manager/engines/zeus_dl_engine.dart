import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:path_provider/path_provider.dart';
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
    // Resolve the execution context (executable + prepended args + extra env).
    // On Android this uses the musl-linker trick to avoid execv() on noexec
    // filesystems (Samsung Knox, MIUI strict mode, etc.):
    //   executable  = nativeLibraryDir/libmusl.so
    //   prependArgs = [nativeLibraryDir/libzeusdl.so]
    //   extraEnv    = {LD_PRELOAD: nativeLibraryDir/libz_zeusdl.so}
    // All three files live in nativeLibraryDir which is installed by
    // PackageManager with exec-capable SELinux context on ALL devices.
    final ctx = await ZeusDlBinaryManager.instance.resolveExecutionContext();

    if (ctx == null) {
      AppLogger.log(
        'ZeusDL executable not found | chapter=$chapterId',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
      );
      throw DownloadEngineException(
        'ZeusDL binary not available. '
        'Reinstall the app to restore the bundled binary '
        '(Android: Android/data/com.Watchtower.app/files/zeusdl, '
        'iOS: applicationSupportDirectory/zeusdl).',
        null,
        false,
      );
    }

    AppLogger.log(
      'Executable resolved: ${ctx.executable} | chapter=$chapterId',
      logLevel: LogLevel.debug,
      tag: LogTag.zeus,
    );

    onProgress(DownloadProgress(0, 100, itemType));

    // Build the process environment.
    // TMPDIR override: PyInstaller (inside the zeusdl binary) extracts Python
    // bytecode and native modules to $TMPDIR/_MEIxxxxxx/ at startup.
    // We point TMPDIR at the app support dir (not cacheDir) because:
    //   • cacheDir is noexec on Android 10+ (never use for TMPDIR).
    //   • supportDir/tmp is writable and on the same partition as filesDir.
    //   • PyInstaller uses dlopen() (not execv) for .so extraction, which is
    //     not blocked by the noexec mount flag or SELinux execute neverallow.
    // STATICX_TMPDIR is set as belt-and-suspenders for any staticx wrapper
    // that might still be in the fallback path (old APK installs).
    final Map<String, String> procEnv =
        Map<String, String>.from(Platform.environment);

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final tmpDir = Directory('${supportDir.path}/tmp');
        await tmpDir.create(recursive: true);
        procEnv['TMPDIR'] = tmpDir.path;
        procEnv['STATICX_TMPDIR'] = tmpDir.path;
        AppLogger.log(
          'ZeusDL: TMPDIR set to ${tmpDir.path}',
          logLevel: LogLevel.debug,
          tag: LogTag.zeus,
        );
      } catch (e) {
        AppLogger.log(
          'ZeusDL: TMPDIR override failed: $e',
          logLevel: LogLevel.warning,
          tag: LogTag.zeus,
        );
      }
    }

    // Apply any extra env from the execution context (e.g. LD_PRELOAD for musl libz).
    procEnv.addAll(ctx.extraEnv);

    // Build the full arg list: prependArgs (e.g. zeusdl binary path for musl)
    // followed by the actual download arguments.
    final fullArgs = [...ctx.prependArgs, ...args];

    if (kDebugMode) {
      debugPrint('[ZeusDL] exec: ${ctx.executable} ${fullArgs.join(' ')}');
    }

    _process = await Process.start(ctx.executable, fullArgs, environment: procEnv);
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
        // Exit code 3 (EPERM/EACCES from execv): staticx or PyInstaller tried
        // to exec a binary from a noexec filesystem (Samsung Knox).
        // This should not happen with the musl-linker approach, but log clearly
        // if it does so the user can report it.
        final hint = (code == 3)
            ? ' [HINT: execv() permission denied — device may block exec from '
              'app data dir. Ensure APK is up to date with musl-linker fix.]'
            : '';
        AppLogger.log(
          'Exited with code $code$hint | chapter=$chapterId',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
        );
        completer.completeError(
          DownloadEngineException(
            code == 3
                ? 'Erreur (code $code) : Permission refusée lors de '
                    "l'exécution du binaire.\n"
                    'Cause probable : SELinux bloque exec() sur ce '
                    'appareil (Samsung Knox / MIUI strict).\n'
                    "Mettez à jour l'application pour utiliser la "
                    'dernière version corrigée.'
                : 'ZeusDL exited with code $code',
            null,
            true,
          ),
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
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS || Platform.isIOS) {
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
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS || Platform.isIOS) {
        _process!.kill(ProcessSignal.sigcont);
      }
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    AppLogger.log('Cancel requested | chapter=$chapterId', tag: LogTag.zeus);
    if (_paused && (Platform.isAndroid || Platform.isLinux || Platform.isMacOS || Platform.isIOS)) {
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
