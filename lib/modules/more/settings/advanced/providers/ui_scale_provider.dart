import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// UI scale (zoom) shared by the Advanced Settings slider and the desktop
/// Ctrl+wheel gesture.
///
/// The value used to live only in the `advanced_settings` Hive box and was read
/// once when `MaterialApp.router` was built, so changing it needed a restart and
/// the wheel could not touch it. Exposing it as a provider makes the whole tree
/// rebuild the moment it changes, which is what makes live zoom possible.
const _kBox = 'advanced_settings';
const kUiScaleKey = 'ui_scale';

/// Zoom limits. 100% is the design size; the range matches the settings slider.
const double kMinUiScale = 0.75;
const double kMaxUiScale = 1.50;

/// Step applied by one wheel notch / one button press.
const double kUiScaleStep = 0.05;

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

class UiScaleNotifier extends Notifier<double> {
  @override
  double build() {
    final raw = _box?.get(kUiScaleKey, defaultValue: 1.0);
    final value = raw is num ? raw.toDouble() : 1.0;
    return value.clamp(kMinUiScale, kMaxUiScale);
  }

  void set(double value) {
    final clamped = value.clamp(kMinUiScale, kMaxUiScale);
    _box?.put(kUiScaleKey, clamped);
    state = clamped;
  }

  /// Moves the scale by [notches] steps, clamped to the allowed range.
  void step(double notches) => set(state + notches * kUiScaleStep);

  void reset() => set(1.0);
}

final uiScaleProvider = NotifierProvider<UiScaleNotifier, double>(
  UiScaleNotifier.new,
);

/// Wraps [child] with the current UI scale applied as a text/UI scale factor.
///
/// Uses `MediaQuery.textScaler`, which scales text and every spacing derived
/// from text metrics without re-laying out fixed-size boxes, so the layout does
/// not break at 150%.
class UiScaleScope extends ConsumerWidget {
  const UiScaleScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(uiScaleProvider);
    if (scale == 1.0) return child;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}
