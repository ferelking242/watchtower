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
  const FlixQuestEmbeddedScreen({super.key});

  @override
  State<FlixQuestEmbeddedScreen> createState() =>
      _FlixQuestEmbeddedScreenState();
}

class _FlixQuestEmbeddedScreenState extends State<FlixQuestEmbeddedScreen> {
  late final Future<_FlixQuestDependencies> _dependencies = _prepare();

  Future<_FlixQuestDependencies> _prepare() async {
    flixquest_constants.sharedPrefsSingleton =
        await SharedPreferences.getInstance();

    final settings = SettingsProvider();
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
    settings.completeHydration();

    final recent = RecentProvider();
    final bookmarks = BookmarkProvider();
    final dependencies = AppDependencyProvider();
    await Future.wait([
      recent.fetchMovies(),
      recent.fetchEpisodes(),
      bookmarks.fetchBookmarks(),
      dependencies.getFlixQuestLogo(),
      dependencies.getOccasionalTheme(),
      dependencies.getAmbientMode(),
      dependencies.getFQUrl(),
      dependencies.getTmdbProxy(),
      dependencies.getUpdateConfiguration(),
    ]);

    return _FlixQuestDependencies(
      settings: settings,
      recent: recent,
      bookmarks: bookmarks,
      dependencies: dependencies,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FlixQuestDependencies>(
      future: _dependencies,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'FlixQuest could not be initialized.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
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
            child: const FlixQuestHomePage(),
          ),
        );
      },
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