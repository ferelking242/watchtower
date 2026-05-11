import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:palette_generator/palette_generator.dart';

/// Auto-cycling banner carousel.
///
/// [forceFullWidth] = true → cinematic hero mode used on the home screen.
/// In this mode the card extends nearly edge-to-edge with generous rounded
/// corners (Disney+/streaming-app style).  Description text is rendered on
/// the image and the synopsis strip below is suppressed.
///
/// Card sizing:
///   forceFullWidth → 62 % of screen height, h-padding 14, radius 22
///   compact        → 190 px, h-padding 6,  radius 16
///   standard       → 270 px, h-padding 6,  radius 20
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
  Timer? _timer;
  int _index = 0;
  Color? _dominantColor;
  String? _lastExtractedUrl;

  // Stable PageController — only recreated when viewportFraction changes.
  late PageController _ctrl;
  double _viewportFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: _viewportFraction);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.items.isNotEmpty) _extractDominantColor(widget.items[0]);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_index + 1) % widget.items.length;
      if (_ctrl.hasClients) {
        _ctrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _extractDominantColor(AnilistMedia media) async {
    final url = media.bannerImage ?? media.bestCover;
    if (url == null || url == _lastExtractedUrl) return;
    _lastExtractedUrl = url;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(300, 168),
        maximumColorCount: 8,
        timeout: const Duration(seconds: 4),
      );
      final color = generator.darkVibrantColor?.color ??
          generator.darkMutedColor?.color ??
          generator.dominantColor?.color;
      if (color != null && mounted) setState(() => _dominantColor = color);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  double _computeVpFraction(bool isCinematic, bool isCompact) {
    if (isCinematic) return 1.0;
    if (isCompact) return 0.88;
    return 0.92;
  }

  void _maybeRebuildController(double newFraction) {
    if (newFraction == _viewportFraction) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final old = _ctrl;
      setState(() {
        _viewportFraction = newFraction;
        _ctrl = PageController(viewportFraction: newFraction);
      });
      old.dispose();
    });
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

    // ── Controller lifecycle ──────────────────────────────────────────────────
    final desiredFraction = _computeVpFraction(isCinematic, isCompact);
    _maybeRebuildController(desiredFraction);

    // ── Sizing & rounding ─────────────────────────────────────────────────────
    // forceFullWidth: large hero — rounded corners + side padding (streaming style)
    final cardHeight = widget.forceFullWidth
        ? screenH * 0.62
        : (isCompact ? 190.0 : 270.0);

    final double hPadding = widget.forceFullWidth
        ? 14.0
        : (isCompact ? 6.0 : 6.0);

    final double cardRadius = widget.forceFullWidth
        ? 22.0
        : (isCompact ? 16.0 : 20.0);

    final totalHeight = (!widget.forceFullWidth && showSynopsis && !isCompact)
        ? cardHeight + 86
        : cardHeight;

    // Dominant-color for top scrim
    final brushColor = _dominantColor != null
        ? Color.lerp(_dominantColor!, Colors.black, 0.45)!
        : Colors.black;

    return SizedBox(
      height: totalHeight,
      child: Column(
        children: [
          // ── Card PageView ─────────────────────────────────────────────────
          SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i < widget.items.length) {
                  _extractDominantColor(widget.items[i]);
                }
              },
              itemBuilder: (_, i) {
                final m = widget.items[i];
                final image = m.bannerImage ?? m.bestCover;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: GestureDetector(
                    onTap: () => widget.onItemTap(m),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(cardRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Cover / banner image ────────────────────────
                          if (image != null)
                            ExtendedImage.network(
                              image,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              cache: true,
                            )
                          else
                            Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),

                          // ── BOTTOM gradient scrim — title legibility ────
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.30, 0.62, 1.0],
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.45),
                                    (_dominantColor != null
                                        ? Color.lerp(_dominantColor!,
                                                Colors.black, 0.5)!
                                            .withValues(alpha: 0.97)
                                        : Colors.black
                                            .withValues(alpha: 0.95)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── TOP brush-stroke scrim — header always legible
                          if (isCinematic)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 165,
                              child: CustomPaint(
                                painter: _TopBrushScrim(brushColor),
                              ),
                            ),

                          // ── Info overlay ────────────────────────────────
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: isCinematic ? 36 : 28,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    _TypeBadge(
                                        m.type, m.format, m.countryOfOrigin),
                                    if (m.averageScore != null) ...[
                                      const SizedBox(width: 8),
                                      _ScoreBadge(m.averageScore!),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  m.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
                                if (m.genres.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: m.genres
                                          .take(3)
                                          .map(
                                            (g) => Padding(
                                              padding: const EdgeInsets.only(
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

                          // ── Page indicator dots ─────────────────────────
                          Positioned(
                            bottom: isCinematic ? 14 : 10,
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
                                  width: _index == di ? 20 : 6,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2.5),
                                  decoration: BoxDecoration(
                                    color: _index == di
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.30),
                                    borderRadius: BorderRadius.circular(99),
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

          // ── Optional synopsis strip ───────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Top brush-stroke scrim
// ─────────────────────────────────────────────────────────────────────────────

class _TopBrushScrim extends CustomPainter {
  final Color color;
  _TopBrushScrim(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.72)
      ..cubicTo(
        w * 0.80, h * 0.95,
        w * 0.62, h * 0.68,
        w * 0.44, h * 0.84,
      )
      ..cubicTo(
        w * 0.30, h * 0.97,
        w * 0.14, h * 0.66,
        0, h * 0.80,
      )
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.88),
          color.withValues(alpha: 0.52),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TopBrushScrim old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Synopsis strip (non-forceFullWidth only)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
