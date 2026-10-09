import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/utils/cached_network.dart';

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
    posterUrl: _nonEmptyImageUrl(item.imageUrl),
    backdropUrl: _nonEmptyImageUrl(item.imageUrl),
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

String? _nonEmptyImageUrl(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    final rating = item.rating;

    return TvPressable(
      onTap: onTap,
      borderRadius: radius,
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
                    if (rating != null && rating > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _RatingPill(rating: rating),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 5 : 6),
            Text(
              item.title,
              // Sous 140 px de carte, deux lignes de titre ne tiennent plus
              // dans la cellule de grille : on les limite à une ligne.
              maxLines: compact || width < 140 ? 1 : 2,
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
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return TvPressable(
      onTap: onTap,
      borderRadius: 16,
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
            if (item.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 3),
              Text(
                item.description!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    return TvPressable(
      onTap: onTap,
      borderRadius: 12,
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
        : cachedNetworkImage(
            imageUrl: image,
            width: null,
            height: null,
            fit: fit,
            errorWidget: const _ContentImagePlaceholder(),
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

class _ContentImagePlaceholder extends StatelessWidget {
  const _ContentImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('content-image-placeholder'),
      color: colors.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.surfaceContainerHighest, colors.surface],
              ),
            ),
          ),
          Positioned(
            top: -22,
            right: -18,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: .55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: .10),
                ),
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 22,
                color: colors.onSurfaceVariant.withValues(alpha: .72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
