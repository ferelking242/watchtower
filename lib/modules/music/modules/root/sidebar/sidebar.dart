import 'package:auto_route/auto_route.dart';
    import 'package:flutter_hooks/flutter_hooks.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:flutter/material.dart';

    import 'package:watchtower/modules/music/collections/side_bar_tiles.dart';
    import 'package:watchtower/modules/music/models/database/database.dart';
    import 'package:watchtower/modules/music/extensions/constrains.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/modules/root/sidebar/sidebar_footer.dart';
    import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

    class Sidebar extends HookConsumerWidget {
    final Widget child;

    const Sidebar({
      required this.child,
      super.key,
    });

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final colorScheme = Theme.of(context).colorScheme;
      final mediaQuery = MediaQuery.sizeOf(context);

      final layoutMode =
          ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

      final sidebarTileList = useMemoized(
        () => getSidebarTileList(context.l10n),
        [context.l10n],
      );

      final sidebarLibraryTileList = useMemoized(
        () => getSidebarLibraryTileList(context.l10n),
        [context.l10n],
      );

      final tileList = [...sidebarTileList, ...sidebarLibraryTileList];

      final router = context.watchRouter;

      final selectedIndex = tileList.indexWhere(
        (e) => router.currentPath.startsWith(e.pathPrefix),
      );

      if (layoutMode == LayoutMode.compact ||
          (mediaQuery.smAndDown && layoutMode == LayoutMode.adaptive)) {
        return child;
      }

      final bool isExpanded = mediaQuery.lgAndUp;

      void onDestinationSelected(int index) {
        if (index < tileList.length) {
          context.navigateTo(tileList[index].route);
        }
      }

      // Build rail destinations
      final mainDestinations = sidebarTileList.map((tile) {
        return NavigationRailDestination(
          icon: Icon(tile.icon),
          label: Text(tile.title),
        );
      }).toList();

      final libraryDestinations = sidebarLibraryTileList.map((tile) {
        return NavigationRailDestination(
          icon: Icon(tile.icon),
          label: Text(tile.title),
        );
      }).toList();

      final allDestinations = [...mainDestinations, ...libraryDestinations];

      final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            "Music Hub",
                            style: TextStyle(
                              fontFamily: "Cookie",
                              fontSize: 28,
                              letterSpacing: 1.8,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      NavigationRail(
                        extended: isExpanded,
                        selectedIndex: safeIndex < allDestinations.length ? safeIndex : 0,
                        onDestinationSelected: onDestinationSelected,
                        destinations: allDestinations,
                        groupAlignment: -1.0,
                        labelType: isExpanded
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.selected,
                      ),
                      const SidebarFooter(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isExpanded ? 130 : 65),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      );
    }
    }
    