import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/side_bar_tiles.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';

class LibraryPage extends HookConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final downloadingCount = ref
        .watch(downloadManagerProvider)
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.queued)
        .length;
    final router = context.watchRouter;
    final sidebarLibraryTileList = useMemoized(
      () => [
        ...getSidebarLibraryTileList(context.l10n),
        SideBarTiles(
          id: "downloads",
          pathPrefix: "library/downloads",
          title: context.l10n.downloads,
          route: const UserDownloadsRoute(),
          icon: SpotubeIcons.download,
        ),
      ],
      [context.l10n],
    );
    final index = sidebarLibraryTileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );
    final mediaQuery = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          appBar: mediaQuery.smAndDown
              ? AppBar(
                  automaticallyImplyLeading: false,
                  titleSpacing: 0,
                  title: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        for (final tile in sidebarLibraryTileList) ...[
                          ChoiceChip(
                            label: Badge(
                              isLabelVisible: tile.id == 'downloads' &&
                                  downloadingCount > 0,
                              label: Text(downloadingCount.toString()),
                              child: Text(tile.title),
                            ),
                            selected: sidebarLibraryTileList.indexOf(tile) ==
                                index,
                            showCheckmark: false,
                            onSelected: (_) {
                              context.navigateTo(tile.route);
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 2),
                      ],
                    ),
                  ),
                )
              : null,
          body: const AutoRouter(),
        ),
      ),
    );
  }
}
