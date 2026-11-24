import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/about/update_page.dart';

void main() {
  test('drops the CI trailer from a release body', () {
    const raw = '''
### 🐛 Corrections

- fix(playback): keep the HLS master

APK Android arm64 construit depuis `main`.

SHA-256 : abc123
Taille : 57770161 octets (exactement — un fichier plus petit est tronqué).

**Comparaison** : https://github.com/o/r/compare/a...b
''';
    final cleaned = cleanReleaseNotes(raw);
    expect(cleaned, contains('### 🐛 Corrections'));
    expect(cleaned, contains('- fix(playback): keep the HLS master'));
    expect(cleaned, isNot(contains('SHA-256')));
    expect(cleaned, isNot(contains('APK Android')));
    expect(cleaned, isNot(contains('Comparaison')));
    expect(cleaned, isNot(contains('Taille :')));
  });

  test('drops the duplicated Nouveautés heading', () {
    final cleaned = cleanReleaseNotes('## Nouveautés\n\n- one change\n');
    expect(cleaned, '- one change');
  });

  test('drops the generated title and build line from history notes', () {
    const raw = '''
# Watchtower 8.1.613

Build automatique depuis `main` — commit `902d1d7` — 2026-11-24.

## ✨ Nouveautés

- feat(reader): screen lock
''';
    final cleaned = cleanReleaseNotes(raw);
    expect(cleaned, startsWith('## ✨ Nouveautés'));
    expect(cleaned, contains('- feat(reader): screen lock'));
    expect(cleaned, isNot(contains('Watchtower 8.1.613')));
    expect(cleaned, isNot(contains('Build automatique')));
  });

  test('returns an empty string for empty notes', () {
    expect(cleanReleaseNotes('  \n '), isEmpty);
  });
}
