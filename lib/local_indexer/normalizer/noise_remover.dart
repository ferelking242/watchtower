/// Étape 3 du pipeline : Suppression du bruit (tags de release).
///
/// Retire de la liste de tokens tous les éléments qui ne font pas partie
/// du titre réel ou des métadonnées utiles (saison, épisode, qualité…).
class NoiseRemover {
  /// Tags de release connus à ignorer (insensible à la casse).
  static const _noiseTokens = <String>{
    // Encodeurs / groupes communs
    'bluray', 'blu-ray', 'bdrip', 'brrip', 'dvdrip', 'dvd', 'dvdscr',
    'hdtv', 'hdrip', 'webrip', 'web-dl', 'webdl', 'web', 'amzn', 'nf',
    'dsnp', 'cr', 'hmax',
    // Remasters / versions
    'repack', 'proper', 'extended', 'theatrical', 'unrated', 'directors',
    'cut', 'remastered', 'remux', 'dual', 'audio',
    // Tags génériques
    'avi', 'mp4', 'mkv', 'mov', 'flv', 'wmv', 'ts', 'mts', 'm2ts',
    'cbz', 'cbr', 'epub', 'zip',
    // Inutiles
    'www', 'http', 'https', 'com', 'net', 'org',
    'sample', 'trailer', 'bonus', 'extra', 'special', 'ova', 'ona',
    // Résolutions (gérées par QualityDetector)
    '2160p', '1080p', '1080i', '720p', '480p', '360p', '4k', '8k',
    // Codecs (gérés par QualityDetector)
    'x264', 'x265', 'h264', 'h265', 'hevc', 'avc', 'av1', 'vp9',
    'xvid', 'divx',
    // Audio (gérés par QualityDetector)
    'aac', 'ac3', 'dts', 'flac', 'mp3', 'opus', 'truehd', 'atmos',
    'dd', 'ddp', 'eac3',
    // Bit-depth / HDR
    '10bit', '10-bit', '8bit', '8-bit', 'hdr', 'hdr10', 'hdr10+',
    'dolbyvision', 'dv', 'sdr',
    // Langues (gérées par LanguageDetector)
    'vostfr', 'vf', 'vff', 'vo', 'multi', 'french', 'english', 'japanese',
    'spanish', 'german', 'portuguese', 'arabic', 'sub', 'dub',
    // Checksums / hashes
    'crc32',
  };

  /// Pattern pour détecter un CRC32 en fin de token (ex: [ABCD1234])
  static final _crc32Pattern = RegExp(r'^[0-9A-Fa-f]{8}$');

  /// Pattern pour détecter un hash ou ID alphanumérique aléatoire
  static final _hashPattern = RegExp(r'^[0-9A-Fa-f]{6,}$');

  /// Retourne `true` si le token est du bruit à ignorer.
  static bool isNoise(String token) {
    final lower = token.toLowerCase();

    // Tokens connus
    if (_noiseTokens.contains(lower)) return true;

    // CRC32 ou hash hex
    if (_crc32Pattern.hasMatch(token) || _hashPattern.hasMatch(token)) {
      return true;
    }

    // Purement numérique et pas un numéro d'épisode/chapitre apparent
    if (RegExp(r'^\d{5,}$').hasMatch(token)) return true;

    return false;
  }

  /// Filtre la liste de tokens et retourne uniquement les non-bruits.
  static List<String> remove(List<String> tokens) {
    return tokens.where((t) => !isNoise(t)).toList();
  }
}
