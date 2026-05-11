import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:palette_generator/palette_generator.dart';

/// Auto-cycling hero carousel — Disney+-style.
///
/// Layout (forceFullWidth = true):
///   • viewportFraction = 0.88 → main card ~88 % wide, 6 % of next card peeks
///   • Rounded corners always (radius 18)
///   • Card height = 54 % of screen height
///   • Info text + genre pills + page dots rendered on the image
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

  late PageController _ctrl;
  double _viewportFraction = 0.88;

  @override
  void initState() {
    super.initState();
    _viewportFraction = widget.forceFullWidth ? 0.88 : 0.92;
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
          duration: const Duration(milliseconds: 550),
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
      final gen = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(300, 168),
        maximumColorCount: 8,
        timeout: const Duration(seconds: 4),
      );
      final c = gen.darkVibrantColor?.color ??
          gen.darkMutedColor?.color ??
          gen.dominantColor?.color;
      if (c != null && mounted) setState(() => _dominantColor = c);
    } catch (_) {}
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

    final carouselStyle = ref.watch(carouselStyleProvider);
    final showSynopsis = ref.watch(carouselSynopsisProvider);
    final theme = Theme.of(context);
    final screenH = MediaQuery.sizeOf(context).height;

    // forceFullWidth always uses cinematic mode (Disney+ hero style)
    final isCinematic = widget.forceFullWidth || carouselStyle == 1;
    final isCompact = !widget.forceFullWidth && carouselStyle == 2;

    // Card sizing
    final double cardHeight = widget.forceFullWidth
        ? screenH * 0.54     // Disney+ hero: ~54 % screen height
        : (isCompact ? 190.0 : 270.0);

    // Always rounded — radius 18 in hero mode
    const double cardRadius = 18.0;

    // Bottom total height
    final totalHeight =
        (!widget.forceFullWidth && showSynopsis && !isCompact)
            ? cardHeight + 86
            : cardHeight;

    return SizedBox(
      height: totalHeight,
      child: Column(
        children: [
          // ── PageView ───────────────────────────────────────────────────────
          SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i < widget.items.length) _extractDominantColor(widget.items[i]);
              },
              itemBuilder: (_, i) {
                final m = widget.items[i];
                final image = m.bannerImage ?? m.bestCover;
                // Slight scale-down for non-focused cards
                final isActive = i == _index;

                return AnimatedScale(
                  scale: isActive ? 1.0 : 0.96,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  child: Padding(
                    // Side padding creates the gap between cards + shows peek
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => widget.onItemTap(m),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cardRadius),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ── Image ─────────────────────────────────────
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

                            // ── Bottom gradient scrim ─────────────────────
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.35, 0.65, 1.0],
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.40),
                                      (_dominantColor != null
                                              ? Color.lerp(
                                                  _dominantColor!,
                                                  Colors.black,
                                                  0.55)!
                                              : Colors.black)
                                          .withValues(alpha: 0.96),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── Info overlay ──────────────────────────────
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 30,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Badge row
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
                                  // Title
                                  Text(
                                    m.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black54,
                                            blurRadius: 8),
                                      ],
                                    ),
                                  ),
                                  // Description (cinematic only)
                                  if (isCinematic &&
                                      m.description != null &&
                                      m.description!.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      m.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.4,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black87,
                                              blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Genre pills
                                  if (m.genres.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: m.genres
                                            .take(3)
                                            .map((g) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 6),
                                                  child: _GenrePill(g),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Page indicator dots ───────────────────────
                            Positioned(
                              bottom: 10,
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
                                        const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                    width: _index == di ? 20 : 5,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: _index == di
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.30),
                                      borderRadius:
                                          BorderRadius.circular(99),
                                    ),
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
// Synopsis strip
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
// Badges / pills
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
        color: Colors.white.withValues(alpha: 0.20),
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
          const Icon(Icons.star_rounded, size: 11, color: Colors.amberAccent),
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
