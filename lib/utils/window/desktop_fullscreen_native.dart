import 'package:window_manager/window_manager.dart';

/// Toggles the desktop window fullscreen state.
///
/// Pass [value] to force a state; omit it to toggle. Returns the resulting
/// state. Shared by the manga and novel readers.
Future<bool> setFullScreen({bool? value}) async {
  if (value != null) {
    await windowManager.setFullScreen(value);
    return value;
  }
  final isFullScreen = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!isFullScreen);
  return !isFullScreen;
}
