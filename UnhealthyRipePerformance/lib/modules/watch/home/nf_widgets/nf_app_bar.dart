// Source visuelle: github.com/namidaco/namida — NamidaAppBarIcon + _CustomAppBar (GPL-3.0)
// Adapted for Watchtower watch home screen.
// NfCircleIconButton → NamidaAppBarIcon (Broken icons, transparent backdrop on dark BG)
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
// Netflix-style transparent→black opacity as you scroll.
// Uses Broken icon font via NamidaAppBarIcon.

class NfWatchAppBarWidget extends StatelessWidget {
  const NfWatchAppBarWidget({
    super.key,
    required this.scrollOffset,
    required this.sourceName,
    this.onSearchTap,
    this.onBackTap,
    this.canPop = false,
  });

  final double        scrollOffset;
  final String        sourceName;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBackTap;
  final bool          canPop;

  @override
  Widget build(BuildContext context) {
    final topPad   = MediaQuery.of(context).viewPadding.top;
    final bgOpacity = (scrollOffset / 100).clamp(0.0, 0.85).toDouble();
    final cs        = Theme.of(context).colorScheme;

    return Container(
      color:   Colors.black.withValues(alpha: bgOpacity),
      padding: EdgeInsets.only(top: topPad, left: 4, right: 4),
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
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  sourceName,
                  style: const TextStyle(
                    color:         Colors.white,
                    fontSize:      22,
                    fontWeight:    FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            const Spacer(),
            // Search — NamidaAppBarIcon style
            NamidaAppBarIcon(
              icon:      Broken.search_normal_1,
              onPressed: onSearchTap ?? () {},
              // wrap in white colour so it's visible over dark poster bg
              child: Icon(
                Broken.search_normal_1,
                color: bgOpacity > 0.3
                    ? cs.onSurface
                    : Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
