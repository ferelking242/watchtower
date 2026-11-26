import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// Full-screen barrier shown while the reader screen is locked.
///
/// It absorbs every tap, drag and long-press, so a stray touch cannot turn the
/// page, and leaves a single padlock that unlocks. Drag gestures matter as much
/// as taps: the paged views are swipe-driven, so swallowing only taps would
/// still let a swipe flip the page under the lock.
class ReaderLockOverlay extends StatelessWidget {
  /// Called when the floating padlock is pressed.
  final VoidCallback onUnlock;

  /// Tooltip for the padlock. When null no tooltip is attached.
  final String? tooltip;

  const ReaderLockOverlay({super.key, required this.onUnlock, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onDoubleTap: () {},
            onLongPress: () {},
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (_) {},
            onHorizontalDragStart: (_) {},
            onHorizontalDragUpdate: (_) {},
            child: const SizedBox.expand(),
          ),
          Positioned(
            bottom: 32,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  onPressed: onUnlock,
                  tooltip: tooltip,
                  color: Colors.white,
                  icon: const Icon(Broken.lock),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
