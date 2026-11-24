import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// Pull-to-refresh that never moves the page.
///
/// A classic [RefreshIndicator] slides the whole scrollable down, which dragged
/// the Hub hero carousel off-screen. This wrapper keeps the content pinned and
/// paints a wave at the top edge instead; the wave grows with the pull and
/// settles while [onRefresh] runs.
class WavePullRefresh extends StatefulWidget {
  const WavePullRefresh({
    required this.child,
    required this.onRefresh,
    this.color,
    super.key,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  @override
  State<WavePullRefresh> createState() => _WavePullRefreshState();
}

class _WavePullRefreshState extends State<WavePullRefresh>
    with SingleTickerProviderStateMixin {
  static const double _trigger = 74;

  double _pull = 0;
  bool _refreshing = false;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification notification) {
    if (_refreshing) return false;
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      setState(() => _pull = (_pull - notification.overscroll).clamp(0, 140));
    } else if (notification is ScrollEndNotification && _pull > 0) {
      if (_pull >= _trigger) {
        _start();
      } else {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _refreshing = true;
      _pull = _trigger;
    });
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (!mounted) return;
      _spin.stop();
      setState(() {
        _refreshing = false;
        _pull = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.primary;
    final progress = (_pull / _trigger).clamp(0.0, 1.0);
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: _pull,
                child: _pull <= 0
                    ? const SizedBox.shrink()
                    : AnimatedBuilder(
                        animation: _spin,
                        builder: (context, _) => CustomPaint(
                          painter: _WavePainter(
                            color: color,
                            amplitude: 3 + 7 * progress,
                            phase: _refreshing
                                ? _spin.value * math.pi * 2
                                : progress * math.pi,
                          ),
                          child: Center(
                            child: Transform.rotate(
                              angle: _refreshing
                                  ? _spin.value * math.pi * 2
                                  : progress * math.pi,
                              child: Icon(
                                Broken.refresh_2,
                                size: 18,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.color,
    required this.amplitude,
    required this.phase,
  });

  final Color color;
  final double amplitude;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.04),
        ],
      ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.75);

    final path = Path()..moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x += 4) {
      final y =
          size.height * 0.55 +
          math.sin((x / size.width) * math.pi * 3 + phase) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, fill);

    final line = Path()..moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x += 4) {
      final y =
          size.height * 0.55 +
          math.sin((x / size.width) * math.pi * 3 + phase) * amplitude;
      line.lineTo(x, y);
    }
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.amplitude != amplitude || old.phase != phase || old.color != color;
}
