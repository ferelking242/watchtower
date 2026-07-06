import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

import 'package:watchtower/modules/music/provider/blacklist_provider.dart';

class ArtistCard extends HookConsumerWidget {
  final SpotubeFullArtistObject artist;
  const ArtistCard(this.artist, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final backgroundImage = UniversalImage.imageProvider(
      artist.images.asUrlString(
        placeholder: ImagePlaceholder.artist,
      ),
    );
    final isBlackListed = ref.watch(
      blacklistProvider.select(
        (blacklist) => blacklist.asData?.value.any(
          (element) => element.elementId == artist.id,
        ),
      ),
    );

    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.navigateTo(ArtistRoute(artistId: artist.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ClipOval(
                  child: CircleAvatar(
                    backgroundImage: backgroundImage,
                    radius: 65,
                    child: AutoSizeText(
                      artist.name.isNotEmpty
                          ? artist.name.trim()[0].toUpperCase()
                          : '?',
                      style: TextStyle(fontSize: 48, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10, width: 10),
                AutoSizeText(
                  artist.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isBlackListed == true) ...[
                      Chip(
                        label: Text(context.l10n.blacklisted.toUpperCase()),
                        backgroundColor: Colors.red.shade100,
                        labelStyle: const TextStyle(
                            color: Colors.red, fontSize: 10),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(height: 5, width: 5),
                    ],
                    Chip(
                      label: Text(context.l10n.artist.toUpperCase()),
                      backgroundColor:
                          theme.colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontSize: 10),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
