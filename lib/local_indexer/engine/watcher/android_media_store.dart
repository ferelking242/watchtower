import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/services.dart';

/// Pont vers Android MediaStore pour la découverte rapide des médias.
///
/// Android indexe déjà tous les médias via MediaStore. Plutôt que de
/// rescanner le stockage entier à chaque démarrage, on interroge MediaStore
/// comme source principale et on complète uniquement pour les formats non
/// référencés (CBZ, EPUB, etc.).
///
/// Requiert la permission READ_EXTERNAL_STORAGE (Android ≤ 12) ou
/// READ_MEDIA_VIDEO + READ_MEDIA_IMAGES (Android 13+).
class AndroidMediaStore {
  static const _channel = MethodChannel('watchtower/media_store');

  /// Retourne `true` si on tourne sur Android.
  static bool get isAvailable =>
      !const bool.fromEnvironment('dart.library.js_interop') &&
      Platform.isAndroid;

  // ── API publique ────────────────────────────────────────────────────────────

  /// Récupère tous les fichiers vidéo indexés par MediaStore.
  ///
  /// Retourne une liste de [MediaStoreEntry].
  /// Beaucoup plus rapide qu'un scan récursif car Android maintient cet index.
  static Future<List<MediaStoreEntry>> queryVideos() async {
    if (!isAvailable) return [];
    try {
      final result = await _channel.invokeMethod<List>('queryVideos');
      if (result == null) return [];
      return result
          .cast<Map>()
          .map((m) => MediaStoreEntry.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } on PlatformException catch (e) {
      // Permissions manquantes ou MediaStore indisponible
      throw MediaStoreException('queryVideos failed: ${e.message}');
    }
  }

  /// Récupère tous les fichiers image (pour les mangas page par page).
  static Future<List<MediaStoreEntry>> queryImages() async {
    if (!isAvailable) return [];
    try {
      final result = await _channel.invokeMethod<List>('queryImages');
      if (result == null) return [];
      return result
          .cast<Map>()
          .map((m) => MediaStoreEntry.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } on PlatformException catch (e) {
      throw MediaStoreException('queryImages failed: ${e.message}');
    }
  }

  /// Scan complémentaire pour les formats non indexés par MediaStore
  /// (CBZ, EPUB, etc.) dans les dossiers typiques Watchtower.
  static Future<List<String>> queryCustomFormats({
    required List<String> rootPaths,
    List<String> extensions = const ['.cbz', '.cbr', '.epub', '.mobi'],
  }) async {
    if (!isAvailable) return [];

    final found = <String>[];
    for (final root in rootPaths) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.toLowerCase();
        if (extensions.any(path.endsWith)) {
          found.add(entity.path);
        }
      }
    }
    return found;
  }

  /// S'abonne aux changements MediaStore via un ContentObserver natif.
  /// Retourne un [Stream] qui émet chaque fois qu'un fichier média change.
  ///
  /// Note : nécessite un MethodChannel côté Android (à implémenter en Kotlin).
  static Stream<MediaStoreChange> observeChanges() {
    if (!isAvailable) return const Stream.empty();

    final controller = StreamController<MediaStoreChange>.broadcast();
    const eventChannel = EventChannel('watchtower/media_store_events');

    eventChannel
        .receiveBroadcastStream()
        .cast<Map>()
        .listen(
          (m) => controller.add(
            MediaStoreChange.fromMap(Map<String, dynamic>.from(m)),
          ),
          onError: controller.addError,
          onDone: controller.close,
        );

    return controller.stream;
  }
}

/// Entrée MediaStore (côté Dart).
class MediaStoreEntry {
  final String path;
  final int size;
  final int modifiedAt; // ms depuis epoch
  final String? mimeType;
  final String? displayName;
  final int? duration; // ms (pour les vidéos)

  const MediaStoreEntry({
    required this.path,
    required this.size,
    required this.modifiedAt,
    this.mimeType,
    this.displayName,
    this.duration,
  });

  factory MediaStoreEntry.fromMap(Map<String, dynamic> m) {
    return MediaStoreEntry(
      path: m['path'] as String,
      size: (m['size'] as num?)?.toInt() ?? 0,
      modifiedAt: (m['modifiedAt'] as num?)?.toInt() ?? 0,
      mimeType: m['mimeType'] as String?,
      displayName: m['displayName'] as String?,
      duration: (m['duration'] as num?)?.toInt(),
    );
  }
}

/// Notification d'un changement MediaStore.
class MediaStoreChange {
  final String? path;
  final MediaStoreChangeType type;

  const MediaStoreChange({this.path, required this.type});

  factory MediaStoreChange.fromMap(Map<String, dynamic> m) {
    final t = m['type'] as String? ?? 'unknown';
    return MediaStoreChange(
      path: m['path'] as String?,
      type: MediaStoreChangeType.values.firstWhere(
        (e) => e.name == t,
        orElse: () => MediaStoreChangeType.unknown,
      ),
    );
  }
}

enum MediaStoreChangeType { inserted, updated, deleted, unknown }

class MediaStoreException implements Exception {
  final String message;
  const MediaStoreException(this.message);
  @override
  String toString() => 'MediaStoreException: $message';
}
