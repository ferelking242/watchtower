import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget localized(Widget child) => MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('offline hub keeps the skeleton sections and adds one notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(const MediaHomeLoading(isSeries: false, showOfflineNotice: true)),
    );
    await tester.pump();

    // The page keeps its shape: the spotlight and section titles are there.
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Trending this week'), findsOneWidget);
    // Exactly one inline "no connection" box, right after the spotlight.
    expect(find.text('Aucune connexion réseau'), findsOneWidget);
  });

  testWidgets('online hub skeleton shows no offline notice', (tester) async {
    await tester.pumpWidget(
      localized(const MediaHomeLoading(isSeries: false)),
    );
    await tester.pump();

    expect(find.text('Aucune connexion réseau'), findsNothing);
    expect(find.text('Popular'), findsOneWidget);
  });
}
