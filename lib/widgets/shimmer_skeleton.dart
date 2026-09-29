import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Local shimmer loading surface used by loading placeholders.
///
/// Loading surfaces are rendered explicitly with the shimmer package so they
/// stay lightweight and do not depend on a second skeleton engine.
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

class ShimmerSkeleton extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final ShimmerEffect? effect;
  final bool _sliver;

  const ShimmerSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
    this.effect,
  }) : _sliver = false;

  const ShimmerSkeleton.sliver({
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

class SliverShimmerSkeleton extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final ShimmerEffect? effect;

  const SliverShimmerSkeleton({
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