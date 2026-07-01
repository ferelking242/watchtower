// Native (Android / iOS / desktop) inline video player — MovieBox-style UI
//
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/video.dart' as wt;
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/widgets/watchtower_loader.dart';
import 'package:watchtower/utils/log/logger.dart';

// ─── Speed levels ─────────────────────────────────────────────────────────────
const _kAllSpeeds = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0];

// ─── Public API ────────────────────────────────────────────────────────────────

class WatchInlinePlayer {
  late final Player _player;
  late final VideoController _controller;
  final ValueNotifier<bool> _seekingNotifier = ValueNotifier(false);

  String title = '';
  bool hasVideoUrl = false;
  bool loadFailed = false;
  int? loadedChapterId;
  List<wt.Video> loadedVideos = [];
  String? selectedQuality;

  WatchInlinePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  void dispose() {
    _player.dispose();
    _seekingNotifier.dispose();
  }

  /// Callback fired when quality changes (so the page UI can rebuild).
  VoidCallback? onQualityChanged;

  /// Switch to a different quality, preserving current playback position.
  Future<void> switchQuality(wt.Video targetVideo) async {
    final savedPos = _player.state.position;
    selectedQuality = targetVideo.quality;
    final ua      = targetVideo.headers?['User-Agent'] ?? targetVideo.headers?['user-agent'] ?? '';
    final referer = targetVideo.headers?['Referer']    ?? targetVideo.headers?['referer']    ?? '';
    try {
      final plat = _player.platform as dynamic;
      if (ua.isNotEmpty)      await plat.setProperty('user-agent', ua);
      if (referer.isNotEmpty) await plat.setProperty('referrer', referer);
    } catch (_) {}
    await _player.open(Media(targetVideo.url, httpHeaders: targetVideo.headers), play: true);
    // Restore position after the new stream is ready
    if (savedPos > Duration.zero) {
      try {
        await _player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 12), onTimeout: () => Duration.zero);
        await _player.seek(savedPos);
      } catch (_) {}
    }
    onQualityChanged?.call();
  }

  void reset() {
    hasVideoUrl = false;
    loadFailed = false;
  }

  Future<void> load({
    required WidgetRef ref,
    required Chapter chapter,
  }) async {
    loadFailed = false;
    hasVideoUrl = false;
    final epName = chapter.name ?? 'ep#${chapter.id}';
    final epUrl  = chapter.url  ?? '';
    AppLogger.log(
      '[PLAYER] load START  ep="$epName"  url=$epUrl',
      logLevel: LogLevel.info,
      tag: LogTag.watch,
    );
    try {
      final data =
          await ref.read(getVideoListProvider(episode: chapter).future);
      final (videos, _, __, ___) = data;
      loadedVideos = videos;

      if (videos.isEmpty) {
        loadFailed = true;
        AppLogger.log(
          '[PLAYER] FAILED — 0 vidéos pour ep="$epName"  url=$epUrl'
          '  ← getVideoList a retourné 0 URLs',
          logLevel: LogLevel.error,
          tag: LogTag.watch,
        );
        return;
      }

      for (var i = 0; i < videos.length; i++) {
        final v    = videos[i];
        final vUrl = v.url.length > 120 ? '${v.url.substring(0, 120)}…' : v.url;
        AppLogger.log(
          '[PLAYER] essai [${i+1}/${videos.length}]  qualité="${v.quality}"  url=$vUrl',
          logLevel: LogLevel.info,
          tag: LogTag.watch,
        );

        // Completer: blocks until the video plays OR errors OR watchdog fires
        final completer = Completer<bool>(); // true=success false=fail
        StreamSubscription<Duration>? durSub;
        StreamSubscription<String>?   errSub;

        final watchdog = Timer(const Duration(seconds: 30), () {
          if (completer.isCompleted) return;
          durSub?.cancel();
          errSub?.cancel();
          AppLogger.log(
            '[PLAYER] WATCHDOG 30s  qualité="${v.quality}"  url=$vUrl'
            '  ← Causes: codec, DRM, URL expirée, serveur silencieux',
            logLevel: LogLevel.error,
            tag: LogTag.watch,
          );
          completer.complete(false);
        });

        durSub = _player.stream.duration.listen((dur) {
          if (completer.isCompleted || dur <= Duration.zero) return;
          watchdog.cancel();
          errSub?.cancel();
          hasVideoUrl = true;
          selectedQuality = v.quality;
          AppLogger.log(
            '[PLAYER] EN LECTURE ✓  qualité="${v.quality}"  durée=${dur.inSeconds}s  ep="$epName"',
            logLevel: LogLevel.info,
            tag: LogTag.watch,
          );
          completer.complete(true);
        });

        errSub = _player.stream.error.listen((err) {
          if (completer.isCompleted) return;
          watchdog.cancel();
          durSub?.cancel();
          AppLogger.log(
            '[PLAYER] ERREUR qualité="${v.quality}": $err',
            logLevel: LogLevel.error,
            tag: LogTag.watch,
          );
          completer.complete(false);
        });

        // ── MPV headers + Dart HTTP probe (captures real CDN status code) ────────
            final _ua      = v.headers?['User-Agent'] ?? v.headers?['user-agent'] ?? '';
            final _referer = v.headers?['Referer']    ?? v.headers?['referer']    ?? '';

            // Dart HttpClient probe: log real HTTP status BEFORE libmpv tries
            try {
              final _cli = HttpClient();
              _cli.connectionTimeout = const Duration(seconds: 8);
              final _req = await _cli.headUrl(Uri.parse(v.url));
              if (_ua.isNotEmpty)      _req.headers.set('User-Agent', _ua);
              if (_referer.isNotEmpty) _req.headers.set('Referer', _referer);
              _req.headers.set('Accept', '*/*');
              final _resp = await _req.close();
              AppLogger.log(
                '[PLAYER] HTTP probe  status=${_resp.statusCode}'
                '  url=${v.url.substring(0, v.url.length.clamp(0, 80))}…',
                logLevel: _resp.statusCode == 200 || _resp.statusCode == 206
                    ? LogLevel.info : LogLevel.error,
                tag: LogTag.watch,
              );
              _cli.close(force: true);
            } catch (_probeErr) {
              AppLogger.log('[PLAYER] HTTP probe exc: $_probeErr',
                  logLevel: LogLevel.warning, tag: LogTag.watch);
            }

            // Set MPV props: 'referrer' (dedicated mpv property, more reliable than http-header-fields)
            if (v.headers != null && v.headers!.isNotEmpty) {
              try {
                final _plat = _player.platform as dynamic;
                if (_ua.isNotEmpty)      await _plat.setProperty('user-agent', _ua);
                if (_referer.isNotEmpty) await _plat.setProperty('referrer', _referer);
                AppLogger.log(
                  '[PLAYER] MPV headers  ua="${_ua.isEmpty ? "default" : _ua.substring(0, _ua.length.clamp(0, 40))}"'
                  '  referer="${_referer.isEmpty ? "none" : _referer}"',
                  logLevel: LogLevel.debug, tag: LogTag.watch,
                );
              } catch (_setErr) {
                AppLogger.log('[PLAYER] setProperty indispo: $_setErr',
                    logLevel: LogLevel.warning, tag: LogTag.watch);
              }
            }
                      await _player.open(Media(v.url, httpHeaders: v.headers), play: true);
        final success = await completer.future;
        if (success) return;

        if (i < videos.length - 1) {
          AppLogger.log(
            '[PLAYER] qualité="${v.quality}" échouée → essai qualité "${videos[i+1].quality}"',
            logLevel: LogLevel.warning,
            tag: LogTag.watch,
          );
        }
      }

      // All qualities failed
      loadFailed = true;
      AppLogger.log(
        '[PLAYER] FAILED — toutes les qualités ont échoué (${videos.length} tentatives)  ep="$epName"',
        logLevel: LogLevel.error,
        tag: LogTag.watch,
      );

    } catch (e, st) {
      loadFailed = true;
      AppLogger.log(
        '[PLAYER] EXCEPTION: $e',
        logLevel: LogLevel.error,
        tag: LogTag.watch,
        error: e,
        stackTrace: st,
      );
    }
  }

  // Banner overlay for portrait inline view
  Widget buildBannerOverlay({required BuildContext context}) {
    if (!hasVideoUrl) return const SizedBox.shrink();
    final accent = Theme.of(context).primaryColor;
    return _PortraitPlayerOverlay(
      player: _player,
      controller: _controller,
      accent: accent,
      title: title,
      seekingNotifier: _seekingNotifier,
      loadedVideos: loadedVideos,
      onSwitchQuality: switchQuality,
      selectedQuality: selectedQuality,
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
            loadedVideos: loadedVideos,
            onSwitchQuality: switchQuality,
            selectedQuality: selectedQuality,
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
  final List<wt.Video> loadedVideos;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final String? selectedQuality;

  const _FullscreenPlayerPage({
    required this.controller,
    required this.player,
    required this.title,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
  });

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
  final _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);

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
    _fitNotifier.dispose();
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
            child: ValueListenableBuilder<BoxFit>(
              valueListenable: _fitNotifier,
              builder: (_, fit, __) => Video(
                controller: widget.controller,
                fit: fit,
                controls: NoVideoControls,
              ),
            ),
          ),
          Positioned.fill(
            child: _FullscreenControlsOverlay(
              player: widget.player,
              controller: widget.controller,
              title: widget.title,
              showBackButton: true,
              fitNotifier: _fitNotifier,
              loadedVideos: widget.loadedVideos,
              onSwitchQuality: widget.onSwitchQuality,
              selectedQuality: widget.selectedQuality,
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
  final List<wt.Video> loadedVideos;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final String? selectedQuality;
  final ValueNotifier<BoxFit>? fitNotifier;

  const _FullscreenControlsOverlay({
    required this.player,
    required this.controller,
    required this.title,
    required this.showBackButton,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
    this.fitNotifier,
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

    // ── Hold-right speed boost + horizontal speed swipe ──────────────────────
    bool _holdSpeedActive       = false;
    double _preHoldSpeed        = 1.0;
    double _holdBoostSpeed      = 2.0;
    double? _horizDragStartX;
    double _horizDragStartSpeed = 1.0;
    bool _showSpeedBoostHUD     = false;

    // ── Seek + mute + orientation + audio-only ────────────────────────────────
    int _seekSeconds = 15;
    bool _muted = false;
    bool _landscapeIsLeft = true;
    bool _audioOnly = false;
    bool _showSubPanel = false;

    // ── Double-tap escalation (skip zones) ────────────────────────────────────
    int _doubleTapCount = 0;
    bool? _doubleTapRight;
    Timer? _doubleTapResetTimer;
    bool _showLeftSkipHUD  = false;
    bool _showRightSkipHUD = false;
    int _skipHudSeconds = 10;
    Timer? _skipHudTimer;

    // ── Current quality (synced with loadedVideos) ────────────────────────────
    String? _currentQuality;

    // ── Seekbar drag state (smooth preview without seeking on every frame) ─────
    bool _seekDragging = false;
    double _seekDragValue = 0.0;

    // ── Horizontal swipe → seek ───────────────────────────────────────────────
    Duration _horizSeekStartPos = Duration.zero;
    int _horizSeekDelta = 0;
    bool _showSeekSwipeHUD = false;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
    _initMedia();
    // Sync current quality from the passed-in selectedQuality or first video
    _currentQuality = widget.selectedQuality ??
        (widget.loadedVideos.isNotEmpty ? widget.loadedVideos.first.quality : null);
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
    _doubleTapResetTimer?.cancel();
    _skipHudTimer?.cancel();
    super.dispose();
  }

  // ── Double-tap seek with escalating amounts ──────────────────────────────────
  void _handleDoubleTap({required bool isRight}) {
    _doubleTapResetTimer?.cancel();

    // Reset count if side changed
    if (_doubleTapRight != null && _doubleTapRight != isRight) {
      _doubleTapCount = 0;
    }
    _doubleTapRight = isRight;
    _doubleTapCount++;

    final seconds = 15 * (1 << (_doubleTapCount - 1)); // 15, 30, 60, 120, 240...
    _skipHudSeconds = seconds;
    _seek(isRight ? seconds : -seconds);

    // Show HUD
    _skipHudTimer?.cancel();
    setState(() {
      _showLeftSkipHUD  = !isRight;
      _showRightSkipHUD = isRight;
    });
    _skipHudTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _showLeftSkipHUD = false; _showRightSkipHUD = false; });
    });

    // Reset escalation counter after 800ms of inactivity
    _doubleTapResetTimer = Timer(const Duration(milliseconds: 800), () {
      _doubleTapCount = 0;
      _doubleTapRight = null;
    });
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
    widget.fitNotifier?.value = _fit;
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
    final speeds = _kAllSpeeds;
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
        onLongPressStart: (d) {
          if (d.globalPosition.dx > size.width / 2) {
            _preHoldSpeed = _speed;
            _holdBoostSpeed = 2.0;
            _speed = 2.0;
            _holdSpeedActive = true;
            widget.player.setRate(2.0);
            _hideTimer?.cancel();
            setState(() => _showSpeedBoostHUD = true);
          }
        },
        onLongPressMoveUpdate: (d) {
          if (!_holdSpeedActive) return;
          final dx = d.offsetFromOrigin.dx;
          final shift = (dx / 50).round().clamp(-6, 6);
          const base2xIdx = 7;
          final newIdx = (base2xIdx + shift).clamp(0, _kAllSpeeds.length - 1);
          final newSpeed = _kAllSpeeds[newIdx];
          if (newSpeed != _holdBoostSpeed) {
            _holdBoostSpeed = newSpeed;
            _speed = newSpeed;
            widget.player.setRate(newSpeed);
            setState(() {});
          }
        },
        onLongPressEnd: (_) {
          if (_holdSpeedActive) {
            _holdSpeedActive = false;
            _speed = _preHoldSpeed;
            _holdBoostSpeed = 2.0;
            widget.player.setRate(_preHoldSpeed);
            setState(() => _showSpeedBoostHUD = false);
            _resetHideTimer();
          }
        },
        onHorizontalDragStart: (d) {
          if (_holdSpeedActive) return;
          _horizDragStartX = d.globalPosition.dx;
          _horizSeekStartPos = widget.player.state.position;
          _horizSeekDelta = 0;
          _hideTimer?.cancel();
        },
        onHorizontalDragUpdate: (d) {
          if (_horizDragStartX == null || _holdSpeedActive) return;
          final dx = d.globalPosition.dx - _horizDragStartX!;
          final dur = widget.player.state.duration.inSeconds;
          if (dur <= 0) return;
          // ~60s per full screen width
          _horizSeekDelta = (dx / size.width * 90).round();
          setState(() => _showSeekSwipeHUD = true);
        },
        onHorizontalDragEnd: (_) {
          if (_horizDragStartX != null && !_holdSpeedActive && _horizSeekDelta != 0) {
            final dur = widget.player.state.duration;
            final next = _horizSeekStartPos + Duration(seconds: _horizSeekDelta);
            final clamped = next < Duration.zero ? Duration.zero : (next > dur ? dur : next);
            widget.player.seek(clamped);
          }
          _horizDragStartX = null;
          _horizSeekDelta = 0;
          setState(() => _showSeekSwipeHUD = false);
          _resetHideTimer();
        },
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
          // ── Left-third invisible double-tap zone (seek back) ─────────────────
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: size.width * 0.33,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _handleDoubleTap(isRight: false),
              onTap: _onTap,
            ),
          ),
          // ── Right-third invisible double-tap zone (seek forward) ─────────────
          Positioned(
            right: 0, top: 0, bottom: 0,
            width: size.width * 0.33,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _handleDoubleTap(isRight: true),
              onTap: _onTap,
            ),
          ),

          // ── Skip HUD — left ───────────────────────────────────────────────────
          if (_showLeftSkipHUD)
            Positioned(
              left: size.width * 0.04,
              top: 0, bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: _buildSkipHUD(isRight: false, seconds: _skipHudSeconds),
                ),
              ),
            ),
          // ── Skip HUD — right ──────────────────────────────────────────────────
          if (_showRightSkipHUD)
            Positioned(
              right: size.width * 0.04,
              top: 0, bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: _buildSkipHUD(isRight: true, seconds: _skipHudSeconds),
                ),
              ),
            ),

          // ── Audio-only mode overlay ───────────────────────────────────────────
          if (_audioOnly)
            IgnorePointer(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: const Icon(Icons.audiotrack_rounded, color: Colors.white70, size: 44),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<Duration>(
                        stream: widget.player.stream.position,
                        initialData: widget.player.state.position,
                        builder: (_, posSnap) {
                          final pos = posSnap.data ?? Duration.zero;
                          final dur = widget.player.state.duration;
                          return Text(
                            '${_fmt(pos)} / ${_fmt(dur)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

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

          // Lock icon — always visible when locked, icon only (no text)
          if (_locked)
            Positioned(
              left: 20, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _locked = false;
                      _showControls = true;
                    });
                    _resetHideTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),

          // Left controls (unlocked): Lock + Mute
          if (_showControls && !_locked)
            Positioned(
              left: 20, top: 0, bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLockButton(),
                    const SizedBox(height: 12),
                    _buildMuteButton(),
                  ],
                ),
              ),
            ),

          // Right controls (unlocked): Screenshot + Rotate
          if (_showControls && !_locked)
            Positioned(
              right: 20, top: 0, bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconCircle(
                      icon: Icons.camera_alt_outlined,
                      tooltip: 'Capture',
                      onTap: () async {
                        setState(() => _showControls = false);
                        await Future.delayed(const Duration(milliseconds: 150));
                        try {
                          final bytes = await widget.player.screenshot();
                          if (bytes != null) {
                            final dir = await getTemporaryDirectory();
                            final path = '${dir.path}/wt_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await File(path).writeAsBytes(bytes);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Capture sauvegardée'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } catch (_) {}
                        if (mounted) {
                          setState(() => _showControls = true);
                          _resetHideTimer();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildIconCircle(
                      icon: Icons.screen_rotation_outlined,
                      tooltip: 'Rotation',
                      onTap: () {
                        _landscapeIsLeft = !_landscapeIsLeft;
                        SystemChrome.setPreferredOrientations([
                          _landscapeIsLeft
                              ? DeviceOrientation.landscapeLeft
                              : DeviceOrientation.landscapeRight,
                        ]);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Subtitles / audio side panel
          if (_showSubPanel)
            Positioned.fill(
              child: _SettingsPanel(
                player: widget.player,
                accent: Theme.of(context).primaryColor,
                onClose: () {
                  setState(() => _showSubPanel = false);
                  _resetHideTimer();
                },
              ),
            ),

          // Brightness HUD — left side, vertical
            if (_showBrightnessHUD)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _buildSideHUD(
                      icon: Icons.brightness_6_rounded,
                      value: _brightness,
                    ),
                  ),
                ),
              ),

            // Volume HUD — right side, vertical
            if (_showVolumeHUD)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _buildSideHUD(
                      icon: _volume <= 0
                          ? Icons.volume_off_rounded
                          : _volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                      value: _volume,
                    ),
                  ),
                ),
              ),

            // Speed boost HUD — center top
              if (_showSpeedBoostHUD)
                Positioned(
                  top: 40, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _holdBoostSpeed == _holdBoostSpeed.roundToDouble()
                                      ? '${_holdBoostSpeed.toInt()}x'
                                      : '${_holdBoostSpeed}x',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 120,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ((_kAllSpeeds.indexOf(_holdBoostSpeed) + 1) / _kAllSpeeds.length).clamp(0.0, 1.0),
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Seek swipe HUD — center
              if (_showSeekSwipeHUD)
                Positioned(
                  top: 0, bottom: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _buildSeekSwipeHUD(),
                    ),
                  ),
                ),,
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

  // ── Skip HUD (YouTube-style double-tap indicator) ─────────────────────────
  Widget _buildSkipHUD({required bool isRight, required int seconds}) {
    final arrows = (seconds >= 60 ? 3 : seconds >= 30 ? 2 : 1);
    final label = isRight ? '+${seconds}s' : '-${seconds}s';
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(64),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < arrows; i++)
                Icon(
                  isRight ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                  color: Colors.white.withValues(alpha: 0.5 + i * 0.2),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSideHUD({required IconData icon, required double value}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              width: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
    }
  

  Widget _buildSeekSwipeHUD() {
    final pos = _horizSeekStartPos + Duration(seconds: _horizSeekDelta);
    final dur = widget.player.state.duration;
    final clamped = pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos);
    final sign = _horizSeekDelta >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _horizSeekDelta >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            '${sign}${_horizSeekDelta}s',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            _fmt(clamped),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            icon: const Icon(Icons.subtitles_outlined, color: Colors.white70, size: 20),
            onPressed: () {
              _hideTimer?.cancel();
              setState(() {
                _showSubPanel = true;
                _showSpeedPicker = false;
                _showQualityPicker = false;
              });
            },
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              _audioOnly ? Icons.audiotrack_rounded : Icons.audiotrack_outlined,
              color: _audioOnly ? Theme.of(context).primaryColor : Colors.white70,
              size: 20,
            ),
            onPressed: () {
              setState(() => _audioOnly = !_audioOnly);
              if (_audioOnly) {
                widget.player.setVideoTrack(VideoTrack.no());
              } else {
                final tracks = widget.player.state.tracks.video;
                if (tracks.isNotEmpty) widget.player.setVideoTrack(tracks.first);
              }
              _resetHideTimer();
            },
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 22),
            onPressed: () {},
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
            onPressed: () {
              _hideTimer?.cancel();
              _openSettings(0);
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
        const SizedBox(width: 80),
        const Spacer(),
        // Center: play/pause only — seek handled by edge double-tap zones
        StreamBuilder<bool>(
          stream: widget.player.stream.playing,
          initialData: widget.player.state.playing,
          builder: (_, snap) => GestureDetector(
            onTap: () {
              widget.player.playOrPause();
              _resetHideTimer();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0x55000000),
                shape: BoxShape.circle,
              ),
              child: Icon(
                (snap.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
          ),
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
          _locked = true;
          _showControls = false;
        });
        _hideTimer?.cancel();
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
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
                  value: _seekDragging ? _seekDragValue : progress,
                  onChangeStart: (_) {
                    setState(() => _seekDragging = true);
                    _hideTimer?.cancel();
                  },
                  onChanged: (v) => setState(() => _seekDragValue = v),
                  onChangeEnd: (v) {
                    if (dur.inMilliseconds > 0) {
                      widget.player.seek(Duration(
                          milliseconds: (v * dur.inMilliseconds).round()));
                    }
                    setState(() => _seekDragging = false);
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
                _showSpeedPicker   = false;
                _showQualityPicker = false;
              });
              _openSettings(2);
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
    final speeds = _kAllSpeeds.reversed.toList();
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

  // ─── Quality picker — uses loadedVideos from parent ────────────────────────
  Widget _buildQualityPickerOverlay() {
    final videos = widget.loadedVideos;
    // Build ordered list preserving original order in loadedVideos
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
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                'Qualité',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            if (videos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text('Aucune qualité', style: TextStyle(color: Colors.white54, fontSize: 13)),
              )
            else
              ...videos.map((v) {
                final isCurrent = _currentQuality == v.quality;
                return GestureDetector(
                  onTap: () async {
                    _currentQuality = v.quality;
                    setState(() => _showQualityPicker = false);
                    _resetHideTimer();
                    if (widget.onSwitchQuality != null) {
                      await widget.onSwitchQuality!(v);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            v.quality,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isCurrent ? Theme.of(context).primaryColor : Colors.white,
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Icon(Icons.check_rounded, color: Theme.of(context).primaryColor, size: 14),
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

  // ─── Open settings sheet ────────────────────────────────────────────────────
  void _openSettings([int initialTab = 0]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _FullscreenSettingsSheet(
        player: widget.player,
        accent: Theme.of(context).primaryColor,
        initialTab: initialTab,
        seekSeconds: _seekSeconds,
        onSeekSeconds: (s) => setState(() => _seekSeconds = s),
        fit: _fit,
        onFit: (f) { setState(() => _fit = f); widget.fitNotifier?.value = f; },
      ),
    ).then((_) => _resetHideTimer());
  }

  // ─── Mute button ────────────────────────────────────────────────────────────
  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _muted = !_muted);
        widget.player.setVolume(_muted ? 0 : _volume * 100);
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // ─── Circle icon button (right side) ────────────────────────────────────────
  Widget _buildIconCircle({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
              ? accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.65) : Colors.transparent,
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

// ─── Fullscreen settings sheet (PLAYit-style) ─────────────────────────────────

class _FullscreenSettingsSheet extends StatefulWidget {
  final Player player;
  final Color accent;
  final int initialTab;
  final int seekSeconds;
  final ValueChanged<int> onSeekSeconds;
  final BoxFit fit;
  final ValueChanged<BoxFit> onFit;

  const _FullscreenSettingsSheet({
    required this.player,
    required this.accent,
    required this.initialTab,
    required this.seekSeconds,
    required this.onSeekSeconds,
    required this.fit,
    required this.onFit,
  });

  @override
  State<_FullscreenSettingsSheet> createState() => _FullscreenSettingsSheetState();
}

class _FullscreenSettingsSheetState extends State<_FullscreenSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late int _seekSeconds;
  late BoxFit _fit;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _seekSeconds = widget.seekSeconds;
    _fit = widget.fit;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seekOptions = [5, 10, 15, 30, 60];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
            const SizedBox(height: 10),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: widget.accent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF8E8E93),
              tabs: const [
                Tab(text: 'Lecture'),
                Tab(text: 'Audio'),
                Tab(text: 'Sous-titres'),
              ],
            ),
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Lecture tab ──────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      const Text(
                        'INTERVALLE DE NAVIGATION',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: seekOptions.map((s) {
                          final sel = s == _seekSeconds;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _seekSeconds = s);
                              widget.onSeekSeconds(s);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: sel ? widget.accent : const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(10),
                                border: sel ? null : Border.all(color: const Color(0xFF3A3A3C), width: 0.8),
                              ),
                              child: Text(
                                '${s}s',
                                style: TextStyle(
                                  color: sel ? Colors.white : const Color(0xFF8E8E93),
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'AJUSTEMENT VIDÉO',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _FitOption(label: 'Ajuster', fit: BoxFit.contain, currentFit: _fit, accent: widget.accent, onTap: () {
                            setState(() => _fit = BoxFit.contain);
                            widget.onFit(BoxFit.contain);
                          }),
                          const SizedBox(width: 8),
                          _FitOption(label: 'Remplir', fit: BoxFit.fill, currentFit: _fit, accent: widget.accent, onTap: () {
                            setState(() => _fit = BoxFit.fill);
                            widget.onFit(BoxFit.fill);
                          }),
                        ],
                      ),
                    ],
                  ),
                  // ── Audio tab ────────────────────────────────────────────
                  StreamBuilder(
                    stream: widget.player.stream.tracks,
                    initialData: widget.player.state.tracks,
                    builder: (_, snap) {
                      final tracks = snap.data?.audio ?? [];
                      if (tracks.isEmpty) {
                        return const Center(
                          child: Text('Aucune piste audio', style: TextStyle(color: Colors.white54)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tracks.length,
                        itemBuilder: (_, i) {
                          final t = tracks[i];
                          final sel = widget.player.state.track.audio == t;
                          return ListTile(
                            dense: true,
                            title: Text(
                              t.language ?? t.title ?? 'Piste ${i + 1}',
                              style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 13),
                            ),
                            trailing: sel ? Icon(Icons.check_rounded, color: widget.accent, size: 16) : null,
                            onTap: () {
                              widget.player.setAudioTrack(t);
                              setState(() {});
                            },
                          );
                        },
                      );
                    },
                  ),
                  // ── Sous-titres tab ──────────────────────────────────────
                  StreamBuilder(
                    stream: widget.player.stream.tracks,
                    initialData: widget.player.state.tracks,
                    builder: (_, snap) {
                      final tracks = snap.data?.subtitle ?? [];
                      if (tracks.isEmpty) {
                        return const Center(
                          child: Text('Aucun sous-titre', style: TextStyle(color: Colors.white54)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tracks.length,
                        itemBuilder: (_, i) {
                          final t = tracks[i];
                          final sel = widget.player.state.track.subtitle == t;
                          return ListTile(
                            dense: true,
                            title: Text(
                              t.language ?? t.title ?? (i == 0 ? 'Désactivé' : 'Sous-titre $i'),
                              style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 13),
                            ),
                            trailing: sel ? Icon(Icons.check_rounded, color: widget.accent, size: 16) : null,
                            onTap: () {
                              widget.player.setSubtitleTrack(t);
                              setState(() {});
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FitOption extends StatelessWidget {
  final String label;
  final BoxFit fit;
  final BoxFit currentFit;
  final Color accent;
  final VoidCallback onTap;

  const _FitOption({
    required this.label,
    required this.fit,
    required this.currentFit,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = fit == currentFit;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? accent : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
          border: sel ? null : Border.all(color: const Color(0xFF3A3A3C), width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
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
          top: safeArea.top + 4,
          right: safeArea.right,
          bottom: safeArea.bottom + 4,
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: Container(
                width: panelW,
                constraints: BoxConstraints(
                  maxHeight: screenH * 0.90,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xD1000000),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
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

  // ─── Portrait player overlay (with tap-to-toggle controls) ───────────────────

  class _PortraitPlayerOverlay extends StatefulWidget {
    final Player player;
    final VideoController controller;
    final Color accent;
    final String title;
    final ValueNotifier<bool> seekingNotifier;
    final List<wt.Video> loadedVideos;
    final Future<void> Function(wt.Video)? onSwitchQuality;
    final String? selectedQuality;

    const _PortraitPlayerOverlay({
      required this.player,
      required this.controller,
      required this.accent,
      required this.title,
      required this.seekingNotifier,
      this.loadedVideos = const [],
      this.onSwitchQuality,
      this.selectedQuality,
    });

    @override
    State<_PortraitPlayerOverlay> createState() => _PortraitPlayerOverlayState();
  }

  class _PortraitPlayerOverlayState extends State<_PortraitPlayerOverlay> {
    bool _showControls = true;
    Timer? _hideTimer;

    @override
    void initState() {
      super.initState();
      _resetHideTimer();
    }

    @override
    void dispose() {
      _hideTimer?.cancel();
      super.dispose();
    }

    void _resetHideTimer() {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }

    void _onTap() {
      setState(() => _showControls = !_showControls);
      if (_showControls) _resetHideTimer();
      else _hideTimer?.cancel();
    }

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Video(
                controller: widget.controller,
                fit: BoxFit.contain,
                controls: NoVideoControls,
              ),
            ),
            // Bottom gradient
            Positioned(
              left: 0, right: 0, bottom: 0,
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
                player: widget.player,
                seekingNotifier: widget.seekingNotifier,
              ),
            ),
            // Inline controls — visible only when _showControls
            if (_showControls)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // absorb taps on controls area
                  child: _InlineControls(
                    player: widget.player,
                    controller: widget.controller,
                    accent: widget.accent,
                    title: widget.title,
                    seekingNotifier: widget.seekingNotifier,
                    loadedVideos: widget.loadedVideos,
                    onSwitchQuality: widget.onSwitchQuality,
                    selectedQuality: widget.selectedQuality,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  
class _InlineControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final Color accent;
  final String title;
  final ValueNotifier<bool> seekingNotifier;
  final List<wt.Video> loadedVideos;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final String? selectedQuality;

  const _InlineControls({
    required this.player,
    required this.controller,
    required this.accent,
    required this.title,
    required this.seekingNotifier,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
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
              loadedVideos: widget.loadedVideos,
              onSwitchQuality: widget.onSwitchQuality,
              selectedQuality: widget.selectedQuality,
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
          loadedVideos: widget.loadedVideos,
          onSwitchQuality: widget.onSwitchQuality,
          selectedQuality: widget.selectedQuality,
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
                    onChangeStart: (_) {
                      widget.seekingNotifier.value = true;
                    },
                    onChanged: (_) {},
                    onChangeEnd: (v) {
                      if (dur.inMilliseconds > 0) {
                        _p.seek(Duration(
                            milliseconds: (v * dur.inMilliseconds).round()));
                      }
                      widget.seekingNotifier.value = false;
                    },
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

  Timer? _bufDebounce;
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
        _bufDebounce?.cancel();
        if (buf) {
          _bufDebounce = Timer(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _anim = 'loading');
          });
        } else {
          setState(() => _anim = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _bufDebounce?.cancel();
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
              : const _BufferingDotsIndicator(),
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

  // ─── 3-dots buffering indicator ───────────────────────────────────────────────
  class _BufferingDotsIndicator extends StatefulWidget {
    const _BufferingDotsIndicator();

    @override
    State<_BufferingDotsIndicator> createState() => _BufferingDotsIndicatorState();
  }

  class _BufferingDotsIndicatorState extends State<_BufferingDotsIndicator>
      with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat();
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final step = (_ctrl.value * 3).floor();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final active = i <= step;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: active ? 0.9 : 0.3),
                ),
              );
            }),
          );
        },
      );
    }
  }
  