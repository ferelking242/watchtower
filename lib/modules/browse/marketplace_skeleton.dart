import 'package:flutter/material.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

/// Full-page loading skeleton for the Marketplace.
///
/// It mirrors the real page structure (header, tabs, hero carousel, shelf
/// blocks with their 2 × 2 grids, then the trailing catalogue rows) so the
/// first paint already fills the viewport and the content does not "jump" into
/// place once the catalogue arrives. The previous placeholder drew a handful of
/// rows and left the rest of the screen empty.
///
/// It is a [Column], not a scroll view: the caller embeds it in a sliver so the
/// page keeps its own scroll and pull-to-refresh while the catalogue loads.
class MarketplaceSkeleton extends StatelessWidget {
  const MarketplaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    return ShimmerSkeleton(
      effect: ShimmerEffect(
        baseColor: palette.skeletonBase,
        highlightColor: palette.skeletonHighlight,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBlock(),
          _TabsBlock(),
          _HeroBlock(),
          _ShelfBlock(),
          _ShelfBlock(),
          _ShelfBlock(),
          _RowsBlock(),
        ],
      ),
    );
  }
}

/// A grey placeholder rectangle in the palette's raised surface.
class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 8});

  /// Fixed width, or null to fill the available width.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: MarketplacePalette.of(context).surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 14, 10),
      child: Row(
        children: [
          _Bone(width: 28, height: 28, radius: 9),
          SizedBox(width: 10),
          _Bone(width: 118, height: 16, radius: 6),
          Spacer(),
          _Bone(width: 26, height: 26, radius: 13),
          SizedBox(width: 10),
          _Bone(width: 36, height: 36, radius: 18),
        ],
      ),
    );
  }
}

class _TabsBlock extends StatelessWidget {
  const _TabsBlock();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) =>
            const Align(child: _Bone(width: 82, height: 30, radius: 15)),
      ),
    );
  }
}

/// Placeholder of the featured banner carousel: one large rounded panel.
class _HeroBlock extends StatelessWidget {
  const _HeroBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _Bone(height: 176, radius: 18),
    );
  }
}

/// One shelf: a title row with its "see all" pill, then a 2 × 2 grid of cards.
class _ShelfBlock extends StatelessWidget {
  const _ShelfBlock();

  @override
  Widget build(BuildContext context) {
    final cardWidth = CatalogCardMetrics.cardWidthFor(
      MediaQuery.sizeOf(context).width - CatalogCardMetrics.padding * 2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 16, 10),
          child: Row(
            children: [
              _Bone(width: 168, height: 15, radius: 6),
              Spacer(),
              _Bone(width: 62, height: 20, radius: 10),
            ],
          ),
        ),
        SizedBox(
          height: CatalogCardMetrics.shelfHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: CatalogCardMetrics.padding,
            ),
            itemCount: 4,
            separatorBuilder: (_, _) =>
                const SizedBox(width: CatalogCardMetrics.gap),
            itemBuilder: (_, _) => SizedBox(
              width: cardWidth,
              child: const _SkeletonCard(),
            ),
          ),
        ),
      ],
    );
  }
}

/// A card-shaped skeleton matching [CatalogCard]'s geometry: icon, title,
/// second line, and the trailing action row.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Bone(width: 46, height: 46, radius: 13),
              SizedBox(width: 10),
              Expanded(child: _Bone(height: 13, radius: 5)),
            ],
          ),
          SizedBox(height: 9),
          _Bone(height: 10, radius: 5),
          SizedBox(height: 6),
          _Bone(width: 120, height: 10, radius: 5),
          Spacer(),
          Row(
            children: [
              _Bone(width: 46, height: 13, radius: 6),
              SizedBox(width: 7),
              _Bone(width: 30, height: 13, radius: 6),
              Spacer(),
              _Bone(width: 62, height: 26, radius: 13),
            ],
          ),
        ],
      ),
    );
  }
}

/// The trailing "all extensions" block: a section title plus a multi-column
/// grid, matching the catalogue rows.
class _RowsBlock extends StatelessWidget {
  const _RowsBlock();

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 32;
    final columns = (available / 200).floor().clamp(2, 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 16, 10),
          child: _Bone(width: 190, height: 15, radius: 6),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: columns * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: CatalogCardMetrics.gap,
              crossAxisSpacing: CatalogCardMetrics.gap,
              mainAxisExtent: CatalogCardMetrics.cardHeight,
            ),
            itemBuilder: (_, _) => const _SkeletonCard(),
          ),
        ),
      ],
    );
  }
}

/// Single-column skeleton for the plugin list surface.
class MarketplacePluginSkeleton extends StatelessWidget {
  const MarketplacePluginSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    return ShimmerSkeleton(
      effect: ShimmerEffect(
        baseColor: palette.skeletonBase,
        highlightColor: palette.skeletonHighlight,
      ),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 24),
        itemCount: 8,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              const _Bone(width: 54, height: 54, radius: 14),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(
                      width: 130 + (index % 3) * 25.0,
                      height: 14,
                      radius: 5,
                    ),
                    const SizedBox(height: 7),
                    const _Bone(width: 92, height: 10, radius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _Bone(width: 54, height: 34, radius: 17),
            ],
          ),
        ),
      ),
    );
  }
}
