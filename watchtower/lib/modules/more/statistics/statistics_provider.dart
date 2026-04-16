import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'statistics_provider.g.dart';

class StatisticsData {
  final int totalItems;
  final int totalChapters;
  final int readChapters;
  final int completedItems;
  final int downloadedItems;
  final int totalReadingTimeSeconds;
  final int ongoingItems;
  final int onHoldItems;
  final int droppedItems;
  final int planToReadItems;
  final int notStartedItems;
  final Map<String, int> topGenres;
  final int totalDownloadedChapters;
  final int updatedThisWeek;

  const StatisticsData({
    required this.totalItems,
    required this.totalChapters,
    required this.readChapters,
    required this.completedItems,
    required this.downloadedItems,
    required this.totalReadingTimeSeconds,
    required this.ongoingItems,
    required this.onHoldItems,
    required this.droppedItems,
    required this.planToReadItems,
    required this.notStartedItems,
    required this.topGenres,
    required this.totalDownloadedChapters,
    required this.updatedThisWeek,
  });
}

@riverpod
Future<StatisticsData> getStatistics(
  Ref ref, {
  required ItemType itemType,
}) async {
  final items = await isar.mangas
      .filter()
      .idIsNotNull()
      .favoriteEqualTo(true)
      .itemTypeEqualTo(itemType)
      .findAll();

  final chapters = await isar.chapters
      .filter()
      .idIsNotNull()
      .manga((q) => q.favoriteEqualTo(true).itemTypeEqualTo(itemType))
      .findAll();

  final downloadedCount = await isar.downloads
      .filter()
      .idIsNotNull()
      .chapter((q) => q.manga((m) => m.itemTypeEqualTo(itemType)))
      .chapter((q) => q.manga((m) => m.favoriteEqualTo(true)))
      .isDownloadEqualTo(true)
      .count();

  final totalDownloadedChapters = await isar.downloads
      .filter()
      .idIsNotNull()
      .chapter((q) => q.manga((m) => m.itemTypeEqualTo(itemType)))
      .isDownloadEqualTo(true)
      .count();

  final totalItems = items.length;
  final totalChapters = chapters.length;
  final readChapters = chapters.where((c) => c.isRead ?? false).length;

  int completedItems = 0;
  int ongoingItems = 0;
  int onHoldItems = 0;
  int droppedItems = 0;
  int planToReadItems = 0;

  final genreCount = <String, int>{};
  final oneWeekAgo = DateTime.now()
      .subtract(const Duration(days: 7))
      .millisecondsSinceEpoch;
  int updatedThisWeek = 0;

  for (var item in items) {
    switch (item.status) {
      case Status.completed:
        completedItems++;
        break;
      case Status.ongoing:
        ongoingItems++;
        break;
      case Status.onHiatus:
        onHoldItems++;
        break;
      case Status.canceled:
        droppedItems++;
        break;
      default:
        break;
    }
    if ((item.lastUpdate ?? 0) > oneWeekAgo) {
      updatedThisWeek++;
    }
    for (final g in item.genre ?? <String>[]) {
      if (g.trim().isNotEmpty) {
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }
  }

  final sortedGenres = genreCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topGenres = Map<String, int>.fromEntries(sortedGenres.take(8));

  final notStartedItems = items.where((item) {
    final chapsRead = chapters.where((c) {
      if (!c.manga.isLoaded) c.manga.loadSync();
      return c.manga.value?.id == item.id && (c.isRead ?? false);
    });
    return chapsRead.isEmpty;
  }).length;

  final histories = await isar.historys
      .filter()
      .itemTypeEqualTo(itemType)
      .findAll();
  int totalReadingTimeSeconds = 0;
  for (final h in histories) {
    totalReadingTimeSeconds += h.readingTimeSeconds ?? 0;
  }

  return StatisticsData(
    totalItems: totalItems,
    totalChapters: totalChapters,
    readChapters: readChapters,
    completedItems: completedItems,
    downloadedItems: downloadedCount,
    totalReadingTimeSeconds: totalReadingTimeSeconds,
    ongoingItems: ongoingItems,
    onHoldItems: onHoldItems,
    droppedItems: droppedItems,
    planToReadItems: planToReadItems,
    notStartedItems: notStartedItems,
    topGenres: topGenres,
    totalDownloadedChapters: totalDownloadedChapters,
    updatedThisWeek: updatedThisWeek,
  );
}
