import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:dartssh2/dartssh2.dart';
  import 'package:flutter/foundation.dart';

  /// Tunnel public via localhost.run — SSH pur-Dart, aucun binaire.
  ///
  /// Séquence correcte :
  ///   1. forwardRemote(remotePort: 80)  → localhost.run assigne un sous-domaine
  ///   2. shell()                         → localhost.run envoie l'URL dans cette session
  ///   3. _handleForwardedConnections()   → proxy TCP vers le serveur HTTP local
  ///
  /// IMPORTANT : ne pas utiliser execute() — localhost.run peut rejeter les
  /// requêtes exec. La session shell suffit pour recevoir l'URL.
  class TunnelService {
    SSHClient? _client;
    bool _running = false;

    void Function(String url)? onUrlChanged;
    void Function(String error)? onError;
    /// Gardé pour compatibilité API — plus utilisé (plus de téléchargement).
    void Function(double progress)? onDownloadProgress;

    static const _sshHost = 'localhost.run';
    static const _sshPort = 22;
    static const _localPort = 4567;

    Future<void> start() async {
      if (kIsWeb) return;
      if (_running) return;

      try {
        final socket = await SSHSocket.connect(
          _sshHost,
          _sshPort,
          timeout: const Duration(seconds: 30),
        );

        _client = SSHClient(
          socket,
          username: 'nokey',
          // localhost.run est un service public — vérification de clé inutile
          disableHostkeyVerification: true,
        );

        await _client!.authenticated;
        _running = true;

        // ── Étape 1 : demander le forwarding inverse ─────────────────────────
        // forwardRemote() envoie SSH_MSG_GLOBAL_REQUEST "tcpip-forward".
        // localhost.run assigne un sous-domaine unique (*.lhr.life) et expose
        // les connexions entrantes sur remotePort: 80.
        // DOIT être fait AVANT d'ouvrir la session shell.
        final forward = await _client!.forwardRemote(remotePort: 80);
        if (forward == null) {
          onError?.call('localhost.run : forwarding refusé par le serveur');
          _running = false;
          _client?.close();
          _client = null;
          return;
        }

        // ── Étape 2 : ouvrir une session shell ───────────────────────────────
        // localhost.run envoie l'URL assignée dans cette session (stdout/stderr).
        // On utilise shell() et non execute() pour éviter le rejet exec.
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

        session.done.then((_) {
          if (_running) {
            onError?.call('Tunnel SSH fermé (code ${session.exitCode ?? -1})');
          }
          _running = false;
        });

        // ── Étape 3 : proxy TCP ──────────────────────────────────────────────
        // Chaque connexion entrante depuis localhost.run est relayée vers
        // le serveur HTTP local (127.0.0.1:4567).
        _handleForwardedConnections(forward);
      } catch (e) {
        _running = false;
        onError?.call('Tunnel SSH : $e');
      }
    }

    void _parseUrlLine(String line) {
      if (line.trim().isEmpty) return;
      // Format principal localhost.run : https://abc123.lhr.life
      final match = RegExp(r'https?://[a-z0-9\-]+\.lhr\.life').firstMatch(line);
      if (match != null) {
        onUrlChanged?.call(match.group(0)!);
        return;
      }
      // Fallback : toute URL HTTPS dans la ligne (au cas où le format change)
      final fallback = RegExp(r'https://\S+').firstMatch(line);
      if (fallback != null) {
        onUrlChanged?.call(
          fallback.group(0)!.replaceAll(RegExp(r'[,\.\s]+$'), ''),
        );
      }
    }

    void _handleForwardedConnections(SSHRemoteForward forward) async {
      try {
        await for (final connection in forward.connections) {
          _proxyConnection(connection);
        }
      } catch (_) {}
    }

    void _proxyConnection(SSHForwardChannel connection) async {
      try {
        final local = await Socket.connect('127.0.0.1', _localPort);
        connection.stream.cast<List<int>>().pipe(local);
        local.cast<List<int>>().pipe(connection.sink);
      } catch (_) {
        try {
          await connection.close();
        } catch (_) {}
      }
    }

    void stop() {
      _running = false;
      _client?.close();
      _client = null;
    }
  }
  