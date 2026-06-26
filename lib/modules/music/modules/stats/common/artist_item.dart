import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
      style: ButtonVariance.ghost,
      title: Text(artist.name),
      leading: Avatar(
        initials: artist.name.substring(0, 1),
        provider: UniversalImage.imageProvider(
          (artist.images).asUrlString(
            placeholder: ImagePlaceholder.artist,
          ),
        ),
      ),
      trailing: info,
      onPressed: () {
        context.navigateTo(ArtistRoute(artistId: artist.id));
      },
    );
  }
}
