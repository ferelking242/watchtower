import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Manages the aria2c binary lifecycle.
///
/// Resolution order (mirrors [ZeusDlBinaryManager]):
///   1. User override at `Android/data/com.watchtower.app/files/aria2c`
///   2. Cached path from this session
///   3. Previously extracted binary in app support
///   4. Extract bundled asset `assets/binaries/aria2c` (if present)
class Aria2BinaryManager {
  static Aria2BinaryManager? _instance;
  static Aria2BinaryManager get instance =>
      _instance ??= Aria2BinaryManager._();
  Aria2BinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/aria2c';
  static const String _binaryName = 'aria2c';

  Future<String?> resolveExecutable() async {
    // 0. Public folder /storage/emulated/0/watchtower/bin/aria2c
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

  Future<void> clearCache() async {
    _cachedPath = null;
    final p = await _internalBinaryPath();
    final f = File(p);
    if (await f.exists()) await f.delete();
  }
}
