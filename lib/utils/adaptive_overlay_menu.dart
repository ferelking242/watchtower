// ignore_for_file: use_build_context_synchronously

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _kCaretW = 14.0;
const double _kCaretH = 7.0;
const double _kScreenPad = 10.0;
const double _kGap = 6.0;
const double _kMinMenuH = 80.0;

// ─────────────────────────────────────────────────────────────────────────────
/// Generic reusable adaptive overlay menu — iOS-style floating panel with
/// glassmorphism, directional caret, and smooth Fade+Scale animation.
///
/// Architecture:
/// - [CompositedTransformTarget] wraps the trigger to provide a [LayerLink].
/// - On tap, an [OverlayEntry] is inserted into the nearest [Overlay].
/// - The panel is positioned using the trigger's [RenderBox] coordinates.
/// - [BackdropFilter] provides the glassmorphism effect.
/// - Auto-flips above/below the trigger based on available screen space.
/// - Closes on outside tap or when the returned [close] callback is invoked.
///
/// Example:
/// ```dart
/// AdaptiveOverlayMenuButton(
///   trigger: Padding(
///     padding: EdgeInsets.all(8),
///     child: Icon(Broken.filter, size: 20),
///   ),
///   contentBuilder: (close) => _MyFilterPanel(onClose: close),
/// )
/// ```
// ─────────────────────────────────────────────────────────────────────────────
class AdaptiveOverlayMenuButton extends StatefulWidget {
  /// The tappable widget that anchors the overlay (icon, button, text, …).
  final Widget trigger;

  /// Builds the content shown inside the floating panel.
  /// The [close] callback dismisses the overlay with the exit animation.
  final Widget Function(VoidCallback close) contentBuilder;

  /// Width of the floating panel. Default 220.
  final double menuWidth;

  const AdaptiveOverlayMenuButton({
    super.key,
    required this.trigger,
    required this.contentBuilder,
    this.menuWidth = 220,
  });

  @override
  State<AdaptiveOverlayMenuButton> createState() =>
      _AdaptiveOverlayMenuButtonState();
}

class _AdaptiveOverlayMenuButtonState
    extends State<AdaptiveOverlayMenuButton>
    with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  final _anchorKey = GlobalKey();
  OverlayEntry? _entry;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _closeImmediate();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final anchorSize = renderBox.size;
    final anchorPos = renderBox.localToGlobal(Offset.zero);

    _entry = OverlayEntry(
      builder: (_) => _OverlayPanel(
        anchorPos: anchorPos,
        anchorSize: anchorSize,
        menuWidth: widget.menuWidth,
        animation: _ctrl,
        onClose: _close,
        contentBuilder: widget.contentBuilder,
      ),
    );

    Overlay.of(context).insert(_entry!);
    _ctrl.forward(from: 0.0);
  }

  void _close() {
    _ctrl.reverse().then((_) => _closeImmediate());
  }

  void _closeImmediate() {
    _entry?.remove();
    _entry = null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _anchorKey,
        child: GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: widget.trigger,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// The floating panel rendered inside the [Overlay].
/// Handles positioning, backdrop blur, caret, and animation.
// ─────────────────────────────────────────────────────────────────────────────
class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({
    required this.anchorPos,
    required this.anchorSize,
    required this.menuWidth,
    required this.animation,
    required this.onClose,
    required this.contentBuilder,
  });

  final Offset anchorPos;
  final Size anchorSize;
  final double menuWidth;
  final AnimationController animation;
  final VoidCallback onClose;
  final Widget Function(VoidCallback close) contentBuilder;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Glass panel background color
    final bg = isDark
        ? cs.surface.withValues(alpha: 0.80)
        : cs.surfaceContainerHigh.withValues(alpha: 0.92);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.06);

    // ── Vertical placement ─────────────────────────────────────────────────
    final bottomOfAnchor = anchorPos.dy + anchorSize.height;
    final spaceBelow =
        (mq.size.height - bottomOfAnchor - _kGap - _kScreenPad).clamp(
            0.0, double.infinity);
    final spaceAbove =
        (anchorPos.dy - _kGap - _kScreenPad).clamp(0.0, double.infinity);
    final showAbove = spaceBelow < _kMinMenuH && spaceAbove > spaceBelow;

    final double maxMenuH = (showAbove ? spaceAbove : spaceBelow).clamp(
        _kMinMenuH, mq.size.height * 0.65);

    // ── Horizontal placement ───────────────────────────────────────────────
    // Right-align with trigger's right edge, then clamp to screen width.
    final rawLeft = anchorPos.dx + anchorSize.width - menuWidth;
    final left =
        rawLeft.clamp(_kScreenPad, mq.size.width - menuWidth - _kScreenPad);

    // ── Caret alignment (points at trigger center) ─────────────────────────
    final anchorCenterX = anchorPos.dx + anchorSize.width / 2.0;
    final caretFrac =
        ((anchorCenterX - left) / menuWidth).clamp(0.07, 0.93);
    final caretAlignX = caretFrac * 2.0 - 1.0;

    // ── Vertical position ─────────────────────────────────────────────────
    final double top = showAbove
        ? anchorPos.dy - _kGap - maxMenuH - _kCaretH
        : bottomOfAnchor + _kGap;

    // ── Animations ────────────────────────────────────────────────────────
    final fadeAnim = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
    );

    // ── Glass panel ────────────────────────────────────────────────────────
    Widget glassPanel = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top caret (panel opens below anchor)
        if (!showAbove)
          Align(
            alignment: Alignment(caretAlignX, 0),
            child: CustomPaint(
              size: const Size(_kCaretW, _kCaretH),
              painter: _CaretPainter(color: bg, pointDown: false),
            ),
          ),

        // Main panel
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxMenuH),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: isDark ? 0.42 : 0.13),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: contentBuilder(onClose),
              ),
            ),
          ),
        ),

        // Bottom caret (panel opens above anchor)
        if (showAbove)
          Align(
            alignment: Alignment(caretAlignX, 0),
            child: CustomPaint(
              size: const Size(_kCaretW, _kCaretH),
              painter: _CaretPainter(color: bg, pointDown: true),
            ),
          ),
      ],
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Stack(
        children: [
          // ── Barrier: close on tap outside ──────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onClose,
            ),
          ),

          // ── Floating panel ─────────────────────────────────────────────
          Positioned(
            top: top,
            left: left,
            width: menuWidth,
            child: FadeTransition(
              opacity: fadeAnim,
              child: ScaleTransition(
                scale: scaleAnim,
                alignment: showAbove
                    ? const Alignment(0, 1.0)
                    : const Alignment(0, -1.0),
                child: glassPanel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-built convenience widgets for use inside the overlay content
// ─────────────────────────────────────────────────────────────────────────────

/// A row item inside an [AdaptiveOverlayMenuButton] panel.
class AdaptiveOverlayItem extends StatelessWidget {
  const AdaptiveOverlayItem({
    super.key,
    this.icon,
    required this.label,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final IconData? icon;
  final String label;
  final Widget? trailing;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black87;
    final textColor = enabled ? base : base.withValues(alpha: 0.35);

    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap?.call();
            }
          : null,
      child: Container(
        color: selected ? cs.primary.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? cs.primary : textColor.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? cs.primary : textColor,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (selected && trailing == null)
              Icon(Broken.tick_circle, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// Section header label inside an [AdaptiveOverlayMenuButton] panel.
class AdaptiveOverlaySection extends StatelessWidget {
  const AdaptiveOverlaySection({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cs.onSurface.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}

/// Thin divider between sections in an [AdaptiveOverlayMenuButton] panel.
class AdaptiveOverlayDivider extends StatelessWidget {
  const AdaptiveOverlayDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}

// ── Caret painter ─────────────────────────────────────────────────────────────
class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.color, this.pointDown = false});
  final Color color;
  final bool pointDown;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.color != color || old.pointDown != pointDown;
}
