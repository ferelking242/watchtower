import 'dart:async';
import 'dart:math' as math;
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/providers/downloaded_only_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/widgets/loading_icon.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/modules/main_view/providers/migration.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/auto_backup.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/services/sync_server.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart' show showAccountSheet;
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/log/log_overlay.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/modules/main_view/widgets/watchtower_menu_overlay.dart';
import 'package:watchtower/modules/music/widgets/music_mini_player.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';


final libLocationRegex = RegExp(r"^/(Manga|Anime|Novel|Music|Game)Library$");

/// Whether the floating dock should be hidden because the user is scrolling
/// down. Pages can opt-in to driving this by wrapping their scrollables in a
/// `NotificationListener<UserScrollNotification>` that updates this provider.
class _DockHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final dockHiddenProvider =
    NotifierProvider<_DockHiddenNotifier, bool>(_DockHiddenNotifier.new);

class _MenuOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final menuOpenProvider =
    NotifierProvider<_MenuOpenNotifier, bool>(_MenuOpenNotifier.new);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  Timer? _backupTimer;
  Timer? _syncTimer;

  late final String _defaultLocation;
  late final List<String> _navigationOrder;
  late final int _autoSyncFrequency;

  static final Map<String, String> _hyphenatedLabelsCache = {};

  final Map<String, List<NavigationRailDestination>> _desktopDestinationsCache =
      {};
  final Map<String, List<Widget>> _mobileDestinationsCache = {};
  void _clearCache() {
    _hyphenatedLabelsCache.clear();
    _desktopDestinationsCache.clear();
    _mobileDestinationsCache.clear();
  }

  String getHyphenatedUpdatesLabel(String languageCode, String defaultLabel) {
    final cacheKey = '$languageCode:$defaultLabel';
    return _hyphenatedLabelsCache.putIfAbsent(cacheKey, () {
      switch (languageCode) {
        case 'de':
          return "Aktuali-\nsierungen";
        case 'es':
        case 'es_419':
          return "Actuali-\nzaciones";
        case 'it':
          return "Aggiorna-\nmenti";
        case 'tr':
          return "Güncel-\nlemeler";
        default:
          return defaultLabel;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _navigationOrder = ref.read(navigationOrderStateProvider);
    _autoSyncFrequency = ref
        .read(synchingProvider(syncId: 1))
        .autoSyncFrequency;
    final hiddenItems = ref.read(hideItemsStateProvider);

    _defaultLocation = _navigationOrder
        .where((e) => !hiddenItems.contains(e))
        .first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(_defaultLocation);
        _initializeTimers();
        _initializeProviders();
      }
    });

    discordRpc?.connect(ref);
  }

  void _initializeTimers() {
    _backupTimer = Timer.periodic(
      const Duration(minutes: 5),
      _onBackupTimerTick,
    );

    if (_autoSyncFrequency != 0) {
      _syncTimer = Timer.periodic(
        Duration(seconds: _autoSyncFrequency),
        _onSyncTimerTick,
      );
    }
  }

  void _initializeProviders() {
    Future.microtask(() {
      if (mounted) {
        ref.read(checkForUpdateProvider(context: context));
        for (var type in ItemType.values) {
          ref.read(
            fetchItemSourcesListProvider(
              id: null,
              reFresh: false,
              itemType: type,
            ),
          );
        }
        // Auto-show the floating log overlay if logs are enabled by default.
        final enableLogs = ref.read(logsStateProvider);
        if (enableLogs) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => LogOverlayController.instance.show(),
          );
        }
      }
    });
  }

  void _onBackupTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    ref.read(checkAndBackupProvider);
  }

  void _onSyncTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    try {
      final l10n = l10nLocalizations(context)!;
      ref.read(syncServerProvider(syncId: 1).notifier).startSync(l10n, true);
    } catch (e) {
      botToast(
        "Failed to sync! Maybe the sync server is down. "
        "Restart the app to resume auto sync.",
      );
      timer.cancel();
    }
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    _syncTimer?.cancel();
    discordRpc?.disconnect();
    super.dispose();
  }

  int currentIndex = 0;
  bool isLibSwitch = false;
  bool isLibrarySwitch = false;
  @override
  Widget build(BuildContext context) {
    ref.listen<Locale>(l10nLocaleStateProvider, (previous, next) {
      _clearCache();
      setState(() {});
    });
    // Invalidate destination caches whenever nav display settings change so
    // the classic dock and desktop rail pick up the new values immediately.
    ref.listen<bool>(navShowLabelsProvider, (_, __) => _clearCache());
    ref.listen<double>(navIconSizeProvider, (_, __) => _clearCache());
    ref.listen<double>(navItemSpacingProvider, (_, __) => _clearCache());
    ref.listen<String>(navDockStyleProvider, (_, __) => _clearCache());
    // Reset dock visibility whenever the route changes so pages with little
    // content (e.g. /plugins) never get stuck with a hidden dock.
    ref.listen<String?>(routerCurrentLocationStateProvider, (prev, next) {
      if (prev != next) {
        ref.read(dockHiddenProvider.notifier).set(false);
      }
    });

    final l10n = context.l10n;
    final route = GoRouter.of(context);
    final navigationOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final mergeLibraryNavMobile = ref.watch(mergeLibraryNavMobileStateProvider);
    final mergeLibraryDock = ref.watch(mergeLibraryOnDockProvider);
    final dockStyle = ref.watch(navDockStyleProvider);
    final location = ref.watch(routerCurrentLocationStateProvider);

    return ref
        .watch(migrationProvider)
        .when(
          data: (_) => Consumer(
            builder: (context, ref, child) {
              final isReadingScreen = _isReadingScreen(location);
              bool uniqueSwitch = false;
              // Guard isLibSwitch with mergeLibraryNavMobile so that disabling
              // the Hub toggle instantly collapses back to the normal item list.
              List<String> dest;
              if (isLibSwitch && mergeLibraryNavMobile) {
                final libItems = navigationOrder
                    .where((nav) => libLocationRegex.hasMatch(nav))
                    .toList();
                dest = [
                  "_disableLibSwitch",
                  ...libItems,
                ].where((nav) => !hideItems.contains(nav)).toList();
                // Always expose Music in the Hub sub-dock even if the user
                // hasn't added /MusicLibrary to their navigation order.
                final hasMusicInDest = dest.any((n) =>
                    n == '/MusicLibrary' || n == '/MusicSearch');
                if (!hasMusicInDest && !hideItems.contains('/MusicSearch')) {
                  dest.add('/MusicSearch');
                }
                // Reset dock-hidden state so the sub-dock is always visible.
                Future.microtask(
                    () => ref.read(dockHiddenProvider.notifier).set(false));
              } else {
                dest = navigationOrder
                    .where((nav) => !hideItems.contains(nav))
                    .toList();
              }

              if (mergeLibraryNavMobile && !isLibSwitch) {
                dest = dest
                    .map((nav) {
                      if ([
                        "/MangaLibrary",
                        "/AnimeLibrary",
                        "/NovelLibrary",
                      ].contains(nav)) {
                        if (uniqueSwitch) return null;
                        uniqueSwitch = true;
                        return "_enableLibSwitch";
                      }
                      // Music & Game are accessible via Hub expansion — hide
                      // them from the main dock row when Hub is enabled.
                      if (nav == "/MusicLibrary" || nav == "/GameLibrary") {
                        return null;
                      }
                      return nav;
                    })
                    .nonNulls
                    .toList();
              }

              // Insert /Library on dock when Library toggle is ON
              if (mergeLibraryDock && !isLibSwitch) {
                // Always filter out individual library items when merge is ON,
                // regardless of whether hideItems was explicitly updated.
                const _individualLibs = [
                  '/MangaLibrary',
                  '/AnimeLibrary',
                  '/NovelLibrary',
                  '/MusicLibrary',
                  '/GameLibrary',
                ];
                dest = dest
                    .where((e) => !_individualLibs.contains(e))
                    .toList();

                if (!dest.contains('/Library')) {
                  final insertIdx = dest.indexWhere(
                    (e) =>
                        e != '_enableLibSwitch' &&
                        !libLocationRegex.hasMatch(e),
                  );
                  if (insertIdx == -1) {
                    dest.add('/Library');
                  } else {
                    dest.insert(insertIdx, '/Library');
                  }
                }
              }

              // ── Library sub-dock mode ───────────────────────────────────────
              // When isLibrarySwitch is on, show [Back, /Library, /MusicLibraryPage].
              // Otherwise, if /Library is in dest, replace it with
              // _enableLibrarySwitch so tapping opens the sub-dock instead of
              // navigating directly to the library page.
              if (isLibrarySwitch) {
                dest = ['_disableLibrarySwitch', '/Library', '/MusicLibraryPage']
                    .where((nav) => !hideItems.contains(nav))
                    .toList();
              } else if (dest.contains('/Library') && !isLibSwitch) {
                dest = dest
                    .map((nav) => nav == '/Library' ? '_enableLibrarySwitch' : nav)
                    .toList();
              }

              if (isLibSwitch &&
                  (currentIndex >= dest.length ||
                      !libLocationRegex.hasMatch(location ?? ""))) {
                currentIndex = 0;
              } else {
                String? libLocation;
                if (mergeLibraryNavMobile &&
                    !isLibSwitch) {
                  libLocation = location?.replaceAll(
                    libLocationRegex,
                    "_enableLibSwitch",
                  );
                }
                int currentIdx = dest.indexOf(
                  libLocation ?? location ?? _defaultLocation,
                );
                if (currentIdx != -1) {
                  currentIndex = currentIdx;
                }
              }

              // ── Browse always in dock, Marketplace always in menu ─────────
              {
                final _mktI = dest.indexOf('/marketplace');
                final _brwI = dest.indexOf('/browse');
                if (_mktI >= 0 && _mktI < 4) {
                  dest = List<String>.from(dest)..removeAt(_mktI)..add('/marketplace');
                }
                final _brwI2 = dest.indexOf('/browse');
                if (_brwI2 >= 4) {
                  dest = List<String>.from(dest)..removeAt(_brwI2)..insert(3, '/browse');
                }
              }

              // ── NFile sub-dock: show back button when inside nfile routes ─
              if (location?.startsWith('/nfile') == true) {
                dest = ['_nfileBack', ...dest];
              }

              // ── 5-item dock cap ───────────────────────────────────────────
              // Classic dock gets a capped dest (4 user items); overflow goes
              // to the menu overlay.  Floating dock caps internally in _buildItems.
              final _cappedDest = dest.take(4).toList();
              final _overflowRoutes =
                  dest.length > 4 ? dest.sublist(4) : <String>[];

              final menuOpen = ref.watch(menuOpenProvider);
              final incognitoMode = ref.watch(incognitoModeStateProvider);
              final downloadedOnly = ref.watch(downloadedOnlyStateProvider);
              final isLongPressed = ref.watch(isLongPressedStateProvider);

              // ── PC sidebar mode (also auto-activates on Android TV / Smart TV) ──
              // NavigationMode.directional is set by the Android TV system when
              // a D-pad / remote control is the primary input device.
              final _isTV = MediaQuery.of(context).navigationMode ==
                  NavigationMode.directional;
              if ((dockStyle == 'pc_sidebar' || _isTV) &&
                  MediaQuery.of(context).size.width >= 700 &&
                  !isReadingScreen) {
                return _TabletLayout(
                  isLongPressed: isLongPressed,
                  location: location,
                  dest: dest,
                  currentIndex: currentIndex,
                  route: route,
                  child: widget.child,
                  ref: ref,
                  buildNavigationWidgetsDesktop: _buildNavigationWidgetsDesktop,
                );
              }

              return Column(
                children: [
                  Flexible(
                    child: Stack(
                      children: [
                    Scaffold(
                      extendBody: true,
                      // The dock is now always persistent — it no longer
                      // auto-hides on scroll/inactivity nor when the drawer
                      // is swiped open. See _isVisible() in _FloatingDockState.
                      body: widget.child,
                      bottomNavigationBar: dockStyle == 'classic'
                              ? _RoundedOrClassicDock(
                                  isRounded: false,
                                  dest: _cappedDest,
                                  currentIndex: currentIndex,
                                  buildDestinations:
                                      _buildNavigationWidgetsMobile,
                                  ref: ref,
                                  onDestinationSelected: (idx) {
                                    if (idx >= _cappedDest.length) {
                                      ref.read(menuOpenProvider.notifier).state =
                                          !ref.read(menuOpenProvider);
                                      return;
                                    }
                                    final destination = _cappedDest[idx];
                                    AppLogger.log(
                                      'Nav -> $destination',
                                      logLevel: LogLevel.debug,
                                      tag: LogTag.ui,
                                    );
                                    ref
                                        .read(dockHiddenProvider.notifier)
                                        .set(false);
                                    if (destination == "_enableLibSwitch") {
                                      setState(() => isLibSwitch = true);
                                    } else if (destination == "_disableLibSwitch") {
                                      setState(() => isLibSwitch = false);
                                    } else if (destination == "_enableLibrarySwitch") {
                                      setState(() => isLibrarySwitch = true);
                                    } else if (destination == "_disableLibrarySwitch") {
                                      setState(() => isLibrarySwitch = false);
                                    } else if (destination == "_nfileBack") {
                                      route.go('/plugins');
                                    } else {
                                      route.go(destination);
                                    }
                                  },
                                )
                              : _FloatingDock(
                                  isLongPressed: isLongPressed,
                                  location: location,
                                  dest: dest,
                                  ref: ref,
                                  showPill: true,
                                  onDestinationSelected: (destination) {
                                    AppLogger.log(
                                      'Nav -> $destination',
                                      logLevel: LogLevel.debug,
                                      tag: LogTag.ui,
                                    );
                                    ref
                                        .read(dockHiddenProvider.notifier)
                                        .set(false);
                                    if (destination == "_enableLibSwitch") {
                                      setState(() => isLibSwitch = true);
                                    } else if (destination == "_disableLibSwitch") {
                                      setState(() => isLibSwitch = false);
                                    } else if (destination == "_enableLibrarySwitch") {
                                      setState(() => isLibrarySwitch = true);
                                    } else if (destination == "_disableLibrarySwitch") {
                                      setState(() => isLibrarySwitch = false);
                                    } else if (destination == "_watchtower_menu") {
                                      ref.read(menuOpenProvider.notifier).state =
                                          !ref.read(menuOpenProvider);
                                    } else if (destination == "_nfileBack") {
                                      route.go('/plugins');
                                    } else {
                                      route.go(destination);
                                    }
                                  },
                                ),
                    ),
                    if (!isReadingScreen && (downloadedOnly || incognitoMode))
                      _SideBanners(
                        downloadedOnly: downloadedOnly,
                        incognitoMode: incognitoMode,
                        l10n: l10n,
                      ),
                    // Music mini-player — shown above the dock when a track is active
                    // Music mini-player — shown on ALL pages above the dock when
                    // music is playing, except inside the music module itself
                    // where the Spotube BottomPlayer/PlayerOverlay already shows.
                    if (!isReadingScreen &&
                        location != '/MusicLibrary')
                      Consumer(
                        builder: (ctx, r, _) {
                          // Check both the custom player and the Spotube player
                          final hasCustomTrack = r.watch(
                            musicPlayerProvider
                                .select((s) => s.activeTrack != null),
                          );
                          final hasSpotubeTrack = r.watch(
                            audioPlayerProvider
                                .select((s) => s.activeTrack != null),
                          );
                          if (!hasCustomTrack && !hasSpotubeTrack) {
                            return const SizedBox.shrink();
                          }
                          final bottomInset =
                              MediaQuery.of(ctx).padding.bottom;
                          // Floating dock height
                          final dockHeight =
                              dockStyle == 'classic' ? 56.0 : 72.0;
                          return Positioned(
                            bottom: dockHeight + bottomInset,
                            left: 0,
                            right: 0,
                            child: const MusicMiniPlayer(),
                          );
                        },
                      ),
                    // Menu overlay — triggered by the dock Menu button
                    if (!isReadingScreen && menuOpen && dockStyle != 'pc_sidebar')
                      Positioned.fill(
                        child: WatchtowerMenuOverlay(
                          overflowRoutes: _overflowRoutes,
                          onClose: () =>
                              ref.read(menuOpenProvider.notifier).state = false,
                        ),
                      ),
                  ],
                ),
              ),
                ],
              );

            },
          ),
          error: (error, _) => const LoadingIcon(),
          loading: () => const LoadingIcon(),
        );
  }

  static bool _isReadingScreen(String? location) {
    return location == '/mangaReaderView' ||
        location == '/animePlayerView' ||
        location == '/novelReaderView';
  }

  List<NavigationRailDestination> _buildNavigationWidgetsDesktop(
    WidgetRef ref,
    List<String> dest,
    BuildContext context,
  ) {
    final cacheKey = dest.join(',');
    if (_desktopDestinationsCache.containsKey(cacheKey)) {
      return _desktopDestinationsCache[cacheKey]!;
    }

    final l10n = context.l10n;
    final destinations = List<NavigationRailDestination?>.filled(
      dest.length,
      null,
    );

    if (dest.contains("/Library")) {
      destinations[dest.indexOf("/Library")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.collections_bookmark),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.library),
        ),
      );
    }
    if (dest.contains("/MangaLibrary")) {
      destinations[dest.indexOf("/MangaLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.book_square),
        icon: const Icon(Broken.book_1),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.manga),
        ),
      );
    }
    if (dest.contains("/AnimeLibrary")) {
      destinations[dest.indexOf("/AnimeLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.video_square),
        icon: const Icon(Broken.video_octagon),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.watch),
        ),
      );
    }
    if (dest.contains("/NovelLibrary")) {
      destinations[dest.indexOf("/NovelLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.note_text),
        icon: const Icon(Broken.text),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.novel),
        ),
      );
    }
    if (dest.contains("/MusicLibrary")) {
      destinations[dest.indexOf("/MusicLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.music_circle),
        icon: const Icon(Broken.music_playlist),
        label: const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text('Music'),
        ),
      );
    }
    if (dest.contains("/GameLibrary")) {
      destinations[dest.indexOf("/GameLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.gameboy),
        icon: const Icon(Broken.gameboy),
        label: const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text('Games'),
        ),
      );
    }
    if (dest.contains("/WatchtowerHome")) {
      destinations[dest.indexOf("/WatchtowerHome")] =
          NavigationRailDestination(
        selectedIcon: const Icon(Broken.home_2),
        icon: const Icon(Broken.home_1),
        label: const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text('Accueil'),
        ),
      );
    }
    if (dest.contains("/updates")) {
      destinations[dest.indexOf("/updates")] = NavigationRailDestination(
        selectedIcon: _UpdatesBadgeWidget(
          icon: const Icon(Broken.notification_bing),
          ref: ref,
        ),
        icon: _UpdatesBadgeWidget(
          icon: const Icon(Broken.notification),
          ref: ref,
        ),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            getHyphenatedUpdatesLabel(
              ref.watch(l10nLocaleStateProvider).languageCode,
              l10n.updates,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (dest.contains("/history")) {
      destinations[dest.indexOf("/history")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.clock),
        icon: const Icon(Broken.clock_1),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.history),
        ),
      );
    }
    if (dest.contains("/browse")) {
      destinations[dest.indexOf("/browse")] = NavigationRailDestination(
        selectedIcon: _ExtensionBadgeWidget(
          icon: const Icon(Broken.global),
          ref: ref,
        ),
        icon: _ExtensionBadgeWidget(
          icon: const Icon(Broken.global_search),
          ref: ref,
        ),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.browse),
        ),
      );
    }
    if (dest.contains("/settings")) {
      destinations[dest.indexOf("/settings")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.setting),
        icon: const Icon(Broken.setting_2),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.more),
        ),
      );
    }
    if (dest.contains("/trackerLibrary")) {
      destinations[dest.indexOf("/trackerLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Broken.chart_21),
        icon: const Icon(Broken.presention_chart),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.tracking),
        ),
      );
    }

    final result = destinations.nonNulls.toList();
    _desktopDestinationsCache[cacheKey] = result;
    return result;
  }

  List<Widget> _buildNavigationWidgetsMobile(
    WidgetRef ref,
    List<String> dest,
    BuildContext context,
  ) {
    final cacheKey = dest.join(',');
    if (_mobileDestinationsCache.containsKey(cacheKey)) {
      return _mobileDestinationsCache[cacheKey]!;
    }

    final l10n = context.l10n;

    // Build a map so unrecognised routes are silently dropped (no SizedBox.shrink placeholders)
    final destMap = <String, NavigationDestination>{};

    if (dest.contains('_disableLibSwitch')) {
      destMap['_disableLibSwitch'] = NavigationDestination(
        selectedIcon: const Icon(Broken.arrow_left_2),
        icon: const Icon(Broken.arrow_left_2),
        label: l10n.go_back,
      );
    }
    if (dest.contains('_nfileBack')) {
      destMap['_nfileBack'] = NavigationDestination(
        selectedIcon: const Icon(Broken.arrow_left_2),
        icon: const Icon(Broken.arrow_left_2),
        label: l10n.go_back,
      );
    }
    if (dest.contains('_enableLibSwitch')) {
      destMap['_enableLibSwitch'] = const NavigationDestination(
        selectedIcon: Icon(Broken.category),
        icon: Icon(Broken.category_2),
        label: 'HUB',
      );
    }
    if (dest.contains('/Library')) {
      destMap['/Library'] = NavigationDestination(
        selectedIcon: const Icon(Broken.book_square),
        icon: const Icon(Broken.book_1),
        label: l10n.library,
      );
    }
    if (dest.contains('/MangaLibrary')) {
      destMap['/MangaLibrary'] = NavigationDestination(
        selectedIcon: const Icon(Broken.book_square),
        icon: const Icon(Broken.book_1),
        label: l10n.manga,
      );
    }
    if (dest.contains('/AnimeLibrary')) {
      destMap['/AnimeLibrary'] = NavigationDestination(
        selectedIcon: const Icon(Broken.video_square),
        icon: const Icon(Broken.video_octagon),
        label: l10n.watch,
      );
    }
    if (dest.contains('/NovelLibrary')) {
      destMap['/NovelLibrary'] = NavigationDestination(
        selectedIcon: const Icon(Broken.note_text),
        icon: const Icon(Broken.text),
        label: l10n.novel,
      );
    }
    if (dest.contains('/MusicLibrary')) {
      destMap['/MusicLibrary'] = const NavigationDestination(
        selectedIcon: Icon(Broken.music_circle),
        icon: Icon(Broken.music_playlist),
        label: 'Music',
      );
    }
    if (dest.contains('/GameLibrary')) {
      destMap['/GameLibrary'] = const NavigationDestination(
        selectedIcon: Icon(Broken.gameboy),
        icon: Icon(Broken.gameboy),
        label: 'Games',
      );
    }
    if (dest.contains('/WatchtowerHome')) {
      destMap['/WatchtowerHome'] = const NavigationDestination(
        selectedIcon: Icon(Broken.home_2),
        icon: Icon(Broken.home_1),
        label: 'Accueil',
      );
    }
    if (dest.contains('/updates')) {
      destMap['/updates'] = NavigationDestination(
        selectedIcon: _UpdatesBadgeWidget(icon: const Icon(Broken.notification_bing), ref: ref),
        icon: _UpdatesBadgeWidget(icon: const Icon(Broken.notification), ref: ref),
        label: l10n.updates,
      );
    }
    if (dest.contains('/history')) {
      destMap['/history'] = NavigationDestination(
        selectedIcon: const Icon(Broken.clock),
        icon: const Icon(Broken.clock_1),
        label: l10n.history,
      );
    }
    if (dest.contains('/browse')) {
      destMap['/browse'] = NavigationDestination(
        selectedIcon: _ExtensionBadgeWidget(icon: const Icon(Broken.global), ref: ref),
        icon: _ExtensionBadgeWidget(icon: const Icon(Broken.global_search), ref: ref),
        label: l10n.browse,
      );
    }
    if (dest.contains('/settings')) {
      destMap['/settings'] = NavigationDestination(
        selectedIcon: const Icon(Broken.setting),
        icon: const Icon(Broken.setting_2),
        label: l10n.more,
      );
    }
    if (dest.contains('/trackerLibrary')) {
      destMap['/trackerLibrary'] = NavigationDestination(
        selectedIcon: const Icon(Broken.chart_21),
        icon: const Icon(Broken.presention_chart),
        label: l10n.tracking,
      );
    }
    if (dest.contains('/marketplace')) {
      destMap['/marketplace'] = const NavigationDestination(
        selectedIcon: Icon(Broken.shop),
        icon: Icon(Broken.shopping_cart),
        label: 'Market',
      );
    }
    if (dest.contains('/schedule')) {
      destMap['/schedule'] = const NavigationDestination(
        selectedIcon: Icon(Broken.clock),
        icon: Icon(Broken.clock_1),
        label: 'Schedule',
      );
    }
    if (dest.contains('/plugins')) {
      destMap['/plugins'] = const NavigationDestination(
        selectedIcon: Icon(Broken.element_4),
        icon: Icon(Broken.element_3),
        label: 'Plugins',
      );
    }
    // ── Routes absents du destMap → dock classique n'affichait que 2 éléments ─
    if (dest.contains('/discover')) {
      destMap['/discover'] = const NavigationDestination(
        selectedIcon: Icon(Broken.global_search),
        icon: Icon(Broken.global_search),
        label: 'Discover',
      );
    }
    if (dest.contains('_enableLibrarySwitch')) {
      destMap['_enableLibrarySwitch'] = NavigationDestination(
        selectedIcon: const Icon(Broken.book_square),
        icon: const Icon(Broken.book_1),
        label: l10n.library,
      );
    }
    if (dest.contains('_disableLibrarySwitch')) {
      destMap['_disableLibrarySwitch'] = NavigationDestination(
        selectedIcon: const Icon(Broken.arrow_left_2),
        icon: const Icon(Broken.arrow_left_2),
        label: l10n.go_back,
      );
    }
    if (dest.contains('/MusicLibraryPage')) {
      destMap['/MusicLibraryPage'] = const NavigationDestination(
        selectedIcon: Icon(Broken.music_library_2),
        icon: Icon(Broken.music_library_2),
        label: 'Music Lib',
      );
    }

    // Reconstruct in the original order, dropping any unrecognised routes
    final result = dest
        .where(destMap.containsKey)
        .map((r) => destMap[r]! as Widget)
        .toList();

    _mobileDestinationsCache[cacheKey] = result;
    return [
      ...result,
      const NavigationDestination(
        selectedIcon: Icon(Broken.close_circle),
        icon: Icon(Broken.menu_1),
        label: 'Menu',
      ),
    ];
  }
}

class _SideBanners extends StatelessWidget {
  const _SideBanners({
    required this.downloadedOnly,
    required this.incognitoMode,
    required this.l10n,
  });

  final bool downloadedOnly;
  final bool incognitoMode;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (downloadedOnly)
              Positioned(
                left: 0,
                top: 80,
                bottom: 80,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_done_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            l10n.downloaded_only,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: GoogleFonts.aBeeZee().fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (incognitoMode)
              Positioned(
                right: 0,
                top: 80,
                bottom: 80,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_rounded, size: 11, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            l10n.incognito_mode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabletLayout extends StatefulWidget {
  const _TabletLayout({
    required this.isLongPressed,
    required this.location,
    required this.dest,
    required this.currentIndex,
    required this.route,
    required this.child,
    required this.ref,
    required this.buildNavigationWidgetsDesktop,
  });

  final bool isLongPressed;
  final String? location;
  final List<String> dest;
  final int currentIndex;
  final GoRouter route;
  final Widget child;
  final WidgetRef ref;
  final List<NavigationRailDestination> Function(
    WidgetRef,
    List<String>,
    BuildContext,
  )
  buildNavigationWidgetsDesktop;

  @override
  State<_TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends State<_TabletLayout> {
  // Sidebar is always icon-only — no collapse/expand toggle.
  static const double _sidebarWidth = 64.0;

  static const _validLocations = {
    '/Library', '/MangaLibrary', '/AnimeLibrary', '/NovelLibrary',
    '/MusicLibrary', '/GameLibrary', '/WatchtowerHome', '/history',
    '/updates', '/browse', '/settings', '/trackerLibrary', '/globalSearch',
    '/marketplace', '/discover', '/plugins', '/nfileHome',
  };

  static const _mainItems = [
    (route: '/discover',       icon: Broken.global_search,    activeIcon: Broken.global_search,   tooltip: 'Discover'),
    (route: '/WatchtowerHome', icon: Broken.home_1,           activeIcon: Broken.home_2,          tooltip: 'Accueil'),
    (route: '/AnimeLibrary',   icon: Broken.video_octagon,    activeIcon: Broken.video_square,    tooltip: 'Watch'),
    (route: '/MangaLibrary',   icon: Broken.book_1,           activeIcon: Broken.book_square,     tooltip: 'Manga'),
    (route: '/NovelLibrary',   icon: Broken.text,             activeIcon: Broken.note_text,       tooltip: 'Novel'),
    (route: '/MusicLibrary',   icon: Broken.music_playlist,   activeIcon: Broken.music_circle,    tooltip: 'Music'),
    (route: '/GameLibrary',    icon: Broken.gameboy,          activeIcon: Broken.gameboy,         tooltip: 'Games'),
    (route: '/Library',        icon: Broken.book_1,           activeIcon: Broken.book_square,     tooltip: 'Bibliothèque'),
    (route: '/globalSearch',   icon: Broken.search_normal_1,  activeIcon: Broken.search_normal,   tooltip: 'Recherche'),
    (route: '/browse',         icon: Broken.global_search,    activeIcon: Broken.global,          tooltip: 'Browse'),
    (route: '/marketplace',    icon: Broken.shopping_cart,    activeIcon: Broken.shop,            tooltip: 'Marketplace'),
    (route: '/plugins',        icon: Broken.element_3,        activeIcon: Broken.element_4,       tooltip: 'Plugins'),
  ];

  static const _footerItems = [
    (route: '/settings', icon: Broken.setting_2, activeIcon: Broken.setting, tooltip: 'Paramètres'),
  ];

  double _railWidth() {
    if (widget.isLongPressed) return 0;
    final loc = widget.location;
    if (loc != null && !_validLocations.contains(loc)) return 0;
    return _sidebarWidth;
  }

  @override
  Widget build(BuildContext context) {
    final railWidth = _railWidth();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final location = widget.location;

    return Row(
      children: [
        // ── Fixed icon-only sidebar ──────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          width: railWidth,
          child: railWidth == 0
              ? const SizedBox.shrink()
              : ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                  width: _sidebarWidth,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.30)
                        : Colors.white.withValues(alpha: 0.25),
                    border: Border(
                      right: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.18),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── App icon ────────────────────────────────
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 10),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/app_icons/icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ── Main nav items ──────────────────────────
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: _mainItems
                              .map((item) => Tooltip(
                                    message: item.tooltip,
                                    preferBelow: false,
                                    child: _SidebarItem(
                                      icon: location == item.route
                                          ? Icon(item.activeIcon)
                                          : Icon(item.icon),
                                      label: null,
                                      active: location == item.route,
                                      cs: cs,
                                      onTap: () =>
                                          widget.route.go(item.route),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      // ── Divider ───────────────────────────────────
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.30),
                        indent: 12,
                        endIndent: 12,
                      ),
                      const SizedBox(height: 4),
                      // ── Footer: More & Settings ─────────────────
                      ..._footerItems.map((item) => Tooltip(
                            message: item.tooltip,
                            child: _SidebarItem(
                              icon: location == item.route
                                  ? Icon(item.activeIcon)
                                  : Icon(item.icon),
                              label: null,
                              active: location == item.route,
                              cs: cs,
                              onTap: () => widget.route.go(item.route),
                            ),
                          )),
                      // ── Account ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Tooltip(
                          message: 'Compte',
                          child: InkWell(
                            onTap: () => showAccountSheet(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    cs.primary.withValues(alpha: 0.85),
                                    cs.tertiary.withValues(alpha: 0.80),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                ),
              ),
        ),
        // ── Content area ──────────────────────────────────
        Expanded(child: widget.child),
      ],
    );
  }
}

// ââ Toggle button âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _SidebarToggle extends StatelessWidget {
  final bool collapsed;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _SidebarToggle({
    required this.collapsed,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Déplier le menu' : 'Replier le menu',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Center(
            child: AnimatedRotation(
              turns: collapsed ? 0.0 : 0.5,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ââ Collapsed rail (icon-only) ââââââââââââââââââââââââââââââââââââââââââââââââ

class _CollapsedRail extends StatelessWidget {
  final List<NavigationRailDestination> destinations;
  final int selectedIndex;
  final List<String> dest;
  final GoRouter route;
  final ColorScheme cs;

  const _CollapsedRail({
    required this.destinations,
    required this.selectedIndex,
    required this.dest,
    required this.route,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: destinations.length,
      itemBuilder: (context, i) {
        final active = selectedIndex == i;
        final d = destinations[i];
        return Tooltip(
          message: _extractLabel(d),
          preferBelow: false,
          child: _SidebarItem(
            icon: active ? d.selectedIcon : d.icon,
            label: null,
            active: active,
            cs: cs,
            onTap: () => route.go(dest[i]),
          ),
        );
      },
    );
  }

  String _extractLabel(NavigationRailDestination d) {
    final w = d.label;
    if (w is Padding) {
      final child = w.child;
      if (child is Text) return child.data ?? '';
    }
    if (w is Text) return w.data ?? '';
    return '';
  }
}

// ââ Expanded rail (icon + label) ââââââââââââââââââââââââââââââââââââââââââââââ

class _ExpandedRail extends StatelessWidget {
  final List<NavigationRailDestination> destinations;
  final int selectedIndex;
  final List<String> dest;
  final GoRouter route;
  final ColorScheme cs;
  final double railWidth;

  const _ExpandedRail({
    required this.destinations,
    required this.selectedIndex,
    required this.dest,
    required this.route,
    required this.cs,
    required this.railWidth,
  });

  String _extractLabel(NavigationRailDestination d) {
    final w = d.label;
    if (w is Padding) {
      final child = w.child;
      if (child is Text) return child.data ?? '';
    }
    if (w is Text) return w.data ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      itemCount: destinations.length,
      itemBuilder: (context, i) {
        final active = selectedIndex == i;
        final d = destinations[i];
        return _SidebarItem(
          icon: active ? d.selectedIcon : d.icon,
          label: _extractLabel(d),
          active: active,
          cs: cs,
          onTap: () => route.go(dest[i]),
        );
      },
    );
  }
}

// ââ Single sidebar item âââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _SidebarItem extends StatelessWidget {
  final Widget icon;
  final String? label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;
  final int badge;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: label != null
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(
                      color: cs.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: label != null
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
                        size: 22,
                      ),
                      child: icon,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: cs.surface,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              badge > 99 ? '99+' : '$badge',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (label != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                  if (active) ...[
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ââ Sidebar footer ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _SidebarFooter extends StatelessWidget {
  final ColorScheme cs;
  final bool collapsed;

  const _SidebarFooter({required this.cs, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.80),
                cs.tertiary.withValues(alpha: 0.75),
              ],
            ),
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.85),
                  cs.tertiary.withValues(alpha: 0.80),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mon profil',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/settings'),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                Icons.settings_outlined,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy static helper kept for reference (no longer called directly)
double _getNavigationRailWidthLegacy(bool isLongPressed, String? location) {
  if (isLongPressed) return 0;
  const validLocations = {
    '/Library', '/MangaLibrary', '/AnimeLibrary', '/NovelLibrary',
    '/MusicLibrary', '/GameLibrary', '/WatchtowerHome', '/history',
    '/updates', '/browse', '/settings', '/trackerLibrary',
  };
  return (location == null || validLocations.contains(location)) ? 200 : 0;
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Floating Glass Dock (replaces classic NavigationBar)
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _DockItemData {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _DockItemData({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _FloatingDock extends StatefulWidget {
  const _FloatingDock({
    required this.isLongPressed,
    required this.location,
    required this.dest,
    required this.ref,
    required this.onDestinationSelected,
    this.showPill = true,
  });

  final bool isLongPressed;
  final String? location;
  final List<String> dest;
  final WidgetRef ref;
  final void Function(String) onDestinationSelected;
  final bool showPill;

  @override
  State<_FloatingDock> createState() => _FloatingDockState();
}

class _FloatingDockState extends State<_FloatingDock> {
  final ScrollController _scrollController = ScrollController();
  bool _menuOpen = false;

  static const double _itemWidth = 52.0;   // compact dock items
  static const double _dockHeight = 56.0;  // reduced height — more native feel
  static const double _dockBottomPad = 10.0;
  static const double _pillHPad = 6.0;
  static const int _maxInlineItems = 5;

  static const _validLocations = {
    '/Library',
    '/MangaLibrary',
    '/AnimeLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/MusicSearch',
    '/MusicLibraryPage',
    '/GameLibrary',
    '/WatchtowerHome',
    '/history',
    '/updates',
    '/browse',
    '/settings',
    '/trackerLibrary',
    '/marketplace',
    '/schedule',
    '/discover',
    '/plugins',
    '/nfileHome',
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isVisible() {
    if (widget.isLongPressed) return false;
    final loc = widget.location;
    if (loc != null && !_validLocations.contains(loc)) return false;
    // Persistent dock: it no longer hides on scroll, inactivity, or while
    // the drawer is being swiped open — it stays on the page at all times.
    return true;
  }

  bool _isActive(String route) {
    if (route == '_watchtower_menu') return _menuOpen;
    return widget.location == route;
  }

  List<_DockItemData> _buildItems(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.dest;
    final items = <_DockItemData>[];

    // ââ Respect the user-configured navigation order from dest ââââââââââââââ
    // dest already carries the correct order (from navigationOrderStateProvider)
    // including any _enableLibSwitch / _disableLibSwitch replacements.
    // Iterate it directly so the floating dock matches the classic dock and rail.
    for (final route in d) {
      switch (route) {
        case '/WatchtowerHome':
          items.add(const _DockItemData(
            route: '/WatchtowerHome',
            label: 'Accueil',
            icon: Broken.home_1,
            activeIcon: Broken.home_2,
          ));
        case '/AnimeLibrary':
          items.add(_DockItemData(
            route: '/AnimeLibrary',
            label: l10n.watch,
            icon: Broken.video_octagon,
            activeIcon: Broken.video_square,
          ));
        case '/MangaLibrary':
          items.add(_DockItemData(
            route: '/MangaLibrary',
            label: l10n.manga,
            icon: Broken.book_1,
            activeIcon: Broken.book_square,
          ));
        case '/NovelLibrary':
          items.add(_DockItemData(
            route: '/NovelLibrary',
            label: l10n.novel,
            icon: Broken.text,
            activeIcon: Broken.note_text,
          ));
        case '/MusicLibrary':
          items.add(const _DockItemData(
            route: '/MusicLibrary',
            label: 'Music',
            icon: Broken.music_playlist,
            activeIcon: Broken.music_circle,
          ));
        case '/GameLibrary':
          items.add(const _DockItemData(
            route: '/GameLibrary',
            label: 'Games',
            icon: Broken.gameboy,
            activeIcon: Broken.gameboy,
          ));
        case '/Library':
          items.add(_DockItemData(
            route: '/Library',
            label: l10n.library,
            icon: Broken.book_1,
            activeIcon: Broken.book_square,
          ));
        case '/browse':
          items.add(_DockItemData(
            route: '/browse',
            label: l10n.browse,
            icon: Broken.global_search,
            activeIcon: Broken.global,
          ));
        case '/history':
          items.add(_DockItemData(
            route: '/history',
            label: l10n.history,
            icon: Broken.clock_1,
            activeIcon: Broken.clock,
          ));
        case '/settings':
          items.add(_DockItemData(
            route: '/settings',
            label: l10n.more,
            icon: Broken.setting_2,
            activeIcon: Broken.setting,
          ));
        case '/updates':
          items.add(_DockItemData(
            route: '/updates',
            label: l10n.updates,
            icon: Broken.notification,
            activeIcon: Broken.notification_bing,
          ));
        case '/trackerLibrary':
          items.add(_DockItemData(
            route: '/trackerLibrary',
            label: l10n.tracking,
            icon: Broken.presention_chart,
            activeIcon: Broken.chart_21,
          ));
        case '/discover':
          items.add(const _DockItemData(
            route: '/discover',
            label: 'Discover',
            icon: Broken.global_search,
            activeIcon: Broken.global_search,
          ));
        case '/marketplace':
          items.add(const _DockItemData(
            route: '/marketplace',
            label: 'Market',
            icon: Broken.shopping_cart,
            activeIcon: Broken.shop,
          ));
        case '_enableLibSwitch':
          items.add(const _DockItemData(
            route: '_enableLibSwitch',
            label: 'Hub',
            icon: Broken.category_2,
            activeIcon: Broken.category,
          ));
        case '_disableLibSwitch':
          items.add(_DockItemData(
            route: '_disableLibSwitch',
            label: l10n.go_back,
            icon: Broken.arrow_left_2,
            activeIcon: Broken.arrow_left_2,
          ));
        case '_enableLibrarySwitch':
          items.add(const _DockItemData(
            route: '_enableLibrarySwitch',
            label: 'Library',
            icon: Broken.book_1,
            activeIcon: Broken.book_square,
          ));
        case '_disableLibrarySwitch':
          items.add(_DockItemData(
            route: '_disableLibrarySwitch',
            label: l10n.go_back,
            icon: Broken.arrow_left_2,
            activeIcon: Broken.arrow_left_2,
          ));
        case '_nfileBack':
          items.add(_DockItemData(
            route: '_nfileBack',
            label: l10n.go_back,
            icon: Broken.arrow_left_2,
            activeIcon: Broken.arrow_left_2,
          ));
        case '/MusicLibraryPage':
          items.add(const _DockItemData(
            route: '/MusicLibraryPage',
            label: 'Music Lib',
            icon: Broken.music_library_2,
            activeIcon: Broken.music_library_2,
          ));
        case '/MusicSearch':
          items.add(const _DockItemData(
            route: '/MusicSearch',
            label: 'Music',
            icon: Broken.music_playlist,
            activeIcon: Broken.music_circle,
          ));
      }
    }

    // In Hub or Library sub-dock mode, allow 5 content slots so that all items
    // fit; otherwise cap at 4.
    final _hubMode = d.contains('_disableLibSwitch') || d.contains('_disableLibrarySwitch') || d.contains('_nfileBack');
    final _cap = _hubMode ? 5 : 4;
    if (items.length > _cap) {
      items.removeRange(_cap, items.length);
    }

    items.add(const _DockItemData(
      route: '_watchtower_menu',
      label: 'Menu',
      icon: Broken.menu_1,
      activeIcon: Broken.close_circle,
    ));

    return items;
  }

  void _onScrollEnd(ScrollMetrics metrics) {
    final index = (metrics.pixels / _itemWidth).round();
    final snapOffset = (index * _itemWidth).clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    if ((metrics.pixels - snapOffset).abs() > 0.5) {
      _scrollController.animateTo(
        snapOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever scroll-direction-driven visibility changes.
    widget.ref.watch(dockHiddenProvider);
    _menuOpen = widget.ref.watch(menuOpenProvider);
    // Respect the user-chosen animation speed from advanced nav settings.
    final animSpeed = widget.ref.watch(navAnimSpeedProvider);
    final dockAnimMs = animSpeed == 0 ? 0 : animSpeed == 2 ? 100 : 220;

    final visible = _isVisible();
    final items = visible ? _buildItems(context) : <_DockItemData>[];
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalHeight = visible
        ? _dockHeight + _dockBottomPad + bottomPad
        : 0.0;

    final isGlass = widget.ref.read(navDockStyleProvider) == 'immersive';

    // In sub-dock mode (Back is first item), detach Back and Menu into their
    // own mini pills flanking the content pill for a cleaner visual.
    final inSubDock = items.length >= 3 &&
        (items.first.route == '_disableLibSwitch' ||
            items.first.route == '_disableLibrarySwitch' ||
            items.first.route == '_nfileBack');

    final screenWidth = MediaQuery.of(context).size.width;

    if (inSubDock) {
      // ONE unified pill: [‹ | content items... | menu]
      // Back is a compact 28px chevron — de-emphasised, not a full slot.
      final backItem = items.first;
      final menuItem = items.last;
      final contentItems = items.sublist(1, items.length - 1);
      // back(32) + sep(9) + content + sep(9) + menu(itemWidth) + pill pads(4+6)
      final rawW = 32.0 + 9 + contentItems.length * _itemWidth + 9 + _itemWidth + 10.0;
      // Guard against narrow/transient layouts where screenWidth - 32 < 80,
      // which would make clamp's upper bound smaller than its lower bound
      // and throw "Invalid argument(s): 80.0".
      final maxPillW = math.max(80.0, screenWidth - 32.0);
      final pillWidth = rawW.clamp(80.0, maxPillW);

      return AnimatedContainer(
        duration: Duration(milliseconds: dockAnimMs),
        curve: Curves.easeInOut,
        height: totalHeight,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: visible
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: _dockBottomPad + bottomPad * 0.5,
                  top: 4,
                ),
                child: SizedBox(
                  width: pillWidth,
                  height: _dockHeight,
                  child: _UnifiedSubDockPill(
                    backItem: backItem,
                    contentItems: contentItems,
                    menuItem: menuItem,
                    itemWidth: _itemWidth,
                    scrollController: _scrollController,
                    isActive: _isActive,
                    ref: widget.ref,
                    isGlass: isGlass,
                    onTap: (route) {
                      HapticFeedback.lightImpact();
                      widget.onDestinationSelected(route);
                    },
                    onScrollEnd: _onScrollEnd,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    // Normal mode — single pill
    final needsScroll = items.length > 5;
    final rawWidth = items.length * _itemWidth + _pillHPad * 2;
    // Same guard as above: keep the upper bound >= 80 so clamp never throws
    // on narrow/transient screen widths.
    final maxPillWidth = math.max(80.0, screenWidth - 32.0);
    final pillWidth = rawWidth.clamp(80.0, maxPillWidth);

    return AnimatedContainer(
      duration: Duration(milliseconds: dockAnimMs),
      curve: Curves.easeInOut,
      height: totalHeight,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: visible
          ? Padding(
              padding: EdgeInsets.only(
                bottom: _dockBottomPad + bottomPad * 0.5,
                top: 4,
              ),
              child: SizedBox(
                width: pillWidth,
                height: _dockHeight,
                child: _DockPill(
                  items: items,
                  itemWidth: _itemWidth,
                  scrollController: _scrollController,
                  isActive: _isActive,
                  ref: widget.ref,
                  needsScroll: needsScroll,
                  isGlass: isGlass,
                  onTap: (route) {
                    HapticFeedback.lightImpact();
                    widget.onDestinationSelected(route);
                  },
                  onScrollEnd: _onScrollEnd,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _DockPill extends StatelessWidget {
  const _DockPill({
    required this.items,
    required this.itemWidth,
    required this.scrollController,
    required this.isActive,
    required this.ref,
    required this.needsScroll,
    required this.isGlass,
    required this.onTap,
    required this.onScrollEnd,
  });

  final List<_DockItemData> items;
  final double itemWidth;
  final ScrollController scrollController;
  final bool Function(String) isActive;
  final WidgetRef ref;
  final bool needsScroll;
  final bool isGlass;
  final void Function(String) onTap;
  final void Function(ScrollMetrics) onScrollEnd;

  int _activeIndex() {
    for (int i = 0; i < items.length; i++) {
      if (isActive(items[i].route)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    Widget buildItem(int index) {
      final item = items[index];
      final active = isActive(item.route);
      return _DockItemWidget(
        item: item,
        active: active,
        ref: ref,
        onTap: () => onTap(item.route),
      );
    }

    final Widget itemsWidget = needsScroll
        ? NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              onScrollEnd(n.metrics);
              return false;
            },
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemExtent: itemWidth,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemBuilder: (context, index) => buildItem(index),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(
              items.length,
              (index) => SizedBox(width: itemWidth, child: buildItem(index)),
            ),
          );

    final decoration = BoxDecoration(
      // Always use Material 3 theme tokens — no hardcoded hex colours so custom
      // themes look clean. Glass mode overlays a transparent tint instead.
      color: isGlass
          ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05))
          : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: isGlass ? 0.14 : 0.09)
            : Colors.black.withValues(alpha: 0.08),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );

    Widget pill = Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: itemsWidget,
      ),
    );

    if (isGlass) {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: pill,
        ),
      );
    }

    return pill;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified sub-dock pill: back chevron | content items | menu — ONE pill only.
// ─────────────────────────────────────────────────────────────────────────────

class _UnifiedSubDockPill extends StatelessWidget {
  const _UnifiedSubDockPill({
    required this.backItem,
    required this.contentItems,
    required this.menuItem,
    required this.itemWidth,
    required this.scrollController,
    required this.isActive,
    required this.ref,
    required this.isGlass,
    required this.onTap,
    required this.onScrollEnd,
  });

  final _DockItemData backItem;
  final List<_DockItemData> contentItems;
  final _DockItemData menuItem;
  final double itemWidth;
  final ScrollController scrollController;
  final bool Function(String) isActive;
  final WidgetRef ref;
  final bool isGlass;
  final void Function(String) onTap;
  final void Function(ScrollMetrics) onScrollEnd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final decoration = BoxDecoration(
      // Always theme-aware — no hardcoded colours, custom themes stay clean.
      color: isGlass
          ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05))
          : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: isGlass ? 0.14 : 0.09)
            : Colors.black.withValues(alpha: 0.08),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );

    // Thin vertical divider between zones
    Widget divider() => Container(
          width: 0.5,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: isDark
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.10),
        );

    // Compact back — 32px slot, icon right-of-center so it's close to divider.
    final backBtn = GestureDetector(
      onTap: () => onTap(backItem.route),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: double.infinity,
        child: Center(
          child: Icon(
            Icons.chevron_left_rounded,
            size: 22,
            color: isDark
                ? Colors.white.withValues(alpha: 0.42)
                : Colors.black.withValues(alpha: 0.36),
          ),
        ),
      ),
    );

    // Content items — scrollable when > 4
    final needsScroll = contentItems.length > 4;
    final Widget contentWidget = needsScroll
        ? NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              onScrollEnd(n.metrics);
              return false;
            },
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: contentItems.length,
              itemExtent: itemWidth,
              padding: EdgeInsets.zero,
              // Clamping: no bounce overshoot before snap fires.
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = contentItems[index];
                return _DockItemWidget(
                  item: item,
                  active: isActive(item.route),
                  ref: ref,
                  onTap: () => onTap(item.route),
                );
              },
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: contentItems
                .map((item) => SizedBox(
                      width: itemWidth,
                      child: _DockItemWidget(
                        item: item,
                        active: isActive(item.route),
                        ref: ref,
                        onTap: () => onTap(item.route),
                      ),
                    ))
                .toList(),
          );

    Widget pill = Container(
      decoration: decoration,
      // Tight left pad (4) so chevron hugs the edge; slightly more right pad (6).
      padding: const EdgeInsets.only(left: 4, right: 6, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          backBtn,
          divider(),
          Expanded(child: contentWidget),
          divider(),
          SizedBox(
            width: itemWidth,
            child: _DockItemWidget(
              item: menuItem,
              active: isActive(menuItem.route),
              ref: ref,
              onTap: () => onTap(menuItem.route),
            ),
          ),
        ],
      ),
    );

    if (isGlass) {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: pill,
        ),
      );
    }

    return pill;
  }
}

// ââ Classic NavigationBar dock ââââââââââââââââââââââââââââââââââââââââââââââââ

class _ClassicDock extends StatelessWidget {
  const _ClassicDock({
    required this.dest,
    required this.currentIndex,
    required this.buildDestinations,
    required this.ref,
    required this.onDestinationSelected,
  });

  final List<String> dest;
  final int currentIndex;
  final List<Widget> Function(WidgetRef, List<String>, BuildContext)
      buildDestinations;
  final WidgetRef ref;
  final void Function(int) onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = buildDestinations(ref, dest, context);
    if (destinations.isEmpty) return const SizedBox.shrink();
    final safeIdx = currentIndex.clamp(0, destinations.length - 1);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: isDark
            ? cs.surface.withValues(alpha: 0.88)
            : cs.surface.withValues(alpha: 0.92),
        indicatorColor: cs.primary.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 56,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel
                ? cs.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.58)
                    : Colors.black.withValues(alpha: 0.52)),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
            color: sel
                ? cs.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.62)
                    : Colors.black.withValues(alpha: 0.55)),
            size: 22,
          );
        }),
      ),
      child: NavigationBar(
        // Default 500 ms makes the indicator slide diagonally when items change;
        // 150 ms keeps it snappy without feeling instant.
        animationDuration: const Duration(milliseconds: 150),
        selectedIndex: safeIdx,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}

// ─── Rounded variant wrapper for _ClassicDock ────────────────────────────────
  /// When [isRounded] is true, clips the [NavigationBar] with large top-corner
  /// radii to produce the "Rounded Full" style.
  class _RoundedOrClassicDock extends StatelessWidget {
    const _RoundedOrClassicDock({
      required this.isRounded,
      required this.dest,
      required this.currentIndex,
      required this.buildDestinations,
      required this.ref,
      required this.onDestinationSelected,
    });

    final bool isRounded;
    final List<String> dest;
    final int currentIndex;
    final List<Widget> Function(WidgetRef, List<String>, BuildContext)
        buildDestinations;
    final WidgetRef ref;
    final void Function(int) onDestinationSelected;

    @override
    Widget build(BuildContext context) {
      final base = _ClassicDock(
        dest: dest,
        currentIndex: currentIndex,
        buildDestinations: buildDestinations,
        ref: ref,
        onDestinationSelected: onDestinationSelected,
      );
      final Widget shaped = isRounded
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: base,
            )
          : base;
      // Blur + semi-transparent background (background opacity set in _ClassicDock)
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: shaped,
        ),
      );
    }
  }

  class _DockItemWidget extends StatelessWidget {
  const _DockItemWidget({
    required this.item,
    required this.active,
    required this.ref,
    required this.onTap,
  });

  final _DockItemData item;
  final bool active;
  final WidgetRef ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = cs.primary;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.52);

    final iconColor = active ? accent : inactiveColor;
    final labelColor = active ? accent : inactiveColor;
    final showLabels = ref.watch(navShowLabelsProvider);
    final iconSize = ref.watch(navIconSizeProvider);

    Widget iconWidget = Icon(
      active ? item.activeIcon : item.icon,
      color: iconColor,
      size: iconSize,
    );

    if (item.route == '/updates') {
      iconWidget = _UpdatesBadgeWidget(icon: iconWidget, ref: ref);
    } else if (item.route == '/browse') {
      iconWidget = _ExtensionBadgeWidget(icon: iconWidget, ref: ref);
    }

    final spacing = ref.watch(navItemSpacingProvider);
    final haptic = ref.watch(navHapticProvider);
    final animSpeed = ref.watch(navAnimSpeedProvider);
    final itemAnimMs = animSpeed == 0 ? 0 : animSpeed == 2 ? 80 : 180;
    const _descriptions = {
      '_enableLibSwitch': 'Hub â tap to expand Manga, Watch & Novel tabs',
      '_disableLibSwitch': 'Tap to go back to Hub view',
      '/Library': 'Library â all your content unified in one page',
      '/AnimeLibrary': 'Watch â your anime & video library',
      '/MangaLibrary': 'Manga â your manga & comic library',
      '/NovelLibrary': 'Novel â your light novel library',
      '/MusicLibrary': 'Music â stream & download music',
      '/GameLibrary': 'Games â browse & download ROMs',
      '/WatchtowerHome': 'Accueil â discover trending content',
      '/browse': 'Browse â explore & install sources and extensions',
      '/history': 'History â recently read or watched items',
      '/settings': 'More â settings, about & advanced options',
      '/updates': 'Updates â new chapters & episodes available',
      '/trackerLibrary': 'Tracking â sync progress with external trackers',
      '_watchtower_menu': 'Menu — History, Updates, Schedule & more',
    };

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (haptic) HapticFeedback.mediumImpact();
        final desc = _descriptions[item.route] ?? item.label;
        botToast(desc);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: itemAnimMs),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(horizontal: spacing / 2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: Duration(milliseconds: itemAnimMs),
              curve: Curves.easeOutCubic,
              child: iconWidget,
            ),
            if (showLabels) ...[
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.0,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
            // Active indicator dot — bottom of item
            AnimatedContainer(
              duration: Duration(milliseconds: itemAnimMs),
              width: active ? 4 : 0,
              height: active ? 4 : 0,
              margin: EdgeInsets.only(top: active ? 3 : 0),
              decoration: BoxDecoration(
                color: active ? accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionBadgeWidget extends ConsumerWidget {
  const _ExtensionBadgeWidget({required this.icon, required this.ref});

  final Widget icon;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideItems = ref.watch(hideItemsStateProvider);

    return StreamBuilder(
      stream: isar.sources
          .filter()
          .idIsNotNull()
          .optional(
            hideItems.contains("/MangaLibrary"),
            (q) => q.not().itemTypeEqualTo(ItemType.manga),
          )
          .optional(
            hideItems.contains("/AnimeLibrary"),
            (q) => q.not().itemTypeEqualTo(ItemType.anime),
          )
          .optional(
            hideItems.contains("/NovelLibrary"),
            (q) => q.not().itemTypeEqualTo(ItemType.novel),
          )
          .optional(
            hideItems.contains("/MusicLibrary"),
            (q) => q.not().itemTypeEqualTo(ItemType.music),
          )
          .optional(
            hideItems.contains("/GameLibrary"),
            (q) => q.not().itemTypeEqualTo(ItemType.game),
          )
          .and()
          .isActiveEqualTo(true)
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return icon;
        }

        final entries = snapshot.data!
            .where(
              (element) =>
                  compareVersions(element.version!, element.versionLast!) < 0,
            )
            .toList();

        if (entries.isEmpty) {
          return icon;
        }

        return Badge(label: Text("${entries.length}"), child: icon);
      },
    );
  }
}

class _UpdatesBadgeWidget extends ConsumerWidget {
  const _UpdatesBadgeWidget({required this.icon, required this.ref});

  final Widget icon;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideItems = ref.watch(hideItemsStateProvider);

    return StreamBuilder(
      stream: isar.updates
          .filter()
          .idIsNotNull()
          .optional(
            hideItems.contains("/MangaLibrary"),
            (q) => q.chapter(
              (c) => c.manga((m) => m.not().itemTypeEqualTo(ItemType.manga)),
            ),
          )
          .optional(
            hideItems.contains("/AnimeLibrary"),
            (q) => q.chapter(
              (c) => c.manga((m) => m.not().itemTypeEqualTo(ItemType.anime)),
            ),
          )
          .optional(
            hideItems.contains("/NovelLibrary"),
            (q) => q.chapter(
              (c) => c.manga((m) => m.not().itemTypeEqualTo(ItemType.novel)),
            ),
          )
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return icon;
        }

        final entries = snapshot.data!.where((element) {
          if (!element.chapter.isLoaded) {
            element.chapter.loadSync();
          }
          return !(element.chapter.value?.isRead ?? false);
        }).toList();

        if (entries.isEmpty) {
          return icon;
        }

        return Badge(label: Text("${entries.length}"), child: icon);
      },
    );
  }
}

