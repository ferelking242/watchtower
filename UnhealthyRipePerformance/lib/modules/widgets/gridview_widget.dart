import 'package:flutter/material.dart';

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
    // In landscape the screen is wider → smaller cells → more columns.
    // We also account for horizontal safe-area insets (camera cutouts, etc.)
    // by using the available width after padding.
    final safeWidth = mq.size.width - mq.padding.left - mq.padding.right;
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
