import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';
import 'package:watchtower/modules/music/pages/music_player_sheet.dart';

/// Collapsed mini-player bar shown just above the dock — mirrors Spotube's
/// PlayerOverlayCollapsedSection design: blurred card with art, title/artist,
/// skip-back, play/pause, skip-forward controls.
class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.activeTrack;

    if (track == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => MusicPlayerSheet.show(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Progress bar at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 2,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    child: MusicCachedImage(
                      url: track.imageUrl,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + artist
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artistNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Controls
                  _MiniControl(
                    icon: Icons.skip_previous_rounded,
                    onTap: () =>
                        ref.read(musicPlayerProvider.notifier).skipToPrevious(),
                  ),
                  _PlayPauseButton(isPlaying: state.isPlaying, isBuffering: state.isBuffering),
                  _MiniControl(
                    icon: Icons.skip_next_rounded,
                    onTap: () =>
                        ref.read(musicPlayerProvider.notifier).skipToNext(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, iconSize: 22),
      onPressed: onTap,
      color: Theme.of(context).colorScheme.onSurface,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  final bool isPlaying;
  final bool isBuffering;
  const _PlayPauseButton({required this.isPlaying, required this.isBuffering});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => ref.read(musicPlayerProvider.notifier).playPause(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        child: isBuffering
            ? Padding(
                padding: const EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onPrimary,
                ),
              )
            : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: cs.onPrimary,
                size: 22,
              ),
      ),
    );
  }
}
