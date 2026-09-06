
import 'dart:async';
class ScreenBrightness {
  static final ScreenBrightness instance = ScreenBrightness._();
  ScreenBrightness._();
  Future<double> get application async => 0.5;
  Future<double> get system async => 0.5;
  Future<void> setApplicationScreenBrightness(double v) async {}
  Future<void> resetApplicationScreenBrightness() async {}
  Stream<double> get onApplicationScreenBrightnessChanged => const Stream.empty();
  Stream<double> get onSystemScreenBrightnessChanged => const Stream.empty();
}
