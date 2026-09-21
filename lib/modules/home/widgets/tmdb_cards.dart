import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Poster card (2:3)
// ─────────────────────────────────────────────────────────────────────────────

class TmdbPosterCard extends StatelessWidget {
  final TmdbMedia media;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;

  const TmdbPosterCard({
    super.key,
    required this.media,
    required this.onTap,
    this.width = 120,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final score = media.voteAverage;
    final image = media.bestCover == null
        ? const _TmdbImagePlaceholder()
        : ExtendedImage.network(
            media.bestCover!,
            fit: BoxFit.cover,
            cache: true,
            loadStateChanged: (s) {
              if (s.extendedImageLoadState == LoadState.completed) return null;
              return const AppShimmerBlock();
            },
          );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? tmdbHeroTag(media),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: image,
                      ),
                    ),
                    // Score badge
                    if (score != null && score > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Broken.star,
                                size: 10,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                score.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
            const SizedBox(height: 6),
            Text(
              media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Landscape card (16:9)
// ─────────────────────────────────────────────────────────────────────────────

class TmdbLandscapeCard extends StatelessWidget {
  final TmdbMedia media;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;

  const TmdbLandscapeCard({
    super.key,
    required this.media,
    required this.onTap,
    this.width = 220,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final image = media.bannerImage ?? media.bestCover;
    final score = media.voteAverage;

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
                      tag: heroTag ?? tmdbHeroTag(media),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: image != null
                            ? ExtendedImage.network(
                                image,
                                fit: BoxFit.cover,
                                cache: true,
                                loadStateChanged: (s) {
                                  if (s.extendedImageLoadState ==
                                      LoadState.completed) {
                                    return null;
                                  }
                                  return const AppShimmerBlock(radius: 0);
                                },
                              )
                            : Container(color: cs.surfaceContainerHighest),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              media.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (score != null && score > 0) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Broken.star, size: 12, color: Colors.amberAccent),
                  const SizedBox(width: 3),
                  Text(
                    score.toStringAsFixed(1),
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

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Ranked card (poster + rank number)
// ─────────────────────────────────────────────────────────────────────────────

class TmdbRankedCard extends StatelessWidget {
  final TmdbMedia media;
  final int rank;
  final VoidCallback onTap;
  final String? heroTag;

  const TmdbRankedCard({
    super.key,
    required this.media,
    required this.rank,
    required this.onTap,
    this.heroTag,
  });

  static const _rankColors = [
    Color(0xFFFFD700), // #1 gold
    Color(0xFFC0C0C0), // #2 silver
    Color(0xFFCD7F32), // #3 bronze
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rankColor = rank <= 3
        ? _rankColors[rank - 1]
        : cs.onSurface.withValues(alpha: 0.40);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: heroTag ?? tmdbHeroTag(media),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: media.bestCover != null
                            ? ExtendedImage.network(
                                media.bestCover!,
                                fit: BoxFit.cover,
                                cache: true,
                                loadStateChanged: (s) {
                                  if (s.extendedImageLoadState ==
                                      LoadState.completed) {
                                    return null;
                                  }
                                  return const AppShimmerBlock();
                                },
                              )
                            : const AppShimmerBlock(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black.withValues(alpha: 0.60),
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              media.displayTitle,
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

String tmdbHeroTag(TmdbMedia media, [String source = 'default']) =>
    'tmdb-${media.mediaType}-${media.id}-$source';

void pushTmdbMediaDetail(
  BuildContext context,
  TmdbMedia media, {
  String source = 'default',
}) {
  context.push(
    '/flixMediaDetail',
    extra: TmdbMediaDetailRoute(
      media: media,
      heroTag: tmdbHeroTag(media, source),
    ),
  );
}

class _TmdbImagePlaceholder extends StatelessWidget {
  const _TmdbImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Broken.video),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TMDB Hero carousel item (full width, for HeroCarousel compatibility)
// ─────────────────────────────────────────────────────────────────────────────

class TmdbHeroCarousel extends StatefulWidget {
  final List<TmdbMedia> items;
  final void Function(TmdbMedia) onTap;
  final double topPadding;

  const TmdbHeroCarousel({
    super.key,
    required this.items,
    required this.onTap,
    this.topPadding = 0.0,
  });

  @override
  State<TmdbHeroCarousel> createState() => _TmdbHeroCarouselState();
}

class _TmdbHeroCarouselState extends State<TmdbHeroCarousel> {
  late PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      final next = (_page + 1) % widget.items.length;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      _startAutoPlay();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final screenH = MediaQuery.sizeOf(context).height;
    final carouselH = widget.topPadding + screenH * 0.34;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: carouselH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) {
              final m = widget.items[i];
              final img = m.bannerImage ?? m.bestCover;
              return GestureDetector(
                onTap: () => widget.onTap(m),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img != null)
                      ExtendedImage.network(img, fit: BoxFit.cover, cache: true)
                    else
                      Container(color: cs.surfaceContainerHighest),
                    // Top gradient (behind header)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: widget.topPadding + 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom info overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, 60, 20, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              cs.surface.withValues(alpha: 0.80),
                              cs.surface,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                            ),
                            if (m.voteAverage != null &&
                                m.voteAverage! > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Broken.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${m.voteAverage!.toStringAsFixed(1)} / 10',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(
                                        alpha: 0.70,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Page dots
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length.clamp(0, 10),
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
