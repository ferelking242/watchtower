import 'dart:developer' show log;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

  // Status of the silent-install feature
  enum SilentInstallStatus {
    unknown,           // not yet checked
    active,            // INSTALL_PACKAGES granted — fully operational
    shizukuRequired,   // Shizuku installed & running but permission not yet granted
    shizukuNotRunning, // Shizuku not running (or not installed)
  }

class SilentInstallerService {
  SilentInstallerService._();
  static final instance = SilentInstallerService._();

  static const _channel = MethodChannel('com.watchtower.app.silent_installer');

  // Persisted key — set to "true" once grantViaShizuku succeeds.
  static const _kConfigKey = 'silent_install_configured';

  // In-memory flag so checkStatus() is instant within the same session.
  static bool _grantedLocally = false;

  /// Returns the current setup status.
  /// Checks the persisted pref first so a successful past setup is remembered
  /// across app restarts without requiring Shizuku to be running.
  Future<SilentInstallStatus> checkStatus() async {
    try {
      if (_grantedLocally) return SilentInstallStatus.active;

      // Fast path: native permission check.
      final hasPerm = await _channel.invokeMethod<bool>('hasInstallPackagesPermission') ?? false;
      if (hasPerm) return SilentInstallStatus.active;

      // Fallback: if we stored a success flag in a previous session, return
      // active immediately (avoids repeatedly asking the user to reconfigure
      // when the native check glitches after an OS update).
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kConfigKey) == true) {
        _grantedLocally = true; // cache for this session
        return SilentInstallStatus.active;
      }

      final available = await _channel.invokeMethod<bool>('isShizukuAvailable') ?? false;
      if (!available) return SilentInstallStatus.shizukuNotRunning;

      return SilentInstallStatus.shizukuRequired;
    } catch (e) {
      log('SilentInstaller.checkStatus error: $e');
      return SilentInstallStatus.unknown;
    }
  }

  /// Full guided setup: request Shizuku permission, then grant INSTALL_PACKAGES.
  /// If the setup was already done in a previous session (pref flag set), shows
  /// an informational dialog instead of repeating the full flow.
  /// Returns true if now active.
  Future<bool> setupWithShizuku(BuildContext context) async {
    final status = await checkStatus();
    if (status == SilentInstallStatus.active) {
      // Already configured — show a friendly "already done" info dialog.
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.silent_install_active_title),
            content: Text(context.l10n.silent_install_active_body),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
      return true;
    }

    if (status == SilentInstallStatus.shizukuNotRunning) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.silent_install_shizuku_title),
            content: Text(context.l10n.silent_install_shizuku_body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
      return false;
    }

    // Shizuku is available — request permission + grant INSTALL_PACKAGES.
    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.l10n.silent_install_setup_title),
          content: Text(context.l10n.silent_install_setup_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.silent_install_continue),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }

    try {
      final permOk = await _channel.invokeMethod<bool>('requestShizukuPermission') ?? false;
      if (!permOk) return false;

      final granted = await _channel.invokeMethod<bool>('grantViaShizuku') ?? false;
      if (granted) {
        _grantedLocally = true;
        // Persist so that next session checkStatus() returns active immediately.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kConfigKey, true);
      }
      if (granted && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.silent_install_enabled_title),
            content: Text(context.l10n.silent_install_enabled_body),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.silent_install_understood),
              ),
            ],
          ),
        );
      }
      return granted;
    } catch (e) {
      log('SilentInstaller.setupWithShizuku error: $e');
      return false;
    }
  }

  /// Install an APK that has already been downloaded.
  Future<bool> installFile(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>('installApkSilent', {'path': path}) ?? false;
      return ok;
    } catch (e) {
      log('SilentInstaller.installFile error: $e');
      return false;
    }
  }

  /// Download [url] into cache and install silently.
  /// [onProgress] is called with 0.0–1.0 as download proceeds.
  Future<bool> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/watchtower_update.apk';
      final file = File(path);

      final client = http.Client();
      try {
        final req  = http.Request('GET', Uri.parse(url));
        final resp = await client.send(req);
        final total = resp.contentLength ?? 0;
        var received = 0;

        final sink = file.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.flush();
        await sink.close();
      } finally {
        client.close();
      }

      onProgress?.call(1.0);

      final ok = await _channel.invokeMethod<bool>('installApkSilent', {'path': path}) ?? false;
      return ok;
    } catch (e) {
      log('SilentInstaller.downloadAndInstall error: $e');
      return false;
    }
  }
}
  