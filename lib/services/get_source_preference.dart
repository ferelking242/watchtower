import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/source.dart';

const extensionDefaultQualityKey = '__watchtower_default_quality';
const extensionQualityFallbackKey = '__watchtower_quality_fallback';
const extensionLanguagesKey = '__watchtower_languages';
const extensionKeepSessionKey = '__watchtower_keep_session';

List<SourcePreference> getSourcePreference({required Source source}) {
  final service = getExtensionService(source, "");
  try {
    final preferences = service.getSourcePreferences()
        .map((preference) => preference..sourceId = source.id)
        .toList();
    return withWatchtowerDefaults(source, preferences);
  } finally {
    service.dispose();
  }
}

List<SourcePreference> withWatchtowerDefaults(
  Source source,
  List<SourcePreference> preferences,
) {
  final result = [...preferences];
  bool hasKey(String key) => result.any((preference) => preference.key == key);

  final qualities = _qualityOptions(source);
  if (qualities.isNotEmpty && !hasKey(extensionDefaultQualityKey)) {
    result.add(
      SourcePreference(
        sourceId: source.id,
        key: extensionDefaultQualityKey,
        listPreference: ListPreference(
          title: 'Qualité vidéo par défaut',
          summary: 'Priorité utilisée quand plusieurs qualités sont disponibles.',
          valueIndex: _defaultQualityIndex(qualities),
          entries: qualities,
          entryValues: qualities,
        ),
      ),
    );
    result.add(
      SourcePreference(
        sourceId: source.id,
        key: extensionQualityFallbackKey,
        listPreference: ListPreference(
          title: 'Qualité de secours',
          summary: 'Choix appliqué si la qualité demandée est indisponible.',
          valueIndex: 1,
          entries: const [
            'Qualité immédiatement supérieure',
            'Qualité immédiatement inférieure',
          ],
          entryValues: const ['higher', 'lower'],
        ),
      ),
    );
  }

  final languages = source.supportedLanguages;
  if (languages.length > 1 && !hasKey(extensionLanguagesKey)) {
    result.add(
      SourcePreference(
        sourceId: source.id,
        key: extensionLanguagesKey,
        multiSelectListPreference: MultiSelectListPreference(
          title: 'Langues préférées',
          summary: 'Sélectionnez une ou plusieurs langues proposées par la source.',
          entries: languages.map(_languageLabel).toList(growable: false),
          entryValues: languages,
          values: List<String>.from(languages),
        ),
      ),
    );
  }

  if (!hasKey(extensionKeepSessionKey)) {
    result.add(
      SourcePreference(
        sourceId: source.id,
        key: extensionKeepSessionKey,
        switchPreferenceCompat: SwitchPreferenceCompat(
          title: 'Conserver la connexion',
          summary: 'Garder la session et les cookies pour les requêtes et le WebView.',
          value: true,
        ),
      ),
    );
  }
  return result;
}

List<String> _qualityOptions(Source source) {
  final declared = (source.videoQualities ?? const <String>[])
      .map((quality) => quality.trim())
      .where((quality) => quality.isNotEmpty);
  final values = <String>{...declared};
  if (values.isEmpty) {
    // Some older catalogue entries predate the videoQualities field. Their
    // JS manifest can still declare the same contract in sourceCode.
    final match = RegExp(
      r'(?:videoQualities|qualities)\s*:\s*\[([^\]]*)\]',
      caseSensitive: false,
    ).firstMatch(source.sourceCode ?? '');
    if (match != null) {
      values.addAll(
        RegExp(r'''['"]([^'"]+)['"]''')
            .allMatches(match.group(1)!)
            .map((match) => match.group(1)!.trim())
            .where((quality) => quality.isNotEmpty),
      );
    }
  }
  // AUTO is a safe universal fallback for extensions that choose the
  // available stream dynamically and do not publish a quality list.
  return (values.isEmpty ? {'AUTO'} : values).toList(growable: false);
}

int _defaultQualityIndex(List<String> qualities) {
  final auto = qualities.indexWhere((quality) =>
      quality.toLowerCase() == 'auto' || quality.toLowerCase() == 'original');
  return auto >= 0 ? auto : 0;
}

String _languageLabel(String language) {
  const labels = {
    'all': 'Toutes les langues',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
  };
  return labels[language] ?? language.toUpperCase();
}
