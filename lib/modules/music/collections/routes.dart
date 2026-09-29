import 'package:flutter/material.dart';

export 'routes.gr.dart';

/// Root navigator key for the embedded Spotube music module.
/// Allows non-widget code (providers, services) to push routes and access
/// the current BuildContext without a widget reference.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'spotube_root');
