import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';

/// Cinematic auto-cycling hero carousel.
///
/// Design:
///   • viewportFraction 0.88 → peek of next card on the right
///   • Rounded corners 16 px
///   • Height: 54 % of screen
///   • Strong bottom-gradient scrim — fades into scaffold background
///   • Info overlay: badge row → title → description → genre pills → dots
class HeroCarousel extends ConsumerStatefulWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onItemTap;
  final bool forceFullWidth;
  final void Function(Color)? onColorExtracted;
  final double topPadding;

  const HeroCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
    this.forceFullWidth = false,
    this.onColorExtracted,
    this.topPadding = 0.0,
  });

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  static const _autoplayInterval = Duration(seconds: 6);
  static const _animDuration = Duration(milliseconds: 520);
  static const _animCurve = Curves.easeOutCubic;

  late PageController _ctrl;
  Timer? _timer;
  int _page = 0;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 1.0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoplayInterval, (_) {
      if (!mounted || widget.items.isEmpty || _hovering) return;
      _ctrl.animateToPage(
        (_page + 1) % widget.items.length,
        duration: _animDuration,
        curve: _animCurve,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final showSynopsis = ref.watch(carouselSynopsisProvider);
    final screenH = MediaQuery.sizeOf(context).height;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // Hero height: cinematic. In landscape the screen height is short (≈ 360dp),
    // so we use a higher fraction to maintain visual impact.
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final cardH = isLandscape
        ? screenH * 0.70
        : (widget.forceFullWidth ? screenH * 0.36 : screenH * 0.34);

    final effectiveCardH = cardH + widget.topPadding;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: SizedBox(
          height: effectiveCardH,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() => _page = i);
            },
            itemBuilder: (ctx, i) {
              final m = widget.items[i];
              final image = m.bannerImage ?? m.bestCover;

              return GestureDetector(
                onTap: () => widget.onItemTap(m),
                child: ClipRect(
                  child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Poster / Banner image ───────────────────────
                          if (image != null)
                            ExtendedImage.network(
                              image,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.3),
                              cache: true,
                              loadStateChanged: (state) {
                                if (state.extendedImageLoadState ==
                                    LoadState.completed) return null;
                                // Shimmer-style placeholder while loading or on error
                                return Container(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(
                                      Icons.movie_creation_outlined,
                                      size: 48,
                                      color: Colors.white24,
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                child: Icon(
                                  Icons.movie_creation_outlined,
                                  size: 48,
                                  color: Colors.white24,
                                ),
                              ),
                            ),

                          // ── Top edge scrim (blur→image seamless) ─────────
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: SizedBox(
                                height: 32,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.18),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                            // ── Brush gradient scrim (bottom only) ──────────
                          // Heavy bottom fade → scaffold bg so the carousel
                          // "paints" seamlessly into the tab bar below —
                          // zero top fade now that tabs are beneath carousel.
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.38, 0.58, 0.76, 1.0],
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.38),
                                    Colors.black.withValues(alpha: 0.72),
                                    scaffoldBg,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Episode count pill — top left ────────────────
                          if (m.episodes != null && m.episodes! > 0)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _Badge(
                                label: '${m.episodes}',
                                bg: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),

                          // ── Score badge — top right ──────────────────────
                          if (m.averageScore != null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _ScoreBadge(m.averageScore!),
                            ),

                          // ── Info overlay ────────────────────────────────
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 18,
                            child: _CardInfo(
                              media: m,
                              page: _page,
                              totalPages: widget.items.length > 8
                                  ? 8
                                  : widget.items.length,
                              pageIndex: i,
                            ),
                          ),
                        ],
                      ),
                    ),
              );
            },
          ),
        ),
        ),

        // ── Optional synopsis strip ────────────────────────────────────────
        if (!widget.forceFullWidth &&
            showSynopsis &&
            widget.items.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _SynopsisStrip(
              key: ValueKey(_page),
              media:
                  widget.items[_page.clamp(0, widget.items.length - 1)],
              onTap: () => widget.onItemTap(
                  widget.items[_page.clamp(0, widget.items.length - 1)]),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card info overlay
// ─────────────────────────────────────────────────────────────────────────────

class _CardInfo extends StatelessWidget {
  final AnilistMedia media;
  final int page;
  final int totalPages;
  final int pageIndex;

  const _CardInfo({
    required this.media,
    required this.page,
    required this.totalPages,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Type badge (small, no score — score is top-right)
        Row(
          children: [
            _Badge(
              label: _typeLabel(media.type, media.format, media.countryOfOrigin),
              bg: Colors.white.withValues(alpha: 0.18),
            ),
            if (media.episodes != null) ...[
              const SizedBox(width: 6),
              _Badge(
                label: '${media.episodes} ép.',
                bg: Colors.black.withValues(alpha: 0.38),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          media.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.3,
            shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
          ),
        ),

        // Genre pills (2 max for compact layout)
        if (media.genres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: media.genres
                .take(2)
                .map((g) => _GenrePill(g))
                .toList(),
          ),
        ],

        // Page indicator dots
        const SizedBox(height: 10),
        Row(
          children: List.generate(totalPages, (di) {
            final isActive = page == di;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: isActive ? 20 : 5,
              height: 3,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _typeLabel(String type, String? format, String? country) {
    if (format == 'NOVEL') return 'Roman';
    if (country == 'KR') return 'Manhwa';
    if (country == 'CN') return 'Manhua';
    if (format == 'MOVIE') return 'Film';
    return type == 'MANGA' ? 'Manga' : 'Anime';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  const _Badge({required this.label, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
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
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              size: 11, color: Color(0xFFFFCC00)),
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
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Synopsis strip (non-fullWidth mode)
// ─────────────────────────────────────────────────────────────────────────────

class _SynopsisStrip extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  const _SynopsisStrip(
      {super.key, required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media.bestCover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ExtendedImage.network(
                  media.bestCover!,
                  width: 42,
                  height: 60,
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
                    style: tt.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (media.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      media.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13,
                color: cs.onSurface.withValues(alpha: 0.30)),
          ],
        ),
      ),
    );
  }
}
