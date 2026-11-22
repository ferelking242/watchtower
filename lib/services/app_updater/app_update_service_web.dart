/// Web build of [AppUpdateService].
///
/// `app_updater` reads files from disk and installs native packages, so it is
/// not compiled for the web target. This stub keeps the same surface so the
/// About screen and the startup hook build unchanged; every call is a no-op.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  Future<bool> isAutoUpdateEnabled() async => false;

  Future<void> setAutoUpdateEnabled(bool enabled) async {}

  Future<void> checkOnLaunch() async {}

  Future<void> checkNow() async {}

  Future<void> checkAndDownload() async {}

  Future<bool> installPending() async => false;

  Future<void> dispose() async {}
}
