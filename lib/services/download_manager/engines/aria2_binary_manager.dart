import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

// Method channel provided by MainActivity for binary path resolution.
const _binaryUtilsChannelAria2 = MethodChannel('com.watchtower.app.binary_utils');

/// Manages the aria2c binary lifecycle.
///
/// Resolution order:
///   1. Public folder /storage/emulated/0/watchtower/bin/aria2c (user override)
///   2. User override at `Android/data/com.watchtower.app/files/aria2c`
///   3. Cached path from this session
///   4. Previously extracted binary in app support
///   5. Extract bundled asset `assets/binaries/aria2c` (if present at build time)
///   6. Auto-download from aria2/aria2 GitHub releases (silent, first use only)
class Aria2BinaryManager {
  static Aria2BinaryManager? _instance;
  static Aria2BinaryManager get instance =>
      _instance ??= Aria2BinaryManager._();
  Aria2BinaryManager._();

  String? _cachedPath;

  static const String _assetPath = 'assets/binaries/aria2c';
  static const String _binaryName = 'aria2c';

  Future<String?> resolveExecutable() async {
    // 1. Public folder /storage/emulated/0/watchtower/bin/aria2c
    if (!kIsWeb && Platform.isAndroid) {
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

    // 2. User override at external storage
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

    // 3. In-memory cache
    if (_cachedPath != null) {
      final cached = File(_cachedPath!);
      if (await cached.exists() && await cached.length() > 0) {
        return _cachedPath;
      }
    }

    // 4. Previously extracted binary in app support
    final internalPath = await _internalBinaryPath();
    final internalFile = File(internalPath);
    if (await internalFile.exists() && await internalFile.length() > 0) {
      await _ensureExecutable(internalFile);
      _cachedPath = internalPath;
      return internalPath;
    }

    // 5. Extract from bundled asset (present only when injected at CI build time)
    final fromAsset = await _extractFromAssets(internalPath);
    if (fromAsset != null) return fromAsset;

    // 6. Auto-download from aria2/aria2 GitHub Releases (silent, first use)
    return await _autoDownload(internalPath);
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
    } catch (_) {
      return null;
    }
  }

  /// Silent auto-download from the official aria2/aria2 GitHub releases.
  /// Picks the best asset for the current device ABI.
  /// Returns null (gracefully) if network is unavailable or no match found.
  Future<String?> _autoDownload(String targetPath) async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      return null;
    }
    try {
      AppLogger.log(
        'aria2c not found locally — attempting auto-download',
        tag: LogTag.download,
      );
      final res = await http
          .get(Uri.parse(
              'https://api.github.com/repos/aria2/aria2/releases/latest'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawAssets = (data['assets'] as List?) ?? const [];
      final abiTokens = await _abiTokens();

      // Look for a raw binary matching the current platform + ABI.
      // Exclude archives (.tar, .bz2, .gz, .zip) — we cannot extract them here.
      final candidates = rawAssets
          .whereType<Map<String, dynamic>>()
          .where((a) {
            final name = (a['name'] ?? '').toString().toLowerCase();
            if (name.endsWith('.sha256')) return false;
            if (name.endsWith('.tar.bz2') ||
                name.endsWith('.tar.gz') ||
                name.endsWith('.zip')) return false;
            if (!kIsWeb && Platform.isAndroid && !name.contains('android')) {
              return false;
            }
            if (abiTokens.isEmpty) return true;
            return abiTokens.any((tok) => name.contains(tok));
          })
          .toList();

      if (candidates.isEmpty) {
        AppLogger.log(
          'aria2c auto-download: no raw binary asset found for this ABI',
          logLevel: LogLevel.warning,
          tag: LogTag.download,
        );
        return null;
      }

      final url =
          (candidates.first['browser_download_url'] ?? '').toString();
      if (url.isEmpty) return null;

      AppLogger.log('aria2c auto-download → $url', tag: LogTag.download);
      final ok = await downloadFromUrl(url);
      if (!ok) return null;

      _cachedPath = targetPath;
      return targetPath;
    } catch (e) {
      AppLogger.log(
        'aria2c auto-download failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      return null;
    }
  }

  /// Detect ABI tokens for the current device to pick the right release asset.
  Future<List<String>> _abiTokens() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        final mapped = <String>[];
        for (final abi in info.supportedAbis) {
          final lower = abi.toLowerCase();
          mapped.add(lower);
          if (lower == 'arm64-v8a') {
            mapped.addAll(['arm64', 'aarch64', 'android-arm64']);
          } else if (lower == 'armeabi-v7a') {
            mapped.addAll(['armv7', 'arm', 'android-arm']);
          } else if (lower == 'x86_64') {
            mapped.addAll(['amd64', 'android-x86_64']);
          } else if (lower == 'x86') {
            mapped.addAll(['i386', 'i686', 'android-x86']);
          }
        }
        return mapped;
      } catch (_) {
        return ['arm64', 'aarch64'];
      }
    }
    if (!kIsWeb && Platform.isLinux) return ['linux', 'x86_64', 'amd64'];
    if (!kIsWeb && Platform.isMacOS) return ['darwin', 'macos'];
    return const [];
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
