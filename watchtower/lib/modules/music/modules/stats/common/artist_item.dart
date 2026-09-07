import 'package:flutter/material.dart';
  import 'package:auto_route/auto_route.dart';
  import 'package:watchtower/modules/music/collections/routes.gr.dart';
  import 'package:watchtower/modules/music/components/image/universal_image.dart';
  import 'package:watchtower/modules/music/components/ui/button_tile.dart';
  import 'package:watchtower/modules/music/models/metadata/metadata.dart';

  class StatsArtistItem extends StatelessWidget {
    final SpotubeSimpleArtistObject artist;
    final Widget info;
    const StatsArtistItem({
      super.key,
      required this.artist,
      required this.info,
    });

    @override
    Widget build(BuildContext context) {
      return ButtonTile(
        title: Text(artist.name),
        leading: CircleAvatar(
          radius: 18,
          backgroundImage: UniversalImage.imageProvider(
            (artist.images).asUrlString(
              placeholder: ImagePlaceholder.artist,
            ),
          ),
          child: Text(artist.name.substring(0, 1)),
        ),
        trailing: info,
        onPressed: () {
          context.navigateTo(ArtistRoute(artistId: artist.id));
        },
      );
    }
  }
  