import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/fetch_interval.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'update_manga_detail_providers.g.dart';

@riverpod
Future<dynamic> updateMangaDetail(
  Ref ref, {
  required int? mangaId,
  required bool isInit,
  bool showToast = true,
}) async {
  try {
    final manga = isar.mangas.getSync(mangaId!);
    if (manga == null) return;

    // loadSync() so .isNotEmpty is reliable (IsarLinks are lazy by default).
    manga.chapters.loadSync();

    if (manga.isLocalArchive ?? false) {
      return;
    }
    final source = getSource(
      manga.lang!,
      manga.source!,
      manga.sourceId,
      installedOnly: true,
    );
    if (source == null) return;

    final getManga = await ref.read(
      getDetailProvider(url: manga.link!, source: source).future,
    );

    final genre =
        getManga.genre
            ?.map((e) => e.toString().trim())
            .toList()
            .toSet()
            .toList() ??
        [];

    final imgUrl = getManga.imageUrl.trimmedOrDefault(manga.imageUrl);
    final now = DateTime.now().millisecondsSinceEpoch;

    manga
      ..imageUrl = imgUrl == null
          ? null
          : imgUrl.startsWith('http')
          ? imgUrl
          : '${source.baseUrl ?? ''}/${imgUrl.getUrlWithoutDomain}'
      ..name = getManga.name.trimmedOrDefault(manga.name)
      ..genre = (genre.isEmpty ? null : genre) ?? manga.genre ?? []
      ..author = getManga.author.trimmedOrDefault(manga.author) ?? ""
      ..artist = getManga.artist.trimmedOrDefault(manga.artist) ?? ""
      ..status = getManga.status == Status.unknown
          ? manga.status
          : getManga.status ?? Status.unknown
      ..description =
          getManga.description.trimmedOrDefault(manga.description) ?? ""
      ..link = getManga.link.trimmedOrDefault(manga.link)
      ..source = manga.source
      ..lang = manga.lang
      ..itemType = source.itemType
      ..lastUpdate = now
      ..updatedAt = now;

    final chaps = getManga.chapters;

    await isar.writeTxn(() async {
      // Persist updated manga metadata.
      final savedMangaId = await isar.mangas.put(manga);

      if (chaps == null || chaps.isEmpty) return;

      // loadSync() was called before the transaction; the set is still valid
      // here because we haven't written to chapters yet.
      final existingChapters = manga.chapters.toList();
      final existingByUrl = <String, Chapter>{
        for (final c in existingChapters)
          if (c.url?.isNotEmpty == true) c.url!.trim(): c,
      };

      // Build a chapterNumber -> isRead map so that when a new scanlator covers
      // a chapter the user has already read, the new entry is pre-marked read.
      final recognition = ChapterRecognition();
      final readByNumber = <int, bool>{};
      for (final c in existingChapters) {
        if (c.name == null) continue;
        final num = recognition.parseChapterNumber(manga.name ?? '', c.name!);
        if (num > 0) {
          readByNumber[num] =
              (readByNumber[num] ?? false) || (c.isRead ?? false);
        }
      }

      final newChapters = <Chapter>[];

      // Iterate ALL chapters from the extension — URL-based deduplication.
      // This is the correct approach: count-based diff breaks when the extension
      // returns chapters in a different order or when the stored count doesn't
      // match (e.g. after a partial save). URL dedup handles all cases correctly.
      for (final chap in chaps) {
        final url = chap.url?.trim();
        if (url == null || url.isEmpty) continue;
        final existing = existingByUrl[url];

        if (existing == null) {
          // New chapter — determine if already read under a different scanlator.
          final chapNum = chap.name != null
              ? recognition.parseChapterNumber(manga.name!, chap.name!)
              : 0;
          final alreadyRead = chapNum > 0 && (readByNumber[chapNum] ?? false);

          final newChapter = Chapter(
            name: chap.name!,
            url: url,
            dateUpload: chap.dateUpload == null
                ? now.toString()
                : chap.dateUpload.toString(),
            scanlator: chap.scanlator ?? '',
            mangaId: savedMangaId,
            updatedAt: now,
            isFiller: chap.isFiller,
            thumbnailUrl: chap.thumbnailUrl,
            description: chap.description,
            downloadSize: chap.downloadSize,
            duration: chap.duration,
          )..manga.value = manga;

          if (alreadyRead) {
            newChapter.isRead = alreadyRead;
            newChapter.lastPageRead = "1";
          }

          newChapters.add(newChapter);
        } else {
          // Existing chapter — refresh metadata only.
          // Do NOT call existing.manga.save() — the IsarLink is already stored
          // from the original insertion. Calling save() on an unloaded link
          // would clear the relationship.
          existing
            ..name = chap.name
            ..scanlator = chap.scanlator
            ..updatedAt = now
            ..isFiller = chap.isFiller
            ..thumbnailUrl = chap.thumbnailUrl
            ..description = chap.description
            ..downloadSize = chap.downloadSize
            ..duration = chap.duration;
          await isar.chapters.put(existing);
        }
      }

      // Insert new chapters oldest-first (extensions typically return newest-first).
      if (newChapters.isNotEmpty) {
        final hasExisting = existingChapters.isNotEmpty;
        for (final chap in newChapters.reversed) {
          await isar.chapters.put(chap);
          await chap.manga.save();

          // Only create an Update entry for genuinely new (unread) chapters,
          // so that pre-read cross-scanlator chapters don't spam the updates feed.
          if (hasExisting && !(chap.isRead ?? false)) {
            final update = Update(
              mangaId: savedMangaId,
              chapterName: chap.name,
              date: now.toString(),
              updatedAt: now,
            )..chapter.value = chap;
            await isar.updates.put(update);
            await update.chapter.save();
          }
        }
      }

      // Calculate fetch interval:
      // median of gaps between recent distinct chapter dates, clamped [1, 28].
      final allChapters = newChapters.isEmpty
          ? existingChapters
          : [...existingChapters, ...newChapters];
      if (allChapters.isNotEmpty) {
        final interval = FetchInterval.calculateInterval(allChapters);
        manga
          ..id = savedMangaId
          ..smartUpdateDays = interval;
        await isar.mangas.put(manga);
      }
    });
  } catch (e, s) {
    if (showToast) {
      botToast('$e\n$s');
    } else {
      rethrow;
    }
  }
}

extension DefaultValueExtension on String? {
  String? trimmedOrDefault(String? defaultValue) {
    if (this?.trim().isNotEmpty ?? false) {
      return this!.trim();
    }
    return defaultValue;
  }
}
