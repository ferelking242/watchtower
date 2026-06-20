import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:dartssh2/dartssh2.dart';
  import 'package:flutter/foundation.dart';
  import 'package:watchtower/utils/log/log.dart';

  void _log(String msg) => Logger.add(LoggerLevel.info, '[TUNNEL] $msg');
  void _logErr(String msg) => Logger.add(LoggerLevel.error, '[TUNNEL] $msg');

  class TunnelService {
    SSHClient? _client;
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
        _log('Forwarding port 80 OK — ouverture session shell...');

        final session = await _client!.shell();
        _log('Session ouverte — attente URL lhr.life...');

        // Collecte tout l output en buffer + parsing temps reel
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

        // Quand la session ferme : chercher l URL dans le buffer complet
        // localhost.run ferme le shell apres envoi URL — c est NORMAL
        session.done.then((_) {
          final code = session.exitCode;
          _log('Session fermee (exit=$code) — parsing buffer complet...');
          _parseFullBuffer();
        });

        // Timeout 60s
        Future.delayed(const Duration(seconds: 60), () {
          if (_running && !_urlReceived) {
            final buf = _outputBuffer.toString();
            _logErr('Timeout 60s. Buffer recu:');
            // Log le buffer par tranches de 200 chars
            for (var i = 0; i < buf.length; i += 200) {
              _logErr(buf.substring(i, i + 200 > buf.length ? buf.length : i + 200));
            }
            onError?.call('Timeout (60s) — localhost.run n\'a pas envoye de lien tunnel.\nVerifiez Internet.');
          }
        });

        _handleForwardedConnections(forward);
      } catch (e) {
        _logErr('Exception: $e');
        _running = false;
        onError?.call('Tunnel SSH : $e');
      }
    }

    // Parsing en temps reel : seulement *.lhr.life, JAMAIS localhost.run URLs
    void _parseLineRealtime(String line) {
      if (line.trim().isEmpty) return;
      final match = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(line);
      if (match != null) {
        final url = match.group(0)!;
        if (!_urlReceived) {
          _urlReceived = true;
          _log('URL trouvee (realtime) : $url');
          onUrlChanged?.call(url);
        }
      }
    }

    // Parsing du buffer complet apres fermeture session
    void _parseFullBuffer() {
      if (_urlReceived) return;
      final full = _outputBuffer.toString();

      // Cherche d abord *.lhr.life
      final lhr = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(full);
      if (lhr != null) {
        _urlReceived = true;
        _log('URL trouvee (post-session lhr) : ${lhr.group(0)}');
        onUrlChanged?.call(lhr.group(0)!);
        return;
      }

      // Cherche toute URL HTTPS sauf localhost.run
      final all = RegExp(r'https://[^\s\n,]+').allMatches(full);
      for (final m in all) {
        final url = m.group(0)!;
        if (!url.contains('localhost.run') && !url.contains('lhr.life/') == false) {
          _urlReceived = true;
          _log('URL trouvee (post-session fallback) : $url');
          onUrlChanged?.call(url);
          return;
        }
      }

      _log('Aucune URL lhr.life dans le buffer — tunnel peut etre actif sans URL');
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
          _logErr('Connexion SSH perdue');
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
      try {
        final local = await Socket.connect('127.0.0.1', _localPort);
        connection.stream.cast<List<int>>().pipe(local);
        local.cast<List<int>>().pipe(connection.sink);
      } catch (_) {
        try { await connection.close(); } catch (_) {}
      }
    }

    void stop() {
      _log('Arret');
      _running = false;
      _urlReceived = false;
      _outputBuffer.clear();
      _client?.close();
      _client = null;
    }
  }
  