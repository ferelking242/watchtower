import 'package:flutter/widgets.dart';

/// Window size classes used across the app.
///
/// The thresholds follow the Material 3 window-size classes for the phone and
/// tablet range, then add two desktop classes so a maximised window on a
/// 1440p or ultrawide monitor is not treated the same as a 1280px laptop.
///
/// This is a plain data enum with no Flutter widget dependency beyond
/// [Size]/[MediaQueryData] so the layout maths can be unit-tested directly.
enum WindowSizeClass {
  /// Phones in portrait. Single column, no rail.
  compact,

  /// Large phones and small tablets in portrait.
  medium,

  /// Tablets in landscape and small desktop windows.
  expanded,

  /// Standard desktop windows (1280–1600px).
  large,

  /// Wide desktop and ultrawide windows (1600px+).
  extraLarge,
}

/// Inclusive lower bound of each class, in logical pixels.
const double kCompactMax = 600;
const double kMediumMax = 840;
const double kExpandedMax = 1200;
const double kLargeMax = 1600;

WindowSizeClass windowSizeClassFor(double width) {
  if (width < kCompactMax) return WindowSizeClass.compact;
  if (width < kMediumMax) return WindowSizeClass.medium;
  if (width < kExpandedMax) return WindowSizeClass.expanded;
  if (width < kLargeMax) return WindowSizeClass.large;
  return WindowSizeClass.extraLarge;
}

extension WindowSizeClassX on WindowSizeClass {
  /// True for the three classes that get the persistent PC sidebar.
  bool get usesSidebar =>
      this == WindowSizeClass.expanded ||
      this == WindowSizeClass.large ||
      this == WindowSizeClass.extraLarge;

  /// True when there is enough room for a second content column (cover next to
  /// the synopsis, chapters next to the metadata, …).
  bool get supportsTwoColumns =>
      this == WindowSizeClass.large || this == WindowSizeClass.extraLarge;

  /// True once the window is wide enough that a full-width row of text forces
  /// the eye to travel: content should be centred at a comfortable measure.
  bool get needsContentCap => index >= WindowSizeClass.expanded.index;

  /// Max width of the centred content column. `null` means "use full width".
  ///
  /// These are the classic desktop reading measures: a settings list, an
  /// article or a form reads best around 1000–1300px regardless of how much
  /// screen is left over.
  double? get contentMaxWidth => switch (this) {
    WindowSizeClass.compact => null,
    WindowSizeClass.medium => null,
    WindowSizeClass.expanded => 900,
    WindowSizeClass.large => 1180,
    WindowSizeClass.extraLarge => 1320,
  };

  /// Horizontal page padding for the shell. Desktop pages get breathing room
  /// from the window edge instead of the phone's tight 16px gutter.
  double get pagePadding => switch (this) {
    WindowSizeClass.compact => 16,
    WindowSizeClass.medium => 20,
    WindowSizeClass.expanded => 24,
    WindowSizeClass.large => 32,
    WindowSizeClass.extraLarge => 40,
  };

  /// Comfortable reading measure for a block of prose (synopsis, description).
  double get proseMaxWidth => switch (this) {
    WindowSizeClass.compact => double.infinity,
    WindowSizeClass.medium => double.infinity,
    WindowSizeClass.expanded => 720,
    WindowSizeClass.large => 780,
    WindowSizeClass.extraLarge => 840,
  };
}

/// Resolves the window size class from a [BuildContext].
WindowSizeClass windowSizeClassOf(BuildContext context) =>
    windowSizeClassFor(MediaQuery.sizeOf(context).width);

/// A responsive grid description: how many columns to draw and how wide each
/// tile should be, derived from the available width and the tile aspect ratio.
class AdaptiveGridSpec {
  const AdaptiveGridSpec({
    required this.columns,
    required this.tileExtent,
    required this.spacing,
  });

  final int columns;
  final double tileExtent;
  final double spacing;

  static const double defaultSpacing = 12;

  /// Builds a spec for [availableWidth].
  ///
  /// [minTileWidth] keeps covers from becoming thumbnails on a huge monitor;
  /// [maxColumns] caps the count so an ultrawide window does not end up with a
  /// strip of fifteen covers. Tiles may end up wider than [minTileWidth] when
  /// the width does not divide evenly or when [maxColumns] is the binding
  /// constraint.
  factory AdaptiveGridSpec.resolve(
    double availableWidth, {
    double minTileWidth = 132,
    int maxColumns = 10,
    double spacing = defaultSpacing,
  }) {
    final safeWidth = availableWidth.isFinite && availableWidth > 0
        ? availableWidth
        : minTileWidth;
    var columns = (safeWidth / (minTileWidth + spacing)).floor();
    if (columns < 1) columns = 1;
    if (columns > maxColumns) columns = maxColumns;
    final extent = (safeWidth - spacing * (columns - 1)) / columns;
    return AdaptiveGridSpec(
      columns: columns,
      tileExtent: extent,
      spacing: spacing,
    );
  }
}
