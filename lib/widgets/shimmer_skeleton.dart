import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Local loading surface used instead of Skeletonizer.
///
/// The old dependency attempted to infer skeleton shapes from the whole
/// widget tree. Watchtower now keeps the same call sites but renders them
/// with the explicit shimmer package, which keeps loading UI lightweight and
/// independent from a second skeleton engine.
class ShimmerEffect {
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.duration = const Duration(milliseconds: 1500),
  });
}

class Skeletonizer extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final ShimmerEffect? effect;
  final bool _sliver;

  const Skeletonizer({
    super.key,
    required this.child,
    this.enabled = true,
    this.effect,
  }) : _sliver = false;

  const Skeletonizer.sliver({
    super.key,
    required this.child,
    this.enabled = true,
    this.effect,
  }) : _sliver = true;

  @override
  Widget build(BuildContext context) {
    // A RenderSliver cannot be wrapped by the box-based Shimmer widget.
    // Sliver loading placeholders remain structurally intact; their child
    // cards use the same shimmer wrapper at the box level.
    if (!enabled || _sliver) return child;

    final colors = effect ?? const ShimmerEffect();
    return Shimmer.fromColors(
      baseColor: colors.baseColor,
      highlightColor: colors.highlightColor,
      period: colors.duration,
      child: child,
    );
  }
}

class SliverSkeletonizer extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final ShimmerEffect? effect;

  const SliverSkeletonizer({
    super.key,
    required this.child,
    this.enabled = true,
    this.effect,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child;
  }
}

class Skeleton {
  const Skeleton._();

  static Widget keep({required Widget child}) => child;

  static Widget ignore({required Widget child}) => child;

  static Widget replace({required Widget child}) => child;
}