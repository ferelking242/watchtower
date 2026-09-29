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

/// Pin position of the mini-player pill.
enum _PinPosition { left, center, right }

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
    final pinPosition = useState(_PinPosition.center);
    final dragDelta = useState(0.0);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldShow.value = (height as double).ceil() == 50;
    });

    if (!canShow || !shouldShow.value) return const SizedBox.shrink();

    final isPinned = pinPosition.value != _PinPosition.center;

    // ── Compact pill (pinned to an edge) ─────────────────────────────────────
    if (isPinned) {
      return AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: pinPosition.value == _PinPosition.left
            ? Alignment.bottomLeft
            : Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              // Dragging back to center: any drag towards center unpins
              if (pinPosition.value == _PinPosition.left &&
                  details.primaryVelocity != null &&
                  details.primaryVelocity! > 100) {
                pinPosition.value = _PinPosition.center;
              } else if (pinPosition.value == _PinPosition.right &&
                  details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                pinPosition.value = _PinPosition.center;
              }
            },
            child: GestureDetector(
              onTap: () => pinPosition.value = _PinPosition.center,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
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
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: panelController.open,
                    child: Center(
                      child: isFetchingActiveTrack
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playing ? SpotubeIcons.pause : SpotubeIcons.play,
                              size: 24,
                              color: cs.onSurface,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Full pill (centered) ──────────────────────────────────────────────────
    return AnimatedAlign(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              dragDelta.value += details.delta.dx;
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final delta = dragDelta.value;
              dragDelta.value = 0;
              // Snap to edge if dragged far enough or flung fast enough
              if (delta < -80 || velocity < -300) {
                pinPosition.value = _PinPosition.left;
              } else if (delta > 80 || velocity > 300) {
                pinPosition.value = _PinPosition.right;
              }
            },
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
      ),
    );
  }
}
