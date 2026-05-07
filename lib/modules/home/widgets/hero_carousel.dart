import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';

/// Auto-cycling banner carousel.
///
/// [forceFullWidth] = true → cinematic edge-to-edge mode used on the home
/// screen hero.  In this mode the description text is rendered **on the
/// image** (there is enough room), the synopsis strip below is suppressed,
/// and the card height is set to 62 % of the screen.
class HeroCarousel extends ConsumerStatefulWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onItemTap;
  final bool forceFullWidth;

  const HeroCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
    this.forceFullWidth = false,
  });

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_index + 1) % widget.items.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final carouselStyle = ref.watch(carouselStyleProvider);
    final showSynopsis = ref.watch(carouselSynopsisProvider);
    final theme = Theme.of(context);
    final screenH = MediaQuery.sizeOf(context).height;

    final isCinematic = widget.forceFullWidth || carouselStyle == 1;
    final isCompact = !widget.forceFullWidth && carouselStyle == 2;

    final cardHeight = widget.forceFullWidth
        ? screenH * 0.62
        : (isCompact ? 190.0 : 270.0);
    final viewportFraction = isCinematic ? 1.0 : (isCompact ? 0.88 : 0.92);

    // For the home hero carousel we use an inner PageController that is
    // separate from the outer one used for animation tracking so we don't
    // get "position not attached" errors.
    final innerController = PageController(viewportFraction: viewportFraction);

    return SizedBox(
      // When forceFullWidth we put the synopsis INSIDE the image, so no
      // extra height is needed below the card.
      height: (!widget.forceFullWidth && showSynopsis && !isCompact)
          ? cardHeight + 86
          : cardHeight,
      child: Column(
        children: [
          SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: innerController,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final m = widget.items[i];
                final image = m.bannerImage ?? m.bestCover;

                return Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: isCinematic ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => widget.onItemTap(m),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isCinematic ? 0 : 20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Cover / banner image ──────────────────────────
                          if (image != null)
                            ExtendedImage.network(
                              image,
                              fit: BoxFit.cover,
                              cache: true,
                            )
                          else
                            Container(
                              color: theme
                                  .colorScheme.surfaceContainerHighest,
                            ),

                          // ── Gradient scrim: subtle at top, heavy at bottom
                          //    so the info overlay pops ──────────────────────
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.38, 1.0],
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.92),
                                ],
                              ),
                            ),
                          ),

                          // ── Info overlay — always on the image ───────────
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: isCinematic ? 36 : 28,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Badges row
                                Row(
                                  children: [
                                    _TypeBadge(m.type, m.format,
                                        m.countryOfOrigin),
                                    if (m.averageScore != null) ...[
                                      const SizedBox(width: 8),
                                      _ScoreBadge(m.averageScore!),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Title
                                Text(
                                  m.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                // ── Description text ON the image ─────────
                                // Shown when there is enough vertical space
                                // (forceFullWidth / cinematic mode).
                                if (isCinematic &&
                                    m.description != null &&
                                    m.description!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    m.description!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      height: 1.45,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Genres
                                if (m.genres.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: m.genres
                                          .take(3)
                                          .map(
                                            (g) => Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      right: 6),
                                              child: _GenrePill(g),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // ── Page indicator dots ───────────────────────────
                          Positioned(
                            bottom: isCinematic ? 16 : 10,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.items.length > 8
                                    ? 8
                                    : widget.items.length,
                                (di) => AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  width: _index == di ? 18 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: _index == di
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.35),
                                    borderRadius:
                                        BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Optional synopsis strip below carousel ──────────────────────
          // Only shown when NOT forceFullWidth (description is on the image
          // in that mode so no need for a strip below).
          if (!widget.forceFullWidth &&
              showSynopsis &&
              !isCompact &&
              widget.items.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _SynopsisRow(
                key: ValueKey(_index),
                media: widget
                    .items[_index.clamp(0, widget.items.length - 1)],
                onTap: () => widget.onItemTap(
                    widget.items[_index.clamp(0, widget.items.length - 1)]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Synopsis strip (non-forceFullWidth only) ──────────────────────────────────

class _SynopsisRow extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;

  const _SynopsisRow({super.key, required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desc = media.description;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media.bestCover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ExtendedImage.network(
                  media.bestCover!,
                  width: 44,
                  height: 62,
                  fit: BoxFit.cover,
                  cache: true,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.60),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final String? format;
  final String? country;
  const _TypeBadge(this.type, this.format, this.country);

  String get _label {
    if (format == 'NOVEL') return 'Novel';
    if (country == 'KR') return 'Manhwa';
    if (country == 'CN') return 'Manhua';
    return type == 'MANGA' ? 'Manga' : 'Anime';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge(this.score);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
          const SizedBox(width: 3),
          Text(
            (score / 10).toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String genre;
  const _GenrePill(this.genre);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        genre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
