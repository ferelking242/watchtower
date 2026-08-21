// Source visuelle: github.com/namidaco/namida — NamidaAppBarIcon + _CustomAppBar (GPL-3.0)
// Adapted for Watchtower watch home screen.
//
// Scroll behaviour: driven by a ValueNotifier so the screen never setState()s
// while scrolling. Visual: while the hero is under the bar a soft top scrim
// keeps the status bar legible; once content scrolls under, the bar becomes a
// SOLID slab of the app background colour — it reads as "resting" on screen,
// never as a translucent overlay. Extension icon + name sit centred.
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/ui/widgets/namida_app_bar.dart';
import 'nf_utils.dart';

// ── NfCircleIconButton — kept for transparent-poster contexts ─────────────────
// (Namida-style: Broken icon, circular translucent backdrop)
class NfCircleIconButton extends StatelessWidget {
  const NfCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 22.0,
  });

  final IconData     icon;
  final VoidCallback onTap;
  final double       size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

// ── NfWatchAppBarWidget ────────────────────────────────────────────────────────
// Collapsed state = solid nfBackgroundColor slab, centred icon + title.

class NfWatchAppBarWidget extends StatelessWidget {
  const NfWatchAppBarWidget({
    super.key,
    required this.scrollOffsetNotifier,
    required this.sourceName,
    this.sourceIconUrl,
    this.onSearchTap,
    this.onBackTap,
    this.canPop = false,
  });

  /// Live scroll offset — listened via ValueListenableBuilder (no rebuilds
  /// of the parent screen).
  final ValueNotifier<double> scrollOffsetNotifier;
  final String        sourceName;
  final String?       sourceIconUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBackTap;
  final bool          canPop;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;

    return ValueListenableBuilder<double>(
      valueListenable: scrollOffsetNotifier,
      builder: (context, offset, _) {
        // 0 → 1 across the first 90px of scroll.
        final t = (offset / 90).clamp(0.0, 1.0);
        final curved = Curves.easeOut.transform(t);

        return Container(
          padding: EdgeInsets.only(top: topPad, left: 4, right: 4),
          decoration: BoxDecoration(
            // While expanded: soft scrim over the hero for status-bar
            // legibility. Collapsed: solid app background — the bar feels
            // physically resting on the screen, not floating above content.
            gradient: curved < 0.02
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end:  Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  )
                : null,
            color: curved < 0.02
                ? Colors.transparent
                : nfBackgroundColor.withValues(alpha: curved),
            boxShadow: curved > 0.95
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: SizedBox(
            height: kToolbarHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Centre: extension icon + name (fades in on collapse) ──
                Opacity(
                  opacity: curved,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sourceIconUrl != null && sourceIconUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ExtendedImage.network(
                            sourceIconUrl!,
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            loadStateChanged: (state) =>
                                state.extendedImageLoadState ==
                                        LoadState.failed
                                    ? const ColoredBox(
                                        color: Color(0xFF1A1A1A))
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:         Colors.white,
                            fontSize:      19,
                            fontWeight:    FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Left: back ────────────────────────────────────────────
                Positioned(
                  left: 0,
                  child: canPop
                      ? NfCircleIconButton(
                          icon:  Broken.arrow_left_2,
                          onTap: onBackTap ?? () => Navigator.of(context).pop(),
                        )
                      : const SizedBox(width: 40),
                ),
                // ── Right: search ─────────────────────────────────────────
                Positioned(
                  right: 0,
                  child: NamidaAppBarIcon(
                    icon:      Broken.search_normal_1,
                    onPressed: onSearchTap ?? () {},
                    child: const Icon(
                      Broken.search_normal_1,
                      color: Colors.white,
                      size:  22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
