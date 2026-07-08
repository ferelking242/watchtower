// Adapted from flutter_netflix — netflix_app_bar.dart
// Removed: BLoC, AnimationStatusCubit, lucide_icons, profile icon, go_router sub-tabs.
// Exposed as a regular StatelessWidget (used as Positioned overlay in WatchHomeScreen).
// Added: NfCircleIconButton — circular translucent-black backdrop for icon visibility.
import 'package:flutter/material.dart';

// ── NfCircleIconButton ─────────────────────────────────────────────────────────
/// A circular icon button with a translucent-black backdrop so it stays
/// readable over both light and dark poster backgrounds.
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
        width:  40,
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

/// Floating app bar with netflix-style transparent→black opacity as you scroll.
/// Used as a Positioned overlay on top of the CustomScrollView.
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
    final topPad = MediaQuery.of(context).viewPadding.top;
    // Mirror the netflix_app_bar opacity: scrollOffset / 100 clamped to 0.85
    final bgOpacity = (scrollOffset / 100).clamp(0.0, 0.85).toDouble();

    return Container(
      color:   Colors.black.withValues(alpha: bgOpacity),
      padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            if (canPop)
              NfCircleIconButton(
                icon:  Icons.arrow_back_ios_new_rounded,
                onTap: onBackTap ?? () => Navigator.of(context).pop(),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 4),
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
            NfCircleIconButton(
              icon:  Icons.search_rounded,
              onTap: onSearchTap ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}
