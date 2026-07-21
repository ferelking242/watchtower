import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/library/local_folder/local_folder_item.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/local_tracks/local_tracks_provider.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

enum SortBy {
  none,
  ascending,
  descending,
  newest,
  oldest,
  duration,
  artist,
  album,
}

class UserLocalLibraryPage extends HookConsumerWidget {
  static const name = 'user_local_library';
  const UserLocalLibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final cacheDir = useFuture(UserPreferencesNotifier.getMusicCacheDir());
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);

    final addLocalLibraryLocation = useCallback(() async {
      if (kIsMobile || kIsMacOS) {
        final dirStr = await FilePicker.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      } else {
        String? dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      }
    }, [preferences.localLibraryLocation]);

    ref.watch(localTracksProvider);

    final locations = [
      preferences.downloadLocation,
      if (cacheDir.hasData) cacheDir.data!,
      ...preferences.localLibraryLocation,
    ];

    return LayoutBuilder(
      builder: (context, constrains) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: addLocalLibraryLocation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(SpotubeIcons.folderAdd),
                    const SizedBox(width: 8),
                    Text(context.l10n.add_library_location),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: constrains.isXs
                      ? 230
                      : constrains.mdAndDown
                          ? 280
                          : 250,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  return LocalFolderItem(
                    folder: locations[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
