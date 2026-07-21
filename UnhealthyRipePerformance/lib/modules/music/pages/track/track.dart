import 'package:auto_route/auto_route.dart';
import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/heart_button/heart_button.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/links/link_text.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/components/track_tile/track_options_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/list.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/tracks/track.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';

import 'package:watchtower/modules/music/extensions/constrains.dart';

class TrackPage extends HookConsumerWidget {
  static const name = "track";

  final String trackId;
  const TrackPage({
    super.key,
    @PathParam("id") required this.trackId,
  });

  @override
  Widget build(BuildContext context, ref) {
    final ThemeData(:typography, :colorScheme) = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);

    final isActive = playlist.activeTrack?.id == trackId;

    final trackQuery = ref.watch(metadataPluginTrackProvider(trackId));

    final track = trackQuery.asData?.value ?? FakeData.track;

    void onPlay() async {
      if (isActive) {
        audioPlayer.pause();
      } else {
        await playlistNotifier.load([track], autoPlay: true);
      }
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: 
          AppBar(
            backgroundColor: Colors.transparent,
                      )
        ,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: UniversalImage.imageProvider(
                      track.album.images.asUrlString(
                        placeholder: ImagePlaceholder.albumArt,
                      ),
                    ),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      colorScheme.surface.withValues(alpha: 0.5),
                      BlendMode.srcOver,
                    ),
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Skeletonizer(enabled: trackQuery.isLoading,
                  child: Container(
                    alignment: Alignment.topCenter,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.surface,
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.2, 1],
                      ),
                    ),
                    child: SafeArea(
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runAlignment: WrapAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: UniversalImage(
                                path: track.album.images.asUrlString(
                                  placeholder: ImagePlaceholder.albumArt,
                                ),
                                height: 200,
                                width: 200,
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: mediaQuery.smAndDown
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.name,
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(SpotubeIcons.album),
                                    SizedBox(height: 5),
                                    Flexible(
                                      child: LinkText(
                                        track.album.name,
                                        AlbumRoute(
                                          id: track.album.id,
                                          album: track.album,
                                        ),
                                        push: true,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(SpotubeIcons.artist),
                                    SizedBox(height: 5),
                                    Flexible(
                                      child: ArtistLink(
                                        artists: track.artists,
                                        hideOverflowArtist: false,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 350),
                                  child: Row(
                                    mainAxisSize: mediaQuery.smAndDown
                                        ? MainAxisSize.max
                                        : MainAxisSize.min,
                                    children: [
                                      SizedBox(height: 5),
                                      if (!isActive &&
                                          !playlist.tracks
                                              .containsBy(track, (t) => t.id))
                                        OutlinedButton(
                                          child: Text(context.l10n.queue),
                                          onPressed: () {
                                            playlistNotifier.addTrack(track);
                                          },
                                        ),
                                      SizedBox(height: 5),
                                      if (!isActive &&
                                          !playlist.tracks
                                              .containsBy(track, (t) => t.id))
                                        IconButton(
                                          icon: const Icon(
                                              SpotubeIcons.lightning),
                                          onPressed: () {
                                            playlistNotifier
                                                .addTracksAtFirst([track]);
                                          },
                                        ),
                                      SizedBox(height: 5),
                                      IconButton(
                                        icon: Icon(
                                          isActive
                                              ? SpotubeIcons.pause
                                              : SpotubeIcons.play,
                                        ),
                                        onPressed: onPlay,
                                      ),
                                      SizedBox(height: 5),
                                      if (mediaQuery.smAndDown)
                                        const Spacer()
                                      else
                                        SizedBox(height: 20),
                                      TrackHeartButton(track: track),
                                      TrackOptionsButton(
                                        track: track,
                                        userPlaylist: false,
                                      ),
                                      SizedBox(height: 5),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
