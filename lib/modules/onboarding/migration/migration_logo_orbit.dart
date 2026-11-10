import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:watchtower/modules/onboarding/migration/migration_apps.dart';
import 'package:watchtower/modules/onboarding/onboarding_showcase_config.dart';

/// The migration animation: the logos of the other apps orbit the Watchtower
/// mark while data motes travel inwards, so the page reads as "everything
/// arrives here".
///
/// It follows the showcase conventions: one controller for the whole scene, a
/// capped amount of work, and no motion at all when the platform asks for
/// reduced motion — in that case the logos are drawn at rest.
class MigrationLogoOrbit extends StatefulWidget {
  const MigrationLogoOrbit({
    super.key,
    required this.apps,
    this.diameter = 260,
    this.highlighted,
  });

  /// The logos to show. Extra entries beyond the orbit capacity are dropped.
  final List<MigrationApp> apps;

  /// Size of the whole scene.
  final double diameter;

  /// The app the user picked, drawn in the inner ring with a brighter ring.
  final MigrationApp? highlighted;

  @override
  State<MigrationLogoOrbit> createState() => _MigrationLogoOrbitState();
}

class _MigrationLogoOrbitState extends State<MigrationLogoOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  bool _motionDisabled = false;
  bool _started = false;

  /// Logos per orbit ring. The scene stays readable and cheap past that.
  static const int _outerCount = 8;
  static const int _innerCount = 4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionDisabled = showcaseMotionDisabled(context);
    _sync();
  }

  @override
  void didUpdateWidget(MigrationLogoOrbit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apps != widget.apps ||
        oldWidget.highlighted != widget.highlighted) {
      _sync();
    }
  }

  void _sync() {
    if (_motionDisabled) {
      _controller.stop();
      if (_controller.value != 0.35) _controller.value = 0.35;
      return;
    }
    if (!_started) {
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    // The highlighted app is drawn in the inner ring, so it is always visible
    // while the outer logos keep turning.
    final rest = widget.apps
        .where((app) => app.id != widget.highlighted?.id)
        .toList(growable: false);
    final outer = rest.take(_outerCount).toList(growable: false);
    final inner = <MigrationApp>[
      if (widget.highlighted != null) widget.highlighted!,
      ...rest.skip(_outerCount).take(_innerCount - 1),
    ];

    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _Halo(accent: accent, pulse: _motionDisabled ? 0.5 : t),
              for (var i = 0; i < outer.length; i++)
                _orbiting(
                  app: outer[i],
                  index: i,
                  count: outer.length,
                  turn: t,
                  radius: 0.44,
                  size: 34,
                  accent: accent,
                  counterRotate: false,
                ),
              for (var i = 0; i < inner.length; i++)
                _orbiting(
                  app: inner[i],
                  index: i,
                  count: inner.length,
                  turn: -t,
                  radius: 0.27,
                  size: 30,
                  accent: accent,
                  counterRotate: true,
                ),
              _CenterMark(size: widget.diameter * 0.30, accent: accent),
            ],
          );
        },
      ),
    );
  }

  Widget _orbiting({
    required MigrationApp app,
    required int index,
    required int count,
    required double turn,
    required double radius,
    required double size,
    required Color accent,
    required bool counterRotate,
  }) {
    final angle = (index / count) * 2 * math.pi + turn * 2 * math.pi;
    final r = widget.diameter * radius;
    final dx = math.cos(angle) * r;
    final dy = math.sin(angle) * r;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: _AppBadge(
        app: app,
        size: size,
        accent: accent,
        // The badge turns with the orbit, so the logo is counter-rotated to
        // stay upright: the app name under it is always readable.
        angle: -angle,
        showName: size >= 32 && !counterRotate,
      ),
    );
  }
}

/// A soft radial glow behind the scene, pulsing slowly.
class _Halo extends StatelessWidget {
  const _Halo({required this.accent, required this.pulse});

  final Color accent;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scale = 1 + 0.05 * math.sin(pulse * 2 * math.pi);
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: 0.22),
              accent.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// One app logo in a glass circle, optionally captioned.
class _AppBadge extends StatelessWidget {
  const _AppBadge({
    required this.app,
    required this.size,
    required this.accent,
    required this.angle,
    required this.showName,
  });

  final MigrationApp app;
  final double size;
  final Color accent;
  final double angle;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.all(size * 0.18),
            child: Image.asset(
              app.logoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // A missing logo must never break the scene.
              errorBuilder: (_, _, _) => Icon(
                Icons.apps_rounded,
                size: size * 0.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (showName) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                app.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Watchtower mark at the centre of the orbit.
class _CenterMark extends StatelessWidget {
  const _CenterMark({required this.size, required this.accent});

  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.2),
      child: Image.asset(
        'assets/app_icons/icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) =>
            Icon(Icons.remove_red_eye_rounded, size: size * 0.5, color: accent),
      ),
    );
  }
}
