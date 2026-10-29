import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/extension_image_headers.dart';
import 'package:watchtower/modules/media/media_badges.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/log/logger.dart';

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
    this.countryCode,
    this.imageUrl,
    this.logoUrl,
    this.coverUrls = const [],
    this.genres = const [],
    this.badges = const [],
    this.meta,
  });

  final String key;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? description;
  final double? rating;
  final String? badge;
  final String? countryCode;

  /// Optional artwork that overrides [posterUrl] for cards that show a single
  /// wide visual (genre tiles, category cards).
  final String? imageUrl;

  /// Optional official brand mark for studios or networks.
  final String? logoUrl;

  /// Extra artwork used to build a visual collage for directories.
  final List<String> coverUrls;

  /// Genre labels for rich media cards.
  final List<String> genres;

  /// Compact metadata published by an extension: language, censorship,
  /// subtitles and dubs (`lang:ja`, `uncensored`, `sub:en`…). Rendered by
  /// [MediaBadgeStrip], so a card never needs a provider-specific widget.
  final List<String> badges;

  /// Optional free-form meta line (studio, genre, country…) for cards that
  /// display one instead of the badge.
  final String? meta;

  factory ContentItem.fromManga(MManga item) => ContentItem(
    key: 'extension-${item.link ?? item.name ?? item.hashCode}',
    title: item.name?.trim().isNotEmpty == true
        ? item.name!.trim()
        : 'Sans titre',
    posterUrl: _nonEmptyImageUrl(item.imageUrl),
    backdropUrl: _nonEmptyImageUrl(item.imageUrl),
    description: item.description,
    badge: item.status?.name,
    badges: item.badges ?? const [],
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
    countryCode: item.countryOfOrigin,
    imageUrl: item.bestBackdrop,
    genres: item.genres,
    meta: item.mainStudio,
  );

  /// A genre tile backed by a real artwork taken from the catalogue.
  factory ContentItem.genreTile({
    required String label,
    required String? imageUrl,
    String? key,
  }) => ContentItem(
    key: key ?? 'genre-${label.toLowerCase()}',
    title: label,
    posterUrl: imageUrl,
    backdropUrl: imageUrl,
    imageUrl: imageUrl,
    badge: label,
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
    this.showMediaMetadata = true,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;
  final bool compact;
  final bool showMediaMetadata;

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
                    if (showMediaMetadata &&
                        countryFlag(item.countryCode).isNotEmpty)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: _MediaBadge(
                          label: countryFlag(item.countryCode),
                          fontSize: 14,
                        ),
                      ),
                    if (showMediaMetadata &&
                        item.badge?.trim().isNotEmpty == true)
                      Positioned(
                        bottom: 7,
                        left: 7,
                        child: _MediaBadge(
                          label: _formatLabel(item.badge!),
                          fontSize: 8,
                        ),
                      ),
                    if (item.badges.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: MediaBadgeStrip(
                          tokens: item.badges,
                          dense: true,
                          onPoster: true,
                          max: 3,
                          axis: Axis.vertical,
                        ),
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

String countryFlag(String? code) {
  var normalized = code?.trim().toUpperCase();
  if (normalized == 'UK') normalized = 'GB';
  if (normalized == null ||
      normalized.length != 2 ||
      normalized.codeUnits.any((unit) => unit < 65 || unit > 90)) {
    return '';
  }
  return String.fromCharCodes(
    normalized.codeUnits.map((unit) => 0x1F1E6 + unit - 65),
  );
}

String _formatLabel(String value) => switch (value.toUpperCase()) {
  'TV' => 'SÉRIE',
  'TV_SHORT' => 'COURT',
  'MOVIE' => 'FILM',
  'ONA' => 'ONA',
  'OVA' => 'OVA',
  'SPECIAL' => 'SP',
  'NOVEL' => 'ROMAN',
  'MANGA' => 'MANGA',
  'MANHWA' => 'MANHWA',
  'ONE_SHOT' => '1-SHOT',
  _ => value.toUpperCase(),
};

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
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
  const TagCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 210,
    this.height,
    this.compact = false,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;

  /// Overrides the default rail height (58/72). The "see all" tag grid passes
  /// a taller value so the card shows a readable slice of its cover.
  final double? height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height ?? (compact ? 58 : 72),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: compact ? .30 : 1,
                child: ContentImage(
                  url: item.imageUrl ?? item.backdropUrl ?? item.posterUrl,
                  radius: 0,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: compact ? .54 : .20),
                      Colors.black.withValues(alpha: compact ? .48 : .38),
                      Colors.black.withValues(alpha: .78),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          size: 14,
                          color: accent.withValues(alpha: .95),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Only the roomy "see all" card has space for the video
                    // count; the rail tile stays a single line.
                    if (height != null && item.description?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 3),
                        child: Text(
                          item.description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Throttled reporter for covers that reach the UI without a URL.
///
/// A missing cover is the one failure the image pipeline cannot log for us —
/// there is no request to fail. It is reported here instead, so the release
/// log distinguishes "extension returned an empty imageUrl" from "download
/// failed". Logging every card would flood the log on a full home screen, so
/// the first 10 are reported, then every 25th one with a running total.
class _EmptyCoverLog {
  static int _seen = 0;

  static void report() {
    _seen++;
    if (_seen <= 10 || _seen % 25 == 0) {
      final coverLabel = _seen == 1 ? 'première carte' : '$_seen cartes';
      AppLogger.log(
        'cover vide: $coverLabel '
        'rendue(s) sans imageUrl → placeholder',
        logLevel: LogLevel.warning,
        tag: LogTag.image,
      );
    }
  }
}

class ContentImage extends StatelessWidget {
  const ContentImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.radius = 14,
    this.headers,
  });

  final String? url;
  final BoxFit fit;
  final double radius;

  /// Explicit request headers. When null, the headers declared by the
  /// enclosing extension screen are used (see [ExtensionImageHeaders]).
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      // The card has nothing to fetch: the item reached the UI without an
      // `imageUrl`. Reported here because the image pipeline cannot log a
      // request that never happens.
      _EmptyCoverLog.report();
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: const _ContentImagePlaceholder(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: cachedNetworkImage(
        imageUrl: image,
        width: null,
        height: null,
        fit: fit,
        headers: headers ?? ExtensionImageHeaders.of(context),
        errorWidget: const _ContentImagePlaceholder(),
      ),
    );
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
