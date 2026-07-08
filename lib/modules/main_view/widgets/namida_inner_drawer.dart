// Adapted from Namida — github.com/namidaco/namida (GPL-3.0)
// Original: lib/ui/widgets/inner_drawer.dart
// Adaptations: Namida-specific deps removed, Rx → ValueNotifier,
// custom gesture detectors → GestureDetector, extensions inlined.
import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

class NamidaInnerDrawer extends StatefulWidget {
  final Widget drawerChild;
  final Color? drawerBG;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double borderRadius;
  final double maxPercentage;
  final bool initiallySwipeable;

  const NamidaInnerDrawer({
    super.key,
    required this.drawerChild,
    this.drawerBG,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.fastEaseInToSlowEaseOut,
    this.borderRadius = 0,
    this.maxPercentage = 0.472,
    this.initiallySwipeable = true,
  });

  @override
  State<NamidaInnerDrawer> createState() => NamidaInnerDrawerState();
}

class NamidaInnerDrawerState extends State<NamidaInnerDrawer>
    with SingleTickerProviderStateMixin {
  Animation<double> get animationView => controller.view;
  double get drawerPercentage =>
      clampDouble(controller.value / _upperBound.value, 0.0, 1.0);
  bool get isOpened => _isOpened;
  void toggle() => isOpened ? _closeDrawer() : _openDrawer();
  void open() => _openDrawer();
  void close() => _closeDrawer();
  void toggleCanSwipe(bool swipe) {
    if (_canSwipe == swipe) return;
    setState(() => _canSwipe = swipe);
  }

  late final AnimationController controller;
  final _upperBound = ValueNotifier<double>(0.0);

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      upperBound: 2.0,
      duration: Duration.zero,
    );
    _upperBound.value = widget.maxPercentage;
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    _upperBound.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NamidaInnerDrawer oldWidget) {
    if (widget.maxPercentage != oldWidget.maxPercentage) {
      _upperBound.value = widget.maxPercentage;
      if (_isOpened) {
        controller.animateTo(_upperBound.value, duration: Duration.zero);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  late bool _canSwipe = widget.initiallySwipeable;
  bool _isOpened = false;
  double _distanceTraveled = 0;

  void _recalculateDistanceTraveled() {
    _distanceTraveled =
        controller.value * MediaQuery.of(context).size.width;
  }

  void _openDrawer() {
    _isOpened = true;
    controller.animateTo(
      _upperBound.value,
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  void _closeDrawer() {
    _isOpened = false;
    controller.animateTo(
      controller.lowerBound,
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drawerChild = RepaintBoundary(child: widget.drawerChild);
    final scaffoldBody = RepaintBoundary(child: widget.child);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double animationValue = controller.value;

        // Main content stack (with dim overlay + edge absorber)
        final content = Stack(
          children: [
            scaffoldBody,
            Positioned.fill(
              child: GestureDetector(
                onTap: animationValue == controller.lowerBound
                    ? null
                    : _closeDrawer,
                child: IgnorePointer(
                  ignoring: animationValue == controller.lowerBound,
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: clampDouble(animationValue * 1.2, 0.0, 1.0),
                    ),
                  ),
                ),
              ),
            ),
            // Edge absorber so swipe-from-left opens the drawer
            if (_canSwipe)
              ColoredBox(
                color: Colors.transparent,
                child: SizedBox(
                  height: screenHeight,
                  width:
                      math.max(20.0, MediaQuery.paddingOf(context).left),
                ),
              ),
          ],
        );

        final finalBuilder = Stack(
          children: [
            if (animationValue > 0) ...[
              // Solid background so drawer reveals it nicely
              Positioned.fill(
                child:
                    ColoredBox(color: theme.scaffoldBackgroundColor),
              ),
              // Shadow on the right edge of the drawer
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(screenWidth * animationValue * 0.6, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: isDark ? 0.02 : 0.10,
                          ),
                          blurRadius: 58.0,
                          spreadRadius: 12.0,
                          offset: const Offset(-2.0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Drawer panel
              ValueListenableBuilder<double>(
                valueListenable: _upperBound,
                builder: (context, upperBound, _) => Padding(
                  padding: EdgeInsets.only(
                      right: screenWidth * (1 - upperBound)),
                  child: Transform.translate(
                    offset: Offset(
                      -((upperBound - animationValue) * screenWidth * 0.5),
                      0,
                    ),
                    child: drawerChild,
                  ),
                ),
              ),
              // Dim overlay on the drawer itself (lightens as drawer opens)
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _upperBound,
                    builder: (context, upperBound, _) => ColoredBox(
                      color: Colors.black.withValues(
                        alpha: clampDouble(
                          (upperBound - animationValue) * 1.8,
                          0.0,
                          1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Main content — slides right as drawer opens
            Transform.translate(
              offset: Offset(screenWidth * animationValue, 0),
              child: widget.borderRadius > 0
                  ? ClipPath(
                      clipper: _DecorationClipper(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.borderRadius * animationValue,
                          ),
                        ),
                      ),
                      child: content,
                    )
                  : content,
            ),
          ],
        );

        if (!_canSwipe) return finalBuilder;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragDown: (_) {
            controller.stop();
            _recalculateDistanceTraveled();
          },
          onHorizontalDragUpdate: (details) {
            double toAdd = details.delta.dx;
            if (controller.value > widget.maxPercentage) {
              toAdd -= toAdd * (0.15 + controller.value);
            }
            _distanceTraveled =
                math.max(0.0, _distanceTraveled + toAdd);
            controller
                .animateTo(_distanceTraveled / screenWidth);
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.velocity.pixelsPerSecond.dx;
            if (velocity > 300) {
              _openDrawer();
            } else if (velocity < -300) {
              _closeDrawer();
            } else if (animationValue > (_upperBound.value * 0.4)) {
              _openDrawer();
            } else {
              _closeDrawer();
            }
          },
          child: finalBuilder,
        );
      },
    );
  }
}

/// Clips a widget using [BoxDecoration.getClipPath] — used for border-radius
/// during the drawer open/close transition.
class _DecorationClipper extends CustomClipper<Path> {
  final BoxDecoration decoration;
  const _DecorationClipper({required this.decoration});

  @override
  Path getClip(Size size) =>
      decoration.getClipPath(Offset.zero & size, TextDirection.ltr);

  @override
  bool shouldReclip(_DecorationClipper old) => decoration != old.decoration;
}
