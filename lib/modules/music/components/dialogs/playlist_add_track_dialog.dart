import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

import 'package:watchtower/modules/music/modules/playlist/playlist_create_dialog.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';

class PlaylistAddTrackDialog extends HookConsumerWidget {
  final String? openFromPlaylist;
  final List<SpotubeTrackObject> tracks;
  const PlaylistAddTrackDialog({
    required this.tracks,
    required this.openFromPlaylist,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final userPlaylists = ref.watch(metadataPluginSavedPlaylistsProvider);
    final favoritePlaylistsNotifier =
        ref.watch(metadataPluginSavedPlaylistsProvider.notifier);

    final me = ref.watch(metadataPluginUserProvider);

    final filteredPlaylists = useMemoized(
      () =>
          userPlaylists.asData?.value.items
              .where(
                (playlist) =>
                    playlist.owner.id == me.asData?.value?.id &&
                    playlist.id != openFromPlaylist,
              )
              .toList() ??
          [],
      [userPlaylists.asData?.value, me.asData?.value?.id, openFromPlaylist],
    );

    final playlistsCheck = useState(<String, bool>{});

    useEffect(() {
      if (userPlaylists.asData?.value != null) {
        favoritePlaylistsNotifier.fetchAll();
      }
      return null;
    }, [userPlaylists.asData?.value]);

    Future<void> onAdd() async {
      final selectedPlaylists = playlistsCheck.value.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key);

      await Future.wait(
        selectedPlaylists.map(
          (playlistId) => favoritePlaylistsNotifier.addTracks(
            playlistId,
            tracks.map((e) => e.id).toList(),
          ),
        ),
      ).then((_) => context.mounted ? Navigator.pop(context, true) : null);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.add_to_playlist,
              style: Theme.of(context).textTheme.bodyLarge!,
            ),
            const Spacer(),
            const PlaylistCreateDialogButton(),
          ],
        ),
        actions: [
          OutlinedButton(
            child: Text(context.l10n.cancel),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          FilledButton(
            onPressed: onAdd,
            child: Text(context.l10n.add),
          ),
        ],
        content: SizedBox(
          height: 300,
          child: userPlaylists.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = filteredPlaylists.elementAt(index);
                    return ListTile(
                      leading: CircleAvatar(
                        foregroundImage: UniversalImage.imageProvider(
                          playlist.images.asUrlString(
                            placeholder: ImagePlaceholder.collection,
                          ),
                        ),
                        child: Text(
                          playlist.name.isNotEmpty ? playlist.name[0] : '?',
                        ),
                      ),
                      title: Text(playlist.name),
                      trailing: Checkbox(
                        value: (playlistsCheck.value[playlist.id] ?? false)
                            ? true
                            : false,
                        onChanged: (val) {
                          playlistsCheck.value = {
                            ...playlistsCheck.value,
                            playlist.id: val == true,
                          };
                        },
                      ),
                      onTap: () {
                        playlistsCheck.value = {
                          ...playlistsCheck.value,
                          playlist.id:
                              !(playlistsCheck.value[playlist.id] ?? false),
                        };
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
