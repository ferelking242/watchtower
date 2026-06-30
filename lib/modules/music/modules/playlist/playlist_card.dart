import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/dialogs/select_device_dialog.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_card.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/connect/connect.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/querying_track_info.dart';
import 'package:watchtower/modules/music/provider/connect/connect.dart';
import 'package:watchtower/modules/music/provider/history/history.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/tracks/playlist.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';

class PlaylistCard extends HookConsumerWidget {
  final SpotubeSimplePlaylistObject playlist;
  final bool _isTile;

  const PlaylistCard(
    this.playlist, {
    super.key,
  }) : _isTile = false;

  const PlaylistCard.tile(
    this.playlist, {
    super.key,
  }) : _isTile = true;

  @override
  Widget build(BuildContext context, ref) {
    final playlistQueue = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final historyNotifier = ref.read(playbackHistoryActionsProvider);

    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final isPlaylistPlaying = useMemoized<bool>(
      () => playlistQueue.containsCollection(playlist.id),
      [playlistQueue, playlist.id],
    );

    final updating = useState(false);
    final me = ref.watch(metadataPluginUserProvider);

    final fetchInitialTracks = useCallback(() async {
      if (playlist.id == 'user-liked-tracks') {
        final tracks = await ref.read(metadataPluginSavedTracksProvider.future)
            as SpotubePaginationResponseObject;
        return tracks.items.cast<SpotubeTrackObject>().toList();
      }

      final result = await ref
          .read(metadataPluginPlaylistTracksProvider(playlist.id).future)
          as SpotubePaginationResponseObject;

      return result.items.cast<SpotubeTrackObject>().toList();
    }, [playlist.id, ref]);

    final fetchAllTracks = useCallback(() async {
      await fetchInitialTracks();

      if (playlist.id == 'user-liked-tracks') {
        return ref.read(metadataPluginSavedTracksProvider.notifier).fetchAll();
      }

      return ref
          .read(metadataPluginPlaylistTracksProvider(playlist.id).notifier)
          .fetchAll();
    }, [playlist.id, ref, fetchInitialTracks]);

    final onTap = useCallback(() {
      context.navigateTo(PlaylistRoute(id: playlist.id, playlist: playlist));
    }, [context, playlist]);

    final onPlaybuttonPressed = useCallback(() async {
      try {
        updating.value = true;
        if (isPlaylistPlaying && playing) {
          return audioPlayer.pause();
        } else if (isPlaylistPlaying && !playing) {
          return audioPlayer.resume();
        }

        final fetchedInitialTracks = await fetchInitialTracks();

        if (fetchedInitialTracks.isEmpty || !context.mounted) return;

        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;
        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final allTracks = await fetchAllTracks();
          await remotePlayback.load(
            WebSocketLoadEventData.playlist(
              tracks: allTracks,
              collection: playlist,
            ),
          );
        } else {
          await playlistNotifier.load(fetchedInitialTracks, autoPlay: true);
          playlistNotifier.addCollection(playlist.id);
          historyNotifier.addPlaylists([playlist]);

          final allTracks = await fetchAllTracks();

          await playlistNotifier
              .addTracks(allTracks.sublist(fetchedInitialTracks.length));
        }
      } finally {
        if (context.mounted) {
          updating.value = false;
        }
      }
    }, [
      isPlaylistPlaying,
      playing,
      fetchInitialTracks,
      context,
      showSelectDeviceDialog,
      ref,
      connectProvider,
      fetchAllTracks,
      playlistNotifier,
      playlist.id,
      historyNotifier,
      playlist,
      updating
    ]);

    final onAddToQueuePressed = useCallback(() async {
      updating.value = true;
      try {
        if (isPlaylistPlaying) return;

        final fetchedInitialTracks = await fetchAllTracks();

        if (fetchedInitialTracks.isEmpty) return;

        playlistNotifier.addTracks(fetchedInitialTracks);
        playlistNotifier.addCollection(playlist.id);
        historyNotifier.addPlaylists([playlist]);
      } finally {
        updating.value = false;
      }
    }, [
      isPlaylistPlaying,
      fetchAllTracks,
      playlistNotifier,
      playlist.id,
      historyNotifier,
      playlist,
      context,
      updating
    ]);

    final imageUrl = useMemoized(
      () => playlist.images.from200PxTo300PxOrSmallestImage(
        ImagePlaceholder.collection,
      ),
      [playlist.images],
    );

    final isLoading =
        (isPlaylistPlaying && isFetchingActiveTrack) || updating.value;
    final isOwner = playlist.owner.id == me.asData?.value?.id &&
        me.asData?.value?.id != null;

    if (_isTile) {
      return PlaybuttonTile(
        title: playlist.name,
        description: playlist.description,
        image: null,
        imageUrl: imageUrl,
        isPlaying: isPlaylistPlaying,
        isLoading: isLoading,
        isOwner: isOwner,
        onTap: onTap,
        onPlaybuttonPressed: onPlaybuttonPressed,
        onAddToQueuePressed: onAddToQueuePressed,
      );
    }

    return PlaybuttonCard(
      title: playlist.name,
      description: playlist.description,
      image: null,
      imageUrl: imageUrl,
      isPlaying: isPlaylistPlaying,
      isLoading: isLoading,
      isOwner: isOwner,
      onTap: onTap,
      onPlaybuttonPressed: onPlaybuttonPressed,
      onAddToQueuePressed: onAddToQueuePressed,
    );
  }
}
