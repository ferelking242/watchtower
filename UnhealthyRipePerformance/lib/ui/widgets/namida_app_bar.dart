// Source: github.com/namidaco/namida — lib/ui/widgets/custom_widgets.dart (GPL-3.0)
// Extracted: NamidaIconButton + NamidaAppBarIcon
// Watchtower adaptation: NamidaTooltip → Tooltip, NamidaMouseRegion → MouseRegion,
//   context.theme → Theme.of(context)
import 'package:flutter/material.dart';

// ── NamidaIconButton ──────────────────────────────────────────────────────────
// Source: NamidaIconButton in custom_widgets.dart

class NamidaIconButton extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final double horizontalPadding;
  final double verticalPadding;
  final double? iconSize;
  final IconData? icon;
  final Color? iconColor;
  final void Function()? onPressed;
  final void Function(LongPressStartDetails details)? onLongPressStart;
  final void Function()? onLongPressFinish;
  final void Function()? onLongPress;
  final String Function()? tooltip;
  final bool disableColor;
  final Widget? child;

  const NamidaIconButton({
    super.key,
    this.padding,
    this.horizontalPadding = 8.0,
    this.verticalPadding = 0.0,
    required this.icon,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressFinish,
    this.onLongPress,
    this.iconSize,
    this.iconColor,
    this.tooltip,
    this.disableColor = false,
    this.child,
  });

  @override
  State<NamidaIconButton> createState() => _NamidaIconButtonState();
}

class _NamidaIconButtonState extends State<NamidaIconButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final inner = MouseRegion(
      cursor: widget.onPressed != null || widget.onLongPress != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => setState(() => isPressed = true),
        onTapUp: (_) => setState(() => isPressed = false),
        onTapCancel: () => setState(() => isPressed = false),
        onTap: widget.onPressed,
        onLongPressStart: widget.onLongPressStart,
        onLongPressEnd: widget.onLongPressFinish == null
            ? null
            : (details) => widget.onLongPressFinish!(),
        onLongPressCancel: widget.onLongPressFinish,
        onLongPress: widget.onLongPress,
        onLongPressUp: widget.onLongPressFinish,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isPressed ? 0.5 : 1.0,
          child: Padding(
            padding: widget.padding ??
                EdgeInsets.symmetric(
                  horizontal: widget.horizontalPadding,
                  vertical: widget.verticalPadding,
                ),
            child: widget.child ??
                Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.disableColor
                      ? null
                      : (widget.iconColor ??
                          Theme.of(context).colorScheme.secondary),
                ),
          ),
        ),
      ),
    );

    final tt = widget.tooltip?.call();
    if (tt == null || tt.isEmpty) return inner;
    return Tooltip(message: tt, child: inner);
  }
}

// ── NamidaAppBarIcon ──────────────────────────────────────────────────────────
// Source: NamidaAppBarIcon in custom_widgets.dart

class NamidaAppBarIcon extends StatelessWidget {
  final IconData icon;
  final Widget? child;
  final void Function()? onPressed;
  final String Function()? tooltip;

  const NamidaAppBarIcon({
    super.key,
    required this.icon,
    this.child,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      verticalPadding: 8.0,
      horizontalPadding: 6.0,
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      child: child,
    );
  }
}
