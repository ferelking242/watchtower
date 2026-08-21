// Source visuelle: github.com/namidaco/namida — NamidaAppBarIcon + _CustomAppBar (GPL-3.0)
// Adapted for Watchtower watch home screen.
// NfCircleIconButton → NamidaAppBarIcon (Broken icons, transparent backdrop on dark BG)
//
// Scroll behaviour: driven by a ValueNotifier so the screen never setState()s
// while scrolling (the old per-pixel setState was the main jank source).
// Visual: permanent top scrim for status-bar legibility + a solid backdrop
// that fades in past ~90px — icons stay white at all times (fixes the
// "bar turns black / icons clash" issue).
import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/ui/widgets/namida_app_bar.dart';

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
// Netflix-style: top scrim always on, solid #010101 backdrop fading in with
// scroll offset, source title fading in once collapsed.

class NfWatchAppBarWidget extends StatelessWidget {
  const NfWatchAppBarWidget({
    super.key,
    required this.scrollOffsetNotifier,
    required this.sourceName,
    this.onSearchTap,
    this.onBackTap,
    this.canPop = false,
  });

  /// Live scroll offset — listened via ValueListenableBuilder (no rebuilds
  /// of the parent screen).
  final ValueNotifier<double> scrollOffsetNotifier;
  final String        sourceName;
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
            // Permanent scrim keeps the status bar readable over the hero…
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:  Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55 * (1 - curved)),
                Colors.transparent,
              ],
            ),
            // …and the solid backdrop fades in once content scrolls under.
            color: Colors.black.withValues(alpha: 0.92 * curved),
          ),
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                if (canPop)
                  NfCircleIconButton(
                    icon:  Broken.arrow_left_2,
                    onTap: onBackTap ?? () => Navigator.of(context).pop(),
                  )
                else
                  // Title fades in as the bar collapses over the hero.
                  Expanded(
                    child: Opacity(
                      opacity: curved,
                      child: Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:         Colors.white,
                          fontSize:      20,
                          fontWeight:    FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                NamidaAppBarIcon(
                  icon:      Broken.search_normal_1,
                  onPressed: onSearchTap ?? () {},
                  // Always white — the backdrop is always dark.
                  child: const Icon(
                    Broken.search_normal_1,
                    color: Colors.white,
                    size:  22,
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
