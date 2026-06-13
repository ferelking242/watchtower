import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Full extension index scanner.
///
/// Algorithm:
///   1. Ask Android for ALL packages with tachiyomi OR aniyomi extension features
///   2. For every DB source, try to match it against installed packages
///      using CASE-INSENSITIVE URL comparison (fixes Keiyoushi CamelCase APKs)
///   3. Activate matching sources (mark isAdded=true, isActive=true)
///   4. Orphan sweep: any Mihon source still isAdded=true but package not
///      on device → deactivate
///
/// Root cause of the "only 6-17 out of 30+ show" bug:
///   Keiyoushi names APKs like `tachiyomi-en.MangaDex-v13.4.22.apk`
///   but Android package names are always lowercase:
///   `eu.kanade.tachiyomi.extension.en.mangadex`
///   The old code did case-SENSITIVE String.contains() → no match for
///   any extension whose APK filename uses CamelCase.
///   Fix: all URL matching is now toLowerCase() on both sides.

const _kLoaderChannel = MethodChannel('com.watchtower.app.ext_loader');

// ─── Public API ───────────────────────────────────────────────────────────────

/// Full index rebuild for [itemType].
/// Call after fetching the extension index from the repo server.
Future<void> rebuildExtensionIndex({
  required ItemType itemType,
  required String androidProxyServer,
}) async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;

  AppLogger.log(
    '[ExtensionScan] Starting full index rebuild for type=${itemType.name}',
    tag: LogTag.extension_,
  );

  // ── 1. Collect installed packages from Android ──────────────────────────
  final installedPkgs = <_InstalledPkg>[];

  try {
    final rawShared =
        await _kLoaderChannel.invokeListMethod('getInstalledExtensions') ?? [];
    for (final raw in rawShared.cast<Map>()) {
      final pkg = raw['pkg'] as String? ?? '';
      final dir = raw['sourceDir'] as String? ?? '';
      if (pkg.isNotEmpty && dir.isNotEmpty) {
        installedPkgs.add(_InstalledPkg(pkg: pkg, sourceDir: dir));
        AppLogger.log(
          '[ExtensionScan] Found package $pkg',
          tag: LogTag.extension_,
        );
      }
    }
  } catch (e) {
    AppLogger.log(
      '[ExtensionScan] Shared package scan error: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
  }

  // Private .ext files
  try {
    final rawPriv =
        await _kLoaderChannel.invokeListMethod('listPrivateExtensions') ?? [];
    for (final raw in rawPriv.cast<Map>()) {
      final path = raw['path'] as String? ?? '';
      final filename = raw['filename'] as String? ?? path.split('/').last;
      if (path.isNotEmpty) {
        final pkg = filename.replaceAll('.ext', '');
        installedPkgs.add(_InstalledPkg(pkg: pkg, sourceDir: path));
        AppLogger.log(
          '[ExtensionScan] Found private extension $pkg',
          tag: LogTag.extension_,
        );
      }
    }
  } catch (e) {
    AppLogger.log(
      '[ExtensionScan] Private extension scan error: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
  }

  AppLogger.log(
    '[ExtensionScan] Total packages found: ${installedPkgs.length} | type=${itemType.name}',
    tag: LogTag.extension_,
  );

  if (installedPkgs.isEmpty) {
    AppLogger.log(
      '[ExtensionScan] No extension packages on device — nothing to activate',
      tag: LogTag.extension_,
    );
    return;
  }

  // ── 2. Load all DB sources for this type ──────────────────────────────────
  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final typeSources = allSources
      .where((s) => s.itemType == itemType && s.id != null)
      .toList();

  AppLogger.log(
    '[ExtensionCache] ${typeSources.length} sources in DB for type=${itemType.name}',
    tag: LogTag.extension_,
  );

  // ── 3. Match: activate sources that have a device package ──────────────────
  final toActivate   = <Source>[];
  final toDeactivate = <Source>[];
  final confirmedIds = <int>{};

  for (final source in typeSources) {
    final isMihon = source.sourceCodeLanguage == SourceCodeLanguage.mihon;
    if (!isMihon) continue;

    if (source.id == null) {
      AppLogger.log(
        '[ExtensionValidation] Skipping source with null id: ${source.name}',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      continue;
    }

    final url = source.sourceCodeUrl ?? '';

    // Find the matching installed package using case-insensitive URL matching
    _InstalledPkg? match;
    for (final p in installedPkgs) {
      if (_pkgMatchesUrl(p.pkg, url)) {
        match = p;
        break;
      }
    }

    if (match == null) {
      if (source.isAdded == true) {
        AppLogger.log(
          '[ExtensionRemoved] ${source.name} — package missing, deactivating',
          tag: LogTag.extension_,
        );
        toDeactivate.add(source);
      }
      continue;
    }

    confirmedIds.add(source.id!);

    // Package exists — validate the APK is readable
    bool apkOk = false;
    String? sourceCode;
    try {
      final bytes = await File(match.sourceDir).readAsBytes();
      sourceCode = base64.encode(bytes);
      apkOk = true;
    } catch (e) {
      AppLogger.log(
        '[ExtensionValidation] Cannot read APK for ${source.name}: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    }

    if (!apkOk) {
      if (source.isAdded == true) {
        toDeactivate.add(source);
      }
      continue;
    }

    AppLogger.log(
      '[ExtensionValidation] Success: ${source.name} ← ${match.pkg}',
      tag: LogTag.extension_,
    );

    // Only update if not already activated (avoid unnecessary writes)
    if (source.isAdded != true || source.isActive != true || source.sourceCode.isNullOrEmpty) {
      toActivate.add(source
        ..sourceCode = sourceCode
        ..isAdded = true
        ..isActive = true);
      AppLogger.log(
        '[ExtensionAdded] ${source.name} [${source.lang}]',
        tag: LogTag.extension_,
      );
    } else {
      // Already activated — still count as confirmed (not an orphan)
      AppLogger.log(
        '[ExtensionScan] Already active: ${source.name}',
        tag: LogTag.extension_,
      );
    }
  }

  // ── 4. Orphan sweep: deactivate sources whose package is NOT on device ───
  final deactivateIds = toDeactivate.map((s) => s.id).toSet();

  for (final source in typeSources) {
    if (source.sourceCodeLanguage != SourceCodeLanguage.mihon) continue;
    if (source.isAdded != true) continue;
    if (confirmedIds.contains(source.id)) continue;
    if (deactivateIds.contains(source.id)) continue;

    // This source is marked installed but was never matched → orphan
    final url = source.sourceCodeUrl ?? '';
    bool onDevice = installedPkgs.any((p) => _pkgMatchesUrl(p.pkg, url));

    if (!onDevice) {
      AppLogger.log(
        '[ExtensionCache] Orphan removed: ${source.name} (id=${source.id})',
        tag: LogTag.extension_,
      );
      toDeactivate.add(source
        ..sourceCode = ''
        ..isAdded = false
        ..isActive = false);
    }
  }

  // ── 5. Write to DB ─────────────────────────────────────────────────────────
  final allWrites = [...toActivate, ...toDeactivate];
  if (allWrites.isNotEmpty) {
    await isar.writeTxn(() async => isar.sources.putAll(allWrites));
    AppLogger.log(
      '[ExtensionScan] DB updated: ${toActivate.length} activated, '
      '${toDeactivate.length} deactivated | type=${itemType.name}',
      tag: LogTag.extension_,
    );
  } else {
    AppLogger.log(
      '[ExtensionScan] No DB changes needed | type=${itemType.name}',
      tag: LogTag.extension_,
    );
  }
}

// ─── Package-change handler (called from extension_watcher) ───────────────────

/// Handle a newly installed / updated extension package.
Future<void> handlePackageInstalled({
  required String pkg,
  required String sourceDir,
}) async {
  AppLogger.log(
    '[PackageChanged] INSTALLED $pkg → $sourceDir',
    tag: LogTag.extension_,
  );

  // Validate the APK is readable
  String sourceCode;
  try {
    final bytes = await File(sourceDir).readAsBytes();
    sourceCode = base64.encode(bytes);
  } catch (e) {
    AppLogger.log(
      '[PackageChanged] Cannot read APK for $pkg: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
    return;
  }

  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final candidates = allSources
      .where((s) => s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final toUpdate = <Source>[];
  for (final s in candidates) {
    final url = s.sourceCodeUrl ?? '';
    if (url.isEmpty) continue;
    if (!_pkgMatchesUrl(pkg, url)) continue;

    AppLogger.log(
      '[ExtensionValidation] Success: ${s.name} ← $pkg',
      tag: LogTag.extension_,
    );
    toUpdate.add(s
      ..sourceCode = sourceCode
      ..isAdded = true
      ..isActive = true);
    AppLogger.log(
      '[ExtensionAdded] ${s.name} [${s.lang}]',
      tag: LogTag.extension_,
    );
  }

  if (toUpdate.isNotEmpty) {
    await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
    AppLogger.log(
      '[PackageChanged] ${toUpdate.length} source(s) activated for $pkg',
      tag: LogTag.extension_,
    );
  }
}

/// Handle a removed extension package.
Future<void> handlePackageRemoved(String pkg) async {
  AppLogger.log(
    '[PackageChanged] REMOVED $pkg',
    tag: LogTag.extension_,
  );

  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final installed = allSources
      .where((s) =>
          s.isAdded == true &&
          s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final toUpdate = <Source>[];
  for (final s in installed) {
    final url = s.sourceCodeUrl ?? '';
    if (url.isEmpty) continue;
    if (!_pkgMatchesUrl(pkg, url)) continue;

    AppLogger.log(
      '[ExtensionRemoved] ${s.name} — package $pkg removed',
      tag: LogTag.extension_,
    );
    toUpdate.add(s
      ..sourceCode = ''
      ..isAdded = false
      ..isActive = false);
  }

  if (toUpdate.isNotEmpty) {
    await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
    AppLogger.log(
      '[PackageChanged] ${toUpdate.length} source(s) deactivated for $pkg',
      tag: LogTag.extension_,
    );
  }
}

// ─── Core matching helper ─────────────────────────────────────────────────────

/// Returns true if Android package [pkg] corresponds to the extension at [url].
///
/// CASE-INSENSITIVE: Keiyoushi / yuzono / kareadita name APK files with
/// CamelCase (e.g. `tachiyomi-en.MangaDex-v13.4.22.apk`) while Android
/// package names are always lowercase (`eu.kanade.tachiyomi.extension.en.mangadex`).
/// Using case-sensitive String.contains() caused ~80% of extensions to go
/// undetected. This function normalises both sides to lowercase first.
///
/// Matching strategies (in order):
///   1. Full package name appears literally in the URL
///   2. Package suffix (after stripping known prefix) appears in the URL
///      with any of the common separator/boundary patterns used by all repos
bool _pkgMatchesUrl(String pkg, String url) {
  if (url.isEmpty || pkg.isEmpty) return false;
  final u = url.toLowerCase();

  // Strategy 1: full package name embedded in URL (e.g. custom repos)
  if (u.contains(pkg.toLowerCase())) return true;

  // Strategy 2: strip known prefix → suffix, then look for it in the URL
  for (final prefix in _kKnownPrefixes) {
    if (pkg.startsWith(prefix)) {
      final suffix = pkg.substring(prefix.length).toLowerCase();
      // e.g. suffix = "en.mangadex"
      if (suffix.isEmpty || !suffix.contains('.')) break;
      if (u.contains('-$suffix-') ||     // tachiyomi-en.mangadex-v...
          u.contains('/$suffix-') ||     // /en.mangadex-v...
          u.contains('.$suffix-') ||     // .en.mangadex-v...
          u.contains('-$suffix.apk') ||  // ...-en.mangadex.apk
          u.contains('/$suffix.apk')) {  // /en.mangadex.apk
        return true;
      }
      break;
    }
  }

  return false;
}

// ─── Internals ────────────────────────────────────────────────────────────────

const _kKnownPrefixes = [
  'eu.kanade.tachiyomi.extension.',
  'eu.kanade.tachiyomi.animeextension.',
  'eu.kanade.tachiyomi.ext.',
  'eu.kanade.tachiyomi.animext.',
  'xyz.aniyomi.extension.',
  'xyz.aniyomi.animeextension.',
  'com.mihon.extension.',
];

class _InstalledPkg {
  final String pkg;
  final String sourceDir;
  const _InstalledPkg({required this.pkg, required this.sourceDir});
}

extension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
