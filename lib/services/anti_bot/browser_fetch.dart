import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/main.dart' show webViewEnvironment;
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Result of a request performed by a real browser engine.
class BrowserFetchResult {
  const BrowserFetchResult({required this.body, required this.statusCode});

  final String body;
  final int statusCode;
}

enum BrowserFetchOutcome {
  /// The headless browser produced the page for this request.
  resolved,

  /// Another request already started solving the same host: the caller should
  /// retry natively instead of opening a second browser.
  joined,

  /// No browser session could help (unsupported platform, block page, timeout).
  unavailable,
}

class BrowserFetchResponse {
  const BrowserFetchResponse(this.outcome, [this.result]);

  final BrowserFetchOutcome outcome;
  final BrowserFetchResult? result;
}

/// Replays a blocked request inside a real browser engine.
///
/// Cloudflare decides per client, not per site: a WebView navigation to
/// `missav.ws` loads instantly (the managed challenge runs its JavaScript and
/// passes), while the extension's native client — a different TLS stack, no
/// browser headers, no solved challenge — is answered with
/// `403 + cf-mitigated: challenge` forever. There is nothing for the user to
/// click, so a resolution panel is useless there: the fix is to fetch the page
/// with the same engine that was accepted, harvest its cookies and User-Agent,
/// and hand the HTML back to the extension. This is how Aidoku's WebView
/// requests and Mihon's Cloudflare interceptor work.
///
/// The browser session is shared with the app: cookies are seeded from
/// [MClient] before the navigation and written back after it, so the next
/// native request carries `cf_clearance` with the matching User-Agent.
class BrowserFetchService {
  BrowserFetchService._();

  /// Total time granted to clear the challenge and capture the page.
  static const Duration _captureTimeout = Duration(seconds: 30);

  /// How often the rendered page is inspected while waiting.
  static const Duration _pollInterval = Duration(milliseconds: 800);

  /// A document is captured only once it stopped changing (challenge → page).
  static const Duration _settleDelay = Duration(milliseconds: 700);

  /// Hosts currently being solved in a headless browser.
  static final Map<String, Future<BrowserFetchResult?>> _inFlight = {};

  /// A phone cannot host many WebViews at once; a burst of refused requests
  /// must not spawn one browser per request.
  static int _activeCaptures = 0;
  static const int _maxActiveCaptures = 2;

  /// Hosts whose session was just refreshed: challenge responses arriving in
  /// this window are expected and must not alert the user.
  static final Map<String, DateTime> _recentlyCleared = {};
  static const Duration _quietWindow = Duration(seconds: 45);

  /// Headless WebViews need a native browser engine.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True when a challenge for [url] is already being solved (or was just
  /// solved), so the user must not be notified about it.
  static bool isResolving(String url) {
    final host = _hostOf(url);
    if (host == null) return false;
    if (_inFlight.containsKey(host)) return true;
    final cleared = _recentlyCleared[host];
    return cleared != null && DateTime.now().difference(cleared) < _quietWindow;
  }

  /// Fetches [url] through a headless browser, solving the Cloudflare challenge
  /// that the native client cannot solve. Never throws: an unusable browser
  /// session yields [BrowserFetchOutcome.unavailable].
  static Future<BrowserFetchResponse> fetchHtml(
    String url, {
    int? sourceId,
    Map<String, String>? headers,
    bool waitForExisting = false,
  }) async {
    if (!isSupported) {
      return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
    }
    final host = _hostOf(url);
    if (host == null) {
      return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
    }

    final pending = _inFlight[host];
    if (pending != null) {
      await pending;
      // The first caller refreshed this host's session: retrying natively is
      // free, a second browser is not.
      if (!waitForExisting) {
        return const BrowserFetchResponse(BrowserFetchOutcome.joined);
      }
    }
    if (_activeCaptures >= _maxActiveCaptures) {
      return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
    }

    _activeCaptures++;
    final future = _capture(url, sourceId: sourceId, headers: headers);
    _inFlight[host] = future;
    try {
      final result = await future;
      if (result == null) {
        return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
      }
      _recentlyCleared[host] = DateTime.now();
      while (_recentlyCleared.length > 32) {
        final oldest = _recentlyCleared.entries.reduce(
          (a, b) => a.value.isBefore(b.value) ? a : b,
        );
        _recentlyCleared.remove(oldest.key);
      }
      return BrowserFetchResponse(BrowserFetchOutcome.resolved, result);
    } finally {
      _inFlight.remove(host);
      _activeCaptures--;
    }
  }

  static Future<BrowserFetchResult?> _capture(
    String url, {
    int? sourceId,
    Map<String, String>? headers,
  }) async {
    HeadlessInAppWebView? headless;
    InAppWebViewController? controller;
    var lastLoadAt = DateTime.now();
    String? body;
    try {
      // Reuse whatever the app already knows about this site; a stale cookie
      // is enough for the navigation to land on the real page.
      try {
        await MClient.restoreCookiesToWebView(url, sourceId: sourceId);
      } catch (_) {}

      final userAgent = MClient.userAgentForRequests(sourceId: sourceId);
      headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSize: const Size(390, 780),
        initialUrlRequest: URLRequest(
          url: WebUri(url),
          headers: headers ?? const <String, String>{},
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          // The User-Agent must be the one the native client sends, otherwise
          // `cf_clearance` is bound to another browser identity and rejected.
          userAgent: userAgent.trim().isEmpty ? null : userAgent,
          transparentBackground: true,
        ),
        onWebViewCreated: (created) => controller = created,
        onLoadStop: (stopped, _) {
          controller = stopped;
          lastLoadAt = DateTime.now();
        },
      );
      await headless.run();

      final deadline = DateTime.now().add(_captureTimeout);
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
          await _persistSession(web, url, sourceId: sourceId);
          body = html;
          break;
        }
      }
    } catch (error, stackTrace) {
      AppLogger.log(
        '[BrowserFetch] ${redactUrl(url)} failed: $error',
        logLevel: LogLevel.warning,
        tag: kLogTagNet,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      try {
        await headless?.dispose();
      } catch (_) {}
    }
    if (body == null) {
      AppLogger.log(
        '[BrowserFetch] ${redactUrl(url)} — no page captured',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
      return null;
    }
    AppLogger.log(
      '[BrowserFetch] ${redactUrl(url)} — page captured in the browser',
      logLevel: LogLevel.debug,
      tag: kLogTagNet,
    );
    return BrowserFetchResult(body: body, statusCode: 200);
  }

  /// Stores the browser session (cookies + User-Agent) so the extension's HTTP
  /// client sends exactly what the accepted navigation sent.
  static Future<void> _persistSession(
    InAppWebViewController controller,
    String url, {
    int? sourceId,
  }) async {
    try {
      final ua = await controller.evaluateJavascript(
        source: 'navigator.userAgent',
      );
      await MClient.setCookie(
        url,
        ua is String ? ua : '',
        controller,
        sourceId: sourceId,
      );
    } catch (error) {
      AppLogger.log(
        '[BrowserFetch] session persist failed: $error',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
    }
  }

  static String? _hostOf(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.isEmpty ? null : host;
  }
}
