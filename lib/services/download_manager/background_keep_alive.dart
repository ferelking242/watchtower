import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Cross-platform background keep-alive for the active download queue.
///
/// ┌─────────┬──────────────────────────────────────────────────────────────┐
/// │ Android │ Starts/stops a real Foreground Service so Android does NOT  │
/// │         │ kill the process during RAM pressure, Doze or app-standby.  │
/// │         │ The service shows a persistent "X téléchargements en cours" │
/// │         │ notification that the user can tap to return to the app.    │
/// ├─────────┼──────────────────────────────────────────────────────────────┤
/// │ iOS     │ Info.plist already declares background-fetch + processing   │
/// │         │ modes.  We additionally hold a WakeLock while the app is    │
/// │         │ in foreground so the CPU never sleeps mid-segment.          │
/// ├─────────┼──────────────────────────────────────────────────────────────┤
/// │ macOS   │ WakeLock prevents display sleep (important for long batches).│
/// │ Linux   │ WakeLock; OS does not kill processes.                        │
/// │ Windows │ WakeLock; OS does not kill processes.                        │
/// ├─────────┼──────────────────────────────────────────────────────────────┤
/// │ Web     │ No-op — downloads run in the browser tab.                   │
/// └─────────┴──────────────────────────────────────────────────────────────┘
class BackgroundKeepAlive {
  BackgroundKeepAlive._();

  static const _ch = MethodChannel('watchtower/download_service');
  static bool _wakelockHeld = false;
  static DateTime? _lastNotificationUpdate;
  static int _lastNotificationProgress = -2;
  static String _lastNotificationTitle = '';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call when the first download starts (queue becomes active).
  static Future<void> start({
    int count = 0,
    String title = 'Téléchargement en cours…',
  }) async {
    await _acquireWakelock();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _ch.invokeMethod<void>('start', {'count': count, 'title': title});
      } catch (_) {}
    }
  }

  /// Update the notification text (Android) — call when active count changes.
  ///
  /// [title]    — name of the current chapter/episode (shown as notification title).
  /// [progress] — download progress 0-100 (-1 = indeterminate).
  static Future<void> update({
    required int count,
    String title = 'Téléchargement en cours…',
    int progress = -1,
    String subtitle = '',
    int downloadedBytes = 0,
    int? totalBytes,
    double speedMbs = 0,
    int? etaSeconds,
    String quality = '',
    bool force = false,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      final now = DateTime.now();
      final progressChanged = progress != _lastNotificationProgress;
      final titleChanged = title != _lastNotificationTitle;
      final elapsed = _lastNotificationUpdate == null
          ? const Duration(seconds: 1)
          : now.difference(_lastNotificationUpdate!);
      // Progress callbacks can arrive for every network chunk. Throttle the
      // tray to a steady cadence so updates remain readable and do not cause
      // notification flicker or excessive binder traffic.
      if (!force &&
          !progressChanged &&
          !titleChanged &&
          elapsed < const Duration(milliseconds: 650)) {
        return;
      }
      _lastNotificationUpdate = now;
      _lastNotificationProgress = progress;
      _lastNotificationTitle = title;
      try {
        await _ch.invokeMethod<void>('update', {
          'count': count,
          'title': title,
          'progress': progress,
          'subtitle': subtitle,
          'downloadedBytes': downloadedBytes,
          'totalBytes': totalBytes,
          'speedMbs': speedMbs,
          'etaSeconds': etaSeconds,
          'quality': quality,
        });
      } catch (_) {}
    }
  }

  /// Call when the queue fully drains (no more active or pending downloads).
  static Future<void> stop() async {
    await _releaseWakelock();
    _lastNotificationUpdate = null;
    _lastNotificationProgress = -2;
    _lastNotificationTitle = '';
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _ch.invokeMethod<void>('stop');
      } catch (_) {}
    }
  }

  // ── WakeLock helpers ───────────────────────────────────────────────────────

  static Future<void> _acquireWakelock() async {
    if (_wakelockHeld) return;
    try {
      await WakelockPlus.enable();
      _wakelockHeld = true;
    } catch (_) {}
  }

  static Future<void> _releaseWakelock() async {
    if (!_wakelockHeld) return;
    try {
      await WakelockPlus.disable();
      _wakelockHeld = false;
    } catch (_) {}
  }
}
