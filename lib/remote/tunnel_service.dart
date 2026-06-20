
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// Tunnel public via localhost.run — SSH pur-Dart, aucun binaire à télécharger.
/// Fonctionne sur Android sans problème de permission (partition noexec).
/// Remplace cloudflared (30 Mo, Permission denied sur Android).
class TunnelService {
  SSHClient? _client;
  bool _running = false;

  void Function(String url)? onUrlChanged;
  void Function(String error)? onError;
  // Gardé pour compatibilité API — plus utilisé (plus de téléchargement)
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
        // localhost.run est un service public — on désactive la vérification de clé hôte
        disableHostkeyVerification: true,
      );

      await _client!.authenticated;
      _running = true;

      // Exécution avec --json pour recevoir l'URL assignée sur stdout
      final session = await _client!.execute('-- --json');

      session.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_parseUrlLine, onError: (_) {});

      // Fallback stderr
      session.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_parseUrlLine, onError: (_) {});

      session.exitCode.then((code) {
        if (_running) onError?.call('Tunnel SSH fermé (code $code)');
        _running = false;
      });

      // Forwarding inverse : connexions internet → serveur HTTP local
      // Port 0 = localhost.run choisit le port et assigne un sous-domaine
      final forward = await _client!.forwardRemote();
      if (forward == null) {
        onError?.call('Tunnel SSH : forwardRemote refusé par le serveur');
        return;
      }

      _handleForwardedConnections(forward);
    } catch (e) {
      _running = false;
      onError?.call('Tunnel SSH indisponible : $e');
    }
  }

  void _parseUrlLine(String line) {
    if (line.trim().isEmpty) return;
    // Tentative JSON (mode --json)
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final address = data['address'] as String?;
      if (address != null) {
        onUrlChanged?.call('https://$address');
        return;
      }
    } catch (_) {}
    // Fallback regex : "https://abc123.lhr.life"
    final match = RegExp(r'https://[a-z0-9\-]+\.lhr\.life').firstMatch(line);
    if (match != null) onUrlChanged?.call(match.group(0)!);
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
      // Bidirectionnel : internet ↔ serveur local
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
