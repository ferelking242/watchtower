import 'dart:async';
    import 'dart:convert';
    import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
    import 'package:flutter/foundation.dart';
    import 'package:http/http.dart' as http;
    import 'package:watchtower/utils/log/logger.dart';

    void _tlog(String msg) => AppLogger.log('[RELAY] $msg', tag: 'REMOTE');
    void _tlogErr(String msg) =>
        AppLogger.log('[RELAY] $msg', tag: 'REMOTE', logLevel: LogLevel.error);

    class TunnelService {
      static const String relayBaseUrl =
          'https://ced0c0ed-46b7-489b-a53b-771860cc38d5-00-33j0djr3c6949.spock.replit.dev/api/relay';

      static const int _localPort = 4567;
      static const Duration _requestTimeout = Duration(seconds: 30);

      void Function(String url)? onUrlChanged;
      void Function(String error)? onError;
      // ignore: unused_field
      void Function(double progress)? onDownloadProgress;

      WebSocket? _ws;
      bool _running = false;
      Timer? _reconnectTimer;
      int _reconnectAttempts = 0;

      /// Backoff: 5s for first 2 failures, 15s up to 5, then 30s.
      Duration get _reconnectDelay {
        if (_reconnectAttempts <= 2) return const Duration(seconds: 5);
        if (_reconnectAttempts <= 5) return const Duration(seconds: 15);
        return const Duration(seconds: 30);
      }

      Future<void> start() async {
        if (kIsWeb) return;
        _running = true;
        _reconnectAttempts = 0;
        _connect();
      }

      void stop() {
        _running = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _ws?.close();
        _ws = null;
        _tlog('Arreté');
      }

      void _scheduleReconnect() {
        if (!_running) return;
        final delay = _reconnectDelay;
        _tlog('Reconnexion dans ${delay.inSeconds}s... (tentative $_reconnectAttempts)');
        _reconnectTimer = Timer(delay, _connect);
      }

      Future<void> _connect() async {
        if (!_running) return;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        final wsUrl = relayBaseUrl
                .replaceFirst('https://', 'wss://')
                .replaceFirst('http://', 'ws://') +
            '/device';

        _tlog('Connexion relay : $wsUrl');

        try {
          // Pre-resolve DNS — catches Android DNS failures before WebSocket.connect
          final host = Uri.parse(relayBaseUrl).host;
          await InternetAddress.lookup(host);

          final ws = await WebSocket.connect(wsUrl).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Connexion timeout'),
          );

          _reconnectAttempts = 0;
          _ws = ws;
          _tlog('Connecté — URL publique : $relayBaseUrl');
          onUrlChanged?.call(relayBaseUrl);

          await for (final raw in ws) {
            if (!_running) break;
            if (raw is! String) continue;
            try {
              final Map<String, dynamic> msg = jsonDecode(raw);
              // Ignore server heartbeat pings (type=ping)
              if (msg['type'] == 'ping') continue;
              _handleRequest(msg);
            } catch (e) {
              _tlogErr('Message invalide : $e');
            }
          }
        } on SocketException catch (e) {
          _reconnectAttempts++;
          _tlogErr('Erreur socket/DNS : $e');
          if (_running) onError?.call('Relay DNS/socket : ${e.message}');
        } on TimeoutException catch (e) {
          _reconnectAttempts++;
          _tlogErr('Timeout connexion : $e');
          if (_running) onError?.call('Relay timeout : $e');
        } catch (e) {
          _reconnectAttempts++;
          _tlogErr('Erreur WebSocket : $e');
          if (_running) onError?.call('Relay déconnecté : $e');
        } finally {
          _ws = null;
        }

        _scheduleReconnect();
      }

      Future<void> _handleRequest(Map<String, dynamic> msg) async {
        final String id = msg['id'] as String? ?? '';
        final String method = (msg['method'] as String? ?? 'GET').toUpperCase();
        final String path = msg['path'] as String? ?? '/';
        final String query = msg['query'] as String? ?? '';
        final String? bodyStr = msg['body'] as String?;

        final fullPath = query.isNotEmpty ? '$path?$query' : path;
        final uri = Uri.parse('http://127.0.0.1:$_localPort$fullPath');

        // API keys may be present in query parameters for browser image requests.
        // Never include query strings in tunnel logs.
        _tlog('Forward $method $path');

        try {
          final reqHeaders = <String, String>{};
          final incomingHeaders = msg['headers'];
          if (incomingHeaders is Map) {
            for (final entry in incomingHeaders.entries) {
              final name = entry.key.toString().toLowerCase();
              final value = entry.value?.toString();
              if (value != null &&
                  (name == 'authorization' || name == 'content-type')) {
                reqHeaders[name] = value;
              }
            }
          }
          final authorization = msg['authorization'];
          if (authorization is String && authorization.isNotEmpty) {
            reqHeaders['authorization'] = authorization;
          }
          if (bodyStr != null && !reqHeaders.containsKey('content-type')) {
            reqHeaders['content-type'] = 'application/json';
          }

          final client = http.Client();
          late final http.Response response;
          try {
            final request = http.Request(method, uri)
              ..headers.addAll(reqHeaders);
            if (bodyStr != null &&
                method != 'GET' &&
                method != 'HEAD' &&
                method != 'OPTIONS') {
              request.body = bodyStr;
            }
            final streamedResponse =
                await client.send(request).timeout(_requestTimeout);
            response = await http.Response.fromStream(streamedResponse)
                .timeout(_requestTimeout);
          } finally {
            client.close();
          }

          final ct = response.headers['content-type'] ?? 'application/json';
          _sendReply(id, response.statusCode, ct, response.body);
        } catch (e) {
          _tlogErr('Erreur requête $path : $e');
          _sendReply(
              id, 500, 'application/json', jsonEncode({'error': e.toString()}));
        }
      }

      void _sendReply(String id, int status, String contentType, String body) {
        final ws = _ws;
        if (ws == null || ws.readyState != WebSocket.open) return;
        ws.add(jsonEncode({
          'id': id,
          'status': status,
          'headers': {'content-type': contentType},
          'body': body,
        }));
      }
    }
    