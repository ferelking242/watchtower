import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton loading screen that mirrors the WatchtowerHomeScreen layout.
///
/// Uses the `skeletonizer` package so the shapes perfectly match real content.
/// No spinning circles â the structure is visible immediately with a shimmer.
/// Only dynamic (data-driven) elements are wrapped; static chrome is not.
class SkeletonHomeScreen extends StatelessWidget {
  const SkeletonHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(opacity: v, child: child!),
      child: Skeletonizer(
        enabled: true,
        enableSwitchAnimation: true,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ââ Hero carousel bone ââââââââââââââââââââââââââââââââââââââââ
            _FakeHeroBanner(height: screenH * 0.62),

            const SizedBox(height: 8),

            // ââ Section rows (3 fake rows) ââââââââââââââââââââââââââââââââ
            _FakeCardRow(
              rowLabel: 'En cours de diffusion',
              cardHeight: 198,
              cardWidth: 120,
              count: 6,
            ),
            _FakeCardRow(
              rowLabel: 'Tendance aujourd\'hui',
              cardHeight: 220,
              cardWidth: 140,
              count: 6,
              firstWide: true,
            ),
            _FakeCardRow(
              rowLabel: 'Top populaires',
              cardHeight: 170,
              cardWidth: 110,
              count: 8,
              ranked: true,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Fake hero banner
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _FakeHeroBanner extends StatelessWidget {
  final double height;
  const _FakeHeroBanner({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Banner image area
        Container(
          width: double.infinity,
          height: height,
          color: cs.surfaceContainerHighest,
        ),

        // Info overlay (bottom-left)
        Positioned(
          left: 16,
          right: 16,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type badge
              Container(
                width: 58,
                height: 22,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              // Title
              Container(
                height: 22,
                width: 220,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              // Description line 1
              Container(
                height: 13,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              // Description line 2
              Container(
                height: 13,
                width: 260,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              // Description line 3
              Container(
                height: 13,
                width: 180,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 10),
              // Genre pills row
              Row(
                children: [
                  _FakePill(width: 60),
                  const SizedBox(width: 6),
                  _FakePill(width: 72),
                  const SizedBox(width: 6),
                  _FakePill(width: 54),
                ],
              ),
            ],
          ),
        ),

        // Page indicator dots
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                width: i == 0 ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Fake card row
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _FakeCardRow extends StatelessWidget {
  final String rowLabel;
  final double cardHeight;
  final double cardWidth;
  final int count;
  final bool ranked;
  final bool firstWide;

  const _FakeCardRow({
    required this.rowLabel,
    required this.cardHeight,
    required this.cardWidth,
    required this.count,
    this.ranked = false,
    this.firstWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              // Title text â Skeletonizer will shimmer this
              Text(
                rowLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // "Voir tout" button placeholder
              Container(
                width: 56,
                height: 14,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ],
          ),
        ),

        // Cards
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (_, __) =>
                SizedBox(width: ranked ? 6 : 10),
            itemBuilder: (context, i) {
              // First card is wider when firstWide is true (featured)
              final w =
                  firstWide && i == 0 ? cardWidth * 1.6 : cardWidth;
              if (ranked) {
                return _FakeRankedCard(
                    width: w, height: cardHeight, rank: i + 1);
              }
              return _FakeCard(width: w, height: cardHeight);
            },
          ),
        ),
      ],
    );
  }
}

// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// Individual fake card shapes
// âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _FakeCard extends StatelessWidget {
  final double width;
  final double height;
  const _FakeCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Poster / thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: width,
            height: height - 36,
            color: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        // Title line
        Container(
          width: width * 0.75,
          height: 11,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 3),
        // Sub-line
        Container(
          width: width * 0.50,
          height: 9,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _FakeRankedCard extends StatelessWidget {
  final double width;
  final double height;
  final int rank;
  const _FakeRankedCard(
      {required this.width, required this.height, required this.rank});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank number placeholder
        Container(
          width: 24,
          height: height * 0.55,
          alignment: Alignment.bottomLeft,
          child: Text(
            '$rank',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: width - 28,
            height: height * 0.90,
            color: cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _FakePill extends StatelessWidget {
  final double width;
  const _FakePill({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 20,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
        ),
      ),
    );
  }
}