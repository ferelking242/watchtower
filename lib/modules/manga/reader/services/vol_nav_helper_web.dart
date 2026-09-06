/// Web no-op stubs — volume_controller is not available on web.
Future<double> volNavInit() async => 0.5;
void volNavListenRaw(void Function(double) cb) {}
void volNavRestore(double vol) {}
void volNavDispose() {}
