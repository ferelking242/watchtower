
import 'dart:async';
class VolumeController {
  static final VolumeController instance = VolumeController._();
  VolumeController._();
  double _vol = 0.5;
  Future<double> getVolume() async => _vol;
  Future<void> setVolume(double v, {bool showSystemUI = false}) async { _vol = v; }
  StreamSubscription<double>? addListener(void Function(double) cb, {bool fetchInitialVolume = true}) {
    if (fetchInitialVolume) cb(_vol);
    return null;
  }
  void removeListener() {}
  void dispose() {}
}
