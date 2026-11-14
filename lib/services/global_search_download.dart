import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Result of a global-search download request.
class GlobalSearchDownloadResult {
  final int queued;
  final int available;
  const GlobalSearchDownloadResult({
    required this.queued,
    required this.available,
  });
}

/// Queues [startChapter]..[endChapter] (1-based, inclusive; `0` = all) of
/// [item] from [source] into Watchtower's normal download pipeline.
///
/// The global search results are `MManga` previews: they carry no chapters and
/// no Isar identity. So the download flow first fetches the extension's detail
/// page (which lists the chapters), persists a [Manga] + its [Chapter] rows,
/// and only then enqueues them — exactly the same pipeline the detail screen
/// uses, so the queue/notification/engine behaviour is identical.
Future<GlobalSearchDownloadResult> downloadMangaFromGlobalSearch({
  required ProviderContainer container,
  required Source source,
  required MManga item,
  required int startChapter,
  required int endChapter,
  bool wifiOnly = true,
  bool addToLibrary = false,
}) async {
  final link = item.link;
  if (link == null || link.isEmpty) {
    throw StateError('Cette entrée n’a pas de lien exploitable.');
  }

  final detail = await container.read(
    getDetailProvider(url: link, source: source).future,
  );
  final chapters = detail.chapters ?? const [];
  if (chapters.isEmpty) {
    throw StateError('Aucun chapitre disponible pour ce titre.');
  }

  final mangaId = _persistManga(source: source, item: item, addToLibrary: addToLibrary);
  final manga = isar.mangas.getSync(mangaId)!;

  final total = chapters.length;
  final from = (startChapter <= 0) ? 1 : startChapter.clamp(1, total);
  final to = (endChapter <= 0) ? total : endChapter.clamp(from, total);
  final selected = chapters.sublist(from - 1, to);

  final now = DateTime.now().millisecondsSinceEpoch;
  final persisted = <Chapter>[];
  for (final c in selected) {
    final url = c.url;
    if (url == null || url.isEmpty) continue;
    final existing = isar.chapters
        .filter()
        .mangaIdEqualTo(mangaId)
        .urlEqualTo(url)
        .findFirstSync();
    if (existing != null) {
      persisted.add(existing);
      continue;
    }
    final chapter = Chapter(
      mangaId: mangaId,
      name: c.name ?? 'Chapitre',
      url: url,
      dateUpload: c.dateUpload ?? '',
      scanlator: c.scanlator ?? '',
      isFiller: c.isFiller ?? false,
      thumbnailUrl: c.thumbnailUrl,
      description: c.description,
      downloadSize: c.downloadSize,
      duration: c.duration,
      updatedAt: now,
    )..manga.value = manga;
    persisted.add(chapter);
  }

  if (persisted.isEmpty) {
    throw StateError('Aucun chapitre valide à télécharger.');
  }

  await isar.writeTxn(() async {
    await isar.chapters.putAll(persisted);
  });

  var queued = 0;
  for (final chapter in persisted) {
    try {
      chapter.manga.value = manga;
      await container.read(addDownloadToQueueProvider(chapter: chapter).future);
      final id = chapter.id;
      if (id != null) {
        container.read(downloadQueueStateProvider.notifier).setPaused(id, false);
      }
      queued++;
    } catch (e, st) {
      AppLogger.log(
        'Global search download failed for chapter "${chapter.name}"',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: e,
        stackTrace: st,
      );
    }
  }

  container.read(processDownloadsProvider(useWifi: wifiOnly));
  return GlobalSearchDownloadResult(queued: queued, available: total);
}

/// Finds (or creates) the stored [Manga] row for a global-search entry and
/// returns its id, mirroring the identity rule used by the detail route
/// (lang + name + source, with a nullable sourceId guard).
int _persistManga({
  required Source source,
  required MManga item,
  required bool addToLibrary,
}) {
  final name = (item.name ?? '').trim();
  final lang = source.lang ?? '';
  final sourceName = source.name ?? '';

  final existing = isar.mangas
      .filter()
      .langEqualTo(lang)
      .nameEqualTo(name)
      .sourceEqualTo(sourceName)
      .findAllSync();
  final match = existing
      .where((e) => e.sourceId == null || e.sourceId == source.id)
      .firstOrNull;
  if (match != null) {
    if (addToLibrary) {
      isar.writeTxnSync(() {
        isar.mangas.putSync(
          match
            ..favorite = true
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      });
    }
    return match.id!;
  }

  final manga = Manga(
    imageUrl: item.imageUrl,
    name: name,
    genre: item.genre?.map((e) => e.toString()).toList() ?? [],
    author: item.author ?? '',
    status: item.status ?? Status.unknown,
    description: item.description ?? '',
    link: item.link,
    source: sourceName,
    lang: lang,
    lastUpdate: 0,
    itemType: source.itemType,
    artist: item.artist ?? '',
    sourceId: source.id,
    favorite: addToLibrary,
    dateAdded: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
  isar.writeTxnSync(() => isar.mangas.putSync(manga));
  return manga.id!;
}
