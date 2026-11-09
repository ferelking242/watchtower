import 'dart:typed_data' show Uint8List;

import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/browser_bridge.dart';
import 'package:watchtower/services/anti_bot/browser_capture.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Result of a request performed by a real browser engine.
class BrowserFetchResult {
  const BrowserFetchResult({
    required this.body,
    required this.statusCode,
    this.bytes,
  });

  final String body;
  final int statusCode;

  /// Raw payload for a binary request (cover, reader page); `null` for text.
  final Uint8List? bytes;
}

enum BrowserFetchOutcome {
  /// The browser produced the page for this request.
  resolved,

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
/// Extension code runs in a worker isolate, where no engine exists, so the
/// call is forwarded to the root isolate through [BrowserBridge]; that isolate
/// owns the WebView and runs the request inside the page Cloudflare accepted
/// (see [BrowserCapture]).
class BrowserFetchService {
  BrowserFetchService._();

  /// A Surrit playlist can return a plain 403 to the native client without
  /// Cloudflare response markers. In that case, retry only the known MissAV
  /// media host in the browser, using the source page as the browser origin.
  static bool isMissAvHlsPlaylistRefusal(String url, int statusCode) {
    if (statusCode != 403) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || !_isSurritHost(uri.host)) {
      return false;
    }
    return uri.path.toLowerCase().endsWith('.m3u8');
  }

  /// Selects the page that initiated a MissAV media request for browser replay.
  ///
  /// Other media hosts keep their existing same-origin behavior. MissAV's
  /// Surrit CDN needs the actual MissAV page context; opening the playlist URL
  /// itself leaves the browser session on a non-HTML media response.
  static String? pageUrlForMissAvMediaRequest(
    String url,
    Map<String, String>? headers,
  ) {
    final mediaUri = Uri.tryParse(url);
    if (mediaUri == null ||
        mediaUri.scheme != 'https' ||
        !_isSurritHost(mediaUri.host)) {
      return null;
    }

    String? referer;
    headers?.forEach((name, value) {
      if (name.toLowerCase() == 'referer') referer = value.trim();
    });
    if (referer == null || referer!.isEmpty) return null;

    final pageUri = Uri.tryParse(referer!);
    if (pageUri == null ||
        pageUri.scheme != 'https' ||
        !_isMissAvHost(pageUri.host)) {
      return null;
    }
    return pageUri.toString();
  }

  /// True for a MissAV media URL on the Surrit CDN, whatever its path.
  ///
  /// Both the HLS playlist and its `.ts`/`.jpeg` segments live there, and both
  /// need the same replay shape (no credentials, MissAV referrer), so the test
  /// is on the host alone rather than on the `.m3u8` extension
  /// [isMissAvHlsPlaylistRefusal] uses.
  static bool isMissAvMediaUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && _isSurritHost(uri.host);
  }

  /// The MissAV referrer a Surrit media request must carry, or `null` when the
  /// request is not a MissAV media one.
  ///
  /// Surrit refuses a playlist/segment whose `Referer` is missing or is not a
  /// missav.ws page (a bare origin is enough: `https://missav.ws/` is accepted).
  /// The browser normally sends that referrer itself, but MissAV answers with
  /// `Referrer-Policy: same-origin`, so a cross-origin `fetch()` from the
  /// accepted page drops it — this value is reattached with an explicit
  /// `referrer`/`referrerPolicy: 'unsafe-url'` on the in-page request.
  static String? missAvMediaReferrer(
    String url,
    Map<String, String>? headers,
  ) {
    if (!isMissAvMediaUrl(url)) return null;
    final page = pageUrlForMissAvMediaRequest(url, headers);
    if (page != null) return page;
    // No usable page header: the site root still satisfies Surrit's check.
    return 'https://missav.ws/';
  }

  static bool _isSurritHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'surrit.com' || normalized.endsWith('.surrit.com');
  }

  static bool _isMissAvHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'missav.ws' || normalized.endsWith('.missav.ws');
  }

  /// Hosts being served right now, per isolate.
  static final Set<String> _inFlightHosts = {};

  /// Hosts whose native client was already answered with a challenge in this
  /// isolate. The verdict is on the client fingerprint (Rust/rustls), not on
  /// the request, so every later native attempt on the same host is guaranteed
  /// to burn a round-trip before the browser serves it — the home layout's
  /// dozen shelves each paid that toll. Remembering the host lets the caller
  /// skip straight to the browser. Bounded and never persisted: a fresh isolate
  /// starts empty, so a host that stops challenging is probed natively again.
  static final Set<String> _nativeChallengedHosts = {};

  /// Records that [url]'s host answered the native client with a challenge.
  static void markNativeChallenged(String url) {
    final host = _hostOf(url);
    if (host == null) return;
    _nativeChallengedHosts.add(host);
    while (_nativeChallengedHosts.length > 64) {
      _nativeChallengedHosts.remove(_nativeChallengedHosts.first);
    }
  }

  /// True when the native client is known to be challenged on [url]'s host, so
  /// the caller may go straight to the browser session.
  static bool nativeProbeIsPointless(String url) {
    final host = _hostOf(url);
    return host != null && _nativeChallengedHosts.contains(host);
  }

  /// Hosts just served by the browser: challenges arriving in this window are
  /// the normal tail of a burst, not something to alert the user about.
  static final Map<String, DateTime> _servedAt = {};
  static const Duration _quietWindow = Duration(seconds: 45);

  /// True when this isolate can reach a browser engine.
  static bool get isSupported =>
      BrowserBridge.isRootIsolate
          ? BrowserCapture.isAvailable
          : BrowserBridge.isConnected;

  /// True when a challenge for [url] is being solved, or was just solved here.
  static bool isResolving(String url) {
    final host = _hostOf(url);
    if (host == null) return false;
    if (_inFlightHosts.contains(host)) return true;
    final at = _servedAt[host];
    return at != null && DateTime.now().difference(at) < _quietWindow;
  }

  /// Fetches [url] through the browser engine. Never throws: a response the
  /// browser could not obtain is reported as
  /// [BrowserFetchOutcome.unavailable].
  ///
  /// [pageUrl] is the HTML page the session should solve the challenge on
  /// before fetching [url] from inside it. Binary targets (images) must pass
  /// one: a WebView navigated straight to an image never clears the challenge.
  static Future<BrowserFetchResponse> fetch(
    String url, {
    int? sourceId,
    Map<String, String>? headers,
    String? pageUrl,
    bool binary = false,
    bool omitCredentials = false,
    String? referrer,
    String? referrerPolicy,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final host = _hostOf(url);
    if (host == null || !isSupported) {
      return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
    }

    _inFlightHosts.add(host);
    try {
      final request = BrowserCaptureRequest(
        url: url,
        sourceId: sourceId,
        headers: headers ?? const <String, String>{},
        pageUrl: pageUrl,
        binary: binary,
        omitCredentials: omitCredentials,
        referrer: referrer,
        referrerPolicy: referrerPolicy,
        timeout: timeout,
      );
      final result = BrowserBridge.isRootIsolate
          ? await BrowserCapture.fetch(request)
          : await BrowserBridge.request(request);
      if (result == null) {
        AppLogger.log(
          '[BrowserFetch] ${redactUrl(url)} — no page from the browser',
          logLevel: LogLevel.debug,
          tag: LogTag.extension_,
        );
        return const BrowserFetchResponse(BrowserFetchOutcome.unavailable);
      }
      _servedAt[host] = DateTime.now();
      while (_servedAt.length > 32) {
        final oldest = _servedAt.entries.reduce(
          (a, b) => a.value.isBefore(b.value) ? a : b,
        );
        _servedAt.remove(oldest.key);
      }
      return BrowserFetchResponse(
        BrowserFetchOutcome.resolved,
        BrowserFetchResult(
          body: result.body,
          statusCode: result.statusCode,
          bytes: result.bytes,
        ),
      );
    } finally {
      _inFlightHosts.remove(host);
    }
  }

  static String? _hostOf(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.isEmpty ? null : host;
  }
}
