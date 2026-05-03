import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
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

  /// Build an intent:// URI with headers passed as extras so apps like
  /// ADM/1DM/IDM can authenticate against streaming sites that require
  /// User-Agent/Referer/Cookie. Multiple key=value extras are appended
  /// using Android's `S.<key>=<value>` syntax.
  static String _buildIntentUri({
    required String url,
    required String? pkg,
    required Map<String, String>? headers,
  }) {
    final parsed = Uri.parse(url);
    final scheme = parsed.scheme;
    final hostPath = url.substring(url.indexOf('://') + 3);

    final buf = StringBuffer('intent://$hostPath#Intent;')
      ..write('scheme=$scheme;')
      ..write('action=android.intent.action.VIEW;');
    if (pkg != null) buf.write('package=$pkg;');

    if (headers != null && headers.isNotEmpty) {
      // Lowercase and dedupe headers — case insensitive per RFC.
      final lc = <String, String>{};
      headers.forEach((k, v) => lc[k.toLowerCase()] = v);

      // Standard extras most Android download managers honor.
      final ua = lc['user-agent'];
      final ref = lc['referer'] ?? lc['referrer'];
      final cookie = lc['cookie'];

      if (ua != null && ua.isNotEmpty) {
        buf.write('S.User-Agent=${Uri.encodeComponent(ua)};');
        // ADM-specific extras
        buf.write('S.com.dv.adm.useragent=${Uri.encodeComponent(ua)};');
      }
      if (ref != null && ref.isNotEmpty) {
        buf.write('S.Referer=${Uri.encodeComponent(ref)};');
        // ADM-specific extras
        buf.write('S.com.dv.adm.referer=${Uri.encodeComponent(ref)};');
        // Also Android browser-style extra
        buf.write(
            'S.android.intent.extra.REFERRER=${Uri.encodeComponent(ref)};');
      }
      if (cookie != null && cookie.isNotEmpty) {
        buf.write('S.Cookie=${Uri.encodeComponent(cookie)};');
        buf.write('S.com.dv.adm.cookie=${Uri.encodeComponent(cookie)};');
      }
    }

    buf.write('S.browser_fallback_url=${Uri.encodeComponent(url)};');
    buf.write('end');
    return buf.toString();
  }

  static Future<bool> launch({
    required String url,
    required String appId,
    Map<String, String>? headers,
  }) async {
    AppLogger.log(
      'External downloader launch | app=$appId | url=$url | hdrs=${headers?.keys.toList() ?? const []}',
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
    final intentUriString =
        _buildIntentUri(url: url, pkg: pkg, headers: headers);
    final intentUri = Uri.parse(intentUriString);

    try {
      final ok = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launchUrl returned false');
      return true;
    } catch (e) {
      AppLogger.log(
        'Intent launch failed (pkg=$pkg) — retry without package then browser: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      // Retry without specific package — let Android show the chooser
      try {
        final genericIntent = Uri.parse(
            _buildIntentUri(url: url, pkg: null, headers: headers));
        final ok2 =
            await launchUrl(genericIntent, mode: LaunchMode.externalApplication);
        if (ok2) return true;
      } catch (_) {}
      try {
        return await launchUrl(
          Uri.parse(url),
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
