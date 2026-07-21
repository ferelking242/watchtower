import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

/// Full-screen player sheet — mirrors Spotube's PlayerOverlay / PlayerPage
/// design: large blurred album art background, track info, progress slider,
/// controls row (shuffle, prev, play/pause, next, repeat), heart + queue.
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
    final track = state.activeTrack;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
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
                color: Colors.white.withValues(alpha: 0.2),
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
                  ? _QueueView(state: state)
                  : _tab == 1
                      ? _LyricsView(track: track)
                      : _PlayerView(state: state, track: track),
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
          color: selected ? cs.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Player view ──────────────────────────────────────────────────────────────

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
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track?.artistNames ?? '',
                                style: tt.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
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
                                : Colors.white.withValues(alpha: 0.6),
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

// ─── Progress slider ──────────────────────────────────────────────────────────

class _ProgressSlider extends ConsumerStatefulWidget {
  final MusicPlayerState state;
  const _ProgressSlider({required this.state});

  @override
  ConsumerState<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends ConsumerState<_ProgressSlider> {
  double? _dragging;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

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
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              Text(
                _fmt(widget.state.duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
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

// ─── Controls row ─────────────────────────────────────────────────────────────

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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ],
            ),
            child: state.isBuffering
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF0E0E0E),
                    ),
                  )
                : Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: const Color(0xFF0E0E0E),
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
      color: active ? cs.primary : Colors.white.withValues(alpha: 0.85),
      onPressed: onTap,
    );
  }
}

// ─── Volume row ───────────────────────────────────────────────────────────────

class _VolumeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(musicVolumeProvider);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.volume_down_rounded,
            size: 18, color: Colors.white.withValues(alpha: 0.5)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 2,
              activeTrackColor: Colors.white.withValues(alpha: 0.8),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
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
            size: 18, color: Colors.white.withValues(alpha: 0.5)),
      ],
    );
  }
}

// ─── Lyrics view ──────────────────────────────────────────────────────────────

class _LyricsView extends StatelessWidget {
  final MusicTrack? track;
  const _LyricsView({required this.track});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded,
                size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Lyrics unavailable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install a lyrics plugin from the Marketplace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Queue view ───────────────────────────────────────────────────────────────

class _QueueView extends ConsumerWidget {
  final MusicPlayerState state;
  const _QueueView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.queue.length,
      onReorder: (oldIdx, newIdx) {
        // reorder handled by provider
      },
      itemBuilder: (ctx, i) {
        final t = state.queue[i];
        final isActive = i == state.currentIndex;
        return ListTile(
          key: ValueKey(t.id + i.toString()),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MusicCachedImage(url: t.imageUrl, width: 40, height: 40),
          ),
          title: Text(
            t.name,
            style: TextStyle(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            t.artistNames,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isActive
              ? Icon(Icons.equalizer_rounded,
                  color: Theme.of(context).colorScheme.primary)
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.4)),
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
