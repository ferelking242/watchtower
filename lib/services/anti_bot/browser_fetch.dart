import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/browser_capture.dart';
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

/// Replays a request refused by Cloudflare inside a real browser engine.
///
/// Cloudflare decides per client, not per site: a WebView navigation to
/// `missav.ws` loads instantly (the managed challenge runs its JavaScript and
/// passes), while the extension's native client — a different TLS stack, header
/// order and cookie jar — is answered with `403 + cf-mitigated: challenge`
/// forever. There is nothing for the user to click, so a resolution panel
/// cannot help there. This service performs the request with the engine that
/// was accepted, harvests the resulting session and hands the HTML back to the
/// extension. That is the Mihon / Aidoku model (browser solves, cookie jar is
/// shared, request retried) taken one step further, as Aidoku's issue #1034
/// suggests, because here the native client is Rust, not OkHttp/URLSession.
class BrowserFetchService {
  BrowserFetchService._();

  /// A phone or a laptop cannot host many WebViews at once; a burst of refused
  /// requests must not spawn one browser per request.
  static const int _maxActiveCaptures = 2;

  /// Hosts currently being solved in a headless browser.
  static final Map<String, Future<BrowserFetchResult?>> _inFlight = {};

  /// Hosts whose session was just refreshed: challenge responses arriving in
  /// this window are expected and must not alert the user.
  static final Map<String, DateTime> _recentlyCleared = {};
  static const Duration _quietWindow = Duration(seconds: 45);

  static int _activeCaptures = 0;

  /// True when this platform has a usable browser engine (see
  /// [BrowserCaptureSupport]).
  static bool get isSupported => BrowserCapture.isAvailable;

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
    final captured = await BrowserCapture.capture(
      BrowserCaptureRequest(
        url: url,
        sourceId: sourceId,
        headers: headers ?? const <String, String>{},
      ),
    );
    if (captured == null) {
      AppLogger.log(
        '[BrowserFetch] ${redactUrl(url)} — no page captured',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
      return null;
    }
    await _storeSession(url, captured, sourceId: sourceId);
    AppLogger.log(
      '[BrowserFetch] ${redactUrl(url)} — page captured in the browser',
      logLevel: LogLevel.debug,
      tag: kLogTagNet,
    );
    return BrowserFetchResult(
      body: captured.body,
      statusCode: captured.statusCode,
    );
  }

  /// Stores the browser session (cookies + User-Agent) so the extension's HTTP
  /// client sends exactly what the accepted navigation sent.
  static Future<void> _storeSession(
    String url,
    BrowserCaptureResult captured, {
    int? sourceId,
  }) async {
    if (captured.cookies.isEmpty) return;
    try {
      await MClient.setCookie(
        captured.finalUrl.isEmpty ? url : captured.finalUrl,
        captured.userAgent,
        null,
        webViewCookies: captured.cookies,
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
