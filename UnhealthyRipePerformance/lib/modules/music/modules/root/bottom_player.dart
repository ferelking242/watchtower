import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/player/player_actions.dart';
import 'package:watchtower/modules/music/modules/player/player_overlay.dart';
import 'package:watchtower/modules/music/modules/player/player_track_details.dart';
import 'package:watchtower/modules/music/modules/player/player_controls.dart';
import 'package:watchtower/modules/music/modules/player/volume_slider.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

import 'package:watchtower/modules/music/provider/volume_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class BottomPlayer extends HookConsumerWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final mediaQuery = MediaQuery.of(context);

    String albumArt = useMemoized(
      () => playlist.activeTrack?.album.images.isNotEmpty == true
          ? (playlist.activeTrack?.album.images).asUrlString(
              index: (playlist.activeTrack?.album.images.length ?? 1) - 1,
              placeholder: ImagePlaceholder.albumArt,
            )
          : Assets.images.albumPlaceholder.path,
      [playlist.activeTrack?.album.images],
    );

    // returning an empty non spacious Container as the overlay will take
    // place in the global overlay stack aka [_entries]
    if (layoutMode == LayoutMode.compact ||
        ((mediaQuery.mdAndDown) && layoutMode == LayoutMode.adaptive)) {
      return PlayerOverlay(albumArt: albumArt);
    }

    return Card(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: PlayerTrackDetails(track: playlist.activeTrack),
          ),
          // controls
          const Flexible(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(top: 5),
              child: PlayerControls(),
            ),
          ),
          // add to saved tracks
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerActions(
                extraActions: [
                  IconButton(
                    icon: const Icon(SpotubeIcons.miniPlayer),
                    onPressed: () async {
                      if (!kIsDesktop) return;

                      final prevSize = await windowManager.getSize();
                      await windowManager.setMinimumSize(
                        const Size(300, 300),
                      );
                      await windowManager.setAlwaysOnTop(true);
                      if (!kIsLinux) {
                        await windowManager.setHasShadow(false);
                      }
                      await windowManager.setAlignment(Alignment.topRight);
                      await windowManager.setSize(const Size(400, 500));
                      await Future.delayed(
                        const Duration(milliseconds: 100),
                        () async {
                          if (context.mounted) {
                            context.navigateTo(
                              MiniLyricsRoute(prevSize: prevSize),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              Container(
                height: 40,
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.only(right: 10),
                child: Consumer(builder: (context, ref, _) {
                  final volume = ref.watch(volumeProvider);
                  return VolumeSlider(
                    fullWidth: true,
                    value: volume,
                    onChanged: (value) {
                      ref.read(volumeProvider.notifier).setVolume(value);
                    },
                  );
                }),
              )
            ],
          ),
        ],
      ),
    );
  }
}
