import 'package:flutter/material.dart';

import 'cover_url.dart';

/// Renders [child] normally, but when [url] points at a known sprite sheet
/// (see [mosaicGrid]) it shows only the first tile instead of the whole grid.
///
/// This is the widget-level safety net for covers: [normalizeCoverUrl] repairs
/// the URL before it is used, and this crop covers the cases where the mosaic
/// URL was already resolved elsewhere or served by an older extension build.
class MosaicAwareCover extends StatelessWidget {
  const MosaicAwareCover({
    required this.url,
    required this.width,
    required this.height,
    required this.child,
    super.key,
  });

  final String? url;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grid = mosaicGrid(url);
    if (grid == null) return child;
    // The child draws the whole sheet squeezed into the cover box; scaling it
    // up by the grid size and clipping to the top-left tile shows one frame.
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.diagonal3Values(
            grid.columns.toDouble(),
            grid.rows.toDouble(),
            1,
          ),
          child: child,
        ),
      ),
    );
  }
}
