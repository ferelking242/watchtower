import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:dartssh2/dartssh2.dart';
  import 'package:flutter/foundation.dart';

  /// Tunnel public via localhost.run — SSH pur-Dart, aucun binaire.
  ///
  /// Comportement localhost.run :
  ///   1. SSH connect → forwardRemote() → localhost.run assigne *.lhr.life
  ///   2. shell()     → localhost.run ENVOIE L'URL puis FERME LA SESSION (normal !)
  ///   3. Le tunnel forwardRemote reste ACTIF même après la fermeture du shell
  ///   4. Chaque connexion entrante est relayée vers localhost:4567
  class TunnelService {
    SSHClient? _client;
    bool _running = false;
    bool _urlReceived = false;

    void Function(String url)? onUrlChanged;
    void Function(String error)? onError;
    void Function(double progress)? onDownloadProgress; // gardé pour compatibilité

    static const _sshHost = 'localhost.run';
    static const _sshPort = 22;
    static const _localPort = 4567;

    Future<void> start() async {
      if (kIsWeb) return;
      if (_running) return;
      _urlReceived = false;

      try {
        final socket = await SSHSocket.connect(
          _sshHost, _sshPort,
          timeout: const Duration(seconds: 30),
        );

        _client = SSHClient(
          socket,
          username: 'nokey',
          disableHostkeyVerification: true,
        );

        await _client!.authenticated;
        _running = true;

        // ── Étape 1 : forwarding inverse ────────────────────────────────────
        // DOIT précéder l'ouverture de la session shell.
        final forward = await _client!.forwardRemote();
        if (forward == null) {
          _running = false;
          _client?.close();
          _client = null;
          onError?.call('localhost.run : forwarding refusé');
          return;
        }

        // ── Étape 2 : session shell pour recevoir l'URL ──────────────────────
        // localhost.run FERME la session shell après avoir envoyé l'URL (code -1).
        // C'est un comportement NORMAL — ne pas interpréter comme une erreur.
        // Le tunnel forwardRemote reste actif indépendamment de la session.
        final session = await _client!.shell();

        session.stdout
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(_parseUrlLine, onError: (_) {});

        session.stderr
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(_parseUrlLine, onError: (_) {});

        // session.done : fermeture normale du shell après envoi URL — ignorer.
        session.done.then((_) {
          // localhost.run ferme le canal shell après avoir envoyé l'URL.
          // Le tunnel forwardRemote reste actif. On ne fait rien ici.
        });

        // ── Timeout 45s si aucune URL reçue ─────────────────────────────────
        Future.delayed(const Duration(seconds: 45), () {
          if (_running && !_urlReceived) {
            onError?.call(
              'Timeout : localhost.run n\'a pas envoyé d\'URL (45s). '
              'Vérifiez votre connexion Internet.',
            );
          }
        });

        // ── Étape 3 : proxy TCP + détection perte de connexion ───────────────
        // La stream forward.connections se ferme quand le client SSH déconnecte.
        _handleForwardedConnections(forward);
      } catch (e) {
        _running = false;
        onError?.call('Tunnel SSH : $e');
      }
    }

    void _parseUrlLine(String line) {
      if (line.trim().isEmpty) return;
      // Tentative JSON (mode --json si supporté)
      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final address = data['address'] as String?;
        if (address != null) {
          _urlReceived = true;
          onUrlChanged?.call('https://$address');
          return;
        }
      } catch (_) {}
      // Regex : *.lhr.life (format texte localhost.run)
      final match = RegExp(r'https?://[a-z0-9\-]+\.lhr\.life').firstMatch(line);
      if (match != null) {
        _urlReceived = true;
        onUrlChanged?.call(match.group(0)!);
        return;
      }
      // Fallback : toute URL HTTPS dans la ligne
      final fallback = RegExp(r'https://\S+').firstMatch(line);
      if (fallback != null) {
        final url = fallback.group(0)!.replaceAll(RegExp(r'[,\.\s]+$'), '');
        _urlReceived = true;
        onUrlChanged?.call(url);
      }
    }

    void _handleForwardedConnections(SSHRemoteForward forward) async {
      try {
        await for (final connection in forward.connections) {
          _proxyConnection(connection);
        }
        // La stream est fermée = SSH client déconnecté = tunnel mort
        if (_running) {
          onError?.call('Tunnel SSH : connexion perdue — réactivez le Mode Distant');
        }
        _running = false;
      } catch (e) {
        if (_running) onError?.call('Tunnel SSH : $e');
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
      _running = false;
      _urlReceived = false;
      _client?.close();
      _client = null;
    }
  }
  