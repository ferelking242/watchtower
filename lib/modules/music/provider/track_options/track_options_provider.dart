import 'package:flutter/material.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/dialogs/playlist_add_track_dialog.dart';
import 'package:watchtower/modules/music/components/dialogs/prompt_dialog.dart';
import 'package:watchtower/modules/music/components/dialogs/track_details_dialog.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/provider/database/database.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';
import 'package:watchtower/modules/music/provider/local_tracks/local_tracks_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

enum TrackOptionValue {
  album,
  share,
  addToPlaylist,
  addToQueue,
  removeFromPlaylist,
  removeFromQueue,
  blacklist,
  delete,
  playNext,
  favorite,
  details,
  download,
  startRadio,
}

class TrackOptionsActions {
  final Ref ref;
  final SpotubeTrackObject track;

  TrackOptionsActions(this.ref, this.track);

  AudioPlayerNotifier get playback => ref.read(audioPlayerProvider.notifier);
  MetadataPluginSavedTracksNotifier get favoriteTracks =>
      ref.read(metadataPluginSavedTracksProvider.notifier);
  MetadataPluginSavedPlaylistsNotifier get favoritePlaylistsNotifier =>
      ref.read(metadataPluginSavedPlaylistsProvider.notifier);
  DownloadManagerNotifier get downloadManager =>
      ref.read(downloadManagerProvider.notifier);
  BlackListNotifier get blacklist => ref.read(blacklistProvider.notifier);

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void actionShare(BuildContext context) {
    Clipboard.setData(ClipboardData(text: track.externalUri)).then((_) {
      if (context.mounted) {
        _showToast(
          context,
          context.l10n.copied_to_clipboard(track.externalUri),
        );
      }
    });
  }

  Future<void> actionAddToPlaylist(
    BuildContext context,
    String? playlistId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return PlaylistAddTrackDialog(
          tracks: [track],
          openFromPlaylist: playlistId,
        );
      },
    );
  }

  Future<void> actionStartRadio(BuildContext context) async {
    final playback = ref.read(audioPlayerProvider.notifier);
    final playlist = ref.read(audioPlayerProvider);
    final metadataPlugin = await ref.read(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    final tracks = await metadataPlugin.track.radio(track.id);

    bool replaceQueue = false;

    if (context.mounted && playlist.tracks.isNotEmpty) {
      replaceQueue = await showPromptDialog(
        context: context,
        title: context.l10n.how_to_start_radio,
        message: context.l10n.replace_queue_question,
        okText: context.l10n.replace,
        cancelText: context.l10n.add_to_queue,
      );
    }

    if (replaceQueue || playlist.tracks.isEmpty) {
      await playback.stop();
      await playback.load([track], autoPlay: true);
      return;
    } else {
      await playback.addTrack(track);
    }

    await playback.addTracks(
      tracks.toList()
        ..removeWhere((e) {
          final isDuplicate = playlist.tracks.any((t) => t.id == e.id);
          return e.id == track.id || isDuplicate;
        }),
    );
  }

  Future<void> action(
    BuildContext context,
    TrackOptionValue value,
    String? playlistId,
  ) async {
    switch (value) {
      case TrackOptionValue.album:
        await context.navigateTo(
          AlbumRoute(id: track.album.id, album: track.album),
        );
        break;
      case TrackOptionValue.delete:
        await File((track as SpotubeLocalTrackObject).path).delete();
        ref.invalidate(localTracksProvider);
        break;
      case TrackOptionValue.addToQueue:
        await playback.addTrack(track);
        if (context.mounted) {
          _showToast(context, context.l10n.added_track_to_queue(track.name));
        }
        break;
      case TrackOptionValue.playNext:
        await playback.addTracksAtFirst([track]);
        if (context.mounted) {
          _showToast(context, context.l10n.track_will_play_next(track.name));
        }
        break;
      case TrackOptionValue.removeFromQueue:
        playback.removeTrack(track.id);
        if (context.mounted) {
          _showToast(
              context, context.l10n.removed_track_from_queue(track.name));
        }
        break;
      case TrackOptionValue.favorite:
        final isLikedTrack = await ref.read(
          metadataPluginIsSavedTrackProvider(track.id).future,
        );
        if (isLikedTrack) {
          await favoriteTracks.removeFavorite([track]);
        } else {
          await favoriteTracks.addFavorite([track]);
        }
        break;
      case TrackOptionValue.addToPlaylist:
        actionAddToPlaylist(context, playlistId);
        break;
      case TrackOptionValue.removeFromPlaylist:
        favoritePlaylistsNotifier.removeTracks(playlistId ?? "", [track.id]);
        break;
      case TrackOptionValue.blacklist:
        if (blacklist.contains(track)) {
          await blacklist.remove(track.id);
        } else {
          final database = ref.read(databaseProvider);
          await database.into(database.blacklistTable).insert(
                BlacklistTableCompanion.insert(
                  name: track.name,
                  elementId: track.id,
                  elementType: BlacklistedType.track,
                ),
              );
        }
        break;
      case TrackOptionValue.share:
        actionShare(context);
        break;
      case TrackOptionValue.details:
        if (track is! SpotubeFullTrackObject) break;
        showDialog(
          context: context,
          builder: (context) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TrackDetailsDialog(track: track as SpotubeFullTrackObject),
          ),
        );
        break;
      case TrackOptionValue.download:
        if (track is SpotubeLocalTrackObject) break;
        downloadManager.addToQueue(track as SpotubeFullTrackObject);
        break;
      case TrackOptionValue.startRadio:
        actionStartRadio(context);
        break;
    }
  }
}

typedef TrackOptionFlags = ({
  bool isInQueue,
  bool isBlacklisted,
  bool isInDownloadQueue,
  bool isActiveTrack,
  bool isAuthenticated,
  bool isLiked,
  DownloadTask? downloadTask,
});

final trackOptionActionsProvider =
    Provider.family<TrackOptionsActions, SpotubeTrackObject>(
  (ref, track) => TrackOptionsActions(ref, track),
);

final trackOptionsStateProvider =
    Provider.family<TrackOptionFlags, SpotubeTrackObject>((ref, track) {
  ref.watch(downloadManagerProvider);
  ref.watch(blacklistProvider);

  final playlist = ref.watch(audioPlayerProvider);
  final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
  final downloadManager = ref.watch(downloadManagerProvider.notifier);
  final blacklist = ref.watch(blacklistProvider.notifier);
  final isBlacklisted = blacklist.contains(track);
  final isSavedTrack = ref.watch(metadataPluginIsSavedTrackProvider(track.id));

  final downloadTask = playlist.activeTrack?.id == null
      ? null
      : downloadManager.getTaskByTrackId(playlist.activeTrack!.id);
  final isInDownloadQueue = playlist.activeTrack == null ||
          playlist.activeTrack! is SpotubeLocalTrackObject
      ? false
      : const [
          DownloadStatus.queued,
          DownloadStatus.downloading,
        ].contains(downloadTask?.status);

  return (
    isInQueue: playlist.containsTrack(track),
    isBlacklisted: isBlacklisted,
    isInDownloadQueue: isInDownloadQueue,
    isActiveTrack: playlist.activeTrack?.id == track.id,
    isAuthenticated: authenticated.asData?.value ?? false,
    isLiked: isSavedTrack.asData?.value ?? false,
    downloadTask: downloadTask,
  );
});
