import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

class PythonPackageInfo {
  final String name;
  final String version;
  const PythonPackageInfo({required this.name, required this.version});
}

// Helper top-level pour compute() — extrait libpython.zip.so vers filesDir
  Future<void> _libpythonExtractZip(List<String> args) async {
    final zipPath = args[0];
    final destDir = args[1];
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive.files) {
      if (f.isDirectory) continue;
      final name = f.name;
      if (name.isEmpty) continue;
      final outPath = '$destDir/$name';

      // Detect Unix symlinks via mode bits (S_IFLNK = 0xA000).
      // Python-for-Android ships versioned .so files as symlinks
      // (e.g. libz.so.1 -> libz.so.1.2.11). Without this check they
      // are written as plain text files (13 bytes = target path string)
      // which makes dlopen fail with "too small to be an ELF executable".
      final isSymlink = (f.mode & 0xF000) == 0xA000;
      if (isSymlink) {
        final target = utf8.decode(f.content as List<int>).trim();
        final link = Link(outPath);
        link.parent.createSync(recursive: true);
        if (link.existsSync()) link.deleteSync();
        link.createSync(target);
      } else {
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(f.content as List<int>);
      }
    }
  }

  class LibPythonManager {
  static LibPythonManager? _instance;
  static LibPythonManager get instance => _instance ??= LibPythonManager._();
  LibPythonManager._();

  static const _channel = MethodChannel('com.watchtower.app.binary_utils');

  static const zeusRequiredPackages = [
    'requests',
    'certifi',
    'urllib3',
    'charset-normalizer',
    'idna',
    'websockets',
    'mutagen',
  ];

  String? _cachedNativeDir;
  String? _cachedFilesDir;
  bool? _pipAvailable;
  bool _depsEnsured = false;
  bool _pipBundleAttempted = false; // évite les logs dupliqués de _ensurePipFromBundle
  String? _cachedPythonHome;

  Future<String?> get _nativeDir async {
    if (_cachedNativeDir != null) return _cachedNativeDir;
    try {
      final result = await _channel.invokeMethod<String>('getNativeLibraryDir');
      _cachedNativeDir = result;
      return result;
    } catch (e, stack) {
      AppLogger.log('[Python] getNativeLibraryDir échoué',
          logLevel: LogLevel.error, error: e, stackTrace: stack);
      return null;
    }
  }

  Future<String> get _filesDir async {
    if (_cachedFilesDir != null) return _cachedFilesDir!;
    final dir = await getApplicationSupportDirectory();
    _cachedFilesDir = dir.path;
    return dir.path;
  }

  Future<String?> get pythonExe async {
    final nd = await _nativeDir;
    if (nd == null) return null;
    final f = File('$nd/libpython.so');
    return (await f.exists()) ? f.path : null;
  }

  Future<String> get pythonHome async {
      final fd = await _filesDir;
      return '$fd/packages/python/usr';
    }

    /// Extrait la stdlib Python (libpython.zip.so -> filesDir/packages/python/usr)
    /// puis bootstrappe pip depuis le wheel bundlé assets/wheels/pip.whl.
    /// Doit etre appelee avant toute invocation de libpython.so.
    /// Retourne PYTHONHOME ou null en cas d'echec.
    Future<String?> ensureStdlib() async {
      if (_cachedPythonHome != null) return _cachedPythonHome;

      final nd = await _nativeDir;
      if (nd == null) {
        AppLogger.log('[Python] ensureStdlib: nativeDir introuvable',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }

      final fd = await _filesDir;
      final zipSo = File('$nd/libpython.zip.so');

      if (!await zipSo.exists()) {
        AppLogger.log('[Python] ensureStdlib: libpython.zip.so absent de $nd',
            logLevel: LogLevel.error, tag: LogTag.zeus);
        return null;
      }

      final zipSize = await zipSo.length();
      final versionFile = File('$fd/packages/python3.11_v3_size.txt');
      final currentSize = zipSize.toString();
      final pythonDir = Directory('$fd/packages/python');

      if (await pythonDir.exists() && await versionFile.exists()) {
        final stored = (await versionFile.readAsString()).trim();
        if (stored == currentSize) {
          final ph = '$fd/packages/python/usr';
          _cachedPythonHome = ph;
          AppLogger.log('[Python] stdlib deja extrait -> PYTHONHOME=$ph',
              logLevel: LogLevel.debug, tag: LogTag.zeus);
          // Ensure pip is bootstrapped even on cached stdlib
          await _ensurePipFromBundle();
          return ph;
        }
      }

      AppLogger.log('[Python] extraction libpython.zip.so...',
          logLevel: LogLevel.info, tag: LogTag.zeus);

      try {
        if (await pythonDir.exists()) {
          await pythonDir.delete(recursive: true);
        }
        await pythonDir.create(recursive: true);

        await compute<List<String>, void>(
            _libpythonExtractZip, [zipSo.path, '$fd/packages/python']);

        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(currentSize);

        final ph = '$fd/packages/python/usr';
        _cachedPythonHome = ph;
        AppLogger.log('[Python] stdlib extrait avec succes -> PYTHONHOME=$ph',
            logLevel: LogLevel.info, tag: LogTag.zeus);

        // Bootstrap pip from bundled wheel right after stdlib extraction
        await _ensurePipFromBundle();
        return ph;
      } catch (e, st) {
        AppLogger.log('[Python] ensureStdlib erreur extraction',
            logLevel: LogLevel.error, tag: LogTag.zeus, error: e, stackTrace: st);
        return null;
      }
    }

  Future<String> get sitePackagesDir async {
    final fd = await _filesDir;
    final dir = Directory('$fd/python_packages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<Map<String, String>> buildEnv() => _env;

  Future<Map<String, String>> get _env async {
    final nd = await _nativeDir ?? '';
    final ph = await pythonHome;
    final sp = await sitePackagesDir;
    final tmp = (await getTemporaryDirectory()).path;
    return {
      'PYTHONHOME': ph,
      'LD_LIBRARY_PATH': '$nd:$ph/lib',
      'SSL_CERT_FILE': '$ph/etc/tls/cert.pem',
      'PYTHONDONTWRITEBYTECODE': '1',
      'PYTHONUNBUFFERED': '1',
      'PYTHONPATH': sp,
      'HOME': ph,
      'TMPDIR': tmp,
    };
  }

  Future<String> getPythonVersion() async {
    final exe = await pythonExe;
    if (exe == null) return 'Python non disponible';
    try {
      final env = await _env;
      final res = await Process.run(exe, ['--version'], environment: env)
          .timeout(const Duration(seconds: 10));
      final out = '${res.stdout}'.trim();
      final err = '${res.stderr}'.trim();
      return out.isNotEmpty ? out : (err.isNotEmpty ? err : 'Inconnu');
    } catch (e) {
      return 'Erreur: $e';
    }
  }

  Future<bool> isPipAvailable() async {
    if (_pipAvailable != null) return _pipAvailable!;
    final exe = await pythonExe;
    if (exe == null) {
      _pipAvailable = false;
      return false;
    }
    try {
      final env = await _env;
      final res = await Process.run(exe, ['-m', 'pip', '--version'],
              environment: env)
          .timeout(const Duration(seconds: 15));
      _pipAvailable = res.exitCode == 0;
      return _pipAvailable!;
    } catch (e, stack) {
      AppLogger.log('[Python] pip indisponible : $e',
          logLevel: LogLevel.warning, tag: LogTag.zeus,
          error: e, stackTrace: stack);
      _pipAvailable = false;
      return false;
    }
  }

  Future<String> getPipVersion() async {
    final exe = await pythonExe;
    if (exe == null) return 'pip non disponible';
    try {
      final env = await _env;
      final res = await Process.run(exe, ['-m', 'pip', '--version'],
              environment: env)
          .timeout(const Duration(seconds: 15));
      if (res.exitCode == 0) {
        final out = '${res.stdout}'.trim();
        return out.isNotEmpty ? out : 'pip disponible';
      }
      return 'pip non installé';
    } catch (_) {
      return 'pip non disponible';
    }
  }

  /// Extrait pip depuis le wheel bundlé assets/wheels/pip.whl vers site-packages.
  ///
  /// Appelé automatiquement par ensureStdlib() — pip devient disponible
  /// dès le premier démarrage, sans réseau, sans recompilation du Python embarqué.
  /// Le wheel pip-*-py3-none-any.whl est pur Python, ~2 MB, valide sur toutes arches.
  Future<void> _ensurePipFromBundle() async {
    if (_pipAvailable == true) return;
    if (_pipBundleAttempted) return; // déjà tenté — évite les logs dupliqués
    if (await isPipAvailable()) return;
    _pipBundleAttempted = true;

    AppLogger.log('LibPython: pip absent — tentative bootstrap depuis assets/wheels/pip.whl',
        tag: LogTag.zeus, logLevel: LogLevel.info);

    const assetKey = 'assets/wheels/pip.whl';
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List();

      final sp  = await sitePackagesDir;
      final tmp = await getTemporaryDirectory();
      final exe = await pythonExe;
      if (exe == null) return;

      final wheelFile  = File('${tmp.path}/pip_bundle.whl');
      final scriptFile = File('${tmp.path}/pip_install.py');
      await wheelFile.writeAsBytes(bytes);
      await scriptFile.writeAsString(
        'import zipfile, os\n'
        'sp = r"""$sp"""\n'
        'whl = r"""${wheelFile.path}"""\n'
        'os.makedirs(sp, exist_ok=True)\n'
        'with zipfile.ZipFile(whl, "r") as z:\n'
        '    z.extractall(sp)\n'
        'print("pip extracted OK")\n',
      );

      final env = await _env;
      final res = await Process.run(exe, [scriptFile.path], environment: env)
          .timeout(const Duration(minutes: 2));

      await wheelFile.delete().catchError((_) {});
      await scriptFile.delete().catchError((_) {});

      if (res.exitCode == 0) {
        _pipAvailable = null; // reset — let isPipAvailable() confirm
        AppLogger.log('LibPython: pip bootstrapped depuis bundle ✓',
            tag: LogTag.zeus, logLevel: LogLevel.info);
        if (await isPipAvailable()) {
          AppLogger.log('LibPython: pip -m pip --version OK ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
        }
      } else {
        AppLogger.log(
            'LibPython: pip bundle extract erreur: ${'${res.stderr}'.trim()}',
            tag: LogTag.zeus, logLevel: LogLevel.warning);
      }
    } on FlutterError {
      AppLogger.log('LibPython: pip.whl absent du bundle APK — bootstrap réseau nécessaire',
          tag: LogTag.zeus, logLevel: LogLevel.info);
    } catch (e) {
      AppLogger.log('LibPython: _ensurePipFromBundle erreur: $e',
          tag: LogTag.zeus, logLevel: LogLevel.warning);
    }
  }

  Future<String> bootstrapPip() async {
    final exe = await pythonExe;
    if (exe == null) return 'ERREUR: libpython.so introuvable';
    _pipAvailable = null;

    // 1st try: bundled wheel (offline, fastest)
    await _ensurePipFromBundle();
    if (await isPipAvailable()) return '✓ pip depuis bundle';

    try {
      final env = await _env;
      final sp = await sitePackagesDir;

      AppLogger.log('LibPython: bootstrap pip via ensurepip...',
          tag: LogTag.zeus, logLevel: LogLevel.info);

      final res = await Process.run(
        exe,
        ['-m', 'ensurepip', '--upgrade', '--default-pip'],
        environment: env,
      ).timeout(const Duration(minutes: 2));

      final out = '${res.stdout}\n${res.stderr}'.trim();

      if (res.exitCode == 0) {
        _pipAvailable = true;
        AppLogger.log('LibPython: pip bootstrapped via ensurepip ✓',
            tag: LogTag.zeus, logLevel: LogLevel.info);
        return '✓ pip installé via ensurepip\n$out';
      }

      AppLogger.log(
          'LibPython: ensurepip échoué (code ${res.exitCode}), tentative via get-pip.py...',
          tag: LogTag.zeus,
          logLevel: LogLevel.warning);

      final dlRes = await Process.run(exe, [
        '-c',
        'import urllib.request; urllib.request.urlretrieve("https://bootstrap.pypa.io/get-pip.py", "/tmp/get-pip.py"); print("OK")',
      ], environment: env).timeout(const Duration(seconds: 30));

      if (dlRes.exitCode != 0) {
        return 'ERREUR: ensurepip échoué et get-pip.py inaccessible\n$out\n${dlRes.stderr}';
      }

      final installRes = await Process.run(
        exe,
        ['/tmp/get-pip.py', '--target', sp, '--no-warn-script-location'],
        environment: env,
      ).timeout(const Duration(minutes: 3));

      final installOut = '${installRes.stdout}\n${installRes.stderr}'.trim();
      if (installRes.exitCode == 0) {
        _pipAvailable = true;
        AppLogger.log('LibPython: pip installé via get-pip.py ✓',
            tag: LogTag.zeus, logLevel: LogLevel.info);
        return '✓ pip installé via get-pip.py\n$installOut';
      }
      return 'ERREUR installation pip:\n$installOut';
    } catch (e, st) {
      AppLogger.log('LibPython: bootstrap pip erreur',
          tag: LogTag.zeus,
          logLevel: LogLevel.error,
          error: e,
          stackTrace: st);
      return 'ERREUR: $e';
    }
  }

  Future<String> installPackage(String packageName) async {
    final exe = await pythonExe;
    if (exe == null) return 'ERREUR: libpython.so introuvable';

    final sp = await sitePackagesDir;
    final env = await _env;

    if (!await isPipAvailable()) await bootstrapPip();

    AppLogger.log('LibPython: pip install $packageName...',
        tag: LogTag.zeus, logLevel: LogLevel.info);

    try {
      final res = await Process.run(
        exe,
        [
          '-m', 'pip', 'install', packageName,
          '--target', sp,
          '--no-warn-script-location',
          '--prefer-binary',
          '-q',
        ],
        environment: env,
      ).timeout(const Duration(minutes: 5));

      _pipAvailable = true;
      final out = '${res.stdout}\n${res.stderr}'.trim();

      if (res.exitCode == 0) {
        AppLogger.log('LibPython: $packageName installé ✓',
            tag: LogTag.zeus, logLevel: LogLevel.info);
        return '✓ $packageName installé\n$out';
      }
      AppLogger.log(
          'LibPython: pip install $packageName ERREUR exit=${res.exitCode}',
          tag: LogTag.zeus,
          logLevel: LogLevel.error);
      return 'ERREUR (code ${res.exitCode}):\n$out';
    } catch (e) {
      return 'ERREUR: $e';
    }
  }

  Future<String> uninstallPackage(String packageName) async {
    final sp = await sitePackagesDir;
    final dir = Directory(sp);
    if (!await dir.exists()) return '$packageName non trouvé';
    final pkgLower = packageName.toLowerCase().replaceAll('-', '_');
    int removed = 0;
    try {
      await for (final e in dir.list()) {
        final n = e.path.split('/').last.toLowerCase();
        if (n == pkgLower ||
            n == '$pkgLower.py' ||
            (n.startsWith(pkgLower) && n.endsWith('.dist-info')) ||
            (n.startsWith(pkgLower) && n.endsWith('.data'))) {
          try {
            if (e is Directory) await e.delete(recursive: true);
            else if (e is File) await e.delete();
            removed++;
          } catch (_) {}
        }
      }
    } catch (e) {
      return 'ERREUR: $e';
    }
    return removed > 0
        ? '✓ $packageName supprimé ($removed éléments)'
        : '$packageName non trouvé dans site-packages';
  }

  Future<List<PythonPackageInfo>> listInstalledPackages() async {
    final sp = await sitePackagesDir;
    final dir = Directory(sp);
    if (!await dir.exists()) return [];

    final packages = <PythonPackageInfo>[];
    try {
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        final name = entry.path.split('/').last;
        if (!name.endsWith('.dist-info')) continue;
        final withoutSuffix = name.substring(0, name.length - '.dist-info'.length);
        final lastDash = withoutSuffix.lastIndexOf('-');
        if (lastDash < 0) continue;
        final pkgName = withoutSuffix.substring(0, lastDash).replaceAll('_', '-');
        final version = withoutSuffix.substring(lastDash + 1);
        packages.add(PythonPackageInfo(name: pkgName, version: version));
      }
    } catch (_) {}

    packages.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return packages;
  }

  Future<Map<String, bool>> checkZeusDeps() async {
    final installed = await listInstalledPackages();
    final installedNames = installed
        .map((p) => p.name.toLowerCase().replaceAll('-', '_'))
        .toSet();

    final result = <String, bool>{};
    for (final pkg in zeusRequiredPackages) {
      final normalized = pkg.toLowerCase().replaceAll('-', '_');
      result[pkg] = installedNames.contains(normalized);
    }
    return result;
  }


  // ── Plugin-generic dep resolution ────────────────────────────────────────

  /// Résout et installe les dépendances Python pour n'importe quel plugin.
  ///
  /// [pluginId]   : identifiant du plugin (ex: 'telegram', 'discord')
  /// [pluginDeps] : liste des packages Python requis
  /// [markerKey]  : clé optionnelle pour le fichier marqueur (défaut: pluginId)
  /// [onProgress] : callback de progression (optionnel)
  Future<String> resolvePluginDeps({
    required String pluginId,
    required List<String> pluginDeps,
    String? markerKey,
    void Function(String msg)? onProgress,
  }) async {
    final exe = await pythonExe;
    if (exe == null) return 'libpython.so introuvable — skip';

    final fd = await _filesDir;
    final key = markerKey ?? pluginId.replaceAll('.', '_');
    final markerFile = File('$fd/python_packages/.deps_ok_$key');

    final depsHash = sha256.convert(utf8.encode(pluginDeps.join(','))).toString();
    if (await markerFile.exists()) {
      final stored = (await markerFile.readAsString()).trim();
      if (stored == depsHash) return 'Dépendances $pluginId déjà installées ✓';
    }

    // Vérifier si les deps sont déjà vendées dans le bundle du plugin
    final bundleDir = '$fd/plugins/$pluginId';
    if (await _areDepsInPluginBundle(bundleDir, pluginDeps)) {
      AppLogger.log(
          'LibPython: deps $pluginId dans le bundle — skip pip',
          tag: LogTag.zeus, logLevel: LogLevel.debug);
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
      return 'Dépendances $pluginId présentes dans le bundle ✓';
    }

    final installed = await listInstalledPackages();
    final installedNames = installed
        .map((p) => p.name.toLowerCase().replaceAll('-', '_'))
        .toSet();

    final missing = pluginDeps.where((pkg) {
      final normalized = pkg.toLowerCase().replaceAll('-', '_');
      return !installedNames.contains(normalized);
    }).toList();

    if (missing.isEmpty) {
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
      AppLogger.log(
          'LibPython: dépendances $pluginId toutes présentes ✓',
          tag: LogTag.zeus, logLevel: LogLevel.debug);
      return 'Toutes les dépendances $pluginId sont présentes ✓';
    }

    AppLogger.log(
        'LibPython: installation deps $pluginId manquantes: ${missing.join(", ")}',
        tag: LogTag.zeus, logLevel: LogLevel.info);
    onProgress?.call('$pluginId — installation: ${missing.join(", ")}...');

    final sp = await sitePackagesDir;
    final env = await _env;
    final results = <String>[];

    // ── Ensure pip is ready before any install attempt ────────────────────────
    // pip is bootstrapped from assets/wheels/pip.whl at first launch by
    // ensureStdlib(), but we double-check here in case resolvePluginDeps
    // is called before ensureStdlib() completes.
    const _bundledWheels   = <String>{'tgcrypto', 'pyrogram'};
    const _binaryOnlyPkgs  = <String>{'tgcrypto'};
    const _optionalPackages = <String>{'tgcrypto'};

    if (!await isPipAvailable()) {
      onProgress?.call('Bootstrap pip depuis bundle...');
      await bootstrapPip();
      _pipAvailable = null;
    }

    for (final pkg in missing) {
      onProgress?.call('$pluginId — installation de $pkg...');
      bool pkgInstalled = false;

      // 1️⃣ Bundled wheel — fast, offline, no network (still useful for tgcrypto/pyrogram)
      if (_bundledWheels.contains(pkg.toLowerCase())) {
        pkgInstalled = await _installFromBundledWheel(pkg, sp, env, exe);
        if (pkgInstalled) {
          results.add('✓ $pkg (bundle)');
          AppLogger.log('LibPython: $pkg installé depuis le bundle ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
          continue;
        }
        AppLogger.log('LibPython: wheel bundle absent pour $pkg — fallback pip',
            tag: LogTag.zeus, logLevel: LogLevel.debug);
      }

      // 2️⃣ pip install (pip is now always available via bootstrapped bundle)
      final binaryOnly = _binaryOnlyPkgs.contains(pkg.toLowerCase());
      final isOptional = _optionalPackages.contains(pkg.toLowerCase());

      if (!await isPipAvailable()) {
        results.add('${isOptional ? "⚠" : "✗"} $pkg (pip indisponible)');
        AppLogger.log(
            isOptional
                ? 'LibPython: $pkg ignoré (optionnel) — pyrogram utilise pyaes comme fallback ✓'
                : 'LibPython: pip absent — impossible d\'installer $pkg (requis)',
            tag: LogTag.zeus, logLevel: LogLevel.warning);
        continue;
      }

      try {
        final res = await Process.run(
          exe,
          [
            '-m', 'pip', 'install', pkg,
            '--target', sp,
            '--no-warn-script-location',
            '--prefer-binary',
            if (binaryOnly) '--only-binary', if (binaryOnly) ':all:',
          ],
          environment: env,
        ).timeout(const Duration(minutes: 3));

        if (res.exitCode == 0) {
          results.add('✓ $pkg (pip)');
          AppLogger.log('LibPython: $pkg installé via pip ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
        } else {
          results.add('${isOptional ? "⚠" : "✗"} $pkg');
          final errLines = (res.stderr as String)
              .split('\n').where((l) => l.trim().isNotEmpty).toList();
          AppLogger.log(
              'LibPython: $pkg ERREUR: ${errLines.isEmpty ? "(vide)" : errLines.last}',
              tag: LogTag.zeus, logLevel: LogLevel.warning);
        }
      } catch (e) {
        results.add('${isOptional ? "⚠" : "✗"} $pkg ($e)');
      }
    }

    // Marker: write even if optional packages (tgcrypto) failed.
    final criticalFailed = missing
        .where((p) => !_optionalPackages.contains(p.toLowerCase()))
        .any((p) => results.any((r) => r.startsWith('✗') && r.contains(p)));
    if (!criticalFailed) {
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
    }
    return results.join('\n');
  }

  /// Installs [packageName] from a pre-compiled wheel bundled in Flutter assets.
  ///
  /// Asset path: `assets/wheels/<packagename>.whl` (lower-case).
  /// Uses Python's zipfile module to extract — no pip required.
  /// Returns true on success, false if the asset is absent or extraction fails.
  Future<bool> _installFromBundledWheel(
    String packageName,
    String sitePackagesDir,
    Map<String, String> env,
    String pythonExePath,
  ) async {
    final assetKey = 'assets/wheels/${packageName.toLowerCase()}.whl';
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List();

      final tmp = await getTemporaryDirectory();
      final wheelFile = File('${tmp.path}/${packageName.toLowerCase()}.whl');
      await wheelFile.writeAsBytes(bytes);

      AppLogger.log(
          'LibPython: install $packageName depuis bundle (${bytes.length} bytes)…',
          tag: LogTag.zeus, logLevel: LogLevel.info);

      // Extract the wheel via Python's zipfile module — no pip required.
      // .whl files are zip archives; extracting to site-packages makes them importable.
      final scriptFile = File('${tmp.path}/whl_${packageName.toLowerCase()}.py');
      await scriptFile.writeAsString(
        'import zipfile, os\n'
        'sp = r"""$sitePackagesDir"""\n'
        'whl = r"""${wheelFile.path}"""\n'
        'os.makedirs(sp, exist_ok=True)\n'
        'with zipfile.ZipFile(whl, "r") as z:\n'
        '    z.extractall(sp)\n'
        'print("OK:", whl)\n',
      );

      final res = await Process.run(
        pythonExePath,
        [scriptFile.path],
        environment: env,
      ).timeout(const Duration(minutes: 2));

      await wheelFile.delete().catchError((_) {});
      await scriptFile.delete().catchError((_) {});

      if (res.exitCode == 0) {
        AppLogger.log('LibPython: $packageName extrait via zipfile ✓',
            tag: LogTag.zeus, logLevel: LogLevel.info);
        return true;
      }
      AppLogger.log(
          'LibPython: zipfile extract $packageName: ${'${res.stderr}'.trim()}',
          tag: LogTag.zeus, logLevel: LogLevel.warning);
      return false;
    } on FlutterError {
      return false; // Asset absent du bundle
    } catch (e) {
      AppLogger.log('LibPython: bundled wheel erreur ($packageName): $e',
          tag: LogTag.zeus, logLevel: LogLevel.warning);
      return false;
    }
  }


  /// Ensures all ZeusDL deps are installed. Fire-and-forget safe.
  Future<String> ensureZeusDlDeps({void Function(String msg)? onProgress}) async {
    final exe = await pythonExe;
    if (exe == null) return 'libpython.so introuvable — skip';

    final fd = await _filesDir;
    final markerFile = File('$fd/python_packages/.zeus_deps_ok');
    final depsHash = sha256
        .convert(utf8.encode(zeusRequiredPackages.join(',')))
        .toString();

    if (_depsEnsured && await markerFile.exists()) {
      final stored = (await markerFile.readAsString()).trim();
      if (stored == depsHash) return 'Dépendances ZeusDL déjà installées ✓';
    }

    // Court-circuit si les deps ZeusDL sont déjà dans le bundle extrait
    const _zeusBundleDeps = ['requests', 'certifi', 'urllib3', 'websockets', 'mutagen'];
    final zeusBundleDir = '$fd/plugins/zeusdl';
    if (await _areDepsInPluginBundle(zeusBundleDir, List.from(_zeusBundleDeps))) {
      _depsEnsured = true;
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
      AppLogger.log(
          'LibPython: deps ZeusDL dans le bundle — skip pip',
          tag: LogTag.zeus, logLevel: LogLevel.debug);
      return 'Dépendances ZeusDL présentes dans le bundle ✓';
    }

    final depsStatus = await checkZeusDeps();
    final missing =
        depsStatus.entries.where((e) => !e.value).map((e) => e.key).toList();

    if (missing.isEmpty) {
      _depsEnsured = true;
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
      AppLogger.log(
          'LibPython: toutes les dépendances ZeusDL présentes ✓',
          tag: LogTag.zeus,
          logLevel: LogLevel.debug);
      return 'Toutes les dépendances ZeusDL sont déjà installées ✓';
    }

    AppLogger.log(
        'LibPython: installation dépendances ZeusDL manquantes: ${missing.join(", ")}',
        tag: LogTag.zeus,
        logLevel: LogLevel.info);
    onProgress?.call('Installation: ${missing.join(", ")}...');

    // pip is bootstrapped from bundle by ensureStdlib(); double-check here.
    if (!await isPipAvailable()) {
      onProgress?.call('Bootstrap pip depuis bundle...');
      await bootstrapPip();
      _pipAvailable = null;
      if (!await isPipAvailable()) {
        return 'ERREUR: pip non disponible après bootstrap.';
      }
    }

    final sp = await sitePackagesDir;
    final env = await _env;
    final results = <String>[];

    for (final pkg in missing) {
      onProgress?.call('Installation de $pkg...');
      try {
        final res = await Process.run(
          exe,
          [
            '-m', 'pip', 'install', pkg,
            '--target', sp,
            '--no-warn-script-location',
            '--prefer-binary',
            '--no-cache-dir',
            '--index-url', 'https://pypi.org/simple/',
            '--trusted-host', 'pypi.org',
            '--trusted-host', 'files.pythonhosted.org',
          ],
          environment: env,
        ).timeout(const Duration(minutes: 3));

        final out = '${res.stdout}\n${res.stderr}'.trim();
        if (res.exitCode == 0) {
          results.add('✓ $pkg');
          AppLogger.log('LibPython: $pkg installé ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
        } else {
          results.add('✗ $pkg (code ${res.exitCode})');
          AppLogger.log(
              'LibPython: $pkg ERREUR (${res.exitCode}): $out',
              tag: LogTag.zeus,
              logLevel: LogLevel.warning);
        }
      } catch (e) {
        results.add('✗ $pkg ($e)');
      }
    }

    final allOk = results.every((r) => r.startsWith('✓'));
    if (allOk) {
      _depsEnsured = true;
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(depsHash);
    }

    return results.join('\n');
  }

  /// Checks whether [deps] are present as importable modules in [bundleDir].
  Future<bool> _areDepsInPluginBundle(String bundleDir, List<String> deps) async {
    if (!await Directory(bundleDir).exists()) return false;
    for (final dep in deps) {
      final normalized = dep.toLowerCase().replaceAll('-', '_');
      final modDir  = Directory('$bundleDir/$normalized');
      final modFile = File('$bundleDir/$normalized.py');
      if (!await modDir.exists() && !await modFile.exists()) return false;
    }
    return true;
  }
}
