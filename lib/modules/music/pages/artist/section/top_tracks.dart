import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/dialogs/select_device_dialog.dart';
import 'package:watchtower/modules/music/components/track_tile/track_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/connect/connect.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/connect/connect.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/top_tracks.dart';

class ArtistPageTopTracks extends HookConsumerWidget {
  final String artistId;
  const ArtistPageTopTracks({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final topTracksQuery =
        ref.watch(metadataPluginArtistTopTracksProvider(artistId));

    final isPlaylistPlaying = playlist.containsTracks(
      topTracksQuery.asData?.value.items ?? <SpotubeTrackObject>[],
    );

    if (topTracksQuery.hasError) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(topTracksQuery.error.toString()),
        ),
      );
    }

    final topTracks = topTracksQuery.asData?.value.items ??
        List.generate(10, (index) => FakeData.track);

    void playPlaylist(
      List<SpotubeFullTrackObject> tracks, {
      SpotubeTrackObject? currentTrack,
    }) async {
      isLoading.value = true;

      currentTrack ??= tracks.first;
      try {
        final isRemoteDevice = await showSelectDeviceDialog(context, ref);

        if (isRemoteDevice == null) return;

        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final remotePlaylist = ref.read(queueProvider);

          final isPlaylistPlaying = remotePlaylist.containsTracks(tracks);

          if (!isPlaylistPlaying) {
            await remotePlayback.load(
              WebSocketLoadEventData.playlist(
                tracks: tracks,
                collection: null,
                initialIndex:
                    tracks.indexWhere((s) => s.id == currentTrack?.id),
              ),
            );
          } else if (isPlaylistPlaying &&
              currentTrack.id != remotePlaylist.activeTrack?.id) {
            final index = playlist.tracks
                .toList()
                .indexWhere((s) => s.id == currentTrack!.id);
            await remotePlayback.jumpTo(index);
          }
        } else {
          if (!isPlaylistPlaying) {
            playlistNotifier.load(
              tracks,
              initialIndex: tracks.indexWhere((s) => s.id == currentTrack?.id),
              autoPlay: true,
            );
          } else if (isPlaylistPlaying &&
              currentTrack.id != playlist.activeTrack?.id) {
            await playlistNotifier.jumpToTrack(currentTrack);
          }
        }
      } finally {
        isLoading.value = false;
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  context.l10n.top_tracks,
                  style: Theme.of(context).textTheme.headlineMedium!,
                ),
              ),
              if (!isPlaylistPlaying)
                IconButton.outlined(
                  icon: const Icon(
                    SpotubeIcons.queueAdd,
                  ),
                  onPressed: () {
                    playlistNotifier.addTracks(topTracks.toList());
                    showToast(
                      context: context,
                      location: ToastLocation.topRight,
                      builder: (context, overlay) {
                        return Card(
                          child: Text(
                            context.l10n.added_to_queue(
                              topTracks.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(width: 5),
              IconButton.primary(
                shape: ButtonShape.circle,
                enabled: !isPlaylistPlaying && !isLoading.value,
                icon: isLoading.value
                    ? CircularProgressIndicator(
                        iconSize: 20 * Theme.of(context).scaling,
                        color: theme.colorScheme.primaryForeground,
                      )
                    : Skeleton.keep(
                        child: Icon(
                          isPlaylistPlaying
                              ? SpotubeIcons.pause
                              : SpotubeIcons.play,
                        ),
                      ),
                onPressed: () => playPlaylist(topTracks.toList()),
              )
            ],
          ),
        ),
        const SliverGap(10),
        SliverList.builder(
          itemCount: topTracks.length,
          itemBuilder: (context, index) {
            final track = topTracks.elementAt(index);
            return TrackTile(
              index: index,
              playlist: playlist,
              track: track,
              onTap: () async {
                playPlaylist(
                  topTracks.toList(),
                  currentTrack: track,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
