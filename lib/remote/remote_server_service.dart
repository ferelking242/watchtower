import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:flutter/foundation.dart';
  import 'package:shelf/shelf.dart';
  import 'package:shelf/shelf_io.dart' as shelf_io;
  import 'package:shelf_router/shelf_router.dart';
  import 'package:watchtower/remote/remote_api_handler.dart';
  import 'package:watchtower/remote/tunnel_service.dart';

  class RemoteServerService {
    RemoteServerService._();
    static final RemoteServerService instance = RemoteServerService._();

    Object? _server;
    TunnelService? _tunnel;
    bool _running = false;
    String? _localUrl;
    String? _tunnelUrl;
    String? _tunnelError;
    double? _downloadProgress;

    bool get isRunning => _running;
    String? get localUrl => _localUrl;
    String? get tunnelUrl => _tunnelUrl;
    String? get tunnelError => _tunnelError;
    double? get downloadProgress => _downloadProgress;

    final List<VoidCallback> _listeners = [];
    void addListener(VoidCallback cb) => _listeners.add(cb);
    void removeListener(VoidCallback cb) => _listeners.remove(cb);
    void _notify() { for (final cb in _listeners) cb(); }

    Future<void> start(RemoteApiHandler handler) async {
      if (kIsWeb) return;
      if (_running) return;

      final router = Router();

      Response cors(Response r) => r.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });

      Response options(Request r) => Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });

      // ── Page d'accueil — ouvrir http://[IP]:4567 dans un navigateur ──────
      router.get('/', (Request req) async {
        final lanUrl = _localUrl ?? 'http://${req.requestedUri.host}:4567';
        final tunnelHtml = _tunnelUrl != null
            ? '<p>🌐 <strong>Lien public (tunnel)</strong> : <a href="$_tunnelUrl">$_tunnelUrl</a></p>'
            : '<p>⏳ Tunnel SSH en cours de démarrage…</p>';
        final html = \'\'\'<!DOCTYPE html>
  <html lang="fr">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Watchtower — Serveur actif</title>
    <style>
      body { font-family: sans-serif; max-width: 560px; margin: 48px auto; padding: 0 24px; background: #111; color: #eee; }
      h1 { color: #7c6ef2; }
      a { color: #a5b4fc; }
      .box { background: #1e1e2e; border-radius: 12px; padding: 20px; margin: 20px 0; }
      code { background: #2a2a3d; padding: 2px 6px; border-radius: 4px; }
      .ok { color: #4ade80; }
      .btn { display:inline-block; background:#7c6ef2; color:#fff; padding:10px 20px;
             border-radius:8px; text-decoration:none; margin-top:12px; }
    </style>
  </head>
  <body>
    <h1>🗼 Watchtower</h1>
    <p class="ok">✅ Serveur actif — port 4567</p>

    <div class="box">
      <p>📡 <strong>Lien local (même Wi-Fi)</strong> : <code>$lanUrl</code></p>
      $tunnelHtml
    </div>

    <div class="box">
      <strong>Comment utiliser depuis un navigateur :</strong>
      <ol>
        <li>Ouvrez <a href="https://ferelking242.github.io/watchtower" target="_blank">ferelking242.github.io/watchtower</a></li>
        <li>Collez le <strong>lien public HTTPS</strong> (tunnel) dans le champ URL</li>
        <li>Appuyez sur Connecter</li>
      </ol>
      <p>⚠️ Le lien local <code>http://</code> ne fonctionnera pas depuis le site
      (page HTTPS → requêtes HTTP bloquées par le navigateur).</p>
      <a class="btn" href="https://ferelking242.github.io/watchtower" target="_blank">Ouvrir l'app web</a>
    </div>

    <div class="box">
      <strong>Test API :</strong>
      <a href="/api/ping">/api/ping</a> —
      <a href="/api/sources">/api/sources</a>
    </div>
  </body>
  </html>\'\'\';
        return cors(Response.ok(html,
            headers: {'Content-Type': 'text/html; charset=utf-8'}));
      });

      // ── API routes ───────────────────────────────────────────────────────
      router.get('/api/ping', (_) async =>
          cors(Response.ok(jsonEncode({'ok': true, 'app': 'Watchtower'}),
              headers: {'Content-Type': 'application/json'})));
      router.get('/api/sources', (Request req) async =>
          cors(await handler.getSources(req)));
      router.get('/api/source/<sourceId>/popular', (Request req, String sourceId) async =>
          cors(await handler.getPopular(req, sourceId)));
      router.get('/api/source/<sourceId>/latest', (Request req, String sourceId) async =>
          cors(await handler.getLatest(req, sourceId)));
      router.get('/api/source/<sourceId>/search', (Request req, String sourceId) async =>
          cors(await handler.search(req, sourceId)));
      router.get('/api/manga/<sourceId>/<mangaId>', (Request req, String sourceId, String mangaId) async =>
          cors(await handler.getMangaDetail(req, sourceId, mangaId)));
      router.get('/api/manga/<sourceId>/<mangaId>/chapters', (Request req, String sourceId, String mangaId) async =>
          cors(await handler.getMangaChapters(req, sourceId, mangaId)));
      router.get('/api/chapter/<chapterId>/pages', (Request req, String chapterId) async =>
          cors(await handler.getChapterPages(req, chapterId)));
      router.get('/api/library', (Request req) async =>
          cors(await handler.getLibrary(req)));
      router.get('/api/history', (Request req) async =>
          cors(await handler.getHistory(req)));
      router.get('/api/proxy', (Request req) async =>
          cors(await handler.proxyImage(req)));
      router.add('OPTIONS', '/<path|.*>', options);

      final pipeline = const Pipeline().addHandler(router.call);

      _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, 4567);
      _localUrl = 'http://${await _getLanIp()}:4567';
      _running = true;
      _tunnelError = null;
      _downloadProgress = null;
      _notify();

      _tunnel = TunnelService();
      _tunnel!.onUrlChanged = (url) {
        _tunnelUrl = url;
        _downloadProgress = null;
        _notify();
      };
      _tunnel!.onError = (err) {
        _tunnelError = err;
        _downloadProgress = null;
        _notify();
      };
      _tunnel!.onDownloadProgress = (progress) {
        _downloadProgress = progress;
        _notify();
      };
      await _tunnel!.start();
    }

    Future<String> _getLanIp() async {
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      } catch (_) {}
      return 'localhost';
    }

    Future<void> stop() async {
      _tunnel?.stop();
      _tunnel = null;
      if (_server != null) {
        await (_server as dynamic).close(force: true);
      }
      _server = null;
      _running = false;
      _localUrl = null;
      _tunnelUrl = null;
      _tunnelError = null;
      _downloadProgress = null;
      _notify();
    }
  }
  