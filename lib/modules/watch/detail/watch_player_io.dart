// Native (Android / iOS / desktop) inline video player.
  // Conditionally imported by watch_detail_view.dart via:
  //   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';
  import 'dart:async';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

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

    Widget buildBannerOverlay({required BuildContext context}) {
      if (!hasVideoUrl) return const SizedBox.shrink();

      final accent = Theme.of(context).primaryColor;

      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Video(
              controller: _controller,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _PlayerStateOverlay(
              player: _player,
              seekingNotifier: _seekingNotifier,
            ),
          ),
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
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
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

  // ─── Inline controls (StatefulWidget for speed/track state) ───────────────────

  class _InlineControls extends StatefulWidget {
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

    @override
    State<_InlineControls> createState() => _InlineControlsState();
  }

  class _InlineControlsState extends State<_InlineControls> {
    double _speed = 1.0;

    Player get _p => widget.player;
    VideoController get _c => widget.controller;

    String _fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    Future<void> _enterPiP() async {
      const ch = MethodChannel('com.watchtower.app.pip');
      try {
        await ch.invokeMethod('enterPiP');
      } catch (_) {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _FullscreenPlayerPage(controller: _c)),
          );
        }
      }
    }

    void _openFullscreen() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullscreenPlayerPage(controller: _c)),
    );

    void _showPlayerSettings() {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) => _PlayerSettingsSheet(
          player: _p,
          currentSpeed: _speed,
          onSpeedChanged: (s) {
            if (mounted) setState(() => _speed = s);
            _p.setRate(s);
          },
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Seek slider row ──────────────────────────────────────────────
            StreamBuilder<Duration>(
              stream: _p.stream.position,
              initialData: _p.state.position,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = _p.state.duration;
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: widget.accent,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: progress,
                        onChangeStart: (_) => widget.seekingNotifier.value = true,
                        onChanged: (v) {
                          if (dur.inMilliseconds > 0) {
                            _p.seek(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                          }
                        },
                        onChangeEnd: (_) => widget.seekingNotifier.value = false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(pos),
                            style: const TextStyle(color: Colors.white70, fontSize: 10,
                                fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          Text(
                            _fmt(dur),
                            style: const TextStyle(color: Colors.white70, fontSize: 10,
                                fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── Buttons row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rewind 10s
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 22),
                  onPressed: () {
                    final pos = _p.state.position;
                    _p.seek(pos - const Duration(seconds: 10));
                  },
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                // Play / Pause
                StreamBuilder<bool>(
                  stream: _p.stream.playing,
                  initialData: _p.state.playing,
                  builder: (_, snap) {
                    final playing = snap.data ?? false;
                    return IconButton(
                      icon: Icon(
                        playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () => _p.playOrPause(),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    );
                  },
                ),

                // Forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 22),
                  onPressed: () {
                    final pos = _p.state.position;
                    _p.seek(pos + const Duration(seconds: 10));
                  },
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                const Spacer(),

                // Speed chip
                GestureDetector(
                  onTap: _showPlayerSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Settings / more options
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 19),
                  onPressed: _showPlayerSettings,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Options lecteur',
                ),

                // PiP
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_outlined,
                      color: Colors.white, size: 19),
                  onPressed: _enterPiP,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Picture-in-picture',
                ),

                // Fullscreen
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                  onPressed: _openFullscreen,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Plein écran',
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  // ─── Player settings sheet ────────────────────────────────────────────────────

  class _PlayerSettingsSheet extends StatefulWidget {
    final Player player;
    final double currentSpeed;
    final void Function(double speed) onSpeedChanged;

    const _PlayerSettingsSheet({
      required this.player,
      required this.currentSpeed,
      required this.onSpeedChanged,
    });

    @override
    State<_PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
  }

  class _PlayerSettingsSheetState extends State<_PlayerSettingsSheet> {
    static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    late double _speed;

    @override
    void initState() {
      super.initState();
      _speed = widget.currentSpeed;
    }

    String _trackLabel(dynamic track, String fallback) {
      if (track == null) return fallback;
      final t = track.toString();
      if (t.isEmpty || t == 'auto' || t == 'no') return fallback;
      return t;
    }

    @override
    Widget build(BuildContext context) {
      const white = Colors.white;
      const grey = Color(0xFF8E8E93);
      const divColor = Color(0xFF3A3A3C);

      final audioTracks = widget.player.state.tracks.audio;
      final subTracks = widget.player.state.tracks.subtitle;
      final curAudio = widget.player.state.track.audio;
      final curSub = widget.player.state.track.subtitle;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Speed ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Vitesse de lecture',
                    style: TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _speeds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = _speeds[i];
                    final selected = s == _speed;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _speed = s);
                        widget.onSpeedChanged(s);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).primaryColor
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(10),
                          border: selected
                              ? null
                              : Border.all(color: divColor, width: 0.8),
                        ),
                        child: Text(
                          s == s.roundToDouble()
                              ? '${s.toInt()}x'
                              : '${s}x',
                          style: TextStyle(
                            color: selected ? Colors.white : grey,
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Divider(color: divColor, height: 1),

              // ── Audio tracks ─────────────────────────────────────────────────
              if (audioTracks.length > 1) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Piste audio',
                      style: TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                ...audioTracks.map((t) {
                  final isSelected = t.id == curAudio.id;
                  final label = t.title?.isNotEmpty == true
                      ? t.title!
                      : (t.language?.isNotEmpty == true ? t.language! : 'Piste ${t.id}');
                  return ListTile(
                    dense: true,
                    title: Text(label, style: const TextStyle(color: white, fontSize: 14)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).primaryColor, size: 20)
                        : null,
                    onTap: () {
                      widget.player.setAudioTrack(t);
                      Navigator.pop(context);
                    },
                  );
                }),
                Divider(color: divColor, height: 1),
              ],

              // ── Subtitle tracks ──────────────────────────────────────────────
              if (subTracks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Sous-titres',
                      style: TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                // "Off" option
                ListTile(
                  dense: true,
                  title: const Text('Désactivés', style: TextStyle(color: white, fontSize: 14)),
                  trailing: curSub.id == 'no'
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).primaryColor, size: 20)
                      : null,
                  onTap: () {
                    widget.player.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.pop(context);
                  },
                ),
                ...subTracks.where((t) => t.id != 'no').map((t) {
                  final isSelected = t.id == curSub.id;
                  final label = t.title?.isNotEmpty == true
                      ? t.title!
                      : (t.language?.isNotEmpty == true ? t.language! : 'Sous-titre ${t.id}');
                  return ListTile(
                    dense: true,
                    title: Text(label, style: const TextStyle(color: white, fontSize: 14)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).primaryColor, size: 20)
                        : null,
                    onTap: () {
                      widget.player.setSubtitleTrack(t);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ],
          ),
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

      _durSub = widget.player.stream.duration.listen((dur) {
        if (dur > Duration.zero && _firstDuration && mounted) {
          _firstDuration = false;
          if (_anim == 'loading') setState(() => _anim = null);
        }
      });

      _bufSub = widget.player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        if (widget.seekingNotifier.value) return;
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
  