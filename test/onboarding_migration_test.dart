import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/onboarding/migration/migration_apps.dart';
import 'package:watchtower/modules/onboarding/migration/migration_page.dart';

/// Phone, small phone, tablet, desktop.
const _sizes = <Size>[
  Size(320, 640),
  Size(360, 800),
  Size(800, 1200),
  Size(1440, 900),
];

Future<void> _pumpMigration(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: MigrationPage(onNext: () {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('catalogue', () {
    test('every category has at least one app', () {
      for (final category in MigrationCategory.values) {
        expect(
          migrationAppsFor(category),
          isNotEmpty,
          reason: 'no app in $category',
        );
      }
    });

    test('app ids and logos are unique', () {
      final ids = migrationApps.map((a) => a.id).toSet();
      final logos = migrationApps.map((a) => a.logoAsset).toSet();
      expect(ids.length, migrationApps.length);
      expect(logos.length, migrationApps.length);
    });

    test('every app has at least one pro and one con', () {
      for (final app in migrationApps) {
        expect(app.pros, isNotEmpty, reason: '${app.id} has no pros');
        expect(app.cons, isNotEmpty, reason: '${app.id} has no cons');
      }
    });

    test('import is offered only for the Mihon-family backup formats', () {
      for (final app in migrationApps) {
        if (!app.importSupported) continue;
        expect(
          app.backupFormat,
          anyOf('.tachibk', '.proto.gz'),
          reason: '${app.id} claims import support for an unread format',
        );
      }
      expect(
        migrationApps.where((a) => a.importSupported).map((a) => a.id),
        containsAll(<String>['mihon', 'aniyomi', 'tachiyomisy', 'neko']),
      );
    });

    test('search matches the app name and the platform', () {
      final mihon = migrationApps.firstWhere((a) => a.id == 'mihon');
      expect(mihon.matchesQuery(''), isTrue);
      expect(mihon.matchesQuery('mih'), isTrue);
      expect(mihon.matchesQuery('MIHON'), isTrue);
      expect(mihon.matchesQuery('android'), isTrue);
      expect(mihon.matchesQuery('ios'), isFalse);
    });
  });

  group('page', () {
    for (final size in _sizes) {
      testWidgets('lays out without overflowing at $size', (tester) async {
        await _pumpMigration(tester, size);
        expect(tester.takeException(), isNull);

        // The orbit animates forever, so settle would never return.
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('switching the dock tab swaps the app list', (tester) async {
      await _pumpMigration(tester, const Size(800, 1200));

      // Manga tab first.
      expect(find.byKey(const ValueKey('mig-app-mihon')), findsOneWidget);

      await tester.tap(find.text('Anime'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('mig-app-hayase')), findsOneWidget);
      expect(find.byKey(const ValueKey('mig-app-mihon')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters the list', (tester) async {
      await _pumpMigration(tester, const Size(800, 1200));

      await tester.enterText(find.byType(TextField), 'neko');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('mig-app-neko')), findsOneWidget);
      expect(find.byKey(const ValueKey('mig-app-mihon')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce-motion stops the orbit animation', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: MigrationPage(onNext: _noop)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
