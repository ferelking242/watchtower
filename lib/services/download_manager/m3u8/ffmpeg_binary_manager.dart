import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Resolves FFmpeg outside the APK.
///
/// Android builds deliberately do not ship an FFmpeg AAR or native codec
/// bundle. A verified executable can be installed into app-private storage by
/// the runtime installer, while desktop builds may use the system executable.
class FfmpegBinaryManager {
  FfmpegBinaryManager._();

  static final instance = FfmpegBinaryManager._();
  static const _binaryName = 'ffmpeg';
  String? _cachedPath;

  Future<bool> isInstalled() async => await resolveExecutable() != null;

  Future<String?> resolveExecutable() async {
    if (kIsWeb) return null;

    if (_cachedPath != null && await _works(_cachedPath!)) {
      return _cachedPath;
    }

    final internal = await _internalPath();
    if (await _works(internal)) {
      _cachedPath = internal;
      return internal;
    }

    // Android/iOS do not have a reliable system PATH for app processes.
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (await _works(_binaryName)) {
        _cachedPath = _binaryName;
        return _binaryName;
      }
    }
    return null;
  }

  /// Installs an immutable runtime asset after verifying its SHA-256 digest.
  ///
  /// The caller must provide an HTTPS URL and a digest published by the
  /// project release process. No unverified executable is ever activated.
  Future<String> installFromUrl(
    String url, {
    required String expectedSha256,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const FfmpegBinaryException('FFmpeg runtime is unavailable on web.');
    }
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      throw const FfmpegBinaryException('FFmpeg runtime URL must use HTTPS.');
    }

    final target = await _internalPath();
    final part = File('$target.part');
    await part.parent.create(recursive: true);
    if (await part.exists()) await part.delete();

    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw FfmpegBinaryException(
          'FFmpeg runtime download failed (${response.statusCode}).',
        );
      }
      final sink = part.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength ?? 0);
      }
      await sink.flush();
      await sink.close();

      final digest = sha256.convert(await part.readAsBytes()).toString();
      if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
        await part.delete();
        throw const FfmpegBinaryException(
          'FFmpeg runtime checksum verification failed.',
        );
      }

      final installed = File(target);
      if (await installed.exists()) await installed.delete();
      await part.rename(target);
      await _makeExecutable(installed);
      if (!await _works(target)) {
        throw const FfmpegBinaryException(
          'The verified FFmpeg runtime could not be executed on this device.',
        );
      }
      _cachedPath = target;
      return target;
    } finally {
      client.close();
      if (await part.exists()) await part.delete();
    }
  }

  Future<String> _internalPath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/binaries/$_binaryName';
  }

  Future<bool> _works(String executable) async {
    try {
      if (executable.contains('/') && !await File(executable).exists()) {
        return false;
      }
      final result = await Process.run(
        executable,
        const ['-version'],
      ).timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _makeExecutable(File file) async {
    if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['+x', file.path]);
    }
  }
}

class FfmpegBinaryException implements Exception {
  final String message;

  const FfmpegBinaryException(this.message);

  @override
  String toString() => message;
}