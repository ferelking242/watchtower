import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/links/hyper_link.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/duration.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/server/sourced_track_provider.dart';

class TrackDetailsDialog extends HookConsumerWidget {
  final SpotubeFullTrackObject track;
  const TrackDetailsDialog({
    super.key,
    required this.track,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final sourcedTrack = ref.read(sourcedTrackProvider(track));

    final detailsMap = {
      context.l10n.title: track.name,
      context.l10n.artist: ArtistLink(
        artists: track.artists,
        mainAxisAlignment: WrapAlignment.start,
        textStyle: const TextStyle(color: Colors.blue),
        hideOverflowArtist: false,
      ),
      context.l10n.duration: sourcedTrack.asData != null
          ? sourcedTrack.asData!.value.info.duration.toHumanReadableString()
          : Duration(milliseconds: track.durationMs).toHumanReadableString(),
      if (track.album.releaseDate != null)
        context.l10n.released: track.album.releaseDate,
    };

    final sourceInfo = sourcedTrack.asData?.value.info;

    final ytTracksDetailsMap = sourceInfo == null
        ? <String, dynamic>{}
        : {
            context.l10n.youtube: Hyperlink(
              "https://piped.video/watch?v=${sourceInfo.id}",
              "https://piped.video/watch?v=${sourceInfo.id}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            context.l10n.channel: Text(sourceInfo.artists.join(", ")),
            if (sourcedTrack.asData?.value.url != null)
              context.l10n.streamUrl: Hyperlink(
                sourcedTrack.asData!.value.url ?? "",
                sourcedTrack.asData!.value.url ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          };

    Widget buildRow(String key, dynamic value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 95,
              child: Text(
                key,
                style: theme.textTheme.bodyMedium!
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Text(":"),
            const SizedBox(width: 8),
            Expanded(
              child: value is Widget
                  ? value
                  : Text(
                      value?.toString() ?? "",
                      style: theme.textTheme.bodyMedium!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(SpotubeIcons.info),
          const SizedBox(width: 8),
          Text(
            context.l10n.details,
            style: theme.textTheme.headlineMedium!,
          ),
        ],
      ),
      content: SizedBox(
        width: mediaQuery.mdAndUp ? double.infinity : 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in detailsMap.entries) buildRow(entry.key, entry.value),
            for (final entry in ytTracksDetailsMap.entries) buildRow(entry.key, entry.value),
          ],
        ),
      ),
    );
  }
}
