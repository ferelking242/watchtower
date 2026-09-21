// Watch hero carousel — evolution of the flutter_netflix highlight banner.
// Design refs: Netflix / Disney+ mobile heroes — landscape backdrop,
// gradient scrims (never a solid black bar), auto-rotation with dot indicator,
// The hero keeps only one action: a centred play button.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart'
    show pushToMangaReaderDetail;
import 'nf_poster_image.dart';
import 'nf_utils.dart';

/// Landscape hero height — generous cinematic frame so the artwork feels like
/// a proper spotlight, clamped so it never eats more than 60% of the screen
/// height (leaves a peek of the next section below).
double heroCarouselHeight(BuildContext context) {
  final size = MediaQuery.of(context).size;
  // Keep enough vertical room for landscape thumbnails and the action row.
  // The previous frame was short enough to crop the artwork and its footer.
  final h = size.width * 1.08;
  return h.clamp(0.0, size.height * 0.68);
}

class NfHeroCarousel extends ConsumerStatefulWidget {
  const NfHeroCarousel({
    super.key,
    required this.items,
    required this.source,
    required this.onTapManga,
    this.onCurrentChanged,
  });

  final List<MManga> items;
  final Source source;
  final void Function(MManga) onTapManga;
  final void Function(MManga)? onCurrentChanged;

  @override
  ConsumerState<NfHeroCarousel> createState() => _NfHeroCarouselState();
}

class _NfHeroCarouselState extends ConsumerState<NfHeroCarousel> {
  static const _autoAdvance = Duration(seconds: 7);
  static const _pageDuration = Duration(milliseconds: 650);

  final PageController _pageCtrl = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCurrentChanged?.call(widget.items.first);
      });
    }
    _armTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _syncCurrentItem(int page) {
    final items = widget.items;
    if (items.isEmpty) return;
    final i = page.clamp(0, items.length - 1);
    widget.onCurrentChanged?.call(items[i]);
  }

  void _armTimer() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(_autoAdvance, (_) {
      if (!mounted || !_pageCtrl.hasClients || widget.items.length < 2) return;
      final next = (_page + 1) % widget.items.length;
      _pageCtrl.nextPage(duration: _pageDuration, curve: Curves.easeInOut);
      setState(() => _page = next);
    });
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _syncCurrentItem(page);
    _armTimer(); // restart countdown after manual swipe
  }

  MManga get _current => widget.items[_page.clamp(0, widget.items.length - 1)];

  void _play(MManga manga) => pushToMangaReaderDetail(
    ref: ref,
    context: context,
    getManga: manga,
    lang: widget.source.lang!,
    source: widget.source.name!,
    itemType: widget.source.itemType,
    sourceId: widget.source.id,
  );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width;
    final height = heroCarouselHeight(context);
    final current = _current;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Pages ────────────────────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: items.length,
            onPageChanged: _onPageChanged,
            allowImplicitScrolling: true,
            itemBuilder: (ctx, i) {
              final manga = items[i];
              return GestureDetector(
                onTap: () => widget.onTapManga(manga),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A muted cover keeps the taller frame cinematic.
                    Opacity(
                      opacity: 0.30,
                      child: NfPosterImage(
                        imageUrl: manga.imageUrl,
                        original: true,
                        borderRadius: BorderRadius.zero,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    // Contain the real thumbnail so its edges are never cut.
                    NfPosterImage(
                      imageUrl: manga.imageUrl,
                      original: true,
                      borderRadius: BorderRadius.zero,
                      width: width,
                      height: height,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Scrims: top (status bar / app bar legibility) + bottom ───────
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height * 0.68,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [Colors.transparent, Colors.black54, Colors.black],
                ),
              ),
            ),
          ),

          // ── Bottom content: small left-aligned title and dots ─────────────
          Positioned(
            bottom: 82,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name ?? '',
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.15,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (items.length > 1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(items.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? nfRedColor
                                  : Colors.white.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // One clean play button cut into the image at the bottom centre.
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: GestureDetector(
                  onTap: () => _play(_current),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.76),
                        width: 1.4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
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

// ── Small frosted genre chip (hero corner) ────────────────────────────────────

class _HeroGenreChip extends StatelessWidget {
  const _HeroGenreChip({required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        genre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Hero action — circular icon + caption, Netflix-style ──────────────────────

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: filled ? 58 : 50,
              height: filled ? 58 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.13),
                border: filled
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.40),
                        width: 1.2,
                      ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: filled ? Colors.black : Colors.white,
                size: filled ? 27 : 21,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
