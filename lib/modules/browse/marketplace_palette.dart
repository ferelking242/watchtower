import 'package:flutter/material.dart';
import 'package:watchtower/models/manga.dart';

/// Every colour the Marketplace paints with.
///
/// The Marketplace used to scatter its own dark constants across
/// `marketplace_screen.dart` and `catalog_widgets.dart` (`#101010`, `#1B1B1D`,
/// `#252527`, `#353539`, `Colors.white`…). A user on the light theme got a black
/// page with white text, and no widget could be themed without hunting for
/// literals.
///
/// Dark keeps the original look, because the Marketplace identity is its own
/// near-black surface rather than the app's scheme. Light derives from the
/// active [ColorScheme]. Widgets read this object and never a literal.
@immutable
class MarketplacePalette {
  /// Which theme these colours were derived from.
  final Brightness brightness;

  /// Accent kept from the original design: the Marketplace stays recognisable
  /// in both themes instead of silently switching to the app's primary.
  final Color accent;

  /// Second accent, used for the "new" state and the tab header highlight.
  final Color accentCyan;

  /// Text and icons drawn on top of [accent] or [accentCyan].
  final Color onAccent;

  /// Page background behind the header and the shelves.
  final Color background;

  /// Card and chip surface.
  final Color surface;

  /// Slightly raised surface: search field, sheet headers.
  final Color surfaceHigh;

  /// Raised again: icon buttons sitting on a card.
  final Color surfaceHighest;

  /// Fill of a disabled button.
  final Color disabledSurface;

  /// Label of a disabled button.
  final Color disabledText;

  /// Secondary text and icons.
  final Color muted;

  /// Hairline used for card and field borders.
  final Color border;

  /// Primary text.
  final Color text;

  /// Avatar disc behind the account icon.
  final Color avatar;

  /// Rating stars.
  final Color star;

  /// Badge background for an alerting count (update bubble).
  final Color alertSurface;

  /// Label on [alertSurface].
  final Color onAlertSurface;

  /// Top-left stop of the featured banner gradient.
  final Color heroStart;

  /// Bottom-right stop of the featured banner gradient.
  final Color heroEnd;

  /// Text colours on the featured banner.
  final Color heroTitle;
  final Color heroSubtitle;
  final Color heroLabel;

  /// Shimmer placeholders shown while a shelf loads.
  final Color skeletonBase;
  final Color skeletonHighlight;

  const MarketplacePalette({
    required this.brightness,
    required this.accent,
    required this.accentCyan,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.disabledSurface,
    required this.disabledText,
    required this.muted,
    required this.border,
    required this.text,
    required this.avatar,
    required this.star,
    required this.alertSurface,
    required this.onAlertSurface,
    required this.heroStart,
    required this.heroEnd,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroLabel,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// Whether these colours describe the dark theme.
  bool get isDark => brightness == Brightness.dark;

  // Dark identity. The Marketplace is deliberately its own near-black surface,
  // independent of the app's scheme, so these stay fixed in the dark theme.
  static const Color _darkAccent = Color(0xFF8ED081);
  static const Color _darkAccentCyan = Color(0xFFB7F4F0);
  static const Color _darkSurface = Color(0xFF1B1B1D);
  static const Color _darkSurfaceHigh = Color(0xFF252527);
  static const Color _darkSurfaceHighest = Color(0xFF343438);
  static const Color _darkDisabledSurface = Color(0xFF3B3B3D);
  static const Color _darkDisabledText = Color(0xFFB0B0B3);
  static const Color _darkMuted = Color(0xFFB9B8BE);
  static const Color _darkBorder = Color(0xFF353539);
  static const Color _darkAvatar = Color(0xFF3B4D58);
  static const Color _darkAlertSurface = Color(0xFFFFB4AB);
  static const Color _darkOnAlertSurface = Color(0xFF4A0806);
  static const Color _darkHeroStart = Color(0xFF254D44);
  static const Color _darkHeroEnd = Color(0xFF121C29);
  static const Color _darkHeroAltStart = Color(0xFF39456B);
  static const Color _darkHeroAltEnd = Color(0xFF201D35);
  static const Color _darkHeroLabel = Color(0xFFD8EEDB);
  static const Color _darkHeroSubtitle = Color(0xFFE0E6E4);
  static const Color _darkSkeletonBase = Color(0xFF252527);
  static const Color _darkSkeletonHighlight = Color(0xFF3A3A3E);

  static const Color _star = Color(0xFFFFC107);

  /// Light counterpart of the dark banner gradient: the same teal-to-indigo
  /// identity, without turning the card into a black slab.
  static const Color _lightHeroStart = Color(0xFFD3ECE3);
  static const Color _lightHeroEnd = Color(0xFFE4E8F5);
  static const Color _lightHeroLabel = Color(0xFF2C5A50);
  static const Color _lightHeroSubtitle = Color(0xFF3A4258);

  factory MarketplacePalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return MarketplacePalette(
      brightness: theme.brightness,
      accent: _darkAccent,
      accentCyan: dark ? _darkAccentCyan : scheme.primary,
      // The accent fills are pale greens and cyans, so the label on top stays
      // dark in both themes.
      onAccent: dark ? Colors.black : scheme.onPrimary,
      background: theme.scaffoldBackgroundColor,
      surface: dark ? _darkSurface : scheme.surfaceContainerLow,
      surfaceHigh: dark ? _darkSurfaceHigh : scheme.surfaceContainerHighest,
      surfaceHighest: dark ? _darkSurfaceHighest : scheme.surfaceContainerHigh,
      disabledSurface: dark
          ? _darkDisabledSurface
          : scheme.surfaceContainerHigh,
      disabledText: dark ? _darkDisabledText : scheme.onSurfaceVariant,
      muted: dark ? _darkMuted : scheme.onSurfaceVariant,
      border: dark ? _darkBorder : scheme.outlineVariant.withValues(alpha: 0.5),
      text: scheme.onSurface,
      avatar: dark ? _darkAvatar : scheme.primaryContainer,
      star: dark ? _star : const Color(0xFFB8860B),
      alertSurface: dark ? _darkAlertSurface : scheme.errorContainer,
      onAlertSurface: dark ? _darkOnAlertSurface : scheme.onErrorContainer,
      heroStart: dark ? _darkHeroStart : _lightHeroStart,
      heroEnd: dark ? _darkHeroEnd : _lightHeroEnd,
      heroTitle: dark ? Colors.white : scheme.onSurface,
      heroSubtitle: dark ? _darkHeroSubtitle : _lightHeroSubtitle,
      heroLabel: dark ? _darkHeroLabel : _lightHeroLabel,
      skeletonBase: dark ? _darkSkeletonBase : scheme.surfaceContainerHighest,
      skeletonHighlight: dark
          ? _darkSkeletonHighlight
          : scheme.surfaceContainerHigh,
    );
  }

  /// Alternate featured-banner gradient, so consecutive banners differ.
  (Color, Color) get heroAlt => isDark
      ? (_darkHeroAltStart, _darkHeroAltEnd)
      : (_lightHeroEnd, _lightHeroStart);

  /// The five discovery accents, one per content type. Kept on the palette so
  /// the category grid, the card captions and the tab icons cannot drift apart.
  List<Color> get typeAccents => isDark
      ? const [
          Color(0xFF65C58A),
          Color(0xFFEF6C92),
          Color(0xFFE6B65C),
          Color(0xFFC388EF),
          Color(0xFF63B8DA),
        ]
      : [
          _darkAccent,
          _lightAccent(const Color(0xFFEF6C92)),
          _lightAccent(const Color(0xFFE6B65C)),
          _lightAccent(const Color(0xFFC388EF)),
          _lightAccent(const Color(0xFF63B8DA)),
        ];

  /// Colour used for a content type's caption and icon.
  Color typeColor(ItemType type) => switch (type) {
    ItemType.anime => typeAccents[0],
    ItemType.manga => typeAccents[1],
    ItemType.novel => typeAccents[4],
    ItemType.music => typeAccents[2],
    ItemType.game => typeAccents[3],
    _ => typeAccents[0],
  };

  /// Darkens a discovery accent so it stays legible on a light surface while
  /// keeping the hue the dark theme uses.
  static Color _lightAccent(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.78), const Color(0xFF000000));
}
