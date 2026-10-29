import 'package:flutter/material.dart';

/// Colours for the Marketplace surfaces.
///
/// The Marketplace used to hard-code its own dark palette (`#101010`,
/// `#1B1B1D`, `#252527`, `Colors.white`), so a user on the light theme still
/// got a black page with white text. Every one of those constants is now
/// derived from the active [ColorScheme], which keeps the dark look identical
/// while letting the light theme actually be light.
@immutable
class MarketplacePalette {
  /// Accent kept from the original design: the Marketplace stays recognisable
  /// in both themes instead of silently switching to the app's primary.
  final Color accent;

  /// Page background behind the header and the shelves.
  final Color background;

  /// Card and chip surface.
  final Color surface;

  /// Slightly raised surface: search field, sheet headers.
  final Color surfaceHigh;

  /// Secondary text and icons.
  final Color muted;

  /// Hairline used for card and field borders.
  final Color border;

  /// Primary text.
  final Color text;

  const MarketplacePalette({
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.muted,
    required this.border,
    required this.text,
  });

  static const Color _accent = Color(0xFF8ED081);

  factory MarketplacePalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MarketplacePalette(
      accent: _accent,
      background: Theme.of(context).scaffoldBackgroundColor,
      surface: dark ? const Color(0xFF1B1B1D) : scheme.surfaceContainerLow,
      surfaceHigh: dark
          ? const Color(0xFF252527)
          : scheme.surfaceContainerHighest,
      muted: dark ? const Color(0xFFB9B8BE) : scheme.onSurfaceVariant,
      border: dark
          ? const Color(0xFF353539)
          : scheme.outlineVariant.withValues(alpha: 0.5),
      text: scheme.onSurface,
    );
  }
}
