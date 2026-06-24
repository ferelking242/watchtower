// Native implementation — requires dart:io and shelf_io.
// Compiled only on Android / iOS / desktop (not web).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'transfer_library_io.dart';
import 'transfer_models.dart';

class IncomingOffer {
  final TransferOffer offer;
  final Completer<bool> response;
  IncomingOffer(this.offer, this.response);
}

typedef ProgressCallback = void Function(
    double progress, String sessionId, String fileId);

class TransferServer {
  final String deviceName;
  final String fingerprint;
  final ProgressCallback onProgress;
  final void Function(String sessionId, String fileId) onFileDone;

  HttpServer? _server;
  int _port = 0;
  int get port => _port;

  // file-id → local path, populated on each /catalog call
  final Map<String, String> _fileIndex = {};

  final _ctrl = StreamController<IncomingOffer>.broadcast();
  Stream<IncomingOffer> get offerStream => _ctrl.stream;

  TransferServer({
    required this.deviceName,
    required this.fingerprint,
    required this.onProgress,
    required this.onFileDone,
  });

  Future<int> start() async {
    final router = Router()
      ..get('/ping', _ping)
      ..get('/catalog', _catalog)
      ..get('/file/<fid>', _fileStream)
      ..post('/offer', _offer)
      ..post('/transfer/<sid>/<fid>', _transfer);

    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (msg, isError) {
          if (isError) debugPrint('[Server] $msg');
        }))
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;
    debugPrint('[TransferServer] listening on port=$_port');
    return _port;
  }

  Response _ping(Request req) => Response.ok(
        jsonEncode({'app': 'watchtower', 'device': deviceName}),
        headers: {'content-type': 'application/json'},
      );

  // ── Catalog ──────────────────────────────────────────────────────────────

  Future<Response> _catalog(Request req) async {
    try {
      final entries = await loadLibraryDownloads();
      _fileIndex.clear();

      final result = entries.map((entry) {
        final chapters = entry.chapters.map((ch) {
          _fileIndex[ch.id] = ch.localPath;
          return {
            'id': ch.id,
            'name': ch.name,
            'size': ch.size,
            'type': ch.type.name,
          };
        }).toList();
        return {
          'mangaName': entry.name,
          'imageUrl': entry.imageUrl,
          'itemType': entry.itemType.name,
          'chapters': chapters,
        };
      }).toList();

      return Response.ok(
        jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[Server] catalog error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _fileStream(Request req, String fid) async {
    final path = _fileIndex[fid];
    if (path == null) return Response.notFound('File not in catalog');
    final file = File(path);
    if (!file.existsSync()) return Response.notFound('File not found');
    final size = file.statSync().size;
    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': 'application/octet-stream',
        'content-length': size.toString(),
        'content-disposition':
            'attachment; filename="${Uri.encodeComponent(p.basename(path))}"',
      },
    );
  }

  // ── Offer (legacy push) ───────────────────────────────────────────────────

  Future<Response> _offer(Request req) async {
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final sessionId = json['sessionId'] as String;
      final senderFp = (json['senderFp'] as String?) ?? 'unknown';
      final senderName = (json['senderName'] as String?) ?? 'Appareil';
      final connInfo = req.context['shelf.io.connection_info'];
      final senderIp = connInfo is HttpConnectionInfo
          ? connInfo.remoteAddress.address
          : '0.0.0.0';

      final files = (json['files'] as List)
          .cast<Map<String, dynamic>>()
          .map(TransferFile.fromJson)
          .toList();

      final peer = PeerDevice(
        fingerprint: senderFp,
        name: senderName,
        ip: senderIp,
        port: 0,
        seenAt: DateTime.now(),
      );

      final offer = TransferOffer(
        sessionId: sessionId,
        from: peer,
        files: files,
        receivedAt: DateTime.now(),
      );

      final completer = Completer<bool>();
      if (!_ctrl.isClosed) _ctrl.add(IncomingOffer(offer, completer));

      final accepted = await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => false,
      );

      return Response.ok(
        jsonEncode({'accepted': accepted, 'sessionId': sessionId}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[Server] offer error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _transfer(Request req, String sid, String fid) async {
    try {
      final saveDir = await _resolveReceiveDir();
      await saveDir.create(recursive: true);

      final cd = req.headers['content-disposition'] ?? '';
      String fileName = fid;
      if (cd.contains('filename=')) {
        fileName = cd.split('filename=').last.replaceAll('"', '').trim();
      }
      fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (fileName.isEmpty) fileName = 'file_$fid';

      final savePath = p.join(saveDir.path, fileName);
      final sink = File(savePath).openWrite();
      final contentLength = int.tryParse(req.headers['content-length'] ?? '');
      var received = 0;

      await for (final chunk in req.read()) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength != null && contentLength > 0) {
          onProgress(received / contentLength, sid, fid);
        }
      }
      await sink.flush();
      await sink.close();
      onFileDone(sid, fid);

      return Response.ok(
        jsonEncode({'ok': true, 'path': savePath}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      debugPrint('[Server] transfer error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  static Future<Directory> _resolveReceiveDir() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Watchtower/received');
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'Watchtower', 'received'));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  void dispose() {
    stop();
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
