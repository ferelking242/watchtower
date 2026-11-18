import 'package:flutter/material.dart';

class GridViewWidget extends StatelessWidget {
  final ScrollController? controller;
  final int? itemCount;
  final bool reverse;
  final double? childAspectRatio;
  final Widget? Function(BuildContext, int) itemBuilder;
  final int? gridSize;

  /// Upper bound for a single tile's width. Without it, asking for one column
  /// on a phone stretches the lone cover across the whole screen — huge and
  /// "zoomed". Tiles are capped at this width and the grid is centered, so a
  /// one-per-row layout still reads as a tidy card.
  final double maxTileWidth;

  const GridViewWidget({
    super.key,
    this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.reverse = false,
    this.childAspectRatio = 0.69,
    this.gridSize,
    this.maxTileWidth = 200,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final available = mq.size.width - mq.padding.left - mq.padding.right;

    const spacing = 8.0;
    final hasExplicitColumns = gridSize != null && gridSize! > 0;
    // No explicit preference: pick a count from the width. Landscape is wider,
    // so it fits more columns at the same tile size.
    final int columns = hasExplicitColumns
        ? gridSize!
        : (available / (isLandscape ? 150 : 120)).round().clamp(3, 8);

    var tileWidth = (available - spacing * (columns - 1)) / columns;
    if (tileWidth > maxTileWidth) tileWidth = maxTileWidth;
    final contentWidth = tileWidth * columns + spacing * (columns - 1);
    final sidePad = ((available - contentWidth) / 2).clamp(0.0, double.infinity);

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: GridView.builder(
          padding: EdgeInsets.only(
            top: 13,
            left: mq.padding.left + sidePad,
            right: mq.padding.right + sidePad,
          ),
          controller: controller,
          reverse: reverse,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio!,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}
