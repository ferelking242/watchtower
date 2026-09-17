import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/app_constants.dart' as flixquest_constants;
import 'package:flixquest/flixquest_main.dart';
import 'package:flixquest/models/translation.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/offline_download_provider.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/tv/platform/device_presentation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hosts the original FlixQuest application surface inside Watchtower.
///
/// This deliberately uses FlixQuest's own home page rather than rebuilding
/// its screens in Watchtower. Watchtower only supplies the route and the
/// provider boundary needed by the imported application.
class FlixQuestEmbeddedScreen extends StatefulWidget {
  const FlixQuestEmbeddedScreen({
    super.key,
    this.initialDestination,
  });

  /// Optional FlixQuest destination selected when Watchtower opens the
  /// embedded surface from a dedicated dock/menu entry.
  final String? initialDestination;

  @override
  State<FlixQuestEmbeddedScreen> createState() =>
      _FlixQuestEmbeddedScreenState();
}

class _FlixQuestEmbeddedScreenState extends State<FlixQuestEmbeddedScreen> {
  late final Future<void> _sharedPreferencesReady =
      _ensureSharedPreferences();
  late Future<_FlixQuestDependencies> _dependencies = _prepare();

  Future<_FlixQuestDependencies> _prepare() async {
    final settings = SettingsProvider();
    final recent = RecentProvider();
    final bookmarks = BookmarkProvider();
    final dependencies = AppDependencyProvider();

    // Render with safe defaults first. A bad preference row, unavailable
    // platform plugin, or Firebase error must not replace the actual screens
    // with a startup error page.
    unawaited(_hydrateBestEffort(
      preferencesReady: _sharedPreferencesReady,
      settings: settings,
      recent: recent,
      bookmarks: bookmarks,
      dependencies: dependencies,
    ));

    return _FlixQuestDependencies(
      settings: settings,
      recent: recent,
      bookmarks: bookmarks,
      dependencies: dependencies,
    );
  }

  Future<void> _ensureSharedPreferences() async {
    if (flixquest_constants.sharedPrefsSingletonOrNull != null) return;
    try {
      flixquest_constants.sharedPrefsSingleton =
          await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
      );
    } catch (error, stack) {
      // The embedded catalog can still render and browse without persisted
      // settings. Keep this failure off the screen and use default values.
      debugPrint('FlixQuest preferences unavailable: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _hydrateBestEffort({
    required Future<void> preferencesReady,
    required SettingsProvider settings,
    required RecentProvider recent,
    required BookmarkProvider bookmarks,
    required AppDependencyProvider dependencies,
  }) async {
    await _ignoreStartupFailure(
      'preferences and settings',
      () async {
        await preferencesReady;
        await Future.wait([
          settings.getCurrentThemeMode(),
          settings.getCurrentMaterial3Mode(),
          settings.getCurrentAdultMode(),
          settings.getCurrentDefaultScreen(),
          settings.getCurrentImageQuality(),
          settings.getCurrentWatchCountry(),
          settings.getCurrentViewType(),
          settings.getSeekDuration(),
          settings.getViewMode(),
          settings.getMaxBufferDuration(),
          settings.getVideoResolution(),
          settings.getSubtitleLanguage(),
          settings.getForegroundSubtitleColor(),
          settings.getBackgroundSubtitleColor(),
          settings.getSubtitleSize(),
          settings.getAppLanguage(),
          settings.getSubtitleMode(),
          settings.getAppColorIndex(),
          settings.getCustomAppColor(),
          settings.getStreamProviderOrder(),
          settings.getPlayerTimeStyle(),
          settings.getUseProxyMode(),
          settings.getSubtitleStyle(),
          settings.getEnableNextEpisodeButton(),
          settings.getIntroDbSettings(),
          settings.getPlayerAmbientGlowEnabled(),
          settings.getAutoLoadSources(),
        ]);
      },
    );
    settings.completeHydration();

    await Future.wait([
      _ignoreStartupFailure('recent movies', recent.fetchMovies),
      _ignoreStartupFailure('recent episodes', recent.fetchEpisodes),
      _ignoreStartupFailure('bookmarks', bookmarks.fetchBookmarks),
      _ignoreStartupFailure(
        'FlixQuest logo',
        dependencies.getFlixQuestLogo,
      ),
      _ignoreStartupFailure(
        'occasional theme',
        dependencies.getOccasionalTheme,
      ),
      _ignoreStartupFailure('ambient mode', dependencies.getAmbientMode),
      _ignoreStartupFailure('API URL', dependencies.getFQUrl),
      _ignoreStartupFailure('TMDB proxy', dependencies.getTmdbProxy),
      _ignoreStartupFailure(
        'update configuration',
        dependencies.getUpdateConfiguration,
      ),
    ]);
  }

  Future<void> _ignoreStartupFailure(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stack) {
      debugPrint('FlixQuest optional startup step failed ($operation): $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FlixQuestDependencies>(
      future: _dependencies,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('FlixQuest local startup failed: ${snapshot.error}');
          return _FlixQuestStartupFallback(
            error: snapshot.error,
            onRetry: () => setState(() {
              _dependencies = _prepare();
            }),
          );
        }
        final dependencies = snapshot.data;
        if (dependencies == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return EasyLocalization(
          supportedLocales: Translation.all,
          path: 'packages/flixquest/assets/translations',
          fallbackLocale: Translation.all.first,
          startLocale: Locale(dependencies.settings.appLanguage),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: dependencies.settings),
              ChangeNotifierProvider.value(value: dependencies.recent),
              ChangeNotifierProvider.value(value: dependencies.bookmarks),
              ChangeNotifierProvider.value(
                value: dependencies.dependencies,
              ),
              ChangeNotifierProvider(
                create: (_) => OfflineDownloadProvider()..initialize(),
              ),
              ChangeNotifierProvider.value(value: WellnessProvider.instance),
            ],
            child: FlixQuestHomePage(
              initialDestination: initialDestination,
            ),
          ),
        );
      },
    );
  }
}

class _FlixQuestStartupFallback extends StatelessWidget {
  const _FlixQuestStartupFallback({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF070B17),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 42),
              const SizedBox(height: 14),
              const Text(
                'FlixQuest ne peut pas démarrer',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlixQuestDependencies {
  const _FlixQuestDependencies({
    required this.settings,
    required this.recent,
    required this.bookmarks,
    required this.dependencies,
  });

  final SettingsProvider settings;
  final RecentProvider recent;
  final BookmarkProvider bookmarks;
  final AppDependencyProvider dependencies;
}