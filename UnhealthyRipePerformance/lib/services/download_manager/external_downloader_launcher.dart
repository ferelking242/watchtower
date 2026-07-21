import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Launches an external Android download manager (ADM, 1DM, FDM, IDM, etc.)
/// with the given URL. Uses Android's `intent://` scheme so we don't need
/// any extra plugin — the Android intent resolver picks the right app.
///
/// Key design choices vs the previous version:
///  • NO `S.browser_fallback_url` — that parameter is the reason Chrome/Kiwi
///    opens instead of ADM: any Chromium browser intercepts intent:// URIs
///    that carry a browser_fallback_url and treats it as "open this URL in me".
///  • Uses `LaunchMode.externalNonBrowserApplication` so url_launcher itself
///    never selects a browser as the handler.
///  • Falls back to a generic-package intent (Android chooser) but NEVER to
///    a raw browser URL — returning false lets the caller show an error toast.
class ExternalDownloaderLauncher {
  /// Map: registry id → Android package name.
  static const Map<String, String> packageMap = {
    'adm': 'com.dv.adm',
    '1dm': 'idm.internet.download.manager',
    'fdm': 'org.freedownloadmanager.fdm',
    'idm': 'idm.internet.download.manager.plus',
  };

  /// Builds an `intent://` URI targeting [pkg] (or no package when null for a
  /// chooser). Does NOT include `browser_fallback_url` — that is what caused
  /// Chrome to open instead of the download manager.
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
      final lc = <String, String>{};
      headers.forEach((k, v) => lc[k.toLowerCase()] = v);

      final ua = lc['user-agent'];
      final ref = lc['referer'] ?? lc['referrer'];
      final cookie = lc['cookie'];

      if (ua != null && ua.isNotEmpty) {
        buf.write('S.User-Agent=${Uri.encodeComponent(ua)};');
        buf.write('S.com.dv.adm.useragent=${Uri.encodeComponent(ua)};');
      }
      if (ref != null && ref.isNotEmpty) {
        buf.write('S.Referer=${Uri.encodeComponent(ref)};');
        buf.write('S.com.dv.adm.referer=${Uri.encodeComponent(ref)};');
        buf.write('S.android.intent.extra.REFERRER=${Uri.encodeComponent(ref)};');
      }
      if (cookie != null && cookie.isNotEmpty) {
        buf.write('S.Cookie=${Uri.encodeComponent(cookie)};');
        buf.write('S.com.dv.adm.cookie=${Uri.encodeComponent(cookie)};');
      }
    }

    // ⚠️  NO browser_fallback_url — that's what caused Chrome/Kiwi to open
    //     instead of ADM when the package-specific intent failed.
    buf.write('end');
    return buf.toString();
  }

  static Future<bool> launch({
    required String url,
    required String appId,
    Map<String, String>? headers,
  }) async {
    AppLogger.log(
      'External downloader launch | app=$appId | url=$url',
      tag: LogTag.download,
    );

    // On non-Android platforms just open the URL in an external app.
    if (!Platform.isAndroid) {
      try {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {
        return false;
      }
    }

    final pkg = packageMap[appId];

    // ── Attempt 1: targeted intent (specific package) ──────────────────────
    try {
      final uri = Uri.parse(_buildIntentUri(url: url, pkg: pkg, headers: headers));
      final ok = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return true;
    } catch (e) {
      AppLogger.log(
        'Intent launch failed (pkg=$pkg): $e',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
    }

    // ── Attempt 2: generic intent — shows Android chooser ─────────────────
    try {
      final generic = Uri.parse(_buildIntentUri(url: url, pkg: null, headers: headers));
      final ok2 = await launchUrl(generic, mode: LaunchMode.externalNonBrowserApplication);
      if (ok2) return true;
    } catch (_) {}

    // ── No browser fallback — return false so caller shows a toast ─────────
    AppLogger.log(
      'External downloader not found for appId=$appId — not falling back to browser.',
      logLevel: LogLevel.warning,
      tag: LogTag.download,
    );
    return false;
  }
}
