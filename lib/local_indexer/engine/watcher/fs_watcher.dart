import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

/// Surveillance du système de fichiers en temps réel.
///
/// Dispatche vers le mécanisme natif le plus rapide selon la plateforme :
///   - Linux   : inotify (via dart:io Directory.watch)
///   - macOS   : FSEvents (via dart:io Directory.watch)
///   - Windows : ReadDirectoryChangesW (via dart:io Directory.watch)
///   - Android : MediaStore + Directory.watch complémentaire
///
/// Émet des [FsEvent] qui déclenchent une mise à jour incrémentale de l'index
/// sans rescanner tout le disque.
class FsWatcher {
  final List<String> _roots;
  final StreamController<FsEvent> _controller =
      StreamController<FsEvent>.broadcast();

  final List<StreamSubscription> _subs = [];
  bool _started = false;

  FsWatcher(this._roots);

  /// Stream des événements du système de fichiers.
  Stream<FsEvent> get events => _controller.stream;

  /// Démarre la surveillance de tous les dossiers racines.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    for (final root in _roots) {
      await _watchDir(root);
    }
  }

  /// Ajoute un nouveau dossier racine à surveiller à chaud.
  Future<void> addRoot(String path) async {
    if (!_roots.contains(path)) {
      _roots.add(path);
      await _watchDir(path);
    }
  }

  /// Arrête tous les watchers.
  Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _started = false;
  }

  /// Libère toutes les ressources.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  // ── Implémentation ─────────────────────────────────────────────────────────

  Future<void> _watchDir(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return;

    try {
      // dart:io utilise le mécanisme natif de chaque plateforme :
      //   Linux   → inotify
      //   macOS   → kqueue / FSEvents
      //   Windows → ReadDirectoryChangesW
      final sub = dir
          .watch(events: FileSystemEvent.all, recursive: true)
          .listen(_handleEvent, onError: _handleError);

      _subs.add(sub);
    } catch (e) {
      // Certaines plateformes (Android sans permissions) peuvent échouer
      _controller.addError(e);
    }
  }

  void _handleEvent(FileSystemEvent event) {
    // Filtrer les événements sur les fichiers non-média
    final path = event.path;
    if (!_isMediaFile(path)) return;

    FsEventType type;
    switch (event.type) {
      case FileSystemEvent.create:
        type = FsEventType.created;
      case FileSystemEvent.modify:
        type = FsEventType.modified;
      case FileSystemEvent.delete:
        type = FsEventType.deleted;
      case FileSystemEvent.move:
        type = FsEventType.moved;
      default:
        return;
    }

    _controller.add(FsEvent(
      type: type,
      path: path,
      destPath: event is FileSystemMoveEvent
          ? (event as FileSystemMoveEvent).destination
          : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _handleError(Object error) {
    _controller.addError(error);
  }

  static final _mediaExts = RegExp(
    r'\.(mkv|mp4|avi|mov|flv|wmv|ts|m2ts|mts|webm|m4v'
    r'|cbz|cbr|cbt|cb7'
    r'|epub|mobi|azw3'
    r')$',
    caseSensitive: false,
  );

  static bool _isMediaFile(String path) => _mediaExts.hasMatch(path);
}

/// Événement système de fichiers normalisé.
class FsEvent {
  final FsEventType type;
  final String path;
  final String? destPath; // uniquement pour FsEventType.moved
  final int timestamp;

  const FsEvent({
    required this.type,
    required this.path,
    this.destPath,
    required this.timestamp,
  });

  @override
  String toString() => 'FsEvent($type, $path)';
}

enum FsEventType { created, modified, deleted, moved }
