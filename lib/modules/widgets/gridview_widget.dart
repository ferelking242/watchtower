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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 13),
        controller: controller,
        gridDelegate: (gridSize == null || gridSize == 0)
            ? SliverGridDelegateWithMaxCrossAxisExtent(
                childAspectRatio: childAspectRatio!,
                // Tighter cell size so the default grid is 3 columns on
                // a typical phone (~360–420dp wide) and 4–5 columns on
                // tablets, instead of the previous 2-column behaviour
                // produced by maxCrossAxisExtent: 220.
                maxCrossAxisExtent: 140,
              )
            : SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize!,
                childAspectRatio: childAspectRatio!,
              ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
