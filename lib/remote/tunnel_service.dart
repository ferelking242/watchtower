
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// Tunnel public via localhost.run — SSH pur-Dart, aucun binaire à télécharger.
/// Fonctionne sur Android sans problème de permission (partition noexec).
/// Usage : ssh -R 80:localhost:4567 nokey@localhost.run
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
        // localhost.run est un service public connu — on accepte sa clé
        onVerifyHostKey: (hostKey) => true,
      );

      await _client!.authenticated;
      _running = true;

      // Demande de forwarding inverse : connexions internet → notre serveur local
      final remoteForward = await _client!.forwardRemote();

      // Exécution avec --json pour recevoir l'URL assignée en JSON sur stdout
      final session = await _client!.execute('-- --json');

      session.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_parseUrlLine, onError: (_) {});

      // Fallback stderr (certaines versions de localhost.run y écrivent l'URL)
      session.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_parseUrlLine, onError: (_) {});

      session.exitCode.then((code) {
        if (_running) onError?.call('Tunnel SSH fermé (code $code)');
        _running = false;
      });

      // Forward chaque connexion entrante → serveur HTTP local
      _handleForwardedConnections(remoteForward);
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
    final match =
        RegExp(r'https://[a-z0-9\-]+\.lhr\.life').firstMatch(line);
    if (match != null) onUrlChanged?.call(match.group(0)!);
  }

  void _handleForwardedConnections(SSHRemoteForward forward) async {
    try {
      await for (final channel in forward.stream) {
        _proxyChannel(channel);
      }
    } catch (_) {}
  }

  void _proxyChannel(SSHForwardChannel channel) async {
    try {
      final local = await Socket.connect('127.0.0.1', _localPort);
      // Bidirectionnel : internet ↔ serveur local
      channel.pipe(local);
      local.pipe(channel.sink);
    } catch (_) {
      try {
        channel.sink.close();
      } catch (_) {}
    }
  }

  void stop() {
    _running = false;
    _client?.close();
    _client = null;
  }
}
