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

// ─────────────────────────────────────────────────────────────────────────────
// updateMangaDetail — optimised for bulk library updates
//
// Key performance improvements vs the previous version:
//
//  1. Non-blocking DB read: `await isar.mangas.get()` instead of `getSync()`.
//     The synchronous variant blocks the main-thread UI thread; the async
//     variant lets the event loop continue between reads.
//
//  2. Non-blocking link load: `await manga.chapters.load()` instead of
//     `loadSync()`.
//
//  3. Batched Isar writes: new chapters are inserted with a single
//     `isar.chapters.putAll()` call; IsarLink saves are collected and fired
//     concurrently with `Future.wait`; Update objects are also `putAll`'d.
//     Previously every chapter triggered 2–3 individual round-trips to Isar.
//
//  4. Single manga persist: the manga object is written once at the end of the
//     transaction, combining metadata + smartUpdateDays. Previously it could
//     be written twice (once at the start, once after interval calculation).
//
//  5. Existing-chapter metadata updates collected into a list and persisted
//     via `putAll` instead of individual `put` calls inside the loop.
// ─────────────────────────────────────────────────────────────────────────────

@riverpod
Future<dynamic> updateMangaDetail(
  Ref ref, {
  required int? mangaId,
  required bool isInit,
  bool showToast = true,
}) async {
  try {
    // ── 1. Load manga (non-blocking) ────────────────────────────────────────
    final manga = await isar.mangas.get(mangaId!);
    if (manga == null) return;

    // Non-blocking IsarLink load — avoids freezing the UI thread.
    await manga.chapters.load();

    if (manga.isLocalArchive ?? false) return;

    final source = getSource(
      manga.lang!,
      manga.source!,
      manga.sourceId,
      installedOnly: true,
    );
    if (source == null) return;

    // ── 2. Fetch latest data from source (network / isolate) ────────────────
    final getManga = await ref.read(
      getDetailProvider(url: manga.link!, source: source).future,
    );

    final genre = getManga.genre
            ?.map((e) => e.toString().trim())
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
      ..author = getManga.author.trimmedOrDefault(manga.author) ?? ''
      ..artist = getManga.artist.trimmedOrDefault(manga.artist) ?? ''
      ..status = getManga.status == Status.unknown
          ? manga.status
          : getManga.status ?? Status.unknown
      ..description = getManga.description.trimmedOrDefault(manga.description) ?? ''
      ..link = getManga.link.trimmedOrDefault(manga.link)
      ..source = manga.source
      ..lang = manga.lang
      ..itemType = source.itemType
      ..lastUpdate = now
      ..updatedAt = now;

    final chaps = getManga.chapters;

    // ── 3. Persist — single transaction with batched writes ─────────────────
    await isar.writeTxn(() async {
      final existingChapters = manga.chapters.toList();

      // URL → existing chapter map for O(1) dedup lookup.
      final existingByUrl = <String, Chapter>{
        for (final c in existingChapters)
          if (c.url?.isNotEmpty == true) c.url!.trim(): c,
      };

      // Chapter-number → isRead map for cross-scanlator pre-read detection.
      final recognition = ChapterRecognition();
      final readByNumber = <int, bool>{};
      for (final c in existingChapters) {
        if (c.name == null) continue;
        final num =
            recognition.parseChapterNumber(manga.name ?? '', c.name!);
        if (num > 0) {
          readByNumber[num] =
              (readByNumber[num] ?? false) || (c.isRead ?? false);
        }
      }

      // Classify chapters into new vs existing-to-refresh.
      final newChapters = <Chapter>[];
      final updatedExisting = <Chapter>[];

      if (chaps != null) {
        for (final chap in chaps) {
          final url = chap.url?.trim();
          if (url == null || url.isEmpty) continue;
          final existing = existingByUrl[url];

          if (existing == null) {
            final chapNum = chap.name != null
                ? recognition.parseChapterNumber(manga.name!, chap.name!)
                : 0;
            final alreadyRead =
                chapNum > 0 && (readByNumber[chapNum] ?? false);

            final newChap = Chapter(
              name: chap.name!,
              url: url,
              dateUpload: chap.dateUpload == null
                  ? now.toString()
                  : chap.dateUpload.toString(),
              scanlator: chap.scanlator ?? '',
              updatedAt: now,
              isFiller: chap.isFiller,
              thumbnailUrl: chap.thumbnailUrl,
              description: chap.description,
              downloadSize: chap.downloadSize,
              duration: chap.duration,
            )..manga.value = manga;

            if (alreadyRead) {
              newChap.isRead = alreadyRead;
              newChap.lastPageRead = '1';
            }
            newChapters.add(newChap);
          } else {
            // Refresh metadata of existing chapter without touching the link.
            existing
              ..name = chap.name
              ..scanlator = chap.scanlator
              ..updatedAt = now
              ..isFiller = chap.isFiller
              ..thumbnailUrl = chap.thumbnailUrl
              ..description = chap.description
              ..downloadSize = chap.downloadSize
              ..duration = chap.duration;
            updatedExisting.add(existing);
          }
        }
      }

      // ── Calculate smart update interval before the writes ─────────────────
      final allChapters = newChapters.isEmpty
          ? existingChapters
          : [...existingChapters, ...newChapters];
      final interval =
          allChapters.isNotEmpty ? FetchInterval.calculateInterval(allChapters) : null;

      if (interval != null) manga.smartUpdateDays = interval;

      // ── Single manga write (metadata + interval combined) ─────────────────
      final savedMangaId = await isar.mangas.put(manga);

      // Fix up mangaId for new chapters (wasn't known before the put).
      for (final c in newChapters) {
        c.mangaId = savedMangaId;
      }

      // ── Batch: persist updated existing chapters ───────────────────────────
      if (updatedExisting.isNotEmpty) {
        await isar.chapters.putAll(updatedExisting);
      }

      // ── Batch: insert new chapters (oldest first) ──────────────────────────
      if (newChapters.isNotEmpty) {
        final orderedNew = newChapters.reversed.toList(); // oldest → newest
        await isar.chapters.putAll(orderedNew);

        // Save IsarLinks concurrently — one `save()` per chapter but all
        // dispatched together so Isar can pipeline them.
        await Future.wait(orderedNew.map((c) => c.manga.save()));

        // ── Batch: create Update entries for genuinely new, unread chapters ──
        final hasExisting = existingChapters.isNotEmpty;
        if (hasExisting) {
          final updates = <Update>[];
          for (final c in orderedNew) {
            if (c.isRead ?? false) continue;
            updates.add(
              Update(
                mangaId: savedMangaId,
                chapterName: c.name,
                date: now.toString(),
                updatedAt: now,
              )..chapter.value = c,
            );
          }
          if (updates.isNotEmpty) {
            await isar.updates.putAll(updates);
            await Future.wait(updates.map((u) => u.chapter.save()));
          }
        }
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
    if (this?.trim().isNotEmpty ?? false) return this!.trim();
    return defaultValue;
  }
}
