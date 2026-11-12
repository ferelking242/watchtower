import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/models/settings.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Service for handling page navigation in the manga reader.
///
/// Abstracts the complexity of navigating between different reader modes:
/// - Paged modes (vertical, LTR, RTL)
/// - Continuous modes (vertical continuous, webtoon, horizontal continuous)
///
/// In continuous modes navigation scrolls by a fraction of the viewport
/// (Mihon's `smoothScrollBy`), instead of snapping the next item's leading edge
/// to the top of the screen. The previous snapping behaviour made a volume key
/// or a tap jump straight to the next page's top, skipping the part of the
/// current page that was still below the fold.
class PageNavigationService {
  /// Fraction of the viewport scrolled per page step. Mihon uses 3/4 of the
  /// screen height so the tail of the current page stays visible.
  static const double _scrollFraction = 3 / 4;

  final ItemScrollController itemScrollController;
  final ScrollOffsetController scrollOffsetController;
  final ExtendedPageController extendedController;

  /// Reports the current visible viewport size in logical pixels.
  final Size Function()? viewportSize;

  /// Reports the axis the continuous list scrolls along, so a page step moves
  /// by the viewport's *width* in horizontal modes and its *height* otherwise.
  final Axis Function()? scrollAxis;

  const PageNavigationService({
    required this.itemScrollController,
    required this.scrollOffsetController,
    required this.extendedController,
    this.viewportSize,
    this.scrollAxis,
  });

  /// Navigates to next page.
  void nextPage({
    required ReaderMode readerMode,
    required int currentIndex,
    required int maxPages,
    required bool animate,
  }) {
    if (PageNavigationService.isContinuousMode(readerMode)) {
      scrollForward(animated: animate);
      return;
    }
    if (currentIndex >= maxPages - 1) return;
    _navigatePaged(currentIndex + 1, animate);
  }

  /// Navigates to previous page.
  void previousPage({
    required ReaderMode readerMode,
    required int currentIndex,
    required bool animate,
  }) {
    if (PageNavigationService.isContinuousMode(readerMode)) {
      scrollBackward(animated: animate);
      return;
    }
    if (currentIndex <= 0) return;
    _navigatePaged(currentIndex - 1, animate);
  }

  /// Scrolls one page forward in a continuous reader (volume keys, tap zones,
  /// keyboard). Mihon scrolls by ~¾ of the screen instead of snapping the next
  /// page to the top, so the tail of the current page stays reachable.
  void scrollForward({bool animated = true}) => _scrollByPages(1, animated);

  /// Scrolls one page backward in a continuous reader.
  void scrollBackward({bool animated = true}) => _scrollByPages(-1, animated);

  /// Scrolls by [pages] viewport extents. Positive = forward (down/right).
  void _scrollByPages(int pages, bool animated) {
    final viewport = viewportSize?.call();
    if (viewport == null) return;

    final horizontal = scrollAxis?.call() == Axis.horizontal;
    final extent = horizontal ? viewport.width : viewport.height;
    if (!extent.isFinite || extent <= 0) return;

    // Increasing the scroll offset always advances towards higher page
    // indices, whatever the axis direction (a reversed list just starts at the
    // far end), so "forward" is always a positive delta.
    final delta = pages * extent * _scrollFraction;
    // `ScrollOffsetController.animateScroll` forwards to `ScrollController
    // .animateTo`, which asserts `duration > Duration.zero`. Passing a zero
    // duration for the "Animer les transitions de page" off case therefore
    // threw and left the list exactly where it was — the volume key looked
    // dead. A single frame (1 ms) is indistinguishable from an instant jump
    // but keeps the assertion happy.
    scrollOffsetController.animateScroll(
      offset: delta,
      duration: animated
          ? const Duration(milliseconds: 250)
          : const Duration(milliseconds: 1),
      curve: Curves.ease,
    );
  }

  /// Jumps to a page without animation (for slider).
  void jumpToPage({required int index, required ReaderMode readerMode}) {
    if (index < 0) return;

    if (_isContinuousMode(readerMode)) {
      itemScrollController.jumpTo(index: index);
    } else {
      if (extendedController.hasClients) {
        extendedController.jumpToPage(index);
      }
    }
  }

  void _navigatePaged(int index, bool animate) {
    if (!extendedController.hasClients) return;

    if (animate) {
      extendedController.animateToPage(
        index,
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
      );
    } else {
      extendedController.jumpToPage(index);
    }
  }

  bool _isContinuousMode(ReaderMode mode) => isContinuousMode(mode);

  /// Whether [mode] scrolls continuously (as opposed to paged).
  static bool isContinuousMode(ReaderMode mode) {
    return mode == ReaderMode.verticalContinuous ||
        mode == ReaderMode.webtoon ||
        mode == ReaderMode.horizontalContinuous ||
        mode == ReaderMode.horizontalContinuousRTL;
  }
}

/// Mixin to add page navigation capabilities to reader state.
mixin PageNavigationMixin<T extends StatefulWidget> on State<T> {
  PageNavigationService? _navigationService;

  /// Initializes the navigation service with the required controllers.
  void initPageNavigation({
    required ItemScrollController itemScrollController,
    required ScrollOffsetController scrollOffsetController,
    required ExtendedPageController extendedController,
    Size Function()? viewportSize,
    Axis Function()? scrollAxis,
  }) {
    _navigationService = PageNavigationService(
      itemScrollController: itemScrollController,
      scrollOffsetController: scrollOffsetController,
      extendedController: extendedController,
      viewportSize: viewportSize,
      scrollAxis: scrollAxis,
    );
  }

  /// Gets the navigation service.
  PageNavigationService get navigationService {
    assert(
      _navigationService != null,
      'PageNavigationService not initialized. Call initPageNavigation first.',
    );
    return _navigationService!;
  }
}
