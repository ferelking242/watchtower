import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Standard poster card (2:3 ratio)
// ─────────────────────────────────────────────────────────────────────────────

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
                // bottom gradient
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 80,
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
                // title
                Positioned(
                  left: 8, right: 8, bottom: 8,
                  child: Text(
                    media.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
                // score chip
                if (media.averageScore != null)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                          const SizedBox(width: 2),
                          Text(
                            (media.averageScore! / 10).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// Ranked card — poster with a big rank number on the left side
// ─────────────────────────────────────────────────────────────────────────────

class RankedDiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final int rank;
  final VoidCallback onTap;

  const RankedDiscoveryCard({
    super.key,
    required this.media,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const cardWidth = 100.0;
    const cardHeight = 150.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth + 36,
        height: cardHeight,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            // Big rank number (behind the card)
            Positioned(
              left: 0,
              bottom: 8,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5
                    ..color = cs.primary.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 8,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: cs.surface.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Card
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (media.bestCover != null)
                        ExtendedImage.network(
                          media.bestCover!,
                          fit: BoxFit.cover,
                          cache: true,
                          loadStateChanged: (s) {
                            if (s.extendedImageLoadState == LoadState.completed) return null;
                            return Container(color: theme.colorScheme.surfaceContainerHighest);
                          },
                        )
                      else
                        Container(color: theme.colorScheme.surfaceContainerHighest),
                      // Bottom gradient + title
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: 64,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6, right: 6, bottom: 6,
                        child: Text(
                          media.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape card — wider 16:9 banner card for movies / episodes
// ─────────────────────────────────────────────────────────────────────────────

class LandscapeDiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final double width;

  const LandscapeDiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = media.bannerImage ?? media.bestCover;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  ExtendedImage.network(
                    image,
                    fit: BoxFit.cover,
                    cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) return null;
                      return Container(color: theme.colorScheme.surfaceContainerHighest);
                    },
                  )
                else
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                // full gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                // Play button
                Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  ),
                ),
                // Title + score
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        media.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                      if (media.averageScore != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                            const SizedBox(width: 3),
                            Text(
                              (media.averageScore! / 10).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Type badge
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      media.format?.toUpperCase() ?? 'MOVIE',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Featured card — tall hero card (first item in trending row)
// ─────────────────────────────────────────────────────────────────────────────

class FeaturedDiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;

  const FeaturedDiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final image = media.bannerImage ?? media.bestCover;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 180,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  ExtendedImage.network(
                    image,
                    fit: BoxFit.cover,
                    cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) return null;
                      return Container(color: theme.colorScheme.surfaceContainerHighest);
                    },
                  )
                else
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                // gradient
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
                    ),
                  ),
                ),
                // Featured badge
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Info
                Positioned(
                  left: 12, right: 12, bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (media.genres.isNotEmpty)
                        Text(
                          media.genres.take(2).join(' • '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        media.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      if (media.averageScore != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Colors.amberAccent),
                            const SizedBox(width: 4),
                            Text(
                              (media.averageScore! / 10).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Legacy DiscoveryRow (kept for backwards compat)
// ─────────────────────────────────────────────────────────────────────────────

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
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
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
