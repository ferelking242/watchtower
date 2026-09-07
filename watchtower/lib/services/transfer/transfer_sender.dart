import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'transfer_models.dart';

typedef ProgressCallback = void Function(
  double progress,
  String sessionId,
  String fileId,
);

class TransferSender {
  final String fingerprint;
  final String deviceName;
  final ProgressCallback? onProgress;

  TransferSender({
    required this.fingerprint,
    required this.deviceName,
    this.onProgress,
  });

  Future<({bool accepted, String? sessionId})> sendOffer({
    required PeerDevice peer,
    required List<TransferFile> files,
    required String sessionId,
  }) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client
          .postUrl(Uri.parse('http://${peer.ip}:${peer.port}/offer'));
      req.headers.set('content-type', 'application/json');
      req.write(jsonEncode({
        'sessionId': sessionId,
        'senderFp': fingerprint,
        'senderName': deviceName,
        'files': files.map((f) => f.toJson()).toList(),
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close(force: true);

      final json = jsonDecode(body) as Map<String, dynamic>;
      final accepted = json['accepted'] as bool? ?? false;
      return (accepted: accepted, sessionId: accepted ? sessionId : null);
    } catch (e) {
      debugPrint('[Sender] offer error: $e');
      return (accepted: false, sessionId: null);
    }
  }

  Future<bool> sendFile({
    required PeerDevice peer,
    required String sessionId,
    required TransferFile file,
  }) async {
    if (file.localPath == null) return false;
    if (kIsWeb) return false;
    final localFile = File(file.localPath!);
    if (!await localFile.exists()) {
      debugPrint('[Sender] file not found: ${file.localPath}');
      return false;
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 60);
      final uri = Uri.parse(
          'http://${peer.ip}:${peer.port}/transfer/$sessionId/${file.id}');
      final req = await client.postUrl(uri);
      req.headers.set('content-type', 'application/octet-stream');
      req.headers.set('content-length', file.size.toString());
      req.headers.set(
          'content-disposition', 'attachment; filename="${file.name}"');

      var sent = 0;
      await for (final chunk in localFile.openRead()) {
        req.add(chunk);
        sent += chunk.length;
        if (file.size > 0) {
          onProgress?.call(sent / file.size, sessionId, file.id);
        }
      }

      final res = await req.close();
      await res.drain<void>();
      client.close(force: true);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[Sender] file error ${file.name}: $e');
      return false;
    }
  }

  Future<bool> sendAll({
    required PeerDevice peer,
    required String sessionId,
    required List<TransferFile> files,
  }) async {
    for (final file in files) {
      final ok = await sendFile(peer: peer, sessionId: sessionId, file: file);
      if (!ok) return false;
    }
    return true;
  }
}
