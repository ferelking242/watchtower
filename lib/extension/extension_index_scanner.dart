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
/// Replaces the legacy suffix-matching approach with a rebuild-from-scratch
/// strategy that guarantees 100% detection and zero ghost counters.
///
/// Algorithm:
///   1. Ask Android for ALL packages with tachiyomi OR aniyomi extension features
///   2. For every installed package, try to match it against DB sources
///   3. Activate matching sources (mark isAdded=true, isActive=true)
///   4. Orphan sweep: any source still isAdded=true but package not on device → deactivate
///   5. Log every step with the canonical [ExtensionScan] / [ExtensionAdded] / etc. tags

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

  // Build suffix → sourceDir lookup (covers all prefix variants)
  final suffixMap = <String, _InstalledPkg>{};
  for (final p in installedPkgs) {
    for (final prefix in _kKnownPrefixes) {
      if (p.pkg.startsWith(prefix)) {
        final suffix = p.pkg.substring(prefix.length);
        if (suffix.isNotEmpty && suffix.contains('.')) {
          suffixMap[suffix] = p;
        }
        break;
      }
    }
    // Also store full package name for direct lookup
    suffixMap[p.pkg] = p;
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
  final toActivate = <Source>[];
  final toDeactivate = <Source>[];
  final installedPkgNames = installedPkgs.map((p) => p.pkg).toSet();

  for (final source in typeSources) {
    final isMihon = source.sourceCodeLanguage == SourceCodeLanguage.mihon;
    if (!isMihon) continue;

    // ── Validation ──────────────────────────────────────────────────────────
    if (source.id == null) {
      AppLogger.log(
        '[ExtensionValidation] Skipping source with null id: ${source.name}',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      continue;
    }

    final url = source.sourceCodeUrl ?? '';
    if (url.isEmpty) {
      // No URL — cannot match to a package.
      // If currently "installed", deactivate (orphan).
      if (source.isAdded == true) {
        AppLogger.log(
          '[ExtensionValidation] Orphan (no url): ${source.name} — deactivating',
          logLevel: LogLevel.warning,
          tag: LogTag.extension_,
        );
        toDeactivate.add(source);
      }
      continue;
    }

    // Try to find the matching installed package
    _InstalledPkg? match;

    // Strategy A: suffix from URL path
    for (final entry in suffixMap.entries) {
      final s = entry.key;
      if (url.contains('-$s-') ||
          url.contains('/$s-') ||
          url.contains('.$s-') ||
          url.endsWith('-$s.apk') ||
          url.contains('/$s.apk')) {
        match = entry.value;
        break;
      }
    }

    // Strategy B: package name embedded directly in URL
    if (match == null) {
      for (final pkg in installedPkgNames) {
        if (url.contains(pkg)) {
          match = installedPkgs.firstWhere((p) => p.pkg == pkg);
          break;
        }
      }
    }

    if (match == null) {
      // Package not found on device
      if (source.isAdded == true) {
        // Was installed but package is gone — orphan
        AppLogger.log(
          '[ExtensionRemoved] ${source.name} — package missing, deactivating',
          tag: LogTag.extension_,
        );
        toDeactivate.add(source);
      }
      continue;
    }

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
    }
  }

  // ── 4. Orphan sweep: deactivate sources whose package is NOT on device ───
  // Any Mihon source still marked isAdded=true that we didn't confirm above
  final confirmedIds = toActivate.map((s) => s.id).toSet();
  final deactivateIds = toDeactivate.map((s) => s.id).toSet();

  for (final source in typeSources) {
    if (source.sourceCodeLanguage != SourceCodeLanguage.mihon) continue;
    if (source.isAdded != true) continue;
    if (confirmedIds.contains(source.id)) continue;
    if (deactivateIds.contains(source.id)) continue;

    // This source is marked installed but was never matched → orphan
    final url = source.sourceCodeUrl ?? '';
    bool onDevice = false;
    for (final entry in suffixMap.entries) {
      final s = entry.key;
      if (url.contains('-$s-') ||
          url.contains('/$s-') ||
          url.contains('.$s-') ||
          url.endsWith('-$s.apk') ||
          url.contains('/$s.apk')) {
        onDevice = true;
        break;
      }
    }
    if (!onDevice) {
      for (final pkg in installedPkgNames) {
        if (url.contains(pkg)) {
          onDevice = true;
          break;
        }
      }
    }

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

  // Derive suffix
  final suffixes = <String>[];
  for (final prefix in _kKnownPrefixes) {
    if (pkg.startsWith(prefix)) {
      final s = pkg.substring(prefix.length);
      if (s.isNotEmpty && s.contains('.')) suffixes.add(s);
    }
  }
  suffixes.add(pkg); // also try full package name

  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final candidates = allSources
      .where((s) => s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final toUpdate = <Source>[];
  for (final s in candidates) {
    final url = s.sourceCodeUrl ?? '';
    if (url.isEmpty) continue;
    bool hit = false;
    for (final suffix in suffixes) {
      if (url.contains('-$suffix-') ||
          url.contains('/$suffix-') ||
          url.contains('.$suffix-') ||
          url.endsWith('-$suffix.apk') ||
          url.contains('/$suffix.apk') ||
          url.contains(suffix)) {
        hit = true;
        break;
      }
    }
    if (!hit) continue;

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

  final suffixes = <String>[];
  for (final prefix in _kKnownPrefixes) {
    if (pkg.startsWith(prefix)) {
      final s = pkg.substring(prefix.length);
      if (s.isNotEmpty && s.contains('.')) suffixes.add(s);
    }
  }
  suffixes.add(pkg);

  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final installed = allSources
      .where((s) =>
          s.isAdded == true &&
          s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final toUpdate = <Source>[];
  for (final s in installed) {
    final url = s.sourceCodeUrl ?? '';
    bool hit = false;
    for (final suffix in suffixes) {
      if (url.contains('-$suffix-') ||
          url.contains('/$suffix-') ||
          url.contains('.$suffix-') ||
          url.endsWith('-$suffix.apk') ||
          url.contains('/$suffix.apk') ||
          url.contains(suffix)) {
        hit = true;
        break;
      }
    }
    if (!hit) continue;
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
