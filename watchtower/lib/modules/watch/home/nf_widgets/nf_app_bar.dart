// Source visuelle: github.com/namidaco/namida — NamidaAppBarIcon + _CustomAppBar (GPL-3.0)
// Adapted for Watchtower watch home screen.
//
// Scroll behaviour: driven by a ValueNotifier so the screen never setState()s
// while scrolling. Visual: while the hero is under the bar a soft top scrim
// keeps the status bar legible; once content scrolls under, the bar becomes a
// SOLID slab of the app background colour — it reads as "resting" on screen,
// never as a translucent overlay. Extension icon + name sit centred.
//
// Layout: back chevron (left) • extension brand (centre) • hamburger menu
// (right). The search affordance lives inside the sidebar that the hamburger
// opens.
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

// ── NfWatchAppBarWidget ────────────────────────────────────────────────────────
// Collapsed state = solid nfBackgroundColor slab, centred icon + title.
// Expanded state = gradient scrim + back + hamburger, all white.
class NfWatchAppBarWidget extends StatelessWidget {
  const NfWatchAppBarWidget({
    super.key,
    required this.scrollOffsetNotifier,
    required this.sourceName,
    this.sourceIconUrl,
    this.onSourceTap,
    this.onMenuTap,
    this.onBackTap,
    this.canPop = false,
  });

  /// Live scroll offset — listened via ValueListenableBuilder (no rebuilds
  /// of the parent screen).
  final ValueNotifier<double> scrollOffsetNotifier;
  final String        sourceName;
  final String?       sourceIconUrl;
  final VoidCallback? onSourceTap;
  final VoidCallback? onMenuTap;
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
        final expanded = curved < 0.02;

        // Round buttons melt into the solid bar once scrolled: over the hero
        // they are dark glass, on the resting bar they become subtle frost.
        final btnColor =
            Colors.black.withValues(alpha: 0.08 + 0.32 * (1 - curved));
        final btnBorder =
            Colors.white.withValues(alpha: 0.05 + 0.12 * (1 - curved));

        Widget roundIcon({required IconData icon, VoidCallback? onTap}) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: btnColor,
                border: Border.all(color: btnBorder),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.only(top: topPad, left: 6, right: 6),
          decoration: BoxDecoration(
            // While expanded: soft scrim over the hero for status-bar
            // legibility. Collapsed: solid app background — the bar feels
            // physically resting on the screen, not floating above content.
            gradient: expanded
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    stops: [0.0, 0.6, 1.0],
                    colors: [
                      Colors.black87,
                      Colors.black45,
                      Colors.transparent,
                    ],
                  )
                : null,
            color: expanded
                ? Colors.transparent
                : nfBackgroundColor.withValues(alpha: curved),
            border: curved > 0.98
                ? Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  )
                : null,
            boxShadow: curved > 0.95
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
                   child: GestureDetector(
                     behavior: HitTestBehavior.opaque,
                     onTap: onSourceTap,
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                      if (sourceIconUrl != null && sourceIconUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: ExtendedImage.network(
                            sourceIconUrl!,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            loadStateChanged: (state) =>
                                state.extendedImageLoadState ==
                                        LoadState.failed
                                    ? const ColoredBox(
                                        color: Color(0xFF1A1A1A))
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 9),
                      ],
                      Flexible(
                        child: Text(
                          sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:         Colors.white,
                            fontSize:      18,
                            fontWeight:    FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                       ],
                     ),
                  ),
                ),
                // ── Left: back ────────────────────────────────────────────
                Positioned(
                  left: 0,
                  child: canPop
                      ? roundIcon(
                          icon:  Broken.arrow_left_2,
                          onTap: onBackTap ??
                              () => Navigator.of(context).pop(),
                        )
                      : const SizedBox(width: 42),
                ),
                // ── Right: hamburger → opens the sidebar menu ─────────────
                Positioned(
                  right: 0,
                  child: roundIcon(
                    icon:  Broken.menu_1,
                    onTap: onMenuTap,
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
