// Web stub — no shelf_io, no dart:io HttpServer.
// Mirrors the public API of transfer_server_io.dart.
import 'dart:async';
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

  TransferServer({
    required this.deviceName,
    required this.fingerprint,
    required this.onProgress,
    required this.onFileDone,
  });

  int get port => 0;

  final _ctrl = StreamController<IncomingOffer>.broadcast();
  Stream<IncomingOffer> get offerStream => _ctrl.stream;

  Future<int> start() async => 0;
  Future<void> stop() async {}
  void dispose() {
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
