import 'package:flutter/material.dart';

import 'package:watchtower/ui/responsive/breakpoints.dart';

class GridViewWidget extends StatelessWidget {
  final ScrollController? controller;
  final int? itemCount;
  final bool reverse;
  final double? childAspectRatio;
  final Widget? Function(BuildContext, int) itemBuilder;
  final int? gridSize;
  const GridViewWidget({
    super.key,
    this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.reverse = false,
    this.childAspectRatio = 0.69,
    this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final sizeClass = windowSizeClassFor(mq.size.width);
    // In landscape the screen is wider → smaller cells → more columns.
    // We also account for horizontal safe-area insets (camera cutouts, etc.)
    // by using the available width after padding.
    final safeWidth = mq.size.width - mq.padding.left - mq.padding.right;

    // A desktop window is wide enough that the user's column count (three by
    // default) would stretch each cover into a billboard. Derive the column
    // count from the width instead, keeping the preference as a floor so a user
    // who asked for five columns still gets at least five.
    final isDesktopWide = sizeClass.index >= WindowSizeClass.expanded.index;
    if (isDesktopWide) {
      final spec = AdaptiveGridSpec.resolve(
        safeWidth,
        minTileWidth: 150,
        maxColumns: 12,
        spacing: 14,
      );
      final columns = gridSize != null && gridSize! > spec.columns
          ? gridSize!
          : spec.columns;
      return SafeArea(
        top: false,
        bottom: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: GridView.builder(
            padding: EdgeInsets.only(
              top: 13,
              left: mq.padding.left + 8,
              right: mq.padding.right + 8,
            ),
            controller: controller,
            reverse: reverse,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spec.spacing,
              crossAxisSpacing: spec.spacing,
              childAspectRatio: childAspectRatio!,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      );
    }

    final double maxExtent;
    if (gridSize != null && gridSize != 0) {
      maxExtent = 140; // ignored when fixedCrossAxisCount is used
    } else if (isLandscape) {
      // landscape: aim for 4-6 columns depending on screen width
      maxExtent = (safeWidth / 5).clamp(100, 130);
    } else {
      // portrait: 3 columns on phones, 4-5 on tablets
      maxExtent = 140;
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: GridView.builder(
          padding: EdgeInsets.only(
            top: 13,
            left: mq.padding.left,
            right: mq.padding.right,
          ),
          controller: controller,
          reverse: reverse,
          gridDelegate: (gridSize == null || gridSize == 0)
              ? SliverGridDelegateWithMaxCrossAxisExtent(
                  childAspectRatio: childAspectRatio!,
                  maxCrossAxisExtent: maxExtent,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize!,
                  childAspectRatio: childAspectRatio!,
                ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}
