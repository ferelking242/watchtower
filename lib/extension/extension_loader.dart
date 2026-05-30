import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Clone of Mihon's ExtensionLoader.kt
///
/// Scans two sources — exactly as Mihon does:
///   1. Shared   — system-installed APKs detected via `reqFeatures "tachiyomi.extension"`
///                 (NOT package-name prefix; this catches ANY compatible app's extensions)
///   2. Private  — .ext files in the app's own filesDir/exts/ dir (no system installer needed)
///
/// APK bytes are read straight from `sourceDir` on device — zero network requests.
/// After a batch DB write the sources appear in Browse exactly like Market installs.

const _kLoaderChannel = MethodChannel('com.watchtower.app.ext_loader');

/// Scan + activate all device extensions for [itemType].
/// Call once after the index repos have been loaded into DB.
Future<void> syncExtensions({
  required ItemType itemType,
  required String androidProxyServer,
}) async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;

  final entries = <({String sourceDir, String? pkg})>[];

  // ── 1a. Shared extensions (system PackageManager, reqFeatures detection) ──
  try {
    final rawList =
        await _kLoaderChannel.invokeListMethod('getInstalledExtensions') ?? [];
    for (final raw in rawList.cast<Map>()) {
      final pkg = raw['pkg'] as String? ?? '';
      final dir = raw['sourceDir'] as String? ?? '';
      if (pkg.isNotEmpty && dir.isNotEmpty) entries.add((sourceDir: dir, pkg: pkg));
    }
  } catch (e) {
    AppLogger.log(
      'ext_loader: shared scan error: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
  }

  // ── 1b. Private extensions (filesDir/exts/*.ext) ───────────────────────
  try {
    final rawList =
        await _kLoaderChannel.invokeListMethod('listPrivateExtensions') ?? [];
    for (final raw in rawList.cast<Map>()) {
      final path = raw['path'] as String? ?? '';
      if (path.isNotEmpty) entries.add((sourceDir: path, pkg: null));
    }
  } catch (e) {
    AppLogger.log(
      'ext_loader: private scan error: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
  }

  if (entries.isEmpty) return;
  AppLogger.log(
    'ext_loader: ${entries.length} extension(s) on device | type=$itemType',
    tag: LogTag.extension_,
  );

  // ── 2. Match against DB sources that are not yet installed ─────────────
  final notInstalled = await isar.sources
      .filter()
      .itemTypeEqualTo(itemType)
      .isAddedEqualTo(false)
      .sourceCodeLanguageEqualTo(SourceCodeLanguage.mihon)
      .findAll();

  // Build suffix→sourceDir lookup once
  // pkg: eu.kanade.tachiyomi.extension.en.cubari      → suffix en.cubari
  //      eu.kanade.tachiyomi.animeextension.en.gogoanime → suffix en.gogoanime
  final suffixMap = <String, String>{};
  for (final e in entries) {
    final pkg = e.pkg ?? '';
    if (pkg.isNotEmpty) {
      final suffix = pkg
          .replaceFirst('eu.kanade.tachiyomi.animeextension.', '')
          .replaceFirst('eu.kanade.tachiyomi.extension.', '');
      if (suffix.isNotEmpty && suffix.contains('.')) {
        suffixMap[suffix] = e.sourceDir;
      }
    }
    // Private .ext files (no pkg): will match by filename below
  }
  // Add private extensions by filename (eu.kanade...en.cubari.ext → suffix en.cubari)
  for (final e in entries) {
    if (e.pkg != null) continue;
    final name = e.sourceDir.split('/').last.replaceAll('.ext', '');
    final suffix = name
        .replaceFirst('eu.kanade.tachiyomi.animeextension.', '')
        .replaceFirst('eu.kanade.tachiyomi.extension.', '');
    if (suffix.isNotEmpty && suffix.contains('.') && !suffixMap.containsKey(suffix)) {
      suffixMap[suffix] = e.sourceDir;
    }
  }

  final toUpdate = <Source>[];

  for (final source in notInstalled) {
    final url = source.sourceCodeUrl ?? '';
    if (url.isEmpty || source.id == null) continue;

    String? apkPath;
    for (final entry in suffixMap.entries) {
      final s = entry.key;
      if (url.contains('-$s-') ||
          url.contains('/$s-') ||
          url.contains('.$s-') ||
          url.endsWith('-$s.apk')) {
        apkPath = entry.value;
        break;
      }
    }
    if (apkPath == null) continue;

    // ── 3. Read APK bytes from device — no network ─────────────────────
    String sourceCode;
    try {
      final bytes = await File(apkPath).readAsBytes();
      sourceCode = base64.encode(bytes);
    } catch (e) {
      AppLogger.log(
        'ext_loader: cannot read "${source.name}": $e',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      continue;
    }

    toUpdate.add(
      source
        ..sourceCode = sourceCode
        ..isAdded = true
        ..isActive = true,
    );
    AppLogger.log(
      'ext_loader: queued "${source.name}" from device',
      tag: LogTag.extension_,
    );
  }

  if (toUpdate.isEmpty) return;

  // ── 4. Single batch write ─────────────────────────────────────────────
  await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
  AppLogger.log(
    'ext_loader: ${toUpdate.length} source(s) activated | type=$itemType',
    tag: LogTag.extension_,
  );
}

/// Copy an APK file (from Downloads, Files app, etc.) into the private
/// extensions dir — no system installer needed, like Mihon's private extensions.
Future<bool> installPrivateExtension(String apkPath) async {
  if (!Platform.isAndroid) return false;
  try {
    await _kLoaderChannel.invokeMethod('installPrivateExtension', {'path': apkPath});
    return true;
  } catch (e) {
    AppLogger.log(
      'ext_loader: installPrivateExtension failed: $e',
      logLevel: LogLevel.error,
      tag: LogTag.extension_,
    );
    return false;
  }
}

/// Remove a private extension by its package name.
Future<void> removePrivateExtension(String pkg) async {
  if (!Platform.isAndroid) return;
  try {
    await _kLoaderChannel.invokeMethod('removePrivateExtension', {'pkg': pkg});
  } catch (_) {}
}
