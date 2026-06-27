import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';

/// Native (mobile/desktop) implementation.
///
/// Embeds the full Spotube UI via [SpotubeAppRouter] inside Watchtower's
/// /MusicLibrary shell route.  Shows the GettingStarted plugin-connect
/// wizard on first launch and the HomeRoute thereafter.
///
/// A [shadcn.Theme] wrapper is injected here so every music widget can access
/// `context.theme.scaling`, `context.theme.surfaceBlur`, etc. — these require
/// a shadcn Theme ancestor that doesn't exist in Watchtower's plain MaterialApp.
class MusicDiscoveryScreen extends StatefulWidget {
  const MusicDiscoveryScreen({super.key});

  @override
  State<MusicDiscoveryScreen> createState() => _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends State<MusicDiscoveryScreen> {
  late final SpotubeAppRouter _router;

  /// Pick the Spotube initial route based on whether the user has already
  /// completed the getting-started / plugin-connect flow.
  List<PageRouteInfo> get _initialRoutes {
    try {
      if (KVStoreService.doneGettingStarted) {
        return const [
          RootAppRoute(children: [HomeRoute()]),
        ];
      }
    } catch (_) {
      // KVStoreService not yet initialised — fall through to getting-started.
    }
    return const [GettingStartedRoute()];
  }

  @override
  void initState() {
    super.initState();
    _router = SpotubeAppRouter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final routes = _initialRoutes;
        if (routes.isNotEmpty) {
          _router.navigate(routes.first);
        }
      }
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final parentDispatcher = Router.of(context).backButtonDispatcher;

    // shadcn_flutter widgets call context.theme.scaling / surfaceBlur /
    // surfaceOpacity (from shadcn_flutter_extension.dart).  Those lookups
    // throw a null-check error when there is no ShadcnApp/Theme ancestor.
    // Wrapping with shadcn.Theme here provides the required InheritedWidget
    // so all descendant music-module widgets work correctly.
    return shadcn.Theme(
      data: shadcn.ThemeData(
        colorScheme: shadcn.LegacyColorSchemes.zinc,
        brightness: brightness,
      ),
      child: Router(
        routerDelegate: _router.delegate(),
        backButtonDispatcher: parentDispatcher != null
            ? ChildBackButtonDispatcher(parentDispatcher)
            : RootBackButtonDispatcher(),
      ),
    );
  }
}
