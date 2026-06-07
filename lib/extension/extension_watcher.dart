import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/extension/extension_index_scanner.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Clone of Mihon's ExtensionInstallReceiver.kt
///
/// Listens to Android's ACTION_PACKAGE_ADDED / REPLACED / REMOVED broadcasts
/// via an EventChannel backed by extReceiver in MainActivity.kt.
///
/// Result: any extension installed by ANY app (Aniyomi, Mihon, manual APK,
/// or Watchtower's own private-ext installer) appears in Browse immediately —
/// exactly as it does in Mihon / Aniyomi.

const _kWatcherChannel = EventChannel('com.watchtower.app.ext_watcher');

/// Call once from app init (e.g. in main.dart or a top-level provider).
/// Returns a subscription — keep it alive as long as the app is running.
Stream<_ExtEvent> get extensionEventStream {
  if (kIsWeb || !Platform.isAndroid) return const Stream.empty();
  return _kWatcherChannel
      .receiveBroadcastStream()
      .cast<Map>()
      .map((raw) => _ExtEvent(
            event: raw['event'] as String? ?? '',
            pkg: raw['pkg'] as String? ?? '',
            sourceDir: raw['sourceDir'] as String? ?? '',
          ));
}

class _ExtEvent {
  final String event;
  final String pkg;
  final String sourceDir;
  const _ExtEvent({required this.event, required this.pkg, required this.sourceDir});
}

/// Register the watcher. Call once; the subscription is kept in a static so
/// it is never GC'd. Mirrors ExtensionManager registering its receiver at app
/// startup.
void startExtensionWatcher() {
  if (kIsWeb || !Platform.isAndroid) return;

  extensionEventStream.listen(
    (e) async {
      AppLogger.log(
        '[PackageChanged] event=${e.event} pkg=${e.pkg}',
        tag: LogTag.extension_,
      );

      switch (e.event) {
        case 'added':
        case 'replaced':
          if (e.sourceDir.isEmpty) {
            AppLogger.log(
              '[PackageChanged] SKIP ${e.pkg} — no sourceDir',
              logLevel: LogLevel.warning,
              tag: LogTag.extension_,
            );
            return;
          }
          await handlePackageInstalled(
            pkg: e.pkg,
            sourceDir: e.sourceDir,
          );

        case 'removed':
          await handlePackageRemoved(e.pkg);
      }
    },
    onError: (err) {
      AppLogger.log(
        '[PackageChanged] Stream error: $err',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    },
  );
  AppLogger.log(
    '[PackageChanged] Watcher started — listening for package events',
    tag: LogTag.extension_,
  );
}
