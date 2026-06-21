import 'dart:async';
    import 'dart:convert';
    import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
    import 'package:flutter/foundation.dart';
    import 'package:http/http.dart' as http;
    import 'package:watchtower/utils/log/logger.dart';

    void _tlog(String msg) => AppLogger.log('[RELAY] $msg', tag: 'REMOTE');
    void _tlogErr(String msg) =>
        AppLogger.log('[RELAY] $msg', tag: 'REMOTE', logLevel: LogLevel.error);

    /// WebSocket relay client — remplace le tunnel SSH dartssh2.
    ///
    /// Le téléphone se connecte en WebSocket au serveur relay Replit.
    /// Le relay transfère les requêtes HTTP du client web (GitHub Pages) vers le
    /// téléphone via WebSocket. Le téléphone appelle son serveur shelf local
    /// (port 4567) et renvoie la réponse au relay.
    ///
    /// URL publique affichée à l'utilisateur : [relayBaseUrl]
    /// L'utilisateur colle cette URL dans l'app web Watchtower.
    class TunnelService {
      /// URL de base du relay Replit (domaine dev — valide pour cette session Replit).
      /// Pour une URL stable permanente, déployer le serveur Replit.
      static const String relayBaseUrl =
          'https://ced0c0ed-46b7-489b-a53b-771860cc38d5-00-33j0djr3c6949.spock.replit.dev/api/relay';

      static const int _localPort = 4567;
      static const Duration _reconnectDelay = Duration(seconds: 5);
      static const Duration _requestTimeout = Duration(seconds: 30);

      void Function(String url)? onUrlChanged;
      void Function(String error)? onError;

      // Kept for API compatibility with RemoteServerService
      // ignore: unused_field
      void Function(double progress)? onDownloadProgress;

      WebSocket? _ws;
      bool _running = false;
      Timer? _reconnectTimer;

      Future<void> start() async {
        if (kIsWeb) return;
        _running = true;
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
        _tlog('Reconnexion dans ${_reconnectDelay.inSeconds}s...');
        _reconnectTimer = Timer(_reconnectDelay, _connect);
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
          final ws = await WebSocket.connect(wsUrl).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Connexion timeout'),
          );
          _ws = ws;
          _tlog('Connecté — URL publique : $relayBaseUrl');
          onUrlChanged?.call(relayBaseUrl);

          await for (final raw in ws) {
            if (!_running) break;
            if (raw is! String) continue;
            try {
              final Map<String, dynamic> msg = jsonDecode(raw);
              _handleRequest(msg);
            } catch (e) {
              _tlogErr('Message invalide : $e');
            }
          }
        } on TimeoutException catch (e) {
          _tlogErr('Timeout connexion : $e');
          if (_running) onError?.call('Relay timeout : $e');
        } catch (e) {
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

        _tlog('Forward $method $fullPath');

        try {
          final reqHeaders = <String, String>{
            'Content-Type': 'application/json',
          };

          http.Response response;
          switch (method) {
            case 'POST':
              response = await http
                  .post(uri, headers: reqHeaders, body: bodyStr ?? '')
                  .timeout(_requestTimeout);
            case 'PUT':
              response = await http
                  .put(uri, headers: reqHeaders, body: bodyStr ?? '')
                  .timeout(_requestTimeout);
            case 'DELETE':
              response = await http
                  .delete(uri, headers: reqHeaders)
                  .timeout(_requestTimeout);
            default:
              response =
                  await http.get(uri, headers: reqHeaders).timeout(_requestTimeout);
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
    