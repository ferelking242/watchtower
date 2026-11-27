import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// Regression for the reader crash "Null check operator used on a null value"
/// that only hit *remote* (never-downloaded) chapters.
///
/// `manga.chapters` is an Isar `@Backlink` over `Chapter.manga`; it only returns
/// the chapters whose IsarLink was actually persisted. The detail screens save
/// chapters with `putAll` (no per-chapter `manga.save()`), so a title can have
/// chapters whose `mangaId` is set but whose backlink is empty — exactly the
/// state a freshly-added remote title is in, because downloading is what writes
/// the link. The reader used to look the chapter up in that empty backlink and
/// then assert on `index!`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIsar testIsar;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testIsar = MockIsar();
    app.isar = testIsar;
    testIsar.seed<Settings>(kSettingsId, Settings()..incognitoMode = false);
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Seeds a manga whose chapters were written with only `mangaId` (no
  /// persisted link), so the backlink stays empty. Chapters are newest-first.
  List<Chapter> seedRemoteManga(int mangaId, int chapterCount) {
    final manga = Manga(
      id: mangaId,
      source: 'Harimanga',
      author: '',
      artist: '',
      genre: const [],
      imageUrl: '',
      lang: 'en',
      link: 'https://example.invalid/manga/$mangaId',
      name: 'Remote title',
      status: Status.ongoing,
      description: '',
      sourceId: 0,
    );
    testIsar.seed<Manga>(manga.id!, manga);
    final chapters = <Chapter>[
      for (var i = 1; i <= chapterCount; i++)
        Chapter(
          id: mangaId * 1000 + i,
          mangaId: mangaId,
          name: 'Chapter $i',
          url: 'https://example.invalid/manga/$mangaId/$i',
        ),
    ];
    for (final c in chapters) {
      testIsar.seed<Chapter>(c.id!, c);
    }
    return chapters;
  }

  ReaderController controllerFor(Chapter chapter) =>
      container.read(readerControllerProvider(chapter: chapter).notifier);

  test('backlink is empty but mangaId still resolves every chapter', () {
    final chapters = seedRemoteManga(7001, 30);
    final manga = testIsar.mangas.getSync(7001)!;

    expect(manga.chapters.toList(), isEmpty);
    expect(chaptersOfManga(manga), hasLength(30));
    expect(chapters, hasLength(30));
  });

  test('chapter index resolves without throwing when the backlink is empty', () {
    final chapters = seedRemoteManga(7002, 30);
    final controller = controllerFor(chapters.first);

    // The old code asserted here ("Null check operator used on a null value").
    final (prevIndex, prevFiltered) = controller.getPrevChapterIndex();
    final (nextIndex, nextFiltered) = controller.getNextChapterIndex();
    final (index, indexFiltered) = controller.getChapterIndex();

    // Newest-first list: chapters.first is "Chapter 1", i.e. the last entry.
    expect(index, 29);
    expect(indexFiltered, isTrue);
    expect(nextIndex, 28);
    expect(nextFiltered, isTrue);
    // No newer chapter → the previous index is out of range and the getter
    // must degrade to the current chapter instead of an out-of-range read.
    expect(prevIndex, 30);
    expect(controller.getPrevChapter().id, chapters.first.id);
  });

  test('next chapter walks the whole series and stops at the end', () {
    final chapters = seedRemoteManga(7003, 60);
    final controller = controllerFor(chapters[40]);

    expect(controller.getChaptersLength(true), 60);
    expect(controller.getChaptersLength(false), 60);

    final next = controller.getNextChapter();
    expect(next.id, chapters[41].id);
    expect(next.name, 'Chapter 42');

    // Last chapter has no next: return the current chapter, never throw.
    final last = controllerFor(chapters.last);
    expect(last.getNextChapter().id, chapters.last.id);
  });

  test('navigation falls back to the full list when filters hide the chapter',
      () {
    final chapters = seedRemoteManga(7004, 10);
    // Hide everything except read chapters; our chapters are all unread, so the
    // filtered list is empty and the lookup must fall back to the full list.
    testIsar.seed<Settings>(
      kSettingsId,
      Settings()
        ..incognitoMode = false
        ..chapterFilterUnreadList = [
          ChapterFilterUnread(mangaId: 7004, type: 2),
        ],
    );

    final controller = controllerFor(chapters[3]);
    final (index, inFiltered) = controller.getChapterIndex();

    expect(inFiltered, isFalse);
    expect(index, 6);
    expect(controller.getNextChapter().id, chapters[4].id);
  });

  test('getFilteredChapterList honours the chapter sort setting', () {
    const mangaId = 7005;
    final manga = Manga(
      id: mangaId,
      source: 'Harimanga',
      author: '',
      artist: '',
      genre: const [],
      imageUrl: '',
      lang: 'en',
      link: 'https://example.invalid/manga/$mangaId',
      name: 'Sorted title',
      status: Status.ongoing,
      description: '',
      sourceId: 0,
    );
    testIsar.seed<Manga>(mangaId, manga);
    // ids ascend with dateUpload, so the raw (id-descending) list is 5..1.
    for (var i = 1; i <= 5; i++) {
      testIsar.seed<Chapter>(
        i,
        Chapter(
          id: i,
          mangaId: mangaId,
          name: 'Chapter $i',
          url: 'https://example.invalid/$i',
          dateUpload: '${i * 100}',
        ),
      );
    }
    // index 2 = sort by upload date.
    testIsar.seed<Settings>(
      kSettingsId,
      Settings()
        ..incognitoMode = false
        ..sortChapterList = [SortChapter(mangaId: mangaId, index: 2)],
    );

    final resolved = testIsar.mangas.getSync(mangaId)!;

    // The displayed list follows the setting: "by upload date" is ascending,
    // and navigation is what stays newest-first (see the test below).
    expect(resolved.getFilteredChapterList().map((c) => c.id).toList(), [
      1,
      2,
      3,
      4,
      5,
    ]);

    // Sort by chapter name instead: ascending A-Z is the same order here, which
    // proves the sort is applied to the displayed list. "Chapter 10" would sort
    // before "Chapter 2" as a string, hence the single-digit names.
    testIsar.seed<Settings>(
      kSettingsId,
      Settings()
        ..incognitoMode = false
        ..sortChapterList = [SortChapter(mangaId: mangaId, index: 3)],
    );
    final byName = testIsar.mangas.getSync(mangaId)!.getFilteredChapterList();
    expect(byName.map((c) => c.id).toList(), [1, 2, 3, 4, 5]);
  });

  test('the sort setting reorders the displayed chapters', () {
    const mangaId = 7006;
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
        name: 'Scrambled title',
        status: Status.ongoing,
        description: '',
        sourceId: 0,
      ),
    );
    // Upload dates deliberately disagree with the ids, so a list left in id
    // order cannot pass by accident.
    const uploads = {1: '300', 2: '100', 3: '500', 4: '200', 5: '400'};
    for (final entry in uploads.entries) {
      testIsar.seed<Chapter>(
        entry.key,
        Chapter(
          id: entry.key,
          mangaId: mangaId,
          name: 'Chapter ${entry.key}',
          url: 'https://example.invalid/${entry.key}',
          dateUpload: entry.value,
        ),
      );
    }
    testIsar.seed<Settings>(
      kSettingsId,
      Settings()
        ..incognitoMode = false
        // index 2 = by upload date, so the display is 2,4,1,5,3.
        ..sortChapterList = [SortChapter(mangaId: mangaId, index: 2)],
    );

    final ordered = testIsar.mangas.getSync(mangaId)!.getFilteredChapterList();
    expect(ordered.map((c) => c.id).toList(), [2, 4, 1, 5, 3]);
  });

  test('navigation stays newest-first whatever the sort setting', () {
    const mangaId = 7007;
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
        name: 'Sorted navigation',
        status: Status.ongoing,
        description: '',
        sourceId: 0,
      ),
    );
    // Same upload dates as above: display 2,4,1,5,3, navigation 3,5,1,4,2.
    const uploads = {1: '300', 2: '100', 3: '500', 4: '200', 5: '400'};
    for (final entry in uploads.entries) {
      testIsar.seed<Chapter>(
        entry.key,
        Chapter(
          id: entry.key,
          mangaId: mangaId,
          name: 'Chapter ${entry.key}',
          url: 'https://example.invalid/${entry.key}',
          dateUpload: entry.value,
        ),
      );
    }
    testIsar.seed<Settings>(
      kSettingsId,
      Settings()
        ..incognitoMode = false
        ..sortChapterList = [SortChapter(mangaId: mangaId, index: 2)],
    );

    // Navigation walks by chapter number, newest first: [5, 4, 3, 2, 1]. From
    // Chapter 4, "next" is 5 and "previous" is 3 — reading the sorted display
    // list ([2, 4, 1, 5, 3]) at that index returned 2 instead.
    final controller = controllerFor(testIsar.chapters.getSync(4)!);
    expect(controller.getNextChapter().id, 5);
    expect(controller.getPrevChapter().id, 3);
  });
}
