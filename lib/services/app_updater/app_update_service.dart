import 'dart:async';
import 'dart:io';

import 'package:app_updater/app_updater.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/core/config/app_config.dart';
import 'package:watchtower/services/silent_installer_service.dart';
import 'package:watchtower/services/update_notification_service.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Bridges `app_updater` with Watchtower's notification and install services.
///
/// The package decides when a build exists, when to download it and when to
/// install it. Watchtower keeps ownership of the platform bits: the Android
/// notification with its "Installer" action and the APK intent.
class WatchtowerUpdateNotifier implements UpdateNotifier {
  const WatchtowerUpdateNotifier();

  WatchtowerNotificationService get _notifications =>
      WatchtowerNotificationService.instance;

  /// The background flow always continues with a download, so announcing the
  /// version separately would produce two competing notifications.
  @override
  Future<void> showUpdateAvailable(UpdateState state) async {}

  @override
  Future<void> showDownloadProgress(UpdateState state) async {
    final total = state.info?.updateSizeBytes ?? 0;
    final progress = state.progress ?? 0;
    if (total > 0) {
      await _notifications.showDownloadProgress(
        (progress * total).round(),
        total,
      );
    } else {
      await _notifications.showDownloadProgress(
        (progress * 100).round(),
        100,
      );
    }
  }

  @override
  Future<void> showReadyToInstall(UpdateState state) async {
    final prepared = state.prepared;
    if (prepared == null) return;
    await _notifications.showDownloadComplete(
      version: prepared.version,
      filePath: prepared.file.path,
    );
  }

  @override
  Future<void> cancel() => _notifications.cancelUpdateNotification();

  @override
  Future<void> showError(UpdateState state) async {
    AppLogger.log(
      'app_updater: ${state.error}',
      logLevel: LogLevel.warning,
      tag: LogTag.network,
    );
  }
}

/// Installs the downloaded APK, silently when a privileged installer is set up.
class WatchtowerUpdateInstaller implements UpdateInstaller {
  static const _channel = MethodChannel('com.watchtower.app.apk_install');

  @override
  Future<bool> canInstallInBackground() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await SilentInstallerService.instance.checkStatus();
      return status == SilentInstallStatus.active;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> install(PreparedUpdate update) async {
    if (!Platform.isAndroid) return false;
    try {
      if (await canInstallInBackground()) {
        return await SilentInstallerService.instance.installFile(
          update.file.path,
        );
      }
      await _channel.invokeMethod('installApk', {'filePath': update.file.path});
      return true;
    } catch (e) {
      AppLogger.log(
        'app_updater install failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return false;
    }
  }
}

/// Watchtower's entry point to `app_updater`.
///
/// Sources, in order: the app_updater CI feed (when the build embeds
/// `APP_UPDATER_URL`), GitHub Actions artifacts (only with a token) and GitHub
/// Releases. The newest version wins, and a failing source is ignored.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _owner = 'ferelking242';
  static const String _repo = 'watchtower';

  /// Set by CI (`--dart-define=APP_UPDATER_URL=...`) when the build was
  /// published to an app_updater server. Empty for plain builds.
  static const String _ciFeedUrl = String.fromEnvironment('APP_UPDATER_URL');
  static const String _ciFeedToken =
      String.fromEnvironment('APP_UPDATER_TOKEN');

  AppUpdateController? _controller;
  bool _launchChecked = false;

  AppUpdateController get controller => _controller ??= _buildController();

  String? get _token =>
      AppConfig.githubToken.isEmpty ? null : AppConfig.githubToken;

  AppUpdateController _buildController() {
    final controller = AppUpdateController(
      source: CompositeUpdateSource([
        // The CI feed is the fastest path: the build is announced as soon as
        // it is green, with the exact version it was compiled with.
        if (_ciFeedUrl.isNotEmpty)
          CiFeedSource(
            endpoint: Uri.parse(_ciFeedUrl),
            appId: _repo,
            token: _ciFeedToken.isEmpty ? null : _ciFeedToken,
          ),
        // GitHub refuses anonymous artifact downloads, so this source only
        // runs when the build embeds a read token.
        if (_token != null)
          GitHubArtifactsSource(
            owner: _owner,
            repo: _repo,
            workflow: 'build-release.yml',
            branch: 'main',
            token: _token,
          ),
        // The rolling `android-latest` release is a prerelease and carries the
        // version in the asset name, so prereleases must be considered here.
        GitHubReleasesSource(
          owner: _owner,
          repo: _repo,
          token: _token,
          includePrereleases: true,
        ),
      ]),
      notifier: const WatchtowerUpdateNotifier(),
      installer: WatchtowerUpdateInstaller(),
      preferencesPrefix: 'watchtower',
      options: const AutoUpdateOptions(
        enabledByDefault: false,
        interval: Duration(hours: 6),
        downloadOnLaunch: true,
        installWhenReady: false,
        channel: 'stable',
      ),
    );
    controller.states.listen((state) {
      if (state.phase == UpdatePhase.failed && state.error != null) {
        AppLogger.log(
          'app_updater state failed: ${state.error}',
          logLevel: LogLevel.warning,
          tag: LogTag.network,
        );
      }
    });
    return controller;
  }

  Future<bool> isAutoUpdateEnabled() => controller.isAutoUpdateEnabled();

  Future<void> setAutoUpdateEnabled(bool enabled) =>
      controller.setAutoUpdateEnabled(enabled);

  /// Called once at startup. Does nothing while the switch is off.
  Future<void> checkOnLaunch() async {
    if (_launchChecked) return;
    _launchChecked = true;
    try {
      await controller.checkOnLaunch();
    } catch (e) {
      AppLogger.log(
        'app_updater launch check failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Checks immediately, bypassing the switch and the interval.
  Future<void> checkNow() async {
    await controller.check(manual: true, force: true);
  }

  /// Check + background download; the notifier posts the install action.
  Future<void> checkAndDownload() async {
    await controller.checkAndDownload(manual: true);
  }

  /// Installs the file downloaded by [checkAndDownload].
  Future<bool> installPending() => controller.install();

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
