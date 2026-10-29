import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every locale must carry every key the catalogue surface defines, so the
/// generated `AppLocalizations` class stays uniform and a missing translation
/// surfaces as an untranslated *value* rather than a compile error in an
/// unrelated locale.
///
/// `tool/add_catalog_l10n.py` mirrors new keys into every ARB file, but it runs
/// by hand; this test is what catches a key that was added to `app_en.arb`
/// alone. Keys beginning with `@` are template-only metadata (placeholders,
/// descriptions) and are legitimately English-only.
///
/// Scope: only the `marketplace_` / `catalog_` / `browse_` namespaces. The
/// repository carries older gaps outside them (`explore_tab`, `for_you`,
/// `player_video`… are absent from most locales, and some locales still define
/// `mass_migration_*` / `statistics_*` keys the template dropped). Those predate
/// this refonte and are tracked in `untranslated_messages.txt`; widening this
/// test to them would report debt it does not own.
const _kOwnedPrefixes = ['marketplace_', 'catalog_', 'browse_'];

void main() {
  final dir = Directory('lib/l10n');
  final template =
      jsonDecode(File('${dir.path}/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;

  final translatable = template.keys
      .where((key) => !key.startsWith('@'))
      .where((key) => _kOwnedPrefixes.any(key.startsWith))
      .toSet();

  test('the template declares Marketplace and Browse keys', () {
    expect(
      translatable.where((key) => key.startsWith('marketplace_')).length,
      greaterThan(100),
      reason: 'the Marketplace surface is expected to be largely localised',
    );
    expect(translatable, contains('browse_marketplace'));
    expect(translatable, contains('catalog_tab_music'));
  });

  test('every locale defines every translatable key', () {
    final locales =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .where((file) => !file.path.endsWith('app_en.arb'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(locales, isNotEmpty, reason: 'no non-template ARB file was found');

    final gaps = <String, List<String>>{};
    for (final locale in locales) {
      final messages =
          jsonDecode(locale.readAsStringSync()) as Map<String, dynamic>;
      final missing =
          translatable.where((key) => !messages.containsKey(key)).toList()
            ..sort();
      if (missing.isNotEmpty) {
        gaps[locale.uri.pathSegments.last] = missing;
      }
    }

    expect(
      gaps,
      isEmpty,
      reason: 'these locales are missing template keys: $gaps',
    );
  });

  test('no locale defines a catalogue key the template does not', () {
    final extra = <String, List<String>>{};
    for (final locale in dir.listSync().whereType<File>()) {
      if (!locale.path.endsWith('.arb')) continue;
      final messages =
          jsonDecode(locale.readAsStringSync()) as Map<String, dynamic>;
      final unknown =
          messages.keys
              .where((key) => !key.startsWith('@'))
              .where((key) => _kOwnedPrefixes.any(key.startsWith))
              .where((key) => !translatable.contains(key))
              .toList()
            ..sort();
      if (unknown.isNotEmpty) {
        extra[locale.uri.pathSegments.last] = unknown;
      }
    }
    expect(extra, isEmpty, reason: 'keys with no template entry: $extra');
  });

  test('placeholders in a value match the declared placeholders', () {
    // The bug this pins: `marketplace_source_blurb` was written as
    // "{language} … {kind}" but declared no placeholders, so the generator
    // ordered the arguments alphabetically and the screen passed them
    // positionally — printing the content type where the language belonged.
    final metadata = template['@marketplace_source_blurb'] as Map?;
    final declared =
        (metadata?['placeholders'] as Map?)?.keys.cast<String>().toSet() ??
        const <String>{};
    expect(
      declared,
      equals({'language', 'kind'}),
      reason: 'the blurb takes both a language and a kind argument',
    );

    final value = template['marketplace_source_blurb'] as String;
    for (final name in declared) {
      expect(
        value,
        contains('{$name}'),
        reason: '$name is declared but never used in "$value"',
      );
    }
  });

  test('French is a genuine translation, not a copy of English', () {
    final french =
        jsonDecode(File('${dir.path}/app_fr.arb').readAsStringSync())
            as Map<String, dynamic>;
    final spotChecks = {
      'browse_marketplace': 'Marketplace',
      'browse_random_source': 'Source aléatoire',
      'browse_diagnostic': 'Diagnostic',
      'marketplace_sort_alpha': 'A → Z',
    };
    spotChecks.forEach((key, expected) {
      expect(french[key], equals(expected), reason: 'app_fr.arb["$key"]');
    });
    expect(french['marketplace_got_it'], equals('Compris'));
  });
}
