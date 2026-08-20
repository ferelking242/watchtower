import 'package:flutter/material.dart';

/// Netflix-style animated "W" splash screen for Watchtower.
///
/// Pure Flutter animation — no Lottie, no assets needed.
/// Shows a dramatic "W" logo reveal with a red glow sweep,
/// then fades out to reveal the app.
///
/// Usage:
/// ```dart
/// Navigator.of(context).pushReplacement(
///   MaterialPageRoute(
///     builder: (_) => WatchtowerSplashScreen(
///       onAnimationComplete: () => context.go('/Library'),
///     ),
///   ),
/// );
/// ```
class WatchtowerSplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const WatchtowerSplashScreen({
    super.key,
    required this.onAnimationComplete,
  });

  @override
  State<WatchtowerSplashScreen> createState() => _WatchtowerSplashScreenState();
}

class _WatchtowerSplashScreenState extends State<WatchtowerSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _glowController;
  late final AnimationController _fadeController;

  // Phase 1: W scales up from nothing (0-1.2s)
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  // Phase 2: Red glow sweeps across (0.8-2.0s)
  late final Animation<double> _glowSweep;

  // Phase 3: Whole screen fades out (2.2-3.0s)
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Main scale + opacity animation for the W
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Glow sweep animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _glowSweep = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Fade out animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Small initial delay for dramatic effect
    await Future.delayed(const Duration(milliseconds: 200));
    _mainController.forward();

    // Start glow slightly after W begins appearing
    await Future.delayed(const Duration(milliseconds: 600));
    _glowController.forward();

    // Wait for scale + glow to finish
    await Future.delayed(const Duration(milliseconds: 1200));

    // Fade out
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _glowController, _fadeController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeOut.value,
          child: Container(
            color: Colors.black,
            child: Center(
              child: _buildWLogo(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWLogo() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final opacity = _opacityAnimation.value;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(200, 160),
              painter: _WatchtowerWPainter(
                glowProgress: _glowSweep.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that draws the Watchtower "W" logo with a red glow sweep.
class _WatchtowerWPainter extends CustomPainter {
  final double glowProgress;

  _WatchtowerWPainter({required this.glowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // W shape path — four strokes forming a bold W
    final wPath = Path();
    final w = size.width;
    final h = size.height;
    final strokeW = w * 0.08; // thickness of each stroke

    // The W: two V shapes side by side
    // Points: top-left, bottom-left-center, middle-top, bottom-right-center, top-right
    final p1 = Offset(w * 0.05, 0);         // top-left
    final p2 = Offset(w * 0.25, h);         // bottom-left
    final p3 = Offset(w * 0.5, h * 0.15);   // middle-top
    final p4 = Offset(w * 0.75, h);         // bottom-right
    final p5 = Offset(w * 0.95, 0);         // top-right

    wPath.moveTo(p1.dx, p1.dy);
    wPath.lineTo(p2.dx, p2.dy);
    wPath.lineTo(p3.dx, p3.dy);
    wPath.lineTo(p4.dx, p4.dy);
    wPath.lineTo(p5.dx, p5.dy);

    // Draw the W with a white stroke
    final wPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(wPath, wPaint);

    // Red glow effect — a vertical light band that sweeps across
    if (glowProgress >= 0.0 && glowProgress <= 2.0) {
      final glowX = center.dx + (glowProgress - 0.5) * w * 0.8;
      final glowRadius = w * 0.35;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          alignment: Alignment(glowProgress - 1.0, 0),
          radius: 0.5,
          colors: [
            const Color(0xFFFF0000).withOpacity(0.6),
            const Color(0xFFFF0000).withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      // Clip to W stroke area for the glow
      canvas.save();
      canvas.drawPath(
        wPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW * 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.transparent,
      );

      // Draw glow as a blend
      final glowRect = Rect.fromLTWH(
        glowX - glowRadius,
        -glowRadius * 0.3,
        glowRadius * 2,
        h + glowRadius * 0.6,
      );
      canvas.drawRect(glowRect, glowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WatchtowerWPainter oldDelegate) {
    return oldDelegate.glowProgress != glowProgress;
  }
}
