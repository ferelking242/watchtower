import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:watchtower/modules/music/collections/routes.dart'
    show rootNavigatorKey;
import 'package:watchtower/modules/music/collections/routes.gr.dart';

/// Auto-route router for the embedded Spotube music module.
///
/// Route tree mirrors the original Spotube app structure:
///   - GettingStartedRoute  → shown on first launch (plugin setup wizard)
///   - RootAppRoute         → main shell (sidebar + bottom player + AutoRouter)
///       ├ HomeRoute             (initial child — browse / featured)
///       ├ SearchRoute
///       ├ LyricsRoute
///       ├ StatsRoute
///       ├ LibraryRoute (shell with its own AutoRouter)
///       │   ├ UserPlaylistsRoute  (initial)
///       │   ├ UserArtistsRoute
///       │   ├ UserAlbumsRoute
///       │   ├ UserLocalLibraryRoute
///       │   └ UserDownloadsRoute
///       ├ ProfileRoute
///       ├ ConnectRoute
///       ├ SettingsRoute
///       └ … pushed-overlay routes (Album, Artist, Track, Playlist, …)
class SpotubeAppRouter extends RootStackRouter {
  /// Each [MusicDiscoveryScreen] instance must pass its own [navigatorKey]
  /// so simultaneous embeddings (Discover + Hub + Library) don't fight over
  /// the same GlobalKey and produce blank screens.
  SpotubeAppRouter({GlobalKey<NavigatorState>? navigatorKey})
      : super(navigatorKey: navigatorKey ?? rootNavigatorKey);

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: GettingStartedRoute.page),
        AutoRoute(
          page: RootAppRoute.page,
          initial: true,
          children: [
            AutoRoute(page: HomeRoute.page, initial: true),
            AutoRoute(page: SearchRoute.page),
            AutoRoute(page: LyricsRoute.page),
            AutoRoute(page: StatsRoute.page),
            AutoRoute(
              page: LibraryRoute.page,
              children: [
                AutoRoute(page: UserPlaylistsRoute.page, initial: true),
                AutoRoute(page: UserArtistsRoute.page),
                AutoRoute(page: UserAlbumsRoute.page),
                AutoRoute(page: UserLocalLibraryRoute.page),
                AutoRoute(page: UserDownloadsRoute.page),
              ],
            ),
            AutoRoute(page: ProfileRoute.page),
            AutoRoute(page: ConnectRoute.page),
            AutoRoute(page: SettingsRoute.page),
            AutoRoute(page: AlbumRoute.page),
            AutoRoute(page: ArtistRoute.page),
            AutoRoute(page: PlaylistRoute.page),
            AutoRoute(page: LikedPlaylistRoute.page),
            AutoRoute(page: TrackRoute.page),
            AutoRoute(page: LastFMLoginRoute.page),
            AutoRoute(page: MiniLyricsRoute.page),
            AutoRoute(page: PlayerLyricsRoute.page),
            AutoRoute(page: PlayerQueueRoute.page),
            AutoRoute(page: PlayerTrackSourcesRoute.page),
            AutoRoute(page: HomeBrowseSectionItemsRoute.page),
            AutoRoute(page: LocalLibraryRoute.page),
            AutoRoute(page: ConnectControlRoute.page),
            AutoRoute(page: SettingsMetadataProviderRoute.page),
            AutoRoute(page: SettingsMetadataProviderFormRoute.page),
            AutoRoute(page: SettingsScrobblingRoute.page),
            AutoRoute(page: AboutSpotubeRoute.page),
            AutoRoute(page: BlackListRoute.page),
            AutoRoute(page: LogsRoute.page),
            AutoRoute(page: StatsAlbumsRoute.page),
            AutoRoute(page: StatsArtistsRoute.page),
            AutoRoute(page: StatsMinutesRoute.page),
            AutoRoute(page: StatsPlaylistsRoute.page),
            AutoRoute(page: StatsStreamFeesRoute.page),
            AutoRoute(page: StatsStreamsRoute.page),
          ],
        ),
      ];
}
