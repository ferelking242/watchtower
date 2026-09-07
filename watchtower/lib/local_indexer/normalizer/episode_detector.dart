/// Étape 5 du pipeline : Détection saison / épisode / chapitre / volume.

class EpisodeResult {
  final int? season;
  final int? episode;
  final int? chapter;
  final int? volume;
  final int? part;

  /// Indices des tokens qui ont servi à construire ce résultat
  /// (à retirer de la liste avant extraction du titre).
  final Set<int> consumedIndices;

  const EpisodeResult({
    this.season,
    this.episode,
    this.chapter,
    this.volume,
    this.part,
    required this.consumedIndices,
  });

  bool get isEmpty =>
      season == null &&
      episode == null &&
      chapter == null &&
      volume == null &&
      part == null;
}

class EpisodeDetector {
  // S01E05 / S1E5 / S01E005
  static final _sXeX = RegExp(
    r'^[Ss](\d{1,3})[Ee](\d{1,4})(?:[Ee](\d{1,4}))?$',
  );

  // E05 / E5 standalone
  static final _eX = RegExp(r'^[Ee](\d{1,4})$');

  // S01 standalone
  static final _sX = RegExp(r'^[Ss](\d{1,3})$');

  // Episode 5 / Ep.5 / EP05
  static final _epWord = RegExp(
    r'^(?:Episode|Ep\.?|EP)(\d{1,4})$',
    caseSensitive: false,
  );

  // Chapter / Ch. / Ch
  static final _chap = RegExp(
    r'^(?:Chapter|Ch\.?|Chap\.?)(\d{1,5})(?:\.(\d+))?$',
    caseSensitive: false,
  );

  // Volume / Vol. / Vol
  static final _vol = RegExp(
    r'^(?:Volume|Vol\.?)(\d{1,4})$',
    caseSensitive: false,
  );

  // Numéro standalone : 01, 001, 1080 is excluded by QualityDetector
  // Valide seulement si entre 1 et 4 chiffres, pas déjà résolution
  static final _bareNumber = RegExp(r'^0*(\d{1,4})$');

  // Résolutions connues à ne pas confondre avec des épisodes
  static const _resolutions = {'2160', '1080', '720', '480', '360', '4096', '2048'};

  static EpisodeResult detect(List<String> tokens) {
    int? season, episode, chapter, volume, part;
    final consumed = <int>{};

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];

      // S01E05
      final m1 = _sXeX.firstMatch(t);
      if (m1 != null) {
        season = int.parse(m1.group(1)!);
        episode = int.parse(m1.group(2)!);
        consumed.add(i);
        continue;
      }

      // S01 standalone
      final m3 = _sX.firstMatch(t);
      if (m3 != null) {
        season = int.parse(m3.group(1)!);
        consumed.add(i);
        continue;
      }

      // E05 standalone
      final m2 = _eX.firstMatch(t);
      if (m2 != null) {
        episode = int.parse(m2.group(1)!);
        consumed.add(i);
        continue;
      }

      // Episode word
      final m4 = _epWord.firstMatch(t);
      if (m4 != null) {
        episode = int.parse(m4.group(1)!);
        consumed.add(i);
        continue;
      }

      // Chapter
      final m5 = _chap.firstMatch(t);
      if (m5 != null) {
        chapter = int.parse(m5.group(1)!);
        consumed.add(i);
        continue;
      }

      // Volume
      final m6 = _vol.firstMatch(t);
      if (m6 != null) {
        volume = int.parse(m6.group(1)!);
        consumed.add(i);
        continue;
      }
    }

    // Heuristique : si on n'a pas trouvé d'épisode et qu'il reste un bare
    // number isolé au milieu ou à la fin (ex: "Naruto 014"), on le prend.
    if (episode == null && chapter == null) {
      for (var i = 0; i < tokens.length; i++) {
        if (consumed.contains(i)) continue;
        final m = _bareNumber.firstMatch(tokens[i]);
        if (m == null) continue;
        final n = int.parse(m.group(1)!);
        // Ignorer si c'est une résolution connue
        if (_resolutions.contains(n.toString())) continue;
        // Ne prendre que si c'est dans un range raisonnable pour un épisode
        if (n >= 1 && n <= 9999) {
          episode = n;
          consumed.add(i);
          break;
        }
      }
    }

    return EpisodeResult(
      season: season,
      episode: episode,
      chapter: chapter,
      volume: volume,
      part: part,
      consumedIndices: consumed,
    );
  }
}
