import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/extension/extension_loader.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Clone of Mihon's ExtensionInstallReceiver.kt
///
/// Listens to Android's `ACTION_PACKAGE_ADDED / REPLACED / REMOVED` broadcasts
/// via an EventChannel backed by `extReceiver` in MainActivity.kt.
///
/// Result: any extension installed by **any** app (Aniyomi, Mihon, manual APK,
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

/// Register the watcher.  Call once; the subscription is kept in a static so
/// it is never GC'd.  Mirrors ExtensionManager registering its receiver at app
/// startup.
void startExtensionWatcher() {
  if (kIsWeb || !Platform.isAndroid) return;

  extensionEventStream.listen(
    (e) async {
      AppLogger.log(
        'ext_watcher: ${e.event} → ${e.pkg}',
        tag: LogTag.extension_,
      );

      switch (e.event) {
        case 'added':
        case 'replaced':
          await _handleInstalled(e);

        case 'removed':
          await _handleRemoved(e.pkg);
      }
    },
    onError: (err) {
      AppLogger.log(
        'ext_watcher: stream error: $err',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    },
  );
  AppLogger.log('ext_watcher: listening for package events', tag: LogTag.extension_);
}

/// A new / updated extension was detected — read its APK and activate it.
Future<void> _handleInstalled(_ExtEvent e) async {
  if (e.sourceDir.isEmpty) return;

  // isar_community 3.3.2: buildQuery().findAll() is the safe async pattern
  // when no single DB condition is available.
  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final matches = allSources
      .where((s) =>
          s.isAdded != true &&
          s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final suffix = e.pkg
      .replaceFirst('eu.kanade.tachiyomi.animeextension.', '')
      .replaceFirst('eu.kanade.tachiyomi.extension.', '');

  final toUpdate = <Source>[];
  for (final s in matches) {
    final url = s.sourceCodeUrl ?? '';
    if (url.isEmpty) continue;
    final hit = url.contains('-$suffix-') ||
        url.contains('/$suffix-') ||
        url.contains('.$suffix-') ||
        url.endsWith('-$suffix.apk');
    if (!hit) continue;

    try {
      final bytes = await File(e.sourceDir).readAsBytes();
      toUpdate.add(s
        ..sourceCode = base64.encode(bytes)
        ..isAdded = true
        ..isActive = true);
    } catch (err) {
      AppLogger.log(
        'ext_watcher: cannot read APK for "${s.name}": $err',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    }
  }

  if (toUpdate.isNotEmpty) {
    await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
    AppLogger.log(
      'ext_watcher: ${toUpdate.length} source(s) activated (${e.event})',
      tag: LogTag.extension_,
    );
  }
}

/// An extension was removed — mark all its DB sources as not installed.
Future<void> _handleRemoved(String pkg) async {
  final suffix = pkg
      .replaceFirst('eu.kanade.tachiyomi.animeextension.', '')
      .replaceFirst('eu.kanade.tachiyomi.extension.', '');

  final allSources = await isar.sources.buildQuery<Source>().findAll();
  final installed = allSources
      .where((s) =>
          s.isAdded == true &&
          s.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .toList();

  final toUpdate = <Source>[];
  for (final s in installed) {
    final url = s.sourceCodeUrl ?? '';
    final hit = url.contains('-$suffix-') ||
        url.contains('/$suffix-') ||
        url.contains('.$suffix-') ||
        url.endsWith('-$suffix.apk');
    if (hit) {
      toUpdate.add(s
        ..sourceCode = ''
        ..isAdded = false
        ..isActive = false);
    }
  }

  if (toUpdate.isNotEmpty) {
    await isar.writeTxn(() async => isar.sources.putAll(toUpdate));
    AppLogger.log(
      'ext_watcher: ${toUpdate.length} source(s) deactivated (removed $pkg)',
      tag: LogTag.extension_,
    );
  }
}
