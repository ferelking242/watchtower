import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// Auto-cycling banner carousel with page indicator dots.
class HeroCarousel extends StatefulWidget {
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onItemTap;

  const HeroCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_index + 1) % widget.items.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return SizedBox(
      height: 270,
      child: Stack(
        children: [
          // ── Pages with scale transform on adjacent items ──
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final m = widget.items[i];
              final image = m.bannerImage ?? m.bestCover;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double page = i.toDouble();
                  if (_controller.position.haveDimensions) {
                    page = _controller.page ?? _controller.initialPage.toDouble();
                  }
                  final delta = (page - i).abs();
                  final scale = (1 - (delta * 0.08)).clamp(0.88, 1.0);
                  final opacity = (1 - (delta * 0.4)).clamp(0.55, 1.0);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => widget.onItemTap(m),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image != null)
                          ExtendedImage.network(
                            image,
                            fit: BoxFit.cover,
                            cache: true,
                          )
                        else
                          Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                        // gradient
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                        // bottom info
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  m.type == 'MANGA' ? 'Manga' : 'Anime',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                              if (m.averageScore != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 16, color: Colors.amberAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(m.averageScore! / 10).toStringAsFixed(1)} / 10',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.white),
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
            },
          ),

          // ── Page indicator dots ──
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length > 8 ? 8 : widget.items.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: _index == i ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _index == i
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
