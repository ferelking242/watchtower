import 'package:flutter/material.dart';

export 'routes.gr.dart';

/// Fallback navigator key for the embedded music module.
///
/// It is **not** attached to any live Navigator: each `MusicDiscoveryScreen`
/// passes its own per-instance key to `MusicAppRouter` (two embeddings sharing
/// one [GlobalKey] would make Flutter drop both Navigators → blank screens).
/// Non-widget code must reach the live surface through
/// [MusicNavigatorRegistry.activeContext]; this key only exists as the router's
/// default when no per-instance key is supplied.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'music_root');
