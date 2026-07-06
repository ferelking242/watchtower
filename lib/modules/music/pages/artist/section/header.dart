import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/artist.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/artists.dart';
import 'package:watchtower/modules/music/utils/primitive_utils.dart';

class ArtistPageHeader extends HookConsumerWidget {
  final String artistId;
  const ArtistPageHeader({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));
    final artist = artistQuery.asData?.value ?? FakeData.artist;

    final theme = Theme.of(context);

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    ref.watch(blacklistProvider);
    final blacklistNotifier = ref.watch(blacklistProvider.notifier);
    final isBlackListed = blacklistNotifier.containsArtist(artist.id);

    final image = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    final actions = Skeleton.keep(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (authenticated.asData?.value == true)
            Consumer(
              builder: (context, ref, _) {
                final isFollowingQuery = ref.watch(
                  metadataPluginIsSavedArtistProvider(artist.id),
                );
                final followingArtistNotifier =
                    ref.watch(metadataPluginSavedArtistsProvider.notifier);

                return switch (isFollowingQuery) {
                  AsyncData(value: final following) => Builder(
                      builder: (context) {
                        if (following) {
                          return OutlinedButton(
                            onPressed: () async {
                              await followingArtistNotifier
                                  .removeFavorite([artist]);
                            },
                            child: Text(context.l10n.following),
                          );
                        }

                        return FilledButton(
                          onPressed: () async {
                            await followingArtistNotifier.addFavorite([artist]);
                          },
                          child: Text(context.l10n.follow),
                        );
                      },
                    ),
                  AsyncError() => const SizedBox(),
                  _ => const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    )
                };
              },
            ),
          const SizedBox(width: 5),
          IconButton(
            icon: Icon(
              SpotubeIcons.userRemove,
              color: !isBlackListed ? Colors.red[400] : null,
            ),
            onPressed: () async {
              if (isBlackListed) {
                await ref.read(blacklistProvider.notifier).remove(artist.id);
              } else {
                await ref.read(blacklistProvider.notifier).add(
                      BlacklistTableCompanion.insert(
                        name: artist.name,
                        elementId: artist.id,
                        elementType: BlacklistedType.artist,
                      ),
                    );
              }
            },
          ),
          IconButton(
            icon: const Icon(SpotubeIcons.share),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: artist.externalUri,
                ),
              );
            },
          )
        ],
      ),
    );

    return Skeletonizer(
      enabled: artistQuery.isLoading,
      child: LayoutBuilder(
        builder: (context, constrains) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: UniversalImage(
                          path: image,
                          width: constrains.mdAndUp ? 200 : 120,
                          height: constrains.mdAndUp ? 200 : 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20, width: 20),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(context.l10n.artist),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (isBlackListed) ...[
                                  const SizedBox(height: 5, width: 5),
                                  Chip(
                                    label: Text(context.l10n.blacklisted),
                                    backgroundColor: Colors.red.shade100,
                                    labelStyle: const TextStyle(
                                        color: Colors.red),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ]
                              ],
                            ),
                            const SizedBox(height: 10, width: 10),
                            Flexible(
                              child: AutoSizeText(
                                artist.name,
                                style: constrains.smAndDown
                                    ? theme.textTheme.headlineSmall!
                                    : theme.textTheme.headlineMedium!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                minFontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5, width: 5),
                            Flexible(
                              child: AutoSizeText(
                                context.l10n.followers(
                                  artist.followers == null
                                      ? double.infinity
                                      : PrimitiveUtils.toReadableNumber(
                                          artist.followers!.toDouble(),
                                        ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                minFontSize: 12,
                              ),
                            ),
                            if (constrains.mdAndUp) ...[
                              const SizedBox(height: 20, width: 20),
                              actions,
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (constrains.smAndDown) ...[
                    const SizedBox(height: 20, width: 20),
                    actions,
                  ]
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}
