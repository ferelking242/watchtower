import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

class PythonPackageInfo {
  final String name;
  final String version;
  const PythonPackageInfo({required this.name, required this.version});
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

  Future<String?> get _nativeDir async {
    if (_cachedNativeDir != null) return _cachedNativeDir;
    try {
      final result = await _channel.invokeMethod<String>('getNativeLibraryDir');
      _cachedNativeDir = result;
      return result;
    } catch (_) {
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

  Future<String> get sitePackagesDir async {
    final fd = await _filesDir;
    final dir = Directory('$fd/python_packages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

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
    } catch (_) {
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

  Future<String> bootstrapPip() async {
    final exe = await pythonExe;
    if (exe == null) return 'ERREUR: libpython.so introuvable';
    _pipAvailable = null;

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
  /// [pluginId]   : identifiant du plugin (ex: "com.watchtower.telegram-source")
  /// [pluginDeps] : liste des packages requis par le plugin
  /// [markerKey]  : clé unique pour le fichier marqueur (évite double-install)
  /// Vérifie si les deps sont déjà vendorées dans le bundle extrait du plugin.
    /// Si c'est le cas, on court-circuite pip install (inutile + lent sur réseau mobile).
    Future<bool> _areDepsInPluginBundle(
        String pluginExtractDir, List<String> deps) async {
      for (final dep in deps) {
        final normalized = dep.replaceAll('-', '_').toLowerCase();
        final dir = Directory('$pluginExtractDir/$normalized');
        if (!await dir.exists()) return false;
      }
      return true;
    }

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

    if (await markerFile.exists()) {
      return 'Dépendances $pluginId déjà installées ✓';
    }

    // Vérifier si les deps sont déjà vendées dans le bundle du plugin
    final bundleDir = '$fd/plugins/$pluginId';
    if (await _areDepsInPluginBundle(bundleDir, pluginDeps)) {
      AppLogger.log(
          'LibPython: deps $pluginId dans le bundle — skip pip',
          tag: LogTag.zeus, logLevel: LogLevel.debug);
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(DateTime.now().toIso8601String());
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
      await markerFile.writeAsString(DateTime.now().toIso8601String());
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

    for (final pkg in missing) {
      onProgress?.call('$pluginId — installation de $pkg...');
      try {
        final res = await Process.run(
          exe,
          ['-m', 'pip', 'install', pkg,
           '--target', sp,
           '--no-warn-script-location',
           '--prefer-binary', '-q'],
          environment: env,
        ).timeout(const Duration(minutes: 3));

        if (res.exitCode == 0) {
          results.add('✓ $pkg');
          AppLogger.log('LibPython: $pkg installé ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
        } else {
          results.add('✗ $pkg');
          AppLogger.log(
              'LibPython: $pkg ERREUR: ${(res.stderr as String).split("\n").last}',
              tag: LogTag.zeus, logLevel: LogLevel.warning);
        }
      } catch (e) {
        results.add('✗ $pkg ($e)');
      }
    }

    final allOk = results.every((r) => r.startsWith('✓'));
    if (allOk) {
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(DateTime.now().toIso8601String());
    }

    return results.join('\n');
  }


  /// Ensures all ZeusDL deps are installed. Fire-and-forget safe.
  Future<String> ensureZeusDlDeps({void Function(String msg)? onProgress}) async {
    final exe = await pythonExe;
    if (exe == null) return 'libpython.so introuvable — skip';

    final fd = await _filesDir;
    final markerFile = File('$fd/python_packages/.zeus_deps_ok');

    if (_depsEnsured && await markerFile.exists()) {
      return 'Dépendances ZeusDL déjà installées ✓';
    }

    // Court-circuit si les deps ZeusDL sont déjà dans le bundle extrait
    const _zeusBundleDeps = ['requests', 'certifi', 'urllib3', 'websockets', 'mutagen'];
    final zeusBundleDir = '$fd/plugins/zeusdl';
    if (await _areDepsInPluginBundle(zeusBundleDir, List.from(_zeusBundleDeps))) {
      _depsEnsured = true;
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(DateTime.now().toIso8601String());
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
      await markerFile.writeAsString(DateTime.now().toIso8601String());
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
            '-q',
          ],
          environment: env,
        ).timeout(const Duration(minutes: 3));

        if (res.exitCode == 0) {
          results.add('✓ $pkg');
          AppLogger.log('LibPython: $pkg installé ✓',
              tag: LogTag.zeus, logLevel: LogLevel.info);
        } else {
          results.add('✗ $pkg');
          AppLogger.log(
              'LibPython: $pkg ERREUR: ${(res.stderr as String).split('\n').last}',
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
      await markerFile.writeAsString(DateTime.now().toIso8601String());
    }

    return results.join('\n');
  }
}
