import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// Tracks one burst of double-taps on a seek zone.
///
/// The HUD label reports the *total* skipped in the burst (`+15`, then `+30`),
/// while the reveal always restarts at a single arrow. An earlier version grew
/// the arrow stack per tap and reached `>>>>`, which the reveal must never do.
class SkipBurst {
  SkipBurst({this.stepSeconds = 15});

  /// Seconds added by one double-tap, mirrored in the label. Mutable because
  /// the seek interval can be changed from the in-player settings panel.
  int stepSeconds;

  bool? _right;
  int _total = 0;
  int _delta = 0;

  /// Registers one double-tap and returns the seconds *this* tap adds.
  ///
  /// The caller seeks by the returned delta and reads [total] for the label, so
  /// a burst of taps seeks 15 then 15 again while the HUD reads `+15` then
  /// `+30` — never `+45` for two taps. Tapping the other side starts a fresh
  /// burst.
  int add({required bool isRight}) {
    if (_right != null && _right != isRight) _total = 0;
    _right = isRight;
    _delta = isRight ? stepSeconds : -stepSeconds;
    _total += _delta;
    return _delta;
  }

  /// Signed seconds skipped so far in the burst; what the label shows.
  int get total => _total;

  /// Seconds added by the most recent double-tap.
  int get lastDelta => _delta;

  void reset() {
    _right = null;
    _total = 0;
    _delta = 0;
  }
}

/// Skip HUD shown on a double-tap: the reveal is always `>` → `>>` → `>>+15`.
///
/// The animation is driven by an [AnimationController] started in `initState`
/// and the parent passes a `ValueKey(token)` so every double-tap mounts a fresh
/// HUD. That is deliberate: `didUpdateWidget` only replays when the widget was
/// already mounted, so a burst of taps landing while the HUD is on screen could
/// otherwise keep the previous frame.
class PlayerSkipHud extends StatefulWidget {
  const PlayerSkipHud({
    super.key,
    required this.isRight,
    required this.seconds,
    this.token = 0,
    this.arrowCount = 2,
  });

  final bool isRight;

  /// Seconds skipped in the current burst; rendered as `+N` / `-N`.
  final int seconds;

  /// Bumped on every double-tap so the reveal replays from the first arrow.
  final int token;

  /// Fixed at two: the reveal must never grow the stack with the tap count.
  final int arrowCount;

  @override
  State<PlayerSkipHud> createState() => _PlayerSkipHudState();
}

class _PlayerSkipHudState extends State<PlayerSkipHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  int get _stages => widget.arrowCount + 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void didUpdateWidget(PlayerSkipHud old) {
    super.didUpdateWidget(old);
    // Belt and braces: the parent also re-keys the HUD, but replaying on a
    // token change keeps the reveal correct if the key is ever dropped.
    if (widget.token != old.token ||
        widget.isRight != old.isRight ||
        widget.seconds != old.seconds) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isRight ? Broken.forward : Broken.backward;
    final slice = 1.0 / _stages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.arrowCount; i++)
          _AnimatedSkipArrow(
            icon: icon,
            size: widget.isRight ? 24 : 26,
            animation: CurvedAnimation(
              parent: _ctrl,
              curve: Interval(
                i * slice,
                (i + 1) * slice,
                curve: Curves.easeOutBack,
              ),
            ),
          ),
        const SizedBox(width: 8),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
              widget.arrowCount * slice,
              1.0,
              curve: Curves.easeOut,
            ),
          ),
          child: Text(
            '${widget.isRight ? '+' : '-'}${widget.seconds.abs()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedSkipArrow extends StatelessWidget {
  const _AnimatedSkipArrow({
    required this.icon,
    required this.size,
    required this.animation,
  });

  final IconData icon;
  final double size;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - animation.value) * 8, 0),
          child: child,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
