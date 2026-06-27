import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';

/// Host widget for the Spotube music module.
///
/// Embeds the full Spotube UI (real pages, shadcn_flutter, auto_route
/// navigation) inside Watchtower's /MusicLibrary shell route.
/// Creates its own [SpotubeAppRouter] so every Spotube page works exactly
/// as in the original app — including the GettingStarted plugin-connect flow.
class MusicDiscoveryScreen extends StatefulWidget {
  const MusicDiscoveryScreen({super.key});

  @override
  State<MusicDiscoveryScreen> createState() => _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends State<MusicDiscoveryScreen> {
  late final SpotubeAppRouter _router;

  /// Determine the initial Spotube route based on whether the user has already
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
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentDispatcher = Router.of(context).backButtonDispatcher;
    return Router(
      routerDelegate: _router.delegate(
        initialRoutes: _initialRoutes,
      ),
      backButtonDispatcher: parentDispatcher != null
          ? ChildBackButtonDispatcher(parentDispatcher)
          : RootBackButtonDispatcher(),
    );
  }
}
