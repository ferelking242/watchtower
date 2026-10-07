import 'package:flutter/material.dart';

class DownloadQueueTreeConnector extends CustomPainter {
  final Color color;
  final bool isLast;
  final double? branchY;

  const DownloadQueueTreeConnector({
    required this.color,
    required this.isLast,
    this.branchY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width * 0.38;
    final centerY = (branchY ?? size.height / 2).clamp(0.0, size.height);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, isLast ? centerY : size.height),
      paint,
    );
    canvas.drawLine(Offset(x, centerY), Offset(size.width, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant DownloadQueueTreeConnector oldDelegate) =>
      color != oldDelegate.color ||
      isLast != oldDelegate.isLast ||
      branchY != oldDelegate.branchY;
}
