
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:watchtower/remote/remote_api_handler.dart';
import 'package:watchtower/remote/tunnel_service.dart';

/// Singleton service that manages the HTTP server lifecycle.
class RemoteServerService {
  RemoteServerService._();
  static final RemoteServerService instance = RemoteServerService._();

  HttpServer? _server;
  TunnelService? _tunnel;
  bool _running = false;
  String? _localUrl;
  String? _tunnelUrl;

  bool get isRunning => _running;
  String? get localUrl => _localUrl;
  String? get tunnelUrl => _tunnelUrl;

  // Listeners for UI updates
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() { for (final cb in _listeners) cb(); }

  Future<void> start(RemoteApiHandler handler) async {
    if (kIsWeb) return;
    if (_running) return;

    final router = Router();

    // CORS middleware
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

    // ── Routes ─────────────────────────────────────────────────────────────
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

    // OPTIONS preflight for all routes
    router.add('OPTIONS', '/<path|.*>', options);

    final pipeline = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, 4567);
    _localUrl = 'http://localhost:4567';
    _running = true;
    _notify();

    // Start tunnel
    _tunnel = TunnelService();
    _tunnel!.onUrlChanged = (url) {
      _tunnelUrl = url;
      _notify();
    };
    await _tunnel!.start();
  }

  Future<void> stop() async {
    _tunnel?.stop();
    _tunnel = null;
    await _server?.close(force: true);
    _server = null;
    _running = false;
    _localUrl = null;
    _tunnelUrl = null;
    _notify();
  }
}
