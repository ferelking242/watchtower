import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_search_index.dart';

void main() {
  group('Recherche globale des paramètres', () {
    test('« général » remonte des entrées de la page Général', () {
      final results = searchSettings('général');
      expect(results, isNotEmpty);
      expect(results.every((e) => e.matches('général')), isTrue);
      expect(
        results.any((e) => e.route == '/general'),
        isTrue,
        reason: 'la page Général doit être atteignable depuis la recherche',
      );
    });

    test('« don\'t kill » trouve l\'entrée de la page Avancé', () {
      final results = searchSettings("don't kill");
      expect(results, isNotEmpty);
      expect(results.any((e) => e.title == "Don't kill my app!"), isTrue);
      expect(results.first.route, '/advanced');
    });

    test('la recherche traverse les sous-pages, pas seulement la page ouverte',
        () {
      // « hub » ne figure pas dans le titre « Général » : la trouver prouve
      // que l'index couvre bien toutes les pages.
      expect(searchSettings('doh').any((e) => e.route == '/general'), isTrue);
      expect(
        searchSettings('catégorie').any((e) => e.route == '/librarySettings'),
        isTrue,
      );
      expect(
        searchSettings('volume').any((e) => e.route == '/readerMode'),
        isTrue,
      );
    });

    test('une requête vide renvoie tout l\'index', () {
      expect(searchSettings('').length, kSettingsSearchIndex.length);
    });
  });
}
