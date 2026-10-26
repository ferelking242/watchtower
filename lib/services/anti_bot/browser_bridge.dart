import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;
import 'package:watchtower/services/anti_bot/browser_capture.dart';
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
    if (port == null) return null;
    final reply = ReceivePort();
    try {
      port.send({
        'id': ++_ticket,
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
          '[BrowserBridge] ${request.url} — $error',
          logLevel: LogLevel.debug,
          tag: LogTag.extension_,
        );
        return null;
      }
      final result = message['result'];
      if (result is! Map) return null;
      return BrowserCaptureResult.fromMap(result.cast<String, dynamic>());
    } catch (error) {
      AppLogger.log(
        '[BrowserBridge] ${request.url} — $error',
        logLevel: LogLevel.debug,
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
    final request = BrowserCaptureRequest.fromMap(
      raw.cast<String, dynamic>(),
    );
    try {
      final result = await BrowserCapture.fetch(request);
      reply.send(
        result == null
            ? {'error': 'the browser could not obtain this page'}
            : {'result': result.toMap()},
      );
    } catch (error) {
      reply.send({'error': '$error'});
    }
  }
}
