import 'package:flutter/widgets.dart';

/// Registry of the music module's *live* navigator keys.
///
/// The music module can be embedded several times at once (Discover tab, the
/// Music Hub and the Library each mount their own [MusicDiscoveryScreen], each
/// with its own router/navigator). Non-widget code — plugin services, option
/// actions, download managers — needs a [BuildContext] to push a route, show a
/// dialog or read the theme, but it has no widget reference.
///
/// A single module-level key cannot serve that need: as soon as two embeddings
/// coexist, attaching the same [GlobalKey] to two Navigators makes Flutter drop
/// both (blank screens), which is why each embedding passes its *own* key to
/// [MusicAppRouter]. This registry records those per-instance keys in mount
/// order and hands out the most recently mounted one, which is the surface the
/// user is actually interacting with.
class MusicNavigatorRegistry {
  MusicNavigatorRegistry._();

  static final List<GlobalKey<NavigatorState>> _keys = [];

  static void register(GlobalKey<NavigatorState> key) {
    if (!_keys.contains(key)) _keys.add(key);
  }

  static void unregister(GlobalKey<NavigatorState> key) {
    _keys.remove(key);
  }

  /// The key of the most recently mounted, still-live music navigator, or
  /// `null` when no music surface is mounted.
  static GlobalKey<NavigatorState>? get activeKey {
    for (final key in _keys.reversed) {
      if (key.currentState != null) return key;
    }
    return null;
  }

  /// Context of the active music navigator, or `null` when none is mounted.
  static BuildContext? get activeContext => activeKey?.currentState?.context;
}
