import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

class StatsTrackItem extends StatelessWidget {
  final SpotubeTrackObject track;
  final Widget info;
  const StatsTrackItem({
    super.key,
    required this.track,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: UniversalImage(
          path: (track.album.images).asUrlString(
            placeholder: ImagePlaceholder.albumArt,
          ),
          width: 40,
          height: 40,
        ),
      ),
      title: Text(track.name),
      subtitle: ArtistLink(
        artists: track.artists,
        mainAxisAlignment: WrapAlignment.start,
        onOverflowArtistClick: () {
          context.navigateTo(TrackRoute(trackId: track.id));
        },
      ),
      trailing: info,
      onPressed: () {
        context.navigateTo(TrackRoute(trackId: track.id));
      },
    );
  }
}
