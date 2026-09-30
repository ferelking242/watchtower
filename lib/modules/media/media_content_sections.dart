import 'package:flutter/material.dart';

import 'app_ui_components.dart';
import 'content_cards.dart';

/// Provider-neutral hero carousel used by catalogues and extensions.
///
/// The owner supplies the data and navigation callback; the visual treatment
/// stays the same for TMDB and extension content.
class MediaHeroCarousel extends StatelessWidget {
  const MediaHeroCarousel({
    required this.items,
    required this.onOpen,
    super.key,
  });

  final List<ContentItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    final visible = items.take(10).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    // Extra bottom room lets the notch/play disc overhang the hero edge.
    return SizedBox(
      width: double.infinity,
      height: heroHeight + 36,
      child: AppCrossfadeCarousel(
        itemCount: visible.length,
        onItemTap: onOpen,
        clipRadius: 0,
        itemBuilder: (context, index) {
          final item = visible[index];
          return Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: item.backdropUrl ?? item.posterUrl,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, .42, 1],
                      colors: [
                        Color(0x52000000),
                        Color(0x15000000),
                        Color(0xE6000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags — bottom-left, above the title
                      if (item.badge != null || (item.rating != null && item.rating! > 0)) ...[
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            if (item.badge != null)
                              _MediaMetaChip(label: item.badge!),
                            if (item.rating != null && item.rating! > 0)
                              _MediaMetaChip(
                                label: item.rating!.toStringAsFixed(1),
                              ),
                          ],
                        ),
                        const SizedBox(height: 9),
                      ],
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (item.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.3,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Notch (half-circle cut) at the hero's bottom edge…
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -30,
                  child: Center(
                    child: AppHeroNotch(
                      backgroundColor: const Color(0xFF0B0B11),
                      ringColor: Colors.white.withValues(alpha: .55),
                    ),
                  ),
                ),
                // …with the play disc sitting in the cut.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -34,
                  child: Center(
                    child: AppHeroPlayButton(
                      size: 62,
                      onTap: () => onOpen(index),
                    ),
                  ),
                ),
              ],
            );
        },
      ),
    );
  }
}

class MediaPosterRail extends StatelessWidget {
  const MediaPosterRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          width: double.infinity,
          height: cardWidth * 1.5 + 62,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AppUI.pagePadding(context) : 10,
                top: 8,
                bottom: 8,
              ),
              child: SizedBox(
                width: cardWidth,
                child: PosterCard(
                  item: items[index],
                  width: cardWidth,
                  onTap: () => onOpen(index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaLandscapeRail extends StatelessWidget {
  const MediaLandscapeRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.width = 238,
    this.height = 184,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => LandscapeCard(
              item: items[index],
              width: width,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaRankedRail extends StatelessWidget {
  const MediaRankedRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 208,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => RankedCard(
              item: items[index],
              rank: index + 1,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaBannerRail extends StatelessWidget {
  const MediaBannerRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final visible = items
        .take(8)
        .toList(growable: false)
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.value.backdropUrl != null || entry.value.posterUrl != null,
        )
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        ...visible.map(
          (entry) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              0,
              AppUI.pagePadding(context),
              12,
            ),
            child: GestureDetector(
              onTap: () => onOpen(entry.key),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 2.05,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ContentImage(
                        url: entry.value.backdropUrl ?? entry.value.posterUrl,
                        radius: 0,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE6000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Text(
                          entry.value.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaGridSection extends StatelessWidget {
  const MediaGridSection({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.columns,
    this.rows,
    this.scrollDirection,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;
  final int? columns;
  final int? rows;
  final String? scrollDirection;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final columnCount = (columns ?? 3).clamp(2, 5).toInt();
    final rowCount = (rows ?? (items.length / columnCount).ceil())
        .clamp(1, 4)
        .toInt();
    final horizontal = scrollDirection == 'horizontal';
    final visible = items
        .take(columnCount * rowCount)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: horizontal ? rowCount * 166 : rowCount * 215,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
            physics: horizontal
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: horizontal ? rowCount : columnCount,
              mainAxisExtent: horizontal ? 132 : null,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: .55,
            ),
            itemBuilder: (_, index) => PosterCard(
              item: visible[index],
              width: double.infinity,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaMetaChip extends StatelessWidget {
  const _MediaMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
