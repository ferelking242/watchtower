import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A push to a route that does not exist silently bounces the user back to the
/// app shell (`onException` in `router.dart`), so a typo in a tile's route looks
/// like "the button does nothing". These checks read the real sources: the
/// router for the routes that exist, and every `context.push('/…')` call site.
void main() {
  late final String routerSource;
  late final Set<String> reachable;

  setUpAll(() {
    routerSource = File('lib/router/router.dart').readAsStringSync();

    // GoRoute entries name their route either with `name:` or through
    // `_genericRoute(name: …)`; the path defaults to "/<name>".
    final names = <String>{
      ...RegExp(
        r'_genericRoute\(\s*(?:name:\s*)?"([^"]+)"',
      ).allMatches(routerSource).map((m) => m.group(1)!),
      ...RegExp(
        r'name:\s*"([^"]+)"',
      ).allMatches(routerSource).map((m) => m.group(1)!),
      ...RegExp(
        r"name:\s*'([^']+)'",
      ).allMatches(routerSource).map((m) => m.group(1)!),
    };
    final paths = <String>{
      ...RegExp(
        r'path:\s*"([^"]+)"',
      ).allMatches(routerSource).map((m) => m.group(1)!),
      ...RegExp(
        r"path:\s*'([^']+)'",
      ).allMatches(routerSource).map((m) => m.group(1)!),
    };
    reachable = {...names, ...paths, for (final n in names) '/$n', '/'};
  });

  test('the router still declares the settings pages the hub links to', () {
    // Guards against the check below passing because the router went missing.
    expect(reachable, contains('/customNavigationSettings'));
    expect(reachable, contains('/readerMode'));
  });

  test('every pushed settings route exists', () {
    // Two shapes: a literal path (`context.push('/general')`) and a record
    // field that a tile pushes (`route: '/general'` then `context.push(route)`).
    // The second shape is how `more_screen.dart` links its tiles, so a typo
    // there is invisible to a literal-only scan.
    final pushLiteral = RegExp(
      r'(?:context\.(?:push|go|replace|pushReplacement)|pushNamed)'
      r'\s*\(\s*[\x27\x22]([^\x27\x22]+)[\x27\x22]',
    );
    final routeField = RegExp(r'route:\s*[\x27\x22]([^\x27\x22]+)[\x27\x22]');
    final pushedIdentifier = RegExp(
      r'context\.(?:push|go)\s*\(\s*[A-Za-z_][A-Za-z0-9_]*\s*[,)]',
    );

    final dead = <String, Set<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('lib/router/router.dart')) continue;
      final source = entity.readAsStringSync();

      final candidates = <String>{
        for (final m in pushLiteral.allMatches(source))
          if (m.group(1)!.startsWith('/')) m.group(1)!,
        // Only treat `route:` fields as navigation when the file also pushes a
        // variable — otherwise they are unrelated data (file paths, URLs).
        if (pushedIdentifier.hasMatch(source))
          for (final m in routeField.allMatches(source))
            if (m.group(1)!.startsWith('/')) m.group(1)!,
      };

      for (final target in candidates) {
        if (reachable.contains(target)) continue;
        dead.putIfAbsent(target, () => <String>{}).add(entity.path);
      }
    }

    expect(
      dead,
      isEmpty,
      reason:
          'ces routes sont poussées mais n\'existent pas dans le routeur, '
          'donc l\'utilisateur revient à l\'accueil au lieu d\'ouvrir la page',
    );
  });
}
