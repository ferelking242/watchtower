import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/modules/settings/color_scheme_picker_dialog.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
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
///   - 'library'        → LibraryRoute (Spotube bibliothèque — Library sub-tab)
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

    // Apply the music module's own accent colour so widgets inside always use
    // the user-chosen colour (green by default) rather than the parent app's
    // FlexColorScheme primary (which defaults to Material blue).
    final accentColor = ref.watch(
      userPreferencesProvider.select((p) => p.accentColorScheme),
    );
    final musicThemeMode = ref.watch(
      userPreferencesProvider.select((p) => p.themeMode),
    );
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final musicBrightness = switch (musicThemeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => systemBrightness,
    };
    final musicColorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: musicBrightness,
    );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: musicColorScheme),
      child: Material(
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
      ),
    );
  }
}
