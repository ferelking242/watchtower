import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show PlaylistMode;
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/volume_provider.dart';

/// Full-screen player sheet — mirrors Spotube's PlayerOverlay / PlayerPage
/// design: large blurred album art background, track info, progress slider,
/// controls row (shuffle, prev, play/pause, next, repeat), heart + queue.
///
/// Serves BOTH players:
///  - the custom [musicPlayerProvider] (preferred when a track is active)
///  - the embedded Spotube player ([audioPlayerProvider]) when a track from
///    the music search / library is active outside the music module
class MusicPlayerSheet extends ConsumerStatefulWidget {
  const MusicPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  @override
  ConsumerState<MusicPlayerSheet> createState() => _MusicPlayerSheetState();
}

class _MusicPlayerSheetState extends ConsumerState<MusicPlayerSheet> {
  int _tab = 0; // 0 = player, 1 = lyrics, 2 = queue

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final spotubeState = ref.watch(audioPlayerProvider);
    final track = state.activeTrack;
    final spotubeTrack = spotubeState.activeTrack;
    final cs = Theme.of(context).colorScheme;

    // Prefer the custom player; fall back to the Spotube player.
    final useSpotube = track == null && spotubeTrack != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Tab bar
            _PlayerTabBar(current: _tab, onChanged: (t) => setState(() => _tab = t)),
            const SizedBox(height: 4),
            // Content
            Expanded(
              child: _tab == 2
                  ? (useSpotube
                      ? _SpotubeQueueView()
                      : _QueueView(state: state))
                  : _tab == 1
                      ? _LyricsView(track: track?.name ?? spotubeTrack?.name)
                      : (useSpotube
                          ? const _SpotubePlayerView()
                          : _PlayerView(state: state, track: track)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────

class _PlayerTabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _PlayerTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Tab(label: 'Player', selected: current == 0, onTap: () => onChanged(0)),
        const SizedBox(width: 8),
        _Tab(label: 'Lyrics', selected: current == 1, onTap: () => onChanged(1)),
        const SizedBox(width: 8),
        _Tab(label: 'Queue', selected: current == 2, onTap: () => onChanged(2)),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.55),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── Player view (custom player) ──────────────────────────────────────────────

class _PlayerView extends ConsumerWidget {
  final MusicPlayerState state;
  final MusicTrack? track;
  const _PlayerView({required this.state, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final liked = ref.watch(
      musicLikedTracksProvider.select((s) => track != null && s.contains(track!.id)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final screenW = MediaQuery.of(context).size.width;
        // Cap album art: never more than 42% of available height or screen width
        final artSize = (screenW - 48).clamp(0.0, available * 0.42).toDouble();

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: available),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    // Album art — adaptive, centered
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MusicCachedImage(
                          url: track?.imageUrl ?? '',
                          width: artSize,
                          height: artSize,
                          placeholder: Icon(
                            Icons.music_note_rounded,
                            size: 60,
                            color: cs.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title + artist + heart
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.name ?? '—',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track?.artistNames ?? '',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: liked
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.6),
                            size: 26,
                          ),
                          onPressed: track != null
                              ? () => ref
                                  .read(musicPlayerProvider.notifier)
                                  .toggleLike(track!.id)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress slider
                    _ProgressSlider(state: state),
                    const SizedBox(height: 24),
                    // Controls
                    _ControlsRow(state: state),
                    const SizedBox(height: 20),
                    // Volume + extra
                    _VolumeRow(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Progress slider (custom player) ─────────────────────────────────────────

class _ProgressSlider extends ConsumerStatefulWidget {
  final MusicPlayerState state;
  const _ProgressSlider({required this.state});

  @override
  ConsumerState<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends ConsumerState<_ProgressSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _dragging ?? widget.state.progress;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.onSurface.withValues(alpha: 0.15),
            thumbColor: cs.onSurface,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            secondaryTrackValue: widget.state.bufferProgress.clamp(0.0, 1.0),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              _dragging = null;
              final pos = Duration(
                milliseconds: (v * widget.state.duration.inMilliseconds).toInt(),
              );
              ref.read(musicPlayerProvider.notifier).seek(pos);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(_dragging != null
                    ? Duration(
                        milliseconds:
                            (_dragging! * widget.state.duration.inMilliseconds)
                                .toInt())
                    : widget.state.position),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              Text(
                _fmt(widget.state.duration),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Controls row (custom player) ─────────────────────────────────────────────

class _ControlsRow extends ConsumerWidget {
  final MusicPlayerState state;
  const _ControlsRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(musicPlayerProvider.notifier);

    final repeatIcon = switch (state.repeatMode) {
      MusicRepeatMode.track => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final repeatActive = state.repeatMode != MusicRepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        _CtrlBtn(
          icon: Icons.shuffle_rounded,
          active: state.isShuffled,
          size: 22,
          onTap: notifier.toggleShuffle,
        ),
        // Skip previous
        _CtrlBtn(
          icon: Icons.skip_previous_rounded,
          size: 32,
          onTap: notifier.skipToPrevious,
        ),
        // Play / Pause
        GestureDetector(
          onTap: notifier.playPause,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: cs.onSurface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ],
            ),
            child: state.isBuffering
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.surface,
                    ),
                  )
                : Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: cs.surface,
                    size: 32,
                  ),
          ),
        ),
        // Skip next
        _CtrlBtn(
          icon: Icons.skip_next_rounded,
          size: 32,
          onTap: notifier.skipToNext,
        ),
        // Repeat
        _CtrlBtn(
          icon: repeatIcon,
          active: repeatActive,
          size: 22,
          onTap: notifier.cycleRepeatMode,
        ),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final VoidCallback? onTap;
  const _CtrlBtn(
      {required this.icon,
      required this.size,
      this.active = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: size),
      color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.85),
      onPressed: onTap,
    );
  }
}

// ─── Volume row (custom player) ───────────────────────────────────────────────

class _VolumeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(musicVolumeProvider);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.volume_down_rounded,
            size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 2,
              activeTrackColor: cs.onSurface.withValues(alpha: 0.8),
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.15),
              thumbColor: cs.onSurface,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: volume,
              onChanged: (v) =>
                  ref.read(musicVolumeProvider.notifier).setVolume(v),
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded,
            size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
      ],
    );
  }
}

// ─── Player view (Spotube player) ─────────────────────────────────────────────

class _SpotubePlayerView extends ConsumerWidget {
  const _SpotubePlayerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final track = ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final shuffled = ref.watch(audioPlayerProvider.select((s) => s.shuffled));
    final loopMode = ref.watch(audioPlayerProvider.select((s) => s.loopMode));

    if (track == null) {
      return Center(
        child: Text('—', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
      );
    }

    final imageUrl = track.album.images.isNotEmpty
        ? track.album.images.last.url
        : Assets.images.albumPlaceholder.path;
    final durationMs = track.durationMs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final screenW = MediaQuery.of(context).size.width;
        final artSize = (screenW - 48).clamp(0.0, available * 0.42).toDouble();

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: available),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    // Album art
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MusicCachedImage(
                          url: imageUrl,
                          width: artSize,
                          height: artSize,
                          placeholder: Icon(
                            Icons.music_note_rounded,
                            size: 60,
                            color: cs.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title + artist
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.artists.map((a) => a.name).join(', '),
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress (driven by the media_kit position stream)
                    _SpotubeProgressSlider(durationMs: durationMs),
                    const SizedBox(height: 24),
                    // Controls
                    _SpotubeControlsRow(
                      shuffled: shuffled,
                      loopMode: loopMode,
                    ),
                    const SizedBox(height: 20),
                    // Volume
                    _SpotubeVolumeRow(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpotubeProgressSlider extends ConsumerStatefulWidget {
  final int? durationMs;
  const _SpotubeProgressSlider({this.durationMs});

  @override
  ConsumerState<_SpotubeProgressSlider> createState() =>
      _SpotubeProgressSliderState();
}

class _SpotubeProgressSliderState
    extends ConsumerState<_SpotubeProgressSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: audioPlayer.positionStream,
      initialData: audioPlayer.position,
      builder: (context, snap) {
        final position = snap.data ?? Duration.zero;
        final duration = audioPlayer.duration.inMilliseconds > 0
            ? audioPlayer.duration
            : Duration(milliseconds: widget.durationMs ?? 0);
        final maxMs = math.max(duration.inMilliseconds, 1);
        final value = _dragging ??
            (position.inMilliseconds / maxMs).clamp(0.0, 1.0);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.15),
                thumbColor: cs.onSurface,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                onChanged: (v) => setState(() => _dragging = v),
                onChangeEnd: (v) {
                  _dragging = null;
                  audioPlayer.seek(
                    Duration(milliseconds: (v * maxMs).toInt()),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(_dragging != null
                        ? Duration(milliseconds: (_dragging! * maxMs).toInt())
                        : position),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _fmt(duration),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotubeControlsRow extends ConsumerWidget {
  final bool shuffled;
  final PlaylistMode loopMode;
  const _SpotubeControlsRow({
    required this.shuffled,
    required this.loopMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final repeatIcon = loopMode == PlaylistMode.single
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final repeatActive = loopMode != PlaylistMode.none;

    return StreamBuilder<bool>(
      stream: audioPlayer.playingStream,
      initialData: audioPlayer.isPlaying,
      builder: (context, snap) {
        final playing = snap.data ?? audioPlayer.isPlaying;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlBtn(
              icon: Icons.shuffle_rounded,
              active: shuffled,
              size: 22,
              onTap: () => audioPlayer.setShuffle(!shuffled),
            ),
            _CtrlBtn(
              icon: Icons.skip_previous_rounded,
              size: 32,
              onTap: audioPlayer.skipToPrevious,
            ),
            GestureDetector(
              onTap: audioPlayer.playOrPause,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: cs.onSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: cs.surface,
                  size: 32,
                ),
              ),
            ),
            _CtrlBtn(
              icon: Icons.skip_next_rounded,
              size: 32,
              onTap: audioPlayer.skipToNext,
            ),
            _CtrlBtn(
              icon: repeatIcon,
              active: repeatActive,
              size: 22,
              onTap: () async {
                await audioPlayer.setLoopMode(
                  switch (loopMode) {
                    PlaylistMode.loop => PlaylistMode.single,
                    PlaylistMode.single => PlaylistMode.none,
                    PlaylistMode.none => PlaylistMode.loop,
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _SpotubeVolumeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.volume_down_rounded,
            size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 2,
              activeTrackColor: cs.onSurface.withValues(alpha: 0.8),
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.15),
              thumbColor: cs.onSurface,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: volume,
              onChanged: (v) =>
                  ref.read(volumeProvider.notifier).setVolume(v),
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded,
            size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
      ],
    );
  }
}

// ─── Lyrics view ──────────────────────────────────────────────────────────────

class _LyricsView extends StatelessWidget {
  final String? track;
  const _LyricsView({required this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded,
                size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Lyrics unavailable',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install a lyrics plugin from the Marketplace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Queue view (custom player) ───────────────────────────────────────────────

class _QueueView extends ConsumerWidget {
  final MusicPlayerState state;
  const _QueueView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (state.queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.queue.length,
      itemBuilder: (ctx, i) {
        final t = state.queue[i];
        final isActive = i == state.currentIndex;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MusicCachedImage(url: t.imageUrl, width: 40, height: 40),
          ),
          title: Text(
            t.name,
            style: TextStyle(
              color: isActive ? cs.primary : cs.onSurface,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            t.artistNames,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isActive
              ? Icon(Icons.equalizer_rounded, color: cs.primary)
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurface.withValues(alpha: 0.4)),
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).removeFromQueue(i),
                ),
          onTap: () =>
              ref.read(musicPlayerProvider.notifier).skipToIndex(i),
        );
      },
    );
  }
}

// ─── Queue view (Spotube player) ──────────────────────────────────────────────

class _SpotubeQueueView extends ConsumerWidget {
  const _SpotubeQueueView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(audioPlayerProvider);
    final tracks = state.tracks;

    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tracks.length,
      itemBuilder: (ctx, i) {
        final t = tracks[i];
        final isActive = i == state.currentIndex;
        final imageUrl = t.album.images.isNotEmpty
            ? t.album.images.first.url
            : null;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MusicCachedImage(
              url: imageUrl ?? '',
              width: 40,
              height: 40,
              placeholder: Icon(Icons.music_note_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
            ),
          ),
          title: Text(
            t.name,
            style: TextStyle(
              color: isActive ? cs.primary : cs.onSurface,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            t.artists.map((a) => a.name).join(', '),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isActive
              ? Icon(Icons.equalizer_rounded, color: cs.primary)
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurface.withValues(alpha: 0.4)),
                  onPressed: () => ref
                      .read(audioPlayerProvider.notifier)
                      .removeTrack(t.id),
                ),
          onTap: () => audioPlayer.jumpTo(i),
        );
      },
    );
  }
}