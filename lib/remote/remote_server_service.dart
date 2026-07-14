import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'dart:math';
  import 'package:flutter/foundation.dart';
  import 'package:hive/hive.dart';
  import 'package:shelf/shelf.dart';
  import 'package:shelf/shelf_io.dart' as shelf_io;
  import 'package:shelf_router/shelf_router.dart';
  import 'package:watchtower/remote/remote_api_handler.dart';
  import 'package:watchtower/remote/tunnel_service.dart';
  import 'package:watchtower/utils/log/logger.dart';

  void _slog(String msg) => AppLogger.log('[SERVER] $msg', tag: 'REMOTE');
  void _slogErr(String msg) => AppLogger.log('[SERVER] $msg', tag: 'REMOTE', logLevel: LogLevel.error);

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
    String? _apiKey;

    bool get isRunning => _running;
    String? get localUrl => _localUrl;
    String? get tunnelUrl => _tunnelUrl;
    String? get tunnelError => _tunnelError;
    double? get downloadProgress => _downloadProgress;
    String? get apiKey => _apiKey;

    // ── API key ──────────────────────────────────────────────────────────
    // Required (as `?key=` or `Authorization: Bearer <key>`) on every
    // `/api/*` route except `/api/ping` — this server can be reached by
    // any third-party app, local or via the public tunnel, so it must not
    // be wide open. Persisted so it survives toggling the server off/on.
    static const _kBox = 'remote_mode';
    static const _kApiKey = 'api_key';

    Future<String> _loadOrCreateApiKey() async {
      final box = await Hive.openBox(_kBox);
      final existing = box.get(_kApiKey) as String?;
      if (existing != null && existing.isNotEmpty) return existing;
      final key = _generateApiKey();
      await box.put(_kApiKey, key);
      return key;
    }

    String _generateApiKey() {
      final rnd = Random.secure();
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
    }

    Future<void> regenerateApiKey() async {
      final box = await Hive.openBox(_kBox);
      final key = _generateApiKey();
      await box.put(_kApiKey, key);
      _apiKey = key;
      _notify();
    }

    final List<VoidCallback> _listeners = [];
    void addListener(VoidCallback cb) => _listeners.add(cb);
    void removeListener(VoidCallback cb) => _listeners.remove(cb);
    void _notify() { for (final cb in _listeners) cb(); }

    // Page HTML avec des placeholders remplacés dynamiquement (pas d'interpolation Dart dans triple-quote)
    static const _htmlTemplate = '''<!DOCTYPE html>
  <html lang="fr">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Watchtower</title>
    <style>
      *{box-sizing:border-box;margin:0;padding:0}
      body{font-family:system-ui,sans-serif;background:#0d0d1a;color:#e0e0ff;
           display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px}
      .wrap{max-width:500px;width:100%}
      .header{display:flex;align-items:center;gap:14px;margin-bottom:24px}
      .icon{width:42px;height:42px;background:#7c3aed;border-radius:50%;
            display:flex;align-items:center;justify-content:center;font-size:1.4rem}
      h1{font-size:1.5rem;color:#a78bfa}
      .badge{font-size:.75rem;background:#16a34a22;color:#4ade80;
             border:1px solid #16a34a44;border-radius:99px;padding:2px 10px;font-weight:600}
      .card{border-radius:12px;padding:16px 18px;margin-bottom:12px;background:#161627;
            border:1px solid #ffffff0f}
      .card.green{background:#052e16;border-color:#16a34a}
      .card.red{background:#2d0a0a;border-color:#dc2626}
      .card.yellow{background:#1c1700;border-color:#ca8a04}
      .label{font-size:.7rem;text-transform:uppercase;letter-spacing:.06em;color:#ffffff55;margin-bottom:6px}
      .url-text{font-size:.95rem;color:#818cf8;word-break:break-all;text-decoration:none}
      .url-text:hover{text-decoration:underline}
      .lan{font-size:.95rem;color:#cbd5e1;word-break:break-all}
      .hint{font-size:.78rem;color:#ffffff44;margin-top:4px}
      .err{font-size:.82rem;color:#f87171;margin-top:4px;word-break:break-word}
      .spinner{width:18px;height:18px;border:2px solid #ca8a0444;
               border-top-color:#ca8a04;border-radius:50%;
               animation:spin 1s linear infinite;margin-top:8px}
      @keyframes spin{to{transform:rotate(360deg)}}
      .steps{list-style:none;counter-reset:s}
      .steps li{counter-increment:s;display:flex;align-items:flex-start;gap:10px;
                padding:8px 0;border-bottom:1px solid #ffffff08;font-size:.88rem}
      .steps li:last-child{border-bottom:none}
      .steps li::before{content:counter(s);min-width:22px;height:22px;background:#7c3aed;
                        border-radius:50%;display:flex;align-items:center;justify-content:center;
                        font-size:.72rem;font-weight:700;flex-shrink:0;margin-top:1px}
      .open-btn{display:block;background:#7c3aed;color:#fff;text-align:center;padding:11px;
                border-radius:9px;text-decoration:none;font-weight:600;margin-top:12px;font-size:.9rem}
      .open-btn:hover{background:#6d28d9}
      .api a{color:#818cf8;text-decoration:none;margin-right:14px;font-size:.8rem}
      .api a:hover{text-decoration:underline}
    </style>
  </head>
  <body>
  <div class="wrap">
    <div class="header">
      <div class="icon">&#128316;</div>
      <div><h1>Watchtower</h1><span class="badge">Serveur actif</span></div>
    </div>

    <div class="card">
      <div class="label">Lien local (meme Wi-Fi)</div>
      <div class="lan">{{LAN}}</div>
      <div class="hint">Accessible uniquement depuis le meme reseau</div>
    </div>

    {{TUNNEL_SECTION}}

    <div class="card">
      <div class="label">Comment utiliser depuis n&apos;importe ou</div>
      <ol class="steps">
        <li>Attendez que le lien relay HTTPS apparaisse ci-dessus</li>
        <li>Copiez ce lien HTTPS</li>
        <li>Ouvrez l&apos;app web et collez-le dans le champ URL</li>
      </ol>
      <a class="open-btn" href="https://ferelking242.github.io/watchtower" target="_blank">
        Ouvrir l&apos;app web Watchtower
      </a>
    </div>

    <div class="card">
      <div class="label">Test API</div>
      <div class="api">
        <a href="/api/ping">/api/ping</a>
        <a href="/api/sources">/api/sources</a>
      </div>
    </div>
  </div>
  <script>
    if (!document.querySelector('.card.green')) setTimeout(() => location.reload(), 5000);
  </script>
  </body>
  </html>''';

    String _buildHomePage() {
      final lan = _localUrl ?? '?';

      final String tunnelSection;
      if (_tunnelUrl != null) {
        final url = _tunnelUrl!;
        tunnelSection =
            '<div class="card green">'
            '<div class="label">Lien public (relay Replit)</div>'
            '<a href="' + url + '" class="url-text">' + url + '</a>'
            '<div class="hint">Utilisez ce lien depuis n&apos;importe ou</div>'
            '</div>';
      } else if (_tunnelError != null) {
        tunnelSection =
            '<div class="card red">'
            '<div class="label">Tunnel indisponible</div>'
            '<div class="err">' + (_tunnelError ?? '') + '</div>'
            '</div>';
      } else {
        tunnelSection =
            '<div class="card yellow">'
            '<div class="label">Relay Replit</div>'
            '<div class="hint">Demarrage en cours...</div>'
            '<div class="spinner"></div>'
            '</div>';
      }

      return _htmlTemplate
          .replaceAll('{{LAN}}', lan)
          .replaceAll('{{TUNNEL_SECTION}}', tunnelSection);
    }

    Future<void> start(RemoteApiHandler handler) async {
      if (kIsWeb) return;
      if (_running) return;

      _slog('Demarrage HTTP port 4567...');
      _apiKey = await _loadOrCreateApiKey();
      final router = Router();

      Response cors(Response r) => r.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
      Response optionsH(Request r) => Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });

      // Every /api/* route (besides /api/ping) requires the API key shown
      // in the Mode Distant screen, passed as `?key=` or a Bearer token.
      Middleware requireApiKey() => (Handler inner) => (Request req) async {
            final path = req.url.path;
            if (!path.startsWith('api/') || path == 'api/ping') {
              return inner(req);
            }
            final auth = req.headers['authorization'];
            final headerKey = (auth != null && auth.startsWith('Bearer '))
                ? auth.substring(7)
                : null;
            final key = req.url.queryParameters['key'] ?? headerKey;
            if (key == null || key != _apiKey) {
              return cors(_unauthorized());
            }
            return inner(req);
          };

      router.get('/', (Request req) async =>
          cors(Response.ok(_buildHomePage(),
              headers: {'Content-Type': 'text/html; charset=utf-8'})));

      router.get('/api/ping', (_) async =>
          cors(Response.ok(jsonEncode({'ok': true, 'app': 'Watchtower'}),
              headers: {'Content-Type': 'application/json'})));
      router.get('/api/sources', (Request req) async => cors(await handler.getSources(req)));
      router.get('/api/source/<sourceId>/popular', (Request req, String sourceId) async =>
          cors(await handler.getPopular(req, sourceId)));
      router.get('/api/source/<sourceId>/latest', (Request req, String sourceId) async =>
          cors(await handler.getLatest(req, sourceId)));
      router.get('/api/source/<sourceId>/search', (Request req, String sourceId) async =>
          cors(await handler.search(req, sourceId)));
      router.get('/api/source/<sourceId>/filters', (Request req, String sourceId) async =>
          cors(await handler.getFilters(req, sourceId)));
      router.get('/api/source/<sourceId>/videos', (Request req, String sourceId) async =>
          cors(await handler.getVideos(req, sourceId)));
      router.get('/api/manga/<sourceId>/<mangaId>', (Request req, String sourceId, String mangaId) async =>
          cors(await handler.getMangaDetail(req, sourceId, mangaId)));
      router.get('/api/manga/<sourceId>/<mangaId>/chapters', (Request req, String sourceId, String mangaId) async =>
          cors(await handler.getMangaChapters(req, sourceId, mangaId)));
      router.get('/api/chapter/<chapterId>/pages', (Request req, String chapterId) async =>
          cors(await handler.getChapterPages(req, chapterId)));
      router.get('/api/library', (Request req) async => cors(await handler.getLibrary(req)));
      router.get('/api/history', (Request req) async => cors(await handler.getHistory(req)));
      router.get('/api/proxy', (Request req) async => cors(await handler.proxyImage(req)));
      router.add('OPTIONS', '/<path|.*>', optionsH);

      final pipeline = const Pipeline()
          .addMiddleware(requireApiKey())
          .addHandler(router.call);
      _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, 4567);
      _localUrl = 'http://' + (await _getLanIp()) + ':4567';
      _running = true;
      _tunnelError = null;
      _downloadProgress = null;
      _slog('Serveur actif sur $_localUrl');
      _notify();

      _tunnel = TunnelService();
      _tunnel!.onUrlChanged = (url) {
        _slog('Tunnel URL : $url');
        _tunnelUrl = url;
        _downloadProgress = null;
        _notify();
      };
      _tunnel!.onError = (err) {
        _slogErr('Tunnel erreur : $err');
        _tunnelError = err;
        _downloadProgress = null;
        _notify();
      };
      _tunnel!.onDownloadProgress = (p) {
        _downloadProgress = p;
        _notify();
      };
      await _tunnel!.start();
    }

    Response _unauthorized() => Response(
          401,
          body: jsonEncode({'error': 'Missing or invalid API key'}),
          headers: {'Content-Type': 'application/json'},
        );

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
      _slog('Arret serveur');
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
  