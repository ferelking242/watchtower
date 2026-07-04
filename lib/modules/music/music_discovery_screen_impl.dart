import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/router/music_app_router.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart' as music_log;
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:go_router/go_router.dart';

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
    // If the user hasn't set up a music provider yet, show a themed redirect
    // page instead of Spotube's own black getting-started screen.
    if (!_doneGettingStarted()) {
      return _NoProviderPage(onSetupTap: () {
        // Navigate to Spotube getting-started via MusicLibrary route which
        // will open the full music router where the user can connect Spotify.
        context.go('/MusicLibrary');
      });
    }

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

// ── No-provider redirect page ──────────────────────────────────────────────────

class _NoProviderPage extends StatelessWidget {
  final VoidCallback onSetupTap;
  const _NoProviderPage({required this.onSetupTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withValues(alpha: 0.60),
                    cs.secondaryContainer.withValues(alpha: 0.40),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 44,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Activer la musique',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Connecte un fournisseur de métadonnées musicales (Spotify) pour accéder à ta bibliothèque et découvrir de la musique.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onSetupTap,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
              label: const Text('Configurer le fournisseur'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
