import 'package:flutter/material.dart';
  import 'package:flutter_hooks/flutter_hooks.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:sliding_up_panel/sliding_up_panel.dart';
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
      final cs = theme.colorScheme;

      final shouldShow = useState(true);

      ref.listen(navigationPanelHeight, (_, height) {
        shouldShow.value = (height as double).ceil() == 50;
      });

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: canShow && shouldShow.value
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: panelController.open,
                          child: Row(
                            children: [
                              // Track details (album art + title + artist)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: PlayerTrackDetails(
                                    track: playlist.activeTrack,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              // Prev
                              IconButton(
                                icon: const Icon(SpotubeIcons.skipBack),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToPrevious,
                              ),
                              // Play / Pause
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                    minimumSize: const Size(40, 40),
                                    maximumSize: const Size(40, 40),
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  onPressed: isFetchingActiveTrack
                                      ? null
                                      : () async {
                                          if (audioPlayer.isPlaying) {
                                            await audioPlayer.pause();
                                          } else {
                                            await audioPlayer.resume();
                                          }
                                        },
                                  child: isFetchingActiveTrack
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          playing
                                              ? SpotubeIcons.pause
                                              : SpotubeIcons.play,
                                          size: 20,
                                        ),
                                ),
                              ),
                              // Next
                              IconButton(
                                icon: const Icon(SpotubeIcons.skipForward),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToNext,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    }
  }
  