import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Live TV menu button: three bars, deliberately misaligned.
///
/// A stock hamburger reads as "a generic drawer". Three bars of different
/// lengths, nudged off each other and slightly tilted, read as hand-drawn —
/// which is the point of the broken icon font this app already uses elsewhere.
/// The whole mark reacts to hover and focus by snapping straight, so the
/// affordance still reads as a menu.
class BrokenMenuIcon extends StatefulWidget {
  const BrokenMenuIcon({
    super.key,
    required this.onPressed,
    this.size = 24,
    this.color,
  });

  final VoidCallback onPressed;
  final double size;
  final Color? color;

  @override
  State<BrokenMenuIcon> createState() => _BrokenMenuIconState();
}

class _BrokenMenuIconState extends State<BrokenMenuIcon> {
  bool _hover = false;
  bool _focus = false;

  bool get _lit => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: 'Menu',
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AnimatedScale(
              scale: _lit ? 1.08 : 1,
              duration: const Duration(milliseconds: 140),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _BrokenBarsPainter(
                    color: _lit ? Theme.of(context).colorScheme.primary : color,
                    straight: _lit,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenBarsPainter extends CustomPainter {
  _BrokenBarsPainter({required this.color, required this.straight});

  final Color color;

  /// When true the bars align, which is the hover/focus state.
  final bool straight;

  // (length factor, vertical offset, tilt in radians) per bar.
  static const _bars = <(double, double, double)>[
    (0.78, -0.13, -0.05),
    (1.0, 0.03, 0.02),
    (0.62, 0.16, -0.03),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height * 0.115
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final centerY = size.height / 2;
    final gap = size.height * 0.29;

    for (var i = 0; i < _bars.length; i++) {
      final (lengthFactor, offsetFactor, tilt) = _bars[i];
      final length = size.width * (straight ? 0.92 : lengthFactor);
      final dy =
          centerY + (i - 1) * gap + (straight ? 0 : size.height * offsetFactor);
      final dx = straight ? (size.width - length) / 2 : size.width * 0.06;
      final start = Offset(dx, dy);
      final end = Offset(dx + length, dy);

      if (straight) {
        canvas.drawLine(start, end, paint);
        continue;
      }
      // Rotate each bar about its own centre so the ends break the grid.
      final centre = Offset((start.dx + end.dx) / 2, dy);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(tilt * math.pi);
      canvas.drawLine(Offset(-length / 2, 0), Offset(length / 2, 0), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BrokenBarsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.straight != straight;
}
