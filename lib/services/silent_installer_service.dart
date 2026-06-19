import 'dart:developer' show log;
  import 'dart:io';

  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';

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

      // Local flag: set to true once grantViaShizuku succeeds so that checkStatus()
      // immediately returns active even before the OS propagates the permission.
      static bool _grantedLocally = false;

      /// Returns the current setup status.
    Future<SilentInstallStatus> checkStatus() async {
      try {
          if (_grantedLocally) return SilentInstallStatus.active;
          final hasPerm = await _channel.invokeMethod<bool>('hasInstallPackagesPermission') ?? false;
          if (hasPerm) return SilentInstallStatus.active;

        final available = await _channel.invokeMethod<bool>('isShizukuAvailable') ?? false;
        if (!available) return SilentInstallStatus.shizukuNotRunning;

        return SilentInstallStatus.shizukuRequired;
      } catch (e) {
        log('SilentInstaller.checkStatus error: $e');
        return SilentInstallStatus.unknown;
      }
    }

    /// Full guided setup: request Shizuku permission, then grant INSTALL_PACKAGES.
    /// Shows a dialog explaining each step.  Returns true if now active.
    Future<bool> setupWithShizuku(BuildContext context) async {
      final status = await checkStatus();
      if (status == SilentInstallStatus.active) return true;
      if (status == SilentInstallStatus.shizukuNotRunning) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Shizuku requis'),
              content: const Text(
                'Shizuku n\'est pas démarré.\n\n'
                '1. Installez Shizuku depuis le Play Store.\n'
                '2. Activez-le via le débogage sans fil (ADB).\n'
                '3. Revenez ici et appuyez à nouveau.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      // Shizuku is available — request permission + grant INSTALL_PACKAGES
      if (context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Configuration unique'),
            content: const Text(
              'Watchtower va demander la permission à Shizuku pour '
              's\'accorder le droit d\'installer des paquets.\n\n'
              'Cette étape n\'est nécessaire qu\'une seule fois.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuer'),
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
          if (granted) _grantedLocally = true;
          if (granted && context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Installation automatique activée'),
              content: const Text(
                'Parfait ! Les prochaines mises à jour de Watchtower '
                's\'installeront automatiquement en arrière-plan.\n\n'
                'Shizuku n\'est plus nécessaire.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Compris'),
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
        // Download APK to temp dir
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

        // Install silently via PackageInstaller.Session
        final ok = await _channel.invokeMethod<bool>('installApkSilent', {'path': path}) ?? false;
        return ok;
      } catch (e) {
        log('SilentInstaller.downloadAndInstall error: $e');
        return false;
      }
    }
  }
  