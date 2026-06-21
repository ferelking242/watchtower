import 'dart:async';
    import 'dart:convert';
    import 'dart:typed_data';
    import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
    import 'package:dartssh2/dartssh2.dart';
    import 'package:flutter/foundation.dart';
    import 'package:watchtower/utils/log/logger.dart';

    void _log(String msg) => AppLogger.log('[TUNNEL] $msg', tag: 'REMOTE');
    void _logErr(String msg) =>
        AppLogger.log('[TUNNEL] $msg', tag: 'REMOTE', logLevel: LogLevel.error);

    // localhost.run ferme le shell ~15s apres le dernier keepalive SSH.
    // Le keepalive STDIN (newline) causait ECONNABORTED car le shell interprète les newlines.
    // → On utilise keepAliveInterval natif dartssh2 (keepalive@openssh.com, RFC 4254).

    class TunnelService {
      SSHClient? _client;
      SSHSession? _shellSession;
      Timer? _reconnectTimer;
      bool _running = false;
      bool _urlReceived = false;
      final StringBuffer _outputBuffer = StringBuffer();

      void Function(String url)? onUrlChanged;
      void Function(String error)? onError;
      void Function(double progress)? onDownloadProgress;

      static const _sshHost = 'localhost.run';
      static const _sshPort = 22;
      static const _localPort = 4567;

      Future<void> start() async {
        if (kIsWeb) return;
        if (_running) return;
        _running = true;
        _urlReceived = false;
        _outputBuffer.clear();
        await _connect();
      }

      Future<void> _connect() async {
        if (!_running) return;

        _shellSession = null;

        try {
          _log('Connexion SSH $_sshHost:$_sshPort...');
          final socket = await SSHSocket.connect(
            _sshHost, _sshPort,
            timeout: const Duration(seconds: 30),
          );

          // keepAliveInterval envoie keepalive@openssh.com (SSH global request)
          // toutes les 5s — propre, ne touche pas stdin du shell.
          // printDebug garde la visibilite sur le matching forwarded-tcpip.
          _client = SSHClient(
            socket,
            username: 'nokey',
            disableHostkeyVerification: true,
            keepAliveInterval: const Duration(seconds: 5),
            printDebug: (msg) => _log('SSH: $msg'),
          );

          _log('Socket OK — authentification...');
          await _client!.authenticated;
          _log('Authentifie ! Demande forwarding port 80...');

          final forward = await _client!.forwardRemote(port: 80);
          if (forward == null) {
            _logErr('Forwarding refuse — reconnexion dans 5s...');
            _cleanupClient();
            _scheduleReconnect(delay: const Duration(seconds: 5));
            return;
          }
          _log('Forwarding OK — ouverture shell...');

          final session = await _client!.shell();
          _shellSession = session;
          _log('Shell ouverte — attente URL lhr.life...');

          session.stdout
              .cast<List<int>>()
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())
              .listen((line) {
                _outputBuffer.writeln(line);
                if (line.trim().isNotEmpty) _log('out: $line');
                _parseLineRealtime(line);
              }, onError: (e) => _logErr('stdout err: $e'));

          session.stderr
              .cast<List<int>>()
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())
              .listen((line) {
                _outputBuffer.writeln(line);
                if (line.trim().isNotEmpty) _log('err: $line');
                _parseLineRealtime(line);
              }, onError: (e) => _logErr('stderr err: $e'));

          session.done.then((_) {
            _log('Shell fermee — reconnexion dans 2s...');
            _shellSession = null;
            _cleanupClient();
            _scheduleReconnect(delay: const Duration(seconds: 2));
          });

          Future.delayed(const Duration(seconds: 60), () {
            if (_running && !_urlReceived) {
              _logErr('Timeout 60s — pas d URL recue');
              onError?.call("Timeout (60s) — localhost.run n'a pas envoye de lien.");
            }
          });

          _handleForwardedConnections(forward);
        } catch (e) {
          _logErr('Exception connexion: $e');
          _cleanupClient();
          _scheduleReconnect(delay: const Duration(seconds: 5));
        }
      }

      void _handleForwardedConnections(SSHRemoteForward forward) async {
        _log('En attente de connexions entrantes...');
        try {
          var connCount = 0;
          await for (final connection in forward.connections) {
            connCount++;
            _log('Connexion entrante #$connCount');
            _proxyConnection(connection);
          }
        } catch (e) {
          if (_running) _logErr('Forward erreur: $e');
        }
        _log('Forward stream ferme');
      }

      void _scheduleReconnect({Duration delay = const Duration(seconds: 5)}) {
        if (!_running) return;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(delay, () {
          if (_running) _connect();
        });
      }

      void _cleanupClient() {
        _shellSession = null;
        try { _client?.close(); } catch (_) {}
        _client = null;
      }

      void _parseLineRealtime(String line) {
        if (line.trim().isEmpty) return;
        final match = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(line);
        if (match != null) {
          final url = match.group(0)!;
          _log('URL trouvee : $url');
          _urlReceived = true;
          onUrlChanged?.call(url);
        }
      }

      void _proxyConnection(SSHForwardChannel connection) async {
        Socket? local;
        try {
          local = await Socket.connect('127.0.0.1', _localPort);
          _log('Proxy: 127.0.0.1:$_localPort connecte');

          var done = false;
          void closeAll() {
            if (done) return;
            done = true;
            try { local!.destroy(); } catch (_) {}
            try { connection.close(); } catch (_) {}
          }

          connection.stream.cast<List<int>>().listen(
            local.add,
            onDone: closeAll,
            onError: (e) { _logErr('Proxy SSH->local: $e'); closeAll(); },
            cancelOnError: true,
          );

          local.listen(
            (data) => connection.sink.add(data),
            onDone: closeAll,
            onError: (e) { _logErr('Proxy local->SSH: $e'); closeAll(); },
            cancelOnError: true,
          );
        } catch (e) {
          _logErr('Proxy 127.0.0.1:$_localPort echoue: $e');
          try { local?.destroy(); } catch (_) {}
          try { connection.close(); } catch (_) {}
        }
      }

      void stop() {
        _log('Arret tunnel');
        _running = false;
        _urlReceived = false;
        _outputBuffer.clear();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _cleanupClient();
      }
    }
  