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

  class TunnelService {
    SSHClient? _client;
    SSHSession? _shellSession;
    Timer? _keepAliveTimer;
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
      _urlReceived = false;
      _outputBuffer.clear();

      try {
        _log('Connexion SSH $_sshHost:$_sshPort...');
        final socket = await SSHSocket.connect(
          _sshHost, _sshPort,
          timeout: const Duration(seconds: 30),
        );

        _client = SSHClient(
          socket,
          username: 'nokey',
          disableHostkeyVerification: true,
        );

        _log('Socket OK — authentification...');
        await _client!.authenticated;
        _log('Authentifie ! Demande forwarding port 80...');
        _running = true;

        final forward = await _client!.forwardRemote(port: 80);
        if (forward == null) {
          _logErr('Forwarding refuse par localhost.run');
          _running = false;
          _client?.close();
          _client = null;
          onError?.call('localhost.run : forwarding refuse');
          return;
        }
        _log('Forwarding port 80 OK — ouverture shell...');

        await _openShell();

        // Keepalive stdin toutes les 5s — ecrit AVANT la fermeture idle (~18s).
        // localhost.run ferme le shell quand stdin est inactif.
        // En ecrivant toutes les 5s, on empeche ce timeout.
        // Si le shell ferme quand meme, _reopenShell() le rouvre immediatement.
        _keepAliveTimer?.cancel();
        _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!_running) return;
          _log('Keepalive stdin — shell actif: ${_shellSession != null}');
          try { _shellSession?.stdin.add(Uint8List.fromList([10])); } catch (_) {}
        });

        // Timeout 60s pour recevoir l'URL
        Future.delayed(const Duration(seconds: 60), () {
          if (_running && !_urlReceived) {
            final buf = _outputBuffer.toString();
            _logErr('Timeout 60s. Buffer:');
            for (var i = 0; i < buf.length; i += 200) {
              _logErr(buf.substring(i, i + 200 > buf.length ? buf.length : i + 200));
            }
            onError?.call("Timeout (60s) — localhost.run n'a pas envoye de lien.\nVerifiez Internet.");
          }
        });

        _handleForwardedConnections(forward);
      } catch (e) {
        _logErr('Exception: $e');
        _running = false;
        onError?.call('Tunnel SSH : $e');
      }
    }

    Future<void> _openShell() async {
      if (_client == null || !_running) return;
      try {
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
          final code = session.exitCode;
          _log('Shell fermee (exit=$code) — reouverture immediate...');
          _parseFullBuffer();
          _shellSession = null;
          // Rouvrir immediatement : localhost.run deregistre le tunnel si plus de shell.
          _reopenShell();
        });
      } catch (e) {
        _logErr('Erreur ouverture shell: $e');
        _shellSession = null;
        _reopenShell();
      }
    }

    void _reopenShell() {
      if (!_running || _client == null) return;
      Future.delayed(const Duration(seconds: 1), () {
        if (_running && _client != null) {
          _log('Reouverture shell...');
          _openShell();
        }
      });
    }

    void _parseLineRealtime(String line) {
      if (line.trim().isEmpty) return;
      final match = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(line);
      if (match != null) {
        final url = match.group(0)!;
        if (!_urlReceived) {
          _urlReceived = true;
          _log('URL trouvee : $url');
          onUrlChanged?.call(url);
        }
      }
    }

    void _parseFullBuffer() {
      if (_urlReceived) return;
      final full = _outputBuffer.toString();

      final lhr = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(full);
      if (lhr != null) {
        _urlReceived = true;
        _log('URL trouvee (buffer) : ${lhr.group(0)}');
        onUrlChanged?.call(lhr.group(0)!);
        return;
      }

      final all = RegExp(r'https://[^\s\n,]+').allMatches(full);
      for (final m in all) {
        final url = m.group(0)!;
        if (!url.contains('localhost.run')) {
          _urlReceived = true;
          _log('URL trouvee (fallback) : $url');
          onUrlChanged?.call(url);
          return;
        }
      }

      _log('Aucune URL lhr.life dans le buffer');
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
        if (_running) {
          _logErr('Connexion SSH perdue (forward.connections ferme)');
          onError?.call('Tunnel ferme — reactivez le Mode Distant');
        }
        _running = false;
      } catch (e) {
        if (_running) {
          _logErr('Erreur forward: $e');
          onError?.call('Tunnel SSH : $e');
        }
        _running = false;
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
        _logErr('Proxy connexion 127.0.0.1:$_localPort echouee: $e');
        try { local?.destroy(); } catch (_) {}
        try { connection.close(); } catch (_) {}
      }
    }

    void stop() {
      _log('Arret tunnel');
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      _running = false;
      _urlReceived = false;
      _outputBuffer.clear();
      _shellSession = null;
      _client?.close();
      _client = null;
    }
  }
