import 'package:isar_community/isar.dart';
part 'local_indexed_item.g.dart';

/// Catégorie de média local.
enum LocalMediaKind { anime, series, movie, manga, novel, unknown }

/// Un élément de média indexé sur le stockage local.
///
/// Plusieurs fichiers peuvent partager le même [canonicalKey] (doublons :
/// VF vs VOSTFR, 720p vs 1080p) — ils sont regroupés sous une seule entrée
/// logique dans l'UI.
@collection
@Name("LocalIndexedItem")
class LocalIndexedItem {
  Id id = Isar.autoIncrement;

  // ── Identité canonique ──────────────────────────────────────────────────
  /// Clé normalisée qui regroupe toutes les variantes de la même œuvre.
  /// Ex : "naruto shippuden" pour tous les fichiers de cette série.
  @Index(unique: false, caseSensitive: false)
  late String canonicalKey;

  /// Titre nettoyé prêt pour l'affichage.
  @Index(caseSensitive: false)
  late String title;

  @enumerated
  late LocalMediaKind kind;

  // ── Structure narrative ─────────────────────────────────────────────────
  int? season;
  int? episode;
  int? chapter;
  int? volume;
  int? part;

  // ── Métadonnées de qualité / langue ────────────────────────────────────
  /// Ex : "1080p", "4K", "720p"
  String? quality;

  /// Ex : "x265", "x264", "HEVC", "AVC", "AV1"
  String? codec;

  /// Ex : "VOSTFR", "VF", "EN", "JP", "MULTI"
  String? language;

  /// Groupe de release : "[SubsPlease]", "[Erai-raws]", etc.
  String? releaseGroup;

  /// Audio codec : "AAC", "FLAC", "Opus", etc.
  String? audioCodec;

  // ── Fichier source ──────────────────────────────────────────────────────
  @Index(unique: true, caseSensitive: false)
  late String filePath;

  /// Taille en octets.
  late int fileSize;

  /// Date de modification (ms depuis epoch).
  late int modifiedAt;

  /// Type MIME déduit de l'extension.
  String? mimeType;

  /// Nom de fichier brut (conservé pour re-analyse future).
  late String rawFilename;

  // ── Déduplication ───────────────────────────────────────────────────────
  /// IDs des autres LocalIndexedItem qui représentent la même œuvre/épisode.
  List<int> duplicateIds = [];

  // ── Score de confiance ──────────────────────────────────────────────────
  /// Score d'analyse du nom (0.0 = incertain, 1.0 = parfait).
  late double confidence;

  // ── Timestamps ──────────────────────────────────────────────────────────
  late int indexedAt;
  int? updatedAt;

  LocalIndexedItem();

  /// Clé humaine pour identifier l'épisode/chapitre.
  /// Ex : "S01E05", "Ch.12 Vol.2", "Film"
  String get episodeKey {
    if (chapter != null) {
      final v = volume != null ? ' Vol.${volume}' : '';
      final p = part != null ? ' Pt.${part}' : '';
      return 'Ch.${chapter}$v$p';
    }
    if (episode != null) {
      final s = season?.toString().padLeft(2, '0') ?? '01';
      final e = episode!.toString().padLeft(2, '0');
      return 'S${s}E${e}';
    }
    if (kind == LocalMediaKind.movie) return 'Film';
    return '';
  }

  /// Étiquette courte de qualité/langue pour l'UI.
  String get badge {
    final parts = <String>[];
    if (language != null) parts.add(language!);
    if (quality != null) parts.add(quality!);
    if (codec != null) parts.add(codec!);
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'canonicalKey': canonicalKey,
        'title': title,
        'kind': kind.index,
        'season': season,
        'episode': episode,
        'chapter': chapter,
        'volume': volume,
        'part': part,
        'quality': quality,
        'codec': codec,
        'language': language,
        'releaseGroup': releaseGroup,
        'audioCodec': audioCodec,
        'filePath': filePath,
        'fileSize': fileSize,
        'modifiedAt': modifiedAt,
        'mimeType': mimeType,
        'rawFilename': rawFilename,
        'duplicateIds': duplicateIds,
        'confidence': confidence,
        'indexedAt': indexedAt,
        'updatedAt': updatedAt,
      };
}
