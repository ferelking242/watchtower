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
    final ThemeData() = theme;

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
            )
                ? ButtonStyle()
                : ButtonStyle(),
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

              if (!context.mounted) return;

              showToast(
                context: context,
                location: ToastLocation.topRight,
                dismissible: true,
                builder: (context, overlay) {
                  return Card(
                    child: Text(
                      context.l10n.artist_url_copied,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constrains) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: theme.borderRadiusXl,
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
                              OutlineBadge(
                                child:
                                    Text(context.l10n.artist),
                              ),
                              if (isBlackListed) ...[
                                const SizedBox(height: 5, width: 5),
                                DestructiveBadge(
                                  child: Text(context.l10n.blacklisted),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 10, width: 10),
                          Flexible(
                            child: AutoSizeText(
                              artist.name,
                              style: constrains.smAndDown
                                  ? typography.h4
                                  : typography.h3,
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
        );
      },
    );
  }
}
