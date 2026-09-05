// Watch hero carousel — evolution of the flutter_netflix highlight banner.
// Design refs: Netflix / Disney+ mobile heroes — landscape backdrop,
// gradient scrims (never a solid black bar), auto-rotation with dot indicator,
// action row: Ma liste (library toggle) • Lecture (play) • Info (bottom sheet).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart'
    show pushToMangaReaderDetail;
import 'nf_bottom_sheet.dart';
import 'nf_favorite.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

/// Landscape hero height — generous cinematic frame so the artwork feels like
/// a proper spotlight, clamped so it never eats more than 60% of the screen
/// height (leaves a peek of the next section below).
double heroCarouselHeight(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final h = size.width * 0.92;
  return h.clamp(0.0, size.height * 0.60);
}

class NfHeroCarousel extends ConsumerStatefulWidget {
  const NfHeroCarousel({
    super.key,
    required this.items,
    required this.source,
    required this.onTapManga,
  });

  final List<MManga> items;
  final Source source;
  final void Function(MManga) onTapManga;

  @override
  ConsumerState<NfHeroCarousel> createState() => _NfHeroCarouselState();
}

class _NfHeroCarouselState extends ConsumerState<NfHeroCarousel> {
  static const _autoAdvance = Duration(seconds: 7);
  static const _pageDuration = Duration(milliseconds: 650);

  final PageController _pageCtrl = PageController();
  Timer? _timer;
  int _page = 0;
  bool _inList = false;

  @override
  void initState() {
    super.initState();
    _syncListFlag(0);
    _armTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _syncListFlag(int page) {
    final items = widget.items;
    if (items.isEmpty) return;
    final i = page.clamp(0, items.length - 1);
    _inList = isMangaInList(widget.source, items[i]);
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
    setState(() {
      _page = page;
      _syncListFlag(page);
    });
    _armTimer(); // restart countdown after manual swipe
  }

  MManga get _current =>
      widget.items[_page.clamp(0, widget.items.length - 1)];

  void _toggleList() {
    setState(() => _inList = toggleMangaInList(widget.source, _current));
  }

  void _play(MManga manga) => pushToMangaReaderDetail(
        ref: ref,
        context: context,
        getManga: manga,
        lang: widget.source.lang!,
        source: widget.source.name!,
        itemType: widget.source.itemType,
        sourceId: widget.source.id,
      );

  void _info(MManga manga) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: nfBottomSheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (ctx) => NfBottomSheet(manga: manga, source: widget.source),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width;
    final height = heroCarouselHeight(context);
    final topPad = MediaQuery.paddingOf(context).top;

    final current = _current;
    final genres = (current.genre ?? const <String>[])
        .where((g) => g.trim().isNotEmpty)
        .take(3)
        .toList();

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
                child: NfPosterImage(
                  imageUrl: manga.imageUrl,
                  original: true,
                  borderRadius: BorderRadius.zero,
                  width: width,
                  height: height,
                  alignment: Alignment.topCenter,
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
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // ── Genre badge — corner chip under the app bar ─────────────────
          if (genres.isNotEmpty)
            Positioned(
              top: topPad + kToolbarHeight + 10,
              left: 16,
              child: IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < genres.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _HeroGenreChip(genre: genres[i]),
                    ],
                  ],
                ),
              ),
            ),

          // ── Bottom content: title, dots, actions ─────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      current.name ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: -0.3,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Page indicator dots
                    if (items.length > 1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(height: 12),
                    ],

                    // Action trio — Ma liste • Lecture • Info (equal weight,
                    // fluid thirds so it never overflows on narrow screens)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _HeroAction(
                            icon: _inList
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            label: _inList ? 'Ajouté' : 'Ma liste',
                            onTap: _toggleList,
                            filled: false,
                          ),
                        ),
                        Expanded(
                          child: _HeroAction(
                            icon: Icons.play_arrow_rounded,
                            label: 'Lecture',
                            onTap: () => _play(_current),
                            filled: true,
                          ),
                        ),
                        Expanded(
                          child: _HeroAction(
                            icon: Icons.info_outline_rounded,
                            label: 'Info',
                            onTap: () => _info(_current),
                            filled: false,
                          ),
                        ),
                      ],
                    ),
                  ],
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
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
