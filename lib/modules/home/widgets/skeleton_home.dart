import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton loading screen that mirrors the WatchtowerHomeScreen layout.
///
/// Real layout order:
///   1. Hero carousel (full-width, 36% screen height) — top, scrolls away
///   2. Tab pills (pinned sticky below carousel)
///   3. Section rows (cards)
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero carousel bone (shimmered) — at the very top ─────────────
            Skeletonizer(
              enabled: true,
              enableSwitchAnimation: true,
              ignorePointers: false,
              child: _FakeHeroBanner(height: screenH * 0.36),
            ),

            // ── Tab pills (static, never shimmered) — pinned below carousel ──
            _StaticTabPills(),

            const SizedBox(height: 10),

            // ── Section rows (only cards shimmered, titles static) ───────────
            _FakeCardRow(
              rowLabel: 'Sorties récentes',
              cardHeight: 196,
              cardWidth: 120,
              count: 6,
            ),
            _FakeCardRow(
              rowLabel: 'En ce moment',
              cardHeight: 218,
              cardWidth: 140,
              count: 6,
              firstWide: true,
            ),
            _FakeCardRow(
              rowLabel: 'Top du moment',
              cardHeight: 170,
              cardWidth: 110,
              count: 8,
              ranked: true,
            ),

            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Static tab pills — never shimmered (below hero, like the real layout)
// ─────────────────────────────────────────────────────────────────────────────

class _StaticTabPills extends StatelessWidget {
  static const _tabs = ['Tout', 'Film', 'Série', 'Anime', 'Asia', 'TV Court', 'Musique'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        itemBuilder: (_, i) {
          final active = i == 0;
          final activeColor = isDark ? Colors.white : cs.onSurface;
          final inactiveColor = isDark
              ? Colors.white.withValues(alpha: 0.38)
              : cs.onSurface.withValues(alpha: 0.35);

          return Padding(
            padding: const EdgeInsets.only(right: 20, top: 4, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _tabs[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? activeColor : inactiveColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 3,
                  width: active ? 20.0 : 0.0,
                  decoration: BoxDecoration(
                    color: active ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake hero banner (shimmered via Skeletonizer wrapping)
// ─────────────────────────────────────────────────────────────────────────────

class _FakeHeroBanner extends StatelessWidget {
  final double height;
  const _FakeHeroBanner({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: height,
          color: cs.surfaceContainerHighest,
        ),
        // Gradient scrim like real carousel
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.38, 0.58, 0.76, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.50),
                  scaffoldBg,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 22,
                width: 220,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 13,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 13,
                width: 260,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _FakePill(width: 60),
                  const SizedBox(width: 6),
                  _FakePill(width: 72),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                width: i == 0 ? 20 : 5,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
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

// ─────────────────────────────────────────────────────────────────────────────
// Fake card row — title is STATIC, cards are shimmered
// ─────────────────────────────────────────────────────────────────────────────

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
        // Section header — static, never shimmered
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                rowLabel,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),

        // Cards — shimmered via Skeletonizer
        Skeletonizer(
          enabled: true,
          enableSwitchAnimation: true,
          ignorePointers: false,
          child: SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: count,
              separatorBuilder: (_, __) =>
                  SizedBox(width: ranked ? 6 : 10),
              itemBuilder: (context, i) {
                final w = firstWide && i == 0 ? cardWidth * 1.5 : cardWidth;
                if (ranked) {
                  return _FakeRankedCard(
                      width: w, height: cardHeight, rank: i + 1);
                }
                return _FakeCard(width: w, height: cardHeight);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual fake card shapes
// ─────────────────────────────────────────────────────────────────────────────

class _FakeCard extends StatelessWidget {
  final double width;
  final double height;
  const _FakeCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(color: cs.surfaceContainerHighest),
        ),
      ),
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
    return SizedBox(
      width: width + 36,
      height: height,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: 0,
            bottom: 8,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: cs.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: width,
                color: cs.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
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
    );
  }
}
