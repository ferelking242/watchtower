import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transfer_discovery.dart';
import 'transfer_models.dart';
import 'transfer_sender.dart';
import 'transfer_server.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class TransferNotifier extends Notifier<TransferState> {
  TransferDiscovery? _discovery;
  TransferServer? _server;
  TransferSender? _sender;

  StreamSubscription<List<PeerDevice>>? _peersSub;
  StreamSubscription<IncomingOffer>? _offerSub;

  bool _disposed = false;

  late final String _fingerprint;
  late final String _deviceName;

  @override
  TransferState build() {
    _fingerprint = _genId();
    _deviceName = _resolveDeviceName();

    ref.onDispose(() {
      _disposed = true;
      _stopInternals();
    });

    return const TransferState();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _genId() =>
      List.generate(16, (_) => Random().nextInt(16).toRadixString(16)).join();

  static String _resolveDeviceName() {
    if (kIsWeb) return 'Watchtower';
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Watchtower';
    }
  }

  void _safeSet(TransferState Function(TransferState) updater) {
    if (_disposed) return;
    state = updater(state);
  }

  // ── public API ────────────────────────────────────────────────────────────

  Future<void> startReceiving() async {
    if (state.mode == TransferMode.receiving) return;
    await _stopInternals();
    if (_disposed) return;

    _server = TransferServer(
      deviceName: _deviceName,
      fingerprint: _fingerprint,
      onProgress: _onProgress,
      onFileDone: _onFileDone,
    );
    final port = await _server!.start();

    _offerSub = _server!.offerStream.listen((incoming) {
      _safeSet((s) => s.copyWith(
            pendingOffers: [...s.pendingOffers, incoming],
          ));
    });

    _discovery = TransferDiscovery(
      fingerprint: _fingerprint,
      deviceName: _deviceName,
      httpPort: port,
    );
    final localIp = await _discovery!.getLocalIp();
    await _discovery!.start();

    _peersSub = _discovery!.peersStream.listen((peers) {
      _safeSet((s) => s.copyWith(peers: peers));
    });

    _safeSet((_) => TransferState(
          mode: TransferMode.receiving,
          serverPort: port,
          localIp: localIp,
        ));
  }

  Future<void> startSending() async {
    if (state.mode == TransferMode.sending) return;
    if (state.mode == TransferMode.receiving) {
      _safeSet((s) => s.copyWith(mode: TransferMode.sending));
      return;
    }
    await _stopInternals();
    if (_disposed) return;

    _discovery = TransferDiscovery(
      fingerprint: _fingerprint,
      deviceName: _deviceName,
      httpPort: 0,
    );
    final localIp = await _discovery!.getLocalIp();
    await _discovery!.start();

    _peersSub = _discovery!.peersStream.listen((peers) {
      _safeSet((s) => s.copyWith(peers: peers));
    });

    _sender = TransferSender(
      fingerprint: _fingerprint,
      deviceName: _deviceName,
      onProgress: _onProgress,
    );

    _safeSet((_) => TransferState(
          mode: TransferMode.sending,
          localIp: localIp,
        ));
  }

  Future<void> sendFiles(PeerDevice peer, List<TransferFile> files) async {
    _sender ??= TransferSender(
      fingerprint: _fingerprint,
      deviceName: _deviceName,
      onProgress: _onProgress,
    );

    final sessionId = _genId();
    final session = TransferSession(
      id: sessionId,
      peer: peer,
      files: files,
      isSender: true,
    );

    _safeSet((s) => s.copyWith(sessions: [...s.sessions, session]));

    final result = await _sender!.sendOffer(
      peer: peer,
      files: files,
      sessionId: sessionId,
    );

    if (_disposed) return;

    if (!result.accepted) {
      _setStatus(sessionId, TransferStatus.rejected);
      return;
    }

    _setStatus(sessionId, TransferStatus.inProgress);

    final ok = await _sender!.sendAll(
      peer: peer,
      sessionId: sessionId,
      files: files,
    );

    if (_disposed) return;
    _setStatus(
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
    _safeSet((s) => s.copyWith(
          pendingOffers: s.pendingOffers.where((o) => o != incoming).toList(),
          sessions: [...s.sessions, session],
        ));
  }

  void rejectOffer(IncomingOffer incoming) {
    incoming.response.complete(false);
    _safeSet((s) => s.copyWith(
          pendingOffers: s.pendingOffers.where((o) => o != incoming).toList(),
        ));
  }

  Future<void> stopAll() async {
    await _stopInternals();
    _safeSet((_) => const TransferState());
  }

  // ── callbacks ──────────────────────────────────────────────────────────────

  void _onProgress(double progress, String sessionId, String fileId) {
    if (_disposed) return;
    final sessions = state.sessions.map((s) {
      if (s.id != sessionId) return s;
      s.fileProgress[fileId] = progress;
      return s;
    }).toList();
    _safeSet((s) => s.copyWith(sessions: sessions));
  }

  void _onFileDone(String sessionId, String fileId) {
    if (_disposed) return;
    final sessions = state.sessions.map((s) {
      if (s.id != sessionId) return s;
      s.fileProgress[fileId] = 1.0;
      final allDone =
          s.files.every((f) => (s.fileProgress[f.id] ?? 0) >= 1.0);
      if (allDone) {
        return s.copyWith(
            status: TransferStatus.done, completedAt: DateTime.now());
      }
      return s;
    }).toList();
    _safeSet((s) => s.copyWith(sessions: sessions));
  }

  void _setStatus(String id, TransferStatus status, {bool done = false}) {
    final sessions = state.sessions.map((s) {
      if (s.id != id) return s;
      return s.copyWith(
        status: status,
        completedAt: done ? DateTime.now() : null,
      );
    }).toList();
    _safeSet((s) => s.copyWith(sessions: sessions));
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final transferProvider =
    NotifierProvider<TransferNotifier, TransferState>(TransferNotifier.new);
