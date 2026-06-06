import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ─── 3 jumping dots (reusable loading indicator) ─────────────────────────────

class JumpingDotsLoader extends StatefulWidget {
  final Color color;
  final double size;
  const JumpingDotsLoader({
    super.key,
    this.color = Colors.white,
    this.size = 7.0,
  });

  @override
  State<JumpingDotsLoader> createState() => _JumpingDotsLoaderState();
}

class _JumpingDotsLoaderState extends State<JumpingDotsLoader>
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
              width: widget.size,
              height: widget.size,
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Overlay d'état du player : loading, buffering, seeking, success, error.
///
/// Utilisation :
///   WatchtowerLoader(animation: 'buffering', percent: 0.42)
///   WatchtowerLoader(animation: 'success', onDismiss: () { ... })
class WatchtowerLoader extends StatefulWidget {
  /// Nom du fichier JSON dans assets/animations/ (sans extension).
  final String animation;

  /// Si non-null, affiche une LinearProgressIndicator sous l'animation.
  final double? percent;

  /// Callback appelé après 1 s quand animation == 'success'.
  final VoidCallback? onDismiss;

  const WatchtowerLoader({
    required this.animation,
    this.percent,
    this.onDismiss,
    super.key,
  });

  @override
  State<WatchtowerLoader> createState() => _WatchtowerLoaderState();
}

class _WatchtowerLoaderState extends State<WatchtowerLoader> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    if (widget.animation == 'success') {
      _dismissTimer = Timer(const Duration(seconds: 1), () {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.54),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Lottie.asset(
                'assets/animations/${widget.animation}.json',
                repeat: widget.animation != 'success' && widget.animation != 'error',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            if (widget.percent != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widget.percent!.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white30,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${(widget.percent!.clamp(0.0, 1.0) * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
