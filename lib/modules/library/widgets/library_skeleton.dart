import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/widgets/gridview_widget.dart';

/// Skeleton painted while the library streams resolve.
///
/// The library used to show a bare `CircularProgressIndicator`, which on a cold
/// start sits on an empty white page for as long as Isar takes to emit. The
/// skeleton mirrors the real layout — same column count, same landscape card
/// ratio, same title slot — so the grid appears to fill in instead of jumping
/// from a spinner to a full page.
class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({this.itemType = ItemType.manga, super.key});

  final ItemType itemType;

  @override
  Widget build(BuildContext context) {
    final colors = _SkeletonColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.base,
      highlightColor: colors.highlight,
      child: GridViewWidget(
        gridSize: 3,
        childAspectRatio: 1.5,
        maxTileWidth: 190,
        itemCount: 12,
        itemBuilder: (context, _) => Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.block,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.82,
                child: SizedBox(
                  height: 11,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.block,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-page skeleton for the boot gate: the library header, the category tabs
/// and the grid, all in one shimmer.
class LibraryBootSkeleton extends StatelessWidget {
  const LibraryBootSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: SizedBox(height: 34, child: LibraryTabsSkeleton()),
        ),
        SizedBox(height: 8),
        Expanded(child: LibrarySkeleton()),
      ],
    );
  }
}

/// Skeleton for the list display mode: a thumbnail plus two text lines.
class LibraryListSkeleton extends StatelessWidget {
  const LibraryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _SkeletonColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.base,
      highlightColor: colors.highlight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 10,
        itemBuilder: (context, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 128,
                height: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.block,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 12,
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.block,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 10,
                      child: FractionallySizedBox(
                        widthFactor: 0.45,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.block,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category-tab strip skeleton, so the header does not pop in alone.
class LibraryTabsSkeleton extends StatelessWidget {
  const LibraryTabsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _SkeletonColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.base,
      highlightColor: colors.highlight,
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, index) => SizedBox(
            width: 54.0 + (index % 2) * 26,
            height: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.block,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonColors {
  const _SkeletonColors({
    required this.base,
    required this.highlight,
    required this.block,
  });

  final Color base;
  final Color highlight;
  final Color block;

  static _SkeletonColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _SkeletonColors(
            base: Color(0xFF24282C),
            highlight: Color(0xFF2E3338),
            block: Color(0xFF30353A),
          )
        : const _SkeletonColors(
            base: Color(0xFFE9EBEE),
            highlight: Color(0xFFF3F5F7),
            block: Color(0xFFDDE1E5),
          );
  }
}
