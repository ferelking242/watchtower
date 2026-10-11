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

    // ── 5b. Groupe de release collé par un tiret ──────────────────────────
    // "...x265-GROUP" est tokenisé en "x265", "GROUP" (le tiret est un
    // séparateur) : le groupe n'apparaît donc pas dans un bloc [..]. On ne le
    // retire que si le token précédent est déjà reconnu comme métadonnée
    // (qualité, codec, langue…) ou comme bruit, afin de ne pas amputer un
    // titre légitime contenant un tiret ("Spider-Man").
    if (releaseGroup == null && tokens.length >= 2) {
      final lastIndex = tokens.length - 1;
      final prevIndex = lastIndex - 1;
      final last = tokens[lastIndex];
      final precededByMetadata =
          quality.consumedIndices.contains(prevIndex) ||
          episode.consumedIndices.contains(prevIndex) ||
          lang.consumedIndices.contains(prevIndex) ||
          NoiseRemover.isNoise(tokens[prevIndex]);
      if (_stem(filename).contains('-') &&
          precededByMetadata &&
          !quality.consumedIndices.contains(lastIndex) &&
          !episode.consumedIndices.contains(lastIndex) &&
          !lang.consumedIndices.contains(lastIndex) &&
          RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,23}$').hasMatch(last)) {
        groupIndices.add(lastIndex);
        releaseGroup = last;
      }
    }

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
    String? yearFallback;
    if (titleTokens.isEmpty) {
      for (final token in tokens) {
        final value = int.tryParse(token);
        if (value != null && value >= 1900 && value <= 2099) {
          yearFallback = token;
          break;
        }
      }
    }
    var title = _cleanTitle(rawTitle);

    // ── 9. Type de média + métadonnées de chemin ─────────────────────────
    final kind = _detectKind(filename, episode);
    var chapter = episode.chapter;
    var volume = episode.volume;
    if (kind == LocalMediaKind.manga) {
      // Le volume/chapitre peut vivre dans un dossier parent
      // ("/Manga/Berserk/Vol. 2/page.cbz") : la tokenisation ne voit que le
      // basename, il faut donc relire le chemin.
      final pathMeta = _mangaPathMetadata(filename);
      volume ??= pathMeta.volume;
      chapter ??= pathMeta.chapter;
      // Un fichier de page ("page.cbz") n'est pas un titre : on préfère le
      // dossier manga ("Berserk").
      final parentTitle = _mangaParentTitle(filename);
      if (parentTitle != null && _isPageLikeTitle(title)) {
        title = parentTitle;
      }
    }

    // ── 10. Clé canonique ────────────────────────────────────────────────
    final canonical = CanonicalKey.generate(title.isEmpty ? filename : title);

    // ── 11. Score de confiance ────────────────────────────────────────────
    final conf = _computeConfidence(
      hasTitle: title.isNotEmpty,
      hasEpisode: !episode.isEmpty,
      hasQuality: quality.resolution != null,
      hasLang: lang.language != null,
      tokenCount: tokens.length,
    );

    return NormalizeResult(
      title: title.isEmpty
          ? (yearFallback ?? _fallbackTitle(filename))
          : title,
      canonicalKey: canonical,
      kind: kind,
      season: episode.season,
      episode: episode.episode,
      chapter: chapter,
      volume: volume,
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

  /// Dernier segment du chemin (nom de fichier), utilisé pour savoir si un
  /// groupe de release a pu être collé par un tiret (`x265-GROUP`).
  static String _stem(String filename) {
    final parts = filename.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? filename : parts.last;
  }

  static String _fallbackTitle(String filename) {
    var name = filename;
    final slash = filename.lastIndexOf(RegExp(r'[/\\]'));
    if (slash >= 0) name = filename.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name.replaceAll(RegExp(r'[_\-\.]'), ' ').trim();
  }

  /// Extrait le volume/chapitre depuis les dossiers parents
  /// ("/Manga/Berserk/Vol. 2/page.cbz" → volume 2).
  static ({int? volume, int? chapter}) _mangaPathMetadata(String filename) {
    final parts = filename.split(RegExp(r'[/\\]'));
    int? volume, chapter;
    for (var i = 0; i < parts.length - 1; i++) {
      final seg = parts[i];
      final vol = RegExp(
        r'^(?:volume|vol)[ ._-]{1,2}(\d{1,4})$',
        caseSensitive: false,
      ).firstMatch(seg);
      if (vol != null) {
        volume ??= int.parse(vol.group(1)!);
        continue;
      }
      final chap = RegExp(
        r'^(?:chapter|chap|ch)[ ._-]{1,2}(\d{1,5})$',
        caseSensitive: false,
      ).firstMatch(seg);
      if (chap != null) chapter ??= int.parse(chap.group(1)!);
    }
    return (volume: volume, chapter: chapter);
  }

  /// Vrai si le "titre" n'est en réalité qu'un nom de page générique
  /// ("page", "001", "cover"…), auquel cas le dossier manga est plus fiable.
  static bool _isPageLikeTitle(String title) {
    final normalized = title.toLowerCase().trim();
    if (normalized.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;
    return const {
      'page',
      'pages',
      'scan',
      'scan1',
      'cover',
      'front',
      'back',
      'img',
      'image',
      'photo',
      'untitled',
    }.contains(normalized);
  }

  static String? _mangaParentTitle(String filename) {
    final parts = filename
        .split(RegExp(r'[/\\]'))
        .where((part) => part.isNotEmpty)
        .toList();
    const mangaFolders = {
      'manga',
      'manhwa',
      'manhua',
      'comic',
      'comics',
      'scan',
      'scans',
    };
    for (var i = 0; i < parts.length - 1; i++) {
      if (mangaFolders.contains(parts[i].toLowerCase()) &&
          i + 1 < parts.length - 1) {
        return _cleanTitle(parts[i + 1]);
      }
    }
    return null;
  }

  static LocalMediaKind _detectKind(String filename, EpisodeResult ep) {
    final ext = _extension(filename).toLowerCase();
    // Formats exclusivement manga/comics
    if (const {'.cbz', '.cbr', '.cbt', '.cb7'}.contains(ext)) {
      return LocalMediaKind.manga;
    }
    // A plain ZIP is treated as manga only when its path or name gives a
    // comic/chapter signal. This avoids indexing arbitrary ZIP downloads as
    // manga while still supporting common manga archives.
    if (ext == '.zip' &&
        (RegExp(
              r'(^|[/\\._ -])(manga|comic|comics|scanlation)([/\\._ -]|$)',
            ).hasMatch(filename.toLowerCase()) ||
            RegExp(
              r'\b(ch(?:apter)?|vol(?:ume)?)\.?\s*\d+',
              caseSensitive: false,
            ).hasMatch(filename))) {
      return LocalMediaKind.manga;
    }
    // Novels
    if (const {'.epub', '.mobi', '.azw3'}.contains(ext)) {
      return LocalMediaKind.novel;
    }
    // Vidéo → anime, série ou film.  An episode is a series by default;
    // "anime" is reserved for an explicit anime directory signal so that
    // ordinary TV episodes are not misclassified.
    if (const {
      '.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.mpg', '.ts',
      '.m2ts', '.mts', '.m4v', '.webm', '.3gp',
    }.contains(ext)) {
      if (ep.episode != null || ep.season != null) {
        final pathParts = filename
            .split(RegExp(r'[/\\]'))
            .map((part) => part.toLowerCase())
            .toSet();
        if (pathParts.contains('anime') || pathParts.contains('anime series')) {
          return LocalMediaKind.anime;
        }
        return LocalMediaKind.series;
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
