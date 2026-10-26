import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/browser_bridge.dart';
import 'package:watchtower/services/anti_bot/browser_capture.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Result of a request performed by a real browser engine.
class BrowserFetchResult {
  const BrowserFetchResult({required this.body, required this.statusCode});

  final String body;
  final int statusCode;
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

  /// Hosts being served right now, per isolate.
  static final Set<String> _inFlightHosts = {};

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
  static Future<BrowserFetchResponse> fetch(
    String url, {
    int? sourceId,
    Map<String, String>? headers,
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
