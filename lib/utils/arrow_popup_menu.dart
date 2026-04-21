import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A drop-in replacement for [PopupMenuButton] that pops the menu open
/// directly under the trigger button, with a small triangular caret that
/// points back up at the button. Used throughout the app for a consistent
/// "anchored menu" style.
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
  final LayerLink _link = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _open() async {
    if (!widget.enabled) return;
    final entries = widget.itemBuilder(context);
    if (entries.isEmpty) return;

    final anchorBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null) return;
    final anchorSize = anchorBox.size;

    final T? selected = await _showArrowMenu<T>(
      context: context,
      link: _link,
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

    return CompositedTransformTarget(
      link: _link,
      child: KeyedSubtree(key: _anchorKey, child: wrapped),
    );
  }
}

/// Shows a menu anchored to [link] with a small upward caret.
Future<T?> _showArrowMenu<T>({
  required BuildContext context,
  required LayerLink link,
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
      link: link,
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
    required this.link,
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

  final LayerLink link;
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
      link: link,
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
    required this.link,
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

  final LayerLink link;
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
    final mq = MediaQuery.of(context);

    final width = menuWidth ?? 240.0;
    final theme = Theme.of(context);
    final bg = backgroundColor ??
        theme.popupMenuTheme.color ??
        theme.colorScheme.surfaceContainerHighest;

    // Desired follower target offset: directly below the trigger, centered.
    final followerOffset = Offset(
      anchorSize.width / 2 - width / 2 + offset.dx,
      anchorSize.height + offset.dy,
    );

    return SafeArea(
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: followerOffset,
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            alignment: const Alignment(0, -1),
            scale: Tween(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: mq.size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: CustomPaint(
                        size: const Size(caretWidth, caretHeight),
                        painter: _CaretPainter(color: bg),
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
                                _renderEntry(context, e),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderEntry(BuildContext context, PopupMenuEntry<T> e) {
    if (e is PopupMenuDivider) {
      return const Divider(height: 1);
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
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08)
              : null,
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium ??
                const TextStyle(),
            child: e.child ?? const SizedBox.shrink(),
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
  _CaretPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.color != color;
}
