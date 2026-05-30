/// Web stub for shorebird_code_push — Shorebird is Android/iOS only.
/// This file is selected by the conditional import in main.dart when
/// `dart.library.js_interop` is available (i.e. on web / dart2js).

enum UpdateStatus { upToDate, outdated, restartRequired, unavailable }

class ShorebirdUpdater {
  Future<UpdateStatus> checkForUpdate() async => UpdateStatus.unavailable;
  Future<void> update() async {}
}
