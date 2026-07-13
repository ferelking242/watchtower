import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/models/track_search.dart';
import 'package:watchtower/modules/anime/anime_player_view.dart';
import 'package:watchtower/modules/anime/anime_discovery_screen.dart';
import 'package:watchtower/modules/manga/manga_discovery_screen.dart';
import 'package:watchtower/modules/browse/extension/edit_code.dart';
import 'package:watchtower/modules/browse/extension/extension_detail.dart';
import 'package:watchtower/modules/browse/extension/widgets/create_extension.dart';
import 'package:watchtower/modules/browse/sources/sources_filter_screen.dart';
import 'package:watchtower/modules/calendar/calendar_screen.dart';
import 'package:watchtower/modules/calendar/schedule_screen.dart';
import 'package:watchtower/modules/manga/detail/widgets/migrate_screen.dart';
import 'package:watchtower/modules/mass_migration/mass_migration_source_selection_screen.dart';
import 'package:watchtower/modules/manga/detail/widgets/recommendation_screen.dart';
import 'package:watchtower/modules/manga/detail/widgets/watch_order_screen.dart';
import 'package:watchtower/modules/more/data_and_storage/create_backup.dart';
import 'package:watchtower/modules/more/data_and_storage/data_and_storage.dart';
import 'package:watchtower/modules/more/settings/appearance/custom_navigation_settings.dart';
import 'package:watchtower/modules/more/settings/browse/source_repositories.dart';
import 'package:watchtower/modules/more/settings/player/custom_button_screen.dart';
import 'package:watchtower/modules/more/settings/player/player_advanced_screen.dart';
import 'package:watchtower/modules/more/settings/player/player_audio_screen.dart';
import 'package:watchtower/modules/more/settings/player/player_decoder_screen.dart';
import 'package:watchtower/modules/more/settings/player/player_overview_screen.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/statistics/statistics_screen.dart';
import 'package:watchtower/modules/novel/novel_reader_view.dart';
import 'package:watchtower/modules/tracker_library/tracker_library_screen.dart';
import 'package:watchtower/modules/updates/updates_screen.dart';
import 'package:watchtower/modules/more/categories/categories_screen.dart';
import 'package:watchtower/modules/more/settings/downloads/downloads_screen.dart';
import 'package:watchtower/modules/more/settings/downloads/local_source_import_page.dart';
import 'package:watchtower/modules/more/settings/player/player_screen.dart';
import 'package:watchtower/modules/more/settings/sync/sync.dart';
import 'package:watchtower/modules/more/settings/track/track.dart';
import 'package:watchtower/modules/more/settings/track/manage_trackers/manage_trackers.dart';
import 'package:watchtower/modules/more/settings/track/manage_trackers/tracking_detail.dart';
import 'package:watchtower/modules/webview/webview.dart';
import 'package:watchtower/modules/browse/browse_screen.dart';
import 'package:watchtower/modules/browse/marketplace_screen.dart';
import 'package:watchtower/modules/browse/extension/extension_lang.dart';
import 'package:watchtower/modules/browse/extension_diagnostic_screen.dart';
import 'package:watchtower/modules/browse/global_search/global_search_screen.dart';
import 'package:watchtower/modules/main_view/main_screen.dart';
import 'package:watchtower/modules/history/history_screen.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/main_library_screen.dart';
import 'package:watchtower/modules/home/anilist_browse_screen.dart';
import 'package:watchtower/modules/home/anilist_detail_screen.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/novel/novel_discovery_screen.dart';
import 'package:watchtower/modules/music/music_discovery_screen.dart';
import 'package:watchtower/modules/music/pages/search/music_search_screen.dart';
import 'package:watchtower/modules/game/game_discovery_screen.dart';
import 'package:watchtower/modules/home/watchtower_home_screen.dart';
import 'package:watchtower/modules/home/widgets/watchtower_search_screen.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_main.dart';
import 'package:watchtower/modules/manga/home/manga_home_screen.dart';
import 'package:watchtower/modules/novel/home/novel_home_screen.dart';
import 'package:watchtower/modules/watch/home/watch_home_screen.dart';
import 'package:watchtower/modules/watch/reel/reel_screen.dart';
import 'package:watchtower/modules/watch/reel/creator_profile_screen.dart';
import 'package:watchtower/modules/manga/reader/reader_view.dart';
import 'package:watchtower/modules/more/about/about_screen.dart';
import 'package:watchtower/modules/more/about/log_viewer_screen.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_screen.dart';
import 'package:watchtower/modules/more/more_screen.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart';
import 'package:watchtower/modules/more/settings/appearance/ui_settings_screen.dart';
import 'package:watchtower/modules/more/settings/browse/browse_screen.dart';
import 'package:watchtower/modules/more/settings/browse/extension_server_screen.dart';
import 'package:watchtower/modules/more/settings/general/general_screen.dart';
import 'package:watchtower/modules/more/settings/general/recommendations_screen.dart';
import 'package:watchtower/modules/more/settings/general/extension_cookie_manager_screen.dart';
import 'package:watchtower/modules/more/settings/reader/reader_screen.dart';
import 'package:watchtower/modules/more/settings/settings_screen.dart';
import 'package:watchtower/modules/more/settings/security/security_screen.dart';
import 'package:watchtower/modules/more/settings/advanced/advanced_screen.dart';
import 'package:watchtower/modules/onboarding/onboarding_screen.dart';
import 'package:watchtower/modules/onboarding/onboarding_state.dart';
import 'package:watchtower/modules/splash/splash_screen.dart';
import 'package:watchtower/modules/transfer/transfer_screen.dart';
import 'package:watchtower/modules/browse/local_how_to_screen.dart';
import 'package:watchtower/modules/search/watchtower_discover_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/cupertino.dart';
import 'package:watchtower/remote/remote_mode_screen.dart';
import 'package:watchtower/remote/remote_setup_screen.dart';
part 'router.g.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
@riverpod
GoRouter router(Ref ref) {
  final router = RouterNotifier();
  final hiddenItems = ref.read(hideItemsStateProvider);
  final mainLocation = ref
      .watch(navigationOrderStateProvider)
      .where((e) => !hiddenItems.contains(e))
      .first;
  // Onboarding tutorial disabled — was low quality and confusing, always
  // land straight on the main app. Route kept registered below in case a
  // future rewrite wants to reuse it.
  final destination = mainLocation;

  return GoRouter(
    observers: [],
    initialLocation: destination,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: router,
    routes: [
      ...router._routes,
    ],
    navigatorKey: navigatorKey,
    onException: (context, state, router) => router.go(mainLocation),
    redirect: (context, state) {
      if (state.matchedLocation == '/more') return '/settings';
      return null;
    },
  );
}

@riverpod
class RouterCurrentLocationState extends _$RouterCurrentLocationState {
  bool _didSubscribe = false;
  @override
  String? build() {
    ref.keepAlive();
    // Delay listener‐registration until after the first frame.
    if (!_didSubscribe) {
      _didSubscribe = true;
      // Schedule the registration to run after the first build/frame:
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listener();
      });
    }
    return null;
  }

  void _listener() {
    final router = ref.read(routerProvider);
    router.routerDelegate.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // go_router 17.x: ImperativeRouteMatch (created by context.push) does
        // not implement _getsLastRouteFromMatches — throws UnimplementedError
        // when the router tries to serialize route info after navigation.
        try {
          final RouteMatchList matches =
              router.routerDelegate.currentConfiguration;
          if (matches.isEmpty) return;
          final RouteMatch lastMatch = matches.last;
          final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
              ? lastMatch.matches
              : matches;
          state = matchList.uri.toString();
        } catch (_) {
          // Silently swallow — state keeps its last known location value.
        }
      });
    });
  }

  void refresh() {
    _listener();
  }
}

class RouterNotifier extends ChangeNotifier {
  List<RouteBase> get _routes => [
    ShellRoute(
      builder: (context, state, child) => MainScreen(child: child),
      routes: [
        _genericRoute<String?>(
          name: "Library",
          builder: (id) => MainLibraryScreen(presetInput: id),
        ),
        _genericRoute(
          name: "MangaLibrary",
          child: const MangaDiscoveryScreen(),
        ),
        _genericRoute(
          name: "AnimeLibrary",
          child: const AnimeDiscoveryScreen(),
        ),
        _genericRoute(
          name: "NovelLibrary",
          child: const NovelDiscoveryScreen(),
        ),
        _genericRoute(
          name: "MusicLibrary",
          child: const MusicDiscoveryScreen(),
        ),
        _genericRoute(
          name: "MusicSearch",
          child: const MusicSearchScreen(),
        ),
        _genericRoute(
          name: "MusicLibraryPage",
          child: const MusicDiscoveryScreen(initialRoute: 'library'),
        ),
        _genericRoute(
          name: "GameLibrary",
          child: const GameDiscoveryScreen(),
        ),
        _genericRoute(
          name: "WatchtowerHome",
          child: const WatchtowerHomeScreen(),
        ),
        _genericRoute<String?>(
          name: "trackerLibrary",
          builder: (id) => TrackerLibraryScreen(presetInput: id),
        ),
        _genericRoute(name: "history", child: const HistoryScreen()),
        _genericRoute(name: "updates", child: const UpdatesScreen()),
        _genericRoute(name: "browse", child: const BrowseScreen()),
        _genericRoute(name: "marketplace", child: const MarketplaceScreen()),
        _genericRoute(name: "downloadQueue", child: const DownloadQueueScreen()),
        _genericRoute(name: "discover", child: const WatchtowerDiscoverScreen()),
      ],
    ),
    _genericRoute<(Source?, bool)>(
      name: "mangaHome",
      builder: (id) => MangaHomeScreen(source: id.$1!, isLatest: id.$2),
    ),
    _genericRoute<(Source?, bool)>(
      name: "watchHome",
      builder: (id) => WatchHomeScreen(source: id.$1!, isLatest: id.$2),
    ),
    _genericRoute<Map<String, dynamic>>(
      name: "reel",
      builder: (data) => ReelScreen(
        source: data['source'] as Source,
        listId: data['listId'] as String,
        startGifId: data['startGifId'] as String?,
      ),
    ),
    _genericRoute<Map<String, dynamic>>(
      name: "creatorProfile",
      builder: (data) => CreatorProfileScreen(
        source:        data['source']        as Source,
        creator:       data['creator']       as String,
        creatorAvatar: (data['creatorAvatar'] ?? '') as String,
        verified:      (data['verified']     ?? false) as bool,
        followers:     (data['followers']    ?? 0) as int,
        bio:           (data['bio']          ?? '') as String,
      ),
    ),
    _genericRoute<(Source?, bool)>(
      name: "novelHome",
      builder: (id) => NovelHomeScreen(source: id.$1!, isLatest: id.$2),
    ),
    _genericRoute<int>(
      path: "/manga-reader/detail",
      builder: (id) => MangaReaderDetail(mangaId: id),
    ),
    _genericRoute<int>(
      name: "mangaReaderView",
      builder: (id) => MangaReaderView(chapterId: id),
    ),
    _genericRoute<int>(
      name: "animePlayerView",
      builder: (id) => AnimePlayerView(episodeId: id),
    ),
    _genericRoute<int>(
      name: "novelReaderView",
      builder: (id) => NovelReaderView(chapterId: id),
    ),
    _genericRoute<ItemType>(
      name: "ExtensionLang",
      builder: (itemType) => ExtensionsLang(itemType: itemType),
    ),
    _genericRoute(name: "settings", child: const SettingsScreen()),
    _genericRoute(name: "appearance", child: const AppearanceScreen()),
    _genericRoute(name: "uiSettings", child: const UiSettingsScreen()),
    _genericRoute<Source>(
      name: "extension_detail",
      builder: (source) => ExtensionDetail(source: source),
    ),
    _genericRoute<ItemType>(
      name: "extensionDiagnostic",
      builder: (itemType) => ExtensionDiagnosticScreen(itemType: itemType),
    ),
    _genericRoute<(String?, ItemType)?>(
      name: "globalSearch",
      builder: (data) => GlobalSearchScreen(
        search: data?.$1,
        itemType: data?.$2 ?? ItemType.manga,
      ),
    ),
    _genericRoute<AnilistMedia>(
      name: "anilistDetail",
      builder: (media) => AnilistDetailScreen(media: media),
    ),
    _genericRoute<(AnilistBrowseFilter, String)>(
      name: "anilistBrowse",
      builder: (data) =>
          AnilistBrowseScreen(filter: data.$1, title: data.$2),
    ),
    _genericRoute(name: "about", child: const AboutScreen()),
    _genericRoute(name: "logViewer", child: const LogViewerScreen()),
    _genericRoute(name: "track", child: const TrackScreen()),
    _genericRoute(name: "sync", child: const SyncScreen()),
    _genericRoute<ItemType>(
      name: "sourceFilter",
      builder: (itemType) => SourcesFilterScreen(itemType: itemType),
    ),
    _genericRoute<Map<String, dynamic>>(
      name: "mangawebview",
      builder: (data) => MangaWebView(
        url: data["url"]!,
        title: data['title']!,
        initialFraction: (data['initialFraction'] as double?) ?? 1.0,
      ),
    ),
    _genericRoute<(bool, int)>(
      name: "categories",
      builder: (data) => CategoriesScreen(data: data),
    ),
    _genericRoute(name: "statistics", child: const StatisticsScreen()),
    _genericRoute(name: "general", child: const GeneralScreen()),
    _genericRoute(name: "recommendations", child: const RecommendationsScreen()),
    _genericRoute(name: "extension-cookies", child: const ExtensionCookieManagerScreen()),
    _genericRoute(name: "readerMode", child: const ReaderScreen()),
    _genericRoute(name: "browseS", child: const BrowseSScreen()),
    _genericRoute(
      name: "extensionServer",
      child: const ExtensionServerScreen(),
    ),
    _genericRoute<ItemType>(
      name: "SourceRepositories",
      builder: (itemType) => SourceRepositories(itemType: itemType),
    ),
    _genericRoute(name: "downloads", child: const DownloadsScreen()),
    _genericRoute(name: "dataAndStorage", child: const DataAndStorage()),
    _genericRoute(name: "security", child: const SecurityScreen()),
    _genericRoute(name: "advanced", child: const AdvancedScreen()),
    _genericRoute(name: "manageTrackers", child: const ManageTrackersScreen()),
    _genericRoute<TrackPreference>(
      name: "trackingDetail",
      builder: (trackerPref) => TrackingDetail(trackerPref: trackerPref),
    ),
    _genericRoute(name: "playerOverview", child: const PlayerOverviewScreen()),
    _genericRoute(name: "playerMode", child: const PlayerScreen()),
    _genericRoute<int>(
      name: "codeEditor",
      builder: (sourceId) => CodeEditorPage(sourceId: sourceId),
    ),
    _genericRoute(name: "createExtension", child: const CreateExtension()),
    _genericRoute(name: "createBackup", child: const CreateBackup()),
    _genericRoute(
      name: "customNavigationSettings",
      child: const CustomNavigationSettings(),
    ),
    _genericRoute(
      name: "customButtonScreen",
      child: const CustomButtonScreen(),
    ),
    _genericRoute(
      name: "playerDecoderScreen",
      child: const PlayerDecoderScreen(),
    ),
    _genericRoute(name: "playerAudioScreen", child: const PlayerAudioScreen()),
    _genericRoute(
      name: "playerAdvancedScreen",
      child: const PlayerAdvancedScreen(),
    ),
    _genericRoute<ItemType?>(
      name: "calendarScreen",
      builder: (itemType) => CalendarScreen(itemType: itemType),
    ),
    _genericRoute(name: "schedule", child: const ScheduleScreen()),
    _genericRoute<Manga>(
      name: "migrate",
      builder: (manga) => MigrationScreen(manga: manga),
    ),
    _genericRoute<Manga>(
      name: "massMigration",
      builder: (manga) =>
          MassMigrationSourceSelectionScreen(initialManga: manga),
    ),
    _genericRoute<(Manga, TrackSearch)>(
      name: "migrate/tracker",
      builder: (data) => MigrationScreen(manga: data.$1, trackSearch: data.$2),
    ),
    _genericRoute<(String, ItemType, AlgorithmWeights)>(
      name: "recommendationDetail",
      builder: (data) => RecommendationScreen(
        name: data.$1,
        itemType: data.$2,
        algorithmWeights: data.$3,
      ),
    ),
    _genericRoute<(String, Track?)>(
      name: "watchOrder",
      builder: (data) => WatchOrderScreen(name: data.$1, track: data.$2),
    ),
    _genericRoute(name: "onboarding", child: const OnboardingScreen()),
      _genericRoute<ItemType>(
      name: "localSources",
      builder: (itemType) => LocalBrowserPage(itemType: itemType),
    ),
    _genericRoute(name: "watchtowerSearch", child: const WatchtowerSearchScreen()),
    _genericRoute(name: "transfer", child: const TransferScreen()),
    _genericRoute<ItemType>(
      name: "localHowTo",
      builder: (itemType) => LocalHowToScreen(itemType: itemType),
    ),
    _genericRoute(name: "remoteMode", child: const RemoteModeScreen()),
    _genericRoute(name: "remoteSetup", child: const RemoteSetupScreen()),
  ];

  GoRoute _genericRoute<T>({
    String? name,
    String? path,
    Widget Function(T extra)? builder,
    Widget? child,
  }) {
    return GoRoute(
      path: path ?? (name != null ? "/$name" : "/"),
      name: name,
      builder: (context, state) {
        if (builder != null) {
          final id = state.extra as T;
          return builder(id);
        } else {
          return child!;
        }
      },
      pageBuilder: (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
          ? (context, state) {
              final pageChild = builder != null
                  ? builder(state.extra as T)
                  : child!;
              return transitionPage(key: state.pageKey, child: pageChild);
            }
          : null,
    );
  }
}

Page transitionPage({required LocalKey key, required child}) {
  return CupertinoPage(key: key, child: child);
}

Route createRoute({required Widget page}) {
  return (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
      ? CupertinoPageRoute(builder: (context) => page)
      : MaterialPageRoute(builder: (context) => page);
}
