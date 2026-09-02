// Native (Android / iOS / desktop) inline video player — MovieBox-style UI
//
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:munchtoast/munchtoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/video.dart' as wt;
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/widgets/watchtower_loader.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart'; // player controls use the Broken/Iconsax pack
import 'package:cached_network_image/cached_network_image.dart';

// ─── Speed levels ─────────────────────────────────────────────────────────────
const _kAllSpeeds = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0];

// ─── Aspect-ratio / fit cycle ─────────────────────────────────────────────────
// "Plein écran" (Fullscreen) = BoxFit.cover: the video is scaled up just
// enough to cover the whole surface with zero black bars/margins on any
// side (cropping overflow instead of letterboxing it).
const _kFitCycle = <BoxFit>[BoxFit.contain, BoxFit.cover, BoxFit.fill, BoxFit.fitWidth, BoxFit.fitHeight];
const _kFitNames = <BoxFit, String>{
  BoxFit.contain:   'Ajuster',
  BoxFit.cover:     'Plein écran',
  BoxFit.fill:      'Remplir',
  BoxFit.fitWidth:  '16:9 →',
  BoxFit.fitHeight: '↕ Hauteur',
};

// ─── Native-style toast (used app-wide inside the player, replaces the old
// custom purple toasts / SnackBars) ─────────────────────────────────────────
void _playerToast(String message) {
  final context = navigatorKey.currentState?.context;
  if (context == null) return;
  try {
    MunchToast.show(
      context,
      message: message,
      type: MunchToastType.info,
      position: MunchToastPosition.bottom,
      duration: const Duration(seconds: 2),
      textStyle: const TextStyle(fontSize: 14, color: Colors.white),
      margin: const EdgeInsets.only(bottom: 8, right: 12, left: 12),
      borderRadius: 12,
      elevation: 4,
    );
  } catch (_) {
    // Ne jamais crasher si l'Overlay n'est pas disponible (ex: navigation).
  }
}

// ─── Public API ────────────────────────────────────────────────────────────────

class WatchInlinePlayer {
  late final Player _player;
  late final VideoController _controller;
  final ValueNotifier<bool> _seekingNotifier = ValueNotifier(false);

  /// Shared fit notifier — drives the Video widget in both the auto-rotate
  /// landscape view and the pushed fullscreen page. Defaults to BoxFit.fill
  /// (no black bars). The controls overlay toggles this via _toggleFit().
  final ValueNotifier<BoxFit> fitNotifier = ValueNotifier<BoxFit>(BoxFit.fill);

  String title = '';
  bool hasVideoUrl = false;
  bool loadFailed = false;
  int? loadedChapterId;
  List<wt.Video> loadedVideos = [];
  String? selectedQuality;
  bool _isDisposed = false; // guard against post-dispose async calls

  /// Notifier for portrait overlay controls visibility (back/aide buttons sync).
  final ValueNotifier<bool> controlsVisible = ValueNotifier(true);

  /// Set to true once the currently-loaded stream is detected as a
  /// vertical/short-form ("reel") video — i.e. taller than it is wide.
  /// Detected automatically from the real decoded video dimensions once
  /// playback starts (no extension changes required). Sources such as
  /// MovieBox "TV courte" never flag this in their URLs/JSON, so aspect
  /// ratio is the only reliable signal available at runtime.
  final ValueNotifier<bool> isPortraitFormat = ValueNotifier(false);
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;

  /// Callbacks for episode navigation (set by the parent page in build()).
  VoidCallback? onPrevEpisode;
  VoidCallback? onNextEpisode;

  /// Episode list + tap callback (set by the parent page in build()).
  List<Chapter> chapters = [];
  void Function(Chapter)? onEpisodeTap;

  /// Cover de l'entrée (série/film) — fallback quand un épisode n'a pas sa
  /// propre miniature dans le panneau d'épisodes.
  String? coverUrl;

  WatchInlinePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  void dispose() {
    _isDisposed = true;
    _widthSub?.cancel();
    _heightSub?.cancel();
    _player.dispose();
    _seekingNotifier.dispose();
    fitNotifier.dispose();
    controlsVisible.dispose();
    isPortraitFormat.dispose();
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
    if (_isDisposed) return;
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
    // Kill any ongoing playback immediately so the old audio doesn't bleed
    // into the next episode while the network request is in flight.
    try { await _player.stop(); } catch (_) {}
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
          durSub?.cancel(); // cancel self to avoid accumulating listeners across loads
          hasVideoUrl = true;
          selectedQuality = v.quality;
          AppLogger.log(
            '[PLAYER] EN LECTURE ✓  qualité="${v.quality}"  durée=${dur.inSeconds}s  ep="$epName"',
            logLevel: LogLevel.info,
            tag: LogTag.watch,
          );
          _startPortraitDetection();
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
            if (!_isDisposed && v.headers != null && v.headers!.isNotEmpty) {
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
                      if (_isDisposed) {
                        watchdog.cancel();
                        durSub?.cancel();
                        errSub?.cancel();
                        return;
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

  /// Watches the decoded video dimensions once and flips [isPortraitFormat]
  /// on if the stream is a vertical/"reel" video (height clearly > width).
  /// A 1.15 ratio margin avoids false positives on near-square content.
  void _startPortraitDetection() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    isPortraitFormat.value = false;

    void check() {
      final w = _player.state.width;
      final h = _player.state.height;
      if (w == null || h == null || w <= 0 || h <= 0) return;
      final portrait = h > w * 1.15;
      if (isPortraitFormat.value != portrait) isPortraitFormat.value = portrait;
    }

    check();
    _widthSub = _player.stream.width.listen((_) => check());
    _heightSub = _player.stream.height.listen((_) => check());
  }

  /// Pushes the dedicated TikTok/reel-style fullscreen page for vertical
  /// short-form content (e.g. MovieBox "TV courte" style videos). Reuses
  /// the same [Player]/[VideoController] so playback continues seamlessly.
  void launchReelPage({
    required BuildContext context,
    required List<Chapter> chapters,
    required Chapter currentChapter,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReelPlayerPage(
          player: _player,
          controller: _controller,
          title: title,
          loadedVideos: loadedVideos,
          selectedQuality: selectedQuality,
          onSwitchQuality: switchQuality,
          chapters: chapters,
          currentChapter: currentChapter,
          onEpisodeTap: (c) {
            loadedChapterId = c.id;
            onEpisodeTap?.call(c);
          },
        ),
      ),
    );
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
      controlsNotifier: controlsVisible,
      currentChapterId: loadedChapterId,
      onPrevEpisode: onPrevEpisode,
      onNextEpisode: onNextEpisode,
      chapters: chapters,
      onEpisodeTap: onEpisodeTap,
      coverUrl: coverUrl,
    );
  }

  // Fullscreen video + controls (used when device auto-rotates to landscape)
  Widget buildFullscreenPlayer() {
    return Stack(
      children: [
        SizedBox.expand(
          child: ValueListenableBuilder<BoxFit>(
            valueListenable: fitNotifier,
            builder: (_, fit, __) => Video(
              controller: _controller,
              fit: fit,
              controls: NoVideoControls,
            ),
          ),
        ),
        Positioned.fill(
          child: _FullscreenControlsOverlay(
            player: _player,
            controller: _controller,
            title: title,
            showBackButton: false,
            fitNotifier: fitNotifier,
            loadedVideos: loadedVideos,
            onSwitchQuality: switchQuality,
            selectedQuality: selectedQuality,
            currentChapterId: loadedChapterId,
            onPrevEpisode: onPrevEpisode,
            onNextEpisode: onNextEpisode,
            chapters: chapters,
            onEpisodeTap: onEpisodeTap,
            fallbackCoverUrl: coverUrl,
          )
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
  final int? currentChapterId;
  final List<wt.Video> loadedVideos;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final String? selectedQuality;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final List<Chapter> chapters;
  final void Function(Chapter)? onEpisodeTap;
  final String? fallbackCoverUrl;

  const _FullscreenPlayerPage({
    required this.controller,
    required this.player,
    required this.title,
    this.currentChapterId,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.chapters = const [],
    this.onEpisodeTap,
    this.fallbackCoverUrl,
  });

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
  final _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);
  double _pinchScale = 1.0;
  double _pinchBase  = 1.0;
  Offset _pinchOffset = Offset.zero;
  Offset _panFocalStart = Offset.zero;
  Offset _panOffsetStart = Offset.zero;

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
    // Revenir en portrait : évite que l'écran détail reste coincé en paysage
    // avec un layout cassé après la fermeture du plein écran.
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
      body: GestureDetector(
        onScaleStart: (d) {
          _pinchBase = _pinchScale;
          _panFocalStart = d.focalPoint;
          _panOffsetStart = _pinchOffset;
        },
        onScaleUpdate: (d) {
          setState(() {
            _pinchScale = (_pinchBase * d.scale).clamp(1.0, 5.0);
            if (_pinchScale > 1.0) {
              final delta = d.focalPoint - _panFocalStart;
              _pinchOffset = _panOffsetStart + delta;
            } else {
              _pinchOffset = Offset.zero;
            }
          });
        },
        onScaleEnd: (_) {
          if (_pinchScale < 1.05) {
            setState(() { _pinchScale = 1.0; _pinchOffset = Offset.zero; });
          }
        },
        child: Stack(
        children: [
          SizedBox.expand(
            child: ValueListenableBuilder<BoxFit>(
              valueListenable: _fitNotifier,
              builder: (_, fit, __) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(_pinchScale)
                  ..translate(_pinchOffset.dx / _pinchScale, _pinchOffset.dy / _pinchScale),
                child: Video(
                  controller: widget.controller,
                  fit: fit,
                  controls: NoVideoControls,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _FullscreenControlsOverlay(
              player: widget.player,
              controller: widget.controller,
              title: widget.title,
              currentChapterId: widget.currentChapterId,
              showBackButton: true,
              fitNotifier: _fitNotifier,
              fallbackCoverUrl: widget.fallbackCoverUrl,
              loadedVideos: widget.loadedVideos,
              onSwitchQuality: widget.onSwitchQuality,
              selectedQuality: widget.selectedQuality,
              onPrevEpisode: widget.onPrevEpisode,
              onNextEpisode: widget.onNextEpisode,
              chapters: widget.chapters,
              onEpisodeTap: widget.onEpisodeTap,
            ),
          ),
        ],
        ),   // Stack
      ),     // GestureDetector
    );       // Scaffold
  }
}

// ─── Fullscreen controls overlay (MovieBox style) ─────────────────────────────

class _FullscreenControlsOverlay extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final bool showBackButton;
  final int? currentChapterId;
  final List<wt.Video> loadedVideos;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final String? selectedQuality;
  final ValueNotifier<BoxFit>? fitNotifier;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final List<Chapter> chapters;
  final void Function(Chapter)? onEpisodeTap;
  final String? fallbackCoverUrl;

  const _FullscreenControlsOverlay({
    required this.player,
    required this.controller,
    required this.title,
    required this.showBackButton,
    this.currentChapterId,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
    this.fitNotifier,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.chapters = const [],
    this.onEpisodeTap,
    this.fallbackCoverUrl,
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

  // ── Speed / Quality / Language / More inline pickers ──────────────────────
  bool _showSpeedPicker   = false;
  bool _showQualityPicker = false;
  bool _showMorePanel     = false;
  bool _showEpPanel       = false;

  // ── More panel state ───────────────────────────────────────────────────────
  bool _loopOne           = false;
  bool _loopAll           = false;
  bool _mirrorMode        = false;
  bool _nightMode         = false;
  bool _abRepeatOn        = false;
  Duration? _abStart;
  Duration? _abEnd;

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
    int _skipHudSeconds = 15;
    Timer? _skipHudTimer;
    // Debounce: accumulate delta, fire ONE seek per rapid-tap burst
    Timer? _seekDebounceTimer;
    int _accumulatedSeekDelta = 0;

    // ── Current quality (synced with loadedVideos) ────────────────────────────
    String? _currentQuality;

    // ── Miniature preview (YouTube-style) ────────────────────────────────────
    final _SeekThumbPreview _thumbPreview = _SeekThumbPreview();

    // ── Seekbar drag state (smooth preview without seeking on every frame) ─────
    bool _seekDragging = false;
    double _seekDragValue = 0.0;

    // ── Buffer fraction (updated from stream) ─────────────────────────────────
    double _bufferFrac = 0.0;
    StreamSubscription<Duration>? _bufSub;

    // ── Buffering indicator debounce ──────────────────────────────────────────
    bool _showBuffering = false;
    Timer? _bufDebounce;
    Duration _bufAnchor = Duration.zero;
    StreamSubscription<bool>? _bufferingSub;
    StreamSubscription<bool>? _completedSub;

    // ── Horizontal swipe → seek ───────────────────────────────────────────────
    Duration _horizSeekStartPos = Duration.zero;
    int _horizSeekDelta = 0;
    bool _showSeekSwipeHUD = false;

    // ── Auto Next Episode (Netflix-style) ─────────────────────────────────────
    bool _showNextEpCard = false;
    int  _nextEpCountdown = 20;
    Timer? _nextEpTimer;
    bool _nextEpTriggered = false;

    // ── Continue Watching ─────────────────────────────────────────────────────
    Timer? _saveProgressTimer;

    // ── Rotation lock mode: 0=auto 1=portrait 2=landscape-L 3=landscape-R ─────
    int _rotationMode = 2;
    bool _showRotationPicker = false;

    // ── Pinch to zoom ─────────────────────────────────────────────────────────
    double _pinchScale   = 1.0;
    Offset _pinchOffset  = Offset.zero;
    Offset? _panStart;

    // ── Gesture hint (first launch) ───────────────────────────────────────────
    bool _showGestureHint = false;

    // ── Subtitle delay ────────────────────────────────────────────────────────
    double _subDelaySec = 0.0;

    // ── Adaptive hide: track recent taps ─────────────────────────────────────
    DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
    _initMedia();
    _currentQuality = widget.selectedQuality ??
        (widget.loadedVideos.isNotEmpty ? widget.loadedVideos.first.quality : null);
    _startPositionWatcher();
    _loadSavedProgress();
    _checkGestureHint();
    // Buffer fraction stream
    _bufSub = widget.player.stream.buffer.listen((buf) {
      if (!mounted) return;
      final dur = widget.player.state.duration;
      if (dur.inMilliseconds > 0) {
        setState(() => _bufferFrac = (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0));
      }
    });
    // Buffering dots — debounced 800ms to avoid spurious flickers.
    // Only shown when actually mid-playback (position > 0 or playing),
    // not during initial load (which has its own _LoadingBannerPulse).
    _bufferingSub = widget.player.stream.buffering.listen((buf) {
      if (!mounted) return;
      _bufDebounce?.cancel();
      if (buf) {
        _bufAnchor = widget.player.state.position;
        _bufDebounce = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          final st = widget.player.state;
          // Guard: only show if still buffering AND mid-stream
          if (st.buffering && (st.playing || st.position > Duration.zero)) {
            setState(() => _showBuffering = true);
          }
        });
      } else {
        // Short delay before hiding so we don't flicker on brief rebuffers
        _bufDebounce = Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _showBuffering = false);
        });
      }
    });
    // Always clear buffering overlay at episode end — mpv sometimes never
    // emits buffering=false at EOS, leaving the indicator stuck on screen.
    _completedSub = widget.player.stream.completed.listen((done) {
      if (!mounted || !done) return;
      _bufDebounce?.cancel();
      setState(() => _showBuffering = false);
    });
  }

  // ── Position watcher: auto-next + save progress ───────────────────────────
  StreamSubscription<Duration>? _posSub;

  void _startPositionWatcher() {
    _posSub = widget.player.stream.position.listen((pos) {
      if (!mounted) return;
      final dur = widget.player.state.duration;
      if (dur <= Duration.zero) return;

      // Sécurité: mpv n'émet parfois jamais buffering=false → on masque les
      // points de chargement dès que la lecture a repris (position avance).
      if (_showBuffering && widget.player.state.playing &&
          pos > _bufAnchor + const Duration(milliseconds: 800)) {
        setState(() => _showBuffering = false);
      }

      // Auto Next Episode: show card 20s before end
      final remaining = dur - pos;
      if (!_nextEpTriggered && remaining.inSeconds <= 20 && remaining.inSeconds > 0
          && widget.onNextEpisode != null) {
        _nextEpTriggered = true;
        setState(() { _showNextEpCard = true; _nextEpCountdown = remaining.inSeconds.clamp(1, 20); });
        _startNextEpCountdown();
      } else if (remaining.inSeconds > 22) {
        if (_nextEpTriggered) { _nextEpTriggered = false; _nextEpTimer?.cancel(); setState(() => _showNextEpCard = false); }
      }
    });
  }

  void _startNextEpCountdown() {
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _nextEpCountdown--;
        if (_nextEpCountdown <= 0) {
          _nextEpTimer?.cancel();
          _showNextEpCard = false;
          widget.onNextEpisode?.call();
        }
      });
    });
  }

  // ── Save/load progress ─────────────────────────────────────────────────────
  Future<void> _loadSavedProgress() async {
    try {
      final dir  = await getTemporaryDirectory();
      final id   = widget.title.hashCode;
      final file = File('${dir.path}/wt_progress_$id.json');
      if (!await file.exists()) return;
      final raw  = json.decode(await file.readAsString()) as Map;
      final ms   = (raw['ms'] as num?)?.toInt() ?? 0;
      if (ms > 5000) {
        // Wait for player to be ready then restore
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          try { await widget.player.seek(Duration(milliseconds: ms)); } catch (_) {}
          if (mounted) {
            _playerToast('Reprise à ${_fmt(Duration(milliseconds: ms))}');
          }
        });
      }
    } catch (_) {}
  }

  void _startSaveProgressTimer() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final dir  = await getTemporaryDirectory();
        final id   = widget.title.hashCode;
        final ms   = widget.player.state.position.inMilliseconds;
        await File('${dir.path}/wt_progress_$id.json').writeAsString(json.encode({'ms': ms}));
      } catch (_) {}
    });
  }

  // ── Gesture hint ──────────────────────────────────────────────────────────
  Future<void> _checkGestureHint() async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/wt_gesture_hint_shown');
      if (!await file.exists()) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _showGestureHint = true);
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) setState(() => _showGestureHint = false);
        await file.writeAsString('1');
      }
    } catch (_) {}
  }

  Future<void> _initMedia() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
    try {
      // Hide the native OS volume overlay (Android/iOS) — we draw our own
      // in-app volume HUD, so the system one must not appear on top of it.
      VolumeController.instance.showSystemUI = false;
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
    _startSaveProgressTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _doubleTapResetTimer?.cancel();
    _skipHudTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _nextEpTimer?.cancel();
    _saveProgressTimer?.cancel();
    _posSub?.cancel();
    _bufSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _bufDebounce?.cancel();
    _thumbPreview.dispose();
    super.dispose();
  }

  // ── Rotation lock cycling ─────────────────────────────────────────────────
  // 0=auto, 1=portrait, 2=landscape-L, 3=landscape-R
  IconData _rotationModeIcon() {
    switch (_rotationMode) {
      case 0: return Icons.screen_rotation_rounded;
      case 1: return Icons.stay_current_portrait_outlined;
      case 2: return Icons.stay_current_landscape_outlined;
      case 3: return Icons.screen_rotation_alt_outlined;
      default: return Icons.screen_rotation_rounded;
    }
  }
  String _rotationModeLabel() {
    switch (_rotationMode) {
      case 0: return 'Auto';
      case 1: return 'Portrait';
      case 2: return 'Paysage ←';
      case 3: return 'Paysage →';
      default: return 'Auto';
    }
  }
  void _setRotationMode(int mode) {
    _showRotationPicker = false;
    setState(() => _rotationMode = mode % 4);
    switch (_rotationMode) {
      case 0:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
        ]);
        break;
      case 1:
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        break;
      case 2:
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
        break;
      case 3:
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
        break;
    }
    _playerToast('Rotation : ${_rotationModeLabel()}');
    _resetHideTimer();
  }

  // Option compacte dans le sélecteur d'orientation dépliant
  Widget _buildRotOption(int mode, IconData icn, String tip) {
    final sel = _rotationMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setRotationMode(mode),
      child: Tooltip(
        message: tip,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sel
                ? Theme.of(context).primaryColor.withValues(alpha: 0.25)
                : Colors.transparent,
            border: Border.all(
              color: sel ? Theme.of(context).primaryColor : Colors.white24,
              width: sel ? 1.6 : 1,
            ),
          ),
          child: Icon(icn, color: sel ? Colors.white : Colors.white60, size: 17),
        ),
      ),
    );
  }

  // ── PiP (Picture-in-Picture) ─────────────────────────────────────────────
  Future<void> _enterPiP() async {
    const ch = MethodChannel('com.watchtower.app.pip');
    try {
      await ch.invokeMethod('enterPiP');
    } catch (_) {}
  }

  // ── Double-tap seek with escalating amounts ──────────────────────────────────
  // Debounced: accumulates delta across rapid taps and fires ONE seek per
  // burst, preventing multiple concurrent mpv buffer positions (RAM spike).
  void _handleDoubleTap({required bool isRight}) {
    if (_locked) return;
    _doubleTapResetTimer?.cancel();

    // Reset count/accumulator if side changed
    if (_doubleTapRight != null && _doubleTapRight != isRight) {
      _doubleTapCount = 0;
      _accumulatedSeekDelta = 0;
    }
    _doubleTapRight = isRight;
    // Cap at 5 to prevent absurdly large jumps (max 15×16 = 240 s per tap)
    _doubleTapCount = (_doubleTapCount + 1).clamp(1, 5);

    final increment = _seekSeconds * (1 << (_doubleTapCount - 1).clamp(0, 4));
    _accumulatedSeekDelta += isRight ? increment : -increment;
    _skipHudSeconds = _accumulatedSeekDelta.abs();

    // Debounce: one real seek fires 350 ms after the last tap in a burst
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _seek(_accumulatedSeekDelta);
      _accumulatedSeekDelta = 0;
    });

    // Show HUD — stays visible until 800 ms after the last tap
    _skipHudTimer?.cancel();
    setState(() {
      _showLeftSkipHUD  = !isRight;
      _showRightSkipHUD = isRight;
    });
    _skipHudTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showLeftSkipHUD = false; _showRightSkipHUD = false; });
    });

    // Reset escalation counter 1 s after last tap
    _doubleTapResetTimer = Timer(const Duration(milliseconds: 1000), () {
      _doubleTapCount = 0;
      _doubleTapRight = null;
      _accumulatedSeekDelta = 0;
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
          _showRotationPicker = false;
        });
      }
    });
  }

  void _onTap() {
    if (_locked) return;
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
    final idx = _kFitCycle.indexOf(_fit);
    setState(() => _fit = _kFitCycle[(idx + 1) % _kFitCycle.length]);
    widget.fitNotifier?.value = _fit;
    _playerToast(_kFitNames[_fit] ?? 'Ajuster');
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
        // NOTE: no onTap here — single tap is handled exclusively by the
        // left/right half-screen zones below (which also own onDoubleTap).
        // Having onTap on this outer wrapper AND on the inner zones created
        // a gesture-arena race: the outer tap fired instantly while the
        // inner tap waited for the double-tap timeout, causing controls to
        // flicker open/close and double-taps to sometimes register as two
        // single taps.
        onLongPressStart: (d) {
          if (_locked) return;
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
          if (_locked || _holdSpeedActive) return;
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
          // Vitesse adaptative : un swipe pleine largeur couvre ~1/4 de la
          // durée du flux (clip de 20 min → précis, film de 2 h → rapide).
          final secondsPerScreen =
              (widget.player.state.duration.inSeconds / 4).clamp(20.0, 900.0);
          _horizSeekDelta = (dx / size.width * secondsPerScreen).round();
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
          if (_locked) return;
          _dragStartPos = d.globalPosition;
          _hideTimer?.cancel();
        },
        onVerticalDragUpdate: (d) { if (_locked) return; _handleSwipeDrag(d, size); },
        onVerticalDragEnd: (_) {
          if (_locked) { return; }
          _dragStartPos = null;
          if (!_showBrightnessHUD && !_showVolumeHUD) _resetHideTimer();
        },
      child: Stack(
        children: [
          // ── Left-half double-tap zone (seek back) — also single-tap toggles controls
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: size.width * 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                if (_locked) return;
                _handleDoubleTap(isRight: false);
              },
              onTap: _onTap,
            ),
          ),
          // ── Right-half double-tap zone (seek forward) — also single-tap toggles controls
          Positioned(
            right: 0, top: 0, bottom: 0,
            width: size.width * 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                if (_locked) return;
                _handleDoubleTap(isRight: true);
              },
              onTap: _onTap,
            ),
          ),

          // ── Skip ripple — left half of screen ───────────────────────────────
          if (_showLeftSkipHUD)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: size.width * 0.5,
              child: IgnorePointer(
                child: _buildSkipHUD(isRight: false, seconds: _skipHudSeconds),
              ),
            ),
          // ── Skip ripple — right half of screen ──────────────────────────────
          if (_showRightSkipHUD)
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: size.width * 0.5,
              child: IgnorePointer(
                child: _buildSkipHUD(isRight: true, seconds: _skipHudSeconds),
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
                        child: const Icon(Broken.musicnote, color: Colors.white70, size: 44),
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

          // Buffering indicator — debounced, hidden while seek-dragging
          IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: (_showBuffering && !_seekDragging && !_showSeekSwipeHUD) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: _BufferingDotsIndicator(bufferFrac: _bufferFrac),
              ),
            ),
          ),

          // Main controls overlay (auto-hides) — fades in/out instead of
          // popping instantly, and stays mounted so it can animate.
          if (!_locked)
            IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _buildControlsOverlay(),
              ),
            ),

          // Lock indicator — compact chip pinned top-right, clear of the
          // video content and of every other control (which are hidden
          // anyway while locked).
          if (_locked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 14,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _locked = false;
                    _showControls = true;
                  });
                  _resetHideTimer();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Broken.lock, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Déverrouiller',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
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
                      icon: Broken.camera,
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
                              _playerToast('Capture sauvegardée');
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Choix d'orientation — se déplie vers la gauche
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          transitionBuilder: (c, anim) => ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: anim.value,
                              child: FadeTransition(
                                  opacity: anim, child: c),
                            ),
                          ),
                          child: !_showRotationPicker
                              ? const SizedBox(width: 0, height: 40)
                              : Container(
                                  key: const ValueKey('rotOpts'),
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  margin:
                                      const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.55),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white24,
                                        width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildRotOption(
                                          0,
                                          Icons.screen_rotation_rounded,
                                          'Auto'),
                                      _buildRotOption(
                                          1,
                                          Icons
                                              .stay_current_portrait_outlined,
                                          'Portrait'),
                                      _buildRotOption(
                                          2,
                                          Icons
                                              .stay_current_landscape_outlined,
                                          'Paysage ←'),
                                      _buildRotOption(
                                          3,
                                          Icons.screen_rotation_alt_outlined,
                                          'Paysage →'),
                                    ],
                                  ),
                                ),
                        ),
                        _buildIconCircle(
                          icon: _rotationModeIcon(),
                          tooltip: 'Orientation',
                          onTap: () {
                            _hideTimer?.cancel();
                            setState(() =>
                                _showRotationPicker =
                                    !_showRotationPicker);
                          },
                        ),
                      ],
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
                onDownload: _startDownload,
                onClose: () {
                  setState(() => _showSubPanel = false);
                  _resetHideTimer();
                },
              ),
            ),

          // Luminosité / Volume — pilule horizontale en HAUT au centre
            if (_showBrightnessHUD || _showVolumeHUD)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _showBrightnessHUD
                        ? _buildTopMediaHud(
                            icon: Broken.sun,
                            value: _brightness)
                        : _buildTopMediaHud(
                            icon: _volume <= 0
                                ? Broken.volume_slash
                                : _volume < 0.5
                                    ? Broken.volume_low
                                    : Broken.volume_high,
                            value: _volume),
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
                                const Icon(Broken.forward, color: Colors.white, size: 18),
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

              // Seek swipe HUD — juste au-dessus de la barre de progression
          if (_showSeekSwipeHUD)
            Positioned(
              bottom: 84, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _buildSeekSwipeHUD(),
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
      // ── Volume — up to 200% (extra gain via player, hardware caps at 100%)
      final next = (_volume - dy / size.height * 2.5).clamp(0.0, 2.0);
      _volume = next;
      try { VolumeController.instance.setVolume(next.clamp(0.0, 1.0)); } catch (_) {}
      widget.player.setVolume(next * 100);
      _hudTimer?.cancel();
      setState(() { _showVolumeHUD = true; _showBrightnessHUD = false; });
      _hudTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showVolumeHUD = false);
      });
    }
  }

  // ── Skip HUD double-tap — "+15 ›" propre et animé (pas de demi-arc) ──────
  Widget _buildSkipHUD({required bool isRight, required int seconds}) {
    final label = '${isRight ? '+' : '-'}${seconds.abs()}';
    return TweenAnimationBuilder<double>(
      key: ValueKey('skip_${isRight}_$seconds'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(isRight ? 16 * (1 - t) : -16 * (1 - t), 0),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isRight ? Broken.forward : Broken.backward,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pilule Luminosité/Volume — horizontale, en haut au centre ────────────
  Widget _buildTopMediaHud({required IconData icon, required double value}) {
    final clamped = value.clamp(0.0, 2.0);
    final fill    = (clamped / 2).clamp(0.0, 1.0); // 0→200% sur la largeur
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: clamped > 1.0 ? Colors.orangeAccent : Colors.white,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: Colors.white24),
                      FractionallySizedBox(
                        widthFactor: fill,
                        alignment: Alignment.centerLeft,
                        child: Container(
                            color:
                                clamped > 1.0 ? Colors.orangeAccent : Colors.white),
                      ),
                      // Repère du seuil 100 %
                      const Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 1,
                          height: 8,
                          child: ColoredBox(color: Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: clamped > 1.0 ? Colors.orangeAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekSwipeHUD() {
    final pos = _horizSeekStartPos + Duration(seconds: _horizSeekDelta);
    final dur = widget.player.state.duration;
    final clamped = pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos);
    final sign = _horizSeekDelta >= 0 ? '+' : '';
    // Pilule minimale centrée au-dessus de la barre de progression
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _horizSeekDelta >= 0 ? Broken.forward : Broken.backward,
            color: Colors.white70,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            '$sign${_horizSeekDelta}s',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text(
            _fmt(clamped),
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }
  // ── Miniature preview : flux courant + position demandée ───────────────────
  wt.Video? get _currentVideo {
    final vids = widget.loadedVideos;
    for (final v in vids) {
      if (v.quality == (widget.selectedQuality ?? _currentQuality)) return v;
    }
    if (vids.isNotEmpty) return vids.first;
    // Fallback : flux en cours de lecture quand loadedVideos est vide
    // (sinon l'aperçu miniature ne s'affiche jamais).
    try {
      final medias = widget.player.state.playlist.medias;
      if (medias.isNotEmpty) {
        final uri = medias.first.uri.toString();
        if (uri.isNotEmpty) {
          return wt.Video(uri, widget.selectedQuality ?? 'auto', uri);
        }
      }
    } catch (_) {}
    return null;
  }

  void _requestThumb(double fraction) {
    final dur = widget.player.state.duration;
    final v = _currentVideo;
    if (v == null || dur <= Duration.zero) return;
    _thumbPreview.request(
      url: v.url,
      headers: v.headers,
      position: Duration(milliseconds: (fraction * dur.inMilliseconds).round()),
    );
  }

  // ── Télécharge la source en cours (qualité sélectionnée) ────────────────────
  Future<void> _startDownload() async {
    try {
      final vids = widget.loadedVideos;
      wt.Video? video;
      for (final v in vids) {
        if (v.quality == _currentQuality) { video = v; break; }
      }
      video ??= vids.isNotEmpty ? vids.first : null;
      if (video == null || video.url.isEmpty) {
        _playerToast('Aucune source à télécharger');
        return;
      }
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/Watchtower/Downloads');
      await dir.create(recursive: true);
      final clean = widget.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '${dir.path}/$clean (${video.quality}).mp4';
      _playerToast('Téléchargement démarré…');
      final req = await HttpClient().getUrl(Uri.parse(video.url));
      video.headers?.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close();
      if (res.statusCode != 200) {
        _playerToast('Échec du téléchargement (HTTP \${res.statusCode})');
        return;
      }
      final tmp = File('\$savePath.part');
      final sink = tmp.openWrite();
      await sink.addStream(res);
      await sink.close();
      await tmp.rename(savePath);
      _playerToast('Téléchargement terminé ✔');
    } catch (e) {
      AppLogger.log('download failed: $e', logLevel: LogLevel.error, tag: 'PlayerDownload');
      _playerToast('Échec du téléchargement');
    }
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
        // Episode list panel — right side
        if (_showEpPanel)
          Positioned.fill(
            child: _EpisodePanel(
              chapters: widget.chapters,
              currentChapterId: widget.currentChapterId,
              fallbackCoverUrl: widget.fallbackCoverUrl,
              accent: Theme.of(context).primaryColor,
              onTap: (ch) {
                setState(() => _showEpPanel = false);
                widget.onEpisodeTap?.call(ch);
                _resetHideTimer();
              },
              onClose: () {
                setState(() => _showEpPanel = false);
                _resetHideTimer();
              },
            ),
          ),
        // More panel (PLAYit-style) — right side
        if (_showMorePanel)
          Positioned.fill(
            child: _MorePanel(
              player: widget.player,
              accent: Theme.of(context).primaryColor,
              loopOne: _loopOne,
              loopAll: _loopAll,
              mirrorMode: _mirrorMode,
              nightMode: _nightMode,
              abRepeatOn: _abRepeatOn,
              abStart: _abStart,
              abEnd: _abEnd,
              audioOnly: _audioOnly,
              onLoopOne: (v) { setState(() { _loopOne = v; _loopAll = false; }); if (v) widget.player.setPlaylistMode(PlaylistMode.single); else widget.player.setPlaylistMode(PlaylistMode.none); },
              onLoopAll: (v) { setState(() { _loopAll = v; _loopOne = false; }); if (v) widget.player.setPlaylistMode(PlaylistMode.loop); else widget.player.setPlaylistMode(PlaylistMode.none); },
              onMirror: (v) => setState(() => _mirrorMode = v),
              onNight: (v) => setState(() => _nightMode = v),
              onAbRepeat: (v) => setState(() => _abRepeatOn = v),
              onAbStartSet: () => setState(() => _abStart = widget.player.state.position),
              onAbEndSet: () => setState(() => _abEnd = widget.player.state.position),
              onAudioOnly: (v) {
                setState(() => _audioOnly = v);
                if (v) widget.player.setVideoTrack(VideoTrack.no());
                else {
                  final vt = widget.player.state.tracks.video;
                  if (vt.isNotEmpty) widget.player.setVideoTrack(vt.first);
                }
              },
              onClose: () {
                setState(() => _showMorePanel = false);
                _resetHideTimer();
              },
            ),
          ),
        // Night mode overlay
        if (_nightMode)
          IgnorePointer(
            child: Container(color: Colors.orange.withValues(alpha: 0.18)),
          ),
        // Auto Next Episode card (Netflix-style)
        if (_showNextEpCard && widget.onNextEpisode != null)
          Positioned(
            bottom: 80, right: 20,
            child: _NextEpCard(
              countdown: _nextEpCountdown,
              accent: Theme.of(context).primaryColor,
              onNow: () {
                _nextEpTimer?.cancel();
                setState(() => _showNextEpCard = false);
                widget.onNextEpisode?.call();
              },
              onCancel: () {
                _nextEpTimer?.cancel();
                setState(() { _showNextEpCard = false; _nextEpTriggered = true; });
                _resetHideTimer();
              },
            ),
          ),
        // Gesture hint (first launch)
        if (_showGestureHint)
          Positioned.fill(
            child: IgnorePointer(
              child: _GestureHintOverlay(),
            ),
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
              icon: const Icon(Broken.arrow_left, color: Colors.white, size: 22),
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
            icon: const Icon(Broken.subtitle, color: Colors.white70, size: 20),
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
          // Episode list — hidden for movies (single item)
          if (widget.chapters.length > 1)
          IconButton(
            icon: Icon(
              Broken.music_playlist,
              color: _showEpPanel ? Theme.of(context).primaryColor : Colors.white70,
              size: 22,
            ),
            onPressed: () {
              _hideTimer?.cancel();
              setState(() {
                _showEpPanel       = !_showEpPanel;
                _showSpeedPicker   = false;
                _showQualityPicker = false;
                _showMorePanel     = false;
              });
            },
            padding: const EdgeInsets.all(8),
          ),
          // More (PLAYit-style panel)
          IconButton(
            icon: Icon(
              Broken.more,
              color: _showMorePanel ? Theme.of(context).primaryColor : Colors.white,
              size: 22,
            ),
            onPressed: () {
              _hideTimer?.cancel();
              setState(() {
                _showMorePanel     = !_showMorePanel;
                _showSpeedPicker   = false;
                _showQualityPicker = false;
                _showEpPanel       = false;
              });
            },
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  // Cercle ±15 façon MovieBox : arc tracé avec tête de flèche courbée et le
  // chiffre centré À L'INTÉRIEUR — pas de fond, pas d'icône à côté.
  Widget _buildSkipButton({required bool isForward, required int seconds}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_locked) return;
        _seek(isForward ? seconds : -seconds);
      },
      child: SizedBox(
        width: 58,
        height: 58,
        child: CustomPaint(
          painter: _SkipCirclePainter(isForward: isForward),
          child: Center(
            child: Text(
              '$seconds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterRow() {
    // Pas de pause au centre (déjà en bas à gauche dans la toolbar).
    // -15 / +15 centrés à 25 % / 75 % de la largeur — pas aux bords.
    return Row(
      children: [
        Expanded(
          child:
              Center(child: _buildSkipButton(isForward: false, seconds: 15)),
        ),
        Expanded(
          child:
              Center(child: _buildSkipButton(isForward: true, seconds: 15)),
        ),
      ],
    );
  }

  Widget _buildLockButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _locked = true;
          _showControls = false;
          _showRotationPicker = false;
        });
        _hideTimer?.cancel();
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: const Icon(Broken.unlock, color: Colors.white, size: 20),
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
        // Seek-preview: target position while dragging
        final previewDur = dur.inMilliseconds > 0
            ? Duration(milliseconds: (_seekDragValue * dur.inMilliseconds).round())
            : Duration.zero;

        return LayoutBuilder(
          builder: (_, constraints) {
            // Approx x position of slider thumb (between time labels ~40px each + 12px padding)
            const timeLabelW = 46.0;
            const hPad = 12.0;
            final sliderW = constraints.maxWidth - timeLabelW * 2 - hPad * 2;
            final displayValue = _seekDragging ? _seekDragValue : progress;
            final thumbX = hPad + timeLabelW + displayValue * sliderW;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: hPad),
                      child: SizedBox(
                        width: timeLabelW - hPad,
                        child: Text(
                          _fmt(pos),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
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
                          inactiveTrackColor: Colors.white24,
                          secondaryActiveTrackColor: Colors.white54,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          value: displayValue,
                          secondaryTrackValue: _bufferFrac,
                          onChangeStart: (v) {
                            setState(() => _seekDragging = true);
                            _hideTimer?.cancel();
                            _requestThumb(v);
                          },
                          onChanged: (v) {
                            setState(() => _seekDragValue = v);
                            _requestThumb(v);
                          },
                          onChangeEnd: (v) {
                            _thumbPreview.clearRequest();
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
                      padding: const EdgeInsets.symmetric(horizontal: hPad),
                      child: SizedBox(
                        width: timeLabelW - hPad,
                        child: Text(
                          _fmt(dur),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Aperçu miniature + bulle temps (YouTube-style) ────────────
                if (_seekDragging)
                  Positioned(
                    left: (thumbX - 75)
                        .clamp(0.0, (constraints.maxWidth - 160).clamp(0.0, double.infinity)),
                    bottom: 26,
                    child: IgnorePointer(
                      child: ValueListenableBuilder<Uint8List?>(
                        valueListenable: _thumbPreview.frame,
                        builder: (_, frame, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (frame != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.memory(
                                    frame,
                                    width: 150,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _fmt(previewDur),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildToolbar() {
    final speedLabel = _speed == _speed.roundToDouble()
        ? '${_speed.toInt()}x'
        : '${_speed}x';
    final fitLabel = _kFitNames[_fit] ?? 'Ajuster';
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
                (snap.data ?? false) ? Broken.pause : Broken.play,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                widget.player.playOrPause();
                _resetHideTimer();
              },
              padding: const EdgeInsets.all(4),
              constraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ),
          // Previous episode
          IconButton(
            icon: Icon(Broken.previous,
                color: widget.onPrevEpisode != null ? Colors.white70 : Colors.white24,
                size: 24),
            onPressed: widget.onPrevEpisode != null ? () {
              widget.onPrevEpisode!();
              _resetHideTimer();
            } : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          // Next episode
          IconButton(
            icon: Icon(Broken.next,
                color: widget.onNextEpisode != null ? Colors.white70 : Colors.white24,
                size: 24),
            onPressed: widget.onNextEpisode != null ? () {
              widget.onNextEpisode!();
              _resetHideTimer();
            } : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          const Spacer(),
          // Fit (cycle through modes)
          _ToolbarChip(
            icon: Broken.crop,
            label: fitLabel,
            onTap: _toggleFit,
          ),
          // Quality picker chip
          _ToolbarChip(
            icon: Icons.hd_outlined,
            label: _qualityLabel(),
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
        constraints: const BoxConstraints(maxHeight: 320),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: speeds.map((s) {
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
                }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ─── Quality label for chip ────────────────────────────────────────────────
  String _qualityLabel() {
    if (_currentQuality != null && _currentQuality!.isNotEmpty) return _currentQuality!;
    if (widget.loadedVideos.isNotEmpty) return widget.loadedVideos.first.quality;
    return 'Qualité';
  }

  // ─── Quality picker — uses loadedVideos from parent ────────────────────────
  Widget _buildQualityPickerOverlay() {
    final videos = widget.loadedVideos;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
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
                child: Text('Qualité',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1, color: Colors.white12),
              if (videos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text('Aucune qualité', style: TextStyle(color: Colors.white54, fontSize: 13)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: videos.map((v) {
                        final isCurrent = _currentQuality == v.quality;
                        return GestureDetector(
                          onTap: () async {
                            _currentQuality = v.quality;
                            setState(() => _showQualityPicker = false);
                            _resetHideTimer();
                            if (widget.onSwitchQuality != null) await widget.onSwitchQuality!(v);
                            _playerToast('Qualité : ${v.quality}');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            color: isCurrent ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 80,
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
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
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
          _muted ? Broken.volume_slash : Broken.volume_high,
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

// ─── Audio track label helper ─────────────────────────────────────────────────

String _audioTrackLabel(AudioTrack t, int index) {
  if (t.id == 'no' || t.id == '-1') return 'Aucune';
  if (t.title?.isNotEmpty == true) return t.title!;
  final langMap = {
    'fr': 'Français', 'ja': 'Japonais', 'jp': 'Japonais',
    'en': 'Anglais',  'de': 'Allemand', 'es': 'Espagnol',
    'pt': 'Portugais','it': 'Italien',  'ar': 'Arabe',
    'zh': 'Chinois',  'ko': 'Coréen',   'ru': 'Russe',
  };
  final lang = t.language?.toLowerCase() ?? '';
  final mapped = langMap[lang];
  if (mapped != null) return mapped;
  if (lang.isNotEmpty) return lang.toUpperCase();
  return 'Piste ${index + 1}';
}

// ─── Skip circle painter (arc + arrowhead + number inside) ────────────────────

class _SkipCirclePainter extends CustomPainter {
  final bool isForward;
  _SkipCirclePainter({required this.isForward});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.5;
    final stroke = 2.2;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.95);

    // Gap en haut où vient se poser la tête de flèche.
    const gap = 0.62; // radians
    final double start;
    final double sweep;
    if (isForward) {
      start = -math.pi / 2 + gap / 2;
      sweep = 2 * math.pi - gap;
    } else {
      start = -math.pi / 2 - gap / 2;
      sweep = -(2 * math.pi - gap);
    }

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        sweep, false, arcPaint);

    _drawArrowHead(canvas, center, radius, start + sweep, stroke);
  }

  void _drawArrowHead(
      Canvas canvas, Offset c, double r, double angle, double stroke) {
    final pos = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    // Tangente dans le sens de l'arc.
    final Offset tangent;
    if (isForward) {
      tangent = Offset(-math.sin(angle), math.cos(angle));
    } else {
      tangent = Offset(math.sin(angle), -math.cos(angle));
    }
    final tip = pos + tangent * (stroke * 4.0);
    final back = -tangent;
    final perp = Offset(-back.dy, back.dx);
    final half = stroke * 3.4;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(pos.dx + perp.dx * half, pos.dy + perp.dy * half)
      ..lineTo(pos.dx - perp.dx * half, pos.dy - perp.dy * half)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SkipCirclePainter oldDelegate) =>
      oldDelegate.isForward != isForward;
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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
                  color: active ? accent : Colors.white60, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? accent : Colors.white,
                fontSize: 12,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kFitCycle.map((f) {
                          final lbl = _kFitNames[f] ?? 'Ajuster';
                          return _FitOption(
                            label: lbl,
                            fit: f,
                            currentFit: _fit,
                            accent: widget.accent,
                            onTap: () {
                              setState(() => _fit = f);
                              widget.onFit(f);
                              _playerToast(lbl);
                            },
                          );
                        }).toList(),
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
  final Future<void> Function()? onDownload;

  const _SettingsPanel({
    required this.player,
    required this.accent,
    required this.onClose,
    this.onDownload,
  });

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  bool _bilingual = false;
  double _subDelay = 0.0;
  bool _subBoldBox = false;
  double _subFontSize = 24;
  static const Color _kBlue = Color(0xFF2E6CEF);

  /// Bilingual subtitles: play a second subtitle track via mpv `secondary-sid`.
  void _applyBilingual() {
    final plat = widget.player.platform as dynamic;
    try {
      if (_bilingual) {
        final cur = widget.player.state.track.subtitle;
        final others = widget.player.state.tracks.subtitle
            .where((t) => t.id != 'no' && t.id != '-1' && t.id != cur.id)
            .toList();
        if (others.isNotEmpty) {
          plat.setProperty('secondary-sid', others.first.id);
        } else {
          _bilingual = false; // nothing to pair with
        }
      } else {
        plat.setProperty('secondary-sid', 'no');
      }
    } catch (_) {}
  }

  /// Apply subtitle styling via mpv properties.
  void _applySubStyle() {
    final plat = widget.player.platform as dynamic;
    try {
      plat.setProperty('sub-font-size', _subFontSize.round().toString());
      plat.setProperty('sub-border-style', _subBoldBox ? '3' : '1');
      plat.setProperty('sub-back-color', _subBoldBox ? '&H80000000' : '&H00000000');
      plat.setProperty('sub-shadow', '0');
    } catch (_) {}
  }

  Widget _subSizeBtn(IconData icon, double delta) {
    return GestureDetector(
      onTap: () {
        setState(() => _subFontSize = (_subFontSize + delta).clamp(14.0, 64.0));
        _applySubStyle();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _styleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? widget.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? widget.accent : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: selected ? widget.accent : Colors.white70, fontSize: 12)),
      ),
    );
  }

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
                                    thumbColor: WidgetStateProperty.resolveWith(
                                        (states) => states.contains(WidgetState.selected)
                                            ? _kBlue
                                            : Colors.white70),
                                    trackColor: WidgetStateProperty.resolveWith(
                                        (states) => states.contains(WidgetState.selected)
                                            ? _kBlue.withValues(alpha: 0.85)
                                            : Colors.white24),
                                    overlayColor:
                                        WidgetStateProperty.all(Colors.transparent),
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
                                        onChanged: (v) {
                                          setState(() => _bilingual = v);
                                          _applyBilingual();
                                        },
                                        activeColor: _kBlue,
                                        activeTrackColor: _kBlue,
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
                                      if (_bilingual) _applyBilingual();
                                      setState(() {});
                                    },
                                  );
                                }),
                              ],
                              Container(height: 0.6, color: Colors.white12),
                              // Subtitle delay control
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Décalage sous-titres',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            final newVal = (_subDelay - 0.5).clamp(-10.0, 10.0);
                                            _subDelay = newVal;
                                            setState(() {});
                                            try {
                                              final plat = widget.player.platform as dynamic;
                                              plat.setProperty('sub-delay', newVal.toStringAsFixed(1));
                                            } catch (_) {}
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white12,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              '${_subDelay >= 0 ? '+' : ''}${_subDelay.toStringAsFixed(1)}s',
                                              style: TextStyle(
                                                color: _subDelay != 0 ? widget.accent : Colors.white54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            final newVal = (_subDelay + 0.5).clamp(-10.0, 10.0);
                                            _subDelay = newVal;
                                            setState(() {});
                                            try {
                                              final plat = widget.player.platform as dynamic;
                                              plat.setProperty('sub-delay', newVal.toStringAsFixed(1));
                                            } catch (_) {}
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white12,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(height: 0.6, color: Colors.white12),
                              Container(height: 0.6, color: Colors.white12),
                              // ── Style des sous-titres ──────────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Style des sous-titres',
                                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _styleChip('Contour', !_subBoldBox, () { setState(() => _subBoldBox = false); _applySubStyle(); }),
                                        const SizedBox(width: 8),
                                        _styleChip('Fond', _subBoldBox, () { setState(() => _subBoldBox = true); _applySubStyle(); }),
                                        const Spacer(),
                                        _subSizeBtn(Icons.remove_rounded, -2),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text('${_subFontSize.round()}',
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ),
                                        _subSizeBtn(Icons.add_rounded, 2),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(height: 0.6, color: Colors.white12),
                              // ── Langue (pistes audio) — mêmes boxes que le picker ──
                              const Padding(
                                padding: EdgeInsets.fromLTRB(12, 10, 12, 2),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Langue',
                                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                                child: Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: widget.player.state.tracks.audio.asMap().entries.map((e) {
                                    final i = e.key; final t = e.value;
                                    final sel = t.id == widget.player.state.track.audio.id;
                                    return GestureDetector(
                                      onTap: () { widget.player.setAudioTrack(t); setState(() {}); },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: sel ? widget.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: sel ? widget.accent : Colors.white12),
                                        ),
                                        child: Text(_audioTrackLabel(t, i),
                                            style: TextStyle(color: sel ? widget.accent : Colors.white70, fontSize: 12)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              Container(height: 0.6, color: Colors.white12),
                              InkWell(
                                onTap: () => widget.onDownload?.call(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Télécharger',
                                          style: TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
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
    final ValueNotifier<bool>? controlsNotifier;
    final int? currentChapterId;
    final VoidCallback? onPrevEpisode;
    final VoidCallback? onNextEpisode;
    final List<Chapter> chapters;
    final void Function(Chapter)? onEpisodeTap;
  final String? coverUrl;

    const _PortraitPlayerOverlay({
      required this.player,
      required this.controller,
      required this.accent,
      required this.title,
      required this.seekingNotifier,
      this.loadedVideos = const [],
      this.onSwitchQuality,
      this.selectedQuality,
      this.controlsNotifier,
      this.currentChapterId,
      this.onPrevEpisode,
      this.onNextEpisode,
      this.chapters = const [],
      this.onEpisodeTap,
    this.coverUrl,
    });

    @override
    State<_PortraitPlayerOverlay> createState() => _PortraitPlayerOverlayState();
  }

  class _PortraitPlayerOverlayState extends State<_PortraitPlayerOverlay> {
    bool _showControls = true;
    Timer? _hideTimer;

    // ── Brightness / Volume swipe ──────────────────────────────────────────────
    double _brightness = 0.5;
    double _volume     = 0.5;
    bool _showBrightnessHUD = false;
    bool _showVolumeHUD     = false;
    Offset? _dragStartPos;
    Timer? _hudTimer;

    // ── Double-tap skip ────────────────────────────────────────────────────────
    int   _doubleTapCount = 0;
    bool? _doubleTapRight;
    Timer? _doubleTapResetTimer;
    // Portrait: HUD flèches latérales animées (style YouTube)
    bool _showLeftSkipHUD  = false;
    bool _showRightSkipHUD = false;
    Timer? _skipHudTimer;
    Timer? _seekDebounceTimer;
    int   _accumulatedSeekDelta = 0;
    int  _skipHudSeconds   = 15;

    // ── Horizontal seek (swipe timeline) ─────────────────────────────────────
    double? _horizDragStartX;
    Duration _horizSeekStartPos = Duration.zero;
    int _horizSeekDelta = 0;
    bool _showSeekSwipeHUD = false;

    @override
    void initState() {
      super.initState();
      // Immediately sync external notifier so back/aide buttons match initial state
      widget.controlsNotifier?.value = _showControls;
      _resetHideTimer();
      _initMedia();
    }

    Future<void> _initMedia() async {
      try { _brightness = await ScreenBrightness().current; } catch (_) {}
      try {
        // Hide the native OS volume overlay (Android/iOS) — we draw our own
        // in-app volume HUD, so the system one must not appear on top of it.
        VolumeController.instance.showSystemUI = false;
        _volume = await VolumeController.instance.getVolume();
      } catch (_) {}
    }

    @override
    void dispose() {
      _hideTimer?.cancel();
      _hudTimer?.cancel();
      _doubleTapResetTimer?.cancel();
      _skipHudTimer?.cancel();
      _seekDebounceTimer?.cancel();
      super.dispose();
    }

    void _setVisible(bool v) {
      setState(() => _showControls = v);
      widget.controlsNotifier?.value = v;
    }

    void _resetHideTimer() {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _setVisible(false);
      });
    }

    void _onTap() {
      _setVisible(!_showControls);
      if (_showControls) _resetHideTimer();
      else _hideTimer?.cancel();
    }

    void _seek(int deltaSeconds) {
      final pos = widget.player.state.position;
      final dur = widget.player.state.duration;
      final next = pos + Duration(seconds: deltaSeconds);
      widget.player.seek(next.isNegative ? Duration.zero : (next > dur ? dur : next));
    }

    void _handleDoubleTap({required bool isRight}) {
      _doubleTapResetTimer?.cancel();
      if (_doubleTapRight != null && _doubleTapRight != isRight) {
        _doubleTapCount = 0;
        _accumulatedSeekDelta = 0;
      }
      _doubleTapRight = isRight;
      _doubleTapCount = (_doubleTapCount + 1).clamp(1, 5);
      final increment = 15 * (1 << (_doubleTapCount - 1).clamp(0, 4));
      _accumulatedSeekDelta += isRight ? increment : -increment;
      _skipHudSeconds = _accumulatedSeekDelta.abs();

      // Debounce: one seek per tap burst, prevents mpv RAM spikes
      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = Timer(const Duration(milliseconds: 120), () {
        if (mounted) { _seek(_accumulatedSeekDelta); _accumulatedSeekDelta = 0; }
      });

      // Portrait: flèches latérales animées (style YouTube)
      _skipHudTimer?.cancel();
      setState(() {
        _showLeftSkipHUD  = !isRight;
        _showRightSkipHUD = isRight;
      });
      _skipHudTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() { _showLeftSkipHUD = false; _showRightSkipHUD = false; });
        }
      });

      _doubleTapResetTimer = Timer(const Duration(milliseconds: 1000), () {
        _doubleTapCount = 0; _doubleTapRight = null; _accumulatedSeekDelta = 0;
      });
    }

    // ── Horizontal drag → seek timeline ──────────────────────────────────────
    void _onHorizDragStart(DragStartDetails d) {
      _horizDragStartX = d.globalPosition.dx;
      _horizSeekStartPos = widget.player.state.position;
      _horizSeekDelta = 0;
      _hideTimer?.cancel();
    }

    void _onHorizDragUpdate(DragUpdateDetails d, Size size) {
      if (_horizDragStartX == null) return;
      final dx = d.globalPosition.dx - _horizDragStartX!;
      final dur = widget.player.state.duration.inSeconds;
      if (dur <= 0) return;
      // Vitesse adaptative : ~1/4 de la durée par swipe pleine largeur.
      final secondsPerScreen =
          (widget.player.state.duration.inSeconds / 4).clamp(20.0, 900.0);
      _horizSeekDelta = (dx / size.width * secondsPerScreen).round();
      setState(() => _showSeekSwipeHUD = true);
    }

    void _onHorizDragEnd(DragEndDetails _) {
      if (_horizDragStartX != null && _horizSeekDelta != 0) {
        final dur = widget.player.state.duration;
        final next = _horizSeekStartPos + Duration(seconds: _horizSeekDelta);
        final clamped = next < Duration.zero ? Duration.zero : (next > dur ? dur : next);
        widget.player.seek(clamped);
      }
      _horizDragStartX = null;
      _horizSeekDelta = 0;
      setState(() => _showSeekSwipeHUD = false);
      _resetHideTimer();
    }

    String _fmtPos(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    Widget _buildSeekSwipeHUD() {
      final pos = _horizSeekStartPos + Duration(seconds: _horizSeekDelta);
      final dur = widget.player.state.duration;
      final clamped = pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos);
      final sign = _horizSeekDelta >= 0 ? '+' : '';
      // Pilule minimale centrée au-dessus de la barre de progression
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_horizSeekDelta >= 0 ? Broken.forward : Broken.backward,
                color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Text('$sign${_horizSeekDelta}s',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Text(_fmtPos(clamped), style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      );
    }

    void _handleSwipeDrag(DragUpdateDetails d, Size size) {
      final startX = _dragStartPos?.dx ?? d.globalPosition.dx;
      final dy     = d.delta.dy;
      final isLeft = startX < size.width / 2;
      if (isLeft) {
        final next = (_brightness - dy / size.height * 2.5).clamp(0.0, 1.0);
        _brightness = next;
        try { ScreenBrightness().setScreenBrightness(next); } catch (_) {}
        _hudTimer?.cancel();
        setState(() { _showBrightnessHUD = true; _showVolumeHUD = false; });
        _hudTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showBrightnessHUD = false);
        });
      } else {
        // Volume — up to 200% (extra gain via player, hardware caps at 100%)
        final next = (_volume - dy / size.height * 2.5).clamp(0.0, 2.0);
        _volume = next;
        try { VolumeController.instance.setVolume(next.clamp(0.0, 1.0)); } catch (_) {}
        widget.player.setVolume(next * 100);
        _hudTimer?.cancel();
        setState(() { _showVolumeHUD = true; _showBrightnessHUD = false; });
        _hudTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showVolumeHUD = false);
        });
      }
    }

    // ── Pilule Luminosité/Volume — horizontale, en haut au centre ────────────
    Widget _buildTopMediaHud({required IconData icon, required double value}) {
      final clamped = value.clamp(0.0, 2.0);
      final fill    = (clamped / 2).clamp(0.0, 1.0);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(opacity: t, child: child),
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(icon, color: clamped > 1.0 ? Colors.orangeAccent : Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(children: [
                      Container(color: Colors.white24),
                      FractionallySizedBox(
                        widthFactor: fill,
                        alignment: Alignment.centerLeft,
                        child: Container(color: clamped > 1.0 ? Colors.orangeAccent : Colors.white),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(value * 100).round()}%',
                  style: TextStyle(
                    color: clamped > 1.0 ? Colors.orangeAccent : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      );
    }

    // Skip HUD double-tap — "+15 ›" propre et animé (pas de demi-arc)
    Widget _buildSkipHUD({required bool isRight, required int seconds}) {
      final label = '${isRight ? '+' : '-'}${seconds.abs()}';
      return TweenAnimationBuilder<double>(
        key: ValueKey('fs_skip_${isRight}_$seconds'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(isRight ? 16 * (1 - t) : -16 * (1 - t), 0),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(isRight ? Broken.forward : Broken.backward, color: Colors.white, size: 22),
          ),
        ]),
      );
    }

    @override
    Widget build(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final safeTop = MediaQuery.of(context).padding.top;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (d) {
          _dragStartPos = d.globalPosition;
          _hideTimer?.cancel();
        },
        onVerticalDragUpdate: (d) => _handleSwipeDrag(d, size),
        onVerticalDragEnd: (_) { _dragStartPos = null; if (!_showBrightnessHUD && !_showVolumeHUD) _resetHideTimer(); },
        onHorizontalDragStart: _onHorizDragStart,
        onHorizontalDragUpdate: (d) => _onHorizDragUpdate(d, size),
        onHorizontalDragEnd: _onHorizDragEnd,
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
            // ── Left zone 30% — double-tap = seek -15, tap = toggle controls ──
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: size.width * 0.3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _handleDoubleTap(isRight: false),
                onTap: _onTap,
              ),
            ),
            // ── Centre 40% — double-tap = pause/resume, tap = toggle controls ─
            Positioned(
              left: size.width * 0.3, top: 0, bottom: 0,
              width: size.width * 0.4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () {
                  widget.player.playOrPause();
                  _resetHideTimer();
                },
                onTap: _onTap,
              ),
            ),
            // ── Right zone 30% — double-tap = seek +15, tap = toggle controls ─
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: size.width * 0.3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _handleDoubleTap(isRight: true),
                onTap: _onTap,
              ),
            ),
            // ── Skip HUD double-tap — flèches latérales animées (style YouTube)
            if (_showLeftSkipHUD)
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: size.width * 0.3,
                child: IgnorePointer(
                  child: Center(
                    child: _buildSkipHUD(isRight: false, seconds: _skipHudSeconds),
                  ),
                ),
              ),
            if (_showRightSkipHUD)
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: size.width * 0.3,
                child: IgnorePointer(
                  child: Center(
                    child: _buildSkipHUD(isRight: true, seconds: _skipHudSeconds),
                  ),
                ),
              ),
            // ── Luminosité/Volume — pilule horizontale en HAUT au centre ─────
            if (_showBrightnessHUD || _showVolumeHUD)
              Positioned(
                top: safeTop + 8, left: 0, right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _showBrightnessHUD
                        ? _buildTopMediaHud(icon: Broken.sun, value: _brightness)
                        : _buildTopMediaHud(
                            icon: _volume <= 0
                                ? Broken.volume_slash
                                : _volume < 0.5
                                    ? Broken.volume_low
                                    : Broken.volume_high,
                            value: _volume),
                  ),
                ),
              ),
            // ── Seek swipe HUD — juste au-dessus de la barre de progression ──
            if (_showSeekSwipeHUD)
              Positioned(
                bottom: 52, left: 0, right: 0,
                child: IgnorePointer(
                  child: Center(child: _buildSeekSwipeHUD()),
                ),
              ),
            // ── Icône Paramètres haut-droite (portrait only) ─────────────────
            if (_showControls)
              Positioned(
                top: safeTop + 2,
                right: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Ouvre le lecteur plein-écran (paramètres complets)
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FullscreenPlayerPage(
                            controller: widget.controller,
                            player: widget.player,
                            title: widget.title,
                            currentChapterId: widget.currentChapterId,
                            loadedVideos: widget.loadedVideos,
                            onSwitchQuality: widget.onSwitchQuality,
                            selectedQuality: widget.selectedQuality,
                            onPrevEpisode: widget.onPrevEpisode,
                            onNextEpisode: widget.onNextEpisode,
                            chapters: widget.chapters,
                            onEpisodeTap: widget.onEpisodeTap,
                            fallbackCoverUrl: widget.coverUrl,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Broken.setting_2, color: Colors.white70, size: 20),
                  ),
                ),
              ),
            // ── Inline controls bas — visible quand _showControls ─────────────
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
                    onPrevEpisode: widget.onPrevEpisode,
                    onNextEpisode: widget.onNextEpisode,
                    chapters: widget.chapters,
                    onEpisodeTap: widget.onEpisodeTap,
                    fallbackCoverUrl: widget.coverUrl,
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
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final List<Chapter> chapters;
  final void Function(Chapter)? onEpisodeTap;
  final String? fallbackCoverUrl;

  const _InlineControls({
    required this.player,
    required this.controller,
    required this.accent,
    required this.title,
    required this.seekingNotifier,
    this.loadedVideos = const [],
    this.onSwitchQuality,
    this.selectedQuality,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.chapters = const [],
    this.onEpisodeTap,
    this.fallbackCoverUrl,
  });

  @override
  State<_InlineControls> createState() => _InlineControlsState();
}

class _InlineControlsState extends State<_InlineControls> {
  bool _dragActive = false;
  double _dragValue = 0.0;

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
              onPrevEpisode: widget.onPrevEpisode,
              onNextEpisode: widget.onNextEpisode,
              chapters: widget.chapters,
              onEpisodeTap: widget.onEpisodeTap,
              fallbackCoverUrl: widget.fallbackCoverUrl,
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
          onPrevEpisode: widget.onPrevEpisode,
          onNextEpisode: widget.onNextEpisode,
          chapters: widget.chapters,
          onEpisodeTap: widget.onEpisodeTap,
          fallbackCoverUrl: widget.fallbackCoverUrl,
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
                      ? Broken.pause
                      : Broken.play,
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
                final bufFrac = dur.inMilliseconds > 0
                    ? (_p.state.buffer.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                final displayValue = _dragActive ? _dragValue : progress;
                final previewDur = dur.inMilliseconds > 0
                    ? Duration(milliseconds: (displayValue * dur.inMilliseconds).round())
                    : Duration.zero;
                return LayoutBuilder(
                  builder: (_, constraints) {
                    final thumbX = displayValue * constraints.maxWidth;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 11),
                            activeTrackColor: widget.accent,
                            inactiveTrackColor: Colors.white24,
                            secondaryActiveTrackColor: Colors.white54,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: displayValue,
                            secondaryTrackValue: bufFrac,
                            onChangeStart: (v) {
                              setState(() { _dragActive = true; _dragValue = v; });
                              widget.seekingNotifier.value = true;
                            },
                            onChanged: (v) => setState(() => _dragValue = v),
                            onChangeEnd: (v) {
                              if (dur.inMilliseconds > 0) {
                                _p.seek(Duration(
                                    milliseconds: (v * dur.inMilliseconds).round()));
                              }
                              setState(() => _dragActive = false);
                              widget.seekingNotifier.value = false;
                            },
                          ),
                        ),
                        if (_dragActive)
                          Positioned(
                            left: (thumbX - 26).clamp(0.0, constraints.maxWidth - 52),
                            bottom: 30,
                            child: IgnorePointer(
                              child: Container(
                                width: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _fmt(previewDur),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
                Broken.screenmirroring,
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
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _posSub;
  Duration? _bufStartPos;

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
          _bufStartPos = widget.player.state.position;
          _bufDebounce = Timer(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _anim = 'loading');
          });
        } else {
          // Short delay avoids flicker on very brief rebuffers
          _bufDebounce = Timer(const Duration(milliseconds: 120), () {
            if (mounted) setState(() => _anim = null);
          });
        }
      }
    });
    // mpv sometimes never emits buffering=false at EOS; clear overlay ourselves
    _completedSub = widget.player.stream.completed.listen((done) {
      if (!mounted || !done) return;
      _bufDebounce?.cancel();
      setState(() => _anim = null);
    });
    // Sécurité: si la position avance pendant l'affichage du buffering, c'est
    // que mpv n'a pas émis buffering=false → on masque les points de suite.
    _posSub = widget.player.stream.position.listen((pos) {
      if (!mounted) return;
      if (_anim == 'loading' && widget.player.state.playing &&
          _bufStartPos != null &&
          pos > _bufStartPos! + const Duration(milliseconds: 800)) {
        setState(() => _anim = null);
      }
    });
  }

  @override
  void dispose() {
    _bufDebounce?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _completedSub?.cancel();
    _posSub?.cancel();
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
              : const _BufferingDotsIndicator(), // bufferFrac omitted → no % label in inline banner
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

// ─── PLAYit-style More Panel ──────────────────────────────────────────────────

class _MorePanel extends StatefulWidget {
  final Player player;
  final Color accent;
  final bool loopOne, loopAll, mirrorMode, nightMode, abRepeatOn, audioOnly;
  final Duration? abStart, abEnd;
  final ValueChanged<bool> onLoopOne, onLoopAll, onMirror, onNight, onAbRepeat, onAudioOnly;
  final VoidCallback onAbStartSet, onAbEndSet, onClose;

  const _MorePanel({
    required this.player,
    required this.accent,
    required this.loopOne,
    required this.loopAll,
    required this.mirrorMode,
    required this.nightMode,
    required this.abRepeatOn,
    required this.abStart,
    required this.abEnd,
    required this.audioOnly,
    required this.onLoopOne,
    required this.onLoopAll,
    required this.onMirror,
    required this.onNight,
    required this.onAbRepeat,
    required this.onAudioOnly,
    required this.onAbStartSet,
    required this.onAbEndSet,
    required this.onClose,
  });

  @override
  State<_MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends State<_MorePanel> {
  double _brightness = 0.5;
  static const Color _kBlue = Color(0xFF2E6CEF);

  // Toggle tile — same visual language as the subtitle panel tiles.
  Widget _toggleTile(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? _kBlue.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _kBlue : Colors.white12, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: active ? _kBlue : Colors.white, fontSize: 13)),
            ),
            Icon(
              active ? Broken.tick_circle : Icons.radio_button_unchecked_rounded,
              color: active ? _kBlue : Colors.white38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ScreenBrightness.instance.current.then((v) { if (mounted) setState(() => _brightness = v); }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.of(context).padding;
    final panelW   = MediaQuery.of(context).size.width * 0.58;
    final audioTracks = widget.player.state.tracks.audio;
    final curAudio    = widget.player.state.track.audio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Container(
        color: Colors.black38,
        alignment: Alignment.centerRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, off, child) => Transform.translate(
              offset: Offset(off.dx * panelW, 0),
              child: child,
            ),
            child: Container(
              width: panelW,
              height: double.infinity,
              color: const Color(0xEE1A1A1A),
              padding: EdgeInsets.fromLTRB(14, safeArea.top + 10, 14, safeArea.bottom + 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text('Plus', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 14),
                    // Row 1: Audio tracks + Mirror + Night + Minuteur
                    _toggleTile('Audio seul', widget.audioOnly, () => widget.onAudioOnly(!widget.audioOnly)),
                    _toggleTile('Miroir', widget.mirrorMode, () => widget.onMirror(!widget.mirrorMode)),
                    _toggleTile('Mode nuit', widget.nightMode, () => widget.onNight(!widget.nightMode)),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    // Loop section
                    const Text('Boucle', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _toggleTile('Épisode', widget.loopOne, () => widget.onLoopOne(!widget.loopOne))),
                        const SizedBox(width: 8),
                        Expanded(child: _toggleTile('Tout', widget.loopAll, () => widget.onLoopAll(!widget.loopAll))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    // AB Repeat section
                    const Text('AB Répétition', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onAbStartSet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.abStart != null ? widget.accent.withValues(alpha: 0.2) : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: widget.abStart != null ? Border.all(color: widget.accent, width: 1) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.abStart != null
                                    ? 'A: ${_fmtDur(widget.abStart!)}'
                                    : 'Déf. A',
                                style: TextStyle(color: widget.abStart != null ? widget.accent : Colors.white60, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onAbEndSet,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.abEnd != null ? widget.accent.withValues(alpha: 0.2) : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: widget.abEnd != null ? Border.all(color: widget.accent, width: 1) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.abEnd != null
                                    ? 'B: ${_fmtDur(widget.abEnd!)}'
                                    : 'Déf. B',
                                style: TextStyle(color: widget.abEnd != null ? widget.accent : Colors.white60, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => widget.onAbRepeat(!widget.abRepeatOn),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.abRepeatOn ? widget.accent.withValues(alpha: 0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: widget.abRepeatOn ? Border.all(color: widget.accent, width: 1) : null,
                            ),
                            child: Icon(Broken.repeate_music,
                                color: widget.abRepeatOn ? widget.accent : Colors.white60, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    // Audio track
                    const Text('Piste audio', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (audioTracks.isEmpty)
                      const Text('Aucune piste', style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: audioTracks.asMap().entries.map((e) {
                          final i = e.key; final t = e.value;
                          final sel = t.id == curAudio.id;
                          return GestureDetector(
                            onTap: () { widget.player.setAudioTrack(t); setState(() {}); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? widget.accent.withValues(alpha: 0.2) : Colors.white10,
                                borderRadius: BorderRadius.circular(20),
                                border: sel ? Border.all(color: widget.accent) : null,
                              ),
                              child: Text(_audioTrackLabel(t, i),
                                  style: TextStyle(color: sel ? widget.accent : Colors.white70, fontSize: 12)),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    // Brightness slider
                    const Text('Luminosité', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Broken.sun, color: Colors.white38, size: 16),
                        Expanded(
                          child: Slider(
                            value: _brightness,
                            min: 0.0, max: 1.0,
                            activeColor: widget.accent,
                            inactiveColor: Colors.white24,
                            onChanged: (v) {
                              setState(() => _brightness = v);
                              ScreenBrightness.instance.setApplicationScreenBrightness(v).catchError((_) {});
                            },
                          ),
                        ),
                        const Icon(Broken.sun, color: Colors.white70, size: 16),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Episode list panel ───────────────────────────────────────────────────────

class _EpisodePanel extends StatefulWidget {
  final List<Chapter> chapters;
  final int? currentChapterId;
  final Color accent;
  final void Function(Chapter) onTap;
  final VoidCallback onClose;
  final String? fallbackCoverUrl;

  const _EpisodePanel({
    required this.chapters,
    required this.currentChapterId,
    required this.accent,
    required this.onTap,
    required this.onClose,
    this.fallbackCoverUrl,
  });

  @override
  State<_EpisodePanel> createState() => _EpisodePanelState();
}

class _EpisodePanelState extends State<_EpisodePanel> {
  final ScrollController _scroll = ScrollController();
  bool _didAutoScroll = false;

  static const _noSeasonSentinel = -999999;

  // S1E12 / S01E02 / Season 3 … → saison ; E12/Ep.12/Episode 12 → numéro.
  static final _seasonRe =
      RegExp(r'(?:[sS]|season\s*)(\d{1,2})', caseSensitive: false);
  static final _epRe =
      RegExp(r'(?:[eE]|[eE]p\.?|[eE]pisode\s*)(\d{1,4})', caseSensitive: false);

  int? _seasonOf(Chapter ch) {
    final m = _seasonRe.firstMatch(ch.name ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  int? _epNumOf(Chapter ch) {
    final name = ch.name ?? '';
    // Éviter que le "S" de "S1" soit consommé : chercher après le marqueur saison.
    for (final m in _epRe.allMatches(name)) {
      final before = name.substring(0, m.start);
      if (!before.toUpperCase().endsWith('S')) {
        return int.tryParse(m.group(1)!);
      }
    }
    return null;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.of(context).padding;
    final panelW = MediaQuery.of(context).size.width * 0.55;

    // ── Regroupement par saison (ordre préservé) → liste plate de rows ──
    final sections = <int?, List<Chapter>>{};
    for (final ch in widget.chapters) {
      sections.putIfAbsent(_seasonOf(ch), () => []).add(ch);
    }
    final rows = <_EpRow>[];
    for (final entry in sections.entries) {
      final s = entry.key;
      // Entête affiché dès qu'on a une vraie saison, ou si mélange avec/sans saison.
      if (s != null || sections.length > 1) {
        rows.add(_EpRow(season: s));
      }
      for (final ch in entry.value) {
        rows.add(_EpRow(chapter: ch));
      }
    }

    // ── Auto-scroll vers l'épisode en cours ──
    final curRowIdx = rows.indexWhere(
        (r) => r.chapter?.id == widget.currentChapterId);
    if (curRowIdx > 0 && !_didAutoScroll) {
      _didAutoScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        double target = 0;
        for (var i = 0; i < curRowIdx; i++) {
          target += rows[i].chapter != null ? 86.0 : 40.0;
        }
        _scroll.jumpTo(
            target.clamp(0.0, _scroll.position.maxScrollExtent));
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Container(
        color: Colors.black38,
        alignment: Alignment.centerRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, off, child) => Transform.translate(
                offset: Offset(off.dx * panelW, 0), child: child),
            child: Container(
              width: panelW,
              height: double.infinity,
              color: const Color(0xEE1A1A1A),
              child: Column(
                children: [
                  SizedBox(height: safeArea.top + 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Text('Épisodes',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text('Aucun épisode',
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            controller: _scroll,
                            padding:
                                EdgeInsets.only(bottom: safeArea.bottom + 8),
                            itemCount: rows.length,
                            itemBuilder: (_, i) {
                              final row = rows[i];
                              if (row.season != _noSeasonSentinel) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 14, 14, 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: widget.accent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Saison ${row.season}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return _buildTile(row.chapter!);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(Chapter ch) {
    final isCur = ch.id == widget.currentChapterId;
    final epNum = _epNumOf(ch);
    final hasThumb = ch.thumbnailUrl?.isNotEmpty ?? false;
    final coverUrl = hasThumb ? ch.thumbnailUrl! : widget.fallbackCoverUrl;
    return GestureDetector(
      onTap: () => widget.onTap(ch),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCur
              ? widget.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCur
                ? widget.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // ── Cover épisode, fallback cover de l'entrée ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 96,
                    height: 54,
                    color: Colors.white.withValues(alpha: 0.07),
                    child: (coverUrl?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: coverUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Broken.video,
                                  color: Colors.white24, size: 20),
                            ),
                          )
                        : const Center(
                            child: Icon(Broken.video,
                                color: Colors.white24, size: 20),
                          ),
                  ),
                ),
                if (isCur)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: widget.accent, shape: BoxShape.circle),
                      child: Icon(Broken.play,
                          color: Colors.black87, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // ── Nom + meta ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ch.name ?? 'Épisode ${epNum ?? '?'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCur ? widget.accent : Colors.white,
                      fontSize: 13,
                      fontWeight:
                          isCur ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ch.duration?.isNotEmpty == true
                        ? ch.duration!
                        : 'Épisode ${epNum ?? '?'}',
                    style: TextStyle(
                      color: isCur
                          ? widget.accent.withValues(alpha: 0.8)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                'EP ${epNum ?? '?'}',
                style: TextStyle(
                  color: isCur ? widget.accent : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Une ligne du panneau : entête de saison ou épisode.
class _EpRow {
  final Chapter? chapter;
  final int season;
  _EpRow({this.chapter, int? season})
      : season = season ?? _EpisodePanelState._noSeasonSentinel;
}

// ─── Auto Next Episode Card (Netflix-style) ────────────────────────────────────

class _NextEpCard extends StatelessWidget {
  final int countdown;
  final Color accent;
  final VoidCallback onNow;
  final VoidCallback onCancel;

  const _NextEpCard({
    required this.countdown,
    required this.accent,
    required this.onNow,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(30 * (1 - t), 0), child: child),
      ),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xEE1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Broken.next, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Épisode suivant dans',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$countdown',
                    style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onNow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Lire maintenant',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: onCancel,
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gesture Hint Overlay (first launch) ──────────────────────────────────────

class _GestureHintOverlay extends StatelessWidget {
  const _GestureHintOverlay();

  Widget _hint(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestes du lecteur',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _hint(Icons.touch_app_outlined,       'Double tap → avancer / reculer'),
              _hint(Icons.swipe_right_alt_outlined,  'Swipe → seek (n\'importe où)'),
              _hint(Broken.sun,'Swipe gauche → luminosité'),
              _hint(Broken.volume_high,        'Swipe droite → volume'),
              _hint(Icons.speed_outlined,            'Maintenir droite → vitesse ×2'),
              _hint(Broken.lock,      'Cadenas → verrouiller écran'),
              const SizedBox(height: 8),
              const Text(
                'Ce tutoriel n\'apparaît qu\'une fois.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 3-dots buffering indicator ───────────────────────────────────────────────
// ─── Buffering overlay ─────────────────────────────────────────────────────────
// Uses the same bouncing-dots animation as the initial-load indicator
// (_ThreeDotsAnimation in watch_detail_view.dart).  Shows how much of the
// stream is buffered (0–100 %) so the user can gauge when playback resumes.

class _BufferingDotsIndicator extends StatelessWidget {
  /// Fraction of total duration already buffered (0.0–1.0).
  /// Pass –1 to omit the percentage label.
  final double bufferFrac;
  const _BufferingDotsIndicator({this.bufferFrac = -1});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PlayerJumpingDots(),
        if (bufferFrac >= 0) ...[
          const SizedBox(height: 8),
          Text(
            '${(bufferFrac * 100).round()} %',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bouncing-dots animation (same visual as _ThreeDotsAnimation in the detail
/// view, duplicated here to avoid a circular import).
class _PlayerJumpingDots extends StatefulWidget {
  const _PlayerJumpingDots();
  @override
  State<_PlayerJumpingDots> createState() => _PlayerJumpingDotsState();
}

class _PlayerJumpingDotsState extends State<_PlayerJumpingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _ctrls.add(c);
      _anims.add(Tween<double>(begin: 0, end: -9).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ));
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Reel player — TikTok/MovieBox "TV courte" style fullscreen page ─────────
//
// Full-bleed vertical (9:16) playback with a top bar (back + episode label),
// a right-side action rail (download / bookmark / share), a bottom info
// block (poster + title + synopsis), and a bottom control bar with an
// episode-picker pill, speed, quality and language shortcuts — matching the
// MovieBox reel player reference screenshot.
class _ReelPlayerPage extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final List<wt.Video> loadedVideos;
  final String? selectedQuality;
  final Future<void> Function(wt.Video)? onSwitchQuality;
  final List<Chapter> chapters;
  final Chapter currentChapter;
  final void Function(Chapter)? onEpisodeTap;

  const _ReelPlayerPage({
    required this.player,
    required this.controller,
    required this.title,
    required this.chapters,
    required this.currentChapter,
    this.loadedVideos = const [],
    this.selectedQuality,
    this.onSwitchQuality,
    this.onEpisodeTap,
  });

  @override
  State<_ReelPlayerPage> createState() => _ReelPlayerPageState();
}

class _ReelPlayerPageState extends State<_ReelPlayerPage> {
  bool _showControls = true;
  Timer? _hideTimer;
  bool _bookmarked = false;
  late Chapter _current;
  late String? _quality;
  double _speed = 1.0;

  Player get _p => widget.player;

  @override
  void initState() {
    super.initState();
    _current = widget.currentChapter;
    _quality = widget.selectedQuality;
    _bookmarked = _current.isBookmarked ?? false;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
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

  List<Chapter> get _sorted {
    final list = [...widget.chapters];
    list.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return list;
  }

  void _selectEpisode(Chapter c) {
    setState(() => _current = c);
    widget.onEpisodeTap?.call(c);
  }

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    _current.isBookmarked = _bookmarked;
    try {
      isar.writeTxnSync(() => isar.chapters.putSync(_current));
    } catch (_) {}
  }

  void _share() {
    final url = _current.url ?? '';
    if (url.isNotEmpty) SharePlus.instance.share(ShareParams(text: url));
  }

  void _setSpeed(double v) {
    setState(() => _speed = v);
    _p.setRate(v);
    Navigator.of(context).pop();
  }

  Future<void> _setQuality(wt.Video v) async {
    Navigator.of(context).pop();
    setState(() => _quality = v.quality);
    await widget.onSwitchQuality?.call(v);
  }

  void _openEpisodeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReelEpisodeSheet(
        episodes: _sorted,
        current: _current,
        onTap: (c) {
          Navigator.of(context).pop();
          _selectEpisode(c);
        },
      ),
    );
  }

  void _openSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReelPickerSheet(
        title: 'Vitesse de lecture',
        options: _kAllSpeeds.map((s) => '${s}x').toList(),
        selected: '${_speed}x',
        onSelect: (s) => _setSpeed(double.parse(s.replaceAll('x', ''))),
      ),
    );
  }

  void _openQualitySheet() {
    if (widget.loadedVideos.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReelPickerSheet(
        title: 'Qualité',
        options: widget.loadedVideos.map((v) => v.quality ?? '').toList(),
        selected: _quality ?? '',
        onSelect: (label) {
          final v = widget.loadedVideos.firstWhere(
            (v) => v.quality == label,
            orElse: () => widget.loadedVideos.first,
          );
          _setQuality(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        SystemChrome.setPreferredOrientations([]);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video (vertical, cropped to fill like a real reel) ──────────
              Video(
                controller: widget.controller,
                fit: BoxFit.cover,
                controls: NoVideoControls,
              ),

              // ── Bottom gradient for legibility ───────────────────────────────
              const Positioned(
                left: 0, right: 0, bottom: 0, height: 260,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xEE000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Center play/pause tap feedback ───────────────────────────────
              IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: StreamBuilder<bool>(
                      stream: _p.stream.playing,
                      initialData: _p.state.playing,
                      builder: (_, snap) => GestureDetector(
                        onTap: () { _p.playOrPause(); _resetHideTimer(); },
                        child: Icon(
                          (snap.data ?? false) ? Broken.pause : Broken.play,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top bar: back + episode label ────────────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPad + 4, left: 4, right: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Broken.arrow_left, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            _current.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Right action rail: download / bookmark / share ───────────────
              Positioned(
                right: 8,
                bottom: 120 + botPad,
                child: Column(
                  children: [
                    _ReelActionButton(
                      icon: Broken.document_download,
                      label: 'Télécharger',
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),
                    _ReelActionButton(
                      icon: _bookmarked ? Broken.bookmark : Broken.bookmark_2,
                      iconColor: _bookmarked ? const Color(0xFFFFC107) : Colors.white,
                      label: '',
                      onTap: _toggleBookmark,
                    ),
                    const SizedBox(height: 18),
                    _ReelActionButton(
                      icon: Broken.share,
                      label: 'Partager',
                      onTap: _share,
                    ),
                  ],
                ),
              ),

              // ── Bottom info + controls bar ───────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: botPad + 6,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster + title + synopsis
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 90, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((_current.thumbnailUrl ?? '').isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    _current.thumbnailUrl!,
                                    width: 34, height: 46, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(width: 34, height: 46),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    if ((_current.description ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '${_current.name ?? ''} | ${_current.description}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Episode picker pill
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: GestureDetector(
                            onTap: _openEpisodeSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.layers_outlined, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_current.name ?? ''} / EP${_sorted.length.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Broken.arrow_up_3, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Seek bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: StreamBuilder<Duration>(
                            stream: _p.stream.position,
                            initialData: _p.state.position,
                            builder: (_, snap) {
                              final pos = snap.data ?? Duration.zero;
                              final dur = _p.state.duration;
                              final progress = dur.inMilliseconds > 0
                                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0;
                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: (v) {
                                    if (dur.inMilliseconds > 0) {
                                      _p.seek(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        // Speed / quality / language row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _openSpeedSheet,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Broken.speedometer, color: Colors.white70, size: 15),
                                    const SizedBox(width: 4),
                                    Text('${_speed}x', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _openQualitySheet,
                                child: Text(
                                  _quality ?? 'Auto',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Broken.subtitle, color: Colors.white70, size: 15),
                                  SizedBox(width: 4),
                                  Text('Langue', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 30, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Episode picker bottom sheet (reel mode) ──────────────────────────────────
class _ReelEpisodeSheet extends StatelessWidget {
  final List<Chapter> episodes;
  final Chapter current;
  final void Function(Chapter) onTap;

  const _ReelEpisodeSheet({
    required this.episodes,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(
          color: Color(0xFF181818),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('EP01 / EP${episodes.length.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                ),
                itemCount: episodes.length,
                itemBuilder: (_, i) {
                  final ep = episodes[i];
                  final active = ep.id == current.id;
                  return GestureDetector(
                    onTap: () => onTap(ep),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFFF5A36) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic picker sheet (speed / quality) for the reel player ──────────────
class _ReelPickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  const _ReelPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        decoration: const BoxDecoration(
          color: Color(0xFF181818),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final active = o == selected;
                  return ListTile(
                    onTap: () => onSelect(o),
                    title: Text(o, style: TextStyle(color: active ? const Color(0xFFFF5A36) : Colors.white, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
                    trailing: active ? const Icon(Icons.check, color: Color(0xFFFF5A36), size: 18) : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Seekbar miniature preview (YouTube-style) ────────────────────────────────
// Second player muet dédié aux vignettes : on ouvre le même flux en pause,
// on seek à la position demandée (debounce) puis on capture la frame décodée.
class _SeekThumbPreview {
  Player? _player;
  String? _loadedUrl;
  bool _ready = false;
  int _seq = 0;
  Timer? _debounce;

  final ValueNotifier<Uint8List?> frame = ValueNotifier(null);

  void request({
    required String url,
    required Map<String, String>? headers,
    required Duration position,
  }) {
    _seq++;
    final mySeq = _seq;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () async {
      try {
        final p = _player ??= Player(
            configuration:
                const PlayerConfiguration(bufferSize: 4 * 1024 * 1024));
        if (_loadedUrl != url || !_ready) {
          _loadedUrl = url;
          _ready = false;
          try { await p.setVolume(0.0); } catch (_) {}
          try { await (p.platform as dynamic).setProperty('audio', 'no'); } catch (_) {}
          await p.open(Media(url, httpHeaders: headers), play: false);
          // Attend que le flux soit prêt (durée connue) avant de seeker.
          await p.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(const Duration(seconds: 10), onTimeout: () => Duration.zero);
          _ready = true;
        }
        if (mySeq != _seq) return;
        await p.seek(position);
        // Laisse mpv décoder la frame demandée.
        await Future.delayed(const Duration(milliseconds: 180));
        if (mySeq != _seq) return;
        final shot = await p.screenshot();
        if (shot != null && mySeq == _seq) {
          frame.value = shot;
        }
      } catch (_) {}
    });
  }

  void clearRequest() {
    _seq++;
    _debounce?.cancel();
  }

  void dispose() {
    _seq++;
    _debounce?.cancel();
    try { _player?.dispose(); } catch (_) {}
    frame.dispose();
  }
}
