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
        _log('Authentifie ! Demande forwarding inverse...');
        _running = true;

        final forward = await _client!.forwardRemote();
        if (forward == null) {
          _logErr('Forwarding refuse par localhost.run');
          _running = false;
          _client?.close();
          _client = null;
          onError?.call('localhost.run : forwarding refuse');
          return;
        }
        _log('Forwarding OK — ouverture session shell...');

        final session = await _client!.shell();
        _log('Session shell ouverte — attente URL...');

        session.stdout
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((line) {
              if (line.trim().isNotEmpty) _log('stdout: $line');
              _parseUrlLine(line);
            }, onError: (e) => _logErr('stdout err: $e'));

        session.stderr
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((line) {
              if (line.trim().isNotEmpty) _log('stderr: $line');
              _parseUrlLine(line);
            }, onError: (e) => _logErr('stderr err: $e'));

        session.done.then((_) {
          final code = session.exitCode;
          _log('Session fermee (exit=$code) — tunnel reste actif');
        });

        Future.delayed(const Duration(seconds: 45), () {
          if (_running && !_urlReceived) {
            _logErr('Timeout 45s : aucune URL recue');
            onError?.call('Timeout (45s) — localhost.run n\'a pas envoye d\'URL.\nVerifiez Internet.');
          }
        });

        _handleForwardedConnections(forward);
      } catch (e) {
        _logErr('Exception: $e');
        _running = false;
        onError?.call('Tunnel SSH : $e');
      }
    }

    void _parseUrlLine(String line) {
      if (line.trim().isEmpty) return;
      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final address = data['address'] as String?;
        if (address != null) {
          _urlReceived = true;
          final url = 'https://$address';
          _log('URL (JSON) : $url');
          onUrlChanged?.call(url);
          return;
        }
      } catch (_) {}

      final match = RegExp(r'https?://[a-z0-9-]+\.lhr\.life').firstMatch(line);
      if (match != null) {
        final url = match.group(0)!;
        _urlReceived = true;
        _log('URL (lhr.life) : $url');
        onUrlChanged?.call(url);
        return;
      }

      final fallback = RegExp(r'https://[^\s,]+').firstMatch(line);
      if (fallback != null) {
        final url = fallback.group(0)!;
        _urlReceived = true;
        _log('URL (fallback) : $url');
        onUrlChanged?.call(url);
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
      _client?.close();
      _client = null;
    }
  }
  