import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/routes.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/track_options/track_options_provider.dart';

/// [track] must be a [SpotubeFullTrackObject] or [SpotubeLocalTrackObject]
class TrackOptions extends HookConsumerWidget {
  final SpotubeTrackObject track;
  final bool userPlaylist;
  final String? playlistId;
  final Widget? icon;
  final VoidCallback? onTapItem;

  const TrackOptions({
    super.key,
    required this.track,
    this.userPlaylist = false,
    this.playlistId,
    this.icon,
    this.onTapItem,
  }) : assert(
          track is SpotubeFullTrackObject || track is SpotubeLocalTrackObject,
          "Track must be a SpotubeFullTrackObject, SpotubeLocalTrackObject",
        );

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.of(context);

    final trackOptionActions = ref.watch(trackOptionActionsProvider(track));
    final (
      :isBlacklisted,
      :isInDownloadQueue,
      :isInQueue,
      :isActiveTrack,
      :isAuthenticated,
      :isLiked,
      :downloadTask
    ) = ref.watch(trackOptionsStateProvider(track));
    final isLocalTrack = track is SpotubeLocalTrackObject;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.delete,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.delete),
          ),
        if (mediaQuery.smAndDown && !isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.album,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.go_to_album),
                Text(
                  track.album.name,
                  style: Theme.of(context).textTheme.labelSmall!,
                ),
              ],
            ),
          ),
        if (!isInQueue) ...[
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.add_to_queue),
          ),
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.playNext,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.play_next),
          ),
        ] else
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            enabled: !isActiveTrack,
            title: Text(context.l10n.remove_from_queue),
          ),
        if (isAuthenticated && !isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.favorite,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: isLiked
                ? const Icon(
                    SpotubeIcons.heartFilled,
                    color: Colors.pink,
                  )
                : const Icon(SpotubeIcons.heart),
            title: Text(
              isLiked
                  ? context.l10n.remove_from_favorites
                  : context.l10n.save_as_favorite,
            ),
          ),
        if (isAuthenticated && !isLocalTrack) ...[
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.startRadio,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.start_a_radio),
          ),
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.add_to_playlist),
          ),
        ],
        if (userPlaylist && isAuthenticated && !isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.remove_from_playlist),
          ),
        if (!isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.download,
                playlistId,
              );
              onTapItem?.call();
            },
            enabled: !isInDownloadQueue,
            leading: isInDownloadQueue
                ? StreamBuilder(
                    stream: downloadTask?.downloadedBytesStream,
                    builder: (context, snapshot) {
                      final progress = downloadTask?.totalSizeBytes == null ||
                              downloadTask?.totalSizeBytes == 0
                          ? 0
                          : (snapshot.data ?? 0) /
                              downloadTask!.totalSizeBytes!;
                      return CircularProgressIndicator(
                        value: progress.toDouble(),
                      );
                    },
                  )
                : const Icon(SpotubeIcons.download),
            title: Text(context.l10n.download_track),
          ),
        if (!isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.blacklist,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(
              isBlacklisted == true
                  ? context.l10n.remove_from_blacklist
                  : context.l10n.add_to_blacklist,
              style: TextStyle(
                color: isBlacklisted != true ? Colors.red[400] : null,
              ),
            ),
          ),
        if (!isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.share,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.share),
          ),
        if (!isLocalTrack)
          ButtonTile(
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.details,
                playlistId,
              );
              onTapItem?.call();
            },
            title: Text(context.l10n.details),
          ),
      ],
    );
  }
}
