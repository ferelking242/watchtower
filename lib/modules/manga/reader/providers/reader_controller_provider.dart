import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/modules/manga/detail/providers/track_state_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/modules/more/settings/track/providers/track_providers.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/chapter_sort.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'reader_controller_provider.g.dart';

/// Upper bound on the per-chapter resume positions kept in the `Settings`
/// record. The list is deserialized by every `getIsarSetting()` read (once per
/// scroll tick), so an unbounded list made the reader slower the more the user
/// read. 500 entries is far more than any realistic resume set.
const int kMaxChapterPageIndexEntries = 500;

@riverpod
class CurrentIndex extends _$CurrentIndex {
  @override
  int build(Chapter chapter) {
    final incognitoMode = ref.watch(incognitoModeStateProvider);
    if (incognitoMode) return 0;
    return ref
        .read(readerControllerProvider(chapter: chapter).notifier)
        .getPageIndex();
  }

  void setCurrentIndex(int currentIndex) {
    state = currentIndex;
  }
}

BoxFit getBoxFit(ScaleType scaleType) {
  return switch (scaleType) {
    ScaleType.fitHeight => BoxFit.fitHeight,
    ScaleType.fitWidth => BoxFit.fitWidth,
    ScaleType.fitScreen => BoxFit.contain,
    ScaleType.originalSize => BoxFit.cover,
    ScaleType.smartFit => BoxFit.contain,
    _ => BoxFit.cover,
  };
}

@riverpod
class ReaderController extends _$ReaderController {
  @override
  bool build({required Chapter chapter}) {
    ref.keepAlive();
    return true;
  }

  void close() {}

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

  final incognitoMode = readSettingsSafely(isar: isar).incognitoMode!;
  ReaderMode getReaderMode() {
    final personalReaderModeList =
        getIsarSetting().personalReaderModeList ?? [];
    final personalReaderMode = personalReaderModeList.where(
      (element) => element.mangaId == getManga().id,
    );
    if (personalReaderMode.isNotEmpty) {
      return personalReaderMode.first.readerMode;
    }
    return readSettingsSafely(isar: isar).defaultReaderMode;
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
    _invalidateSettingsCache();
  }

  PageMode getPageMode() {
    final personalPageModeList = getIsarSetting().personalPageModeList ?? [];
    final personalPageMode = personalPageModeList.where(
      (element) => element.mangaId == getManga().id,
    );
    if (personalPageMode.isNotEmpty) {
      return personalPageMode.first.pageMode;
    }
    return PageMode.onePage;
  }

  void setReaderMode(ReaderMode newReaderMode) {
    List<PersonalReaderMode>? personalReaderModeLists = [];
    for (var personalReaderMode
        in getIsarSetting().personalReaderModeList ?? []) {
      if (personalReaderMode.mangaId != getManga().id) {
        personalReaderModeLists.add(personalReaderMode);
      }
    }
    personalReaderModeLists.add(
      PersonalReaderMode()
        ..mangaId = getManga().id
        ..readerMode = newReaderMode,
    );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        getIsarSetting()
          ..personalReaderModeList = personalReaderModeLists
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _invalidateSettingsCache();
  }

  void setPageMode(PageMode newPageMode) {
    List<PersonalPageMode>? personalPageModeLists = [];
    for (var personalPageMode in getIsarSetting().personalPageModeList ?? []) {
      if (personalPageMode.mangaId != getManga().id) {
        personalPageModeLists.add(personalPageMode);
      }
    }
    personalPageModeLists.add(
      PersonalPageMode()
        ..mangaId = getManga().id
        ..pageMode = newPageMode,
    );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        getIsarSetting()
          ..personalPageModeList = personalPageModeLists
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _invalidateSettingsCache();
  }

  void setShowPageNumber(bool value) {
    if (!incognitoMode) {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          getIsarSetting()
            ..showPagesNumber = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _invalidateSettingsCache();
    }
  }

  /// Cached snapshot of the `Settings` record for this reader session.
  ///
  /// `isar.settings.getSync` deserializes *every* property, including the
  /// embedded `chapterPageUrlsList` (one entry per chapter whose pages were
  /// ever cached). The scroll/progress listeners call [getIsarSetting] several
  /// times per frame — [setPageIndex] alone reads it three times — so the
  /// reader re-decoded that whole list on every scroll tick. That is what made
  /// the reader stutter and run out of memory on long chapters. The record is
  /// only written through this controller, so caching it and invalidating on
  /// every write keeps the reads free without serving stale values.
  Settings? _settingsCache;

  Settings getIsarSetting() {
    // Lecture auto-réparante : le lecteur lit le même record `Settings`
    // (getPageIndex → chapterPageUrlsList). Un record corrompu ne doit pas
    // tuer l'UI — readSettingsSafely répare et journalise.
    return _settingsCache ??= readSettingsSafely(isar: isar);
  }

  void _invalidateSettingsCache() => _settingsCache = null;

  bool getShowPageNumber() {
    if (!incognitoMode) {
      return getIsarSetting().showPagesNumber!;
    }
    return true;
  }

  void setMangaHistoryUpdate({int readingTimeSeconds = 0}) {
    if (incognitoMode) return;
    isar.writeTxnSync(() {
      Manga? manga = chapter.manga.value;
      manga!.lastRead = DateTime.now().millisecondsSinceEpoch;
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
    return isar.chapters.getSync(chapter.id!)?.isBookmarked ?? false;
  }

  /// Locates [chapter] in the reader's chapter list and offsets it by [delta].
  ///
  /// The filtered list is tried first (it respects the user's filters); when the
  /// chapter is hidden by a filter, the full list is used. Both lists come from
  /// the reliable `mangaId` index ([chaptersOfManga]), so a title whose chapter
  /// links were never persisted is still navigable — the previous backlink-based
  /// lookup returned an empty list for those and asserted on `index!`.
  ///
  /// Returns `(index, inFilteredList)`. When the chapter is absent from both
  /// lists it returns `(0, true)` so navigation degrades to "first chapter"
  /// instead of throwing.
  /// Chapters in reading-navigation order: newest chapter first, whatever
  /// display sort the user picked.
  ///
  /// "Next" is `-1` and "previous" `+1` on this order. Once
  /// [MangaExtensions.getFilteredChapterList] started honouring the sort
  /// setting it can come back ascending (date, name, scanlator), which would
  /// have silently walked the reader backwards.
  List<Chapter> _navigationChapters(Manga manga) => sortChapters(
    manga.getFilteredChapterList(),
    sortIndex: 1,
    reverse: true,
    mangaTitle: manga.name ?? '',
  );

  (int, bool) _chapterIndexOf(int delta) {
    final manga = getManga();
    final filtered = _navigationChapters(manga);
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
        ? _navigationChapters(getManga())
        : getManga().getAllChapterList();
    if (index < 0 || index >= list.length) return chapter;
    return list[index];
  }

  Chapter getNextChapter() {
    final (index, inFiltered) = getNextChapterIndex();
    // The index comes from the newest-first navigation list, so the lookup has
    // to use that same list: reading the display list (which follows the sort
    // setting) returned the wrong chapter as soon as the user sorted.
    final list = inFiltered
        ? _navigationChapters(getManga())
        : getManga().getAllChapterList();
    if (index < 0 || index >= list.length) return chapter;
    return list[index];
  }

  int getChaptersLength(bool isInFilterList) {
    return isInFilterList
        ? getManga().getFilteredChapterList().length
        : getManga().getAllChapterList().length;
  }

  int getPageIndex() {
    if (incognitoMode) return 0;
    final chapterPageIndexList = getIsarSetting().chapterPageIndexList ?? [];
    final index = chapterPageIndexList.where(
      (element) => element.chapterId == chapter.id,
    );
    return (chapter.isRead ?? false)
        ? 0
        : index.isNotEmpty
        ? (index.first.index ?? 0)
        : 0;
  }

  int getPageLength(List incognitoPageLength) {
    if (incognitoMode) return incognitoPageLength.length;
    final urls = (getIsarSetting().chapterPageUrlsList ?? [])
        .where((element) => element.chapterId == chapter.id)
        .firstOrNull
        ?.urls;
    if (urls == null || urls.isEmpty) return incognitoPageLength.length;
    return urls.length;
  }

  void setPageIndex(int newIndex, bool save) {
    if (chapter.isRead ?? false) return;
    if (incognitoMode) return;
    final isContinuousLike =
        getReaderMode() == ReaderMode.verticalContinuous ||
        getReaderMode() == ReaderMode.webtoon;
    final isRead = isContinuousLike
        ? (newIndex + 2) >= getPageLength([]) - 1
        : (newIndex + 2) >= getPageLength([]);
    if (isRead || save) {
      // Bound the list: it used to grow by one entry per chapter ever opened,
      // so `getIsarSetting()` decoded an ever-larger list on every scroll tick
      // and this whole-record write got slower the more the user read. Keep
      // the most recently touched entries only; a missing entry just means the
      // chapter opens at page 1.
      List<ChapterPageIndex>? chapterPageIndexs = [];
      for (var chapterPageIndex
          in getIsarSetting().chapterPageIndexList ?? []) {
        if (chapterPageIndex.chapterId != chapter.id) {
          chapterPageIndexs.add(chapterPageIndex);
        }
      }
      chapterPageIndexs.add(
        ChapterPageIndex()
          ..chapterId = chapter.id
          ..index = isRead ? 0 : newIndex,
      );
      if (chapterPageIndexs.length > kMaxChapterPageIndexEntries) {
        chapterPageIndexs = chapterPageIndexs.sublist(
          chapterPageIndexs.length - kMaxChapterPageIndexEntries,
        );
      }
      final chap = chapter;
      isar.writeTxnSync(() {
        isar.settings.putSync(
          getIsarSetting()
            ..chapterPageIndexList = chapterPageIndexs
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
        chap.isRead = isRead;
        chap.lastPageRead = isRead ? '1' : (newIndex + 1).toString();
        chap.updatedAt = DateTime.now().millisecondsSinceEpoch;
        isar.chapters.putSync(chap);
      });
      _invalidateSettingsCache();
      if (isRead) {
        chapter.updateTrackChapterRead(ref);
        if (ref.read(deleteDownloadAfterReadingStateProvider)) {
          chapter.deleteDownloadedFiles();
        }
      }
    }
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

extension ChapterExtensions on Chapter {
  void updateTrackChapterRead(dynamic ref) {
    if (!(ref is WidgetRef || ref is Ref)) return;
    final updateProgressAfterReading = ref.watch(
      updateProgressAfterReadingStateProvider,
    );
    if (!updateProgressAfterReading) return;
    final manga = resolveChapterManga(this);
    if (manga == null) return;
    final chapterNumber = ChapterRecognition().parseChapterNumber(
      manga.name!,
      name!,
    );

    final tracks = isar.tracks
        .where()
        .mangaIdEqualTo(manga.id!)
        .filter()
        .itemTypeEqualTo(manga.itemType)
        .findAllSync();

    if (tracks.isEmpty) return;
    for (var track in tracks) {
      final service = isar.trackPreferences
          .filter()
          .syncIdIsNotNull()
          .syncIdEqualTo(track.syncId)
          .findFirstSync();
      if (!(service == null || chapterNumber <= (track.lastChapterRead ?? 0))) {
        if (track.status != TrackStatus.completed) {
          track.lastChapterRead = chapterNumber;
          if (track.lastChapterRead == track.totalChapter &&
              (track.totalChapter ?? 0) > 0) {
            track.status = TrackStatus.completed;
            track.finishedReadingDate = DateTime.now().millisecondsSinceEpoch;
          } else {
            track.status = manga.itemType == ItemType.manga
                ? TrackStatus.reading
                : TrackStatus.watching;
            if (track.lastChapterRead == 1) {
              track.startedReadingDate = DateTime.now().millisecondsSinceEpoch;
            }
          }
        }
        ref
            .read(
              trackStateProvider(
                track: track,
                itemType: manga.itemType,
                widgetRef: ref,
              ).notifier,
            )
            .updateManga();
      }
    }
  }
}

extension MangaExtensions on Manga {
  /// Every chapter of this title, newest-first, from the reliable `mangaId`
  /// index rather than the fragile `chapters` backlink (see [chaptersOfManga]).
  ///
  /// The index returns insertion order, which is not reading order, so the list
  /// is sorted by chapter number before being reversed. Without that explicit
  /// sort, "next chapter" followed the extension's publication order and could
  /// jump from chapter 50 back to 49.
  List<Chapter> getAllChapterList() => sortChapters(
    chaptersOfManga(this),
    sortIndex: 1,
    reverse: true,
    mangaTitle: name ?? '',
  );

  List<Chapter> getFilteredChapterList() {
    // Ascending input, matching `_filterAndSortChapter` in the detail screen:
    // the sort cases below (`reversed` for "latest chapter") assume it. Feeding
    // the already-reversed `getAllChapterList()` double-reversed the default
    // sort and ignored the order for every other sort mode.
    final data = chaptersOfManga(this);
    // One synchronous read of the Settings record instead of four: this runs on
    // every rebuild of the chapter list, on the UI isolate.
    final settings = readSettingsSafely(isar: isar);
    final _unreadList = settings.chapterFilterUnreadList;
    final filterUnread =
        (_unreadList?.where((element) => element.mangaId == id)
                    .toList()
                    .firstOrNull ??
                ChapterFilterUnread(mangaId: id, type: 0))
            .type!;

    final _bookmarkedList = settings.chapterFilterBookmarkedList;
    final filterBookmarked =
        (_bookmarkedList?.where((element) => element.mangaId == id)
                    .toList()
                    .firstOrNull ??
                ChapterFilterBookmarked(mangaId: id, type: 0))
            .type!;
    final _downloadedList = settings.chapterFilterDownloadedList;
    final filterDownloaded =
        (_downloadedList?.where((element) => element.mangaId == id)
                    .toList()
                    .firstOrNull ??
                ChapterFilterDownloaded(mangaId: id, type: 0))
            .type!;

    final _sortList = settings.sortChapterList;
    final sortChapter =
        (_sortList?.where((element) => element.mangaId == id)
                    .toList()
                    .firstOrNull ??
                SortChapter(mangaId: id, index: 1, reverse: false))
            .index ??
        1;
    final filterScanlator = _getFilterScanlator(this) ?? [];
    // One Isar query for the whole list instead of one per chapter (see
    // manga_detail_view.dart — the same per-chapter lookup used to run a
    // synchronous Isar read for every chapter on the UI isolate).
    final Set<int>? downloadedIds = filterDownloaded == 0
        ? null
        : isar.downloads
              .where()
              .findAllSync()
              .where((download) => download.isDownload == true)
              .map((download) => download.id)
              .whereType<int>()
              .toSet();
    List<Chapter>? chapterList;
    chapterList = data
        .where(
          (element) => filterUnread == 1
              ? element.isRead == false
              : filterUnread == 2
              ? element.isRead == true
              : true,
        )
        .where(
          (element) => filterBookmarked == 1
              ? element.isBookmarked == true
              : filterBookmarked == 2
              ? element.isBookmarked == false
              : true,
        )
        .where((element) {
          if (downloadedIds == null) return true;
          final isDownloaded =
              element.id != null && downloadedIds.contains(element.id);
          return filterDownloaded == 1 ? isDownloaded : !isDownloaded;
        })
        .where((element) => !filterScanlator.contains(element.scanlator))
        .toList();
    // The direction follows the setting, exactly like the detail screen
    // (`reverse: sortChapter == 1`): "by number" lists newest-first, every
    // other sort lists ascending. Hardcoding `reverse: true` ignored the
    // setting and returned the opposite order for date, name and scanlator.
    // Navigation no longer relies on this order — see [_navigationChapters],
    // which always walks newest-first.
    return sortChapters(
      chapterList,
      sortIndex: sortChapter,
      reverse: sortChapter == 1,
      mangaTitle: name ?? '',
    );
  }
}

List<String>? _getFilterScanlator(Manga manga) {
  final scanlators = readSettingsSafely(isar: isar).filterScanlatorList ?? [];
  final filter = scanlators
      .where((element) => element.mangaId == manga.id)
      .toList();
  return filter.firstOrNull?.scanlators;
}
