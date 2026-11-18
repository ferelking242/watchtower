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
  // Distinct from [_events]: on Android a method channel and an event channel
  // that share a name both register a handler under the same messenger key, so
  // the later registration replaces the earlier one and the event stream never
  // receives its sink.
  static const _methods = MethodChannel(
    'com.watchtower.app.volume_keys_methods',
  );

  static StreamSubscription<dynamic>? _sub;

  /// Owner of the current subscription. Each [enable] mints a fresh token;
  /// [disable] only tears the listener down when the caller still owns it.
  static Object? _owner;

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
  ///
  /// Returns an ownership token to hand back to [disable]. The reader is
  /// replaced on every chapter change (`pushReplacement`), and Flutter disposes
  /// the *old* reader *after* the new one has already subscribed; without the
  /// token the stale dispose would cancel the live subscription and silently
  /// kill volume-key navigation from the second chapter onwards.
  static Future<Object?> enable(
    void Function(int direction) onDirection,
  ) async {
    final token = Object();
    _owner = token;
    final previousSubscription = _sub;
    _sub = null;
    await previousSubscription?.cancel();
    if (!identical(_owner, token)) return null;

    // Subscribe *before* flipping the native flag: the EventChannel's
    // `onListen` (which installs the native sink) is what the host checks
    // before forwarding a key, so enabling first would open a window where the
    // activity swallows a volume key into a sink that does not exist yet.
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        if (identical(_owner, token) && event is int) {
          onDirection(event);
        }
      },
      onError: (Object _) {
        if (identical(_owner, token)) {
          unawaited(disable(token));
        }
      },
    );
    try {
      // EventChannel's onListen is asynchronous. Have the host confirm that it
      // has a live event sink before treating navigation as enabled; otherwise
      // an Android activity could swallow the key without delivering it.
      for (var attempt = 0; attempt < 8; attempt++) {
        final ready = await _methods.invokeMethod<bool>('setEnabled', {
          'enabled': true,
        });
        if (!identical(_owner, token)) return null;
        if (ready == true) return token;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    } on MissingPluginException {
      // Desktop / web build: the reader falls back to no key navigation.
      await disable(token);
      return null;
    } on PlatformException {
      // Host refused to enable; nothing to do.
      await disable(token);
      return null;
    }

    await disable(token);
    return null;
  }

  /// Stops forwarding and releases the native listener.
  ///
  /// [token] is the value returned by [enable]. When it is no longer the
  /// current owner (a newer reader already subscribed) this is a no-op, so a
  /// late dispose cannot disable the reader that replaced it.
  static Future<void> disable([Object? token]) async {
    if (token != null && !identical(token, _owner)) return;
    _owner = null;
    final subscription = _sub;
    _sub = null;
    await subscription?.cancel();
    // A new reader may have subscribed while the old listener was cancelling.
    // Do not let the old reader's delayed shutdown turn the new one off.
    if (_owner != null) return;
    try {
      await _methods.invokeMethod<bool>('setEnabled', {'enabled': false});
    } catch (_) {
      // Ignore: the platform may not implement the channel.
    }
  }
}
