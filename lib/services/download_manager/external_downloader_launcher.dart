import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Launches an external Android download manager (ADM, 1DM, FDM, IDM, etc.)
/// with the given URL. Uses Android's `intent://` scheme so we don't need
/// any extra plugin — the Android intent resolver picks the right app or
/// shows a chooser when no specific package is set.
class ExternalDownloaderLauncher {
  /// Map: registry id -> Android package name.
  static const Map<String, String> packageMap = {
    'adm': 'com.dv.adm',
    '1dm': 'idm.internet.download.manager',
    'fdm': 'org.freedownloadmanager.fdm',
    'idm': 'idm.internet.download.manager.plus',
  };

  static Future<bool> launch({
    required String url,
    required String appId,
    Map<String, String>? headers,
  }) async {
    AppLogger.log(
      'External downloader launch | app=$appId | url=$url',
      tag: LogTag.download,
    );
    if (!Platform.isAndroid) {
      try {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }

    final pkg = packageMap[appId];
    final parsed = Uri.parse(url);
    final scheme = parsed.scheme;
    final hostPath = url.substring(url.indexOf('://') + 3);

    final intentBuf = StringBuffer('intent://$hostPath#Intent;')
      ..write('scheme=$scheme;')
      ..write('action=android.intent.action.VIEW;');
    if (pkg != null) intentBuf.write('package=$pkg;');
    intentBuf.write('S.browser_fallback_url=${Uri.encodeComponent(url)};');
    intentBuf.write('end');

    final intentUri = Uri.parse(intentBuf.toString());
    try {
      final ok = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launchUrl returned false');
      return true;
    } catch (e) {
      AppLogger.log(
        'Intent launch failed (pkg=$pkg) — falling back to browser: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      try {
        return await launchUrl(
          parsed,
          mode: LaunchMode.externalApplication,
        );
      } catch (e2) {
        AppLogger.log(
          'Fallback launch failed: $e2',
          logLevel: LogLevel.error,
          tag: LogTag.download,
        );
        return false;
      }
    }
  }
}
