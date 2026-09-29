import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/side_bar_tiles.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

final navigationPanelHeight = StateProvider<double>((ref) => 50);

class SpotubeNavigationBar extends HookConsumerWidget {
  const SpotubeNavigationBar({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.of(context);

    final downloadCount = ref
        .watch(downloadManagerProvider)
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.queued)
        .length;
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final navbarTileList = useMemoized(
      () => getNavbarTileList(context.l10n),
      [context.l10n],
    );

    final panelHeight = ref.watch(navigationPanelHeight);

    final router = context.watchRouter;
    final selectedIndex = max(
      0,
      navbarTileList.indexWhere(
        (e) => router.currentPath.startsWith(e.pathPrefix),
      ),
    );

    if (layoutMode == LayoutMode.extended ||
        (mediaQuery.mdAndUp && layoutMode == LayoutMode.adaptive) ||
        panelHeight < 10) {
      return const SizedBox();
    }

    final safeIndex =
        selectedIndex < navbarTileList.length ? selectedIndex : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: panelHeight,
      child: Column(
        children: [
          const Divider(height: 1),
          NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              context.navigateTo(navbarTileList[index].route);
            },
            destinations: navbarTileList.map((tile) {
              final isLibrary = tile.id == "library";
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: isLibrary && downloadCount > 0,
                  label: Text(downloadCount.toString()),
                  child: Icon(tile.icon),
                ),
                label: tile.title,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
