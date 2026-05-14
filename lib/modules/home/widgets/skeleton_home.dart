import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton loading screen that mirrors the WatchtowerHomeScreen layout.
///
/// Section titles and static chrome are NOT shimmered (Skeleton.ignore).
/// Only data-driven content (hero banner, cards) gets the shimmer effect.
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
            // ── "Pour vous" static header (never shimmered) ─────────────
            _StaticTitleBar(),

            // ── Tab pills (static, never shimmered) ──────────────────────
            _StaticTabPills(),

            const SizedBox(height: 16),

            // ── Hero carousel bone (shimmered) ───────────────────────────
            Skeletonizer(
              enabled: true,
              enableSwitchAnimation: true,
              ignorePointers: false,
              child: _FakeHeroBanner(height: screenH * 0.52),
            ),

            const SizedBox(height: 8),

            // ── Section rows (only cards shimmered, titles static) ───────
            _FakeCardRow(
              rowLabel: 'En cours de diffusion',
              cardHeight: 198,
              cardWidth: 120,
              count: 6,
            ),
            _FakeCardRow(
              rowLabel: "Tendance aujourd'hui",
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

// ─────────────────────────────────────────────────────────────────────────────
// Static "Pour vous" header — never shimmered
// ─────────────────────────────────────────────────────────────────────────────

class _StaticTitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Pour vous',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ),
            // Avatar placeholder (static, not shimmered)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest,
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Static tab pills — never shimmered
// ─────────────────────────────────────────────────────────────────────────────

class _StaticTabPills extends StatelessWidget {
  static const _tabs = ['Tout', 'Film', 'Série', 'Asia', 'Football', 'Musique', 'Jeux'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _tabs.length,
        itemBuilder: (_, i) {
          final active = i == 0;
          final activeBg = isDark ? Colors.white : cs.onSurface;
          final activeText = isDark ? const Color(0xFF0A0A0F) : cs.surface;
          final inactiveBg = isDark
              ? Colors.white.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.07);
          final inactiveBorder = isDark
              ? Colors.white.withValues(alpha: 0.14)
              : cs.onSurface.withValues(alpha: 0.12);
          final inactiveText = isDark
              ? Colors.white.withValues(alpha: 0.68)
              : cs.onSurface.withValues(alpha: 0.62);

          return Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(999),
              border: active
                  ? null
                  : Border.all(color: inactiveBorder, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              _tabs[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeText : inactiveText,
              ),
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
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: height,
          color: cs.surfaceContainerHighest,
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
                height: 22,
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
                  const SizedBox(width: 6),
                  _FakePill(width: 54),
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
                width: i == 0 ? 18 : 6,
                height: 6,
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
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rowLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              // "Voir tout" static muted button
              Text(
                'Voir tout',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: count,
              separatorBuilder: (_, __) =>
                  SizedBox(width: ranked ? 6 : 10),
              itemBuilder: (context, i) {
                final w = firstWide && i == 0 ? cardWidth * 1.6 : cardWidth;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: width,
            height: height - 36,
            color: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: width * 0.75,
          height: 11,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 3),
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
    );
  }
}
