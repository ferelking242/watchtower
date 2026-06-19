import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

const _binaryUtilsChannel = MethodChannel('com.watchtower.app.binary_utils');

// ── ZeusDlExecutionContext ───────────────────────────────────────────────────

/// Execution context returned by [ZeusDlBinaryManager.resolveExecutionContext].
///
/// All platforms: native ELF (Android/Linux) or Mach-O (iOS/macOS) binary.
/// Assets path: `assets/binaries/zeusdl`
class ZeusDlExecutionContext {
  final String executable;
  final List<String> prependArgs;
  final Map<String, String> extraEnv;

  const ZeusDlExecutionContext({
    required this.executable,
    this.prependArgs = const [],
    this.extraEnv = const {},
  });
}

// ── ZeusDlBinaryManager ──────────────────────────────────────────────────────

/// Manages the ZeusDL native binary lifecycle.
///
/// All platforms use the native ELF/Mach-O binary from `assets/binaries/zeusdl`.
/// Android additionally checks jniLibs for `libzeusdl.so`.
class ZeusDlBinaryManager {
  static ZeusDlBinaryManager? _instance;
  static ZeusDlBinaryManager get instance =>
      _instance ??= ZeusDlBinaryManager._();
  ZeusDlBinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/zeusdl';
  static const String _binaryName = 'zeusdl';

  // ── Public API ────────────────────────────────────────────────────────────

  Future<ZeusDlExecutionContext?> resolveExecutionContext() async {
    if (Platform.isAndroid) return _resolveAndroidContext();
    if (Platform.isIOS) return _resolveIOSContext();
    final path = await resolveExecutable();
    if (path == null) return null;
    return ZeusDlExecutionContext(executable: path);
  }

  // ── Android: native binary ────────────────────────────────────────────────

  Future<ZeusDlExecutionContext?> _resolveAndroidContext() async {
    AppLogger.log('ZeusDL: résolution contexte Android (natif)',
        logLevel: LogLevel.info, tag: LogTag.zeus);
    final path = await resolveExecutable();
    if (path == null) {
      AppLogger.log('ZeusDL [ERREUR] aucun binaire natif disponible sur Android',
          logLevel: LogLevel.error, tag: LogTag.zeus);
      return null;
    }
    AppLogger.log('ZeusDL: binaire natif → $path',
        logLevel: LogLevel.info, tag: LogTag.zeus);
    return ZeusDlExecutionContext(executable: path);
  }

  // ── iOS: résolution du contexte d'exécution ───────────────────────────────
  //
  // Non-jailbreaké   : Process.start() interdit par le sandbox iOS → null.
  // Dopamine/rootless: binaires arm64 dans /var/jb exécutables si signés ldid.
  // Rooted (classic) : /usr/bin, /usr/local/bin accessibles directement.
  Future<ZeusDlExecutionContext?> _resolveIOSContext() async {
    AppLogger.log('ZeusDL iOS: résolution contexte',
        logLevel: LogLevel.info, tag: LogTag.zeus);

    // 1. AppDelegate channel: détection jailbreak + chemin yt-dlp
    try {
      final path = await _binaryUtilsChannel.invokeMethod<String?>('getYtDlpPath');
      if (path != null && path.isNotEmpty) {
        if (await File(path).exists()) {
          AppLogger.log('ZeusDL iOS → via AppDelegate: $path',
              logLevel: LogLevel.info, tag: LogTag.zeus);
          return ZeusDlExecutionContext(executable: path);
        }
      }
    } catch (e) {
      AppLogger.log('ZeusDL iOS: getYtDlpPath error: $e',
          logLevel: LogLevel.debug, tag: LogTag.zeus);
    }

    // 2. Chemins jailbreak connus
    const kJBPaths = <String>[
      '/var/jb/usr/local/bin/zeusdl',
      '/var/jb/usr/bin/zeusdl',
      '/var/jb/usr/local/bin/yt-dlp',
      '/var/jb/usr/bin/yt-dlp',
      '/usr/local/bin/zeusdl',
      '/usr/bin/zeusdl',
      '/usr/local/bin/yt-dlp',
      '/usr/bin/yt-dlp',
    ];
    for (final p in kJBPaths) {
      if (await File(p).exists()) {
        AppLogger.log('ZeusDL iOS → jailbreak path: $p',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return ZeusDlExecutionContext(executable: p);
      }
    }

    // 3. Binaire bundlé dans les assets (Mach-O arm64 apple-ios)
    final bundled = await _extractIOSBundledBinary();
    if (bundled != null) {
      AppLogger.log('ZeusDL iOS → asset extrait: $bundled',
          logLevel: LogLevel.info, tag: LogTag.zeus);
      return ZeusDlExecutionContext(executable: bundled);
    }

    AppLogger.log(
        'ZeusDL iOS: aucun binaire disponible (non-jailbreaké ou binaire absent)',
        logLevel: LogLevel.warning, tag: LogTag.zeus);
    return null;
  }

  Future<String?> _extractIOSBundledBinary() async {
    try {
      final supportDir = (await getApplicationSupportDirectory()).path;
      final destPath = '$supportDir/zeusdl';
      final dest = File(destPath);
      if (await dest.exists() && await dest.length() > 100000) return destPath;

      try {
        final data = await rootBundle.load(_assetPath);
        final bytes = data.buffer.asUint8List();
        if (bytes.length < 4) return null;
        final isMachO = (bytes[0] == 0xCE || bytes[0] == 0xCF) &&
                        bytes[1] == 0xFA && bytes[2] == 0xED && bytes[3] == 0xFE;
        final isFat = bytes[0] == 0xCA && bytes[1] == 0xFE &&
                      bytes[2] == 0xBA && bytes[3] == 0xBE;
        if (!isMachO && !isFat) {
          AppLogger.log(
            'ZeusDL iOS: asset non Mach-O (magic=${bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, "0")).join()})',
            logLevel: LogLevel.error, tag: LogTag.zeus);
          return null;
        }
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(bytes);
        try {
          await _binaryUtilsChannel.invokeMethod('chmod', {'path': destPath});
        } catch (_) {}
        AppLogger.log('ZeusDL iOS: asset extrait (${bytes.length} bytes)',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return destPath;
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // ── Universal binary resolution ───────────────────────────────────────────

  Future<String?> resolveExecutable() async {
    if (Platform.isAndroid) {
      try {
        final nativeDir = await _binaryUtilsChannel
            .invokeMethod<String>('getNativeLibraryDir');
        if (nativeDir != null && nativeDir.isNotEmpty) {
          final nativeFile = File('$nativeDir/libzeusdl.so');
          if (await nativeFile.exists() && await nativeFile.length() > 0) {
            _cachedPath = nativeFile.path;
            return nativeFile.path;
          }
        }
      } catch (_) {}
    }

    final internalPath = await _internalBinaryPath();

    if (_cachedPath != null) {
      final cached = File(_cachedPath!);
      if (await cached.exists() && await cached.length() > 0) {
        return _cachedPath;
      }
      _cachedPath = null;
    }

    final internalFile = File(internalPath);
    if (await internalFile.exists() && await internalFile.length() > 0) {
      await _ensureExecutable(internalFile);
      _cachedPath = internalPath;
      return internalPath;
    }

    return await _extractFromAssets(internalPath);
  }

  Future<String?> _extractFromAssets(String targetPath) async {
    try {
      final ByteData data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) return null;

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await _ensureExecutable(file);
      _cachedPath = targetPath;
      AppLogger.log('ZeusDL: extrait depuis assets ($targetPath)',
          tag: LogTag.zeus);
      return targetPath;
    } catch (e, st) {
      AppLogger.log('ZeusDL: extraction assets échouée',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
          error: e,
          stackTrace: st);
      return null;
    }
  }

  Future<void> _ensureExecutable(File file) async {
    if (Platform.isAndroid) {
      try {
        final ok = await _binaryUtilsChannel
            .invokeMethod<bool>('setExecutable', {'path': file.path});
        AppLogger.log(
            'ZeusDL: setExecutable=${ok ?? false} → ${file.path}',
            logLevel: ok == true ? LogLevel.debug : LogLevel.warning,
            tag: LogTag.zeus);
        return;
      } catch (e) {
        AppLogger.log('ZeusDL: setExecutable channel échoué: $e',
            logLevel: LogLevel.warning, tag: LogTag.zeus);
      }
      try {
        final r = await Process.run('/system/bin/chmod', ['+x', file.path]);
        if (r.exitCode != 0) {
          AppLogger.log(
              'ZeusDL: chmod échoué (${r.exitCode}): ${r.stderr}',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
        }
      } catch (e) {
        AppLogger.log('ZeusDL: chmod exception: $e',
            logLevel: LogLevel.warning, tag: LogTag.zeus);
      }
      return;
    }
    try {
      await Process.run('chmod', ['+x', file.path]);
    } catch (_) {}
  }

  Future<String> _internalBinaryPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/binaries/$_binaryName';
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/$_binaryName';
    }
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_binaryName.exe';
  }

  // ── Helpers for UI (binaries_section) ────────────────────────────────────

  Future<int?> getBundledBinarySize() async {
    try {
      final data = await rootBundle.load(_assetPath);
      return data.lengthInBytes;
    } catch (_) {
      return null;
    }
  }

  Future<String> userOverrideDisplayPath() async {
    if (!Platform.isAndroid) return 'N/A (Android only)';
    try {
      final dir = await getExternalStorageDirectory();
      return '${dir?.path ?? 'Android/data/com.watchtower.app/files'}/$_binaryName';
    } catch (_) {
      return 'Android/data/com.watchtower.app/files/$_binaryName';
    }
  }

  Future<bool> downloadFromUrl(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    AppLogger.log('ZeusDL: téléchargement depuis $url',
        logLevel: LogLevel.info, tag: LogTag.zeus);
    try {
      final internalPath = await _internalBinaryPath();
      final tmpFile = File('$internalPath.part');
      await tmpFile.parent.create(recursive: true);
      if (await tmpFile.exists()) await tmpFile.delete();

      final req = http.Request('GET', Uri.parse(url));
      final res = await http.Client().send(req);
      if (res.statusCode != 200) {
        AppLogger.log(
            'ZeusDL: téléchargement échoué HTTP ${res.statusCode} → $url',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return false;
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = tmpFile.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();

      final finalFile = File(internalPath);
      if (await finalFile.exists()) await finalFile.delete();
      await tmpFile.rename(internalPath);
      await _ensureExecutable(finalFile);
      _cachedPath = internalPath;
      AppLogger.log(
          'ZeusDL: téléchargement terminé ($received octets) → $internalPath',
          logLevel: LogLevel.info, tag: LogTag.zeus);
      return true;
    } catch (e, st) {
      AppLogger.log('ZeusDL: downloadFromUrl erreur',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
          error: e,
          stackTrace: st);
      return false;
    }
  }

  void resetCachedPath() {
    _cachedPath = null;
  }
}
