import 'package:auto_route/auto_route.dart';
  import 'dart:io' show Platform;
  import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
  import 'package:flutter/material.dart' show Material, Colors, Brightness;
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
  import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
  import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
  import 'package:watchtower/modules/music/collections/routes.gr.dart';
  import 'package:watchtower/modules/music/router/music_app_router.dart';
  import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
  import 'package:watchtower/modules/music/services/logger/logger.dart' as music_log;

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
  class MusicDiscoveryScreen extends ConsumerStatefulWidget {
    final String? initialRoute;
    const MusicDiscoveryScreen({super.key, this.initialRoute});

    @override
    ConsumerState<MusicDiscoveryScreen> createState() =>
        _MusicDiscoveryScreenState();
  }

  class _MusicDiscoveryScreenState extends ConsumerState<MusicDiscoveryScreen> {
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
      // Initialise Spotube's own AppLogger so the Logs page and error
      // reporting inside the music module work correctly.
      try {
        music_log.AppLogger.initialize(false); // no-op — now delegates to wt AppLogger
      } catch (_) {
        // Already initialised — safe to ignore.
      }
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

      // Read Watchtower's own theme providers so the shadcn colour scheme
      // always matches the host app's dark/light state, regardless of the
      // system brightness or follow-system setting.
      final forcedDark = ref.watch(themeModeStateProvider);
      final followSystem = ref.watch(followSystemThemeStateProvider);
      final isDark = followSystem
          ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
          : forcedDark;

      // ShadcnApp wraps its entire tree with Material(color: transparent) so
      // that shadcn.Scaffold's internal Overlay entries (headers, drawers,
      // sheets, popovers) can call Material.of(context)! without crashing.
      //
      // shadcn.Scaffold.build() returns:
      //   Overlay(initialEntries: [OverlayEntry(builder: _buildContent)])
      // Overlay entries inherit ancestors only UP from the Overlay widget.
      // Without a Material ABOVE the Overlay, any widget in an overlay entry
      // that calls Material.of(context) (e.g. ListTile with shape → Ink)
      // throws "Null check operator used on a null value" and the page goes gray.
      //
      // ShadcnApp normally provides OverlayManagerLayer + Theme + root Material.
      // Since Watchtower uses MaterialApp.router instead of ShadcnApp, we inject
      // all three manually here.
      //
      // Mobile uses Sheet-based overlays; desktop uses floating Popover overlays —
      // mirroring exactly what ShadcnApp chooses based on mobileMode.
      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      return Material(
        color: Colors.transparent,
        child: shadcn.Theme(
          data: shadcn.ThemeData(
            colorScheme: shadcn.LegacyColorSchemes.zinc(
              isDark ? shadcn.ThemeMode.dark : shadcn.ThemeMode.light,
            ),
            radius: 0.5,
            surfaceOpacity: 1.0,
            surfaceBlur: 0,
            scaling: 1.0,
          ),
          child: shadcn.OverlayManagerLayer(
            popoverHandler: isMobile
                ? const shadcn.SheetOverlayHandler()
                : const shadcn.PopoverOverlayHandler(),
            tooltipHandler: isMobile
                ? const shadcn.FixedTooltipOverlayHandler()
                : const shadcn.PopoverOverlayHandler(),
            menuHandler: isMobile
                ? const shadcn.SheetOverlayHandler()
                : const shadcn.PopoverOverlayHandler(),
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
  