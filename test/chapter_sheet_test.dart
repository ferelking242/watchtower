import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/widgets/chapter_sheet.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// The chapter sheet is the reader's only way to jump between chapters, so the
/// list it shows, the order it shows them in and the row that opens the reader
/// all have to be exercised against a real (mocked) Isar store rather than a
/// stubbed provider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mangaId = 7;
  late MockIsar testIsar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The sort/filter panel is taller than the default 600 px test surface, so
    // give it room; otherwise the lower entries cannot be tapped at all.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(900, 1600)
      ..devicePixelRatio = 1.0;
    testIsar = MockIsar();
    app.isar = testIsar;
    testIsar.seed<Settings>(kSettingsId, Settings()..incognitoMode = false);
    testIsar.seed<Manga>(
      mangaId,
      Manga(
        id: mangaId,
        source: 'Harimanga',
        author: '',
        artist: '',
        genre: const [],
        imageUrl: '',
        lang: 'en',
        link: 'https://example.invalid/manga/$mangaId',
        name: 'Sheet title',
        status: Status.ongoing,
        description: '',
        sourceId: 0,
      ),
    );
    for (var i = 1; i <= 4; i++) {
      testIsar.seed<Chapter>(
        i,
        Chapter(
          id: i,
          mangaId: mangaId,
          name: 'Chapter $i',
          url: 'https://example.invalid/$i',
          // Ascending with the id, so "newest first" is the reverse of it.
          dateUpload: '$i',
          isRead: i == 1,
        ),
      );
    }
  });

  Chapter chapter(int id) => testIsar.chapters.getSync(id)!;

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pumpSheet(WidgetTester tester, int currentId) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChapterSheet(chapter: chapter(currentId), title: 'Chapters'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every chapter by default', (tester) async {
    await pumpSheet(tester, 2);

    for (var i = 1; i <= 4; i++) {
      expect(find.text('Chapter $i'), findsOneWidget);
    }
  });

  testWidgets('the current chapter is marked and tapping it does nothing', (
    tester,
  ) async {
    await pumpSheet(tester, 3);

    // The current row gets the "reading" glyph, the unread ones a plain dot.
    expect(find.byIcon(Broken.play_circle), findsOneWidget);

    await tester.tap(find.text('Chapter 3'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtering to unread hides the chapters already read', (
    tester,
  ) async {
    await pumpSheet(tester, 2);
    expect(find.text('Chapter 1'), findsOneWidget);

    await tester.tap(find.byIcon(Broken.layer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter 1'), findsNothing);
    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('Chapter 4'), findsOneWidget);
  });

  testWidgets('filtering to downloaded keeps only saved chapters', (
    tester,
  ) async {
    // The download row id is the chapter id: that is what the sheet's
    // downloaded filter matches on.
    testIsar.seed<Download>(
      2,
      Download(
        id: 2,
        succeeded: 1,
        failed: 0,
        total: 1,
        isDownload: true,
        isStartDownload: true,
      ),
    );
    await pumpSheet(tester, 2);

    await tester.tap(find.byIcon(Broken.layer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('Chapter 3'), findsNothing);
  });

  testWidgets('sorting oldest first reverses the list', (tester) async {
    await pumpSheet(tester, 2);

    await tester.tap(find.byIcon(Broken.layer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.textContaining('Chapter '))
        .map((text) => text.data)
        .toList();
    expect(titles, ['Chapter 1', 'Chapter 2', 'Chapter 3', 'Chapter 4']);
  });

  testWidgets('grid mode renders the same chapters', (tester) async {
    await pumpSheet(tester, 2);

    await tester.tap(find.byIcon(Broken.layer));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Grid size 3'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 4'), findsOneWidget);
    // The grid-size shortcut only exists in grid mode.
    expect(find.byIcon(Broken.grid_3), findsWidgets);
  });

  testWidgets('a started chapter shows its reading progress', (tester) async {
    testIsar.seed<Chapter>(
      9,
      Chapter(
        id: 9,
        mangaId: mangaId,
        name: 'Chapter 9',
        url: 'https://example.invalid/9',
        dateUpload: '9',
        isRead: false,
        lastPageRead: '12',
      ),
    );
    await pumpSheet(tester, 2);

    expect(find.text('Page 12'), findsOneWidget);
  });
}
