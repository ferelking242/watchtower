import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shimmer skeleton that exactly mirrors the WatchtowerHomeScreen layout.
/// Shown while anilistHomeProvider is loading.
class SkeletonHomeScreen extends StatefulWidget {
  const SkeletonHomeScreen({super.key});

  @override
  State<SkeletonHomeScreen> createState() => _SkeletonHomeScreenState();
}

class _SkeletonHomeScreenState extends State<SkeletonHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            // Header space
            const SliverToBoxAdapter(child: SizedBox(height: 80)),

            // ── Hero carousel skeleton (full-width)
            SliverToBoxAdapter(child: _heroBannerSkeleton(context)),

            // ── Section + horizontal cards
            _cardRowSkeleton(context, 'Trending Today'),
            _cardRowSkeleton(context, 'Currently Airing'),
            _cardRowSkeleton(context, 'Popular Anime'),
            _cardRowSkeleton(context, 'Trending Manga'),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _heroBannerSkeleton(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return _Bone(
      width: w,
      height: 340,
      radius: 0,
      anim: _anim,
    );
  }

  SliverToBoxAdapter _cardRowSkeleton(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
            child: Row(
              children: [
                _Bone(width: 140, height: 16, radius: 8, anim: _anim),
                const Spacer(),
                _Bone(width: 56, height: 14, radius: 7, anim: _anim),
              ],
            ),
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => _Bone(
                width: 120,
                height: 180,
                radius: 14,
                anim: _anim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single skeleton bone with shimmer gradient.
class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Animation<double> anim;

  const _Bone({
    required this.width,
    required this.height,
    required this.radius,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final shine = cs.surfaceContainerHighest.withValues(alpha: 0.35);
    final t = anim.value;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + t * 3, 0),
          end: Alignment(-0.5 + t * 3, 0),
          colors: [base, shine, base],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Reusable bone used for individual fields (title, subtitle, etc.)
class SkeletonBone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBone({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
