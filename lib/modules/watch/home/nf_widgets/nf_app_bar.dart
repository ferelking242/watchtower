// Adapted from flutter_netflix — netflix_app_bar.dart
// Removed: BLoC, AnimationStatusCubit, lucide_icons, profile icon, go_router sub-tabs.
// Exposed as a regular StatelessWidget (used as Positioned overlay in WatchHomeScreen).
import 'package:flutter/material.dart';

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
    final bgOpacity =
        (scrollOffset / 100).clamp(0.0, 0.85).toDouble();

    return Container(
      color:   Colors.black.withValues(alpha: bgOpacity),
      padding: EdgeInsets.only(top: topPad, left: 4, right: 4),
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            if (canPop)
              IconButton(
                onPressed: onBackTap ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 12),
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
            IconButton(
              onPressed: onSearchTap,
              icon: const Icon(Icons.search_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
