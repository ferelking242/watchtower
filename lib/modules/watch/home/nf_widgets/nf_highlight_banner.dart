// Watch hero carousel — evolution of the flutter_netflix highlight banner.
// Design refs: Netflix / Disney+ mobile heroes — landscape ~16:9-ish backdrop,
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
import 'nf_new_and_hot_tile_action.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

/// Landscape hero height — fixes the old `width * 1.6` portrait monster.
/// ~16:9-ish, clamped so it never eats more than 44% of the screen height.
double heroCarouselHeight(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final h = size.width * 0.62;
  return h.clamp(0.0, size.height * 0.44);
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

  void _toggleList() {
    final current = widget.items[_page.clamp(0, widget.items.length - 1)];
    setState(() => _inList = toggleMangaInList(widget.source, current));
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
            height: height * 0.72,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black,
                  ],
                ),
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
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      items[_page.clamp(0, items.length - 1)].name ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.3,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 14),
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

                    // Action row — Ma liste • Lecture • Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NfNewAndHotTileAction(
                          icon: _inList
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          label: _inList ? 'Ajouté' : 'Ma liste',
                          onTap: _toggleList,
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22.0, vertical: 6.0),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shadowColor: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () =>
                              _play(items[_page.clamp(0, items.length - 1)]),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Lecture',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        NfNewAndHotTileAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Info',
                          onTap: () =>
                              _info(items[_page.clamp(0, items.length - 1)]),
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
