import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  const MbThumb({
    super.key,
    required this.imageUrl,
    required this.customBytes,
    required this.itemType,
    required this.badge,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A poster ratio keeps the queue recognizable at a glance while leaving
    // the center column wide enough for exact byte progress and actions.
    const w = 76.0;
    const h = 108.0;
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
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {}
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = cachedNetworkImage(
        imageUrl: imageUrl!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorWidget: placeholder,
      );
    }

    return ClipRRect(
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
  }
}

class MbGradientProgressBar extends StatefulWidget {
  final double? value;
  final double height;
  final bool paused;
  final bool failed;

  /// Golden second pass: the archive is being packed/compressed after the
  /// transfer finished. Uses a golden gradient instead of the green/teal one.
  final bool compressing;

  const MbGradientProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.paused = false,
    this.failed = false,
    this.compressing = false,
  });

  @override
  State<MbGradientProgressBar> createState() => _MbGradientProgressBarState();
}

class _MbGradientProgressBarState extends State<MbGradientProgressBar>
    with TickerProviderStateMixin {
  // "Snake" sweep that runs across the filled part while a transfer is active.
  late final AnimationController _sweep;

  // Progress is eased towards the latest value instead of snapping, so noisy
  // byte/page counters do not make the bar jitter on every rebuild.
  late final AnimationController _valueAnim;
  static const _valueDuration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;
  // Ignore sub-pixel target moves; they are pure counter noise.
  static const _deadband = 0.004;

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
    final start = _target ?? 0;
    _from = start;
    _to = start;
    _valueAnim = AnimationController(
      vsync: this,
      duration: _valueDuration,
      value: 1,
    );
    if (_sweepEnabled) _sweep.repeat();
  }

  bool get _sweepEnabled =>
      _target != null &&
      !widget.paused &&
      !widget.failed &&
      !widget.compressing;

  @override
  void didUpdateWidget(covariant MbGradientProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (target != null && (target - _to).abs() > _deadband) {
      _from = _displayed;
      _to = target;
      _valueAnim.forward(from: 0);
    }
    if (_sweepEnabled) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else if (_sweep.isAnimating) {
      _sweep.stop();
      _sweep.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
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
        ? const LinearGradient(colors: [mbAmber, Color(0xFFFF8F00)])
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
                        DecoratedBox(
                          decoration: BoxDecoration(gradient: gradient),
                        ),
                        if (_sweepEnabled) _buildSnake(),
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

  // A soft highlight band travelling left to right across the filled region.
  Widget _buildSnake() {
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
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.0),
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

/// Right rail: compact 3-dot overflow menu (pause/resume, retry, open,
/// cancel, delete) above the gradient circular action button — MovieBox style.
/// All handlers are the screen's existing callbacks; no logic lives here.
class MbRowActions extends StatelessWidget {
  final bool isComplete;
  final bool hasFailed;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  const MbRowActions({
    super.key,
    required this.isComplete,
    required this.hasFailed,
    required this.isPaused,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient = hasFailed
        ? const LinearGradient(colors: [mbRed, Color(0xFFFF7043)])
        : isComplete
        ? const LinearGradient(colors: [mbTeal, mbGreen])
        : const LinearGradient(colors: [mbGreen, mbTeal]);
    final icon = isComplete
        ? Icons.folder_open_rounded
        : hasFailed
        ? Icons.refresh_rounded
        : isPaused
        ? Icons.play_arrow_rounded
        : Icons.pause_rounded;
    final onTap = hasFailed
        ? onRetry
        : isComplete
        ? onOpen
        : onPauseResume;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          onSelected: (v) {
            switch (v) {
              case 'pause':
                onPauseResume();
                break;
              case 'cancel':
                onCancel();
                break;
              case 'retry':
                onRetry();
                break;
              case 'delete':
                onDelete();
                break;
              case 'open':
                onOpen();
                break;
            }
          },
          itemBuilder: (_) => [
            if (!isComplete)
              PopupMenuItem(
                value: 'pause',
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 17,
                      color: mbAmber,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isPaused ? 'Reprendre' : 'Pause',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (hasFailed)
              PopupMenuItem(
                value: 'retry',
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 17, color: mbRed),
                    const SizedBox(width: 10),
                    const Text('Réessayer', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            if (isComplete)
              PopupMenuItem(
                value: 'open',
                height: 40,
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 17,
                      color: mbTeal,
                    ),
                    const SizedBox(width: 10),
                    const Text('Ouvrir', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'cancel',
              height: 40,
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  const Text('Annuler', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              height: 40,
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Supprimer',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
        ),
      ],
    );
  }
}
