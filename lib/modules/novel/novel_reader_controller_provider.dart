import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'novel_reader_controller_provider.g.dart';

@riverpod
class NovelReaderController extends _$NovelReaderController {
  @override
  void build({required Chapter chapter}) {}

  Manga getManga() {
    final manga = resolveChapterManga(chapter);
    if (manga == null) {
      throw StateError(
        'Chapter ${chapter.id} has no linked title (mangaId=${chapter.mangaId})',
      );
    }
    return manga;
  }

  Chapter geChapter() {
    return chapter;
  }

  final incognitoMode = (isar.settings.getSync(kSettingsId) ?? Settings()).incognitoMode!;

  Settings getIsarSetting() {
    return (isar.settings.getSync(kSettingsId) ?? Settings());
  }

  (bool, double) autoScrollValues() {
    final autoScrollPagesList = getIsarSetting().autoScrollPages ?? [];
    final autoScrollPages = autoScrollPagesList.where(
      (element) => element.mangaId == getManga().id,
    );
    if (autoScrollPages.isNotEmpty) {
      return (
        autoScrollPages.first.autoScroll ?? false,
        autoScrollPages.first.pageOffset ?? 10,
      );
    }
    return (false, 10);
  }

  void setAutoScroll(bool value, double offset) {
    List<AutoScrollPages>? autoScrollPagesList = [];
    for (var autoScrollPages in getIsarSetting().autoScrollPages ?? []) {
      if (autoScrollPages.mangaId != getManga().id) {
        autoScrollPagesList.add(autoScrollPages);
      }
    }
    autoScrollPagesList.add(
      AutoScrollPages()
        ..mangaId = getManga().id
        ..pageOffset = offset
        ..autoScroll = value,
    );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        getIsarSetting()
          ..autoScrollPages = autoScrollPagesList
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void setMangaHistoryUpdate({int readingTimeSeconds = 0}) {
    if (incognitoMode) return;
    isar.writeTxnSync(() {
      final manga = resolveChapterManga(chapter);
      if (manga == null) return;
      manga.lastRead = DateTime.now().millisecondsSinceEpoch;
      manga.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.mangas.putSync(manga);
    });
    History? history;

    final empty = isar.historys
        .where()
        .mangaIdEqualTo(getManga().id)
        .isEmptySync();

    if (empty) {
      history = History(
        mangaId: getManga().id,
        date: DateTime.now().millisecondsSinceEpoch.toString(),
        itemType: getManga().itemType,
        chapterId: chapter.id,
      )..chapter.value = chapter;
    } else {
      history =
          (isar.historys
                .where()
                .mangaIdEqualTo(getManga().id)
                .findFirstSync())!
            ..chapterId = chapter.id
            ..chapter.value = chapter
            ..date = DateTime.now().millisecondsSinceEpoch.toString();
    }
    isar.writeTxnSync(() {
      history!.updatedAt = DateTime.now().millisecondsSinceEpoch;
      if (readingTimeSeconds > 0) {
        history.readingTimeSeconds =
            (history.readingTimeSeconds ?? 0) + readingTimeSeconds;
      }
      isar.historys.putSync(history);
      history.chapter.saveSync();
    });
  }

  void setChapterOffset(double newOffset, double maxOffset, bool save) {
    if (incognitoMode) return;
    final isRead = (newOffset / (maxOffset != 0 ? maxOffset : 1)) >= 0.9;
    if (isRead || save) {
      final ch = chapter;
      isar.writeTxnSync(() {
        ch.isRead = isRead;
        ch.lastPageRead = (maxOffset != 0 ? newOffset / maxOffset : 0)
            .toString();
        ch.updatedAt = DateTime.now().millisecondsSinceEpoch;
        isar.chapters.putSync(ch);
      });
    }
  }

  void setChapterBookmarked() {
    if (incognitoMode) return;
    final isBookmarked = getChapterBookmarked();
    final chap = chapter;
    isar.writeTxnSync(() {
      chap.isBookmarked = !isBookmarked;
      chap.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.chapters.putSync(chap);
    });
  }

  bool getChapterBookmarked() {
    return isar.chapters.getSync(chapter.id!)!.isBookmarked!;
  }

  /// See [ReaderController._chapterIndexOf] — same reliable `mangaId` lookup,
  /// same guard against the `index!` assertion that crashed the reader when a
  /// title's chapter links were never persisted.
  (int, bool) _chapterIndexOf(int delta) {
    final manga = getManga();
    final filtered = manga.getFilteredChapterList();
    final inFiltered = filtered.indexWhere((c) => c.id == chapter.id);
    if (inFiltered >= 0) return (inFiltered + delta, true);
    final all = manga.getAllChapterList();
    final inAll = all.indexWhere((c) => c.id == chapter.id);
    if (inAll >= 0) return (inAll + delta, false);
    return (0, true);
  }

  (int, bool) getPrevChapterIndex() => _chapterIndexOf(1);

  (int, bool) getNextChapterIndex() => _chapterIndexOf(-1);

  (int, bool) getChapterIndex() => _chapterIndexOf(0);

  Chapter getPrevChapter() {
    final (index, inFiltered) = getPrevChapterIndex();
    final list = inFiltered
        ? getManga().getFilteredChapterList()
        : getManga().getAllChapterList();
    if (index < 0 || index >= list.length) return chapter;
    return list[index];
  }

  Chapter getNextChapter() {
    final (index, inFiltered) = getNextChapterIndex();
    final list = inFiltered
        ? getManga().getFilteredChapterList()
        : getManga().getAllChapterList();
    if (index < 0 || index >= list.length) return chapter;
    return list[index];
  }

  int getChaptersLength(bool isInFilterList) {
    return isInFilterList
        ? getManga().getFilteredChapterList().length
        : getManga().getAllChapterList().length;
  }

  String getMangaName() {
    return getManga().name!;
  }

  String getSourceName() {
    return getManga().source!;
  }

  String getChapterTitle() {
    return chapter.name!;
  }
}
