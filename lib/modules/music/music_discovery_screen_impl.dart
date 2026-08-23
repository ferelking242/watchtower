import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart' as music_log;

class MusicDiscoveryScreen extends StatefulWidget {
  final String? initialRoute;
  const MusicDiscoveryScreen({super.key, this.initialRoute});

  @override
  State<MusicDiscoveryScreen> createState() => _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends State<MusicDiscoveryScreen> {
  final _navKey = GlobalKey<NavigatorState>(debugLabel: 'spotube_music');
  late final SpotubeAppRouter _router;
  late final RouterDelegate<Object?> _routerDelegate;

  bool _doneGettingStarted() {
    try {
      return KVStoreService.doneGettingStarted;
    } catch (_) {
      return false;
    }
  }

  List<PageRouteInfo> get _initialRoutes {
    switch (widget.initialRoute) {
      case 'search':
        return const [RootAppRoute(children: [SearchRoute()])];
      case 'library':
        return const [RootAppRoute(children: [LibraryRoute()])];
      default:
        if (_doneGettingStarted()) {
          return const [RootAppRoute(children: [HomeRoute()])];
        }
        return const [GettingStartedRoute()];
    }
  }

  @override
  void initState() {
    super.initState();
    try { music_log.AppLogger.initialize(false); } catch (_) {}
    _router = SpotubeAppRouter(navigatorKey: _navKey);
    _routerDelegate = _router.delegate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _router.replaceAll(_initialRoutes);
      } catch (e, st) {
        music_log.AppLogger.reportError(e, st, 'MusicDiscoveryScreen initial route resolution failed');
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
    // Use scaffold background to match the rest of the app, and expand to
    // fill all available space so child pages (e.g. the "no provider" fallback
    // with Center) can center vertically.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox.expand(
        child: Router(
          routerDelegate: _routerDelegate,
          backButtonDispatcher: parentDispatcher != null
              ? ChildBackButtonDispatcher(parentDispatcher)
              : RootBackButtonDispatcher(),
        ),
      ),
    );
  }
}
