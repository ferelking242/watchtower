import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:watchtower/modules/music/collections/intents.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/player/player_track_details.dart';
import 'package:watchtower/modules/music/modules/root/spotube_navigation_bar.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/audio_player/querying_track_info.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';

class PlayerOverlayCollapsedSection extends HookConsumerWidget {
  final PanelController panelController;
  const PlayerOverlayCollapsedSection({
    super.key,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final canShow = playlist.activeTrack != null;

    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final theme = Theme.of(context);

    final shouldShow = useState(true);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldShow.value = (height as double).ceil() == 50;
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: canShow && shouldShow.value
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                panelController.open();
                              },
                              child: Container(
                                width: double.infinity,
                                color: Colors.transparent,
                                child: PlayerTrackDetails(
                                  track: playlist.activeTrack,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(SpotubeIcons.skipBack),
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToPrevious,
                              ),
                              IconButton(
                                icon: isFetchingActiveTrack
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Icon(
                                        playing
                                            ? SpotubeIcons.pause
                                            : SpotubeIcons.play,
                                      ),
                                onPressed: () async {
                                  if (audioPlayer.isPlaying) {
                                    await audioPlayer.pause();
                                  } else {
                                    await audioPlayer.resume();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(SpotubeIcons.skipForward),
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToNext,
                              ),
                              const SizedBox(height: 5, width: 5),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
