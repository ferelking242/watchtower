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

  // ── Result type for internal steps ─────────────────────────────────────────

  /// Wraps either a success value [T] or an error [message].
  class _Result<T> {
    final T? value;
    final String? error;
    const _Result.ok(this.value) : error = null;
    const _Result.fail(this.error) : value = null;
    bool get isOk => error == null;
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
      AppLogger.log('ZeusDL: démarrage résolution contexte Android',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      // ── Étape 1 : nativeLibraryDir ──────────────────────────────────────────
      final String nativeDir;
      try {
        final result = await _binaryUtilsChannel
            .invokeMethod<String>('getNativeLibraryDir');
        if (result == null || result.isEmpty) {
          AppLogger.log(
              'ZeusDL [ERREUR] nativeLibraryDir vide — MethodChannel sans réponse',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return null;
        }
        nativeDir = result;
        AppLogger.log('ZeusDL [1/4] nativeDir = $nativeDir',
            logLevel: LogLevel.debug, tag: LogTag.zeus);
      } catch (e, st) {
        AppLogger.log('ZeusDL [ERREUR] getNativeLibraryDir a lancé une exception',
            logLevel: LogLevel.error, tag: LogTag.zeus, error: e, stackTrace: st);
        return null;
      }

      // ── Étape 2 : libpython.so ──────────────────────────────────────────────
      final pythonBin = File('$nativeDir/libpython.so');
      final pythonBinExists = await pythonBin.exists();
      final pythonBinSize = pythonBinExists ? await pythonBin.length() : 0;
      AppLogger.log(
          'ZeusDL [2/4] libpython.so — existe=$pythonBinExists taille=${pythonBinSize}B',
          logLevel: pythonBinExists && pythonBinSize > 0
              ? LogLevel.info
              : LogLevel.error,
          tag: LogTag.zeus);
      if (!pythonBinExists || pythonBinSize == 0) {
        AppLogger.log(
            'ZeusDL [ERREUR] libpython.so absent ou vide dans $nativeDir — APK mal assemblé',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }

      // ── Étape 3 : Python stdlib (libpython.zip.so → filesDir) ───────────────
      final filesDir = (await getApplicationSupportDirectory()).path;
      AppLogger.log('ZeusDL [3/4] filesDir = $filesDir',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      final stdlibResult = await _ensurePythonStdlib(nativeDir, filesDir);
      if (!stdlibResult.isOk) {
        AppLogger.log(
            'ZeusDL [ERREUR] Python stdlib indisponible : ${stdlibResult.error}',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }
      final pythonHome = stdlibResult.value!;
      AppLogger.log('ZeusDL [3/4] PYTHONHOME = $pythonHome',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      // ── Étape 4 : scripts ZeusDL (__main__.py) ──────────────────────────────
      final scriptResult = await _ensureZeusDlScripts(filesDir);
      if (!scriptResult.isOk) {
        AppLogger.log(
            'ZeusDL [ERREUR] scripts ZeusDL indisponibles : ${scriptResult.error}',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }
      final mainPy = scriptResult.value!;
      AppLogger.log('ZeusDL [4/4] __main__.py = $mainPy',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      AppLogger.log(
          'ZeusDL ✓ contexte prêt — ${pythonBin.path} $mainPy',
          logLevel: LogLevel.info, tag: LogTag.zeus);

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
    }

    // ── Python stdlib extraction ──────────────────────────────────────────────

    /// Extrait libpython.zip.so (stdlib Python) depuis nativeLibsDir vers filesDir.
    /// Retourne PYTHONHOME = filesDir/packages/python/usr, ou une erreur.
    Future<_Result<String>> _ensurePythonStdlib(
        String nativeDir, String filesDir) async {
      final zipSo = File('$nativeDir/libpython.zip.so');
      final zipExists = await zipSo.exists();
      final zipSize = zipExists ? await zipSo.length() : 0;
      AppLogger.log(
          'ZeusDL stdlib: libpython.zip.so — existe=$zipExists taille=${zipSize}B — chemin=${zipSo.path}',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      if (!zipExists || zipSize == 0) {
        // Lister ce qui est présent dans nativeDir pour aider au diagnostic
        try {
          final contents = Directory(nativeDir)
              .listSync()
              .map((e) => e.path.split('/').last)
              .join(', ');
          AppLogger.log(
              'ZeusDL stdlib [ERREUR] libpython.zip.so absent — '
              'contenu de nativeDir : $contents',
              logLevel: LogLevel.error, tag: LogTag.zeus);
        } catch (_) {
          AppLogger.log(
              'ZeusDL stdlib [ERREUR] libpython.zip.so absent et nativeDir illisible',
              logLevel: LogLevel.error, tag: LogTag.zeus);
        }
        return const _Result.fail(
            'libpython.zip.so absent de nativeLibsDir — APK mal packagé');
      }

      final pythonDir = Directory('$filesDir/packages/python');
      final versionFile = File('$filesDir/packages/python_size.txt');
      final currentSize = zipSize.toString();

      // Vérifier si déjà extrait avec la bonne version
      if (await pythonDir.exists() && await versionFile.exists()) {
        final stored = (await versionFile.readAsString()).trim();
        if (stored == currentSize) {
          AppLogger.log(
              'ZeusDL stdlib: déjà extrait ($currentSize octets) — pas de re-extraction',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return _Result.ok('$filesDir/packages/python/usr');
        }
        AppLogger.log(
            'ZeusDL stdlib: version changée (stockée=$stored actuelle=$currentSize) — re-extraction',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      } else {
        AppLogger.log(
            'ZeusDL stdlib: première extraction ($currentSize octets)',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      }

      try {
        if (await pythonDir.exists()) {
          AppLogger.log('ZeusDL stdlib: suppression ancien répertoire',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          await pythonDir.delete(recursive: true);
        }
        await pythonDir.create(recursive: true);

        AppLogger.log(
            'ZeusDL stdlib: extraction en cours vers ${pythonDir.path}…',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        await compute(_extractZip,
            _ExtractArgs(zipSo.path, '$filesDir/packages/python'));

        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(currentSize);

        AppLogger.log(
            'ZeusDL stdlib: extraction terminée → ${pythonDir.path}',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok('$filesDir/packages/python/usr');
      } catch (e, st) {
        AppLogger.log(
            'ZeusDL stdlib [ERREUR] extraction échouée',
            logLevel: LogLevel.error,
            tag: LogTag.zeus,
            error: e,
            stackTrace: st);
        return _Result.fail('Extraction libpython.zip.so échouée : $e');
      }
    }

    // ── ZeusDL scripts ───────────────────────────────────────────────────────

    /// Assure que filesDir/zeusdl/__main__.py existe.
    /// Tente d'abord une mise à jour GitHub, puis replie sur l'asset bundlé.
    Future<_Result<String>> _ensureZeusDlScripts(String filesDir) async {
      final zeusDir = Directory('$filesDir/zeusdl');
      final mainPy = File('$filesDir/zeusdl/__main__.py');
      final versionFile = File('$filesDir/zeusdl_version.txt');

      AppLogger.log('ZeusDL scripts: vérification dans ${zeusDir.path}',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      // Tentative de mise à jour en arrière-plan
      await _tryUpdateZeusDl(filesDir, zeusDir, versionFile);

      if (await mainPy.exists()) {
        final size = await mainPy.length();
        AppLogger.log(
            'ZeusDL scripts: __main__.py présent ($size octets)',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok(mainPy.path);
      }

      // __main__.py absent — extraction depuis l'asset bundlé
      AppLogger.log(
          'ZeusDL scripts: __main__.py absent, extraction depuis asset bundlé…',
          logLevel: LogLevel.info, tag: LogTag.zeus);
      try {
        final data = await rootBundle.load('assets/zeusdl/zeusdl.zip');
        final bytes = data.buffer.asUint8List();
        if (bytes.isEmpty) {
          AppLogger.log(
              'ZeusDL scripts [ERREUR] asset zeusdl.zip vide',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return const _Result.fail('Asset zeusdl.zip vide dans APK');
        }
        AppLogger.log(
            'ZeusDL scripts: asset chargé (${bytes.length} octets) — extraction vers $filesDir',
            logLevel: LogLevel.info, tag: LogTag.zeus);

        if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
        await zeusDir.create(recursive: true);
        await compute(_extractZipBytes, _ExtractBytesArgs(bytes, filesDir));

        final exists = await mainPy.exists();
        if (!exists) {
          AppLogger.log(
              'ZeusDL scripts [ERREUR] __main__.py introuvable après extraction — '
              'structure de zeusdl.zip incorrecte ?',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return const _Result.fail(
              '__main__.py absent après extraction — vérifier la structure de zeusdl.zip');
        }
        AppLogger.log(
            'ZeusDL scripts: extraction asset réussie → ${mainPy.path}',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok(mainPy.path);
      } catch (e, st) {
        AppLogger.log(
            'ZeusDL scripts [ERREUR] extraction asset échouée',
            logLevel: LogLevel.error,
            tag: LogTag.zeus,
            error: e,
            stackTrace: st);
        return _Result.fail('Extraction asset zeusdl.zip échouée : $e');
      }
    }

    Future<void> _tryUpdateZeusDl(
        String filesDir, Directory zeusDir, File versionFile) async {
      try {
        final storedTag = await versionFile.exists()
            ? (await versionFile.readAsString()).trim()
            : '';

        AppLogger.log(
            'ZeusDL mise à jour: vérification GitHub (version locale = "$storedTag")…',
            logLevel: LogLevel.debug, tag: LogTag.zeus);

        final res = await http
            .get(Uri.parse(_zeusReleaseApiUrl),
                headers: {'Accept': 'application/vnd.github+json'})
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) {
          AppLogger.log(
              'ZeusDL mise à jour: GitHub API ${res.statusCode} — ignoré',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return;
        }

        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final latestTag = (json['tag_name'] as String? ?? '').trim();
        if (latestTag.isEmpty || latestTag == storedTag) {
          AppLogger.log(
              'ZeusDL mise à jour: déjà à jour ("$latestTag")',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise à jour: nouvelle version disponible $storedTag → $latestTag',
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
          AppLogger.log(
              'ZeusDL mise à jour [WARN] pas de zeusdl.zip dans la release $latestTag',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise à jour: téléchargement $downloadUrl',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        final zipRes = await http
            .get(Uri.parse(downloadUrl))
            .timeout(const Duration(minutes: 3));
        if (zipRes.statusCode != 200) {
          AppLogger.log(
              'ZeusDL mise à jour [WARN] téléchargement échoué HTTP ${zipRes.statusCode}',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise à jour: extraction ${zipRes.bodyBytes.length} octets → $filesDir',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
        await zeusDir.create(recursive: true);
        await compute(
            _extractZipBytes, _ExtractBytesArgs(zipRes.bodyBytes, filesDir));

        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(latestTag);
        AppLogger.log(
            'ZeusDL mise à jour: $latestTag installé avec succès ✓',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      } catch (e) {
        AppLogger.log(
            'ZeusDL mise à jour: vérification ignorée (réseau/timeout) : $e',
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
      // Windows
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/$_binaryName.exe';
    }

    // ── Helpers for UI (binaries_section, marketplace) ───────────────────────

    Future<int?> getBundledBinarySize() async {
      if (Platform.isAndroid) {
        try {
          final nativeDir = await _binaryUtilsChannel
              .invokeMethod<String>('getNativeLibraryDir');
          if (nativeDir != null && nativeDir.isNotEmpty) {
            final f = File('$nativeDir/libpython.so');
            if (await f.exists()) return await f.length();
          }
        } catch (_) {}
        return null;
      }
      try {
        final data = await rootBundle.load(_assetPath);
        return data.lengthInBytes;
      } catch (_) {
        return null;
      }
    }

    Future<String?> downloadFromUrl(String url) async {
      try {
        AppLogger.log('ZeusDL: téléchargement depuis $url',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) {
          AppLogger.log(
              'ZeusDL: téléchargement échoué HTTP ${res.statusCode}',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return null;
        }
        final targetPath = await _internalBinaryPath();
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(res.bodyBytes, flush: true);
        await _ensureExecutable(file);
        _cachedPath = targetPath;
        AppLogger.log('ZeusDL: téléchargement terminé → $targetPath',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return targetPath;
      } catch (e, st) {
        AppLogger.log('ZeusDL: downloadFromUrl erreur',
            logLevel: LogLevel.error,
            tag: LogTag.zeus,
            error: e,
            stackTrace: st);
        return null;
      }
    }
  }
  