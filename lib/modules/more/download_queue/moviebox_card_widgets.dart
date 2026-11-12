import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:watchtower/utils/mosaic_cover.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/utils/cached_network.dart';

// MovieBox-style palette shared by the download queue cards.
const Color mbGreen = Color(0xFF27C46B);
const Color mbTeal = Color(0xFF00BFA5);
const Color mbAmber = Color(0xFFFFB300);
const Color mbRed = Color(0xFFFF5252);

/// Poster thumbnail: centered play overlay for video rows and a bottom-left
/// source badge on a dark scrim — MovieBox signature.
class MbThumb extends StatelessWidget {
  final String? imageUrl;
  final List<dynamic>? customBytes;
  final ItemType itemType;
  final String badge;
  final bool isVideo;
  final double width;
  final double height;
  final Map<String, String>? headers;
  final int? sourceId;

  /// When set, tapping the thumbnail opens the episode (the whole poster is
  /// the tap target, not just the small play glyph).
  final VoidCallback? onTap;

  const MbThumb({
    super.key,
    required this.imageUrl,
    required this.customBytes,
    required this.itemType,
    required this.badge,
    required this.isVideo,
    this.width = 106,
    this.height = 64,
    this.headers,
    this.sourceId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // MovieBox uses a landscape preview so each queue row stays compact.
    final w = width;
    final h = height;
    final placeholder = Container(
      width: w,
      height: h,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        itemType == ItemType.anime
            ? Icons.play_circle_outline
            : itemType == ItemType.novel
            ? Icons.auto_stories_outlined
            : Icons.menu_book_outlined,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        size: 24,
      ),
    );

    Widget image = placeholder;
    if (customBytes != null && customBytes!.isNotEmpty) {
      try {
        image = Image.memory(
          Uint8List.fromList(customBytes!.cast<int>()),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      } catch (_) {}
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = MosaicAwareCover(
        url: imageUrl,
        width: w,
        height: h,
        child: cachedNetworkImage(
          imageUrl: imageUrl!,
          width: w,
          height: h,
          fit: BoxFit.cover,
          headers: headers,
          sourceId: sourceId,
          errorWidget: placeholder,
        ),
      );
    }

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (badge.isNotEmpty)
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                  constraints: const BoxConstraints(maxWidth: 116),
                  child: Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF),
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            if (isVideo)
              Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: thumb,
    );
  }
}

class MbGradientProgressBar extends StatefulWidget {
  final double? value;
  final double height;
  final bool paused;
  final bool failed;

  /// True only while this download is actually transferring. Idle, queued and
  /// finished cards pass false so their bar is a static fill instead of running
  /// the sweep/wave tickers — with dozens of rows in the queue those animations
  /// are the bulk of the frame cost (and a source of jank/OOM on a phone).
  final bool active;

  /// Golden second pass: the archive is being packed/compressed after the
  /// transfer finished. Uses a golden gradient instead of the green/teal one.
  final bool compressing;

  const MbGradientProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.paused = false,
    this.failed = false,
    this.active = true,
    this.compressing = false,
  });

  @override
  State<MbGradientProgressBar> createState() => _MbGradientProgressBarState();
}

class _MbGradientProgressBarState extends State<MbGradientProgressBar>
    with TickerProviderStateMixin {
  // "Pulse" band travelling from the left edge of the fill to its leading edge
  // while a transfer is active.
  late final AnimationController _sweep;

  // Drives the up/down wave drawn on the filled region.
  late final AnimationController _wave;

  // Progress is eased towards the latest value instead of snapping, so noisy
  // byte/page counters do not make the bar jitter on every rebuild.
  late final AnimationController _valueAnim;
  static const _valueDuration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;
  // Ignore sub-pixel target moves; they are pure counter noise.
  static const _deadband = 0.004;

  /// A jump this large is not transfer progress: it is a resume landing at the
  /// on-disk offset after the counters read 0, or a retry restarting. Easing it
  /// is the "the bar races from the left to the resume point" glitch, so such a
  /// move — and any move backwards — snaps straight to the new value.
  static const _snapThreshold = 0.12;

  double _from = 0;
  double _to = 0;

  double? get _target {
    final value = widget.value;
    if (value == null) return null;
    return value.clamp(0.0, 1.0).toDouble();
  }

  double get _displayed =>
      _from + (_to - _from) * _curve.transform(_valueAnim.value);

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final start = _target ?? 0;
    _from = start;
    _to = start;
    _valueAnim = AnimationController(
      vsync: this,
      duration: _valueDuration,
      value: 1,
    );
    if (_sweepEnabled) {
      _sweep.repeat();
      _wave.repeat();
    }
  }

  /// Whether the fill runs its wave + pulse animation.
  ///
  /// Active transfers animate; a *paused* row keeps animating too, because the
  /// paused bar is the "we will resume from here" marker — the user asked for
  /// the wave and the pulse-from-the-left on the saved position, not a frozen
  /// bar. A failed or compressing row stays static.
  bool get _sweepEnabled =>
      (widget.active || widget.paused) &&
      _target != null &&
      !widget.failed &&
      !widget.compressing;

  @override
  void didUpdateWidget(covariant MbGradientProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (target != null) {
      final delta = target - _to;
      if (delta.abs() > _snapThreshold || delta < -_deadband) {
        // Resume jump or a transient counter reset: land immediately instead
        // of sweeping across the bar.
        _valueAnim.value = 1;
        _from = target;
        _to = target;
      } else if (delta.abs() > _deadband) {
        _from = _displayed;
        _to = target;
        _valueAnim.forward(from: 0);
      }
    }
    if (_sweepEnabled) {
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      if (_sweep.isAnimating) {
        _sweep.stop();
        _sweep.value = 0;
      }
      if (_wave.isAnimating) {
        _wave.stop();
        _wave.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _wave.dispose();
    _valueAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paused = widget.paused;
    final failed = widget.failed;
    final background = paused
        ? mbAmber.withValues(alpha: 0.18)
        : failed
        ? mbRed.withValues(alpha: 0.18)
        : scheme.onSurface.withValues(alpha: 0.10);
    final gradient = failed
        ? const LinearGradient(colors: [mbRed, Color(0xFFFF7043)])
        : paused
        // A paused row marks where the transfer will resume from: a bright
        // white fill at the saved position (the user's "barre blanche là où on
        // s'est arrêté"), not the amber in-progress colour.
        ? const LinearGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFFFFFFF)],
          )
        : widget.compressing
        ? const LinearGradient(colors: [Color(0xFFF5C518), Color(0xFFE0A800)])
        : const LinearGradient(colors: [mbGreen, mbTeal]);

    if (_target == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: LinearProgressIndicator(
          value: null,
          minHeight: widget.height,
          backgroundColor: background,
          valueColor: AlwaysStoppedAnimation<Color>(gradient.colors.first),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _valueAnim,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: background),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _displayed,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The fill ripples (a shallow sine on its top edge)
                        // while the transfer is active, and is a plain bar
                        // otherwise.
                        AnimatedBuilder(
                          animation: _wave,
                          builder: (context, _) => CustomPaint(
                            painter: _FillWavePainter(
                              gradient: gradient,
                              phase: _wave.value,
                              animate: _sweepEnabled,
                            ),
                          ),
                        ),
                        if (_sweepEnabled) _buildPulse(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A soft highlight band travelling from the left of the fill to its leading
  // edge, so a stalled-looking bar still reads as "alive". On the white paused
  // fill a white band would be invisible, so the paused pulse is tinted teal.
  Widget _buildPulse() {
    final tint = widget.paused ? mbTeal : Colors.white;
    final peak = widget.paused
        ? tint.withValues(alpha: 0.55)
        : tint.withValues(alpha: 0.45);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bandWidth = width * 0.42;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) {
              final travel = -bandWidth + (width + bandWidth) * _sweep.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: travel,
                    top: 0,
                    bottom: 0,
                    width: bandWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tint.withValues(alpha: 0.0),
                            peak,
                            tint.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Paints the progress fill, optionally with a shallow travelling sine on its
/// top edge so the filled region visibly ripples while the transfer is active.
class _FillWavePainter extends CustomPainter {
  _FillWavePainter({
    required this.gradient,
    required this.phase,
    required this.animate,
  });

  final LinearGradient gradient;
  final double phase;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = gradient.createShader(
      Offset.zero & size,
    );
    if (!animate || size.height < 3) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    // Two full waves across the fill, bobbing within the bar height.
    final amplitude = size.height * 0.28;
    final mid = size.height / 2;
    final path = Path()..moveTo(0, mid);
    const step = 2.0;
    for (double x = 0; x <= size.width; x += step) {
      final t = (x / size.width) * 2 * 2 * math.pi + phase * 2 * math.pi;
      path.lineTo(x, mid + math.sin(t) * amplitude);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FillWavePainter old) =>
      old.phase != phase ||
      old.animate != animate ||
      old.gradient != gradient;
}

/// Compact circular pause/resume, retry, or open action for grouped rows.
class MbRowActions extends StatelessWidget {
  final bool isComplete;
  final bool hasFailed;
  final bool isPaused;

  /// Queued behind a concurrency limit or Wi-Fi gate: not transferring yet.
  /// Shown grey with a clock so the user can tell it apart from an active row.
  final bool isWaiting;
  final VoidCallback onPauseResume;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  const MbRowActions({
    super.key,
    required this.isComplete,
    required this.hasFailed,
    required this.isPaused,
    this.isWaiting = false,
    required this.onPauseResume,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = hasFailed
        ? const LinearGradient(colors: [mbRed, Color(0xFFFF7043)])
        : isComplete
        ? const LinearGradient(colors: [mbTeal, mbGreen])
        : isWaiting
        ? const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)])
        : const LinearGradient(colors: [mbGreen, mbTeal]);
    final icon = isComplete
        ? Icons.folder_open_rounded
        : hasFailed
        ? Icons.refresh_rounded
        : isPaused
        ? Icons.play_arrow_rounded
        : isWaiting
        ? Icons.schedule_rounded
        : Icons.pause_rounded;
    final onTap = hasFailed
        ? onRetry
        : isComplete
        ? onOpen
        : onPauseResume;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

/// Circular pause/play button that sits at the right end of the progress bar.
class MbPlayPauseButton extends StatelessWidget {
  final bool isComplete;
  final bool hasFailed;
  final bool isPaused;

  /// Queued behind a concurrency limit or Wi-Fi gate: not transferring yet.
  final bool isWaiting;
  final VoidCallback onPauseResume;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final double size;

  const MbPlayPauseButton({
    super.key,
    required this.isComplete,
    required this.hasFailed,
    required this.isPaused,
    this.isWaiting = false,
    required this.onPauseResume,
    required this.onRetry,
    required this.onOpen,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = hasFailed
        ? const LinearGradient(colors: [mbRed, Color(0xFFFF7043)])
        : isComplete
        ? const LinearGradient(colors: [mbTeal, mbGreen])
        : isWaiting
        ? const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)])
        : const LinearGradient(colors: [mbGreen, mbTeal]);
    final icon = isComplete
        ? Icons.folder_open_rounded
        : hasFailed
        ? Icons.refresh_rounded
        : isPaused
        ? Icons.play_arrow_rounded
        : isWaiting
        ? Icons.schedule_rounded
        : Icons.pause_rounded;
    final onTap = hasFailed
        ? onRetry
        : isComplete
        ? onOpen
        : onPauseResume;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}
