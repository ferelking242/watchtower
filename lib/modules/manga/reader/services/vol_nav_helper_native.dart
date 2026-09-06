import 'package:volume_controller/volume_controller.dart';

/// Initialises VolumeController: captures current volume and hides system UI.
Future<double> volNavInit() async {
  final vol = await VolumeController.instance.getVolume();
  try {
    VolumeController.instance.showSystemUI = false;
  } catch (_) {}
  return vol;
}

/// Registers a listener called with (newVolume, previousVolume) on every key event.
void volNavListen(void Function(double newVol, double prevVol) cb) {
  VolumeController.instance.addListener(
    (newVol) => cb(newVol, newVol), // prev injected by caller via _lastVolume
    fetchInitialVolume: false,
  );
}

/// Registers a listener called with the raw new volume (caller tracks prev).
void volNavListenRaw(void Function(double newVol) cb) {
  VolumeController.instance.addListener(cb, fetchInitialVolume: false);
}

/// Restores volume to [vol] without showing the system UI overlay.
void volNavRestore(double vol) {
  try {
    VolumeController.instance.setVolume(vol.clamp(0.0, 1.0));
  } catch (_) {}
}

/// Tears down the listener and restores system volume UI.
void volNavDispose() {
  try {
    VolumeController.instance.removeListener();
    VolumeController.instance.showSystemUI = true;
  } catch (_) {}
}
