import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/main.dart' show webViewEnvironment;
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// How this build can obtain a page that Cloudflare refuses to the HTTP client.
enum BrowserCaptureSupport {
  /// A hidden WebView navigates to the URL, runs the challenge JavaScript and
  /// hands back the rendered DOM. Used on Android, iOS, macOS, Windows and
  /// Linux: every platform where flutter_inappwebview registers an engine.
  headless,

  /// Flutter web: the browser cannot read another origin's HTML, so blocked
  /// requests go through the Cloudflare Worker proxy instead
  /// (`WebProxyInterceptor` in `m_client.dart`).
  proxy,

  /// Nothing usable: the visible panel and the user remain the only path.
  none,
}

/// Platform matrix, kept pure so it is testable without a device.
BrowserCaptureSupport browserCaptureSupportFor({
  required bool isWeb,
  required String operatingSystem,
  required bool engineRegistered,
}) {
  if (isWeb) return BrowserCaptureSupport.proxy;
  if (!engineRegistered) return BrowserCaptureSupport.none;
  return switch (operatingSystem) {
    'android' || 'ios' || 'macos' || 'windows' || 'linux' =>
      BrowserCaptureSupport.headless,
    _ => BrowserCaptureSupport.none,
  };
}

class BrowserCaptureRequest {
  const BrowserCaptureRequest({
    required this.url,
    this.sourceId,
    this.headers = const <String, String>{},
    this.timeout = const Duration(seconds: 30),
  });

  final String url;
  final int? sourceId;
  final Map<String, String> headers;

  /// Time granted to the page to clear the challenge and settle.
  final Duration timeout;
}

class BrowserCaptureResult {
  const BrowserCaptureResult({
    required this.body,
    required this.finalUrl,
    required this.cookies,
    required this.userAgent,
    this.statusCode = 200,
  });

  final String body;
  final String finalUrl;

  /// Browser cookies for the final URL; the caller stores them so the HTTP
  /// client reuses the same session (`cf_clearance` included).
  final List<Cookie> cookies;
  final String userAgent;
  final int statusCode;
}

/// Fetches a page with a real browser engine, in the background.
///
/// The engine is the credential: Cloudflare answers `403 + cf-mitigated:
/// challenge` to a native client whose TLS stack, header order and cookie jar
/// are not a browser's, while the same URL loads instantly in a WebView because
/// the managed challenge is plain JavaScript. A `HeadlessInAppWebView` runs that
/// JavaScript off-screen, so the app gets the page without a full-screen
/// detour.
class BrowserCapture {
  BrowserCapture._();

  static const Duration _pollInterval = Duration(milliseconds: 800);

  /// A document is captured only once it stopped changing (challenge → page).
  static const Duration _settleDelay = Duration(milliseconds: 700);

  static BrowserCaptureSupport get support => browserCaptureSupportFor(
    isWeb: kIsWeb,
    operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
    engineRegistered:
        !kIsWeb && InAppWebViewPlatform.instance != null,
  );

  static bool get isAvailable => support == BrowserCaptureSupport.headless;

  /// Navigates to [request.url] in a hidden WebView and returns the rendered
  /// page, or `null` when the page never left a challenge / block state.
  /// Never throws.
  static Future<BrowserCaptureResult?> capture(
    BrowserCaptureRequest request,
  ) async {
    if (!isAvailable) return null;
    HeadlessInAppWebView? headless;
    InAppWebViewController? controller;
    var lastLoadAt = DateTime.now();
    String? body;
    String finalUrl = request.url;
    try {
      // Reuse what the app already knows about this site: a still-valid
      // clearance makes the navigation land on the real page immediately.
      try {
        await MClient.restoreCookiesToWebView(
          request.url,
          sourceId: request.sourceId,
        );
      } catch (_) {}

      headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSize: const Size(390, 780),
        initialUrlRequest: URLRequest(
          url: WebUri(request.url),
          headers: request.headers,
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          // Must be the User-Agent the HTTP client sends: `cf_clearance` is
          // bound to the identity that solved the challenge.
          userAgent: MClient.userAgentForRequests(sourceId: request.sourceId),
          transparentBackground: true,
        ),
        onWebViewCreated: (created) => controller = created,
        onLoadStop: (stopped, url) {
          controller = stopped;
          lastLoadAt = DateTime.now();
          if (url != null && url.toString().isNotEmpty) {
            finalUrl = url.toString();
          }
        },
      );
      await headless.run();

      final deadline = DateTime.now().add(request.timeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(_pollInterval);
        final web = controller;
        if (web == null) continue;
        if (DateTime.now().difference(lastLoadAt) < _settleDelay) continue;

        final assessment = parsePageProbe(
          await web.evaluateJavascript(source: kCfPageProbeJs) as String?,
        );
        if (assessment.pageType == AntiBotPageType.challenge) {
          // The managed challenge is running its JavaScript; keep waiting.
          continue;
        }
        if (assessment.pageType == AntiBotPageType.blocked) {
          // Hard WAF block: no browser session can unlock this request.
          break;
        }
        final html = await web.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        if (html is String && html.trim().length > 200) {
          body = html;
          break;
        }
      }
      if (body == null) return null;

      final ua = await controller?.evaluateJavascript(
        source: 'navigator.userAgent',
      );
      final cookies = await _cookiesFor(finalUrl);
      return BrowserCaptureResult(
        body: body,
        finalUrl: finalUrl,
        cookies: cookies,
        userAgent: ua is String ? ua : '',
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        '[BrowserCapture] ${redactUrl(request.url)} failed: $error',
        logLevel: LogLevel.warning,
        tag: kLogTagNet,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      try {
        await headless?.dispose();
      } catch (_) {}
    }
  }

  static Future<List<Cookie>> _cookiesFor(String url) async {
    if (!isAvailable) return const [];
    try {
      final manager = CookieManager.instance(
        webViewEnvironment: webViewEnvironment,
      );
      final cookies = await manager.getCookies(url: WebUri(url));
      return cookies.whereType<Cookie>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

