import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';

/// Provider-neutral data used by every catalogue card.
///
/// The card only knows how to display content. Navigation and provider
/// behavior stay in the screen that owns the item.
@immutable
class ContentItem {
  const ContentItem({
    required this.key,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.description,
    this.rating,
    this.badge,
  });

  final String key;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? description;
  final double? rating;
  final String? badge;

  factory ContentItem.fromManga(MManga item) => ContentItem(
    key: 'extension-${item.link ?? item.name ?? item.hashCode}',
    title: item.name?.trim().isNotEmpty == true
        ? item.name!.trim()
        : 'Sans titre',
    posterUrl: item.imageUrl,
    backdropUrl: item.imageUrl,
    description: item.description,
    badge: item.status?.name,
  );

  factory ContentItem.fromTmdb(TmdbMedia item) => ContentItem(
    key: 'tmdb-${item.mediaType}-${item.id}',
    title: item.displayTitle,
    posterUrl: item.bestCover,
    backdropUrl: item.bannerImage,
    description: item.overview,
    rating: item.voteAverage,
    badge: item.mediaType == 'tv' ? 'Série' : 'Film',
  );

  factory ContentItem.fromAnilist(AnilistMedia item) => ContentItem(
    key: 'anilist-${item.type}-${item.id}',
    title: item.displayTitle,
    posterUrl: item.bestCover,
    backdropUrl: item.bannerImage,
    description: item.description,
    rating: item.averageScore == null ? null : item.averageScore! / 10,
    badge: item.format,
  );

  factory ContentItem.fromObject(Object item) {
    if (item is ContentItem) return item;
    if (item is MManga) return ContentItem.fromManga(item);
    if (item is TmdbMedia) return ContentItem.fromTmdb(item);
    if (item is AnilistMedia) return ContentItem.fromAnilist(item);
    return ContentItem(key: 'content-${item.hashCode}', title: item.toString());
  }
}

enum ContentCardVariant { poster, landscape, ranked, tag }

/// The shared poster card used by Films, Séries, AniList and extensions.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 120,
    this.heroTag,
    this.compact = false,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 11.0 : 14.0;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 11 : 11.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'content-${item.key}',
                      child: ContentImage(url: item.posterUrl, radius: radius),
                    ),
                    if (item.rating != null && item.rating! > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _RatingPill(rating: item.rating!),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 5 : 6),
            Text(
              item.title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared 16:9 card used for discovery rails and extension video rows.
class LandscapeCard extends StatelessWidget {
  const LandscapeCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 220,
    this.heroTag,
    this.showPlayButton = true,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;
  final bool showPlayButton;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'content-${item.key}',
                      child: ContentImage(
                        url: item.backdropUrl ?? item.posterUrl,
                        radius: 16,
                      ),
                    ),
                    if (showPlayButton)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _ArcPlayButton(
                          background: colors.surface,
                          onPressed: onTap,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.rating != null && item.rating! > 0) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Broken.star, size: 12, color: Colors.amberAccent),
                  const SizedBox(width: 3),
                  Text(
                    item.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared ranked poster card used by all Top/Popular sections.
class RankedCard extends StatelessWidget {
  const RankedCard({
    super.key,
    required this.item,
    required this.rank,
    required this.onTap,
    this.width = 110,
    this.heroTag,
  });

  final ContentItem item;
  final int rank;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;

  static const _rankColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rankColor = rank >= 1 && rank <= 3
        ? _rankColors[rank - 1]
        : colors.onSurface.withValues(alpha: .40);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: heroTag ?? 'content-${item.key}',
                      child: ContentImage(url: item.posterUrl, radius: 12),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: _RankLabel(
                      rank: rank,
                      color: rankColor,
                      outline: true,
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: _RankLabel(rank: rank, color: rankColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class TagCard extends StatelessWidget {
  const TagCard({super.key, required this.item, required this.onTap});

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF173E46), Color(0xFF236B70)],
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_offer_rounded,
              size: 16,
              color: Color(0xFF9AF3E2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentImage extends StatelessWidget {
  const ContentImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.radius = 14,
  });

  final String? url;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = url?.trim();
    final child = image == null || image.isEmpty
        ? const _ContentImagePlaceholder()
        : ExtendedImage.network(
            image,
            fit: fit,
            cache: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.completed) {
                return null;
              }
              return const AppShimmerBlock();
            },
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .70),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Broken.star, size: 10, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankLabel extends StatelessWidget {
  const _RankLabel({
    required this.rank,
    required this.color,
    this.outline = false,
  });

  final int rank;
  final Color color;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$rank',
      style: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        height: 1,
        color: outline ? null : color,
        foreground: outline
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.black.withValues(alpha: .60))
            : null,
      ),
    );
  }
}

class _ArcPlayButton extends StatelessWidget {
  const _ArcPlayButton({required this.background, required this.onPressed});

  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 54,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            size: const Size(82, 54),
            painter: _ArcPainter(background),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * .72)
      ..cubicTo(
        size.width * .1,
        size.height * .16,
        size.width * .9,
        size.height * .16,
        size.width,
        size.height * .72,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = background);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.background != background;
}

class _ContentImagePlaceholder extends StatelessWidget {
  const _ContentImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Broken.video, color: Colors.white54)),
    );
  }
}
