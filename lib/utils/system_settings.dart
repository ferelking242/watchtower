import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens the operating system's network settings.
///
/// On Android the native `com.watchtower.app.system_settings` channel shows the
/// Internet connectivity panel (Android 10+) or the wireless settings list.
/// iOS uses `openAppSettings`. Everywhere else — or if the native call fails —
/// it falls back to the in-app network settings page so the button is never a
/// dead end.
Future<void> openNetworkSettings(BuildContext context) async {
  final isAndroid = !kIsWeb && Platform.isAndroid;
  final isIOS = !kIsWeb && Platform.isIOS;

  if (isAndroid) {
    try {
      const channel = MethodChannel('com.watchtower.app.system_settings');
      final opened = await channel.invokeMethod<bool>('openNetworkSettings');
      if (opened == true) return;
    } catch (_) {
      // Fall through to the generic path below.
    }
  }
  if (isIOS) {
    try {
      await openAppSettings();
      return;
    } catch (_) {
      // Fall through.
    }
  }
  if (context.mounted) context.push('/general');
}
