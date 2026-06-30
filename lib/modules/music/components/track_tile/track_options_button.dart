import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/track_tile/track_options.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

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

  static OverlayCompleter<dynamic> showOptions(
    BuildContext context,
    Offset offset,
    SpotubeTrackObject track, {
    bool userPlaylist = false,
    String? playlistId,
  }) {
    return showPopover(
      context: context,
      position: offset,
      alignment: Alignment.bottomRight,
      builder: (context) {
        return SizedBox(
          width: 220 * Theme.of(context).scaling,
          child: Card(
            padding: const EdgeInsets.all(8),
            child: TrackOptions(
              track: track,
              playlistId: playlistId,
              userPlaylist: userPlaylist,
              onTapItem: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final imageProvider = useMemoized(
      () => UniversalImage.imageProvider(
        (track.album.images).smallest(ImagePlaceholder.albumArt),
      ),
      [track.album.images],
    );

    return IconButton(
      icon: const Icon(SpotubeIcons.moreHorizontal),
      onPressed: () {
        final mediaQuery = MediaQuery.sizeOf(context);

        if (mediaQuery.lgAndUp) {
          final renderBox = context.findRenderObject() as RenderBox;
          final position = RelativeRect.fromRect(
            Rect.fromPoints(
              renderBox.localToGlobal(Offset.zero,
                  ancestor: context.findRenderObject()),
              renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero),
                  ancestor: context.findRenderObject()),
            ),
            Offset.zero & mediaQuery,
          );
          final offset = Offset(position.left, position.top);
          showOptions(
            context,
            offset,
            track,
            userPlaylist: userPlaylist,
            playlistId: playlistId,
          );
        } else {
          final capturedTheme = Theme.of(context);
          openDrawer(
            context: context
            draggable: true,
            showDragHandle: true,
            borderRadius: Theme.of(context).borderRadiusMd,
            transformBackdrop: false,
            builder: (context) {
              return Theme(
                data: capturedTheme,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Basic(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: Theme.of(context).borderRadiusMd,
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: imageProvider,
                              ),
                            ),
                          ),
                          title: Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Align(
                            alignment: Alignment.centerLeft,
                            child: ArtistLink(
                              artists: track.artists,
                              onOverflowArtistClick: () => context.navigateTo(
                                TrackRoute(trackId: track.id),
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        TrackOptions(
                          track: track,
                          userPlaylist: userPlaylist,
                          playlistId: playlistId,
                          onTapItem: () {
                            closeDrawer(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
