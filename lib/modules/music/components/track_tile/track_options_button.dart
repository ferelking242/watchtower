import 'package:auto_route/auto_route.dart';
    import 'package:flutter_hooks/flutter_hooks.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:flutter/material.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/collections/spotube_icons.dart';
    import 'package:watchtower/modules/music/components/image/universal_image.dart';
    import 'package:watchtower/modules/music/components/links/artist_link.dart';
    import 'package:watchtower/modules/music/components/track_tile/track_options.dart';
    import 'package:watchtower/modules/music/extensions/constrains.dart';
    import 'package:watchtower/modules/music/models/metadata/metadata.dart';

    class TrackOptionsButton extends HookConsumerWidget {
    final SpotubeTrackObject track;
    final bool userPlaylist;
    final String? playlistId;
    const TrackOptionsButton({
      super.key,
      required this.track,
      required this.userPlaylist,
      this.playlistId,
    });

    static Future<void> showOptions(
      BuildContext context,
      SpotubeTrackObject track, {
      bool userPlaylist = false,
      String? playlistId,
    }) async {
      final mediaQuery = MediaQuery.sizeOf(context);
      if (mediaQuery.lgAndUp) {
        await showDialog(
          context: context,
          useRootNavigator: false,
          barrierColor: Colors.transparent,
          builder: (ctx) => Align(
            alignment: Alignment.topRight,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TrackOptions(
                    track: track,
                    playlistId: playlistId,
                    userPlaylist: userPlaylist,
                    onTapItem: () {
                      Navigator.of(ctx, rootNavigator: false).pop();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        await showModalBottomSheet(
          context: context,
          useRootNavigator: false,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: UniversalImage.imageProvider(
                              (track.album.images).smallest(ImagePlaceholder.albumArt),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ArtistLink(
                              artists: track.artists,
                              onOverflowArtistClick: () => ctx.navigateTo(
                                TrackRoute(trackId: track.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  TrackOptions(
                    track: track,
                    userPlaylist: userPlaylist,
                    playlistId: playlistId,
                    onTapItem: () {
                      Navigator.of(ctx, rootNavigator: false).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
    }

    @override
    Widget build(BuildContext context, ref) {
      return IconButton(
        icon: const Icon(SpotubeIcons.moreHorizontal),
        onPressed: () {
          showOptions(
            context,
            track,
            userPlaylist: userPlaylist,
            playlistId: playlistId,
          );
        },
      );
    }
    }
    