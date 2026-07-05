import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart' as music_log;
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

/// Native (mobile/desktop) implementation.
///
/// Embeds the full Spotube UI via [SpotubeAppRouter] inside Watchtower's
/// shell routes (/MusicLibrary, /MusicSearch, /MusicLibraryPage).
///
/// [initialRoute] controls which Spotube page opens first:
///   - null / 'home'    → HomeRoute  (default)
///   - 'search'         → SearchRoute
///   - 'library'        → LibraryRoute
///
/// NOTE: We intentionally do NOT wrap in a Theme() override — Spotube inherits
/// the parent Watchtower theme so Music mode follows the user's chosen palette.
/// Spotube's own GettingStartedRoute handles the "no provider set up" case.
class MusicDiscoveryScreen extends ConsumerStatefulWidget {
  final String? initialRoute;
  const MusicDiscoveryScreen({super.key, this.initialRoute});

  @override
  ConsumerState<MusicDiscoveryScreen> createState() =>
      _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends ConsumerState<MusicDiscoveryScreen> {
  late final SpotubeAppRouter _router;

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
    try {
      music_log.AppLogger.initialize(false);
    } catch (_) {}
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

    final Locale? musicLocale = ref.watch(
      userPreferencesProvider.select((p) => p.locale),
    );

    // Inherit the parent app's theme — do NOT override with Spotube's own
    // accent color so Music mode follows the user's chosen app theme.
    return Material(
      color: Colors.transparent,
      child: Builder(
        builder: (locCtx) => Localizations.override(
          context: locCtx,
          locale: musicLocale,
          child: Router(
            routerDelegate: _router.delegate(),
            backButtonDispatcher: parentDispatcher != null
                ? ChildBackButtonDispatcher(parentDispatcher)
                : RootBackButtonDispatcher(),
          ),
        ),
      ),
    );
  }
}
