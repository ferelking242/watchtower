import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/string.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/local_tracks/local_tracks_provider.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class LocalFolderItem extends HookConsumerWidget {
  final String folder;
  const LocalFolderItem({super.key, required this.folder});

  @override
  Widget build(BuildContext context, ref) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    final downloadFolder =
        ref.watch(userPreferencesProvider.select((s) => s.downloadLocation));
    final cacheFolder = useFuture(UserPreferencesNotifier.getMusicCacheDir());

    final isDownloadFolder = folder == downloadFolder;
    final isCacheFolder = folder == cacheFolder.data;

    final trackSnapshot = ref.watch(
      localTracksProvider.select(
        (s) => s.whenData((tracks) => tracks[folder]?.take(4).toList()),
      ),
    );

    final tracks = trackSnapshot.value ?? [];

    return TextButton(
      onPressed: () {
        context.navigateTo(
          LocalLibraryRoute(
            location: folder,
            isCache: isCacheFolder,
            isDownloads: isDownloadFolder,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                SpotubeIcons.folder,
                size: mediaQuery.smAndDown
                    ? 95
                    : mediaQuery.mdAndDown
                        ? 100
                        : 142,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: max((tracks.length / 2).ceil(), 2),
                ),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return UniversalImage(
                    path: track.album.images.asUrlString(
                      placeholder: ImagePlaceholder.albumArt,
                    ),
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          SizedBox(height: 8),
          Stack(
            children: [
              Center(
                child: Text(
                  isDownloadFolder
                      ? context.l10n.downloads
                      : isCacheFolder
                          ? context.l10n.cache_folder.capitalize()
                          : basename(folder),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isDownloadFolder && !isCacheFolder)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert),
                    iconSize: 20.0,
                    onPressed: () {
                      // Capture theme data before entering the overlay.
                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(0, 0, 0, 0),
                        items: [
                          PopupMenuItem(
                            child: Text(context.l10n.remove_library_location),
                            onTap: () {
                              final libraryLocations = ref.read(userPreferencesProvider).localLibraryLocation;
                              ref.read(userPreferencesProvider.notifier).setLocalLibraryLocation(
                                libraryLocations.where((e) => e != folder).toList(),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
