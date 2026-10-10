import 'package:flutter/material.dart';

/// Small transparent vector marks shared by the Smart Library entry and page.
class SmartLibraryIcon extends StatelessWidget {
  final bool isManga;
  final Color color;
  final double size;

  const SmartLibraryIcon({
    required this.isManga,
    required this.color,
    this.size = 40,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _SmartLibraryIconPainter(isManga: isManga, color: color),
    ),
  );
}

class _SmartLibraryIconPainter extends CustomPainter {
  final bool isManga;
  final Color color;

  const _SmartLibraryIconPainter({required this.isManga, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 54, size.height / 54);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()
      ..color = color.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    if (isManga) {
      final leftPage = Path()
        ..moveTo(8, 13)
        ..cubicTo(15, 11, 22, 13, 27, 17)
        ..lineTo(27, 43)
        ..cubicTo(21, 39, 15, 38, 8, 40)
        ..close();
      final rightPage = Path()
        ..moveTo(27, 17)
        ..cubicTo(33, 13, 40, 11, 46, 13)
        ..lineTo(46, 40)
        ..cubicTo(39, 38, 33, 39, 27, 43)
        ..close();
      canvas.drawPath(leftPage, outline);
      canvas.drawPath(rightPage, outline);
      canvas.drawLine(const Offset(27, 17), const Offset(27, 43), outline);
      canvas
        ..drawLine(const Offset(13, 21), const Offset(21, 23), accent)
        ..drawLine(const Offset(13, 27), const Offset(21, 29), accent)
        ..drawLine(const Offset(33, 23), const Offset(41, 21), accent)
        ..drawLine(const Offset(33, 29), const Offset(41, 27), accent);
    } else {
      final screen = RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 8, 44, 33),
        const Radius.circular(6),
      );
      canvas.drawRRect(screen, outline);
      final play = Path()
        ..moveTo(23, 17)
        ..lineTo(23, 32)
        ..lineTo(35, 24.5)
        ..close();
      canvas.drawPath(
        play,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas
        ..drawLine(const Offset(21, 42), const Offset(21, 47), outline)
        ..drawLine(const Offset(33, 42), const Offset(33, 47), outline)
        ..drawLine(const Offset(16, 48), const Offset(38, 48), outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SmartLibraryIconPainter oldDelegate) =>
      oldDelegate.isManga != isManga || oldDelegate.color != color;
}
