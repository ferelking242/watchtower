import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card helpers
// ─────────────────────────────────────────────────────────────────────────────

String _countryFlag(String? code) {
  const flags = {'JP': '🇯🇵', 'KR': '🇰🇷', 'CN': '🇨🇳', 'TW': '🇹🇼'};
  return flags[code?.toUpperCase()] ?? '';
}

String _fmtLabel(String? fmt) {
  switch (fmt?.toUpperCase()) {
    case 'TV':       return 'SÉRIE';
    case 'TV_SHORT': return 'COURT';
    case 'MOVIE':    return 'FILM';
    case 'ONA':      return 'ONA';
    case 'OVA':      return 'OVA';
    case 'SPECIAL':  return 'SP';
    case 'NOVEL':    return 'ROMAN';
    case 'MANGA':    return 'MANGA';
    case 'MANHWA':   return 'MANHWA';
    case 'ONE_SHOT': return '1-SHOT';
    default:         return fmt?.toUpperCase() ?? '';
  }
}

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
    final flag = _countryFlag(media.countryOfOrigin);
    final fmt  = _fmtLabel(media.format);

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
                // Cover image
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
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),

                // Bottom gradient scrim
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
                      ),
                    ),
                  ),
                ),

                // Title
                Positioned(
                  left: 8, right: 8, bottom: 8,
                  child: Text(
                    media.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ),

                // Score chip — top left
                if (media.averageScore != null)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                          const SizedBox(width: 2),
                          Text(
                            (media.averageScore! / 10).toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Country flag + format badge — top right
                Positioned(
                  top: 6, right: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (flag.isNotEmpty)
                        Text(flag, style: const TextStyle(fontSize: 15)),
                      if (fmt.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            fmt,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.4,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
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
// Ranked card — poster with big rank number on the left side
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
    const cardWidth  = 100.0;
    const cardHeight = 150.0;
    final flag = _countryFlag(media.countryOfOrigin);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth + 36,
        height: cardHeight,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            // Big rank number (behind card)
            Positioned(
              left: 0, bottom: 8,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w900, height: 1.0,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5
                    ..color = cs.primary.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              left: 0, bottom: 8,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w900, height: 1.0,
                  color: cs.surface.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Card
            Positioned(
              right: 0, top: 0, bottom: 0,
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
                          media.bestCover!, fit: BoxFit.cover, cache: true,
                          loadStateChanged: (s) {
                            if (s.extendedImageLoadState == LoadState.completed) return null;
                            return Container(color: cs.surfaceContainerHighest);
                          },
                        )
                      else
                        Container(color: cs.surfaceContainerHighest),
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: 64,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6, right: 6, bottom: 6,
                        child: Text(
                          media.displayTitle,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                        ),
                      ),
                      if (flag.isNotEmpty)
                        Positioned(
                          top: 5, right: 5,
                          child: Text(flag, style: const TextStyle(fontSize: 13)),
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
    final flag = _countryFlag(media.countryOfOrigin);
    final fmt  = _fmtLabel(media.format);

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
                    image, fit: BoxFit.cover, cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) return null;
                      return Container(color: theme.colorScheme.surfaceContainerHighest);
                    },
                  )
                else
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                // Gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                // Play button
                Center(
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  ),
                ),
                // Title + score + episodes — bottom left
                Positioned(
                  left: 10, right: 70, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        media.displayTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (media.averageScore != null) ...[
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                            const SizedBox(width: 3),
                            Text(
                              (media.averageScore! / 10).toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (media.episodes != null && media.episodes! > 0) ...[
                            if (media.averageScore != null)
                              const Text('  ·  ', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const Icon(Icons.play_circle_outline_rounded, size: 11, color: Colors.white60),
                            const SizedBox(width: 3),
                            Text(
                              '${media.episodes} ép.',
                              style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Top-right: format badge + country flag
                Positioned(
                  top: 8, right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          fmt.isNotEmpty ? fmt : (media.format?.toUpperCase() ?? 'MOVIE'),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                        ),
                      ),
                      if (flag.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(flag, style: const TextStyle(fontSize: 16)),
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
    final flag = _countryFlag(media.countryOfOrigin);

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
                    image, fit: BoxFit.cover, cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) return null;
                      return Container(color: cs.surfaceContainerHighest);
                    },
                  )
                else
                  Container(color: cs.surfaceContainerHighest),
                // Gradient
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
                    ),
                  ),
                ),
                // FEATURED badge — top left
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
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                  ),
                ),
                // Country flag — top right
                if (flag.isNotEmpty)
                  Positioned(
                    top: 12, right: 12,
                    child: Text(flag, style: const TextStyle(fontSize: 18)),
                  ),
                // Info — bottom
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
                            fontSize: 10, fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        media.displayTitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (media.averageScore != null) ...[
                            const Icon(Icons.star_rounded, size: 13, color: Colors.amberAccent),
                            const SizedBox(width: 4),
                            Text(
                              (media.averageScore! / 10).toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (media.episodes != null && media.episodes! > 0) ...[
                            if (media.averageScore != null) const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${media.episodes} ép.',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
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
// Saga card — wide 16:10 card for long-running franchise rows
// ─────────────────────────────────────────────────────────────────────────────

class SagaDiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;

  const SagaDiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = media.bannerImage ?? media.bestCover;
    final flag  = _countryFlag(media.countryOfOrigin);
    final fmt   = _fmtLabel(media.format);
    final eps   = media.episodes;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  ExtendedImage.network(
                    image, fit: BoxFit.cover, cache: true,
                    loadStateChanged: (s) {
                      if (s.extendedImageLoadState == LoadState.completed) return null;
                      return Container(color: cs.surfaceContainerHighest);
                    },
                  )
                else
                  Container(color: cs.surfaceContainerHighest),
                // Gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      stops: [0.15, 1.0],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                // Top-right: flag + format
                Positioned(
                  top: 8, right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (flag.isNotEmpty)
                        Text(flag, style: const TextStyle(fontSize: 16)),
                      if (fmt.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            fmt,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Episode count badge
                if (eps != null && eps > 0)
                  Positioned(
                    bottom: 32, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, size: 11, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '$eps ép.',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Bottom: title + score
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        media.displayTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                      if (media.averageScore != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 11, color: Colors.amberAccent),
                            const SizedBox(width: 3),
                            Text(
                              (media.averageScore! / 10).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600,
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
// Spotlight card — wide cinematic editorial card for the "Coup de cœur" row
// ─────────────────────────────────────────────────────────────────────────────

class SpotlightDiscoveryCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;

  const SpotlightDiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = media.bannerImage ?? media.bestCover;
    final flag = _countryFlag(media.countryOfOrigin);
    final fmt  = _fmtLabel(media.format);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 2.5 / 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (image != null)
                ExtendedImage.network(
                  image,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cache: true,
                  loadStateChanged: (s) {
                    if (s.extendedImageLoadState == LoadState.completed) return null;
                    return Container(color: cs.surfaceContainerHighest);
                  },
                )
              else
                Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.movie_creation_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.20)),
                ),

              // Cinematic horizontal gradient (right → left)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    stops: const [0.0, 0.45, 0.85],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),

              // Right-side bottom gradient (title area bleed)
              Align(
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                  child: const SizedBox(height: 60, width: double.infinity),
                ),
              ),

              // Left side content
              Positioned(
                left: 16, top: 0, bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "COUP DE CŒUR" label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE84393), Color(0xFF6C5CE7)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'COUP DE CŒUR',
                        style: TextStyle(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // Title
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        media.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900,
                          letterSpacing: -0.5, height: 1.15,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // Score + format + flag row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (media.averageScore != null) ...[
                          const Icon(Icons.star_rounded, size: 13, color: Colors.amberAccent),
                          const SizedBox(width: 3),
                          Text(
                            (media.averageScore! / 10).toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (fmt.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                            ),
                            child: Text(fmt, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        if (flag.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Text(flag, style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                    if (media.genres.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        media.genres.take(3).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 10.5, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Top-right: episode count (if available)
              if (media.episodes != null && media.episodes! > 0)
                Positioned(
                  top: 12, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 11, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${media.episodes} ép.',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                        'Voir tout',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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

// ─────────────────────────────────────────────────────────────────────────────
// Animated wrapper — staggered fade-in + slide for horizontal card lists
// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in replacement for [DiscoveryCard] that plays a staggered
/// fade-in + upward slide animation when the card is first mounted.
/// Use [delay] to offset successive cards in a row.
class AnimatedDiscoveryCard extends StatefulWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final double width;
  final Duration delay;

  const AnimatedDiscoveryCard({
    super.key,
    required this.media,
    required this.onTap,
    this.width = 120,
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedDiscoveryCard> createState() => _AnimatedDiscoveryCardState();
}

class _AnimatedDiscoveryCardState extends State<AnimatedDiscoveryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: DiscoveryCard(media: widget.media, onTap: widget.onTap, width: widget.width),
      ),
    );
  }
}
