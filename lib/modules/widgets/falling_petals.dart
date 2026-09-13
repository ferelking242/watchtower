import 'dart:math' as math;
import 'package:flutter/material.dart';

class FallingPetals extends StatefulWidget {
  const FallingPetals({super.key});

  @override
  State<FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<FallingPetals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PetalPainter(_controller), size: Size.infinite);
}

class _PetalPainter extends CustomPainter {
  final Animation<double> animation;

  _PetalPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 22; i++) {
      final seed = i * 37.0;
      final progress = (animation.value + i / 22) % 1;
      final x = ((seed * 17) % 100) / 100 * size.width +
          math.sin((progress * math.pi * 2) + i) * 18;
      final y = progress * (size.height + 70) - 35;
      final r = 3.0 + (i % 4);
      paint.color = (i.isEven ? const Color(0xFFFFB7D5) : const Color(0xFFF4A7C1))
          .withValues(alpha: 0.16 + (i % 3) * 0.05);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 3 + i);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) => false;
}