import 'dart:ui';

export 'window_manager.dart';

mixin WindowListener {
  void onWindowClose() {}
  void onWindowFocus() {}
  void onWindowBlur() {}
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowMinimize() {}
  void onWindowRestore() {}
  void onWindowResize() {}
  void onWindowResized() {}
  void onWindowMove() {}
  void onWindowMoved() {}
  void onWindowEnterFullScreen() {}
  void onWindowLeaveFullScreen() {}
}

class WindowOptions {
  final Size? size;
  final bool center;
  final String? backgroundColor;
  final bool? skipTaskbar;
  final String? titleBarStyle;
  final bool? windowButtonVisibility;
  final String? title;
  const WindowOptions({
    this.size,
    this.center = false,
    this.backgroundColor,
    this.skipTaskbar,
    this.titleBarStyle,
    this.windowButtonVisibility,
    this.title,
  });
}

class _WindowManager {
  Future<void> ensureInitialized() async {}
  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
  Future<void> setSize(Size size) async {}
  Future<void> setPosition(Offset position) async {}
  Future<void> maximize() async {}
  Future<void> unmaximize() async {}
  Future<void> minimize() async {}
  Future<void> restore() async {}
  Future<void> setFullScreen(bool fullScreen) async {}
  Future<bool> isFullScreen() async => false;
  Future<void> waitUntilReadyToShow(
      [WindowOptions? options, Future<void> Function()? callback]) async {
    await callback?.call();
  }
  Future<Size> getSize() async => const Size(1280, 720);
  Future<Offset> getPosition() async => const Offset(0, 0);
  Future<bool> isMaximized() async => false;
  Future<void> setTitle(String title) async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}
  Future<bool> isAlwaysOnTop() async => false;
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> focus() async {}
  Future<void> blur() async {}
  Future<void> close() async {}
}

final windowManager = _WindowManager();
