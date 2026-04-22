import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Manages the ZeusDL binary lifecycle:
///   1. Check user-replaceable binary (external storage — accessible via file manager)
///   2. Check already-extracted internal binary (skip re-extraction)
///   3. Extract from Flutter assets if needed and mark as executable
///
/// On Android, the user can place their own binary at:
///   Android/data/com.Watchtower.app/files/zeusdl
/// (visible with any file manager that shows app-specific folders)
class ZeusDlBinaryManager {
  static ZeusDlBinaryManager? _instance;
  static ZeusDlBinaryManager get instance =>
      _instance ??= ZeusDlBinaryManager._();
  ZeusDlBinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/zeusdl';
  static const String _binaryName = 'zeusdl';

  /// Returns the resolved executable path, or null if unavailable.
  /// Checks in order:
  ///   1. User override in external files dir (file manager accessible)
  ///   2. Previously extracted internal binary
  ///   3. Extract from assets (first run)
  Future<String?> resolveExecutable() async {
    // 0. Public folder /storage/emulated/0/watchtower/bin/zeusdl
    if (Platform.isAndroid) {
      final publicFile = File('/storage/emulated/0/watchtower/bin/$_binaryName');
      if (await publicFile.exists() && await publicFile.length() > 0) {
        await _ensureExecutable(publicFile);
        AppLogger.log(
          'Using public-folder ZeusDL binary: ${publicFile.path}',
          tag: LogTag.zeus,
        );
        _cachedPath = publicFile.path;
        return publicFile.path;
      }
    }
    // 1. Check user override (external files dir — accessible via file manager)
    final userOverride = await _userOverridePath();
    if (userOverride != null) {
      final file = File(userOverride);
      if (await file.exists() && await file.length() > 0) {
        await _ensureExecutable(file);
        AppLogger.log(
          'Using user-provided ZeusDL binary: $userOverride',
          tag: LogTag.zeus,
        );
        return userOverride;
      }
    }

    // 2. Use cached path (already extracted this session)
    if (_cachedPath != null) {
      final cached = File(_cachedPath!);
      if (await cached.exists() && await cached.length() > 0) {
        return _cachedPath;
      }
    }

    // 3. Check internal binary (extracted in a previous app launch)
    final internalPath = await _internalBinaryPath();
    final internalFile = File(internalPath);
    if (await internalFile.exists() && await internalFile.length() > 0) {
      await _ensureExecutable(internalFile);
      _cachedPath = internalPath;
      AppLogger.log(
        'Using previously extracted ZeusDL binary: $internalPath',
        logLevel: LogLevel.debug,
        tag: LogTag.zeus,
      );
      return internalPath;
    }

    // 4. Extract from bundled assets
    return await _extractFromAssets(internalPath);
  }

  Future<String?> _extractFromAssets(String targetPath) async {
    try {
      AppLogger.log(
        'Extracting ZeusDL binary from assets → $targetPath',
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
        'ZeusDL extracted successfully (${bytes.length} bytes)',
        tag: LogTag.zeus,
      );
      return targetPath;
    } catch (e, st) {
      AppLogger.log(
        'Failed to extract ZeusDL from assets',
        logLevel: LogLevel.error,
        tag: LogTag.zeus,
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

  /// Internal path: app-private storage (not accessible by user directly)
  Future<String> _internalBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/binaries/$_binaryName';
  }

  /// External path: accessible via file manager under
  /// Android/data/com.Watchtower.app/files/zeusdl
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

  /// Returns the user-facing path where they can drop a custom binary.
  /// Shown in the settings UI.
  Future<String> userOverrideDisplayPath() async {
    if (!Platform.isAndroid) return 'N/A (Android only)';
    try {
      final dir = await getExternalStorageDirectory();
      return '${dir?.path ?? 'Android/data/com.Watchtower.app/files'}/$_binaryName';
    } catch (_) {
      return 'Android/data/com.Watchtower.app/files/$_binaryName';
    }
  }

  /// Download a binary from a remote URL and install it as the active
  /// internal binary (replacing any cached/extracted copy). [onProgress]
  /// receives (received, total) pairs while bytes stream in.
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
      await _ensureExecutable(finalFile);
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
    if (await file.exists()) {
      await file.delete();
    }
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

  /// Whether a user override binary exists.
  Future<bool> hasUserOverride() async {
    final path = await _userOverridePath();
    if (path == null) return false;
    return File(path).existsSync();
  }
}
