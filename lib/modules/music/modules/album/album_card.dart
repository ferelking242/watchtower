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
import 'package:watchtower/modules/music/provider/metadata_plugin/tracks/album.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';

extension FormattedAlbumType on SpotubeAlbumType {
  String get formatted => name.replaceFirst(name[0], name[0].toUpperCase());
}

class AlbumCard extends HookConsumerWidget {
  final SpotubeSimpleAlbumObject album;
  final bool _isTile;
  const AlbumCard(
    this.album, {
    super.key,
  }) : _isTile = false;

  const AlbumCard.tile(
    this.album, {
    super.key,
  }) : _isTile = true;

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final historyNotifier = ref.read(playbackHistoryActionsProvider);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);

    final isPlaylistPlaying = useMemoized<bool>(
      () => playlist.containsCollection(album.id),
      [playlist, album.id],
    );

    final updating = useState(false);

    final fetchAllTrack = useCallback(() async {
      await ref.read(metadataPluginAlbumTracksProvider(album.id).future);
      return ref
          .read(metadataPluginAlbumTracksProvider(album.id).notifier)
          .fetchAll();
    }, [album.id, ref]);

    final imageUrl = useMemoized(
      () => album.images.from200PxTo300PxOrSmallestImage(
        ImagePlaceholder.collection,
      ),
      [album.images],
    );

    final isLoading =
        (isPlaylistPlaying && isFetchingActiveTrack) || updating.value;
    final description = "${album.albumType.name} • ${album.artists.asString()}";

    final onTap = useCallback(() {
      context.navigateTo(AlbumRoute(id: album.id, album: album));
    }, [context, album]);

    final onPlaybuttonPressed = useCallback(() async {
      updating.value = true;
      try {
        if (isPlaylistPlaying) {
          return playing ? audioPlayer.pause() : audioPlayer.resume();
        }

        final fetchedTracks = await fetchAllTrack();

        if (fetchedTracks.isEmpty || !context.mounted) return;

        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;
        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          await remotePlayback.load(
            WebSocketLoadEventData.album(
              tracks: fetchedTracks,
              collection: album,
            ),
          );
        } else {
          await playlistNotifier.load(fetchedTracks, autoPlay: true);
          playlistNotifier.addCollection(album.id);
          historyNotifier.addAlbums([album]);
        }
      } finally {
        updating.value = false;
      }
    }, [
      isPlaylistPlaying,
      playing,
      audioPlayer,
      fetchAllTrack,
      context,
      ref,
      playlistNotifier,
      album,
      historyNotifier,
      updating
    ]);

    final onAddToQueuePressed = useCallback(() async {
      if (isPlaylistPlaying) {
        return;
      }

      updating.value = true;
      try {
        final fetchedTracks = await fetchAllTrack();

        if (fetchedTracks.isEmpty) return;
        playlistNotifier.addTracks(fetchedTracks);
        playlistNotifier.addCollection(album.id);
        historyNotifier.addAlbums([album]);
      } finally {
        updating.value = false;
      }
    }, [
      isPlaylistPlaying,
      updating.value,
      fetchAllTrack,
      playlistNotifier,
      album.id,
      historyNotifier,
      album,
      context
    ]);

    if (_isTile) {
      return PlaybuttonTile(
        imageUrl: imageUrl,
        isPlaying: isPlaylistPlaying,
        isLoading: isLoading,
        title: album.name,
        description: description,
        onTap: onTap,
        onPlaybuttonPressed: onPlaybuttonPressed,
        onAddToQueuePressed: onAddToQueuePressed,
      );
    }

    return PlaybuttonCard(
      imageUrl: imageUrl,
      isPlaying: isPlaylistPlaying,
      isLoading: isLoading,
      title: album.name,
      description: description,
      onTap: onTap,
      onPlaybuttonPressed: onPlaybuttonPressed,
      onAddToQueuePressed: onAddToQueuePressed,
    );
  }
}
