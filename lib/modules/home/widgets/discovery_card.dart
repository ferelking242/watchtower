import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// Compact poster card — title overlaid inside the image, score chip in
/// the top-left corner of the poster.
class DiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final double width;

  const DiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (media.bestCover != null)
                  ExtendedImage.network(
                    media.bestCover!,
                    fit: BoxFit.cover,
                    cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) {
                        return null;
                      }
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      );
                    },
                  )
                else
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                // bottom gradient for title legibility
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                // title at bottom of image
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    media.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // score chip — top-left corner
                if (media.averageScore != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Colors.amberAccent),
                          const SizedBox(width: 2),
                          Text(
                            (media.averageScore! / 10).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrolling row of [DiscoveryCard]s with a section title and
/// an optional "See all" link on the right.
class DiscoveryRow extends StatelessWidget {
  final String title;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onItemTap;
  final VoidCallback? onSeeAll;

  const DiscoveryRow({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => DiscoveryCard(
              media: items[i],
              onTap: () => onItemTap(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}
