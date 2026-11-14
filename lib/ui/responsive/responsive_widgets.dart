import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Centres [child] at a comfortable reading measure on wide windows and leaves
/// it full-width on phones.
///
/// A list or a form stretched edge to edge on a 2000px monitor forces the eye
/// to travel from one side of the screen to the other. Desktop apps cap the
/// content column; this widget applies the same cap everywhere so a page only
/// has to wrap its body once.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padHorizontally = true,
    this.padVertically = false,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;

  /// Overrides the class-derived maximum. `null` uses the size-class default.
  final double? maxWidth;

  /// When true the content gets the size-class page gutter on its left/right.
  final bool padHorizontally;

  /// When true the content also gets a vertical gutter.
  final bool padVertically;

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final cls = windowSizeClassOf(context);
    final limit = maxWidth ?? cls.contentMaxWidth;
    Widget content = child;
    if (padHorizontally || padVertically) {
      final pad = cls.pagePadding;
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padHorizontally ? pad : 0,
          vertical: padVertically ? pad * 0.5 : 0,
        ),
        child: content,
      );
    }
    if (limit == null) return content;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: content,
      ),
    );
  }
}

/// A two-column layout that collapses to a single column on narrow windows.
///
/// On a wide desktop window there is plenty of empty space next to a detail
/// page's cover; [ResponsiveSplitView] puts the secondary pane beside the
/// primary one instead of below it. Below the split threshold it stacks them in
/// the original order, so the phone layout is unchanged.
class ResponsiveSplitView extends StatelessWidget {
  const ResponsiveSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.gap = 24,
    this.primaryFlex = 2,
    this.secondaryFlex = 3,
  });

  final Widget primary;
  final Widget secondary;
  final double gap;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    final cls = windowSizeClassOf(context);
    if (!cls.supportsTwoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, SizedBox(height: gap), secondary],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: primaryFlex, child: primary),
        SizedBox(width: gap),
        Expanded(flex: secondaryFlex, child: secondary),
      ],
    );
  }
}

/// Runs [builder] with the current [WindowSizeClass] and the available width,
/// re-running on every resize. Useful where a `LayoutBuilder` would otherwise
/// be needed but the widget also wants the shared class thresholds.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    WindowSizeClass sizeClass,
    double width,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return builder(context, windowSizeClassFor(width), width);
      },
    );
  }
}
