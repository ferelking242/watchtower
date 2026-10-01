import 'package:flutter/material.dart';
import 'package:watchtower/modules/widgets/comments_section.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

/// Shimmer skeletons reproducing the exact geometry of MangaDetailsScreen.
///
/// Every placeholder mirrors its final widget (cover ratio, card sizes,
/// text line heights) so content swapping in causes no layout jump.

// ─── Page skeleton ───────────────────────────────────────────────────────────

/// Full-page skeleton shown while the manga detail record is loading:
/// header · cover · title/author/status · actions · tabs · chapters ·
/// details · similar · comments.
class MangaDetailSkeleton extends StatelessWidget {
  const MangaDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      effect: shimmerEffectFor(context),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HeaderSkeleton(),
              _HeroSkeleton(),
              _ActionsSkeleton(),
              _TabsSkeleton(),
              _SectionHeaderSkeleton(),
              ChapterCardSkeleton(),
              ChapterCardSkeleton(),
              ChapterCardSkeleton(),
              _DetailsSkeleton(),
              _SimilarSkeleton(),
              CommentsSkeleton(rows: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      height: kToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _box(color, 24, 24, radius: 6),
            const Spacer(),
            _box(color, 22, 22, radius: 6),
            const SizedBox(width: 18),
            _box(color, 22, 22, radius: 6),
            const SizedBox(width: 18),
            _box(color, 22, 22, radius: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Hero: cover + title / author / status ───────────────────────────────────

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover — exact geometry of the real cover card.
          _box(color, 65 * 1.5, 65 * 2.3, radius: 5),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _box(color, 200, 22, radius: 5),
                const SizedBox(height: 10),
                _box(color, 150, 14, radius: 4),
                const SizedBox(height: 10),
                _box(color, 110, 13, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actions ─────────────────────────────────────────────────────────────────

class _ActionsSkeleton extends StatelessWidget {
  const _ActionsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
      child: Row(
        children: [
          Expanded(child: _box(color, null, 44, radius: 12)),
          const SizedBox(width: 8),
          Expanded(child: _box(color, null, 44, radius: 12)),
        ],
      ),
    );
  }
}

// ─── Tab pills ───────────────────────────────────────────────────────────────

class _TabsSkeleton extends StatelessWidget {
  const _TabsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        children: [
          _box(color, 108, 34, radius: 17),
          const SizedBox(width: 8),
          _box(color, 84, 34, radius: 17),
          const SizedBox(width: 8),
          _box(color, 84, 34, radius: 17),
        ],
      ),
    );
  }
}

// ─── Section header (count + filter) ─────────────────────────────────────────

class _SectionHeaderSkeleton extends StatelessWidget {
  const _SectionHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          _box(color, 130, 15, radius: 4),
          const Spacer(),
          _box(color, 36, 36, radius: 10),
        ],
      ),
    );
  }
}

// ─── Details block ───────────────────────────────────────────────────────────

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stretch(color, 12),
          const SizedBox(height: 8),
          _stretch(color, 12),
          const SizedBox(height: 8),
          _box(color, 240, 12, radius: 4),
          const SizedBox(height: 18),
          Row(
            children: [
              _box(color, 64, 26, radius: 13),
              const SizedBox(width: 8),
              _box(color, 78, 26, radius: 13),
              const SizedBox(width: 8),
              _box(color, 56, 26, radius: 13),
            ],
          ),
          const SizedBox(height: 18),
          _infoRow(color),
          const SizedBox(height: 12),
          _infoRow(color),
          const SizedBox(height: 12),
          _infoRow(color),
        ],
      ),
    );
  }

  Widget _infoRow(Color color) => Row(
    children: [
      _box(color, 90, 11, radius: 4),
      const SizedBox(width: 14),
      _box(color, 150, 11, radius: 4),
    ],
  );
}

// ─── Similar rail ────────────────────────────────────────────────────────────

class _SimilarSkeleton extends StatelessWidget {
  const _SimilarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 8),
      child: Row(
        children: const [
          SimilarCardSkeleton(),
          SizedBox(width: 10),
          SimilarCardSkeleton(),
          SizedBox(width: 10),
          SimilarCardSkeleton(),
        ],
      ),
    );
  }
}

// ─── Shared boxes ────────────────────────────────────────────────────────────

/// Skeleton box. Pass `w: null` inside an `Expanded` to stretch full width.
Widget _box(Color color, double? w, double h, {double radius = 6}) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Full-width skeleton line (works under loose cross-axis constraints).
Widget _stretch(Color color, double h) {
  return Row(children: [Expanded(child: _box(color, null, h, radius: 4))]);
}

// ─── Chapter card skeleton ───────────────────────────────────────────────────

/// Mirrors [ChapterListTileWidget]: leading accent bar · title · metadata.
class ChapterCardSkeleton extends StatelessWidget {
  const ChapterCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(color, 2, 40, radius: 10),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _box(color, 190, 12, radius: 4),
                const SizedBox(height: 8),
                _box(color, 120, 10, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Similar card skeleton ───────────────────────────────────────────────────

/// Mirrors [PosterCard] at width 116: 2/3 cover + title line.
class SimilarCardSkeleton extends StatelessWidget {
  const SimilarCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _box(color, 116, 174, radius: 14),
        const SizedBox(height: 6),
        _box(color, 96, 11, radius: 4),
      ],
    );
  }
}
