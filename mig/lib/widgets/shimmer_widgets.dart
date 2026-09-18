import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MigShimmer extends StatelessWidget {
  final Widget child;
  const MigShimmer({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      child: child,
    );
  }
}

class LoadingPosterRow extends StatelessWidget {
  const LoadingPosterRow({super.key});

  @override
  Widget build(BuildContext context) {
    return MigShimmer(
      child: SizedBox(
        height: 184,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => Container(
            width: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}