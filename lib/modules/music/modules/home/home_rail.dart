import 'package:flutter/material.dart';

import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/components/shimmers/music_shimmer.dart';

/// Shimmer row shown in place of a shelf that is still loading.
///
/// The home used to hide every shelf until its provider answered, so sections
/// appeared one by one and the page kept reflowing. Rendering a skeleton of the
/// final layout instead keeps the page stable and shows how much content is
/// coming.
class HomeRailSkeleton extends StatelessWidget {
  const HomeRailSkeleton({
    this.itemWidth = 150,
    this.itemHeight = 200,
    this.itemCount = 5,
    this.title = true,
    this.titleWidth = 140,
    this.circular = false,
    super.key,
  });

  final double itemWidth;
  final double itemHeight;
  final int itemCount;
  final bool title;
  final double titleWidth;

  /// Artist shelves use round artwork, so their placeholder is round too.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title)
          Padding(
            padding: EdgeInsets.fromLTRB(AppUI.pagePadding(context), 16, 16, 12),
            child: Container(
              width: titleWidth,
              height: 16,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        SizedBox(
          height: itemHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => circular
                ? Column(
                    children: [
                      Container(
                        width: itemWidth,
                        height: itemWidth,
                        decoration: BoxDecoration(
                          color: base,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: itemWidth * 0.7,
                        height: 10,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  )
                : MusicCardShimmer(width: itemWidth, height: itemHeight),
          ),
        ),
      ],
    );
  }
}
