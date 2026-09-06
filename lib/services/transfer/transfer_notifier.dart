import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  final Map<String, List<PeerCatalogEntry>> peerCatalogs;
  final Set<String> catalogsLoading;
  final int localLibraryCount;

  const TransferState({
    this.mode = TransferMode.idle,
    this.peers = const [],
    this.pendingOffers = const [],
    this.sessions = const [],
    this.localIp,
    this.serverPort,
    this.error,
    this.peerCatalogs = const {},
    this.catalogsLoading = const <String>{},
    this.localLibraryCount = 0,
  });

  TransferState copyWith({
    TransferMode? mode,
    List<PeerDevice>? peers,
    List<IncomingOffer>? pendingOffers,
    List<TransferSession>? sessions,
    String? localIp,
    int? serverPort,
    String? error,
    Map<String, List<PeerCatalogEntry>>? peerCatalogs,
    Set<String>? catalogsLoading,
    int? localLibraryCount,
  }) =>
      TransferState(
        mode: mode ?? this.mode,
        peers: peers ?? this.peers,
        pendingOffers: pendingOffers ?? this.pendingOffers,
        sessions: sessions ?? this.sessions,
        localIp: localIp ?? this.localIp,
        serverPort: serverPort ?? this.serverPort,
        error: error,
        peerCatalogs: peerCatalogs ?? this.peerCatalogs,
        catalogsLoading: catalogsLoading ?? this.catalogsLoading,
        localLibraryCount: localLibraryCount ?? this.localLibraryCount,
      );

  List<TransferSession> get activeSessions => sessions
      .where((s) =>
          s.status == TransferStatus.inProgress ||
          s.status == TransferStatus.pending)
      .toList();
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
  final Set<String> _fetchedFingerprints = {};

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

  String get deviceName => _deviceName;
  String get fingerprint => _fingerprint;

  // ── Room mode (symmetric: server + discovery) ─────────────────────────────

  Future<void> joinRoom() async {
    if (state.mode == TransferMode.room) return;
    await _stopInternals();
    if (_disposed) return;
    _fetchedFingerprints.clear();

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
      _safeSet((s) {
        // Remove catalog entries for peers no longer in the list
        final activeFingerprints =
            peers.map((p) => p.fingerprint).toSet();
        final pruned = Map<String, List<PeerCatalogEntry>>.from(
            s.peerCatalogs)
          ..removeWhere((k, _) => !activeFingerprints.contains(k));
        return s.copyWith(peers: peers, peerCatalogs: pruned);
      });

      // Auto-fetch catalog for newly discovered peers
      for (final peer in peers) {
        if (!_fetchedFingerprints.contains(peer.fingerprint)) {
          _fetchedFingerprints.add(peer.fingerprint);
          fetchCatalog(peer);
        }
      }
    });

    _safeSet((_) => TransferState(
          mode: TransferMode.room,
          serverPort: port,
          localIp: localIp,
        ));
  }

  // ── Legacy send/receive ───────────────────────────────────────────────────

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

  // ── Catalog fetch ─────────────────────────────────────────────────────────

  Future<void> fetchCatalog(PeerDevice peer) async {
    if (state.catalogsLoading.contains(peer.fingerprint)) return;
    _safeSet((s) => s.copyWith(
          catalogsLoading: {...s.catalogsLoading, peer.fingerprint},
        ));

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('http://${peer.ip}:${peer.port}/catalog');
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close(force: true);

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final list =
          (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      final entries = list.map(PeerCatalogEntry.fromJson).toList();

      _safeSet((s) {
        final updated =
            Map<String, List<PeerCatalogEntry>>.from(s.peerCatalogs);
        updated[peer.fingerprint] = entries;
        final loading = Set<String>.from(s.catalogsLoading)
          ..remove(peer.fingerprint);
        return s.copyWith(peerCatalogs: updated, catalogsLoading: loading);
      });
    } catch (e) {
      debugPrint('[Notifier] fetchCatalog error: $e');
      _safeSet((s) {
        final loading = Set<String>.from(s.catalogsLoading)
          ..remove(peer.fingerprint);
        return s.copyWith(catalogsLoading: loading);
      });
    }
  }

  void refreshCatalog(PeerDevice peer) {
    _fetchedFingerprints.remove(peer.fingerprint);
    _safeSet((s) {
      final updated =
          Map<String, List<PeerCatalogEntry>>.from(s.peerCatalogs);
      updated.remove(peer.fingerprint);
      return s.copyWith(peerCatalogs: updated);
    });
    _fetchedFingerprints.add(peer.fingerprint);
    fetchCatalog(peer);
  }

  // ── Download from peer (pull) ─────────────────────────────────────────────

  Future<void> downloadFromPeer(
    PeerDevice peer,
    List<PeerCatalogChapter> chapters,
  ) async {
    if (kIsWeb) return;
    final sessionId = _genId();
    final files = chapters.map((c) => c.toTransferFile()).toList();
    final session = TransferSession(
      id: sessionId,
      peer: peer,
      files: files,
      isSender: false,
      status: TransferStatus.inProgress,
    );
    _safeSet((s) => s.copyWith(sessions: [...s.sessions, session]));

    for (final ch in chapters) {
      final ok = await _pullFile(peer, sessionId, ch);
      if (!ok) {
        _setStatus(sessionId, TransferStatus.failed);
        return;
      }
    }
    _setStatus(sessionId, TransferStatus.done, done: true);
  }

  Future<bool> _pullFile(
    PeerDevice peer,
    String sessionId,
    PeerCatalogChapter chapter,
  ) async {
    if (kIsWeb) return false;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(minutes: 30);
      final uri =
          Uri.parse('http://${peer.ip}:${peer.port}/file/${chapter.id}');
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close(force: true);
        return false;
      }

      final saveDir = await _saveDir();
      await saveDir.create(recursive: true);

      String safeName =
          chapter.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (safeName.isEmpty) safeName = 'file_${chapter.id}';
      final savePath = p.join(saveDir.path, safeName);

      final sink = File(savePath).openWrite();
      final contentLength =
          int.tryParse(res.headers.value('content-length') ?? '');
      var received = 0;

      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength != null && contentLength > 0) {
          _onProgress(received / contentLength, sessionId, chapter.id);
        }
      }
      await sink.flush();
      await sink.close();
      client.close(force: true);
      _onFileDone(sessionId, chapter.id);
      return true;
    } catch (e) {
      debugPrint('[Notifier] pullFile error: $e');
      return false;
    }
  }

  static Future<Directory> _saveDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      return Directory('/storage/emulated/0/Watchtower/received');
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'Watchtower', 'received'));
  }

  // ── Stop ─────────────────────────────────────────────────────────────────

  Future<void> stopAll() async {
    await _stopInternals();
    _fetchedFingerprints.clear();
    _safeSet((_) => const TransferState());
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

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
