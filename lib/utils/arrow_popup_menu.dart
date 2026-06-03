import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A drop-in replacement for [PopupMenuButton] that pops the menu open
/// directly under (or above) the trigger button, with a small triangular
/// caret whose horizontal position is dynamically aligned with the button.
class ArrowPopupMenuButton<T> extends StatefulWidget {
  const ArrowPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    this.initialValue,
    this.tooltip,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.padding = const EdgeInsets.all(8),
    this.child,
    this.enabled = true,
    this.color,
    this.shape,
    this.elevation,
    this.offset = const Offset(0, 8),
    this.menuWidth,
    // Compatibility shims — accepted for API parity with PopupMenuButton
    // but intentionally not used by the anchored implementation.
    // ignore: unused_element_parameter
    Object? popUpAnimationStyle,
    // ignore: unused_element_parameter
    Object? position,
    // ignore: unused_element_parameter
    Object? surfaceTintColor,
    // ignore: unused_element_parameter
    Object? splashRadius,
    // ignore: unused_element_parameter
    Object? constraints,
    // ignore: unused_element_parameter
    Object? menuPadding,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final VoidCallback? onCanceled;
  final T? initialValue;
  final String? tooltip;
  final Widget? icon;
  final double? iconSize;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final bool enabled;
  final Color? color;
  final ShapeBorder? shape;
  final double? elevation;
  final Offset offset;
  final double? menuWidth;

  @override
  State<ArrowPopupMenuButton<T>> createState() =>
      _ArrowPopupMenuButtonState<T>();
}

class _ArrowPopupMenuButtonState<T> extends State<ArrowPopupMenuButton<T>> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _open() async {
    if (!widget.enabled) return;
    final entries = widget.itemBuilder(context);
    if (entries.isEmpty) return;

    final anchorBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null) return;
    final anchorSize = anchorBox.size;
    final anchorGlobalPos = anchorBox.localToGlobal(Offset.zero);

    final T? selected = await _showArrowMenu<T>(
      context: context,
      anchorGlobalPos: anchorGlobalPos,
      anchorSize: anchorSize,
      offset: widget.offset,
      entries: entries,
      initialValue: widget.initialValue,
      backgroundColor: widget.color,
      shape: widget.shape,
      elevation: widget.elevation,
      menuWidth: widget.menuWidth,
    );

    if (!mounted) return;
    if (selected == null) {
      widget.onCanceled?.call();
    } else {
      widget.onSelected?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.child ??
        Icon(
          Icons.more_vert,
          size: widget.iconSize,
          color: widget.iconColor,
        );

    final button = InkResponse(
      onTap: widget.enabled ? _open : null,
      radius: 24,
      child: Padding(
        padding: widget.padding,
        child: widget.icon ?? trigger,
      ),
    );

    final wrapped = widget.tooltip != null && widget.tooltip!.isNotEmpty
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;

    return KeyedSubtree(key: _anchorKey, child: wrapped);
  }
}

/// Shows a menu anchored to the given [anchorGlobalPos] with a small caret
/// that dynamically aligns with the anchor's horizontal center.
Future<T?> _showArrowMenu<T>({
  required BuildContext context,
  required Offset anchorGlobalPos,
  required Size anchorSize,
  required List<PopupMenuEntry<T>> entries,
  Offset offset = const Offset(0, 8),
  T? initialValue,
  Color? backgroundColor,
  ShapeBorder? shape,
  double? elevation,
  double? menuWidth,
}) {
  return Navigator.of(context).push<T>(
    _ArrowMenuRoute<T>(
      anchorGlobalPos: anchorGlobalPos,
      anchorSize: anchorSize,
      entries: entries,
      offset: offset,
      initialValue: initialValue,
      backgroundColor: backgroundColor,
      shape: shape,
      elevation: elevation,
      menuWidth: menuWidth,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _ArrowMenuRoute<T> extends PopupRoute<T> {
  _ArrowMenuRoute({
    required this.anchorGlobalPos,
    required this.anchorSize,
    required this.entries,
    required this.offset,
    required this.initialValue,
    required this.backgroundColor,
    required this.shape,
    required this.elevation,
    required this.menuWidth,
    required this.barrierLabel,
  });

  final Offset anchorGlobalPos;
  final Size anchorSize;
  final List<PopupMenuEntry<T>> entries;
  final Offset offset;
  final T? initialValue;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final double? elevation;
  final double? menuWidth;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ArrowMenuOverlay<T>(
      anchorGlobalPos: anchorGlobalPos,
      anchorSize: anchorSize,
      entries: entries,
      offset: offset,
      initialValue: initialValue,
      backgroundColor: backgroundColor,
      shape: shape,
      elevation: elevation,
      menuWidth: menuWidth,
      animation: animation,
      onSelect: (v) => Navigator.of(context).pop<T>(v),
    );
  }
}

class _ArrowMenuOverlay<T> extends StatelessWidget {
  const _ArrowMenuOverlay({
    required this.anchorGlobalPos,
    required this.anchorSize,
    required this.entries,
    required this.offset,
    required this.initialValue,
    required this.backgroundColor,
    required this.shape,
    required this.elevation,
    required this.menuWidth,
    required this.animation,
    required this.onSelect,
  });

  final Offset anchorGlobalPos;
  final Size anchorSize;
  final List<PopupMenuEntry<T>> entries;
  final Offset offset;
  final T? initialValue;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final double? elevation;
  final double? menuWidth;
  final Animation<double> animation;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) {
    const double caretWidth = 14;
    const double caretHeight = 7;
    const double screenPadding = 8;
    final mq = MediaQuery.of(context);

    final width = menuWidth ?? 240.0;
    final theme = Theme.of(context);
    final bg = backgroundColor ??
        theme.popupMenuTheme.color ??
        theme.colorScheme.surfaceContainerHigh;

    // Anchor bottom edge (where menu would start if shown below)
    final anchorBottomY =
        anchorGlobalPos.dy + anchorSize.height + offset.dy;

    // Space available below and above the anchor
    final spaceBelow =
        (mq.size.height - anchorBottomY - screenPadding).clamp(0.0, double.infinity);
    final spaceAbove =
        (anchorGlobalPos.dy - offset.dy - screenPadding).clamp(0.0, double.infinity);

    // Flip menu above anchor when there isn't enough room below
    final showAbove = spaceBelow < 180 && spaceAbove > spaceBelow;

    final double maxMenuHeight;
    final double top;

    if (showAbove) {
      maxMenuHeight = spaceAbove.clamp(80.0, mq.size.height * 0.7);
      top = (anchorGlobalPos.dy - offset.dy - maxMenuHeight)
          .clamp(screenPadding, mq.size.height - screenPadding);
    } else {
      maxMenuHeight = spaceBelow.clamp(80.0, mq.size.height * 0.7);
      top = anchorBottomY;
    }

    // Center the menu under/above the anchor button, then clamp to screen bounds.
    double left = anchorGlobalPos.dx +
        anchorSize.width / 2 -
        width / 2 +
        offset.dx;
    left = left.clamp(
      screenPadding,
      mq.size.width - width - screenPadding,
    );

    // ── Dynamic caret position ────────────────────────────────────────────────
    // After clamping, the popup box may no longer be centered under the button.
    // Compute how far the button's center is from the popup's left edge so the
    // caret points EXACTLY at the trigger button regardless of screen position.
    final anchorCenterX = anchorGlobalPos.dx + anchorSize.width / 2.0;
    // Clamp so the caret tip stays within the visible rounded-corner area.
    final caretFraction =
        ((anchorCenterX - left) / width).clamp(0.06, 0.94);
    // Alignment uses [-1, 1] range: -1 = left edge, 0 = center, 1 = right edge.
    final caretAlignX = caretFraction * 2.0 - 1.0;

    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              alignment: showAbove
                  ? const Alignment(0, 1)
                  : const Alignment(0, -1),
              scale: Tween(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: maxMenuHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top caret (shown when menu opens below the button)
                    if (!showAbove)
                      Align(
                        alignment: Alignment(caretAlignX, 0),
                        child: CustomPaint(
                          size: const Size(caretWidth, caretHeight),
                          painter: _CaretPainter(color: bg, pointDown: false),
                        ),
                      ),
                    Flexible(
                      child: Material(
                        color: bg,
                        elevation: elevation ?? 8,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        shape: shape ??
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final e in entries)
                                _renderEntry(context, e, bg),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom caret (shown when menu opens above the button)
                    if (showAbove)
                      Align(
                        alignment: Alignment(caretAlignX, 0),
                        child: CustomPaint(
                          size: const Size(caretWidth, caretHeight),
                          painter: _CaretPainter(color: bg, pointDown: true),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderEntry(BuildContext context, PopupMenuEntry<T> e, Color bg) {
    final theme = Theme.of(context);
    // Derive a readable text color from the background (important in dark mode).
    final textColor =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    if (e is PopupMenuDivider) {
      return Divider(
        height: 1,
        color: textColor.withValues(alpha: 0.12),
      );
    }
    if (e is PopupMenuItem<T>) {
      final enabled = e.enabled;
      final selected =
          initialValue != null && e.value == initialValue;
      return InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onSelect(e.value);
              }
            : null,
        child: Container(
          constraints: BoxConstraints(
            minHeight: e.height,
          ),
          padding: (e.padding as EdgeInsetsGeometry?) ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle(
            style: (theme.textTheme.bodyMedium ?? const TextStyle())
                .copyWith(color: textColor),
            child: IconTheme(
              data: IconThemeData(color: textColor.withValues(alpha: 0.7)),
              child: e.child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }
    // Fallback for other PopupMenuEntry subclasses (CheckedPopupMenuItem etc.)
    return InkWell(
      onTap: () => onSelect(null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: e,
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({required this.color, this.pointDown = false});
  final Color color;
  final bool pointDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointDown
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close())
        : (Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close());
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.color != color || old.pointDown != pointDown;
}
