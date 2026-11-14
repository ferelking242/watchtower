import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

// Method channel provided by MainActivity for binary path resolution.
const _binaryUtilsChannelZeus = MethodChannel('com.watchtower.app.binary_utils');

/// A remote ZeusDL runtime package. Mirrors are tried in order so a single
/// GitHub outage cannot brick the downloader.
class ZeusRuntimeSource {
  final String url;

  /// Optional SHA-256 of the whole zip. When present the download is rejected
  /// unless it matches — this is the integrity gate for a self-updating binary.
  final String? sha256;

  const ZeusRuntimeSource({required this.url, this.sha256});
}

/// Manages the ZeusDL runtime lifecycle: **download, store, exec**.
///
/// ZeusDL is a Python runtime (bundled `yt-dlp`-style extractors) shipped as
/// `zeusdl.zip`. It is stored under the app-support directory (exec-capable on
/// Android 10+, unlike external storage which is mounted `noexec`) and run with
/// the bundled `libpython` from `nativeLibraryDir`.
///
/// Resolution order for the runtime script (`__main__.py`):
///   1. User override marker at `<support>/zeusdl/`
///   2. Previously extracted runtime (version marker matches, or stale-but-usable)
///   3. Bundled asset `assets/binaries/zeusdl.zip` (CI-injected, offline install)
///   4. Auto-download from [sources] (silent, first use only)
class ZeusBinaryManager {
  static ZeusBinaryManager? _instance;
  static ZeusBinaryManager get instance =>
      _instance ??= ZeusBinaryManager._();
  ZeusBinaryManager._();

  /// Bumped whenever a new runtime package ships. A mismatch with the on-disk
  /// marker triggers a background refresh (auto-update without reinstalling the
  /// APK).
  static const String runtimeVersion = '1.0.0';

  static const String _assetPath = 'assets/binaries/zeusdl.zip';
  static const String _entryName = '__main__.py';

  /// Ordered mirrors. The CI release asset is authoritative; the second entry
  /// is a raw-repo fallback so a missing release asset is not fatal.
  static const List<ZeusRuntimeSource> sources = [
    ZeusRuntimeSource(
      url: 'https://github.com/ferelking242/watchtower/releases/latest/download/zeusdl.zip',
    ),
    ZeusRuntimeSource(
      url: 'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/zeusdl.zip',
    ),
  ];

  String? _cachedScriptPath;
  bool _extractedThisSession = false;

  /// Directory holding the extracted runtime (`__main__.py` + packages).
  Future<Directory> runtimeDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/zeusdl');
  }

  Future<String> _versionMarkerPath() async =>
      '${(await runtimeDir()).path}/.version';

  /// No-network check used by the UI (onboarding, settings) so merely opening a
  /// screen never triggers traffic.
  Future<bool> isInstalled() async {
    final cached = _cachedScriptPath;
    if (cached != null) {
      final file = File(cached);
      if (await file.exists() && await file.length() > 0) return true;
    }
    final script = File(await _entryPath());
    return await script.exists() && await script.length() > 0;
  }

  Future<String> _entryPath() async =>
      '${(await runtimeDir()).path}/$_entryName';

  /// Returns the path to `__main__.py`, extracting or downloading as needed.
  Future<String?> resolveRuntime() async {
    // 1 & 2. Already installed on disk.
    final entry = await _entryPath();
    final entryFile = File(entry);
    if (await entryFile.exists() && await entryFile.length() > 0) {
      _cachedScriptPath = entry;
      return entry;
    }

    // 3. Bundled asset (present only when injected at CI build time).
    final fromAsset = await _extractFromAssets();
    if (fromAsset != null) return fromAsset;

    // 4. Auto-download from the mirrors.
    return await _autoDownload();
  }

  /// The Python interpreter that runs the script: the bundled `libpython`
  /// packaged as `libpython.so` in `nativeLibraryDir` (exec-capable, no SELinux
  /// restriction). Returns null on platforms that do not ship it.
  Future<String?> pythonExecutable() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final nativeDir = await _binaryUtilsChannelZeus
          .invokeMethod<String>('getNativeLibraryDir');
      if (nativeDir == null || nativeDir.isEmpty) return null;
      for (final name in const ['libpython.so', 'libpython3.so', 'python']) {
        final candidate = File('$nativeDir/$name');
        if (await candidate.exists()) return candidate.path;
      }
    } catch (_) {}
    return null;
  }

  /// Extracts a downloaded/asset zip into the runtime directory and writes the
  /// version marker. Throws [ZeusRuntimeException] when the package is invalid.
  Future<String> extractZipBytes(
    List<int> bytes, {
    String version = runtimeVersion,
  }) async {
    if (bytes.isEmpty) {
      throw const ZeusRuntimeException('ZeusDL package is empty');
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw ZeusRuntimeException('ZeusDL package is not a valid zip: $e');
    }

    final hasEntry = archive.files.any(
      (f) => f.isFile && (f.name == _entryName || f.name.endsWith('/$_entryName')),
    );
    if (!hasEntry) {
      throw const ZeusRuntimeException(
        'ZeusDL package is missing $_entryName — refusing to install',
      );
    }

    // Extract to a scratch dir, then swap it in so a failed/partial extract can
    // never leave a half-written runtime that fails at exec time.
    final dir = await runtimeDir();
    final staging = Directory('${dir.path}.staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final outPath = '${staging.path}/${file.name}';
      final out = File(outPath);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(file.content as List<int>, flush: true);
    }

    // Atomic-ish swap: remove old tree, move staging into place.
    if (await dir.exists()) await dir.delete(recursive: true);
    await staging.rename(dir.path);
    await File('${dir.path}/.version').writeAsString(version, flush: true);

    _cachedScriptPath = '${dir.path}/$_entryName';
    _extractedThisSession = true;
    AppLogger.log(
      'ZeusDL runtime installed (v$version) → ${dir.path}',
      tag: LogTag.download,
    );
    return _cachedScriptPath!;
  }

  /// Downloads [source] to a temp file, verifies integrity, then extracts it.
  /// [onProgress] streams (received, total).
  Future<bool> installFromSource(
    ZeusRuntimeSource source, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await runtimeDir();
      await dir.parent.create(recursive: true);
      final tmp = File('${dir.path}.zip.part');
      if (await tmp.exists()) await tmp.delete();

      final ok = await _downloadToFile(source.url, tmp, onProgress: onProgress);
      if (!ok) return false;

      final bytes = await tmp.readAsBytes();
      await tmp.delete().catchError((_) => tmp);

      if (source.sha256 != null) {
        final digest = sha256.convert(bytes).toString();
        if (digest.toLowerCase() != source.sha256!.toLowerCase()) {
          AppLogger.log(
            'ZeusDL download failed SHA-256 check (got $digest)',
            logLevel: LogLevel.error,
            tag: LogTag.download,
          );
          return false;
        }
      }

      await extractZipBytes(bytes);
      return true;
    } catch (e, st) {
      AppLogger.log(
        'ZeusDL installFromSource error',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Non-blocking auto-update: when the on-disk marker differs from
  /// [runtimeVersion], refresh the runtime in the background. Safe to call at
  /// startup — failures are logged and swallowed.
  Future<void> maybeAutoUpdate() async {
    try {
      if (!await isInstalled()) return;
      final marker = File(await _versionMarkerPath());
      final installed = (await marker.exists())
          ? (await marker.readAsString()).trim()
          : '';
      if (installed == runtimeVersion) return;
      AppLogger.log(
        'ZeusDL runtime $installed → $runtimeVersion, refreshing',
        tag: LogTag.download,
      );
      await _autoDownload();
    } catch (_) {}
  }

  Future<String?> _extractFromAssets() async {
    try {
      final ByteData data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) return null;
      AppLogger.log(
        'ZeusDL extracting bundled asset (${bytes.length} bytes)',
        tag: LogTag.download,
      );
      return await extractZipBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _autoDownload() async {
    if (kIsWeb) return null;
    for (final source in sources) {
      try {
        AppLogger.log('ZeusDL auto-download → ${source.url}', tag: LogTag.download);
        if (await installFromSource(source)) return _cachedScriptPath;
      } catch (_) {
        // try the next mirror
      }
    }
    AppLogger.log(
      'ZeusDL auto-download failed on all mirrors',
      logLevel: LogLevel.warning,
      tag: LogTag.download,
    );
    return null;
  }

  /// Streams [url] into [target], following redirects, via the app HTTP stack.
  Future<bool> _downloadToFile(
    String url,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    try {
      var uri = Uri.parse(url);
      for (var redirect = 0; redirect < 8; redirect++) {
        final req = http.Request('GET', uri)..followRedirects = false;
        final res = await client.send(req);
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final loc = res.headers['location'];
          if (loc == null) return false;
          await res.stream.drain<void>();
          uri = uri.resolve(loc);
          continue;
        }
        if (res.statusCode != 200) {
          AppLogger.log(
            'ZeusDL download HTTP ${res.statusCode} — $uri',
            logLevel: LogLevel.error,
            tag: LogTag.download,
          );
          return false;
        }
        await target.parent.create(recursive: true);
        final total = res.contentLength ?? 0;
        var received = 0;
        final sink = target.openWrite();
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
        await sink.close();
        return received > 0;
      }
      return false;
    } catch (e, st) {
      AppLogger.log(
        'ZeusDL download error',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Removes the installed runtime and any staging/partial files.
  Future<void> uninstall() async {
    _cachedScriptPath = null;
    _extractedThisSession = false;
    final dir = await runtimeDir();
    for (final path in [
      dir.path,
      '${dir.path}.staging',
      '${dir.path}.zip.part',
    ]) {
      final entity = FileSystemEntity.isDirectorySync(path)
          ? Directory(path)
          : File(path);
      if (entity.existsSync()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Reset only the in-memory path cache — does NOT delete anything on disk.
  void resetCachedPath() {
    _cachedScriptPath = null;
    _extractedThisSession = false;
  }

  /// True when the runtime was (re)extracted during this session — used by the
  /// settings screen to prompt a re-run.
  bool get extractedThisSession => _extractedThisSession;
}

/// Thrown when a ZeusDL package cannot be validated or installed.
class ZeusRuntimeException implements Exception {
  final String message;
  const ZeusRuntimeException(this.message);

  @override
  String toString() => 'ZeusRuntimeException: $message';
}
