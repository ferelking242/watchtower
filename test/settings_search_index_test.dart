import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_search_index.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  group('Recherche globale des paramètres', () {
    test('« général » remonte des entrées de la page Général', () {
      final results = searchSettings('général', l10n);
      expect(results, isNotEmpty);
      expect(results.every((e) => e.matches('général', l10n)), isTrue);
      expect(
        results.any((e) => e.route == '/general'),
        isTrue,
        reason: 'la page Général doit être atteignable depuis la recherche',
      );
    });

    test("« don't kill » trouve l'entrée de la page Avancé", () {
      final results = searchSettings("don't kill", l10n);
      expect(results, isNotEmpty);
      expect(results.any((e) => e.title(l10n) == "Don't kill my app!"), isTrue);
      expect(results.first.route, '/advanced');
    });

    test('la recherche traverse les sous-pages, pas seulement la page ouverte',
        () {
      // « doh » ne figure pas dans un titre : le trouver prouve que l'index
      // couvre bien toutes les pages via les mots-clés.
      expect(
        searchSettings('doh', l10n).any((e) => e.route == '/general'),
        isTrue,
      );
      expect(
        searchSettings('catégorie', l10n).any(
          (e) => e.route == '/librarySettings',
        ),
        isTrue,
      );
      expect(
        searchSettings('volume', l10n).any((e) => e.route == '/readerMode'),
        isTrue,
      );
    });

    test('une requête vide renvoie tout l\'index', () {
      expect(searchSettings('', l10n).length, kSettingsSearchIndex.length);
    });

    test('les libellés suivent la locale active', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final frTitles = kSettingsSearchIndex.map((e) => e.title(l10n)).toSet();
      final enTitles = kSettingsSearchIndex.map((e) => e.title(en)).toSet();
      expect(frTitles, isNot(equals(enTitles)));
      expect(enTitles, contains('About'));
      expect(frTitles, contains('À propos'));
    });
  });
}
