import 'package:isar_community/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/utils/isar_batch.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'library_filter_provider.g.dart';

/// Pre-fetches all downloaded chapter IDs in a single Isar query.
/// Returns a [Set<int>] for O(1) lookup instead of per-chapter queries.
@riverpod
Set<int> downloadedChapterIds(Ref ref) {
  // isar_community can reject filters on nullable bool properties at
  // runtime. Read the collection without a filter and apply the predicate
  // in Dart.
  final downloads = isar.downloads
      .where()
      .findAllSync()
      .where((download) => download.isDownload == true)
      .map((download) => download.id);
  return downloads.whereType<int>().toSet();
}

/// Pre-fetches all manga IDs that have at least one tracking entry.
@riverpod
Set<int> trackedMangaIds(Ref ref) {
  final tracks = isar.tracks.where().findAllSync();
  return tracks.map((t) => t.mangaId).whereType<int>().toSet();
}

/// Filters and sorts a list of [Manga] based on library filter/sort settings.
@riverpod
List<Manga> filteredLibraryManga(
  Ref ref, {
  required List<Manga> data,
  required int downloadFilterType,
  required int unreadFilterType,
  required int startedFilterType,
  required int bookmarkedFilterType,
  required int completedFilterType,
  required int trackingFilterType,
  required int sortType,
  required bool downloadedOnly,
  required String searchQuery,
  required bool ignoreFiltersOnSearch,
}) {
  final downloadedIds = ref.watch(downloadedChapterIdsProvider);
  final trackedIds = ref.watch(trackedMangaIdsProvider);

  // Chapters are only needed by some filters/sorts; resolve them in one query
  // instead of letting each `manga.chapters` access hit Isar on its own.
  final needsChapters =
      downloadFilterType != 0 ||
      downloadedOnly ||
      unreadFilterType != 0 ||
      startedFilterType != 0 ||
      bookmarkedFilterType != 0 ||
      const {3, 4, 5, 7, 10}.contains(sortType);
  final chaptersByManga = needsChapters
      ? loadChaptersByMangaIds(data.map((e) => e.id).whereType<int>())
      : const <int, List<Chapter>>{};

  return _filterAndSortManga(
    data: data,
    downloadFilterType: downloadFilterType,
    unreadFilterType: unreadFilterType,
    startedFilterType: startedFilterType,
    bookmarkedFilterType: bookmarkedFilterType,
    completedFilterType: completedFilterType,
    trackingFilterType: trackingFilterType,
    sortType: sortType,
    downloadedOnly: downloadedOnly,
    searchQuery: searchQuery,
    ignoreFiltersOnSearch: ignoreFiltersOnSearch,
    downloadedIds: downloadedIds,
    trackedIds: trackedIds,
    chaptersByManga: chaptersByManga,
  );
}

bool _matchesSearchQuery(Manga manga, String query) {
  final keywords = query
      .toLowerCase()
      .split(',')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty);

  return keywords.any(
    (keyword) =>
        (manga.name?.toLowerCase().contains(keyword) ?? false) ||
        (manga.source?.toLowerCase().contains(keyword) ?? false) ||
        (manga.genre?.any((g) => g.toLowerCase().contains(keyword)) ?? false),
  );
}

List<Manga> _filterAndSortManga({
  required List<Manga> data,
  required int downloadFilterType,
  required int unreadFilterType,
  required int startedFilterType,
  required int bookmarkedFilterType,
  required int completedFilterType,
  required int trackingFilterType,
  required int sortType,
  required bool downloadedOnly,
  required String searchQuery,
  required bool ignoreFiltersOnSearch,
  required Set<int> downloadedIds,
  required Set<int> trackedIds,
  required Map<int, List<Chapter>> chaptersByManga,
}) {
  List<Manga> mangas;

  // The single batched query; never touch `manga.chapters` here — that backlink
  // triggers one synchronous Isar read per entry on the UI thread.
  List<Chapter> chaptersOf(Manga manga) =>
      manga.id == null ? const [] : (chaptersByManga[manga.id] ?? const []);

  // Skip all filters, just do search
  if (searchQuery.isNotEmpty && ignoreFiltersOnSearch) {
    mangas = data
        .where((element) => _matchesSearchQuery(element, searchQuery))
        .toList();
  } else {
    mangas = data.where((element) {
      final chapters = chaptersOf(element);
      // Filter by download — uses Set lookup instead of per-chapter Isar query
      if (downloadFilterType == 1 || downloadedOnly) {
        final hasDownloaded = chapters.any(
          (chap) => chap.id != null && downloadedIds.contains(chap.id),
        );
        if (!hasDownloaded) return false;
      } else if (downloadFilterType == 2) {
        final allNotDownloaded = chapters.every(
          (chap) => chap.id == null || !downloadedIds.contains(chap.id),
        );
        if (!allNotDownloaded) return false;
      }

      // Filter by unread or started
      if (unreadFilterType == 1 || startedFilterType == 1) {
        final hasUnread = chapters.any((chap) => !chap.isRead!);
        if (!hasUnread) return false;
      } else if (unreadFilterType == 2 || startedFilterType == 2) {
        final allRead = chapters.every((chap) => chap.isRead!);
        if (!allRead) return false;
      }

      // Filter by bookmarked
      if (bookmarkedFilterType == 1) {
        final hasBookmarked = chapters.any((chap) => chap.isBookmarked!);
        if (!hasBookmarked) return false;
      } else if (bookmarkedFilterType == 2) {
        final allNotBookmarked = chapters.every((chap) => !chap.isBookmarked!);
        if (!allNotBookmarked) return false;
      }

      // Filter by completed status
      if (completedFilterType == 1) {
        if (element.status != Status.completed) return false;
      } else if (completedFilterType == 2) {
        if (element.status == Status.completed) return false;
      }

      // Filter by tracking
      if (trackingFilterType == 1) {
        if (element.id == null || !trackedIds.contains(element.id)) {
          return false;
        }
      } else if (trackingFilterType == 2) {
        if (element.id != null && trackedIds.contains(element.id)) {
          return false;
        }
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        if (!_matchesSearchQuery(element, searchQuery)) return false;
      }

      return true;
    }).toList();
  }

  // "Aléatoire" — shuffle instead of comparing.
  if (sortType == 9) {
    mangas.shuffle();
    return mangas;
  }

  // "Nombre de non-lus": precompute the unread count once per entry. Doing it
  // inside the comparator re-scanned every chapter list O(n log n) times.
  Map<int?, int>? unreadCounts;
  if (sortType == 3) {
    unreadCounts = {
      for (final manga in mangas)
        manga.id: chaptersOf(manga).where((e) => e.isRead != true).length,
    };
  }

  // Sort
  mangas.sort((a, b) {
    switch (sortType) {
      case 0:
        return a.name!.compareTo(b.name!);
      case 1:
        return a.lastRead!.compareTo(b.lastRead!);
      case 2:
        return a.lastUpdate?.compareTo(b.lastUpdate ?? 0) ?? 0;
      case 3:
        return (unreadCounts![a.id] ?? 0).compareTo(unreadCounts[b.id] ?? 0);
      case 4:
        return chaptersOf(a).length.compareTo(chaptersOf(b).length);
      case 5:
        return (chaptersOf(a).lastOrNull?.dateUpload ?? "").compareTo(
          chaptersOf(b).lastOrNull?.dateUpload ?? "",
        );
      case 6:
        return a.dateAdded?.compareTo(b.dateAdded ?? 0) ?? 0;
      // "Date de sortie" — release date of the series, i.e. the earliest
      // chapter upload date. Chapters are ordered newest-first, so the last
      // entry is the oldest.
      case 7:
        return (chaptersOf(a).lastOrNull?.dateUpload ?? "").compareTo(
          chaptersOf(b).lastOrNull?.dateUpload ?? "",
        );
      // "Nom du dossier" — the on-disk folder name for local archives, falling
      // back to the title when there is no path.
      case 8:
        return _folderName(a).compareTo(_folderName(b));
      // "R18" — adult titles (flagged through their genre) sink to the end.
      case 11:
        return (_isNsfw(a) ? 1 : 0).compareTo(_isNsfw(b) ? 1 : 0);
      // "Date de récupération du chapitre" — when the latest chapter was
      // fetched into the library.
      case 10:
        return (chaptersOf(a).lastOrNull?.updatedAt ?? 0).compareTo(
          chaptersOf(b).lastOrNull?.updatedAt ?? 0,
        );
      default:
        return 0;
    }
  });

  return mangas;
}

/// Folder name used by the "Nom du dossier" sort: the basename of the stored
/// path for local archives, otherwise the entry title.
String _folderName(Manga manga) {
  final link = manga.link;
  if (link != null && link.trim().isNotEmpty) {
    final normalized = link.replaceAll('\\', '/');
    final base = normalized.split('/').where((s) => s.isNotEmpty).lastOrNull;
    if (base != null && base.isNotEmpty) return base.toLowerCase();
  }
  return (manga.name ?? '').toLowerCase();
}

/// Whether an entry is adult content, as declared by its genre list.
bool _isNsfw(Manga manga) {
  const markers = {'r18', 'r-18', '18+', 'nsfw', 'adult', 'hentai', 'ecchi'};
  final genres = manga.genre;
  if (genres == null) return false;
  for (final g in genres) {
    if (markers.contains(g.trim().toLowerCase())) return true;
  }
  return false;
}

/// Per-manga chapter stats used by the library grid/list badges.
class MangaChapterStats {
  const MangaChapterStats({
    required this.total,
    required this.unread,
    required this.downloaded,
  });

  final int total;
  final int unread;
  final int downloaded;
}

/// Aggregates chapter counts once per Isar write instead of per rebuild.
///
/// The grid and list used to call `loadChaptersByMangaIds` directly inside
/// `build`: that is one synchronous Isar read of **every chapter of the whole
/// library** on each rebuild — and the grid rebuilds on unrelated state changes
/// (long-press selection, the overlay toggle). Wrapping the same batched read
/// in a provider memoises it until an actual chapter or download write, and the
/// per-row badge becomes a map lookup.
///
/// Declared manually (not `@riverpod`) because the checked-in generated files
/// must stay in sync with a `build_runner` that is currently unusable in this
/// environment (riverpod_generator 4.0.0 vs analyzer 9.0.0).
final libraryChapterStatsProvider =
    StreamProvider<Map<int, MangaChapterStats>>((ref) {
  return isar.chapters.where().watch(fireImmediately: true).asyncMap((
    rows,
  ) async {
    // A fresh subscription each pass: an Isar watch stream is
    // single-subscription, so reusing one instance across events would throw.
    final downloadedIds =
        (await isar.downloads.where().watch(fireImmediately: true).first)
            .where((download) => download.isDownload == true)
            .map((download) => download.id)
            .whereType<int>()
            .toSet();
    final counts = <int, List<int>>{};
    for (final chapter in rows) {
      final mangaId = chapter.mangaId;
      if (mangaId == null) continue;
      final slot = counts[mangaId] ??= [0, 0, 0];
      slot[0]++;
      if (chapter.isRead != true) slot[1]++;
      if (chapter.id != null && downloadedIds.contains(chapter.id)) slot[2]++;
    }
    return {
      for (final entry in counts.entries)
        entry.key: MangaChapterStats(
          total: entry.value[0],
          unread: entry.value[1],
          downloaded: entry.value[2],
        ),
    };
  });
});
