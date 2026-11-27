import 'package:watchtower/services/app_updater/update_models.dart';

/// Web build of `AppUpdateService`.
///
/// `app_updater` reads files from disk and installs native packages, so it is
/// not compiled for the web target. This stub keeps the same surface so the
/// About screen and the startup hook build unchanged; every call is a no-op.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  Future<bool> isAutoUpdateEnabled() async => false;

  Future<void> setAutoUpdateEnabled(bool enabled) async {}

  String? get lastPhaseName => null;

  /// Last known state, mirroring the io implementation. The update
  /// notification no longer compiles without it on the web target.
  UpdateInfoView get current =>
      const UpdateInfoView(currentVersion: '', phase: 'upToDate');

  Stream<UpdateInfoView> get updates => const Stream<UpdateInfoView>.empty();

  Future<void> checkOnLaunch() async {}

  Future<UpdateInfoView> checkNow() async =>
      const UpdateInfoView(currentVersion: '', phase: 'upToDate');

  Future<UpdateInfoView> downloadNow() async =>
      const UpdateInfoView(currentVersion: '', phase: 'failed');

  Future<bool> installNow() async => false;

  Future<void> checkAndAnnounce() async {}

  Future<bool> installPending() async => false;

  Future<void> clearPending() async {}

  Future<List<UpdateHistoryEntry>> history({int limit = 10}) async => const [];

  Future<void> dispose() async {}
}
