import 'dart:async';

import 'package:flutter/services.dart';

/// Hardware volume-key bridge for the reader.
///
/// `volume_controller` listens to the `VOLUME_CHANGED_ACTION` broadcast, which
/// Android 13+ no longer delivers to apps reliably, so volume-button page
/// navigation silently stopped working. Here the host activity intercepts the
/// key events itself (`MainActivity.dispatchKeyEvent`) and pushes the direction
/// over this channel: `1` = volume up, `-1` = volume down. The system volume is
/// never touched, so no volume HUD appears.
class VolumeKeyChannel {
  VolumeKeyChannel._();

  static const _events = EventChannel('com.watchtower.app.volume_keys');
  static const _methods = MethodChannel('com.watchtower.app.volume_keys');

  static StreamSubscription<dynamic>? _sub;

  /// Whether a hardware volume key turns to the next page.
  ///
  /// [direction] is `1` for volume-up and `-1` for volume-down. By default
  /// volume-down goes forward and volume-up goes back (the usual reading
  /// gesture). Setting [invert] swaps the two, matching the settings subtitle
  /// "▲ → page suivante • ▼ → page précédente".
  static bool volumeKeyGoesToNextPage({
    required int direction,
    required bool invert,
  }) {
    final volUp = direction > 0;
    return invert ? volUp : !volUp;
  }

  /// Starts forwarding hardware volume keys, invoking [onDirection] with `1`
  /// (up) or `-1` (down). No-op on platforms without the native handler.
  static Future<void> enable(void Function(int direction) onDirection) async {
    await disable();
    try {
      await _methods.invokeMethod<void>('setEnabled', {'enabled': true});
      _sub = _events.receiveBroadcastStream().listen((event) {
        if (event is int) {
          onDirection(event);
        }
      });
    } on MissingPluginException {
      // Desktop / web build: the reader falls back to no key navigation.
    } on PlatformException {
      // Host refused to enable; nothing to do.
    }
  }

  /// Stops forwarding and releases the native listener.
  static Future<void> disable() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _methods.invokeMethod<void>('setEnabled', {'enabled': false});
    } catch (_) {
      // Ignore: the platform may not implement the channel.
    }
  }
}
