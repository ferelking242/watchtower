import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

// Method channel provided by MainActivity — same as ZeusDlBinaryManager.
const _binaryUtilsChannelAria2 = MethodChannel('com.watchtower.app.binary_utils');

/// Manages the aria2c binary lifecycle.
///
/// Resolution order:
///   1. nativeLibraryDir/libaria2c.so — installed by PackageManager, always
///      exec-capable on all Android versions (no SELinux restriction).
///      Will exist once aria2c is packaged in jniLibs/ of the APK.
///   2. Public folder /storage/emulated/0/watchtower/bin/aria2c (user override)
///   3. User override at `Android/data/com.watchtower.app/files/aria2c`
///   4. Cached path from this session
///   5. Previously extracted binary in app support
///   6. Extract bundled asset `assets/binaries/aria2c` (if present)
class Aria2BinaryManager {
  static Aria2BinaryManager? _instance;
  static Aria2BinaryManager get instance =>
      _instance ??= Aria2BinaryManager._();
  Aria2BinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/aria2c';
  static const String _binaryName = 'aria2c';

  Future<String?> resolveExecutable() async {
    // 1. nativeLibraryDir — canonical exec-capable location used by
    //    youtubedl-android, Seal, ytdlnis for all compiled ELF binaries.
    if (Platform.isAndroid) {
      try {
        final nativeDir = await _binaryUtilsChannelAria2
            .invokeMethod<String>('getNativeLibraryDir');
        if (nativeDir != null && nativeDir.isNotEmpty) {
          final nativeFile = File('$nativeDir/libaria2c.so');
          if (await nativeFile.exists() && await nativeFile.length() > 0) {
            _cachedPath = nativeFile.path;
            AppLogger.log(
              'aria2c: using nativeLibraryDir binary at ${nativeFile.path}',
              logLevel: LogLevel.debug,
              tag: LogTag.download,
            );
            return nativeFile.path;
          }
        }
      } catch (_) {}
    }

    // 2. Public folder /storage/emulated/0/watchtower/bin/aria2c
    if (Platform.isAndroid) {
      final publicFile = File('/storage/emulated/0/watchtower/bin/$_binaryName');
      if (await publicFile.exists() && await publicFile.length() > 0) {
        await _ensureExecutable(publicFile);
        AppLogger.log(
          'Using public-folder aria2 binary: ${publicFile.path}',
          tag: LogTag.download,
        );
        _cachedPath = publicFile.path;
        return publicFile.path;
      }
    }

    final userOverride = await _userOverridePath();
    if (userOverride != null) {
      final file = File(userOverride);
      if (await file.exists() && await file.length() > 0) {
        await _ensureExecutable(file);
        AppLogger.log(
          'Using user-provided aria2 binary: $userOverride',
          tag: LogTag.download,
        );
        return userOverride;
      }
    }

    if (_cachedPath != null) {
      final cached = File(_cachedPath!);
      if (await cached.exists() && await cached.length() > 0) {
        return _cachedPath;
      }
    }

    final internalPath = await _internalBinaryPath();
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
      if (bytes.isEmpty) {
        AppLogger.log(
          'aria2 asset is empty — binary was not bundled at build time.',
          logLevel: LogLevel.warning,
          tag: LogTag.download,
        );
        return null;
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await _ensureExecutable(file);
      _cachedPath = targetPath;
      AppLogger.log(
        'aria2 extracted (${bytes.length} bytes) → $targetPath',
        tag: LogTag.download,
      );
      return targetPath;
    } catch (e, st) {
      AppLogger.log(
        'Failed to extract aria2 from assets',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _ensureExecutable(File file) async {
    if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['+x', file.path]);
      } catch (_) {}
    }
  }

  /// Always use internal app support dir — exec-capable on Android 10+.
  /// External storage (/storage/emulated/0/Android/data/…) is mounted noexec;
  /// exec() is blocked by the kernel even after chmod +x (exit code 126).
  Future<String> _internalBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/binaries/$_binaryName';
  }

  Future<String?> _userOverridePath() async {
    if (!Platform.isAndroid) return null;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;
      return '${dir.path}/$_binaryName';
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

  /// Download a binary from a remote URL and install it as the active
  /// internal aria2 binary. [onProgress] streams (received, total).
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
          'aria2 download failed (${res.statusCode}) — $url',
          logLevel: LogLevel.error,
          tag: LogTag.download,
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
      await _ensureExecutable(finalFile);
      _cachedPath = internalPath;
      AppLogger.log(
        'aria2 downloaded ($received bytes) → $internalPath',
        tag: LogTag.download,
      );
      return true;
    } catch (e, st) {
      AppLogger.log(
        'aria2 downloadFromUrl error',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> clearCache() async {
    _cachedPath = null;
    final p = await _internalBinaryPath();
    final f = File(p);
    if (await f.exists()) await f.delete();
  }

  /// Reset only the in-memory cache — does NOT delete the binary on disk.
  void resetCachedPath() {
    _cachedPath = null;
  }
}
