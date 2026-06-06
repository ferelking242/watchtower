// Native (Android / iOS / desktop) inline video player — MovieBox-style UI
//
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/widgets/watchtower_loader.dart';

// ─── Public API ────────────────────────────────────────────────────────────────

class WatchInlinePlayer {
  late final Player _player;
  late final VideoController _controller;
  final ValueNotifier<bool> _seekingNotifier = ValueNotifier(false);

  String title = '';
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

  // Banner overlay for portrait inline view
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
        // Bottom gradient
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xEE000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        // Loading / buffering overlay
        Positioned.fill(
          child: _PlayerStateOverlay(
            player: _player,
            seekingNotifier: _seekingNotifier,
          ),
        ),
        // Inline controls bar — MovieBox layout: [▶ | ─●─ time | PiP | ⛶]
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _InlineControls(
            player: _player,
            controller: _controller,
            accent: accent,
            title: title,
            seekingNotifier: _seekingNotifier,
          ),
        ),
      ],
    );
  }

  // Fullscreen video + controls (used when device auto-rotates to landscape)
  // The back button is provided by watch_detail_view._buildLandscape above this widget.
  Widget buildFullscreenPlayer() {
    return Stack(
      children: [
        SizedBox.expand(
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          ),
        ),
        Positioned.fill(
          child: _FullscreenControlsOverlay(
            player: _player,
            controller: _controller,
            title: title,
            showBackButton: false,
          ),
        ),
      ],
    );
  }
}

// ─── Fullscreen page (pushed via fullscreen button tap) ────────────────────────

class _FullscreenPlayerPage extends StatefulWidget {
  final VideoController controller;
  final Player player;
  final String title;

  const _FullscreenPlayerPage({
    required this.controller,
    required this.player,
    required this.title,
  });

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
      body: Stack(
        children: [
          SizedBox.expand(
            child: Video(
              controller: widget.controller,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
          ),
          Positioned.fill(
            child: _FullscreenControlsOverlay(
              player: widget.player,
              controller: widget.controller,
              title: widget.title,
              showBackButton: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fullscreen controls overlay (MovieBox style) ─────────────────────────────

class _FullscreenControlsOverlay extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final bool showBackButton;

  const _FullscreenControlsOverlay({
    required this.player,
    required this.controller,
    required this.title,
    required this.showBackButton,
  });

  @override
  State<_FullscreenControlsOverlay> createState() =>
      _FullscreenControlsOverlayState();
}

class _FullscreenControlsOverlayState
    extends State<_FullscreenControlsOverlay> {
  bool _showControls = true;
  bool _locked = false;
  bool _showSettings = false;
  double _speed = 1.0;
  BoxFit _fit = BoxFit.contain;
  Timer? _hideTimer;

  // ── Speed / Quality inline pickers ────────────────────────────────────────
  bool _showSpeedPicker   = false;
  bool _showQualityPicker = false;

  // ── Brightness / Volume swipe ─────────────────────────────────────────────
  double _brightness       = 0.5;
  double _volume           = 0.5;
  bool _showBrightnessHUD  = false;
  bool _showVolumeHUD      = false;
  Offset? _dragStartPos;
  Timer? _hudTimer;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
    _initMedia();
  }

  Future<void> _initMedia() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
    try {
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    if (_showSettings) {
      setState(() => _showSettings = false);
      _resetHideTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
    else _hideTimer?.cancel();
  }

  void _seek(int deltaSeconds) {
    final pos = widget.player.state.position;
    final dur = widget.player.state.duration;
    final next = pos + Duration(seconds: deltaSeconds);
    widget.player.seek(next.isNegative ? Duration.zero : (next > dur ? dur : next));
    _resetHideTimer();
  }

  void _toggleFit() {
    setState(() =>
        _fit = _fit == BoxFit.contain ? BoxFit.fill : BoxFit.contain);
    _resetHideTimer();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSpeedSheet() {
    _hideTimer?.cancel();
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSt) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E8E93),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vitesse de lecture',
                      style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: speeds.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final s = speeds[i];
                      final sel = s == _speed;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _speed = s);
                          setSt(() {});
                          widget.player.setRate(s);
                          Navigator.pop(ctx);
                          _resetHideTimer();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? Theme.of(context).primaryColor
                                : const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(10),
                            border: sel
                                ? null
                                : Border.all(
                                    color: const Color(0xFF3A3A3C),
                                    width: 0.8),
                          ),
                          child: Text(
                            s == s.roundToDouble()
                                ? '${s.toInt()}x'
                                : '${s}x',
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF8E8E93),
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => _resetHideTimer());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onVerticalDragStart: (d) {
        _dragStartPos = d.globalPosition;
        _hideTimer?.cancel();
      },
      onVerticalDragUpdate: (d) => _handleSwipeDrag(d, size),
      onVerticalDragEnd: (_) {
        _dragStartPos = null;
        if (!_showBrightnessHUD && !_showVolumeHUD) _resetHideTimer();
      },
      child: Stack(
        children: [
          // Buffering indicator
          IgnorePointer(
            child: Center(
              child: StreamBuilder<bool>(
                stream: widget.player.stream.buffering,
                initialData: widget.player.state.buffering,
                builder: (_, snap) => AnimatedOpacity(
                  opacity: snap.data == true ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const JumpingDotsLoader(),
                ),
              ),
            ),
          ),

          // Main controls overlay (auto-hides)
          if (_showControls && !_locked)
            _buildControlsOverlay(),

          // Lock icon
          if (_locked)
            Positioned(
              left: 20, top: 0, bottom: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Center(child: _buildLockButton()),
              ),
            ),

          if (_showControls && !_locked)
            Positioned(
              left: 20, top: 0, bottom: 0,
              child: Center(child: _buildLockButton()),
            ),

          // Settings panel — rounded, animated from corner
          if (_showSettings)
            Positioned.fill(
              child: _SettingsPanel(
                player: widget.player,
                accent: Theme.of(context).primaryColor,
                onClose: () {
                  setState(() => _showSettings = false);
                  _resetHideTimer();
                },
              ),
            ),

          // Brightness HUD
          if (_showBrightnessHUD)
            IgnorePointer(
              child: Center(
                child: _buildGestureHUD(
                  icon: Icons.brightness_6_rounded,
                  value: _brightness,
                ),
              ),
            ),

          // Volume HUD
          if (_showVolumeHUD)
            IgnorePointer(
              child: Center(
                child: _buildGestureHUD(
                  icon: _volume <= 0
                      ? Icons.volume_off_rounded
                      : _volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  value: _volume,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleSwipeDrag(DragUpdateDetails d, Size size) {
    final startX = _dragStartPos?.dx ?? d.globalPosition.dx;
    final dy     = d.delta.dy;
    final isLeft = startX < size.width / 2;

    if (isLeft) {
      // ── Brightness ──────────────────────────────────────────────────────
      final next = (_brightness - dy / size.height * 2.5).clamp(0.0, 1.0);
      _brightness = next;
      try { ScreenBrightness().setScreenBrightness(next); } catch (_) {}
      _hudTimer?.cancel();
      setState(() { _showBrightnessHUD = true; _showVolumeHUD = false; });
      _hudTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showBrightnessHUD = false);
      });
    } else {
      // ── Volume ───────────────────────────────────────────────────────────
      final next = (_volume - dy / size.height * 2.5).clamp(0.0, 1.0);
      _volume = next;
      try { VolumeController.instance.setVolume(next); } catch (_) {}
      widget.player.setVolume(next * 100);
      _hudTimer?.cancel();
      setState(() { _showVolumeHUD = true; _showBrightnessHUD = false; });
      _hudTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showVolumeHUD = false);
      });
    }
  }

  Widget _buildGestureHUD({required IconData icon, required double value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          SizedBox(
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final safeArea = MediaQuery.of(context).padding;
    return Stack(
      children: [
        Container(
          color: const Color(0x55000000),
          padding: EdgeInsets.only(
            left: safeArea.left,
            right: safeArea.right,
            top: safeArea.top,
            bottom: safeArea.bottom,
          ),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildCenterRow()),
              _buildBottomSection(),
            ],
          ),
        ),
        // Speed picker — expands upward from bottom-right
        if (_showSpeedPicker)
          Positioned(
            bottom: safeArea.bottom + 52,
            right: safeArea.right + 50,
            child: _buildSpeedPickerOverlay(),
          ),
        // Quality picker — expands upward from bottom-right
        if (_showQualityPicker)
          Positioned(
            bottom: safeArea.bottom + 52,
            right: safeArea.right + 130,
            child: _buildQualityPickerOverlay(),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.all(8),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.white70, size: 20),
            onPressed: () {},
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white, size: 20),
            onPressed: () {
              _hideTimer?.cancel();
              setState(() => _showSettings = true);
            },
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Lock button placeholder — actual button rendered outside via Positioned
        const SizedBox(width: 80),
        const Spacer(),
        // Center controls: ↺10 | play/pause | ↻10
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _seek(-10),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.replay_10, color: Colors.white, size: 46),
              ),
            ),
            const SizedBox(width: 24),
            StreamBuilder<bool>(
              stream: widget.player.stream.playing,
              initialData: widget.player.state.playing,
              builder: (_, snap) => GestureDetector(
                onTap: () {
                  widget.player.playOrPause();
                  _resetHideTimer();
                },
                child: Icon(
                  (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => _seek(10),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.forward_10, color: Colors.white, size: 46),
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 80),
      ],
    );
  }

  Widget _buildLockButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _locked = !_locked;
          _showControls = true;
        });
        if (!_locked) {
          _resetHideTimer();
        } else {
          // When locking: briefly show then auto-hide
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showControls = false);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              _locked ? 'Verrouillé' : 'Verrouiller',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSeekRow(),
        const SizedBox(height: 2),
        _buildToolbar(),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildSeekRow() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (_, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        final dur = widget.player.state.duration;
        final progress = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _fmt(pos),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    if (dur.inMilliseconds > 0) {
                      widget.player.seek(Duration(
                          milliseconds:
                              (v * dur.inMilliseconds).round()));
                    }
                    _resetHideTimer();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _fmt(dur),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    final speedLabel = _speed == _speed.roundToDouble()
        ? '${_speed.toInt()}x'
        : '${_speed}x';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Play/Pause
          StreamBuilder<bool>(
            stream: widget.player.stream.playing,
            initialData: widget.player.state.playing,
            builder: (_, snap) => IconButton(
              icon: Icon(
                (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                widget.player.playOrPause();
                _resetHideTimer();
              },
              padding: const EdgeInsets.all(4),
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          // Next
          IconButton(
            icon: const Icon(Icons.skip_next,
                color: Colors.white70, size: 22),
            onPressed: () {},
            padding: const EdgeInsets.all(4),
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const Spacer(),
          // Ajuster (fit)
          _ToolbarChip(
            icon: Icons.fit_screen_outlined,
            label: _fit == BoxFit.contain ? 'Ajuster' : 'Remplir',
            onTap: _toggleFit,
          ),
          const SizedBox(width: 8),
          // Langue (audio / subtitle)
          _ToolbarChip(
            icon: Icons.subtitles_outlined,
            label: 'Langue',
            onTap: () {
              _hideTimer?.cancel();
              setState(() {
                _showSettings    = true;
                _showSpeedPicker   = false;
                _showQualityPicker = false;
              });
            },
          ),
          const SizedBox(width: 8),
          // Quality picker chip
          _ToolbarChip(
            icon: Icons.hd_outlined,
            label: 'Qualité',
            active: _showQualityPicker,
            onTap: () {
              _hideTimer?.cancel();
              setState(() {
                _showQualityPicker = !_showQualityPicker;
                _showSpeedPicker   = false;
              });
            },
          ),
          const SizedBox(width: 8),
          // Speed chip — vertical picker
          _ToolbarChip(
            label: speedLabel,
            active: _showSpeedPicker,
            onTap: () {
              _hideTimer?.cancel();
              setState(() {
                _showSpeedPicker   = !_showSpeedPicker;
                _showQualityPicker = false;
              });
            },
          ),
          const SizedBox(width: 8),
          // Fullscreen exit
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.fullscreen_exit,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.all(4),
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  // ─── Speed picker — vertical list expanding upward ─────────────────────────
  Widget _buildSpeedPickerOverlay() {
    const speeds = [2.0, 1.75, 1.5, 1.25, 1.0, 0.75, 0.5, 0.25];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12, width: 0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                'Vitesse',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            ...speeds.map((s) {
              final sel = s == _speed;
              final label = s == s.roundToDouble()
                  ? '${s.toInt()}x'
                  : '${s}x';
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _speed           = s;
                    _showSpeedPicker = false;
                  });
                  widget.player.setRate(s);
                  _resetHideTimer();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                  color: sel
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                sel ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (sel) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_rounded,
                            color: Theme.of(context).primaryColor,
                            size: 14),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ─── Quality picker — vertical list expanding upward ───────────────────────
  Widget _buildQualityPickerOverlay() {
    // Standard quality tiers ordered top→bottom (highest at top)
    const allQualities = ['4K', '1440p', '1080p', '720p', '480p', '360p'];
    // Detect available qualities from video tracks
    final videoTracks = widget.player.state.tracks.video;
    final Set<String> available = {};
    for (final t in videoTracks) {
      final h = t.h ?? 0;
      if (h >= 2160)      available.add('4K');
      else if (h >= 1440) available.add('1440p');
      else if (h >= 1080) available.add('1080p');
      else if (h >= 720)  available.add('720p');
      else if (h >= 480)  available.add('480p');
      else if (h > 0)     available.add('360p');
    }
    // If no track info, treat all as available
    final effectiveAvail =
        available.isEmpty ? allQualities.toSet() : available;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12, width: 0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                'Qualité',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            ...allQualities.map((q) {
              final isAvail = effectiveAvail.contains(q);
              return GestureDetector(
                onTap: isAvail
                    ? () {
                        // Select matching video track
                        if (videoTracks.isNotEmpty) {
                          final target = videoTracks.cast<VideoTrack?>().firstWhere(
                            (t) {
                              final h = t?.h ?? 0;
                              if (q == '4K')    return h >= 2160;
                              if (q == '1440p') return h >= 1440;
                              if (q == '1080p') return h >= 1080;
                              if (q == '720p')  return h >= 720;
                              if (q == '480p')  return h >= 480;
                              return h > 0;
                            },
                            orElse: () => null,
                          );
                          if (target != null) {
                            widget.player.setVideoTrack(target);
                          }
                        }
                        setState(() => _showQualityPicker = false);
                        _resetHideTimer();
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          q,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isAvail
                                ? Colors.white
                                : Colors.white30,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!isAvail) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'N/D',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Toolbar chip button ───────────────────────────────────────────────────────

class _ToolbarChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarChip({
    required this.label,
    this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.20)
              : const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.65) : Colors.white12,
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: active ? accent : Colors.white60, size: 12),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? accent : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings panel — slides from right (Audio + Sous-titre side by side) ─────

class _SettingsPanel extends StatefulWidget {
  final Player player;
  final Color accent;
  final VoidCallback onClose;

  const _SettingsPanel({
    required this.player,
    required this.accent,
    required this.onClose,
  });

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  bool _bilingual = false;

  @override
  Widget build(BuildContext context) {
    final audioTracks = widget.player.state.tracks.audio;
    final subTracks = widget.player.state.tracks.subtitle;
    final curAudio = widget.player.state.track.audio;
    final curSub = widget.player.state.track.subtitle;

    final screenH = MediaQuery.of(context).size.height;
    final safeArea = MediaQuery.of(context).padding;
    final panelW   = MediaQuery.of(context).size.width * 0.52;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.topRight,
        padding: EdgeInsets.only(
          top: safeArea.top + 48,
          right: safeArea.right + 8,
          bottom: safeArea.bottom + 56,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (_, offset, child) => Transform.translate(
              offset: Offset(offset.dx * panelW, offset.dy * screenH),
              child: child,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: panelW,
                constraints: BoxConstraints(
                  maxHeight: screenH * 0.70,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12, width: 0.7),
                ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header: Audio | Sous-titre + toggle
                  Container(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.white24, width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                              'Audio',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                            width: 0.8,
                            height: 20,
                            color: Colors.white24),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Text(
                                  'Sous-titre',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    value: curSub.id != 'no' &&
                                        curSub.id != '-1',
                                    onChanged: (v) {
                                      if (!v) {
                                        widget.player
                                            .setSubtitleTrack(
                                                SubtitleTrack.no());
                                      } else {
                                        final t = subTracks.firstWhere(
                                          (t) =>
                                              t.id != 'no' &&
                                              t.id != '-1',
                                          orElse: () => subTracks.first,
                                        );
                                        widget.player.setSubtitleTrack(t);
                                      }
                                      setState(() {});
                                    },
                                    activeColor: widget.accent,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content: two columns
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Audio column
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              if (audioTracks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Aucune piste',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                )
                              else
                                ...audioTracks.map((t) {
                                  final sel = t.id == curAudio.id;
                                  final label =
                                      t.title?.isNotEmpty == true
                                          ? t.title!
                                          : (t.language?.isNotEmpty == true
                                              ? t.language!
                                              : 'Piste ${t.id}');
                                  return _TrackTile(
                                    label: label,
                                    selected: sel,
                                    accent: widget.accent,
                                    onTap: () {
                                      widget.player.setAudioTrack(t);
                                      setState(() {});
                                    },
                                  );
                                }),
                            ],
                          ),
                        ),
                        Container(
                            width: 0.8,
                            color: Colors.white12),

                        // Subtitle column
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              // Bilingue toggle
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 4, 4),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Bilingue',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: _bilingual,
                                        onChanged: (v) =>
                                            setState(() =>
                                                _bilingual = v),
                                        activeColor: widget.accent,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                  height: 0.6, color: Colors.white12),
                              if (subTracks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Aucun sous-titre',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                )
                              else ...[
                                _TrackTile(
                                  label: 'Désactiver',
                                  selected: curSub.id == 'no' ||
                                      curSub.id == '-1',
                                  accent: widget.accent,
                                  onTap: () {
                                    widget.player.setSubtitleTrack(
                                        SubtitleTrack.no());
                                    setState(() {});
                                  },
                                ),
                                ...subTracks
                                    .where((t) =>
                                        t.id != 'no' && t.id != '-1')
                                    .map((t) {
                                  final sel = t.id == curSub.id;
                                  final label =
                                      t.title?.isNotEmpty == true
                                          ? t.title!
                                          : (t.language?.isNotEmpty ==
                                                  true
                                              ? t.language!
                                              : 'Sub ${t.id}');
                                  return _TrackTile(
                                    label: label,
                                    selected: sel,
                                    accent: widget.accent,
                                    onTap: () {
                                      widget.player.setSubtitleTrack(t);
                                      setState(() {});
                                    },
                                  );
                                }),
                              ],
                              Container(
                                  height: 0.6, color: Colors.white12),
                              InkWell(
                                onTap: () {},
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Télécharger',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: Colors.white54, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _TrackTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _TrackTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? accent : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: accent, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Inline controls (portrait banner) — MovieBox layout ─────────────────────
// Layout: [▶ | ─────●───── time | PiP | ⛶]

class _InlineControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final Color accent;
  final String title;
  final ValueNotifier<bool> seekingNotifier;

  const _InlineControls({
    required this.player,
    required this.controller,
    required this.accent,
    required this.title,
    required this.seekingNotifier,
  });

  @override
  State<_InlineControls> createState() => _InlineControlsState();
}

class _InlineControlsState extends State<_InlineControls> {
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
          MaterialPageRoute(
            builder: (_) => _FullscreenPlayerPage(
              controller: _c,
              player: _p,
              title: widget.title,
            ),
          ),
        );
      }
    }
  }

  void _openFullscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenPlayerPage(
          controller: _c,
          player: _p,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Play / Pause ─────────────────────────────────────────────────
          StreamBuilder<bool>(
            stream: _p.stream.playing,
            initialData: _p.state.playing,
            builder: (_, snap) => GestureDetector(
              onTap: _p.playOrPause,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 6),
                child: Icon(
                  (snap.data ?? false)
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),

          // ── Seek bar (Expanded) ──────────────────────────────────────────
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _p.stream.position,
              initialData: _p.state.position,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = _p.state.duration;
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0;
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 11),
                    activeTrackColor: widget.accent,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: progress,
                    onChangeStart: (_) =>
                        widget.seekingNotifier.value = true,
                    onChanged: (v) {
                      if (dur.inMilliseconds > 0) {
                        _p.seek(Duration(
                            milliseconds:
                                (v * dur.inMilliseconds).round()));
                      }
                    },
                    onChangeEnd: (_) =>
                        widget.seekingNotifier.value = false,
                  ),
                );
              },
            ),
          ),

          // ── Time label: pos / dur ────────────────────────────────────────
          StreamBuilder<Duration>(
            stream: _p.stream.position,
            initialData: _p.state.position,
            builder: (_, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = _p.state.duration;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${_fmt(pos)}/${_fmt(dur)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),

          // ── PiP ─────────────────────────────────────────────────────────
          GestureDetector(
            onTap: _enterPiP,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Icon(
                Icons.picture_in_picture_alt_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // ── Fullscreen ───────────────────────────────────────────────────
          GestureDetector(
            onTap: _openFullscreen,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

// ─── Player state overlay (loading/buffering anim for inline banner) ──────────

class _PlayerStateOverlay extends StatefulWidget {
  final Player player;
  final ValueNotifier<bool> seekingNotifier;

  const _PlayerStateOverlay({
    required this.player,
    required this.seekingNotifier,
  });

  @override
  State<_PlayerStateOverlay> createState() => _PlayerStateOverlayState();
}

class _PlayerStateOverlayState extends State<_PlayerStateOverlay> {
  String? _anim;
  bool _firstDuration = true;
  bool _successShown = false;

  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _bufSub;

  @override
  void initState() {
    super.initState();
    _anim = 'loading';
    _durSub = widget.player.stream.duration.listen((dur) {
      if (!mounted) return;
      if (_firstDuration && dur > Duration.zero) {
        _firstDuration = false;
        setState(() => _anim = 'success');
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _anim = null);
          _successShown = true;
        });
      }
    });
    _bufSub = widget.player.stream.buffering.listen((buf) {
      if (!mounted) return;
      if (_successShown) {
        setState(() => _anim = buf ? 'loading' : null);
      }
    });
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _bufSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_anim == null) return const SizedBox.shrink();
    if (_anim == 'loading') {
      return Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.seekingNotifier,
          builder: (_, seeking, __) => seeking
              ? const SizedBox.shrink()
              : const WatchtowerLoader(animation: 'loading'),
        ),
      );
    }
    if (_anim == 'success') {
      return Center(
        child: Icon(
          Icons.check_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 40,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
