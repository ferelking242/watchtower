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
}
