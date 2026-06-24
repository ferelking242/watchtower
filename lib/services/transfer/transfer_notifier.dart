import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transfer_discovery.dart';
import 'transfer_models.dart';
import 'transfer_sender.dart';
import 'transfer_server.dart';

class TransferState {
  final TransferMode mode;
  final List<PeerDevice> peers;
  final List<IncomingOffer> pendingOffers;
  final List<TransferSession> sessions;
  final String? localIp;
  final int? serverPort;
  final String? error;

  const TransferState({
    this.mode = TransferMode.idle,
    this.peers = const [],
    this.pendingOffers = const [],
    this.sessions = const [],
    this.localIp,
    this.serverPort,
    this.error,
  });

  TransferState copyWith({
    TransferMode? mode,
    List<PeerDevice>? peers,
    List<IncomingOffer>? pendingOffers,
    List<TransferSession>? sessions,
    String? localIp,
    int? serverPort,
    String? error,
  }) =>
      TransferState(
        mode: mode ?? this.mode,
        peers: peers ?? this.peers,
        pendingOffers: pendingOffers ?? this.pendingOffers,
        sessions: sessions ?? this.sessions,
        localIp: localIp ?? this.localIp,
        serverPort: serverPort ?? this.serverPort,
        error: error,
      );
}

class TransferNotifier extends StateNotifier<TransferState> {
  final String fingerprint;
  final String deviceName;

  TransferDiscovery? _discovery;
  TransferServer? _server;
  TransferSender? _sender;

  StreamSubscription<List<PeerDevice>>? _peersSub;
  StreamSubscription<IncomingOffer>? _offerSub;

  TransferNotifier({required this.fingerprint, required this.deviceName})
      : super(const TransferState());

  Future<void> startReceiving() async {
    if (state.mode == TransferMode.receiving) return;
    await _stopInternals();

    _server = TransferServer(
      deviceName: deviceName,
      fingerprint: fingerprint,
      onProgress: _onProgress,
      onFileDone: _onFileDone,
    );
    final port = await _server!.start();

    _offerSub = _server!.offerStream.listen((incoming) {
      if (!mounted) return;
      state = state.copyWith(
        pendingOffers: [...state.pendingOffers, incoming],
      );
    });

    _discovery = TransferDiscovery(
      fingerprint: fingerprint,
      deviceName: deviceName,
      httpPort: port,
    );
    final localIp = await _discovery!.getLocalIp();
    await _discovery!.start();

    _peersSub = _discovery!.peersStream.listen((peers) {
      if (!mounted) return;
      state = state.copyWith(peers: peers);
    });

    if (mounted) {
      state = state.copyWith(
        mode: TransferMode.receiving,
        serverPort: port,
        localIp: localIp,
        error: null,
      );
    }
  }

  Future<void> startSending() async {
    if (state.mode == TransferMode.sending) return;
    if (state.mode == TransferMode.receiving) {
      state = state.copyWith(mode: TransferMode.sending);
      return;
    }
    await _stopInternals();

    _discovery = TransferDiscovery(
      fingerprint: fingerprint,
      deviceName: deviceName,
      httpPort: 0,
    );
    final localIp = await _discovery!.getLocalIp();
    await _discovery!.start();

    _peersSub = _discovery!.peersStream.listen((peers) {
      if (!mounted) return;
      state = state.copyWith(peers: peers);
    });

    _sender = TransferSender(
      fingerprint: fingerprint,
      deviceName: deviceName,
      onProgress: _onProgress,
    );

    if (mounted) {
      state = state.copyWith(
        mode: TransferMode.sending,
        localIp: localIp,
        error: null,
      );
    }
  }

  Future<void> sendFiles(PeerDevice peer, List<TransferFile> files) async {
    _sender ??= TransferSender(
      fingerprint: fingerprint,
      deviceName: deviceName,
      onProgress: _onProgress,
    );

    final sessionId = _genId();
    final session = TransferSession(
      id: sessionId,
      peer: peer,
      files: files,
      isSender: true,
    );

    if (!mounted) return;
    state = state.copyWith(sessions: [...state.sessions, session]);

    final result = await _sender!.sendOffer(
      peer: peer,
      files: files,
      sessionId: sessionId,
    );

    if (!mounted) return;

    if (!result.accepted) {
      _setSessionStatus(sessionId, TransferStatus.rejected);
      return;
    }

    _setSessionStatus(sessionId, TransferStatus.inProgress);

    final ok = await _sender!.sendAll(
      peer: peer,
      sessionId: sessionId,
      files: files,
    );

    if (!mounted) return;
    _setSessionStatus(
      sessionId,
      ok ? TransferStatus.done : TransferStatus.failed,
      done: ok,
    );
  }

  void acceptOffer(IncomingOffer incoming) {
    incoming.response.complete(true);
    final session = TransferSession(
      id: incoming.offer.sessionId,
      peer: incoming.offer.from,
      files: incoming.offer.files,
      isSender: false,
      status: TransferStatus.inProgress,
    );
    if (!mounted) return;
    state = state.copyWith(
      pendingOffers:
          state.pendingOffers.where((o) => o != incoming).toList(),
      sessions: [...state.sessions, session],
    );
  }

  void rejectOffer(IncomingOffer incoming) {
    incoming.response.complete(false);
    if (!mounted) return;
    state = state.copyWith(
      pendingOffers:
          state.pendingOffers.where((o) => o != incoming).toList(),
    );
  }

  Future<void> stopAll() async {
    await _stopInternals();
    if (mounted) state = const TransferState();
  }

  void _onProgress(double progress, String sessionId, String fileId) {
    if (!mounted) return;
    final sessions = state.sessions.map((s) {
      if (s.id != sessionId) return s;
      s.fileProgress[fileId] = progress;
      return s;
    }).toList();
    state = state.copyWith(sessions: sessions);
  }

  void _onFileDone(String sessionId, String fileId) {
    if (!mounted) return;
    final sessions = state.sessions.map((s) {
      if (s.id != sessionId) return s;
      s.fileProgress[fileId] = 1.0;
      final allDone = s.files.every((f) => (s.fileProgress[f.id] ?? 0) >= 1.0);
      if (allDone) {
        return s.copyWith(status: TransferStatus.done, completedAt: DateTime.now());
      }
      return s;
    }).toList();
    state = state.copyWith(sessions: sessions);
  }

  void _setSessionStatus(
    String id,
    TransferStatus status, {
    bool done = false,
  }) {
    final sessions = state.sessions.map((s) {
      if (s.id != id) return s;
      return s.copyWith(
        status: status,
        completedAt: done ? DateTime.now() : null,
      );
    }).toList();
    if (mounted) state = state.copyWith(sessions: sessions);
  }

  Future<void> _stopInternals() async {
    _peersSub?.cancel();
    _offerSub?.cancel();
    _peersSub = null;
    _offerSub = null;
    await _discovery?.stop();
    await _server?.stop();
    _server?.dispose();
    _discovery?.dispose();
    _discovery = null;
    _server = null;
    _sender = null;
  }

  static String _genId() =>
      List.generate(16, (_) => Random().nextInt(16).toRadixString(16)).join();

  @override
  void dispose() {
    _stopInternals();
    super.dispose();
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  final rng = Random();
  final fp =
      List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
  String name = 'Watchtower';
  if (!kIsWeb) {
    try {
      name = Platform.localHostname;
    } catch (_) {}
  }
  return TransferNotifier(fingerprint: fp, deviceName: name);
});
