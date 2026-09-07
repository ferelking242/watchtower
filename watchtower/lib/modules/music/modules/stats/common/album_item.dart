import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/album/album_card.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';

class StatsAlbumItem extends StatelessWidget {
  final SpotubeSimpleAlbumObject album;
  final Widget info;
  const StatsAlbumItem({super.key, required this.album, required this.info});

  @override
  Widget build(BuildContext context) {
    return ButtonTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: UniversalImage(
          path: (album.images).asUrlString(
            placeholder: ImagePlaceholder.albumArt,
          ),
          width: 40,
          height: 40,
        ),
      ),
      title: Text(album.name),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${album.albumType.formatted} • "),
          Flexible(
            child: ArtistLink(
              artists: album.artists,
              mainAxisAlignment: WrapAlignment.start,
              onOverflowArtistClick: () =>
                  context.navigateTo(AlbumRoute(id: album.id, album: album)),
            ),
          ),
        ],
      ),
      trailing: info,
      onPressed: () {
        context.navigateTo(AlbumRoute(id: album.id, album: album));
      },
    );
  }
}
