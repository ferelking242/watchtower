import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Shared empty state: the same `empty_box_partho` animation already used by
/// the watch home and Library, with a single message underneath.
class AnimatedEmptyState extends StatelessWidget {
  const AnimatedEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.animationSize = 132,
  });

  final String message;
  final IconData? icon;
  final double animationSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/empty_box_partho.json',
                  width: animationSize,
                  height: animationSize,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
                if (icon != null)
                  Icon(icon, size: 26, color: cs.primary.withValues(alpha: 0.9)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
