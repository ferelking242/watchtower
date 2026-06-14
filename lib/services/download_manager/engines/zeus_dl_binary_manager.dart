import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

// Method channel provided by MainActivity — used for reliable setExecutable()
// on Android (Java's File.setExecutable bypasses PATH/SELinux issues with chmod).
const _binaryUtilsChannel = MethodChannel('com.watchtower.app.binary_utils');

/// Execution context returned by [ZeusDlBinaryManager.resolveExecutionContext].
///
/// On Android the binary must be launched as:
///   executable  prependArgs  user_args
///
/// On Android:
///   executable = nativeLibraryDir/libzeusdl.so  (Nuitka standalone PIE, ET_DYN)
///   extraEnv   = {SSL_CERT_FILE: filesDir/certifi/cacert.pem}
///
/// Nuitka --standalone: binary runs DIRECTLY from nativeLibraryDir.
/// No --onefile bootstrap → no execv() on app_data_file → no SIGSEGV (139).
/// certifi.where() is patched to check SSL_CERT_FILE first; we extract the
/// bundled cacert.pem from assets to filesDir on first launch.
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

/// Manages the ZeusDL binary lifecycle.
///
/// Binary storage: internal app support directory ONLY.
/// External storage paths (Android/data/... and /storage/emulated/0/...) are
/// mounted noexec on Android 10+ — exec() returns EPERM (exit 126) even after
/// chmod +x. We never return an external path as an executable.
///
/// Execution: direct Process.start(binaryPath, args) — no sh wrapper.
class ZeusDlBinaryManager {
  static ZeusDlBinaryManager? _instance;
  static ZeusDlBinaryManager get instance =>
      _instance ??= ZeusDlBinaryManager._();
  ZeusDlBinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/zeusdl';
  static const String _binaryName = 'zeusdl';

  /// Resolves the full execution context needed to launch ZeusDL.
  ///
  /// On Android, libzeusdl.so is the Nuitka standalone PIE binary (ET_DYN).
  /// It lives in nativeLibraryDir which is always exec-capable.
  ///
  /// certifi.where() inside the compiled binary is patched to check SSL_CERT_FILE
  /// before any filesystem lookup.  We extract assets/certifi/cacert.pem to
  /// filesDir on first launch and pass the path via SSL_CERT_FILE so HTTPS works.
  Future<ZeusDlExecutionContext?> resolveExecutionContext() async {
    if (Platform.isAndroid) {
      try {
        final nativeDir = await _binaryUtilsChannel
            .invokeMethod<String>('getNativeLibraryDir');
        if (nativeDir != null && nativeDir.isNotEmpty) {
          final zeusdlBin = File('$nativeDir/libzeusdl.so');
          if (await zeusdlBin.exists() && await zeusdlBin.length() > 0) {
            AppLogger.log(
              'ZeusDL: nativeLibraryDir context → ${zeusdlBin.path}',
              logLevel: LogLevel.debug,
              tag: LogTag.zeus,
            );
            final certifiPath = await _ensureCertifiExtracted();
            return ZeusDlExecutionContext(
              executable: zeusdlBin.path,
              extraEnv: {
                if (certifiPath != null) 'SSL_CERT_FILE': certifiPath,
              },
            );
          }
        }
      } catch (e) {
        AppLogger.log(
          'ZeusDL: resolveExecutionContext error: $e',
          logLevel: LogLevel.warning,
          tag: LogTag.zeus,
        );
      }
    }

    // Non-Android or fallback: use the classic single-binary approach.
    final path = await resolveExecutable();
    if (path == null) return null;
    return ZeusDlExecutionContext(executable: path);
  }

  /// Extracts assets/certifi/cacert.pem to filesDir on first launch.
  ///
  /// Returns the absolute path so the caller can set SSL_CERT_FILE.
  /// The compiled certifi.where() checks SSL_CERT_FILE first (build-time patch).
  Future<String?> _ensureCertifiExtracted() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final certFile = File('${dir.path}/certifi/cacert.pem');
      if (await certFile.exists() && await certFile.length() > 0) {
        return certFile.path;
      }
      final data = await rootBundle.load('assets/certifi/cacert.pem');
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) {
        AppLogger.log(
          'ZeusDL: certifi asset empty — SSL may fail',
          logLevel: LogLevel.warning,
          tag: LogTag.zeus,
        );
        return null;
      }
      await certFile.parent.create(recursive: true);
      await certFile.writeAsBytes(bytes, flush: true);
      AppLogger.log(
        'ZeusDL: certifi extracted (${bytes.length} bytes) → ${certFile.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.zeus,
      );
      return certFile.path;
    } catch (e) {
      AppLogger.log(
        'ZeusDL: certifi extraction failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.zeus,
      );
      return null;
    }
  }

  /// Returns the path to the executable binary, or null if unavailable.
  ///
  /// Priority order:
  ///   1. nativeLibraryDir/libzeusdl.so — installed by PackageManager, always
  ///      exec-capable on all Android versions (no SELinux restriction).
  ///      Will exist once ZeusDL is packaged in jniLibs/ of the APK.
  ///   2. Cached path from this session (already resolved + chmod'd).
  ///   3. Internal support dir binary (downloaded via marketplace / user copy).
  ///      NOTE: on Android 10+ with strict SELinux (Samsung, MIUI, etc.) this
  ///      path may fail with EACCES on exec. Use Shizuku to work around it.
  ///   4. Extract from bundled assets (first run / reinstall, same caveat).
  Future<String?> resolveExecutable() async {
    // 1. nativeLibraryDir — canonical location used by youtubedl-android,
    //    Seal, ytdlnis for all compiled ELF binaries (libaria2c.so, libffmpeg.so…)
    if (Platform.isAndroid) {
      try {
        final nativeDir = await _binaryUtilsChannel
            .invokeMethod<String>('getNativeLibraryDir');
        if (nativeDir != null && nativeDir.isNotEmpty) {
          final nativeFile = File('$nativeDir/libzeusdl.so');
          if (await nativeFile.exists() && await nativeFile.length() > 0) {
            _cachedPath = nativeFile.path;
            AppLogger.log(
              'ZeusDL: using nativeLibraryDir binary at ${nativeFile.path}',
              logLevel: LogLevel.debug,
              tag: LogTag.zeus,
            );
            return nativeFile.path;
          }
        }
      } catch (_) {}
    }

    final internalPath = await _internalBinaryPath();

    // 2. Use cached path from this session.
    if (_cachedPath != null) {
      final cached = File(_cachedPath!);
      if (await cached.exists() && await cached.length() > 0) {
        return _cachedPath;
      }
      _cachedPath = null;
    }

    // 3. Check internal binary (downloaded via marketplace or user copy).
    final internalFile = File(internalPath);
    if (await internalFile.exists() && await internalFile.length() > 0) {
      await _ensureExecutable(internalFile);
      _cachedPath = internalPath;
      AppLogger.log(
        'ZeusDL: using installed binary at $internalPath',
        logLevel: LogLevel.debug,
        tag: LogTag.zeus,
      );
      return internalPath;
    }

    // 4. Extract from bundled assets (first run / reinstall).
    return await _extractFromAssets(internalPath);
  }

  Future<String?> _extractFromAssets(String targetPath) async {
    try {
      AppLogger.log(
        'ZeusDL: extracting from assets → $targetPath',
        tag: LogTag.zeus,
      );

      final ByteData data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List();

      if (bytes.isEmpty) {
        AppLogger.log(
          'ZeusDL asset is empty — binary was not bundled at build time.',
          logLevel: LogLevel.warning,
          tag: LogTag.zeus,
        );
        return null;
      }

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await _ensureExecutable(file);

      _cachedPath = targetPath;
      AppLogger.log(
        'ZeusDL extracted successfully (${bytes.length} bytes) → $targetPath',
        tag: LogTag.zeus,
      );
      return targetPath;
    } catch (e, st) {
      AppLogger.log(
        'ZeusDL: failed to extract from assets',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _ensureExecutable(File file) async {
    if (Platform.isAndroid) {
      // Prefer Java's File.setExecutable() via method channel — avoids PATH
      // lookup for chmod and is not blocked by SELinux on any device.
      try {
        final ok = await _binaryUtilsChannel.invokeMethod<bool>(
          'setExecutable', {'path': file.path},
        );
        AppLogger.log(
          'ZeusDL: setExecutable=${ok ?? false} for ${file.path}',
          logLevel: ok == true ? LogLevel.debug : LogLevel.warning,
          tag: LogTag.zeus,
        );
        return;
      } catch (e) {
        AppLogger.log(
          'ZeusDL: setExecutable channel failed ($e), falling back to chmod',
          logLevel: LogLevel.warning,
          tag: LogTag.zeus,
        );
      }
      // Fallback: call chmod with full path to avoid PATH issues.
      try {
        final r = await Process.run('/system/bin/chmod', ['+x', file.path]);
        if (r.exitCode != 0) {
          AppLogger.log(
            'ZeusDL: chmod failed (${r.exitCode}): ${r.stderr}',
            logLevel: LogLevel.warning,
            tag: LogTag.zeus,
          );
        }
      } catch (e) {
        AppLogger.log('ZeusDL: chmod exception: $e', logLevel: LogLevel.warning, tag: LogTag.zeus);
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['+x', file.path]);
      } catch (_) {}
    }
  }

  /// Internal app support dir — exec-capable on Android (not mounted noexec).
  Future<String> _internalBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/binaries/$_binaryName';
  }

  /// Returns the internal install path shown in the settings UI.
  Future<String> installedBinaryPath() => _internalBinaryPath();

  /// Destination path used when the user manually copies a binary via the
  /// file picker (about_screen). Always points to internal storage — external
  /// storage is noexec on Android 10+ and cannot be used to run binaries.
  Future<String> userOverrideDisplayPath() => _internalBinaryPath();

  /// Download a binary from [url] and install it as the active binary.
  /// [onProgress] receives (received, total) pairs while bytes stream in.
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
      if (res.statusCode != 200) {
        AppLogger.log(
          'ZeusDL download failed (${res.statusCode}) — $url',
          logLevel: LogLevel.error,
          tag: LogTag.zeus,
        );
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
      await _ensureExecutable(File(internalPath));
      _cachedPath = internalPath;
      AppLogger.log(
        'ZeusDL downloaded ($received bytes) → $internalPath',
        tag: LogTag.zeus,
      );
      return true;
    } catch (e, st) {
      AppLogger.log(
        'ZeusDL downloadFromUrl error',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Force re-extraction from assets (e.g. after an app update).
  Future<void> clearCache() async {
    _cachedPath = null;
    final internalPath = await _internalBinaryPath();
    final file = File(internalPath);
    if (await file.exists()) await file.delete();
  }

  /// Reset only the in-memory cache — does NOT delete the binary on disk.
  void resetCachedPath() {
    _cachedPath = null;
  }

  /// Check if the bundled asset is non-empty (build included the binary).
  Future<bool> isAssetBundled() async {
    try {
      final data = await rootBundle.load(_assetPath);
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

  /// Whether a user override binary exists (kept for backward compat).
  Future<bool> hasUserOverride() async => false;
}
