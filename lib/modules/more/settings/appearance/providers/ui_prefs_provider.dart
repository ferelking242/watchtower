import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _kBox = 'ui_prefs';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

// ── Nav-bar blur (translucent bar) ────────────────────────────────────────────

class NavBarBlurNotifier extends Notifier<bool> {
  @override
  bool build() =>
      _box?.get('navbar_blur', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('navbar_blur', v);
    state = v;
  }
}

final navBarBlurProvider =
    NotifierProvider<NavBarBlurNotifier, bool>(NavBarBlurNotifier.new);

// ── Header scroll blur ────────────────────────────────────────────────────────

class HeaderBlurNotifier extends Notifier<bool> {
  @override
  bool build() =>
      _box?.get('header_blur', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('header_blur', v);
    state = v;
  }
}

final headerBlurProvider =
    NotifierProvider<HeaderBlurNotifier, bool>(HeaderBlurNotifier.new);

// ── Bottom sheet blur ─────────────────────────────────────────────────────────

class BottomSheetBlurNotifier extends Notifier<bool> {
  @override
  bool build() =>
      _box?.get('bottom_sheet_blur', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('bottom_sheet_blur', v);
    state = v;
  }
}

final bottomSheetBlurProvider =
    NotifierProvider<BottomSheetBlurNotifier, bool>(BottomSheetBlurNotifier.new);

// ── Blur intensity multiplier (0.5 → 2.0) ────────────────────────────────────

class BlurIntensityNotifier extends Notifier<double> {
  @override
  double build() =>
      (_box?.get('blur_intensity', defaultValue: 1.0) as num?)?.toDouble() ??
      1.0;

  void set(double v) {
    final clamped = v.clamp(0.2, 2.0);
    _box?.put('blur_intensity', clamped);
    state = clamped;
  }
}

final blurIntensityProvider =
    NotifierProvider<BlurIntensityNotifier, double>(BlurIntensityNotifier.new);

// ── Carousel Style ────────────────────────────────────────────────────────────
// 0 = classic (cards scale), 1 = cinematic (full width), 2 = compact

class CarouselStyleNotifier extends Notifier<int> {
  @override
  int build() => (_box?.get('carousel_style', defaultValue: 0) as num?)?.toInt() ?? 0;

  void set(int v) {
    _box?.put('carousel_style', v);
    state = v;
  }
}

final carouselStyleProvider = NotifierProvider<CarouselStyleNotifier, int>(
  CarouselStyleNotifier.new,
);

const carouselStyleLabels = ['Classic', 'Cinematic', 'Compact'];

// ── Card Style ────────────────────────────────────────────────────────────────
// 0 = standard, 1 = modern (rounded), 2 = blur

class CardStyleNotifier extends Notifier<int> {
  @override
  int build() => (_box?.get('card_style', defaultValue: 0) as num?)?.toInt() ?? 0;

  void set(int v) {
    _box?.put('card_style', v);
    state = v;
  }
}

final cardStyleProvider = NotifierProvider<CardStyleNotifier, int>(
  CardStyleNotifier.new,
);

const cardStyleLabels = ['Standard', 'Modern', 'Blur'];

// ── Glow Effects ──────────────────────────────────────────────────────────────

class GlowEffectsNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('glow_effects', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('glow_effects', v);
    state = v;
  }
}

final glowEffectsProvider = NotifierProvider<GlowEffectsNotifier, bool>(
  GlowEffectsNotifier.new,
);

// ── Carousel Synopsis ─────────────────────────────────────────────────────────

class CarouselSynopsisNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('carousel_synopsis', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('carousel_synopsis', v);
    state = v;
  }
}

final carouselSynopsisProvider = NotifierProvider<CarouselSynopsisNotifier, bool>(
  CarouselSynopsisNotifier.new,
);

// ── Detail Ken Burns ──────────────────────────────────────────────────────────

class KenBurnsNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('ken_burns', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('ken_burns', v);
    state = v;
  }
}

final kenBurnsProvider = NotifierProvider<KenBurnsNotifier, bool>(
  KenBurnsNotifier.new,
);

  // ── Page Transition Style ─────────────────────────────────────────────────────
  // 0 = Fondu (FadeUpwards), 1 = Glissement (Cupertino), 2 = Échelle (Zoom), 3 = Aucun

  class PageTransitionStyleNotifier extends Notifier<int> {
    @override
    int build() =>
        (_box?.get('page_transition_style', defaultValue: 0) as num?)?.toInt() ?? 0;

    void set(int v) {
      _box?.put('page_transition_style', v);
      state = v;
    }
  }

  final pageTransitionStyleProvider =
      NotifierProvider<PageTransitionStyleNotifier, int>(PageTransitionStyleNotifier.new);

  const pageTransitionStyleLabels = ['Fondu', 'Glissement', 'Échelle', 'Aucun'];
  