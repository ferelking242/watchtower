import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

const _kScanChannel = MethodChannel('com.watchtower.app.package_scanner');

/// Scans the device for Mihon / Aniyomi extension APKs — exactly as Aniyomi
/// auto-discovers Mihon extensions — and activates them in the local DB.
///
/// APK bytes are read straight from the device (no network download needed).
/// The extension still needs ApkBridge to serve live content; this just makes
/// it appear in Browse immediately, the same as a manual Market install.
Future<void> syncDeviceExtensions({
  required ItemType itemType,
  required String androidProxyServer,
}) async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;

  // ── 1. Ask Android for installed Mihon/Aniyomi packages ──────────────────
  List<dynamic> rawList;
  try {
    rawList =
        await _kScanChannel.invokeListMethod('getInstalledMihonExtensions') ??
        [];
  } catch (e) {
    AppLogger.log(
      'device_sync: PackageManager scan error: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
    return;
  }
  if (rawList.isEmpty) return;

  // ── 2. Build suffix → sourceDir map ──────────────────────────────────────
  //   eu.kanade.tachiyomi.extension.en.cubari        → en.cubari
  //   eu.kanade.tachiyomi.animeextension.en.gogoanime → en.gogoanime
  final suffixToDir = <String, String>{};
  for (final raw in rawList.cast<Map>()) {
    final pkg = raw['pkg'] as String? ?? '';
    final dir = raw['sourceDir'] as String? ?? '';
    if (pkg.isEmpty || dir.isEmpty) continue;
    final suffix = pkg
        .replaceFirst('eu.kanade.tachiyomi.animeextension.', '')
        .replaceFirst('eu.kanade.tachiyomi.extension.', '');
    if (suffix.isNotEmpty && suffix.contains('.')) {
      suffixToDir[suffix] = dir;
    }
  }
  if (suffixToDir.isEmpty) return;

  AppLogger.log(
    'device_sync: ${suffixToDir.length} device pkg(s) | type=$itemType',
    tag: LogTag.extension_,
  );

  // ── 3. Find un-installed Mihon sources in DB whose APK URL matches ────────
  final notInstalled = await isar.sources
      .filter()
      .itemTypeEqualTo(itemType)
      .isAddedEqualTo(false)
      .sourceCodeLanguageEqualTo(SourceCodeLanguage.mihon)
      .findAll();

  final toUpdate = <Source>[];

  for (final source in notInstalled) {
    final url = source.sourceCodeUrl ?? '';
    if (url.isEmpty || source.id == null) continue;

    // APK filenames follow: tachiyomi[-anime]extension-{suffix}-v{ver}.apk
    String? apkPath;
    for (final entry in suffixToDir.entries) {
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

    // ── 4. Read APK bytes from device — zero network calls ─────────────────
    String sourceCode;
    try {
      final bytes = await File(apkPath).readAsBytes();
      sourceCode = base64.encode(bytes);
    } catch (e) {
      AppLogger.log(
        'device_sync: cannot read APK for "${source.name}": $e',
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
      'device_sync: queued "${source.name}" (read from device)',
      tag: LogTag.extension_,
    );
  }

  if (toUpdate.isEmpty) return;

  // ── 5. Single batch write ─────────────────────────────────────────────────
  await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
  AppLogger.log(
    'device_sync: ${toUpdate.length} source(s) activated from device | type=$itemType',
    tag: LogTag.extension_,
  );
}
