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
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hosts the original FlixQuest application surface inside Watchtower.
///
/// This deliberately uses FlixQuest's own home page rather than rebuilding
/// its screens in Watchtower. Watchtower only supplies the route and the
/// provider boundary needed by the imported application.
class FlixQuestEmbeddedScreen extends StatefulWidget {
  const FlixQuestEmbeddedScreen({super.key});

  @override
  State<FlixQuestEmbeddedScreen> createState() =>
      _FlixQuestEmbeddedScreenState();
}

class _FlixQuestEmbeddedScreenState extends State<FlixQuestEmbeddedScreen> {
  late final Future<_FlixQuestDependencies> _dependencies = _prepare();

  Future<_FlixQuestDependencies> _prepare() async {
    // Firebase is an enhancement, never a reason to keep the catalog off
    // screen. Start it in the background so a missing native configuration
    // cannot hold the embedded app behind its startup gate.
    _startOptionalFirebase();

    // The home page stores its selected tab in SharedPreferences. This is the
    // only small local prerequisite for rendering the original FlixQuest
    // surface; every other startup task is deliberately best effort.
    flixquest_constants.sharedPrefsSingleton =
        await SharedPreferences.getInstance();

    final settings = SettingsProvider();
    final recent = RecentProvider();
    final bookmarks = BookmarkProvider();
    final dependencies = AppDependencyProvider();

    // Render with safe defaults first. A bad preference row, unavailable
    // platform plugin, or Firebase error must not replace the actual screens
    // with a startup error page.
    unawaited(_hydrateBestEffort(
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

  void _startOptionalFirebase() {
    if (Firebase.apps.isNotEmpty) return;
    unawaited(
      Firebase.initializeApp().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          debugPrint('FlixQuest optional Firebase unavailable: $error');
        },
      ),
    );
  }

  Future<void> _hydrateBestEffort({
    required SettingsProvider settings,
    required RecentProvider recent,
    required BookmarkProvider bookmarks,
    required AppDependencyProvider dependencies,
  }) async {
    await _ignoreStartupFailure(
      'settings',
      () => Future.wait([
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
      ]),
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
          // Only the local SharedPreferences prerequisite can reach this
          // branch. Never expose an exception as the product screen.
          debugPrint('FlixQuest local startup failed: ${snapshot.error}');
          return const _FlixQuestStartupFallback();
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
            child: const FlixQuestHomePage(),
          ),
        );
      },
    );
  }
}

class _FlixQuestStartupFallback extends StatelessWidget {
  const _FlixQuestStartupFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF070B17),
      child: Center(
        child: CircularProgressIndicator(),
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