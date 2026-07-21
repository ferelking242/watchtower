import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/canonical_key.dart';
import 'package:watchtower/local_indexer/normalizer/episode_detector.dart';
import 'package:watchtower/local_indexer/normalizer/language_detector.dart';
import 'package:watchtower/local_indexer/normalizer/noise_remover.dart';
import 'package:watchtower/local_indexer/normalizer/quality_detector.dart';
import 'package:watchtower/local_indexer/normalizer/tokenizer.dart';

/// Résultat complet de l'analyse d'un nom de fichier.
class NormalizeResult {
  final String title;
  final String canonicalKey;
  final LocalMediaKind kind;
  final int? season;
  final int? episode;
  final int? chapter;
  final int? volume;
  final int? part;
  final String? quality;
  final String? codec;
  final String? audioCodec;
  final String? language;
  final String? releaseGroup;
  final double confidence;

  const NormalizeResult({
    required this.title,
    required this.canonicalKey,
    required this.kind,
    this.season,
    this.episode,
    this.chapter,
    this.volume,
    this.part,
    this.quality,
    this.codec,
    this.audioCodec,
    this.language,
    this.releaseGroup,
    required this.confidence,
  });

  @override
  String toString() =>
      'NormalizeResult('
      'title=$title, key=$canonicalKey, kind=$kind, '
      'S${season}E${episode}, Ch$chapter, '
      'q=$quality, codec=$codec, lang=$language, '
      'conf=${confidence.toStringAsFixed(2)}'
      ')';
}

/// Orchestrateur principal du pipeline de normalisation.
///
/// Pipeline :
///   1. Tokenisation
///   2. Extraction du groupe de release
///   3. Suppression du bruit
///   4. Détection épisode/saison/chapitre
///   5. Détection langue
///   6. Détection qualité/codec
///   7. Extraction du titre (tokens restants)
///   8. Génération de la clé canonique
///   9. Calcul du score de confiance
///   10. Détermination du type de média
class NameNormalizer {
  // Groupes de release courants (souvent dans [brackets])
  static final _releaseGroupPattern = RegExp(
    r'^\[([A-Za-z0-9][A-Za-z0-9\-_]{1,24})\]$',
  );

  /// Analyse un nom de fichier complet (basename avec extension) et retourne
  /// les métadonnées structurées.
  static NormalizeResult normalize(String filename) {
    // ── 1. Tokenisation ────────────────────────────────────────────────────
    final tokens = Tokenizer.tokenize(filename);

    // ── 2. Extraction du groupe de release ────────────────────────────────
    String? releaseGroup;
    final Set<int> groupIndices = {};
    for (var i = 0; i < tokens.length; i++) {
      final m = _releaseGroupPattern.firstMatch(tokens[i]);
      if (m != null) {
        releaseGroup = m.group(1);
        groupIndices.add(i);
        break; // on ne prend que le premier bracket
      }
    }

    // ── 3. Détection qualité ──────────────────────────────────────────────
    final quality = QualityDetector.detect(tokens);

    // ── 4. Détection langue ───────────────────────────────────────────────
    final lang = LanguageDetector.detect(tokens);

    // ── 5. Détection épisode/chapitre ─────────────────────────────────────
    final episode = EpisodeDetector.detect(tokens);

    // ── 6. Indices à exclure pour l'extraction du titre ───────────────────
    final excluded = <int>{
      ...groupIndices,
      ...quality.consumedIndices,
      ...lang.consumedIndices,
      ...episode.consumedIndices,
    };

    // ── 7. Tokens restants → candidats titre ──────────────────────────────
    final titleTokens = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (excluded.contains(i)) continue;
      final t = tokens[i];
      if (NoiseRemover.isNoise(t)) continue;
      // Ignorer les tokens purement numériques résiduels
      if (RegExp(r'^\d+$').hasMatch(t)) continue;
      titleTokens.add(t);
    }

    // ── 8. Reconstitution du titre ────────────────────────────────────────
    final rawTitle = titleTokens.join(' ');
    final title = _cleanTitle(rawTitle);

    // ── 9. Clé canonique ──────────────────────────────────────────────────
    final canonical = CanonicalKey.generate(title.isEmpty ? filename : title);

    // ── 10. Type de média ─────────────────────────────────────────────────
    final kind = _detectKind(filename, episode);

    // ── 11. Score de confiance ────────────────────────────────────────────
    final conf = _computeConfidence(
      hasTitle: title.isNotEmpty,
      hasEpisode: !episode.isEmpty,
      hasQuality: quality.resolution != null,
      hasLang: lang.language != null,
      tokenCount: tokens.length,
    );

    return NormalizeResult(
      title: title.isEmpty ? _fallbackTitle(filename) : title,
      canonicalKey: canonical,
      kind: kind,
      season: episode.season,
      episode: episode.episode,
      chapter: episode.chapter,
      volume: episode.volume,
      part: episode.part,
      quality: quality.resolution,
      codec: quality.videoCodec,
      audioCodec: quality.audioCodec,
      language: lang.language,
      releaseGroup: releaseGroup,
      confidence: conf,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        // Capitaliser la première lettre
        .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
  }

  static String _fallbackTitle(String filename) {
    var name = filename;
    final slash = filename.lastIndexOf(RegExp(r'[/\\]'));
    if (slash >= 0) name = filename.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name.replaceAll(RegExp(r'[_\-\.]'), ' ').trim();
  }

  static LocalMediaKind _detectKind(String filename, EpisodeResult ep) {
    final ext = _extension(filename).toLowerCase();
    // Formats exclusivement manga/comics
    if (const {'.cbz', '.cbr', '.cbt'}.contains(ext)) {
      return LocalMediaKind.manga;
    }
    // Novels
    if (const {'.epub', '.mobi', '.azw3'}.contains(ext)) {
      return LocalMediaKind.novel;
    }
    // Vidéo → anime ou série ou film
    if (const {'.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.ts'}.contains(ext)) {
      if (ep.episode != null || ep.season != null) {
        return LocalMediaKind.anime; // heuristique : épisode → anime (peut être série)
      }
      return LocalMediaKind.movie;
    }
    // Images → manga probable
    if (const {'.jpg', '.jpeg', '.png', '.webp', '.avif'}.contains(ext)) {
      return LocalMediaKind.manga;
    }
    return LocalMediaKind.unknown;
  }

  static String _extension(String path) {
    final i = path.lastIndexOf('.');
    return i >= 0 ? path.substring(i) : '';
  }

  static double _computeConfidence({
    required bool hasTitle,
    required bool hasEpisode,
    required bool hasQuality,
    required bool hasLang,
    required int tokenCount,
  }) {
    double score = 0.0;
    if (hasTitle) score += 0.45;
    if (hasEpisode) score += 0.30;
    if (hasQuality) score += 0.15;
    if (hasLang) score += 0.10;
    // Pénalité si très peu de tokens (filename trop court/bruité)
    if (tokenCount < 2) score *= 0.5;
    return score.clamp(0.0, 1.0);
  }
}
