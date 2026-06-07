import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/extension/extension_index_scanner.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Clone of Mihon's ExtensionLoader.kt — now delegates to the full
/// [rebuildExtensionIndex] scanner for 100% detection accuracy.
///
/// This file is kept for API compatibility (fetch_item_sources.dart calls
/// [syncExtensions]). The heavy lifting is done by extension_index_scanner.dart.

const _kLoaderChannel = MethodChannel('com.watchtower.app.ext_loader');

/// Scan + activate all device extensions for [itemType].
/// Call once after the index repos have been loaded into DB.
Future<void> syncExtensions({
  required ItemType itemType,
  required String androidProxyServer,
}) async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;

  // Delegate to the full rebuild scanner — it handles all detection,
  // validation, orphan cleanup, and logging in one atomic pass.
  await rebuildExtensionIndex(
    itemType: itemType,
    androidProxyServer: androidProxyServer,
  );
}

/// Copy an APK file (from Downloads, Files app, etc.) into the private
/// extensions dir — no system installer needed, like Mihon's private extensions.
Future<bool> installPrivateExtension(String apkPath) async {
  if (!Platform.isAndroid) return false;
  try {
    await _kLoaderChannel.invokeMethod('installPrivateExtension', {'path': apkPath});
    AppLogger.log(
      '[ExtensionAdded] Private extension installed from $apkPath',
      tag: LogTag.extension_,
    );
    return true;
  } catch (e) {
    AppLogger.log(
      '[ExtensionValidation] installPrivateExtension failed: $e',
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
    AppLogger.log(
      '[ExtensionRemoved] Private extension removed: $pkg',
      tag: LogTag.extension_,
    );
  } catch (_) {}
}
