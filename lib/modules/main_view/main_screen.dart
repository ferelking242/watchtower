import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
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

final libLocationRegex = RegExp(r"^/(Manga|Anime|Novel)Library$");

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
  @override
  Widget build(BuildContext context) {
    ref.listen<Locale>(l10nLocaleStateProvider, (previous, next) {
      _clearCache();
      setState(() {});
    });

    final l10n = context.l10n;
    final route = GoRouter.of(context);
    final navigationOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final mergeLibraryNavMobile = ref.watch(mergeLibraryNavMobileStateProvider);
    final location = ref.watch(routerCurrentLocationStateProvider);

    return ref
        .watch(migrationProvider)
        .when(
          data: (_) => Consumer(
            builder: (context, ref, child) {
              final isReadingScreen = _isReadingScreen(location);
              bool uniqueSwitch = false;
              List<String> dest = !context.isTablet && isLibSwitch
                  ? [
                      "_disableLibSwitch",
                      ...navigationOrder.where(
                        (nav) => libLocationRegex.hasMatch(nav),
                      ),
                    ].where((nav) => !hideItems.contains(nav)).toList()
                  : navigationOrder
                        .where((nav) => !hideItems.contains(nav))
                        .toList();

              if (mergeLibraryNavMobile && !context.isTablet && !isLibSwitch) {
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
                      return nav;
                    })
                    .nonNulls
                    .toList();
              }

              if (isLibSwitch &&
                  (currentIndex >= dest.length ||
                      !libLocationRegex.hasMatch(location ?? ""))) {
                currentIndex = 0;
              } else {
                String? libLocation;
                if (mergeLibraryNavMobile &&
                    !context.isTablet &&
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

              final incognitoMode = ref.watch(incognitoModeStateProvider);
              final downloadedOnly = ref.watch(downloadedOnlyStateProvider);
              final isLongPressed = ref.watch(isLongPressedStateProvider);

              return Column(
                children: [
                  if (!isReadingScreen)
                    _DownloadedOnlyBar(
                      downloadedOnly: downloadedOnly,
                      l10n: l10n,
                    ),
                  if (!isReadingScreen)
                    _IncognitoModeBar(incognitoMode: incognitoMode, l10n: l10n),
                  Flexible(
                    child: Scaffold(
                      extendBody: true,
                      body: context.isTablet
                          ? _TabletLayout(
                              isLongPressed: isLongPressed,
                              location: location,
                              dest: dest,
                              currentIndex: currentIndex,
                              route: route,
                              ref: ref,
                              buildNavigationWidgetsDesktop:
                                  _buildNavigationWidgetsDesktop,
                              child: widget.child,
                            )
                          : widget.child,
                      bottomNavigationBar: context.isTablet
                          ? null
                          : _FloatingDock(
                              isLongPressed: isLongPressed,
                              location: location,
                              dest: dest,
                              ref: ref,
                              onDestinationSelected: (destination) {
                                if (destination == "_enableLibSwitch") {
                                  setState(() {
                                    isLibSwitch = true;
                                  });
                                } else if (destination == "_disableLibSwitch") {
                                  setState(() {
                                    isLibSwitch = false;
                                  });
                                } else {
                                  route.go(destination);
                                }
                              },
                            ),
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

    if (dest.contains("/MangaLibrary")) {
      destinations[dest.indexOf("/MangaLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.collections_bookmark),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.manga),
        ),
      );
    }
    if (dest.contains("/AnimeLibrary")) {
      destinations[dest.indexOf("/AnimeLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.video_collection),
        icon: const Icon(Icons.video_collection_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.anime),
        ),
      );
    }
    if (dest.contains("/NovelLibrary")) {
      destinations[dest.indexOf("/NovelLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.local_library),
        icon: const Icon(Icons.local_library_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.novel),
        ),
      );
    }
    if (dest.contains("/updates")) {
      destinations[dest.indexOf("/updates")] = NavigationRailDestination(
        selectedIcon: _UpdatesBadgeWidget(
          icon: const Icon(Icons.new_releases),
          ref: ref,
        ),
        icon: _UpdatesBadgeWidget(
          icon: const Icon(Icons.new_releases_outlined),
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
        selectedIcon: const Icon(Icons.history),
        icon: const Icon(Icons.history_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.history),
        ),
      );
    }
    if (dest.contains("/browse")) {
      destinations[dest.indexOf("/browse")] = NavigationRailDestination(
        selectedIcon: _ExtensionBadgeWidget(
          icon: const Icon(Icons.explore),
          ref: ref,
        ),
        icon: _ExtensionBadgeWidget(
          icon: const Icon(Icons.explore_outlined),
          ref: ref,
        ),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.browse),
        ),
      );
    }
    if (dest.contains("/more")) {
      destinations[dest.indexOf("/more")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.more_horiz),
        icon: const Icon(Icons.more_horiz_outlined),
        label: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(l10n.more),
        ),
      );
    }
    if (dest.contains("/trackerLibrary")) {
      destinations[dest.indexOf("/trackerLibrary")] = NavigationRailDestination(
        selectedIcon: const Icon(Icons.account_tree),
        icon: const Icon(Icons.account_tree_outlined),
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
    final destinations = List<Widget>.filled(
      dest.length,
      const SizedBox.shrink(),
    );

    if (dest.contains("_disableLibSwitch")) {
      destinations[dest.indexOf("_disableLibSwitch")] = NavigationDestination(
        selectedIcon: const Icon(Icons.arrow_back),
        icon: const Icon(Icons.arrow_back),
        label: l10n.go_back,
      );
    }
    if (dest.contains("_enableLibSwitch")) {
      destinations[dest.indexOf("_enableLibSwitch")] = NavigationDestination(
        selectedIcon: const Icon(Icons.collections_bookmark),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: l10n.library,
      );
    }
    if (dest.contains("/MangaLibrary")) {
      destinations[dest.indexOf("/MangaLibrary")] = NavigationDestination(
        selectedIcon: const Icon(Icons.collections_bookmark),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: l10n.manga,
      );
    }
    if (dest.contains("/AnimeLibrary")) {
      destinations[dest.indexOf("/AnimeLibrary")] = NavigationDestination(
        selectedIcon: const Icon(Icons.video_collection),
        icon: const Icon(Icons.video_collection_outlined),
        label: l10n.anime,
      );
    }
    if (dest.contains("/NovelLibrary")) {
      destinations[dest.indexOf("/NovelLibrary")] = NavigationDestination(
        selectedIcon: const Icon(Icons.local_library),
        icon: const Icon(Icons.local_library_outlined),
        label: l10n.novel,
      );
    }
    if (dest.contains("/updates")) {
      destinations[dest.indexOf("/updates")] = NavigationDestination(
        selectedIcon: _UpdatesBadgeWidget(
          icon: const Icon(Icons.new_releases),
          ref: ref,
        ),
        icon: _UpdatesBadgeWidget(
          icon: const Icon(Icons.new_releases_outlined),
          ref: ref,
        ),
        label: l10n.updates,
      );
    }
    if (dest.contains("/history")) {
      destinations[dest.indexOf("/history")] = NavigationDestination(
        selectedIcon: const Icon(Icons.history),
        icon: const Icon(Icons.history_outlined),
        label: l10n.history,
      );
    }
    if (dest.contains("/browse")) {
      destinations[dest.indexOf("/browse")] = NavigationDestination(
        selectedIcon: _ExtensionBadgeWidget(
          icon: const Icon(Icons.explore),
          ref: ref,
        ),
        icon: _ExtensionBadgeWidget(
          icon: const Icon(Icons.explore_outlined),
          ref: ref,
        ),
        label: l10n.browse,
      );
    }
    if (dest.contains("/more")) {
      destinations[dest.indexOf("/more")] = NavigationDestination(
        selectedIcon: const Icon(Icons.more_horiz),
        icon: const Icon(Icons.more_horiz_outlined),
        label: l10n.more,
      );
    }
    if (dest.contains("/trackerLibrary")) {
      destinations[dest.indexOf("/trackerLibrary")] = NavigationDestination(
        selectedIcon: const Icon(Icons.account_tree),
        icon: const Icon(Icons.account_tree_outlined),
        label: l10n.tracking,
      );
    }

    _mobileDestinationsCache[cacheKey] = destinations;
    return destinations;
  }
}

class _DownloadedOnlyBar extends StatelessWidget {
  const _DownloadedOnlyBar({required this.downloadedOnly, required this.l10n});

  final bool downloadedOnly;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: AnimatedContainer(
        height: downloadedOnly
            ? Platform.isAndroid || Platform.isIOS
                  ? MediaQuery.of(context).padding.top * 2
                  : 50
            : 0,
        curve: Curves.easeIn,
        duration: const Duration(milliseconds: 150),
        color: context.secondaryColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                l10n.downloaded_only,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: GoogleFonts.aBeeZee().fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncognitoModeBar extends StatelessWidget {
  const _IncognitoModeBar({required this.incognitoMode, required this.l10n});

  final bool incognitoMode;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: AnimatedContainer(
        height: incognitoMode
            ? Platform.isAndroid || Platform.isIOS
                  ? MediaQuery.of(context).padding.top * 2
                  : 50
            : 0,
        curve: Curves.easeIn,
        duration: const Duration(milliseconds: 150),
        color: context.primaryColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                l10n.incognito_mode,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: GoogleFonts.aBeeZee().fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final destinations = buildNavigationWidgetsDesktop(ref, dest, context);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 0),
          width: _getNavigationRailWidth(isLongPressed, location),
          child: Stack(
            children: [
              NavigationRailTheme(
                data: NavigationRailThemeData(
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: NavigationRail(
                  labelType: NavigationRailLabelType.all,
                  useIndicator: true,
                  destinations: destinations,
                  selectedIndex:
                      (currentIndex >= 0 && currentIndex < destinations.length)
                      ? currentIndex
                      : 0,
                  onDestinationSelected: (newIndex) {
                    route.go(dest[newIndex]);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  static double _getNavigationRailWidth(bool isLongPressed, String? location) {
    if (isLongPressed) return 0;

    const validLocations = {
      '/MangaLibrary',
      '/AnimeLibrary',
      '/NovelLibrary',
      '/history',
      '/updates',
      '/browse',
      '/more',
      '/trackerLibrary',
    };

    return (location == null || validLocations.contains(location)) ? 100 : 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Glass Dock (replaces classic NavigationBar)
// ─────────────────────────────────────────────────────────────────────────────

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
  });

  final bool isLongPressed;
  final String? location;
  final List<String> dest;
  final WidgetRef ref;
  final void Function(String) onDestinationSelected;

  @override
  State<_FloatingDock> createState() => _FloatingDockState();
}

class _FloatingDockState extends State<_FloatingDock> {
  final ScrollController _scrollController = ScrollController();

  static const double _itemWidth = 62.0;
  static const double _dockHeight = 72.0;
  static const double _dockBottomPad = 20.0;
  static const double _pillHPad = 14.0;
  static const int _maxInlineItems = 5;

  static const _validLocations = {
    '/MangaLibrary',
    '/AnimeLibrary',
    '/NovelLibrary',
    '/history',
    '/updates',
    '/browse',
    '/more',
    '/trackerLibrary',
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isVisible() {
    if (widget.isLongPressed) return false;
    final loc = widget.location;
    return loc == null || _validLocations.contains(loc);
  }

  bool _isActive(String route) => widget.location == route;

  List<_DockItemData> _buildItems(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.dest;
    final items = <_DockItemData>[];

    // ── Order: Watch, Manga, Novel, History, Updates, Browse, More ───────────
    if (d.contains('/AnimeLibrary')) {
      items.add(_DockItemData(
        route: '/AnimeLibrary',
        label: 'Watch',
        icon: Icons.video_collection_outlined,
        activeIcon: Icons.video_collection,
      ));
    }
    if (d.contains('/MangaLibrary')) {
      items.add(_DockItemData(
        route: '/MangaLibrary',
        label: l10n.manga,
        icon: Icons.collections_bookmark_outlined,
        activeIcon: Icons.collections_bookmark,
      ));
    }
    if (d.contains('/NovelLibrary')) {
      items.add(_DockItemData(
        route: '/NovelLibrary',
        label: l10n.novel,
        icon: Icons.local_library_outlined,
        activeIcon: Icons.local_library,
      ));
    }
    if (d.contains('/history')) {
      items.add(_DockItemData(
        route: '/history',
        label: l10n.history,
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
      ));
    }
    if (d.contains('/updates')) {
      items.add(_DockItemData(
        route: '/updates',
        label: l10n.updates,
        icon: Icons.new_releases_outlined,
        activeIcon: Icons.new_releases,
      ));
    }
    if (d.contains('/browse')) {
      items.add(_DockItemData(
        route: '/browse',
        label: l10n.browse,
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
      ));
    }
    if (d.contains('/more')) {
      items.add(_DockItemData(
        route: '/more',
        label: l10n.more,
        icon: Icons.apps_outlined,
        activeIcon: Icons.apps,
      ));
    }
    if (d.contains('/trackerLibrary')) {
      items.add(_DockItemData(
        route: '/trackerLibrary',
        label: l10n.tracking,
        icon: Icons.account_tree_outlined,
        activeIcon: Icons.account_tree,
      ));
    }

    // ── Library switch items ──────────────────────────────────────────────────
    if (d.contains('_enableLibSwitch')) {
      items.insert(
        0,
        _DockItemData(
          route: '_enableLibSwitch',
          label: l10n.library,
          icon: Icons.collections_bookmark_outlined,
          activeIcon: Icons.collections_bookmark,
        ),
      );
    }
    if (d.contains('_disableLibSwitch')) {
      items.insert(
        0,
        _DockItemData(
          route: '_disableLibSwitch',
          label: l10n.go_back,
          icon: Icons.arrow_back,
          activeIcon: Icons.arrow_back,
        ),
      );
    }

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
    final visible = _isVisible();
    final items = visible ? _buildItems(context) : <_DockItemData>[];
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalHeight = visible
        ? _dockHeight + _dockBottomPad + bottomPad
        : 0.0;

    final needsScroll = items.length > _maxInlineItems;
    final rawWidth = needsScroll
        ? (_maxInlineItems * _itemWidth + _pillHPad * 2)
        : (items.length * _itemWidth + _pillHPad * 2);
    final screenWidth = MediaQuery.of(context).size.width;
    final pillWidth = rawWidth.clamp(80.0, screenWidth - 32.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
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
    required this.onTap,
    required this.onScrollEnd,
  });

  final List<_DockItemData> items;
  final double itemWidth;
  final ScrollController scrollController;
  final bool Function(String) isActive;
  final WidgetRef ref;
  final bool needsScroll;
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
    final activeIdx = _activeIndex();

    // Neon violet/blue glow color
    const neonColor = Color(0xFF7C3AED);

    Widget _buildItem(int index) {
      final item = items[index];
      final active = isActive(item.route);
      final dist = activeIdx < 0 ? 99 : (index - activeIdx).abs();
      return _DockItemWidget(
        item: item,
        active: active,
        distanceFromActive: dist,
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
              itemBuilder: (context, index) => _buildItem(index),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(
              items.length,
              (index) => SizedBox(width: itemWidth, child: _buildItem(index)),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(46),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            // Glassmorphism: low opacity, high blur
            color: isDark
                ? cs.surface.withOpacity(0.18)
                : cs.surface.withOpacity(0.78),
            borderRadius: BorderRadius.circular(46),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.18)
                  : Colors.white.withOpacity(0.60),
              width: 1.0,
            ),
            boxShadow: [
              // Deep shadow
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.18),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
              // Neon violet glow
              BoxShadow(
                color: neonColor.withOpacity(isDark ? 0.30 : 0.12),
                blurRadius: 28,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
              // Neon blue inner shimmer
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(isDark ? 0.18 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: itemsWidget,
        ),
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
    this.distanceFromActive = 99,
  });

  final _DockItemData item;
  final bool active;
  final WidgetRef ref;
  final VoidCallback onTap;
  final int distanceFromActive;

  double get _scale {
    if (active) return 1.20;
    if (distanceFromActive == 1) return 0.90;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = colorScheme.primary;
    const neonViolet = Color(0xFF7C3AED);
    final inactiveColor = colorScheme.onSurface.withOpacity(0.48);
    final color = active ? activeColor : inactiveColor;

    Widget iconWidget = Icon(
      active ? item.activeIcon : item.icon,
      color: color,
      size: 21,
    );

    if (item.route == '/updates') {
      iconWidget = _UpdatesBadgeWidget(icon: iconWidget, ref: ref);
    } else if (item.route == '/browse') {
      iconWidget = _ExtensionBadgeWidget(icon: iconWidget, ref: ref);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon bubble with neon glow when active
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                color: active
                    ? neonViolet.withOpacity(isDark ? 0.22 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: neonViolet.withOpacity(isDark ? 0.55 : 0.30),
                          blurRadius: 14,
                          spreadRadius: -1,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? activeColor : inactiveColor,
                letterSpacing: active ? 0.15 : 0.0,
                overflow: TextOverflow.ellipsis,
              ),
              child: Text(item.label, textAlign: TextAlign.center),
            ),
            // Active neon dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: active ? 16 : 4,
              height: 2.5,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: active
                    ? neonViolet
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: neonViolet.withOpacity(0.70),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
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
