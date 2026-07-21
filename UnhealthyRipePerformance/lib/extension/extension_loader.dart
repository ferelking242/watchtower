import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/utils/log/logger.dart';

const _kLoaderChannel = MethodChannel('com.watchtower.app.ext_loader');

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
