import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:watchtower/services/device_capabilities.dart';

/// Every tunable of the onboarding showcase in one place.
///
/// The showcase used to hard-code its geometry and its card counts, so a
/// tablet showed three narrow columns in the middle of a wide screen and a
/// low-RAM phone rendered the same 450 poster cards as a flagship. Both the
/// lane geometry and the amount of work per frame are derived here instead.
class OnboardingShowcaseConfig {
  OnboardingShowcaseConfig._();

  // ── Timing ───────────────────────────────────────────────────────────────

  /// How long a lane takes to travel its own height once.
  static const Duration laneCycle = Duration(seconds: 18);
  static const Duration sloganCycle = Duration(seconds: 28);

  /// How often the visible window of lanes slides by one lane.
  static const Duration windowRotate = Duration(seconds: 5);
  static const Duration windowSwitch = Duration(milliseconds: 600);

  // ── Card geometry ────────────────────────────────────────────────────────

  static const double cardGap = 10;
  static const double cardRadius = 12;
  static const double lanePadding = 4;
  static const double sloganCardGap = 6;

  /// A card never gets narrower than this, or its title becomes unreadable.
  static const double minCardWidth = 96;

  /// …and never wider, or the poster turns into a landscape slab.
  static const double maxCardWidth = 168;

  /// Poster aspect ratio (2:3) drives the card height from its width.
  static const double cardAspect = 2 / 3;

  static const double minCardHeight = 132;
  static const double maxCardHeight = 232;

  /// Screens wider than this keep the lanes centred instead of stretching
  /// three columns across a desktop window.
  static const double maxContentWidth = 1100;

  // ── Work limits ──────────────────────────────────────────────────────────

  /// Cards built per lane copy. The lane duplicates its column to scroll
  /// seamlessly, so the real cost is twice this number, times the lane count.
  static const int itemsPerLaneDesktop = 8;
  static const int itemsPerLaneMobile = 7;

  /// Total cards the slogan page is allowed to build, across every lane copy.
  ///
  /// The slogan rotates the whole pool diagonally behind the text, where the
  /// cards are decorative and mostly covered by the overlay. Capping the pool
  /// is what keeps that page from dropping frames on a phone.
  static const int sloganCardBudget = 96;

  // ── Layout ───────────────────────────────────────────────────────────────

  /// How many lane columns fit on a screen of [width] logical pixels.
  static int laneCountFor(double width) {
    if (width < 380) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }

  /// Width of one lane, clamped so posters stay poster-shaped on any screen.
  ///
  /// On a narrow phone the lanes fill the width; on a desktop the width stops
  /// growing at [maxCardWidth] and [contentWidthFor] centres the block.
  static double laneWidthFor(double width) {
    final lanes = laneCountFor(width);
    final raw = width / lanes;
    return raw.clamp(minCardWidth, maxCardWidth);
  }

  /// Width actually occupied by the lane block, never wider than the screen.
  static double contentWidthFor(double width) {
    final lanes = laneCountFor(width);
    return math.min(width, laneWidthFor(width) * lanes);
  }

  /// Card height for a lane of [laneWidth], derived from the poster ratio.
  static double cardHeightFor(double laneWidth) {
    final w = laneWidth - 2 * lanePadding;
    return (w / cardAspect).clamp(minCardHeight, maxCardHeight);
  }

  /// Lane count for the diagonal slogan backdrop.
  ///
  /// Fewer lanes than the showcase: the block is rotated and over-scaled, so
  /// extra lanes cost cards nobody sees.
  static int sloganLaneCountFor(double width) {
    if (width < 380) return 3;
    if (width < 900) return 4;
    return 5;
  }

  /// Items each slogan lane may show, so the page stays inside
  /// [sloganCardBudget] cards no matter how many lanes are on screen.
  static int sloganItemsPerLaneFor(double width) {
    final lanes = sloganLaneCountFor(width);
    // Two copies per lane, so half the budget goes to each lane's own column.
    return math.max(4, sloganCardBudget ~/ (lanes * 2));
  }

  /// Cards per lane copy, trimmed on constrained devices.
  ///
  /// [ramTier] is [DeviceRamTier]; a low-RAM phone builds fewer cards rather
  /// than the same scene as a flagship.
  static int itemsPerLaneFor(DeviceRamTier ramTier) =>
      ramTier == DeviceRamTier.low ? itemsPerLaneMobile : itemsPerLaneDesktop;

  /// Whether a shadow may be painted behind the cards.
  ///
  /// The blur is the single most expensive part of a card, and the showcase
  /// stacks dozens of them. It is dropped where it costs frames and is
  /// invisible anyway (behind the gradient vignette on the slogan page).
  static bool shadowsEnabled({
    required bool ramConstrained,
    required bool covered,
  }) => !ramConstrained && !covered;
}

/// How much memory the device has, as far as the showcase cares.
///
/// A local enum keeps the layout maths independent of `DeviceCapabilities`
/// state, while [deviceRamTierFromMB] reuses its thresholds so the two never
/// disagree about a device.
enum DeviceRamTier { low, mid, high }

/// Maps a physical memory reading to a showcase tier.
///
/// A reading of `0` means "unknown" (desktop, web, or a failed channel call)
/// and is treated as [DeviceRamTier.high]: those platforms are not the ones
/// the showcase needs to protect. The app's own tier treats `0` as `mid`
/// because it applies to a different decision (cache sizing), so the unknown
/// case is handled here rather than delegated.
DeviceRamTier deviceRamTierFromMB(int physicalMemoryMB) {
  if (physicalMemoryMB <= 0) return DeviceRamTier.high;
  return switch (DeviceCapabilities.ramTierForMB(physicalMemoryMB)) {
    'low' => DeviceRamTier.low,
    'mid' => DeviceRamTier.mid,
    _ => DeviceRamTier.high,
  };
}

/// Whether motion should be suppressed, honouring the platform's
/// "reduce motion" accessibility setting.
bool showcaseMotionDisabled(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
