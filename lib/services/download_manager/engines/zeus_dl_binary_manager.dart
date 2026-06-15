import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

const _binaryUtilsChannel = MethodChannel('com.watchtower.app.binary_utils');

const _zeusReleaseApiUrl =
    'https://api.github.com/repos/ferelking242/zeusdl/releases/latest';

// ── Isolate helpers (top-level, required by compute()) ─────────────────────

class _ExtractArgs {
  final String zipPath;
  final String destDir;
  const _ExtractArgs(this.zipPath, this.destDir);
}

class _ExtractBytesArgs {
  final List<int> bytes;
  final String destDir;
  const _ExtractBytesArgs(this.bytes, this.destDir);
}

void _extractZip(_ExtractArgs args) {
  extractFileToDisk(args.zipPath, args.destDir);
}

void _extractZipBytes(_ExtractBytesArgs args) {
  final archive = ZipDecoder().decodeBytes(args.bytes);
  extractArchiveToDisk(archive, args.destDir);
}

// ───────────────────────────────────────────────────────────────────────────

/// Execution context returned by [ZeusDlBinaryManager.resolveExecutionContext].
///
/// Android (Python Bionic via youtubedl-android runtime):
///   executable  = nativeLibsDir/libpython.so     ← Python ARM64 Bionic, execv OK
///   prependArgs = [filesDir/zeusdl/__main__.py]   ← ZeusDL Python entry point
///   extraEnv    = {PYTHONHOME, LD_LIBRARY_PATH, SSL_CERT_FILE}
///
/// Desktop / fallback:
///   executable  = path/to/zeusdl binary
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

/// Manages the ZeusDL lifecycle.
///
/// Android — Python-based execution (no SIGSEGV, no SELinux block):
///   • libpython.so     (4 KB)  lives in nativeLibsDir → execv'd directly ✓
///   • libpython.zip.so (11 MB) lives in nativeLibsDir → unzipped to filesDir
///   • zeusdl.zip               bundled in assets + downloadable from GitHub
///
/// Update flow:
///   On each [resolveExecutionContext] call the manager checks GitHub for a
///   new ZeusDL release.  If one exists it downloads zeusdl.zip and re-extracts
///   it to filesDir — no APK reinstall needed.
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
    if (Platform.isAndroid) {
      return _resolveAndroidContext();
    }
    final path = await resolveExecutable();
    if (path == null) return null;
    return ZeusDlExecutionContext(executable: path);
  }

  // ── Android: Python Bionic execution ─────────────────────────────────────

  Future<ZeusDlExecutionContext?> _resolveAndroidContext() async {
    try {
      final nativeDir = await _binaryUtilsChannel
          .invokeMethod<String>('getNativeLibraryDir');
      if (nativeDir == null || nativeDir.isEmpty) {
        AppLogger.log('ZeusDL: nativeLibraryDir unavailable',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        throw Exception('DIAG-1: nativeLibraryDir vide — MethodChannel raté');
      }

      // Python interpreter — executed directly from nativeLibsDir (SELinux OK)
      final pythonBin = File('$nativeDir/libpython.so');
      if (!await pythonBin.exists() || await pythonBin.length() == 0) {
        AppLogger.log(
            'ZeusDL: libpython.so absent de nativeLibsDir — APK sans runtime Python?',
            logLevel: LogLevel.error,
            tag: LogTag.zeus);
        throw Exception('DIAG-2: libpython.so absent de $nativeDir');
      }

      final filesDir = (await getApplicationSupportDirectory()).path;

      // 1. Ensure Python stdlib extracted (libpython.zip.so → filesDir/packages/python)
      final pythonHome = await _ensurePythonExtracted(nativeDir, filesDir);
      if (pythonHome == null) throw Exception('DIAG-3: _ensurePythonExtracted a échoué');

      // 2. Ensure ZeusDL scripts present (download update if available)
      final mainPy = await _ensureZeusDlReady(filesDir);
      if (mainPy == null) throw Exception('DIAG-4: _ensureZeusDlReady a échoué (__main__.py introuvable)');

      AppLogger.log(
        'ZeusDL: context Python → ${pythonBin.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.zeus,
      );

      return ZeusDlExecutionContext(
        executable: pythonBin.path,
        prependArgs: [mainPy],
        extraEnv: {
          'PYTHONHOME': pythonHome,
          'LD_LIBRARY_PATH': '$pythonHome/lib',
          'SSL_CERT_FILE': '$pythonHome/etc/tls/cert.pem',
          'PYTHONDONTWRITEBYTECODE': '1',
          'PYTHONUNBUFFERED': '1',
        },
      );
    } catch (e, st) {
      AppLogger.log('ZeusDL: _resolveAndroidContext erreur: $e',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
          error: e,
          stackTrace: st);
      rethrow;
    }
  }

  /// Unzip libpython.zip.so (Python stdlib) from nativeLibsDir to filesDir.
  /// Returns PYTHONHOME = filesDir/packages/python/usr, or null on failure.
  /// Uses file size as version token (same approach as youtubedl-android).
  Future<String?> _ensurePythonExtracted(
      String nativeDir, String filesDir) async {
    final zipSo = File('$nativeDir/libpython.zip.so');
    if (!await zipSo.exists()) {
    if (!await zipSo.exists()) {
      final nativeDirContents = Directory(nativeDir).existsSync()
          ? Directory(nativeDir).listSync().map((e) => e.path.split('/').last).join(', ')
          : 'répertoire inaccessible';
      throw Exception('DIAG-3a: libpython.zip.so absent.\nContenu nativeDir: $nativeDirContents');
    }

    final pythonDir = Directory('$filesDir/packages/python');
    final versionFile = File('$filesDir/packages/python_size.txt');
    final currentSize = (await zipSo.length()).toString();

    if (await pythonDir.exists() && await versionFile.exists()) {
      final stored = (await versionFile.readAsString()).trim();
      if (stored == currentSize) {
        AppLogger.log('ZeusDL: Python stdlib déjà extrait ($currentSize bytes)',
            logLevel: LogLevel.debug, tag: LogTag.zeus);
        return '$filesDir/packages/python/usr';
      }
    }

    AppLogger.log(
        'ZeusDL: extraction Python stdlib (${zipSo.lengthSync()} bytes)…',
        logLevel: LogLevel.info,
        tag: LogTag.zeus);

    try {
      if (await pythonDir.exists()) await pythonDir.delete(recursive: true);
      await pythonDir.create(recursive: true);

      await compute(_extractZip,
          _ExtractArgs(zipSo.path, '$filesDir/packages/python'));

      await versionFile.parent.create(recursive: true);
      await versionFile.writeAsString(currentSize);

      AppLogger.log('ZeusDL: Python stdlib extrait → ${pythonDir.path}',
          logLevel: LogLevel.info, tag: LogTag.zeus);
      return '$filesDir/packages/python/usr';
    } catch (e, st) {
      AppLogger.log('ZeusDL: extraction Python échouée: $e',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
          error: e,
          stackTrace: st);
      rethrow;
    }
  }

  /// Ensures ZeusDL scripts are in filesDir/zeusdl/, downloading updates from
  /// GitHub if a newer release exists.  Falls back to the bundled asset.
  /// Returns path to __main__.py or null on failure.
  Future<String?> _ensureZeusDlReady(String filesDir) async {
    final zeusDir = Directory('$filesDir/zeusdl');
    final mainPy = File('$filesDir/zeusdl/__main__.py');
    final versionFile = File('$filesDir/zeusdl_version.txt');

    // Background update check (non-blocking for subsequent cold starts)
    await _tryUpdateZeusDl(filesDir, zeusDir, versionFile);

    if (await mainPy.exists()) return mainPy.path;

    // First run or update wiped the dir — extract from bundled asset
    AppLogger.log('ZeusDL: extraction depuis asset bundlé…',
        logLevel: LogLevel.info, tag: LogTag.zeus);
    try {
      final data = await rootBundle.load('assets/zeusdl/zeusdl.zip');
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) {
        AppLogger.log('ZeusDL: asset zeusdl.zip vide',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }
      if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
      await zeusDir.create(recursive: true);
      // Extract to filesDir/ → creates filesDir/zeusdl/__main__.py
      await compute(_extractZipBytes, _ExtractBytesArgs(bytes, filesDir));
      AppLogger.log('ZeusDL: extrait depuis asset → $filesDir',
          logLevel: LogLevel.info, tag: LogTag.zeus);
    } catch (e) {
      AppLogger.log('ZeusDL: extraction asset échouée: $e',
          logLevel: LogLevel.error, tag: LogTag.zeus);
      return null;
    }

    return await mainPy.exists() ? mainPy.path : null;
  }

  Future<void> _tryUpdateZeusDl(
      String filesDir, Directory zeusDir, File versionFile) async {
    try {
      final storedTag =
          await versionFile.exists() ? (await versionFile.readAsString()).trim() : '';

      final res = await http
          .get(Uri.parse(_zeusReleaseApiUrl),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final latestTag = (json['tag_name'] as String? ?? '').trim();
      if (latestTag.isEmpty || latestTag == storedTag) return;

      AppLogger.log('ZeusDL: mise à jour $storedTag → $latestTag',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      final assets = json['assets'] as List<dynamic>;
      String? downloadUrl;
      for (final a in assets) {
        if ((a['name'] as String).endsWith('zeusdl.zip')) {
          downloadUrl = a['browser_download_url'] as String;
          break;
        }
      }
      if (downloadUrl == null) {
        AppLogger.log('ZeusDL: pas de zeusdl.zip dans la release $latestTag',
            logLevel: LogLevel.warning, tag: LogTag.zeus);
        return;
      }

      final zipRes =
          await http.get(Uri.parse(downloadUrl)).timeout(const Duration(minutes: 3));
      if (zipRes.statusCode != 200) return;

      if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
      await zeusDir.create(recursive: true);
      await compute(
          _extractZipBytes, _ExtractBytesArgs(zipRes.bodyBytes, filesDir));

      await versionFile.parent.create(recursive: true);
      await versionFile.writeAsString(latestTag);
      AppLogger.log('ZeusDL: mis à jour vers $latestTag ✓',
          logLevel: LogLevel.info, tag: LogTag.zeus);
    } catch (e) {
      // Silently ignore — offline or GitHub down, use existing version
      AppLogger.log('ZeusDL: vérif mise à jour ignorée: $e',
          logLevel: LogLevel.debug, tag: LogTag.zeus);
    }
  }

  // ── Non-Android: classic binary approach ─────────────────────────────────

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
          AppLogger.log('ZeusDL: chmod échoué (${r.exitCode}): ${r.stderr}',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
        }
      } catch (e) {
        AppLogger.log('ZeusDL: chmod exception: $e',
            logLevel: LogLevel.warning, tag: LogTag.zeus);
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['+x', file.path]);
      } catch (_) {}
    }
  }

  Future<String> _internalBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/binaries/$_binaryName';
  }

  Future<String> installedBinaryPath() => _internalBinaryPath();
  Future<String> userOverrideDisplayPath() => _internalBinaryPath();

  Future<bool> downloadFromUrl(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final internalPath = await _internalBinaryPath();
      final tmpFile = File('$internalPath.part');
      await tmpFile.parent.create(recursive: true);
      if (await tmpFile.exists()) await tmpFile.delete();

      final req = http.Request('GET', Uri.parse(url));
      final res = await http.Client().send(req);
      if (res.statusCode != 200) return false;

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
      await _ensureExecutable(File(internalPath));
      _cachedPath = internalPath;
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

  Future<void> clearCache() async {
    _cachedPath = null;
    final internalPath = await _internalBinaryPath();
    final file = File(internalPath);
    if (await file.exists()) await file.delete();
  }

  void resetCachedPath() => _cachedPath = null;

  Future<bool> isAssetBundled() async {
    try {
      final data = await rootBundle.load(_assetPath);
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasUserOverride() async => false;
}
