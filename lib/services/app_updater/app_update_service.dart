import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_updater/app_updater.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/core/config/app_config.dart';
import 'package:watchtower/services/app_updater/update_models.dart';
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

  /// Name of the last [UpdatePhase], for the About screen. Null until the
  /// first check ran.
  String? get lastPhaseName => _controller?.state.phase.name;

  /// Every state change, mapped to the plain model used by the UI.
  Stream<UpdateInfoView> get updates => controller.states.map(_viewOf);

  UpdateInfoView _viewOf(UpdateState state) {
    final info = state.info;
    final candidate = state.candidate;
    return UpdateInfoView(
      currentVersion: info?.currentVersion ?? '',
      latestVersion: info?.latestVersion ?? candidate?.version,
      releaseNotes: info?.releaseNotes ?? candidate?.releaseNotes,
      sizeBytes: info?.updateSizeBytes ?? candidate?.artifactFor()?.sizeBytes,
      publishedAt: info?.releaseDate ?? candidate?.publishedAt,
      updateAvailable: state.updateAvailable,
      phase: state.phase.name,
      progress: state.progress,
      error: state.error,
    );
  }

  /// Checks immediately, bypassing the switch and the interval.
  Future<UpdateInfoView> checkNow() async {
    final state = await controller.check(manual: true, force: true);
    return _viewOf(state);
  }

  /// Downloads the candidate found by [checkNow] and reports progress on
  /// [updates].
  Future<UpdateInfoView> downloadNow() async {
    final state = await controller.download();
    return _viewOf(state);
  }

  /// Installs the downloaded build (silent when the platform allows it).
  Future<bool> installNow() => controller.install();

  /// Check + background download; the notifier posts the install action.
  Future<void> checkAndDownload() async {
    await controller.checkAndDownload(manual: true);
  }

  /// Installs the file downloaded by [checkAndDownload].
  Future<bool> installPending() => controller.install();

  /// Recent releases, newest first, for the history section.
  Future<List<UpdateHistoryEntry>> history({int limit = 10}) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/releases?per_page=$limit',
    );
    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode != 200) return const [];
      final releases = jsonDecode(response.body);
      if (releases is! List) return const [];

      final installed = await controller.currentVersion();
      final entries = <UpdateHistoryEntry>[];
      for (final raw in releases.whereType<Map>()) {
        final release = raw.cast<String, dynamic>();
        if (release['draft'] == true) continue;
        final version = _releaseVersion(release);
        if (version == null) continue;
        entries.add(
          UpdateHistoryEntry(
            version: version,
            publishedAt:
                DateTime.tryParse(release['published_at']?.toString() ?? ''),
            notes: release['body']?.toString(),
            isCurrent: VersionUtils.compare(version, installed) == 0,
          ),
        );
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// Version of a release: from its tag, else from its asset names
  /// (`android-latest` carries the version in the APK name).
  static String? _releaseVersion(Map<String, dynamic> release) {
    final fromTag = VersionUtils.normalize(release['tag_name']?.toString());
    if (fromTag != null) return fromTag;
    final assets = (release['assets'] as List?) ?? const [];
    for (final asset in assets.whereType<Map>()) {
      final version = VersionUtils.normalize(asset['name']?.toString());
      if (version != null) return version;
    }
    return null;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
