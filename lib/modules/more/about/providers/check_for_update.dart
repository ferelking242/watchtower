import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:developer';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/about/update_page.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/app_updater/app_update_service.dart'
    if (dart.library.js_interop) 'package:watchtower/services/app_updater/app_update_service_web.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:github_release_apk_updater/github_release_apk_updater.dart';

part 'check_for_update.g.dart';

/// Repository owner and name for GitHub releases.
const _kOwner = 'ferelking242';
const _kRepo = 'watchtower';

@riverpod
Future<void> checkForUpdate(
  Ref ref, {
  BuildContext? context,
  bool? manualUpdate,
}) async {
  final manual = manualUpdate ?? false;
  final checkForUpdates = ref.read(checkForAppUpdatesProvider);
  if (!checkForUpdates && !manual) return;

  if (manual && context != null && context.mounted) {
    final l10n = l10nLocalizations(context);
    if (l10n != null) botToast(l10n.searching_for_updates);
  }

  // Single update pipeline: `app_updater` checks the CI feed, the artifacts
  // and the releases, and the update page handles download and install.
  final info = await AppUpdateService.instance.checkNow();
  pendingUpdateBanner = info.updateAvailable ? info.latestVersion : null;
  pendingUpdateData = info.updateAvailable
      ? (
          info.latestVersion ?? '',
          info.releaseNotes ?? '',
          info.releaseUrl ?? '',
          const <dynamic>[],
        )
      : null;

  if (!manual) return;
  if (context == null || !context.mounted) return;
  if (info.updateAvailable) {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => UpdatePage(initial: info),
      ),
    );
    return;
  }
  final l10n = l10nLocalizations(context);
  botToast(
    info.phase == 'upToDate'
        ? (l10n?.no_new_updates_available ?? 'Vous avez la dernière version')
        : 'Vérification impossible',
  );
}

@riverpod
bool checkForAppUpdates(Ref ref) {
  return isar.settings.getSync(kSettingsId)?.checkForAppUpdates ?? true;
}

// ── Skipped version ──────────────────────────────────────────────────────────
String? _skippedVersion;

// ── Pending update banner (read by menu overlay) ─────────────────────────────
/// The latest known update version string, or null if the app is up to date.
/// Set whenever an update is found; cleared when the version is skipped.
String? pendingUpdateBanner;

/// Full update payload for the pending update (so the menu overlay can open
/// the download screen directly without an extra network call).
(String, String, String, List<dynamic>)? pendingUpdateData;

/// Called by the update dialog when the user taps "Ignorer cette version".
void skipAppUpdate(String version) {
  _skippedVersion = version;
  pendingUpdateBanner = null;
  pendingUpdateData = null;
}

// ── Caching ──────────────────────────────────────────────────────────────────
//
// Automatic background calls used to hammer api.github.com on every
// rebuild of the About / Settings screens. Cache the result for 5 minutes
// to slash request volume and stay well under GitHub's 60-req/hour
// anonymous rate limit.
const Duration _appUpdateCacheTtl = Duration(minutes: 5);
(String, String, String, List<dynamic>)? _appUpdateCache;
DateTime? _appUpdateCachedAt;

/// Check for the latest release, using the cache when available.
/// Used by the download screen to refresh in the background.
Future<(String, String, String, List<dynamic>)> checkLatestRelease({
  bool forceRefresh = false,
}) async {
  final now = DateTime.now();
  if (!forceRefresh &&
      _appUpdateCache != null &&
      _appUpdateCachedAt != null &&
      now.difference(_appUpdateCachedAt!) < _appUpdateCacheTtl) {
    return _appUpdateCache!;
  }

  try {
    final updater = GithubReleaseApkUpdater();
    final apiService = GithubApiService();
    final supportedAbis = await updater.getSupportedAbis();
    final release = await apiService.getLatestGithubAPKRelease(
      ownerGithub: _kOwner,
      repositoryGithub: _kRepo,
      apkKeyName: '',
      supportedAbis: supportedAbis,
    );

    if (release == null) {
      final result = ('0.0.0', '', '', <String>[]);
      _appUpdateCache = result;
      _appUpdateCachedAt = DateTime.now();
      return result;
    }

    final result = (
      release.version,
      release.releaseNote,
      'https://github.com/ferelking242/watchtower/releases/tag/v${release.version}',
      <String>[release.apkUrl],
    );
    _appUpdateCache = result;
    _appUpdateCachedAt = DateTime.now();
    return result;
  } catch (e, st) {
    if (kDebugMode) {
      log('checkLatestRelease failed: $e\n$st');
    }
    // Surface previous cache to avoid oscillation
    return _appUpdateCache ?? ('0.0.0', '', '', <String>[]);
  }
}

// ── Pending install file ──────────────────────────────────────────────────────
/// Downloaded APK file path that is ready to install.
/// Set by the background download callback; cleared after install is triggered.
File? pendingInstallFile;

void setInstallReady(File file) {
  pendingInstallFile = file;
}

void clearInstallReady() {
  pendingInstallFile = null;
}
