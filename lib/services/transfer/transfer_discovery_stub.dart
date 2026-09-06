// Web stub — no dart:io, no UDP sockets.
// Mirrors the public API of transfer_discovery_io.dart.
import 'dart:async';
import 'transfer_models.dart';

class TransferDiscovery {
  final String fingerprint;
  final String deviceName;
  final int httpPort;

  TransferDiscovery({
    required this.fingerprint,
    required this.deviceName,
    required this.httpPort,
  });

  final _ctrl = StreamController<List<PeerDevice>>.broadcast();
  Stream<List<PeerDevice>> get peersStream => _ctrl.stream;
  List<PeerDevice> get currentPeers => const [];

  Future<String?> getLocalIp() async => null;
  Future<void> start() async {}
  Future<void> stop() async {}
  void dispose() {
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
