import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/modules/browse/marketplace_skeleton.dart';
import 'package:watchtower/modules/updates/notifications_screen.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/utils/mock_isar.dart';

ExtensionPublicationNotice _notice(int id, {String name = 'Pornhub'}) =>
    ExtensionPublicationNotice(
      id: id,
      name: name,
      itemType: ItemType.anime,
      version: '1.0.$id',
      lang: 'en',
    );

/// An installed extension offering a newer version.
Source _pendingUpdate(int id, String name) {
  final source = Source(
    id: id,
    name: name,
    itemType: ItemType.anime,
    isAdded: true,
    version: '1.0.0',
  );
  source.versionLast = '2.0.0';
  return source;
}

class _NoRepos extends ExtensionsRepoState {
  _NoRepos(this._type);

  final ItemType _type;

  @override
  List<Repo> build(ItemType itemType) => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExtensionCatalogNotifications dismissed updates', () {
    test('an acknowledged signature is reported back', () async {
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 7,
        itemType: ItemType.anime,
        signature: '1:7:1.2.0|',
      );

      final dismissed =
          await ExtensionCatalogNotifications.dismissedUpdateSignatures();
      expect(dismissed, contains('1:7:1.2.0|'));
    });

    test('an unknown extension has no acknowledged signature', () async {
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 7,
        itemType: ItemType.anime,
        signature: '1:7:1.2.0|',
      );

      final dismissed =
          await ExtensionCatalogNotifications.dismissedUpdateSignatures();
      expect(dismissed, isNot(contains('1:8:1.2.0|')));
    });

    test('recording the same signature twice is idempotent', () async {
      for (var i = 0; i < 3; i++) {
        await ExtensionCatalogNotifications.dismissPendingUpdate(
          id: 7,
          itemType: ItemType.anime,
          signature: '1:7:1.2.0|',
        );
      }

      final dismissed =
          await ExtensionCatalogNotifications.dismissedUpdateSignatures();
      expect(dismissed.where((s) => s == '1:7:1.2.0|').length, 1);
    });

    test('clearing one extension keeps other extensions signatures', () async {
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 7,
        itemType: ItemType.anime,
        signature: '1:7:1.2.0|',
      );
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 9,
        itemType: ItemType.manga,
        signature: '1:9:2.0.0|',
      );

      await ExtensionCatalogNotifications.clearDismissedUpdates(
        id: 7,
        itemType: ItemType.anime,
      );

      final dismissed =
          await ExtensionCatalogNotifications.dismissedUpdateSignatures();
      expect(dismissed, isNot(contains('1:7:1.2.0|')));
      expect(dismissed, contains('1:9:2.0.0|'));
    });

    test('a newer version of the same extension is not pre-acknowledged',
        () async {
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 7,
        itemType: ItemType.anime,
        signature: '1:7:1.2.0|',
      );

      final dismissed =
          await ExtensionCatalogNotifications.dismissedUpdateSignatures();
      // The ledger is keyed by version, so 1.3.0 is a different entry.
      expect(dismissed, isNot(contains('1:7:1.3.0|')));
    });

    test('dismissing without a signature leaves the ledger untouched',
        () async {
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: 7,
        itemType: ItemType.anime,
      );

      expect(
        await ExtensionCatalogNotifications.dismissedUpdateSignatures(),
        isEmpty,
      );
    });
  });

  group('ExtensionCatalogNotifications new publications', () {
    test('the first catalogue fetch announces nothing', () async {
      final published = await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: 'https://example.test/index/anime.json',
        entries: [_notice(1), _notice(2)],
      );
      expect(published, isEmpty);
    });

    test('a later addition is announced exactly once', () async {
      const url = 'https://example.test/index/anime.json';
      await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1)],
      );

      final first = await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1), _notice(2)],
      );
      expect(first.map((n) => n.id), [2]);

      final second = await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1), _notice(2)],
      );
      expect(second, isEmpty);
    });

    test('a partial fetch does not re-announce known extensions', () async {
      const url = 'https://example.test/index/anime.json';
      await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1), _notice(2)],
      );

      // A transient response that only carries one entry must not shrink the
      // ledger, or the next full fetch would look like a new publication.
      await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1)],
      );

      final afterRecovery = await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(1), _notice(2)],
      );
      expect(afterRecovery, isEmpty);
    });

    test('a dismissed publication stays dismissed', () async {
      const url = 'https://example.test/index/anime.json';
      await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: const [],
      );
      await ExtensionCatalogNotifications.observeCatalog(
        catalogUrl: url,
        entries: [_notice(5)],
      );
      expect((await ExtensionCatalogNotifications.pending()).length, 1);

      await ExtensionCatalogNotifications.dismiss(_notice(5));
      expect(await ExtensionCatalogNotifications.pending(), isEmpty);
    });
  });

  group('MarketplaceSkeleton', () {
    testWidgets('fills the viewport with the page structure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(child: MarketplaceSkeleton()),
          ),
        ),
      );
      await tester.pump();

      // The skeleton is taller than the phone viewport, so it covers the whole
      // first screen instead of leaving the bottom empty.
      expect(
        tester.getSize(find.byType(MarketplaceSkeleton)).height,
        greaterThan(2400 / 3),
      );
      // The 2 × 2 shelf grids are part of the skeleton.
      expect(find.byType(GridView), findsWidgets);
    });

    testWidgets('renders in both themes without overflowing', (tester) async {
      for (final theme in [ThemeData.dark(), ThemeData.light()]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(child: MarketplaceSkeleton()),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('plugin skeleton renders a single column of rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: MarketplacePluginSkeleton()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MarketplacePluginSkeleton), findsOneWidget);
    });
  });

  group('MarketplacePalette', () {
    testWidgets('exposes skeleton colours for both themes', (tester) async {
      for (final theme in [ThemeData.dark(), ThemeData.light()]) {
        late MarketplacePalette palette;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                palette = MarketplacePalette.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(palette.skeletonBase, isNot(palette.skeletonHighlight));
      }
    });
  });

  group('NotificationsScreen grouping', () {
    late MockIsar isar;

    // The screen refreshes extension repositories on open; point every content
    // type at an empty list so the test never touches the network.
    Widget host() => ProviderScope(
      overrides: [
        for (final type in ItemType.values)
          extensionsRepoStateProvider(type).overrideWith(() => _NoRepos(type)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsScreen(),
      ),
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      isar = MockIsar();
      app.isar = isar;
    });

    testWidgets('three pending updates render as one grouped message', (
      tester,
    ) async {
      isar.seed<Source>(11, _pendingUpdate(11, 'Pornhub'));
      isar.seed<Source>(12, _pendingUpdate(12, 'Xhamster'));
      isar.seed<Source>(13, _pendingUpdate(13, 'Redtube'));

      await tester.pumpWidget(host());
      // First frame shows the loader; then the (empty) catalogue refresh runs.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // One message, not three: the count sentence names the batch.
      expect(find.text('3 extension updates'), findsOneWidget);
      // The children start collapsed, so no per-extension row is painted yet.
      expect(find.text('Pornhub extension update'), findsNothing);

      // Expanding the message reveals the three children.
      await tester.tap(find.text('3 extension updates'));
      await tester.pump();
      expect(find.text('Pornhub extension update'), findsOneWidget);
      expect(find.text('Xhamster extension update'), findsOneWidget);
      expect(find.text('Redtube extension update'), findsOneWidget);
    });

    testWidgets('a single update opens directly on its message', (
      tester,
    ) async {
      isar.seed<Source>(21, _pendingUpdate(21, 'Pornhub'));

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Pornhub extension update'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('an acknowledged update is hidden until a newer version', (
      tester,
    ) async {
      final source = _pendingUpdate(31, 'Pornhub');
      isar.seed<Source>(31, source);
      // Seed the acknowledgement ledger directly: the screen only reads it.
      SharedPreferences.setMockInitialValues({
        'watchtower_extension_updates_dismissed_v1': <String>['1:31:2.0.0|'],
      });

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Pornhub extension update'), findsNothing);
    });

    testWidgets('a new publication is listed with its type and language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'watchtower_extension_catalog_pending_v1': <String>[
          jsonEncode(_notice(41, name: 'NewSource').toJson()),
        ],
      });

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('NewSource'), findsOneWidget);
      expect(find.textContaining('EN'), findsOneWidget);
    });
  });
}
