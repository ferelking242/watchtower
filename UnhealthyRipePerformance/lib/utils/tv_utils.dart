import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Returns true when the app is running under D-pad / remote-control navigation.
/// Android TV and most Smart TV Android environments report NavigationMode.directional
/// instead of the default NavigationMode.traditional (touch-based).
bool isTVMode(BuildContext context) {
  return MediaQuery.of(context).navigationMode == NavigationMode.directional;
}

/// A widget that makes any child focusable and activatable via D-pad / TV remote.
///
/// Wraps [child] with a [Focus] node that:
///  - draws a visible highlight ring when focused (D-pad has moved to this item)
///  - forwards Enter / Select / GameButton-A key presses as [onTap]
///
/// Drop this around custom widgets built with [GestureDetector] so they remain
/// usable on TV without a touchscreen.
class TVFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool autofocus;

  const TVFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.autofocus = false,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.60),
                    blurRadius: 0,
                    spreadRadius: 3,
                  )
                ]
              : null,
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Shows the software keyboard for the given [FocusNode].
/// On Android TV the system keyboard must be explicitly requested after focus
/// is set — this helper combines both steps.
void requestTVKeyboard(FocusNode node) {
  node.requestFocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.show');
}
