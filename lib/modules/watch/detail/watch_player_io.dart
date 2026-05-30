// Native (Android / iOS / desktop) inline video player.
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

class WatchInlinePlayer {
  late final Player _player;
  late final VideoController _controller;

  bool hasVideoUrl = false;
  int? loadedChapterId;

  WatchInlinePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  void dispose() {
    _player.dispose();
  }

  Future<void> load({
    required WidgetRef ref,
    required Chapter chapter,
  }) async {
    try {
      final data =
          await ref.read(getVideoListProvider(episode: chapter).future);
      final (videos, _, __, ___) = data;
      if (videos.isNotEmpty) {
        final v = videos.first;
        await _player.open(
          Media(v.url, httpHeaders: v.headers),
          play: true,
        );
        hasVideoUrl = true;
      }
    } catch (_) {}
  }

  /// Overlay shown on top of the poster inside the SliverAppBar banner.
  Widget buildBannerOverlay({
    required BuildContext context,
    required List<Chapter> chapters,
  }) {
    if (!hasVideoUrl) return const SizedBox.shrink();

    final accent = Theme.of(context).primaryColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        ),
        // gradient for readability of controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
          ),
        ),
        // Controls bar
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _InlineControls(
            player: _player,
            accent: accent,
            chapters: chapters,
          ),
        ),
      ],
    );
  }

  /// Full-screen landscape player widget.
  Widget buildFullscreenPlayer() {
    return Video(
      controller: _controller,
      fit: BoxFit.contain,
      controls: MaterialVideoControls,
    );
  }
}

// ─── Inline controls widget ───────────────────────────────────────────────────

class _InlineControls extends StatelessWidget {
  final Player player;
  final Color accent;
  final List<Chapter> chapters;

  const _InlineControls({
    required this.player,
    required this.accent,
    required this.chapters,
  });

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Play / Pause ──────────────────────────────
          StreamBuilder<bool>(
            stream: player.stream.playing,
            initialData: player.state.playing,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return IconButton(
                icon: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => player.playOrPause(),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            },
          ),

          // ── Seek slider + time ────────────────────────
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = player.state.duration;
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12),
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            if (dur.inMilliseconds > 0) {
                              player.seek(Duration(
                                  milliseconds:
                                      (v * dur.inMilliseconds).round()));
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_fmt(pos)}/${_fmt(dur)}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── PiP ──────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_outlined,
                color: Colors.white, size: 19),
            onPressed: () {
              // PiP requires platform channel — no-op for now
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),

          // ── Fullscreen ────────────────────────────────
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
            onPressed: chapters.isEmpty
                ? null
                : () => chapters.first
                    .pushToReaderView(context, ignoreIsRead: true),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}
