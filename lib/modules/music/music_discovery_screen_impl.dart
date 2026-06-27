import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';

/// Native (mobile/desktop) implementation.
///
/// Embeds the full Spotube UI via [SpotubeAppRouter] inside Watchtower's
/// shell routes (/MusicLibrary, /MusicSearch, /MusicLibraryPage).
///
/// [initialRoute] controls which Spotube page opens first:
///   - null / 'home'    → HomeRoute  (Spotube accueil — default)
///   - 'search'         → SearchRoute (Spotube recherche — Discovery pill)
///   - 'library'        → LibraryRoute (Spotube bibliothèque — Library sub-dock)
///
/// A [shadcn.Theme] wrapper is injected so every music widget can access
/// `context.theme.scaling`, `context.theme.surfaceBlur`, etc.
class MusicDiscoveryScreen extends StatefulWidget {
  final String? initialRoute;
  const MusicDiscoveryScreen({super.key, this.initialRoute});

  @override
  State<MusicDiscoveryScreen> createState() => _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends State<MusicDiscoveryScreen> {
  late final SpotubeAppRouter _router;

  List<PageRouteInfo> get _initialRoutes {
    switch (widget.initialRoute) {
      case 'search':
        return const [RootAppRoute(children: [SearchRoute()])];
      case 'library':
        return const [RootAppRoute(children: [LibraryRoute()])];
      default:
        try {
          if (KVStoreService.doneGettingStarted) {
            return const [RootAppRoute(children: [HomeRoute()])];
          }
        } catch (_) {
          // KVStoreService not yet initialised — fall through to getting-started.
        }
        return const [GettingStartedRoute()];
    }
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
    final parentDispatcher = Router.of(context).backButtonDispatcher;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // shadcn_flutter widgets call context.theme.scaling / surfaceBlur /
    // surfaceOpacity (from shadcn_flutter_extension.dart).  Those lookups
    // throw a null-check error when there is no ShadcnApp/Theme ancestor.
    // Wrapping with shadcn.Theme here provides the required InheritedWidget
    // so all descendant music-module widgets work correctly.
    //
    // LegacyColorSchemes.zinc expects shadcn.ThemeMode (not Flutter's
    // ThemeMode) — use the shadcn-namespaced constant to avoid the
    // "ThemeMode/*1*/ can't be assigned to ThemeMode/*2*/" type conflict.
    return shadcn.Theme(
      data: shadcn.ThemeData(
        colorScheme: shadcn.LegacyColorSchemes.zinc(
          isDark ? shadcn.ThemeMode.dark : shadcn.ThemeMode.light,
        ),
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
