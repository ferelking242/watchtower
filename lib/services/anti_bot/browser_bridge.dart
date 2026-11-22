import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;
import 'package:watchtower/services/anti_bot/browser_capture.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Gives spawned isolates access to the browser engine of the root isolate.
///
/// Extension code runs in a worker isolate (`isolate_service.dart`) so a slow
/// source cannot freeze the UI. A WebView cannot be created there: platform
/// views belong to the root isolate, and the plugin registry that
/// [BrowserCapture] checks is empty in a worker — which is why a capture
/// attempted from the worker failed instantly and silently, leaving the
/// extension with its original `403`.
///
/// The bridge is a one-message RPC: the worker sends the request plus a reply
/// port, the root isolate performs it in the browser and answers with the body.
class BrowserBridge {
  BrowserBridge._();

  static SendPort? _mainPort;
  static ReceivePort? _server;
  static SendPort? _serverSendPort;
  static int _ticket = 0;

  /// Root isolate: called when the browser could not obtain a page, i.e. the
  /// block needs a human in the bypass panel.
  ///
  /// Notifications must be raised from the root isolate — a worker isolate has
  /// no platform channel (`Background isolates do not support
  /// setMessageHandler()`), so a challenge first seen while replaying a request
  /// from an extension or download worker would otherwise be silently dropped.
  static void Function(String url, int? sourceId)? onBrowserUnavailable;

  /// False inside a spawned isolate (extension workers).
  static bool get isRootIsolate => RootIsolateToken.instance != null;

  static bool get isConnected => _mainPort != null;

  /// Root isolate only: starts listening and returns the port to hand to the
  /// workers. Idempotent.
  static SendPort startServer() {
    final existing = _serverSendPort;
    if (existing != null) return existing;
    final port = ReceivePort();
    _server = port;
    _serverSendPort = port.sendPort;
    port.listen((message) => unawaited(_serve(message)));
    return port.sendPort;
  }

  static void stopServer() {
    _server?.close();
    _server = null;
    _serverSendPort = null;
  }

  /// Worker isolate only: connects to the root isolate's server.
  static void connect(SendPort port) {
    _mainPort = port;
  }

  /// Worker isolate only: performs [request] in the root isolate's browser.
  static Future<BrowserCaptureResult?> request(
    BrowserCaptureRequest request,
  ) async {
    final port = _mainPort;
    final ticket = ++_ticket;
    final stopwatch = Stopwatch()..start();
    if (port == null) {
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=worker-unavailable '
        'reason=bridge_not_connected url=${redactUrl(request.url)}',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      return null;
    }
    final reply = ReceivePort();
    try {
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=worker-send '
        'timeoutMs=${request.timeout.inMilliseconds} '
        'solveTimeoutMs=${request.solveTimeout.inMilliseconds} '
        'url=${redactUrl(request.url)}',
        logLevel: LogLevel.info,
        tag: LogTag.extension_,
      );
      port.send({
        'id': ticket,
        'request': request.toMap(),
        'reply': reply.sendPort,
      });
      final message = await reply.first.timeout(
        request.timeout + request.solveTimeout + const Duration(seconds: 5),
      );
      if (message is! Map) return null;
      final error = message['error']?.toString() ?? '';
      if (error.isNotEmpty) {
        AppLogger.log(
          '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
          'sourceId=${request.sourceId ?? "-"} phase=worker-result '
          'outcome=unavailable elapsedMs=${stopwatch.elapsedMilliseconds} '
          'reason=$error url=${redactUrl(request.url)}',
          logLevel: LogLevel.warning,
          tag: LogTag.extension_,
        );
        return null;
      }
      final result = message['result'];
      if (result is! Map) return null;
      final capture = BrowserCaptureResult.fromMap(
        result.cast<String, dynamic>(),
      );
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=worker-result '
        'outcome=resolved status=${capture.statusCode} '
        'bodyChars=${capture.body.length} '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'url=${redactUrl(request.url)}',
        logLevel: LogLevel.info,
        tag: LogTag.extension_,
      );
      return capture;
    } catch (error) {
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=worker-result '
        'outcome=error errorType=${error.runtimeType} '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'url=${redactUrl(request.url)}',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      return null;
    } finally {
      reply.close();
    }
  }

  /// Root isolate: answers one worker request.
  static Future<void> _serve(dynamic message) async {
    if (message is! Map) return;
    final reply = message['reply'];
    final raw = message['request'];
    if (reply is! SendPort || raw is! Map) return;
    final ticket = message['id'] as int? ?? -1;
    final request = BrowserCaptureRequest.fromMap(raw.cast<String, dynamic>());
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
      'sourceId=${request.sourceId ?? "-"} phase=root-start '
      'url=${redactUrl(request.url)}',
      logLevel: LogLevel.info,
      tag: LogTag.extension_,
    );
    try {
      final result = await BrowserCapture.fetch(request);
      if (result == null) {
        // The worker asked for a page the browser could not obtain: this is the
        // only place that runs in the root isolate, so raise the notification
        // here (a platform channel is unavailable in the worker).
        //
        // A raw media URL never reaches this point meaningfully: a WebView
        // cannot serve a playlist or a segment, so the failure says nothing
        // about Cloudflare and reporting it raised a false "blocked" alert
        // while mpv was already playing the video. Stay silent for those.
        if (request.notifyOnUnavailable && !isRawMediaUrl(request.url)) {
          try {
            onBrowserUnavailable?.call(request.url, request.sourceId);
          } catch (_) {
            // Notification failures must never break the bridge reply.
          }
        }
      }
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=root-result '
        'outcome=${result == null ? "unavailable" : "resolved"} '
        'status=${result?.statusCode ?? "-"} '
        'bodyChars=${result?.body.length ?? 0} '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'url=${redactUrl(request.url)}',
        logLevel: result == null ? LogLevel.warning : LogLevel.info,
        tag: LogTag.extension_,
      );
      reply.send(
        result == null
            ? {'error': 'the browser could not obtain this page'}
            : {'result': result.toMap()},
      );
    } catch (error) {
      AppLogger.log(
        '[BrowserBridge] ticket=$ticket trace=${request.traceId ?? "-"} '
        'sourceId=${request.sourceId ?? "-"} phase=root-result '
        'outcome=error errorType=${error.runtimeType} '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'url=${redactUrl(request.url)}',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
      // The trace already has the redacted URL and elapsed time; returning the
      // raw exception could re-introduce a signed query string into worker logs.
      reply.send({'error': error.runtimeType.toString()});
    }
  }
}
