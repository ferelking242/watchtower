import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads and installs the optional MPV configuration bundle.
///
/// The archive is intentionally not a Flutter asset: shader files account for
/// more than a megabyte and are only needed when the user enables MPV
/// configuration. The immutable commit URL and digest make the deferred
/// download reproducible rather than tracking a moving branch.
class MpvConfigService {
  MpvConfigService._();

  static const archiveUrl =
      'https://raw.githubusercontent.com/ferelking242/watchtower/'
      '4a4ed4a53f907b1c4c9f54a8a6a656e62a8f1f8d/assets/watchtower_mpv.zip';
  static const archiveSha256 =
      'e832f935d06e1550eb7486bde667205365c41779f68d85aafc0acf2cfcb75a0c';

  static Future<void>? _activeInstall;

  static Future<void> ensureInstalled(Directory directory) async {
    final mpvConfig = File(p.join(directory.path, 'mpv.conf'));
    final inputConfig = File(p.join(directory.path, 'input.conf'));
    if (await mpvConfig.exists() && await inputConfig.exists()) return;
    await install(directory);
  }

  static Future<void> install(Directory directory) {
    final activeInstall = _activeInstall;
    if (activeInstall != null) return activeInstall;

    final installFuture = _install(directory);
    _activeInstall = installFuture;
    return installFuture.whenComplete(() {
      if (identical(_activeInstall, installFuture)) {
        _activeInstall = null;
      }
    });
  }

  static Future<void> _install(Directory directory) async {
    final staging = Directory(
      p.join(directory.path, '.watchtower_mpv_staging'),
    );
    final archiveFile = File(
      p.join(directory.path, '.watchtower_mpv.zip.part'),
    );
    final client = http.Client();

    try {
      await directory.create(recursive: true);
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archiveFile.exists()) await archiveFile.delete();

      final response = await client.send(
        http.Request('GET', Uri.parse(archiveUrl)),
      );
      if (response.statusCode != 200) {
        throw MpvConfigException(
          'MPV config download failed (${response.statusCode})',
        );
      }

      final bytes = await response.stream.toBytes();
      final digest = sha256.convert(bytes).toString();
      if (digest != archiveSha256) {
        throw MpvConfigException('MPV config checksum mismatch');
      }
      await archiveFile.writeAsBytes(bytes, flush: true);

      final archive = ZipDecoder().decodeBytes(bytes);
      await _extractAllowedFiles(archive, staging);
      await _copyStagedFiles(staging, directory);
    } finally {
      client.close();
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archiveFile.exists()) await archiveFile.delete();
    }
  }

  static Future<void> _extractAllowedFiles(
    Archive archive,
    Directory staging,
  ) async {
    for (final file in archive.files) {
      final relativePath = file.name.replaceAll('\\', '/');
      if (!_isAllowed(relativePath)) continue;

      final output = File(p.join(staging.path, relativePath));
      await output.parent.create(recursive: true);
      await output.writeAsBytes(file.content, flush: true);
    }
  }

  static bool _isAllowed(String relativePath) {
    if (relativePath == 'mpv.conf' || relativePath == 'input.conf') {
      return true;
    }
    if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
      return false;
    }
    return (relativePath.startsWith('shaders/') &&
            relativePath.endsWith('.glsl')) ||
        (relativePath.startsWith('scripts/') &&
            (relativePath.endsWith('.js') || relativePath.endsWith('.lua')));
  }

  static Future<void> _copyStagedFiles(
    Directory staging,
    Directory destination,
  ) async {
    if (!await staging.exists()) {
      throw MpvConfigException('MPV config archive contains no supported files');
    }

    var copied = 0;
    await for (final entity in staging.list(recursive: true)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: staging.path);
      final destinationFile = File(p.join(destination.path, relativePath));
      await destinationFile.parent.create(recursive: true);
      await entity.copy(destinationFile.path);
      copied++;
    }
    if (copied == 0) {
      throw MpvConfigException('MPV config archive contains no supported files');
    }
  }
}

class MpvConfigException implements Exception {
  final String message;
  const MpvConfigException(this.message);

  @override
  String toString() => message;
}