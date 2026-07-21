// Source: github.com/namidaco/namida — lib/ui/widgets/inner_drawer.dart (GPL-3.0)
// Watchtower adaptation: Namida-only deps replaced with Flutter equivalents.
//   Rx           → ValueNotifier
//   ObxO         → ValueListenableBuilder
//   context.width / .height  → MediaQuery
//   withOpacityExt / clampDouble / withMinimum → inlined
//   AnimatedColor → AnimatedContainer
//   ArtworkWidget.isMovingDrawer  → removed (no-op)
//   HorizontalDragDetector / TapDetector → GestureDetector
//   DecorationClipper → _DecorationClipper (inlined)
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
      (controller.value / _upperBoundRx.value).clamp(0.0, 1.0);
  bool get isOpened => _isOpened;
  void toggle() => isOpened ? _closeDrawer() : _openDrawer();
  void open() => _openDrawer();
  void close() => _closeDrawer();
  void toggleCanSwipe(bool swipe) {
    if (_canSwipe == swipe) return;
    setState(() => _canSwipe = swipe);
  }

  late final AnimationController controller;
  final _upperBoundRx = ValueNotifier<double>(0.0);

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      upperBound: 2.0,
      duration: Duration.zero,
    );
    controller.addStatusListener(_statusListener);
    _upperBoundRx.value = widget.maxPercentage;
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    _upperBoundRx.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NamidaInnerDrawer oldWidget) {
    if (widget.maxPercentage != oldWidget.maxPercentage) {
      _upperBoundRx.value = widget.maxPercentage;
      if (_isOpened) {
        controller.animateTo(_upperBoundRx.value,
            duration: Duration.zero); // just reanimate
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

  void _statusListener(AnimationStatus status) {
    // ArtworkWidget.isMovingDrawer removed — not needed in Watchtower
  }

  void _openDrawer() {
    _isOpened = true;
    controller.animateTo(_upperBoundRx.value,
        duration: widget.duration, curve: widget.curve);
  }

  void _closeDrawer() {
    _isOpened = false;
    controller.animateTo(controller.lowerBound,
        duration: widget.duration, curve: widget.curve);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerChild = RepaintBoundary(child: widget.drawerChild);
    final scaffoldBody = RepaintBoundary(child: widget.child);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double animationValue = controller.value;
        final child = Stack(
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
                    color: Colors.black
                        .withOpacity((animationValue * 0.35).clamp(0.0, 0.7)),
                  ),
                ),
              ),
            ),
          ],
        );
        final finalBuilder = Stack(
          children: [
            // -- bg
            if (animationValue > 0) ...[
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: theme.scaffoldBackgroundColor,
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(screenWidth * animationValue * 0.6, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(
                              theme.brightness == Brightness.dark ? 5 : 25),
                          blurRadius: 58.0,
                          spreadRadius: 12.0,
                          offset: const Offset(-2.0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // -- drawer
              ValueListenableBuilder<double>(
                valueListenable: _upperBoundRx,
                builder: (context, upperBound, _) => Padding(
                  padding: EdgeInsets.only(right: screenWidth * (1 - upperBound)),
                  child: Transform.translate(
                    offset: Offset(
                        -((upperBound - animationValue) * screenWidth * 0.5),
                        0),
                    child: drawerChild,
                  ),
                ),
              ),
              // -- drawer dim
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _upperBoundRx,
                    builder: (context, upperBound, _) => ColoredBox(
                      color: Colors.black.withOpacity(
                          ((upperBound - animationValue) * 0.4)
                              .clamp(0.0, 0.6)),
                    ),
                  ),
                ),
              ),
            ],

            // -- child
            Transform.translate(
              offset: Offset(screenWidth * animationValue, 0),
              child: widget.borderRadius > 0
                  ? ClipPath(
                      clipper: _DecorationClipper(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              widget.borderRadius * animationValue),
                        ),
                      ),
                      child: child,
                    )
                  : child,
            ),
          ],
        );
        return _canSwipe
            // -- touch absorber
            ? GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragDown: (_) {
                  controller.stop();
                  _recalculateDistanceTraveled();
                },
                onHorizontalDragUpdate: (details) {
                  double toAdd = details.delta.dx;
                  if (controller.value > widget.maxPercentage) {
                    double toSubtract = (toAdd * (0.15 + controller.value));
                    toAdd -= toSubtract;
                  }
                  _distanceTraveled =
                      (_distanceTraveled + toAdd).clamp(0.0, double.infinity);
                  controller.animateTo(_distanceTraveled / screenWidth);
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond.dx;
                  if (velocity > 300) {
                    _openDrawer();
                  } else if (velocity < -300) {
                    _closeDrawer();
                  } else if (animationValue > (_upperBoundRx.value * 0.4)) {
                    _openDrawer();
                  } else {
                    _closeDrawer();
                  }
                },
                child: finalBuilder,
              )
            : finalBuilder;
      },
    );
  }
}

// -- DecorationClipper (from Namida custom_widgets.dart — inlined)
class _DecorationClipper extends CustomClipper<Path> {
  const _DecorationClipper({
    this.textDirection = TextDirection.ltr,
    required this.decoration,
  });

  final TextDirection textDirection;
  final Decoration decoration;

  @override
  Path getClip(Size size) {
    return decoration.getClipPath(Offset.zero & size, textDirection);
  }

  @override
  bool shouldReclip(_DecorationClipper oldClipper) {
    return oldClipper.decoration != decoration ||
        oldClipper.textDirection != textDirection;
  }
}
