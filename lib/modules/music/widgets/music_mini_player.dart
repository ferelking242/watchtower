import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/pages/music_player_sheet.dart';

/// Collapsed mini-player bar shown above the dock on ALL pages when music
/// is playing — bridges both the custom MusicPlayerProvider and the main
/// Spotube AudioPlayerProvider.
class MusicMiniPlayer extends HookConsumerWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Prefer custom player, fallback to Spotube player ──────────────────
    final musicState = ref.watch(musicPlayerProvider);
    final spotubeState = ref.watch(audioPlayerProvider);

    final customTrack = musicState.activeTrack;
    final spotubeTrack = spotubeState.activeTrack;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSmall = MediaQuery.of(context).size.width < 400;

    // ── Custom music player (MusicPlayerProvider) ─────────────────────────
    if (customTrack != null) {
      return _MusicPlayerBar(
        imageUrl: customTrack.imageUrl,
        imagePlaceholder: Assets.images.albumPlaceholder.path,
        title: customTrack.name,
        subtitle: customTrack.artistNames,
        progress: musicState.progress,
        isSmall: isSmall,
        cs: cs,
        tt: tt,
        onTap: () => MusicPlayerSheet.show(context),
        onPlayPause: () =>
            ref.read(musicPlayerProvider.notifier).playPause(),
        onPrev: () =>
            ref.read(musicPlayerProvider.notifier).skipToPrevious(),
        onNext: () =>
            ref.read(musicPlayerProvider.notifier).skipToNext(),
      );
    }

    // ── Spotube audio player (AudioPlayerProvider) ─────────────────────────
    if (spotubeTrack == null) return const SizedBox.shrink();

    return _MusicPlayerBar(
      imageUrl: spotubeTrack.album.images.isNotEmpty
          ? spotubeTrack.album.images.last.url
          : null,
      imagePlaceholder: Assets.images.albumPlaceholder.path,
      title: spotubeTrack.name,
      subtitle:
          spotubeTrack.artists.map((a) => a.name).join(', '),
      progress: null, // driven by stream inside the bar
      isSmall: isSmall,
      cs: cs,
      tt: tt,
      onTap: null,
      onPlayPause: () => audioPlayer.playOrPause(),
      onPrev: () => audioPlayer.skipToPrevious(),
      onNext: () => audioPlayer.skipToNext(),
      spotubeTrackDurationMs: spotubeTrack.durationMs,
    );
  }
}

// ─── Shared mini-bar ─────────────────────────────────────────────────────────

class _MusicPlayerBar extends HookConsumerWidget {
  final String? imageUrl;
  final String imagePlaceholder;
  final String title;
  final String subtitle;
  final double? progress; // null = derive from Spotube positionStream
  final bool isSmall;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final int? spotubeTrackDurationMs;

  const _MusicPlayerBar({
    required this.imageUrl,
    required this.imagePlaceholder,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.isSmall,
    required this.cs,
    required this.tt,
    required this.onTap,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    this.spotubeTrackDurationMs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream-driven play state
    final playing = useStream(
      useMemoized(() => audioPlayer.playingStream),
      initialData: audioPlayer.isPlaying,
    ).data ?? audioPlayer.isPlaying;

    // Progress from positionStream (only when progress not provided)
    final positionMs = useStream(
      useMemoized(() => audioPlayer.positionStream.map((d) => d.inMilliseconds)),
      initialData: audioPlayer.position.inMilliseconds,
    ).data ?? 0;

    final computedProgress = progress ??
        (spotubeTrackDurationMs != null && spotubeTrackDurationMs! > 0
            ? (positionMs / spotubeTrackDurationMs!).clamp(0.0, 1.0)
            : 0.0);

    final barHeight = isSmall ? 58.0 : 64.0;
    final artSize = barHeight - 2; // slight inset

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          isSmall ? 6 : 8,
          0,
          isSmall ? 6 : 8,
          isSmall ? 6 : 8,
        ),
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
              // Progress indicator at very bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: computedProgress.toDouble(),
                  minHeight: 2,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              // Content row
              Row(
                children: [
                  // Album art
                  SizedBox(
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
                          : Image.asset(imagePlaceholder,
                              fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(width: isSmall ? 8 : 12),
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
                  SizedBox(width: isSmall ? 4 : 6),
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
