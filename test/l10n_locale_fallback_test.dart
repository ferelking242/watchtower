import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// `MaterialApp` is given the union of the app's and the music module's
/// supported locales. When the resolved locale is one only the music module
/// translates (or no module translates), `AppLocalizations.of` returns null and
/// every call site's `!` used to throw on the first build — which replaced every
/// screen with the friendly error view while the rest of the app kept running.
void main() {
  testWidgets('a locale without an app table falls back to English', (
    tester,
  ) async {
    late String library;
    await tester.pumpWidget(
      MaterialApp(
        // No app delegate: `AppLocalizations.of` returns null for every locale,
        // exactly like a locale the app has no translation table for.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            library = l10nLocalizations(context)!.library;
            return Text(context.l10n.library);
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(library, 'Library');
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('a supported locale still uses its own table', (tester) async {
    late String library;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Builder(
          builder: (context) {
            library = l10nLocalizations(context)!.library;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(library, isNot('Library'));
  });
}
