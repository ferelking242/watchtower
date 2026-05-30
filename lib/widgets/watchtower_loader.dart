import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
