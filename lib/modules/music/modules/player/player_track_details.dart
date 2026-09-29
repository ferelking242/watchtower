import 'package:auto_route/auto_route.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/links/link_text.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';

class PlayerTrackDetails extends HookConsumerWidget {
  final Color? color;
  final SpotubeTrackObject? track;
  const PlayerTrackDetails({super.key, this.color, this.track});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final playback = ref.watch(audioPlayerProvider);

    return Row(
      children: [
        if (playback.activeTrack != null)
          Container(
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(
              maxWidth: 80,
              maxHeight: 80,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: UniversalImage(
                path: (track?.album.images)
                    .asUrlString(placeholder: ImagePlaceholder.albumArt),
                placeholder: Assets.images.albumPlaceholder.path,
              ),
            ),
          ),
        if (mediaQuery.mdAndDown)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  playback.activeTrack?.name ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: color,
                  ),
                ),
                Text(
                  playback.activeTrack?.artists.asString() ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: color),
                )
              ],
            ),
          ),
        if (mediaQuery.lgAndUp)
          Flexible(
            flex: 1,
            child: Column(
              children: [
                LinkText(
                  playback.activeTrack?.name ?? "",
                  TrackRoute(trackId: playback.activeTrack?.id ?? ""),
                  push: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                ArtistLink(
                  artists: playback.activeTrack?.artists ?? [],
                  onRouteChange: (route) {
                    context.router.navigateNamed(route);
                  },
                  onOverflowArtistClick: () =>
                      context.navigateTo(TrackRoute(trackId: track!.id)),
                )
              ],
            ),
          ),
      ],
    );
  }
}
