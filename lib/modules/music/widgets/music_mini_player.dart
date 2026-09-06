import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/pages/music_player_sheet.dart';

/// Pin position of the mini-player pill.
enum MiniPinPosition { left, center, right }

/// Collapsed mini-player bar shown above the dock on ALL pages when music
/// is playing — bridges both the custom MusicPlayerProvider and the main
/// Spotube AudioPlayerProvider.
///
/// Features:
///  - tap anywhere on the bar → opens the full player sheet (both players)
///  - X button → dismisses the bar and stops playback
///  - horizontal drag → pins the bar to the left/right edge as a compact
///    round chip (chevron + animated equalizer), music keeps playing
class MusicMiniPlayer extends HookConsumerWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicPlayerProvider);
    final spotubeState = ref.watch(audioPlayerProvider);

    final customTrack = musicState.activeTrack;
    final spotubeTrack = spotubeState.activeTrack;

    if (customTrack == null && spotubeTrack == null) {
      return const SizedBox.shrink();
    }

    // ── Custom music player (MusicPlayerProvider) ─────────────────────────
    if (customTrack != null) {
      return _MiniBarHost(
        imageUrl: customTrack.imageUrl,
        imagePlaceholder: Assets.images.albumPlaceholder.path,
        title: customTrack.name,
        subtitle: customTrack.artistNames,
        onOpen: () => MusicPlayerSheet.show(context),
        onPlayPause: () => ref.read(musicPlayerProvider.notifier).playPause(),
        onPrev: () => ref.read(musicPlayerProvider.notifier).skipToPrevious(),
        onNext: () => ref.read(musicPlayerProvider.notifier).skipToNext(),
        onClose: () => ref.read(musicPlayerProvider.notifier).clearQueue(),
      );
    }

    // ── Spotube audio player (AudioPlayerProvider) ─────────────────────────
    final st = spotubeState.activeTrack;
    if (st == null) return const SizedBox.shrink();
    final albumArt = st.album.images.isNotEmpty ? st.album.images.last.url : null;
    return _MiniBarHost(
      imageUrl: albumArt,
      imagePlaceholder: Assets.images.albumPlaceholder.path,
      title: st.name,
      subtitle: st.artists.map((a) => a.name).join(', '),
      onOpen: () => MusicPlayerSheet.show(context),
      onPlayPause: () => audioPlayer.playOrPause(),
      onPrev: () => audioPlayer.skipToPrevious(),
      onNext: () => audioPlayer.skipToNext(),
      onClose: () => ref.read(audioPlayerProvider.notifier).stop(),
    );
  }
}

/// Host widget that owns the pin state and the play-state stream.
class _MiniBarHost extends HookConsumerWidget {
  final String? imageUrl;
  final String imagePlaceholder;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const _MiniBarHost({
    required this.imageUrl,
    required this.imagePlaceholder,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = useStream(
      useMemoized(() => audioPlayer.playingStream),
      initialData: audioPlayer.isPlaying,
    ).data ?? audioPlayer.isPlaying;

    final pinPosition = useState(MiniPinPosition.center);
    final dragDelta = useState(0.0);

    final isPinned = pinPosition.value != MiniPinPosition.center;

    // ── Pinned chip: round button stuck to the edge ────────────────────────
    if (isPinned) {
      return AnimatedAlign(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: pinPosition.value == MiniPinPosition.left
            ? Alignment.centerLeft
            : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: GestureDetector(
            // Drag towards center to unpin back to the full bar
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (pinPosition.value == MiniPinPosition.left && v > 150) {
                pinPosition.value = MiniPinPosition.center;
              } else if (pinPosition.value == MiniPinPosition.right &&
                  v < -150) {
                pinPosition.value = MiniPinPosition.center;
              }
            },
            child: GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            UniversalImage(
                              path: imageUrl!,
                              placeholder: imagePlaceholder,
                              fit: BoxFit.cover,
                            ),
                            // Dark scrim so the icon reads on any artwork
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                            Center(
                              child: playing
                                  ? const _EqualizerBars()
                                  : Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                            ),
                          ],
                        )
                      : Center(
                          child: playing
                              ? const _EqualizerBars()
                              : Icon(
                                  Icons.play_arrow_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 26,
                                ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Full bar (centered) ─────────────────────────────────────────────────
    return AnimatedAlign(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                pinPosition.value = MiniPinPosition.left;
              } else if (delta > 80 || velocity > 300) {
                pinPosition.value = MiniPinPosition.right;
              }
            },
            child: _BarBody(
              imageUrl: imageUrl,
              imagePlaceholder: imagePlaceholder,
              title: title,
              subtitle: subtitle,
              playing: playing,
              onOpen: onOpen,
              onPlayPause: onPlayPause,
              onPrev: onPrev,
              onNext: onNext,
              onClose: onClose,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarBody extends StatelessWidget {
  final String? imageUrl;
  final String imagePlaceholder;
  final String title;
  final String subtitle;
  final bool playing;
  final VoidCallback onOpen;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const _BarBody({
    required this.imageUrl,
    required this.imagePlaceholder,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.onOpen,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSmall = MediaQuery.of(context).size.width < 400;
    final barHeight = isSmall ? 58.0 : 64.0;
    final artSize = barHeight - 2;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Album art
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: artSize,
                  height: artSize,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? UniversalImage(
                            path: imageUrl!,
                            placeholder: imagePlaceholder,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(imagePlaceholder, fit: BoxFit.cover),
                  ),
                ),
              ),
              // Content row
              Row(
                children: [
                  SizedBox(width: artSize + (isSmall ? 8 : 12)),
                  // Track info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmall ? 12 : 14,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: isSmall ? 10 : 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Controls
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded,
                        size: isSmall ? 20 : 22),
                    onPressed: onPrev,
                    color: cs.onSurface,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  _PlayPauseCircle(
                    isPlaying: playing,
                    isSmall: isSmall,
                    cs: cs,
                    onTap: onPlayPause,
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded,
                        size: isSmall ? 20 : 22),
                    onPressed: onNext,
                    color: cs.onSurface,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  // Dismiss (stop) button
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: isSmall ? 18 : 20),
                    onPressed: onClose,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox(width: isSmall ? 2 : 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseCircle extends StatelessWidget {
  final bool isPlaying;
  final bool isSmall;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _PlayPauseCircle({
    required this.isPlaying,
    required this.isSmall,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 32.0 : 36.0;
    final iconSize = isSmall ? 18.0 : 22.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: cs.onPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}

/// Small animated 3-bar equalizer shown while the music plays.
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            // Staggered sine-wave heights per bar
            final phase = _controller.value * 2 * math.pi + i * (math.pi / 2.2);
            final h = 4 + 8 * (0.5 + 0.5 * math.sin(phase));
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}