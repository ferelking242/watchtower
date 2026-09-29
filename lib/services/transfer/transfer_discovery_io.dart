// Native implementation — requires dart:io UDP sockets.
// Compiled only on Android / iOS / desktop (not web).
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'transfer_models.dart';

const _kPort = 53318;
const _kMagic = 'WTPEER';

class TransferDiscovery {
  final String fingerprint;
  final String deviceName;
  final int httpPort;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _staleTimer;
  String? _localIp;

  final _ctrl = StreamController<List<PeerDevice>>.broadcast();
  final _peers = <String, PeerDevice>{};

  Stream<List<PeerDevice>> get peersStream => _ctrl.stream;
  List<PeerDevice> get currentPeers => List.unmodifiable(_peers.values.toList());

  TransferDiscovery({
    required this.fingerprint,
    required this.deviceName,
    required this.httpPort,
  });

  Future<String?> getLocalIp() async {
    if (_localIp != null) return _localIp;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        if (n.startsWith('wlan') ||
            n.startsWith('en') ||
            n.startsWith('wifi') ||
            n.startsWith('ap')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              _localIp = addr.address;
              return _localIp;
            }
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _localIp = addr.address;
            return _localIp;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> start() async {
    _localIp = await getLocalIp();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _kPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _socket!.broadcastEnabled = true;
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _socket?.receive();
          if (dg != null) _handleDatagram(dg);
        }
      });
    } catch (e) {
      debugPrint('[Discovery] bind error: $e');
    }

    _broadcastTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _broadcast());
    _broadcast();
    _staleTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _evictStale());
  }

  void _broadcast() {
    if (_socket == null || _localIp == null) return;
    final msg = '$_kMagic\t$fingerprint\t$deviceName\t$_localIp\t$httpPort';
    try {
      _socket!.send(
        msg.codeUnits,
        InternetAddress('255.255.255.255'),
        _kPort,
      );
    } catch (_) {}
  }

  void _handleDatagram(Datagram dg) {
    try {
      final msg = String.fromCharCodes(dg.data).trim();
      final parts = msg.split('\t');
      if (parts.length < 5 || parts[0] != _kMagic) return;
      final fp = parts[1];
      final name = parts[2];
      final ip = parts[3];
      final port = int.tryParse(parts[4]) ?? 0;
      if (fp == fingerprint) return;

      final existed = _peers.containsKey(fp);
      _peers[fp] = PeerDevice(
        fingerprint: fp,
        name: name,
        ip: ip,
        port: port,
        seenAt: DateTime.now(),
      );
      if (!existed && !_ctrl.isClosed) {
        _ctrl.add(currentPeers);
      }
    } catch (_) {}
  }

  void _evictStale() {
    final before = _peers.length;
    _peers.removeWhere((_, p) => p.isStale);
    if (_peers.length != before && !_ctrl.isClosed) {
      _ctrl.add(currentPeers);
    }
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _staleTimer?.cancel();
    _broadcastTimer = null;
    _staleTimer = null;
    _socket?.close();
    _socket = null;
    _localIp = null;
    _peers.clear();
  }

  void dispose() {
    stop();
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
