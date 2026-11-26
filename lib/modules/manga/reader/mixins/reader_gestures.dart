import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget providing horizontal tap zones for reader navigation.
class HorizontalTapZones extends StatelessWidget {
  /// Callback for left region tap.
  final VoidCallback onLeftTap;

  /// Callback for center region tap.
  final VoidCallback onCenterTap;

  /// Callback for right region tap.
  final VoidCallback onRightTap;

  /// Callback for double-tap with position.
  final void Function(Offset position)? onDoubleTap;

  /// Whether to show overlay for failed images.
  final bool showFailedOverlay;

  /// Widget to show when image failed to load.
  final Widget? failedWidget;

  const HorizontalTapZones({
    super.key,
    required this.onLeftTap,
    required this.onCenterTap,
    required this.onRightTap,
    this.onDoubleTap,
    this.showFailedOverlay = false,
    this.failedWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left region (2 flex)
        Expanded(
          flex: 2,
          child: _TapZone(onTap: onLeftTap, onDoubleTap: onDoubleTap),
        ),
        // Center region (2 flex)
        Expanded(
          flex: 2,
          child: showFailedOverlay && failedWidget != null
              ? failedWidget!
              : _TapZone(onTap: onCenterTap, onDoubleTap: onDoubleTap),
        ),
        // Right region (2 flex)
        Expanded(
          flex: 2,
          child: _TapZone(onTap: onRightTap, onDoubleTap: onDoubleTap),
        ),
      ],
    );
  }
}

/// Widget providing vertical tap zones for reader navigation.
class VerticalTapZones extends StatelessWidget {
  /// Callback for top region tap.
  final VoidCallback onTopTap;

  /// Callback for center region tap.
  final VoidCallback onCenterTap;

  /// Callback for bottom region tap.
  final VoidCallback onBottomTap;

  /// Callback for double-tap with position.
  final void Function(Offset position)? onDoubleTap;

  const VerticalTapZones({
    super.key,
    required this.onTopTap,
    required this.onCenterTap,
    required this.onBottomTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top region (2 flex)
        Expanded(
          flex: 2,
          child: _TapZone(onTap: onTopTap, onDoubleTap: onDoubleTap),
        ),
        // Center region (5 flex) - larger for viewing
        const Expanded(flex: 5, child: SizedBox.shrink()),
        // Bottom region (2 flex)
        Expanded(
          flex: 2,
          child: _TapZone(onTap: onBottomTap, onDoubleTap: onDoubleTap),
        ),
      ],
    );
  }
}

class _TapZone extends StatelessWidget {
  final VoidCallback onTap;
  final void Function(Offset position)? onDoubleTap;

  const _TapZone({required this.onTap, this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onDoubleTapDown: onDoubleTap != null
          ? (details) => onDoubleTap!(details.globalPosition)
          : null,
      onDoubleTap: onDoubleTap != null ? () {} : null,
      onSecondaryTapDown: onDoubleTap != null
          ? (details) => onDoubleTap!(details.globalPosition)
          : null,
      onSecondaryTap: onDoubleTap != null ? () {} : null,
    );
  }
}

/// Handler for keyboard shortcuts in the reader.
class ReaderKeyboardHandler {
  final VoidCallback? onEscape;
  final VoidCallback? onFullScreen;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;

  /// Called for a hardware volume-up press. Only wired when the reader's
  /// "use the volume buttons" preference is on and the native host is *not*
  /// swallowing the keys: consuming the event here is what keeps the system
  /// volume from moving.
  final VoidCallback? onVolumeUp;

  /// Called for a hardware volume-down press. See [onVolumeUp].
  final VoidCallback? onVolumeDown;

  const ReaderKeyboardHandler({
    this.onEscape,
    this.onFullScreen,
    this.onPreviousPage,
    this.onNextPage,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onVolumeUp,
    this.onVolumeDown,
  });

  /// Whether [event] is a volume key this handler consumes itself.
  bool _isOwnedVolumeKey(KeyEvent event) =>
      (event.logicalKey == LogicalKeyboardKey.audioVolumeUp &&
          onVolumeUp != null) ||
      (event.logicalKey == LogicalKeyboardKey.audioVolumeDown &&
          onVolumeDown != null);

  /// Claims a volume key for this reader, independently of keyboard focus.
  ///
  /// Why this exists: Flutter's Android embedder sends the key to Dart and,
  /// when no handler claims it, `KeyboardManager` calls `onUnhandled()` →
  /// `redispatch()`, which hands the event back to the platform and moves the
  /// system volume. A `Focus` node only receives keys while it actually holds
  /// focus, so relying on it left the key unclaimed as soon as anything else
  /// took focus — the volume went up and the page never turned.
  ///
  /// Register this with `HardwareKeyboard.instance.addHandler`, which receives
  /// every key regardless of focus (the same "consume before anything else"
  /// position Mihon takes with `onPreviewKeyEvent`).
  ///
  /// Returns whether [event] was claimed. Both the down and the up event are
  /// claimed: claiming only the down would still redispatch the up.
  bool claimVolumeKeyEvent(KeyEvent event) {
    if (!_isOwnedVolumeKey(event)) return false;
    if (event is KeyDownEvent) handleKeyEvent(event);
    return true;
  }

  /// Whether [event] is a volume key this reader owns, without acting on it.
  ///
  /// Used while the screen is locked: the key must still be claimed so the
  /// platform does not fall back to raising the volume, but it must not turn
  /// the page.
  bool claimsVolumeKey(KeyEvent event) => _isOwnedVolumeKey(event);

  /// Handles a key event and returns true if it was handled.
  bool handleKeyEvent(KeyEvent event, {bool isReverseHorizontal = false}) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f11:
        onFullScreen?.call();
        return true;

      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.backspace:
        onEscape?.call();
        return true;

      case LogicalKeyboardKey.arrowUp:
        onPreviousPage?.call();
        return true;

      case LogicalKeyboardKey.arrowDown:
        onNextPage?.call();
        return true;

      case LogicalKeyboardKey.arrowLeft:
        if (isReverseHorizontal) {
          onNextPage?.call();
        } else {
          onPreviousPage?.call();
        }
        return true;

      case LogicalKeyboardKey.arrowRight:
        if (isReverseHorizontal) {
          onPreviousPage?.call();
        } else {
          onNextPage?.call();
        }
        return true;

      case LogicalKeyboardKey.audioVolumeUp:
        if (onVolumeUp == null) return false;
        onVolumeUp!();
        return true;

      case LogicalKeyboardKey.audioVolumeDown:
        if (onVolumeDown == null) return false;
        onVolumeDown!();
        return true;

      case LogicalKeyboardKey.keyN:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.shiftRight:
        onNextChapter?.call();
        return true;

      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.pageUp:
      case LogicalKeyboardKey.shiftLeft:
        onPreviousChapter?.call();
        return true;

      default:
        return false;
    }
  }

  /// Creates a KeyboardListener widget with this handler.
  ///
  /// [focusNode] must be owned by the caller (created in `initState` and
  /// disposed with the state). Building one here on every frame would leak a
  /// node per rebuild and let the reader lose keyboard focus.
  Widget wrapWithKeyboardListener({
    required Widget child,
    required FocusNode focusNode,
    bool isReverseHorizontal = false,
  }) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        // Volume keys are deliberately not handled here. They are claimed by
        // the global handler ([claimVolumeKeyEvent], registered through
        // `HardwareKeyboard.addHandler`) because a focus node only sees keys
        // while it holds focus. Both destinations receive every event, so
        // handling them here too would turn the page twice.
        if (_isOwnedVolumeKey(event)) return KeyEventResult.ignored;
        final handled = handleKeyEvent(
          event,
          isReverseHorizontal: isReverseHorizontal,
        );
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
