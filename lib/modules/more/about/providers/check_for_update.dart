import 'dart:convert';
import 'dart:developer';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/about/providers/download_file_screen.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'check_for_update.g.dart';

@riverpod
Future<void> checkForUpdate(
  Ref ref, {
  BuildContext? context,
  bool? manualUpdate,
}) async {
  manualUpdate = manualUpdate ?? false;
  final checkForUpdates = ref.watch(checkForAppUpdatesProvider);
  if (!checkForUpdates && !manualUpdate) return;
  final l10n = l10nLocalizations(context!)!;

  if (manualUpdate) {
    botToast(l10n.searching_for_updates);
  }
  final info = await PackageInfo.fromPlatform();
  if (kDebugMode) {
    log(info.data.toString());
  }
  // Manual update bypasses the cache so the user always gets the freshest
  // answer; automatic background checks honour the cache to avoid spam.
  final updateAvailable = await _checkUpdate(forceRefresh: manualUpdate);

  // Sentinel '0.0.0' = no releases found or error → treat as up to date
  if (updateAvailable.$1 == '0.0.0' || updateAvailable.$1.isEmpty) {
    if (manualUpdate) {
      botToast(l10n.no_new_updates_available);
    }
    return;
  }

  if (compareVersions(info.version, updateAvailable.$1) < 0) {
    if (manualUpdate) {
      botToast(l10n.new_update_available);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return DownloadFileScreen(updateAvailable: updateAvailable);
        },
      );
    }
  } else {
    if (manualUpdate) {
      botToast(l10n.no_new_updates_available);
    }
  }
}

@riverpod
bool checkForAppUpdates(Ref ref) {
  return isar.settings.getSync(227)?.checkForAppUpdates ?? true;
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
Future<(String, String, String, List<dynamic>)>? _appUpdateInflight;

Future<(String, String, String, List<dynamic>)> _checkUpdate({
  bool forceRefresh = false,
}) async {
  final now = DateTime.now();
  if (!forceRefresh &&
      _appUpdateCache != null &&
      _appUpdateCachedAt != null &&
      now.difference(_appUpdateCachedAt!) < _appUpdateCacheTtl) {
    return _appUpdateCache!;
  }
  if (_appUpdateInflight != null) return _appUpdateInflight!;

  _appUpdateInflight = _fetchAppUpdate();
  try {
    final result = await _appUpdateInflight!;
    _appUpdateCache = result;
    _appUpdateCachedAt = DateTime.now();
    return result;
  } finally {
    _appUpdateInflight = null;
  }
}

Future<(String, String, String, List<dynamic>)> _fetchAppUpdate() async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  try {
    final res = await http.get(
      Uri.parse(
        "https://api.github.com/repos/ferelking242/watchtower/releases?page=1&per_page=10",
      ),
    );
    List resListJson = jsonDecode(res.body) as List;
    // No releases published yet → treat as up to date
    if (resListJson.isEmpty) {
      return ('0.0.0', '', '', []);
    }
    return (
      resListJson.first["name"]
          .toString()
          .substringAfter('v')
          .substringBefore('-'),
      resListJson.first["body"].toString(),
      resListJson.first["html_url"].toString(),
      (resListJson.first["assets"] as List)
          .map((asset) => asset["browser_download_url"])
          .toList(),
    );
  } catch (e, st) {
    AppLogger.log(
      'checkForUpdate fetch failed: $e\n$st',
      logLevel: LogLevel.warning,
      tag: LogTag.network,
    );
    // Surface the previous successful answer when available so the UI
    // doesn't oscillate between "update available" and "up to date" on
    // transient network blips.
    return _appUpdateCache ?? ('0.0.0', '', '', []);
  }
}
