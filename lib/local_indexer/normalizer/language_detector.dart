/// Étape 6 du pipeline : Détection de la langue / version audio.

class LanguageResult {
  final String? language;       // "VOSTFR", "VF", "EN", "JP"…
  final bool isSubbed;          // sous-titres présents
  final bool isDubbed;          // doublage présent
  final Set<int> consumedIndices;

  const LanguageResult({
    this.language,
    this.isSubbed = false,
    this.isDubbed = false,
    required this.consumedIndices,
  });
}

class LanguageDetector {
  static final _langMap = <Pattern, String>{
    // Français
    RegExp(r'^VOSTFR$', caseSensitive: false): 'VOSTFR',
    RegExp(r'^VFF?$', caseSensitive: false): 'VF',
    RegExp(r'^TRUEFRENCH$', caseSensitive: false): 'VF',
    RegExp(r'^FRENCH$', caseSensitive: false): 'VF',
    RegExp(r'^FR$', caseSensitive: false): 'VF',
    // Multi
    RegExp(r'^MULTI(?:FR)?$', caseSensitive: false): 'MULTI',
    RegExp(r'^DUAL(?:AUDIO)?$', caseSensitive: false): 'DUAL',
    // Anglais
    RegExp(r'^(?:ENG?|ENGLISH)$', caseSensitive: false): 'EN',
    RegExp(r'^VO$', caseSensitive: false): 'VO',
    // Japonais
    RegExp(r'^(?:JA?P(?:ANESE)?)$', caseSensitive: false): 'JP',
    // Espagnol
    RegExp(r'^(?:ES|ESP|SPANISH)$', caseSensitive: false): 'ES',
    // Allemand
    RegExp(r'^(?:DE|GER|GERMAN)$', caseSensitive: false): 'DE',
    // Portugais
    RegExp(r'^(?:PT|POR|PORTUGUESE|PtBr)$', caseSensitive: false): 'PT',
    // Arabe
    RegExp(r'^(?:AR|ARA|ARABIC)$', caseSensitive: false): 'AR',
    // Coréen
    RegExp(r'^(?:KO|KOR|KOREAN)$', caseSensitive: false): 'KO',
    // Chinois
    RegExp(r'^(?:ZH|CHI|CHINESE)$', caseSensitive: false): 'ZH',
  };

  static final _subPattern = RegExp(
    r'^(?:SUB(?:BED|TITLE)?|SOFTSUB|HARDSUB)$',
    caseSensitive: false,
  );
  static final _dubPattern = RegExp(r'^DUB(?:BED)?$', caseSensitive: false);

  static LanguageResult detect(List<String> tokens) {
    String? language;
    bool isSubbed = false, isDubbed = false;
    final consumed = <int>{};

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];

      if (_subPattern.hasMatch(t)) {
        isSubbed = true;
        consumed.add(i);
        continue;
      }
      if (_dubPattern.hasMatch(t)) {
        isDubbed = true;
        consumed.add(i);
        continue;
      }

      if (language == null) {
        for (final entry in _langMap.entries) {
          final matches = entry.key is RegExp
              ? (entry.key as RegExp).hasMatch(t)
              : entry.key == t;
          if (matches) {
            language = entry.value;
            consumed.add(i);
            break;
          }
        }
      }
    }

    return LanguageResult(
      language: language,
      isSubbed: isSubbed,
      isDubbed: isDubbed,
      consumedIndices: consumed,
    );
  }
}
