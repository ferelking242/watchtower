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
  bool _warmed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 1.0);
    _startTimer();
    _warmImages();
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _warmImages();
  }

  /// Decode every poster/banner up front so a card never shows a bare colour
  /// block while its artwork downloads. Runs after the first frame so the
  /// carousel itself paints instantly, then the images snap in from cache.
  void _warmImages() {
    if (_warmed) return;
    _warmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final m in widget.items) {
        final url = m.bannerImage ?? m.bestCover;
        if (url == null || url.isEmpty) continue;
        precacheImage(ExtendedNetworkImageProvider(url, cache: true), context)
            .catchError((_) {});
      }
    });
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
            // Build the neighbouring pages too, so their artwork starts
            // loading before the user ever swipes to them.
            allowImplicitScrolling: true,
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
                          // `_HeroImage` shows the artwork immediately from the
                          // memory cache when warm, and otherwise a neutral
                          // backdrop (never a bare flat colour) while it fades
                          // in — no more "colours only" cards.
                          if (image != null)
                            _HeroImage(url: image)
                          else
                            const _HeroPlaceholder(),

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
// Hero artwork — instant when cached, neutral fade-in otherwise.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroImage extends StatefulWidget {
  final String url;
  const _HeroImage({required this.url});

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  bool _loaded = false;
  bool _failed = false;

  @override
  void didUpdateWidget(_HeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loaded = false;
      _failed = false;
    }
  }

  /// `loadStateChanged` runs during build, so a state change has to be
  /// deferred to the end of the frame.
  void _settle({bool loaded = false, bool failed = false}) {
    if ((loaded && _loaded) || (failed && _failed)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (loaded) _loaded = true;
        if (failed) _failed = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Neutral backdrop shown until the first frame of the artwork is
        // ready. Prevents a bright flat colour flashing before the poster.
        _HeroPlaceholder(failed: _failed),
        AnimatedOpacity(
          opacity: _loaded ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          // Fade the artwork over the neutral backdrop so the transition is
          // smooth whether it came from cache or the network.
          child: ExtendedImage.network(
            widget.url,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
            cache: true,
            clearMemoryCacheIfFailed: false,
            clearMemoryCacheWhenDispose: false,
            loadStateChanged: (state) {
              switch (state.extendedImageLoadState) {
                case LoadState.completed:
                  _settle(loaded: true);
                  return null;
                case LoadState.failed:
                  _settle(failed: true);
                  return null;
                case LoadState.loading:
                  return null;
              }
            },
          ),
        ),
      ],
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final bool failed;
  const _HeroPlaceholder({this.failed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest,
            cs.surfaceContainerHigh,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          failed ? Icons.broken_image_outlined : Icons.image_outlined,
          size: 44,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
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
