import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:archive/archive_io.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/services.dart';
  import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';
  import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/core/config/app_config.dart';
  import 'package:watchtower/services/python/libpython_manager.dart';

  const _binaryUtilsChannel = MethodChannel('com.watchtower.app.binary_utils');

  const _zeusReleaseApiUrl =
      'https://api.github.com/repos/ferelking242/zeusdl/releases/latest';

  // ââ Isolate helpers (top-level, required by compute()) âââââââââââââââââââââ

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

  Future<void> _extractZip(_ExtractArgs args) async {
    // extractFileToDisk() valide l'extension du fichier (.zip, .tar.gz...).
    // libpython.zip.so est un ZIP valide mais son extension est .so -> on lit
    // les octets bruts et on les decode directement, sans verification d'extension.
    final bytes = File(args.zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    await extractArchiveToDisk(archive, args.destDir);
  }

  /// Strip-aware extraction: detects if all zip entries share one common root
  /// prefix (e.g. "zeusdl/") and strips it, then writes directly to [destDir].
  /// Works correctly whether the zip is flat or has a single root folder.
  Future<void> _extractZipBytesToDir(_ExtractBytesArgs args) async {
    final archive = ZipDecoder().decodeBytes(args.bytes);

    // ── Detect common root prefix ────────────────────────────────────────────
    // Only consider FILE entries when computing the prefix (directory entries
    // like "zeusdl" have no slash, which used to incorrectly reset the prefix
    // to null and leave a nested folder after rename).
    String? commonPrefix;
    for (final f in archive.files) {
      if (!f.isFile) continue; // skip directory entries
      final name = f.name;
      if (name.isEmpty) continue;
      final slash = name.indexOf('/');
      if (slash < 0) { commonPrefix = null; break; }
      final prefix = name.substring(0, slash + 1);
      if (commonPrefix == null) {
        commonPrefix = prefix;
      } else if (commonPrefix != prefix) {
        commonPrefix = null;
        break;
      }
    }

    // ── Extract files, stripping the common prefix when present ─────────────
    for (final f in archive.files) {
      if (!f.isFile) continue;
      var name = f.name;
      if (commonPrefix != null && name.startsWith(commonPrefix)) {
        name = name.substring(commonPrefix.length);
      }
      if (name.isEmpty) continue;
      final outFile = File('${args.destDir}/$name');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(f.content as List<int>);
    }
  }

  // ââ Result type for internal steps âââââââââââââââââââââââââââââââââââââââââ

  /// Wraps either a success value [T] or an error [message].
  class _Result<T> {
    final T? value;
    final String? error;
    const _Result.ok(this.value) : error = null;
    const _Result.fail(this.error) : value = null;
    bool get isOk => error == null;
  }

  // âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

  /// Execution context returned by [ZeusDlBinaryManager.resolveExecutionContext].
  ///
  /// Android (Python Bionic via youtubedl-android runtime):
  ///   executable  = nativeLibsDir/libpython.so     â Python ARM64 Bionic, execv OK
  ///   prependArgs = [filesDir/zeusdl/__main__.py]   â ZeusDL Python entry point
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
  /// Android â Python-based execution (no SIGSEGV, no SELinux block):
  ///   â¢ libpython.so     (4 KB)  lives in nativeLibsDir â execv'd directly â
  ///   â¢ libpython.zip.so (11 MB) lives in nativeLibsDir â unzipped to filesDir
  ///   â¢ zeusdl.zip               bundled in assets + downloadable from GitHub
  ///
  /// Update flow:
  ///   On each [resolveExecutionContext] call the manager checks GitHub for a
  ///   new ZeusDL release.  If one exists it downloads zeusdl.zip and re-extracts
  ///   it to filesDir â no APK reinstall needed.
  class ZeusDlBinaryManager {
    static ZeusDlBinaryManager? _instance;
    static ZeusDlBinaryManager get instance =>
        _instance ??= ZeusDlBinaryManager._();
    ZeusDlBinaryManager._();

    String? _cachedPath;
    DateTime? _lastUpdateCheckAt;

    static const String _assetPath = 'assets/binaries/zeusdl';
    static const String _binaryName = 'zeusdl';

    // ââ Public API ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    Future<ZeusDlExecutionContext?> resolveExecutionContext() async {
      if (Platform.isAndroid) return _resolveAndroidContext();
      if (Platform.isIOS) return _resolveIOSContext();
      final path = await resolveExecutable();
      if (path == null) return null;
      return ZeusDlExecutionContext(executable: path);
    }



      // ââ iOS: rÃ©solution du contexte d'exÃ©cution âââââââââââââââââââââââââââââââ
      //
      // Non-jailbreakÃ©   : Process.start() interdit par le sandbox iOS.
      //                    On retourne null â ZeusDL dÃ©sactivÃ© sur cet appareil.
      // Dopamine/rootless: les binaires arm64 dans /var/jb sont exÃ©cutables
      //                    si signÃ©s avec ldid et si le jailbreak patche posix_spawn.
      // Rooted (classic) : /usr/bin, /usr/local/bin accessibles directement.
      Future<ZeusDlExecutionContext?> _resolveIOSContext() async {
        AppLogger.log('ZeusDL iOS: rÃ©solution contexte',
            logLevel: LogLevel.info, tag: LogTag.zeus);

        // ââ 1. AppDelegate channel: dÃ©tection jailbreak + chemin yt-dlp ââââââââââ
        try {
          final path = await _binaryUtilsChannel.invokeMethod<String?>('getYtDlpPath');
          if (path != null && path.isNotEmpty) {
            if (await File(path).exists()) {
              AppLogger.log('ZeusDL iOS â via AppDelegate: $path',
                  logLevel: LogLevel.info, tag: LogTag.zeus);
              return ZeusDlExecutionContext(executable: path);
            }
          }
        } catch (e) {
          AppLogger.log('ZeusDL iOS: getYtDlpPath error: $e',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
        }

        // ââ 2. Chemins jailbreak connus âââââââââââââââââââââââââââââââââââââââââââ
        const _kJBPaths = <String>[
          '/var/jb/usr/local/bin/zeusdl',   // Dopamine rootless
          '/var/jb/usr/bin/zeusdl',
          '/var/jb/usr/local/bin/yt-dlp',
          '/var/jb/usr/bin/yt-dlp',
          '/usr/local/bin/zeusdl',          // Rooted classique
          '/usr/bin/zeusdl',
          '/usr/local/bin/yt-dlp',
          '/usr/bin/yt-dlp',
        ];
        for (final p in _kJBPaths) {
          if (await File(p).exists()) {
            AppLogger.log('ZeusDL iOS â jailbreak path: $p',
                logLevel: LogLevel.info, tag: LogTag.zeus);
            return ZeusDlExecutionContext(executable: p);
          }
        }

        // ââ 3. Binaire bundlÃ© dans les assets (Mach-O arm64 apple-ios) âââââââââââ
        final bundled = await _extractIOSBundledBinary();
        if (bundled != null) {
          AppLogger.log('ZeusDL iOS â asset extrait: $bundled',
              logLevel: LogLevel.info, tag: LogTag.zeus);
          return ZeusDlExecutionContext(executable: bundled);
        }

        AppLogger.log(
            'ZeusDL iOS: aucun binaire disponible (non-jailbreakÃ© ou binaire absent)',
            logLevel: LogLevel.warning, tag: LogTag.zeus);
        return null;
      }

      Future<String?> _extractIOSBundledBinary() async {
        try {
          final supportDir = (await getApplicationSupportDirectory()).path;
          final destPath = '$supportDir/zeusdl';
          final dest = File(destPath);
          if (await dest.exists() && await dest.length() > 100000) return destPath;

          // Charger depuis les assets Flutter
          try {
            final data = await rootBundle.load(_assetPath);
            final bytes = data.buffer.asUint8List();
            // Valider le magic Mach-O arm64 : CE FA ED FE ou CF FA ED FE
            if (bytes.length < 4) return null;
            final isMachO = (bytes[0] == 0xCE || bytes[0] == 0xCF) &&
                            bytes[1] == 0xFA && bytes[2] == 0xED && bytes[3] == 0xFE;
            final isFat = bytes[0] == 0xCA && bytes[1] == 0xFE &&
                          bytes[2] == 0xBA && bytes[3] == 0xBE;
            if (!isMachO && !isFat) {
              AppLogger.log(
                'ZeusDL iOS: asset non Mach-O (magic=${bytes.sublist(0,4).map((b) => b.toRadixString(16).padLeft(2,"0")).join()})',
                logLevel: LogLevel.error, tag: LogTag.zeus);
              return null;
            }
            await dest.parent.create(recursive: true);
            await dest.writeAsBytes(bytes);
            // chmod +x via AppDelegate (Ã©vite Process.run sur iOS sandbox)
            try {
              await _binaryUtilsChannel.invokeMethod('chmod', {'path': destPath});
            } catch (_) {}
            AppLogger.log('ZeusDL iOS: asset extrait (${bytes.length} bytes)',
                logLevel: LogLevel.info, tag: LogTag.zeus);
            return destPath;
          } on FlutterError {
            return null; // Asset absent du bundle
          }
        } catch (_) {
          return null;
        }
      }

    // ââ Android: Python Bionic execution âââââââââââââââââââââââââââââââââââââ

    Future<ZeusDlExecutionContext?> _resolveAndroidContext() async {
      AppLogger.log('ZeusDL: dÃ©marrage rÃ©solution contexte Android',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      // ââ Ãtape 1 : nativeLibraryDir ââââââââââââââââââââââââââââââââââââââââââ
      final String nativeDir;
      try {
        final result = await _binaryUtilsChannel
            .invokeMethod<String>('getNativeLibraryDir');
        if (result == null || result.isEmpty) {
          AppLogger.log(
              'ZeusDL [ERREUR] nativeLibraryDir vide â MethodChannel sans rÃ©ponse',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return null;
        }
        nativeDir = result;
        AppLogger.log('ZeusDL [1/4] nativeDir = $nativeDir',
            logLevel: LogLevel.debug, tag: LogTag.zeus);
      } catch (e, st) {
        AppLogger.log('ZeusDL [ERREUR] getNativeLibraryDir a lancÃ© une exception',
            logLevel: LogLevel.error, tag: LogTag.zeus, error: e, stackTrace: st);
        return null;
      }

      // ââ Ãtape 2 : libpython.so ââââââââââââââââââââââââââââââââââââââââââââââ
      final pythonBin = File('$nativeDir/libpython.so');
      final pythonBinExists = await pythonBin.exists();
      final pythonBinSize = pythonBinExists ? await pythonBin.length() : 0;
      AppLogger.log(
          'ZeusDL [2/4] libpython.so â existe=$pythonBinExists taille=${pythonBinSize}B',
          logLevel: pythonBinExists && pythonBinSize > 0
              ? LogLevel.info
              : LogLevel.error,
          tag: LogTag.zeus);
      if (!pythonBinExists || pythonBinSize == 0) {
        AppLogger.log(
            'ZeusDL [ERREUR] libpython.so absent ou vide dans $nativeDir â APK mal assemblÃ©',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }

      // ââ Ãtape 3 : Python stdlib (libpython.zip.so â filesDir) âââââââââââââââ
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

      // ââ Ãtape 4 : scripts ZeusDL (__main__.py) ââââââââââââââââââââââââââââââ
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

      // Sur x86_64 avec ARM translation (NDK Translation), le runner x86_64 utilise
      // son propre RPATH (/system/lib64/) pour ses dependances â il n'est pas affecte
      // par LD_LIBRARY_PATH. On definit donc LD_LIBRARY_PATH pour TOUS les appareils
      // afin que les extensions C Python (lib-dynload) trouvent libffi.so, libssl.so, etc.
      // nativeDir est inclus en premier pour que libpython3.11.so.1.0 soit trouve par SONAME.
      const _kNdkTranslationRunner =
          '/system/bin/ndk_translation_program_runner_binfmt_misc_arm64';
      final isX86WithArmTranslation =
          await File(_kNdkTranslationRunner).exists();
      AppLogger.log(
          'ZeusDL: x86_64+arm_translation=$isX86WithArmTranslation '
          '(LD_LIBRARY_PATH actif avec nativeDir+pythonHome/lib)',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      AppLogger.log(
          'ZeusDL â contexte prÃªt â ${pythonBin.path} $mainPy',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      // ââ Ãtape 5 : site-packages (dÃ©pendances pip) âââââââââââââââââââââââ
      final sitePackagesDir = await LibPythonManager.instance.sitePackagesDir;
      AppLogger.log('ZeusDL [5/5] PYTHONPATH = $sitePackagesDir',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      // Installer les dÃ©pendances ZeusDL manquantes en arriÃ¨re-plan (non-bloquant)
      LibPythonManager.instance
          .ensureZeusDlDeps(
            onProgress: (msg) => AppLogger.log('LibPython: $msg',
                tag: LogTag.zeus, logLevel: LogLevel.debug),
          )
          .then((result) => AppLogger.log('LibPython deps: $result',
              tag: LogTag.zeus, logLevel: LogLevel.info))
          .catchError((e) => AppLogger.log('LibPython deps erreur: $e',
              tag: LogTag.zeus, logLevel: LogLevel.warning));

      return ZeusDlExecutionContext(
        executable: pythonBin.path,
        prependArgs: [mainPy],
        extraEnv: {
          'PYTHONHOME': pythonHome,
          // LD_LIBRARY_PATH defini pour TOUS les appareils (ARM64 natif et x86_64+translation).
          // nativeDir en premier : libpython3.11.so (SONAME libpython3.11.so.1.0) pour les C extensions.
          // pythonHome/lib ensuite : libffi.so, libssl.so, libcrypto.so, etc.
          'LD_LIBRARY_PATH': '$nativeDir:$pythonHome/lib',
          'SSL_CERT_FILE': '$pythonHome/etc/tls/cert.pem',
          'PYTHONDONTWRITEBYTECODE': '1',
          'PYTHONUNBUFFERED': '1',
          // PYTHONPATH : dÃ©pendances pip installÃ©es par LibPythonManager
          'PYTHONPATH': sitePackagesDir,
        },
      );
    }

    // ââ Python stdlib extraction ââââââââââââââââââââââââââââââââââââââââââââââ

    /// Extrait libpython.zip.so (stdlib Python) depuis nativeLibsDir vers filesDir.
    /// Retourne PYTHONHOME = filesDir/packages/python/usr, ou une erreur.
    Future<_Result<String>> _ensurePythonStdlib(
        String nativeDir, String filesDir) async {
      final zipSo = File('$nativeDir/libpython.zip.so');
      final zipExists = await zipSo.exists();
      final zipSize = zipExists ? await zipSo.length() : 0;
      AppLogger.log(
          'ZeusDL stdlib: libpython.zip.so â existe=$zipExists taille=${zipSize}B â chemin=${zipSo.path}',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      if (!zipExists || zipSize == 0) {
        // Lister ce qui est prÃ©sent dans nativeDir pour aider au diagnostic
        try {
          final contents = Directory(nativeDir)
              .listSync()
              .map((e) => e.path.split('/').last)
              .join(', ');
          AppLogger.log(
              'ZeusDL stdlib [ERREUR] libpython.zip.so absent â '
              'contenu de nativeDir : $contents',
              logLevel: LogLevel.error, tag: LogTag.zeus);
        } catch (_) {
          AppLogger.log(
              'ZeusDL stdlib [ERREUR] libpython.zip.so absent et nativeDir illisible',
              logLevel: LogLevel.error, tag: LogTag.zeus);
        }
        return const _Result.fail(
            'libpython.zip.so absent de nativeLibsDir â APK mal packagÃ©');
      }

      final pythonDir = Directory('$filesDir/packages/python');
      final versionFile = File('$filesDir/packages/python3.11_v2_size.txt');
      final currentSize = zipSize.toString();

      // VÃ©rifier si dÃ©jÃ  extrait avec la bonne version
      if (await pythonDir.exists() && await versionFile.exists()) {
        final stored = (await versionFile.readAsString()).trim();
        if (stored == currentSize) {
          AppLogger.log(
              'ZeusDL stdlib: dÃ©jÃ  extrait ($currentSize octets) â pas de re-extraction',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return _Result.ok('$filesDir/packages/python/usr');
        }
        AppLogger.log(
            'ZeusDL stdlib: version changÃ©e (stockÃ©e=$stored actuelle=$currentSize) â re-extraction',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      } else {
        AppLogger.log(
            'ZeusDL stdlib: premiÃ¨re extraction ($currentSize octets)',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      }

      try {
        if (await pythonDir.exists()) {
          AppLogger.log('ZeusDL stdlib: suppression ancien rÃ©pertoire',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          await pythonDir.delete(recursive: true);
        }
        await pythonDir.create(recursive: true);

        AppLogger.log(
            'ZeusDL stdlib: extraction en cours vers ${pythonDir.path}â¦',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        await compute(_extractZip,
            _ExtractArgs(zipSo.path, '$filesDir/packages/python'));

        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(currentSize);

        AppLogger.log(
            'ZeusDL stdlib: extraction terminÃ©e â ${pythonDir.path}',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok('$filesDir/packages/python/usr');
      } catch (e, st) {
        AppLogger.log(
            'ZeusDL stdlib [ERREUR] extraction Ã©chouÃ©e',
            logLevel: LogLevel.error,
            tag: LogTag.zeus,
            error: e,
            stackTrace: st);
        return _Result.fail('Extraction libpython.zip.so Ã©chouÃ©e : $e');
      }
    }

    // ââ ZeusDL scripts âââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    /// Assure que filesDir/zeusdl/__main__.py existe.
    /// Tente d'abord une mise Ã  jour GitHub, puis replie sur l'asset bundlÃ©.
    Future<_Result<String>> _ensureZeusDlScripts(String filesDir) async {
      final zeusDir = Directory('$filesDir/zeusdl');
      final mainPy = File('$filesDir/zeusdl/__main__.py');
      final versionFile = File('$filesDir/zeusdl_version.txt');

      AppLogger.log('ZeusDL scripts: vÃ©rification dans ${zeusDir.path}',
          logLevel: LogLevel.debug, tag: LogTag.zeus);

      // Tentative de mise Ã  jour en arriÃ¨re-plan
      await _tryUpdateZeusDl(filesDir, zeusDir, versionFile);

      if (await mainPy.exists()) {
        final size = await mainPy.length();
        AppLogger.log(
            'ZeusDL scripts: __main__.py prÃ©sent ($size octets)',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok(mainPy.path);
      }

      // __main__.py absent â extraction depuis l'asset bundlÃ©
      AppLogger.log(
          'ZeusDL scripts: __main__.py absent, extraction depuis asset bundlÃ©â¦',
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
            'ZeusDL scripts: asset chargÃ© (${bytes.length} octets) â extraction vers $filesDir',
            logLevel: LogLevel.info, tag: LogTag.zeus);

        final tmpAssetDir = Directory(
            '${zeusDir.path}_tmp_${DateTime.now().millisecondsSinceEpoch}');
        try {
          await tmpAssetDir.create(recursive: true);
          await compute(_extractZipBytesToDir, _ExtractBytesArgs(bytes, tmpAssetDir.path));
          if (!kIsWeb) {
            final extractedFiles = tmpAssetDir.listSync(recursive: true);
            AppLogger.log('[ZEUS] Fichiers extraits: ${extractedFiles.map((f) => f.path.replaceAll(tmpAssetDir.path, '')).join(', ')}', logLevel: LogLevel.debug, tag: LogTag.zeus);
          }
          if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
          await tmpAssetDir.rename(zeusDir.path);
        } catch (e) {
          if (await tmpAssetDir.exists()) {
            await tmpAssetDir.delete(recursive: true).catchError((_) {});
          }
          rethrow;
        }

        final exists = await mainPy.exists();
        if (!exists) {
          AppLogger.log(
              'ZeusDL scripts [ERREUR] __main__.py introuvable aprÃ¨s extraction â '
              'structure de zeusdl.zip incorrecte ?',
              logLevel: LogLevel.error, tag: LogTag.zeus);
          return const _Result.fail(
              '__main__.py absent aprÃ¨s extraction â vÃ©rifier la structure de zeusdl.zip');
        }
        AppLogger.log(
            'ZeusDL scripts: extraction asset rÃ©ussie â ${mainPy.path}',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        return _Result.ok(mainPy.path);
      } catch (e, st) {
        AppLogger.log(
            'ZeusDL scripts [ERREUR] extraction asset Ã©chouÃ©e',
            logLevel: LogLevel.error,
            tag: LogTag.zeus,
            error: e,
            stackTrace: st);
        return _Result.fail('Extraction asset zeusdl.zip Ã©chouÃ©e : $e');
      }
    }

    Future<void> _tryUpdateZeusDl(
        String filesDir, Directory zeusDir, File versionFile) async {
      try {
        // Cache l'appel GitHub 1h pour Ã©viter un hit rÃ©seau Ã  chaque dÃ©marrage
        const _kUpdateCheckInterval = Duration(hours: 1);
        final now = DateTime.now();
        if (_lastUpdateCheckAt != null &&
            now.difference(_lastUpdateCheckAt!) < _kUpdateCheckInterval) {
          AppLogger.log(
              'ZeusDL mise Ã  jour: check ignorÃ© (dernier check il y a ${now.difference(_lastUpdateCheckAt!).inMinutes} min)',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return;
        }
        _lastUpdateCheckAt = now;

        final storedTag = await versionFile.exists()
            ? (await versionFile.readAsString()).trim()
            : '';

        AppLogger.log(
            'ZeusDL mise Ã  jour: vÃ©rification GitHub (version locale = "$storedTag")â¦',
            logLevel: LogLevel.debug, tag: LogTag.zeus);

        final res = await http
            .get(Uri.parse(_zeusReleaseApiUrl), headers: {
              'Accept': 'application/vnd.github+json',
              if (AppConfig.githubToken.isNotEmpty)
                'Authorization': 'token ${AppConfig.githubToken}',
            })
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) {
          AppLogger.log(
              'ZeusDL mise Ã  jour: GitHub API ${res.statusCode} â ignorÃ©',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return;
        }

        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final latestTag = (json['tag_name'] as String? ?? '').trim();
        if (latestTag.isEmpty || latestTag == storedTag) {
          AppLogger.log(
              'ZeusDL mise Ã  jour: dÃ©jÃ  Ã  jour ("$latestTag")',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise Ã  jour: nouvelle version disponible $storedTag â $latestTag',
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
              'ZeusDL mise Ã  jour [WARN] pas de zeusdl.zip dans la release $latestTag',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise Ã  jour: tÃ©lÃ©chargement $downloadUrl',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        final zipRes = await http
            .get(Uri.parse(downloadUrl))
            .timeout(const Duration(minutes: 3));
        if (zipRes.statusCode != 200) {
          AppLogger.log(
              'ZeusDL mise Ã  jour [WARN] tÃ©lÃ©chargement Ã©chouÃ© HTTP ${zipRes.statusCode}',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
          return;
        }

        AppLogger.log(
            'ZeusDL mise Ã  jour: extraction ${zipRes.bodyBytes.length} octets â $filesDir',
            logLevel: LogLevel.info, tag: LogTag.zeus);
        final tmpUpdateDir = Directory(
            '${zeusDir.path}_tmp_${DateTime.now().millisecondsSinceEpoch}');
        try {
          await tmpUpdateDir.create(recursive: true);
          await compute(
              _extractZipBytesToDir, _ExtractBytesArgs(zipRes.bodyBytes, tmpUpdateDir.path));
          if (!kIsWeb) {
            final updatedFiles = tmpUpdateDir.listSync(recursive: true);
            AppLogger.log('[ZEUS] Fichiers mis à jour: ${updatedFiles.map((f) => f.path.replaceAll(tmpUpdateDir.path, '')).join(', ')}', logLevel: LogLevel.debug, tag: LogTag.zeus);
          }
          if (await zeusDir.exists()) await zeusDir.delete(recursive: true);
          await tmpUpdateDir.rename(zeusDir.path);
        } catch (e) {
          if (await tmpUpdateDir.exists()) {
            await tmpUpdateDir.delete(recursive: true).catchError((_) {});
          }
          rethrow;
        }

        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(latestTag);
        AppLogger.log(
            'ZeusDL mise Ã  jour: $latestTag installÃ© avec succÃ¨s â',
            logLevel: LogLevel.info, tag: LogTag.zeus);
      } catch (e) {
        AppLogger.log(
            'ZeusDL mise Ã  jour: vÃ©rification ignorÃ©e (rÃ©seau/timeout) : $e',
            logLevel: LogLevel.debug, tag: LogTag.zeus);
      }
    }

    // ââ Non-Android: classic binary approach âââââââââââââââââââââââââââââââââ

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
        AppLogger.log('ZeusDL: extraction assets Ã©chouÃ©e',
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
              'ZeusDL: setExecutable=${ok ?? false} â ${file.path}',
              logLevel: ok == true ? LogLevel.debug : LogLevel.warning,
              tag: LogTag.zeus);
          return;
        } catch (e) {
          AppLogger.log('ZeusDL: setExecutable channel Ã©chouÃ©: $e',
              logLevel: LogLevel.warning, tag: LogTag.zeus);
        }
        try {
          final r = await Process.run('/system/bin/chmod', ['+x', file.path]);
          if (r.exitCode != 0) {
            AppLogger.log(
                'ZeusDL: chmod Ã©chouÃ© (${r.exitCode}): ${r.stderr}',
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

    // ââ Helpers for UI (binaries_section, marketplace) âââââââââââââââââââââââ

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

    // ââ User-facing helpers ââââââââââââââââââââââââââââââââââââââââââââââââââ

    /// Chemin affichÃ© dans l'UI quand l'utilisateur installe ZeusDL manuellement.
    Future<String> userOverrideDisplayPath() async {
      if (!Platform.isAndroid) return 'N/A (Android only)';
      try {
        final dir = await getExternalStorageDirectory();
        return '${dir?.path ?? 'Android/data/com.watchtower.app/files'}/$_binaryName';
      } catch (_) {
        return 'Android/data/com.watchtower.app/files/$_binaryName';
      }
    }

    /// TÃ©lÃ©charge un binaire ZeusDL depuis une URL et l'installe.
    /// [onProgress] est appelÃ© avec (reÃ§us, total) Ã  chaque chunk reÃ§u.
    Future<bool> downloadFromUrl(
      String url, {
      void Function(int received, int total)? onProgress,
    }) async {
      AppLogger.log('ZeusDL: tÃ©lÃ©chargement depuis $url',
          logLevel: LogLevel.info, tag: LogTag.zeus);
      try {
        final internalPath = await _internalBinaryPath();
        final tmpFile = File('$internalPath.part');
        await tmpFile.parent.create(recursive: true);
        if (await tmpFile.exists()) await tmpFile.delete();

        final req = http.Request('GET', Uri.parse(url));
        final res = await http.Client().send(req);
        if (res.statusCode != 200) {
          AppLogger.log(
              'ZeusDL: tÃ©lÃ©chargement Ã©chouÃ© HTTP ${res.statusCode} â $url',
              logLevel: LogLevel.error, tag: LogTag.zeus);
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
            'ZeusDL: tÃ©lÃ©chargement terminÃ© ($received octets) â $internalPath',
            logLevel: LogLevel.info, tag: LogTag.zeus);
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

    /// RÃ©initialise le cache mÃ©moire â ne supprime pas le binaire sur disque.
    void resetCachedPath() {
      _cachedPath = null;
    }
  }
  