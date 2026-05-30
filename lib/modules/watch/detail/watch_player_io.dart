// Native (Android / iOS / desktop) inline video player.
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/widgets/watchtower_loader.dart';

class WatchInlinePlayer {
  late final Player _player;
  late final VideoController _controller;
  final ValueNotifier<bool> _seekingNotifier = ValueNotifier(false);

  bool hasVideoUrl = false;
  int? loadedChapterId;

  WatchInlinePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  void dispose() {
    _player.dispose();
    _seekingNotifier.dispose();
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
  }) {
    if (!hasVideoUrl) return const SizedBox.shrink();

    final accent = Theme.of(context).primaryColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // IgnorePointer so touches reach the controls below
        IgnorePointer(
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          ),
        ),
        // gradient for readability of controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: IgnorePointer(
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
        ),
        // State overlay (loading / buffering / seeking / success / error)
        Positioned.fill(
          child: _PlayerStateOverlay(
            player: _player,
            seekingNotifier: _seekingNotifier,
          ),
        ),
        // Controls bar — receives all pointer events
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _InlineControls(
            player: _player,
            controller: _controller,
            accent: accent,
            seekingNotifier: _seekingNotifier,
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

// ─── Fullscreen player page ────────────────────────────────────────────────────

class _FullscreenPlayerPage extends StatefulWidget {
  final VideoController controller;
  const _FullscreenPlayerPage({required this.controller});

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Video(
        controller: widget.controller,
        fit: BoxFit.contain,
        controls: MaterialVideoControls,
      ),
    );
  }
}

// ─── Inline controls widget ───────────────────────────────────────────────────

class _InlineControls extends StatelessWidget {
  final Player player;
  final VideoController controller;
  final Color accent;
  final ValueNotifier<bool> seekingNotifier;

  const _InlineControls({
    required this.player,
    required this.controller,
    required this.accent,
    required this.seekingNotifier,
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
                          onChangeStart: (_) => seekingNotifier.value = true,
                          onChanged: (v) {
                            if (dur.inMilliseconds > 0) {
                              player.seek(Duration(
                                  milliseconds:
                                      (v * dur.inMilliseconds).round()));
                            }
                          },
                          onChangeEnd: (_) => seekingNotifier.value = false,
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullscreenPlayerPage(controller: controller),
              ),
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

// ─── Player state overlay (Lottie animations) ─────────────────────────────────

class _PlayerStateOverlay extends StatefulWidget {
  final Player player;
  final ValueNotifier<bool> seekingNotifier;
  const _PlayerStateOverlay({required this.player, required this.seekingNotifier});

  @override
  State<_PlayerStateOverlay> createState() => _PlayerStateOverlayState();
}

class _PlayerStateOverlayState extends State<_PlayerStateOverlay> {
  String? _anim;
  double? _percent;
  bool _firstDuration = true;
  bool _successShown = false;

  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _bufSub;

  @override
  void initState() {
    super.initState();
    _anim = 'loading';

    // Hide loading once first duration is known
    _durSub = widget.player.stream.duration.listen((dur) {
      if (dur > Duration.zero && _firstDuration && mounted) {
        _firstDuration = false;
        if (_anim == 'loading') setState(() => _anim = null);
      }
    });

    // Buffering → show buffering overlay with percent; dismiss → flash success once
    _bufSub = widget.player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (widget.seekingNotifier.value) return; // seek overlay handled separately
      if (buffering) {
        final buffered = widget.player.state.buffer;
        final duration = widget.player.state.duration;
        final pct = duration.inMilliseconds > 0
            ? (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : null;
        setState(() { _anim = 'buffering'; _percent = pct; });
      } else if (_anim == 'buffering') {
        if (!_successShown) {
          _successShown = true;
          setState(() { _anim = 'success'; _percent = null; });
        } else {
          setState(() { _anim = null; _percent = null; });
        }
      }
    });

    widget.seekingNotifier.addListener(_onSeeking);
  }

  void _onSeeking() {
    if (!mounted) return;
    setState(() {
      _anim = widget.seekingNotifier.value ? 'seeking' : null;
      _percent = null;
    });
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _bufSub?.cancel();
    widget.seekingNotifier.removeListener(_onSeeking);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_anim == null) return const SizedBox.shrink();
    return WatchtowerLoader(
      animation: _anim!,
      percent: _percent,
      onDismiss: _anim == 'success'
          ? () { if (mounted) setState(() => _anim = null); }
          : null,
    );
  }
}
