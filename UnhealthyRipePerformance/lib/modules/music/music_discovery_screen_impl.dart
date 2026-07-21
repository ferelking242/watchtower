import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/router/music_app_router.dart';
    import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
    import 'package:watchtower/modules/music/services/logger/logger.dart' as music_log;

    /// FIX: Removed Localizations.override — it caused an async delegate reload that
    /// made AppLocalizations.of(context) return null on first build → null crash → blank pages.
    /// The music module's AppLocalizations.delegate is already registered in the root
    /// MaterialApp (main.dart spotube_l10n.AppLocalizations.delegate), so this Router
    /// inherits it directly with no async gap.
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
      // FIX (black screen on 2nd visit): this used to only call replaceAll()
      // on the very first mount (initialRoute != null || !doneGettingStarted).
      // On every later mount — e.g. leaving the Music Hub and coming back, or
      // the app being backgrounded/killed and restored by the OS — a brand
      // new [_MusicDiscoveryScreenState]/[SpotubeAppRouter] is created, but
      // this guard skipped replaceAll() and silently relied on auto_route's
      // declared `initial: true` route resolving correctly on its own. If
      // that resolution raced with anything not yet ready (prefs, providers)
      // the Navigator ended up with zero pages, which paints as a plain
      // black surface (Flutter's default canvas colour) instead of an error.
      // Always explicitly (re)set the correct initial stack after the first
      // frame so the destination is deterministic on every mount, not just
      // the first one.
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
      // Explicit background (instead of a bare Router with nothing behind
      // it) so any transient empty-page-stack frame renders as the app's
      // surface colour rather than a raw black canvas.
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Router(
          routerDelegate: _routerDelegate,
          backButtonDispatcher: parentDispatcher != null
              ? ChildBackButtonDispatcher(parentDispatcher)
              : RootBackButtonDispatcher(),
        ),
      );
    }
    }
    