import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/mihon_backup.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/blend_level_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'restore.g.dart';

@riverpod
void doRestore(Ref ref, {required String path, required BuildContext context}) {
  // `.tachibk` / `.proto.gz` backups (Mihon, Tachiyomi, Neko…) are a gzipped
  // protobuf stream, not a zip archive: `ZipDecoder` must not touch them.
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.tachibk') || lowerPath.endsWith('.proto.gz')) {
    try {
      ref.read(restoreMihonBackupProvider(path));
      showBotToast('Backup restored!');
    } catch (e, s) {
      AppLogger.log(
        'Mihon backup restore failed',
        logLevel: LogLevel.error,
        tag: 'Backup',
        error: e,
        stackTrace: s,
      );
      botToast('$e\n$s');
    }
    return;
  }

  final inputStream = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(inputStream);
    final backupType = checkBackupType(path, archive);
    switch (backupType) {
      case BackupType.watchtower:
        final backup =
            jsonDecode(utf8.decode(archive.files.first.content))
                as Map<String, dynamic>;
        ref.read(restoreBackupProvider(backup));
        break;
      case BackupType.kotatsu:
        ref.read(restoreKotatsuBackupProvider(archive));
        break;
      default:
    }
    if (backupType != BackupType.unknown) {
      showBotToast("Backup restored!");
    } else {
      showBotToast("Backup Type not supported!");
    }
  } catch (e, s) {
    botToast('$e\n$s');
  } finally {
    inputStream.close();
  }
}

void showBotToast(String text) => botToast(text, second: 5);

enum BackupType { unknown, watchtower, kotatsu, mihon }

BackupType checkBackupType(String path, Archive archive) {
  if (path.toLowerCase().contains("watchtower") &&
      (archive.files.firstOrNull?.name ?? "").endsWith(".backup.db")) {
    return BackupType.watchtower;
  } else if (path.toLowerCase().contains("kotatsu") &&
      archive.files.where((f) {
            switch (f.name) {
              case "categories":
              case "favourites":
                return true;
              default:
                return false;
            }
          }).length ==
          2) {
    return BackupType.kotatsu;
  } else if (path.toLowerCase().endsWith(".tachibk") ||
      path.toLowerCase().endsWith(".proto.gz")) {
    // Every Mihon-family app (Mihon, Tachiyomi, Aniyomi, Neko, …) writes the
    // same `BackupWriter` stream, so the file name does not change the format.
    return BackupType.mihon;
  }
  return BackupType.unknown;
}

@riverpod
void restoreBackup(Ref ref, Map<String, dynamic> backup, {bool full = true}) {
  final version = backup['version'];
  if (["1", "2"].any((e) => e == version)) {
    try {
      final manga = (backup["manga"] as List?)
          ?.map((e) => Manga.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final chapters = (backup["chapters"] as List?)
          ?.map((e) => Chapter.fromJson(e))
          .toList();
      final categories = (backup["categories"] as List?)
          ?.map(
            (e) =>
                Category.fromJson(e)
                  ..forItemType = _convertToItemTypeCategory(e),
          )
          .toList();
      final track = (backup["tracks"] as List?)
          ?.map((e) => Track.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final trackPreferences = (backup["trackPreferences"] as List?)
          ?.map((e) => TrackPreference.fromJson(e))
          .toList();
      final history = (backup["history"] as List?)
          ?.map((e) => History.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final downloads = (backup["downloads"] as List?)
          ?.map((e) => Download.fromJson(e))
          .toList();
      final settings = (backup["settings"] as List?)
          ?.map((e) => Settings.fromJson(e))
          .toList();
      final extensions = (backup["extensions"] as List?)
          ?.map((e) => Source.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final sourcesPrefs = (backup["extensions_preferences"] as List?)
          ?.map((e) => SourcePreference.fromJson(e))
          .toList();
      final updates = (backup["updates"] as List?)
          ?.map((e) => Update.fromJson(e))
          .toList();
      final customButtons = (backup["customButtons"] as List?)
          ?.map((e) => CustomButton.fromJson(e))
          .toList();

      isar.writeTxnSync(() {
        isar.mangas.clearSync();
        if (manga != null) {
          isar.mangas.putAllSync(manga);
          if (chapters != null) {
            isar.chapters.clearSync();
            for (var chapter in chapters) {
              final manga = isar.mangas.getSync(chapter.mangaId!);
              if (manga != null) {
                isar.chapters.putSync(chapter..manga.value = manga);
                chapter.manga.saveSync();
              }
            }

            if (full) {
              isar.downloads.clearSync();
              if (downloads != null) {
                for (var download in downloads) {
                  final chapter = isar.chapters.getSync(download.id!);
                  if (chapter != null) {
                    isar.downloads.putSync(download..chapter.value = chapter);
                    download.chapter.saveSync();
                  }
                }
              }
            }

            isar.historys.clearSync();
            if (history != null) {
              for (var element in history) {
                final chapter = isar.chapters.getSync(element.chapterId!);
                if (chapter != null) {
                  isar.historys.putSync(element..chapter.value = chapter);
                  element.chapter.saveSync();
                }
              }
            }

            isar.updates.clearSync();
            if (updates != null) {
              final tempChapters = isar.chapters
                  .where()
                  .findAllSync()
                  .toList();
              for (var update in updates) {
                final matchingChapter = tempChapters
                    .where(
                      (chapter) =>
                          chapter.mangaId == update.mangaId &&
                          chapter.name == update.chapterName,
                    )
                    .firstOrNull;
                if (matchingChapter != null) {
                  isar.updates.putSync(update..chapter.value = matchingChapter);
                  update.chapter.saveSync();
                }
              }
            }
          }

          isar.categorys.clearSync();
          if (categories != null) {
            isar.categorys.putAllSync(categories);
          }
        }

        isar.tracks.clearSync();
        if (track != null) {
          isar.tracks.putAllSync(track);
        }

        if (full) {
          if (trackPreferences != null) {
            isar.trackPreferences.clearSync();
            isar.trackPreferences.putAllSync(trackPreferences);
          }
          isar.sources.clearSync();
          if (extensions != null) {
            isar.sources.putAllSync(extensions);
          }
          isar.sourcePreferences.clearSync();
          if (sourcesPrefs != null) {
            isar.sourcePreferences.putAllSync(sourcesPrefs);
          }
          isar.settings.clearSync();
          if (settings != null) {
            isar.settings.putAllSync(settings);
          }
          isar.customButtons.clearSync();
          if (customButtons != null) {
            isar.customButtons.putAllSync(customButtons);
          }
          _invalidateCommonState(ref);
        }
      });
    } catch (e) {
      rethrow;
    }
  } else {
    throw "Failed to restore the backup";
  }
}

ItemType _convertToItemType(Map<String, dynamic> backup) {
  final isManga = backup['isManga'];
  return isManga == null
      ? ItemType.values[backup['itemType'] ?? 0]
      : isManga
      ? ItemType.manga
      : ItemType.anime;
}

ItemType _convertToItemTypeCategory(Map<String, dynamic> backup) {
  final forManga = backup['forManga'];
  return forManga == null
      ? ItemType.values[backup['forItemType'] ?? 0]
      : forManga
      ? ItemType.manga
      : ItemType.anime;
}

@riverpod
void restoreKotatsuBackup(Ref ref, Archive archive) {
  try {
    for (var f in archive.files) {
      List<Category> cats = [];
      switch (f.name) {
        case "categories":
          final categories = jsonDecode(utf8.decode(f.content)) as List? ?? [];
          isar.writeTxnSync(() {
            isar.categorys.clearSync();
            for (var category in categories) {
              final cat = Category(
                id: category["id"],
                name: category["title"],
                forItemType: ItemType.manga,
                hide: !(category["show_in_lib"] ?? true),
              );
              isar.categorys.putSync(cat);
              cats.add(cat);
            }
          });
        case "favourites":
          final favourites = jsonDecode(utf8.decode(f.content)) as List? ?? [];
          isar.writeTxnSync(() {
            isar.mangas.clearSync();
            for (var favourite in favourites) {
              final tempManga = favourite["manga"];
              final manga = Manga(
                source: tempManga["source"],
                author: tempManga["author"],
                artist: null,
                genre:
                    (tempManga["tags"] as List?)
                        ?.map((t) => t["title"] as String)
                        .toList() ??
                    [],
                imageUrl: tempManga["large_cover_url"],
                lang: 'en',
                link: tempManga["url"],
                name: tempManga["title"],
                status: Status.values.firstWhere(
                  (s) =>
                      s.name.toLowerCase() ==
                      (tempManga["state"] as String?)?.toLowerCase(),
                  orElse: () => Status.unknown,
                ),
                description: null,
                categories: [favourite["category_id"]],
                itemType: ItemType.manga,
                favorite: true,
                sourceId: null,
              );
              isar.mangas.putSync(manga);
            }
          });
        default:
          continue;
      }
    }
    isar.writeTxnSync(() {
      isar.chapters.clearSync();
      isar.downloads.clearSync();
      isar.historys.clearSync();
      isar.updates.clearSync();
      isar.tracks.clearSync();
      isar.trackPreferences.clearSync();
      _invalidateCommonState(ref);
    });
  } catch (e) {
    rethrow;
  }
}

@riverpod
void restoreMihonBackup(Ref ref, String path) {
  final inputStream = InputFileStream(path);
  Uint8List raw;
  try {
    raw = inputStream.toUint8List();
  } finally {
    inputStream.close();
  }

  // Mihon always gzips its backups, but an ungzipped protobuf stream is also
  // valid: sniff the gzip magic (0x1f 0x8b) instead of assuming.
  final bytes = (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b)
      ? Uint8List.fromList(GZipDecoder().decodeBytes(raw))
      : raw;

  final backup = MihonBackup.parse(bytes);
  final now = DateTime.now().millisecondsSinceEpoch;

  final settings = isar.settings.getSync(kSettingsId) ?? Settings();
  // A restore replaces the whole library, so per-manga overrides start empty.
  // Global Mihon defaults are recorded against mangaId 0 and the per-manga
  // entries are appended below.
  settings
    ..sortChapterList = []
    ..chapterFilterUnreadList = []
    ..chapterFilterDownloadedList = []
    ..chapterFilterBookmarkedList = []
    ..filterScanlatorList = []
    ..personalReaderModeList = [];

  for (final preference in backup.preferences) {
    _applyMihonPreference(settings, preference);
  }

  // Resolve extension preferences before opening the write transaction: the
  // lookup may touch the sources collection and the extension registry.
  final sourcePrefs = <SourcePreference>[];
  for (final entry in backup.sourcePreferences) {
    final source = _resolveMihonSourceByPreferenceKey(entry.sourceKey);
    if (source == null) continue;
    for (final preference in entry.prefs) {
      final restored = _mihonSourcePreference(source.id, preference);
      if (restored != null) sourcePrefs.add(restored);
    }
  }

  // Mihon references categories by *order* in each manga, while the category
  // record carries a separate id. Join on order, not on id.
  final orderToCategoryId = <int, int>{};
  final toBuild = <_MihonMangaBuild>[];

  isar.writeTxnSync(() {
    isar.categorys.clearSync();
    isar.mangas.clearSync();
    isar.chapters.clearSync();
    isar.historys.clearSync();
    isar.tracks.clearSync();
    isar.downloads.clearSync();
    isar.updates.clearSync();
    isar.sourcePreferences.clearSync();

    for (final category in backup.categories) {
      final local = Category(
        name: category.name,
        forItemType: ItemType.manga,
        pos: category.order,
        updatedAt: now,
      );
      isar.categorys.putSync(local);
      orderToCategoryId[category.order] = local.id!;
    }

    for (final manga in backup.mangas) {
      final sourceName = backup.sources
              .where((s) => s.sourceId == manga.source)
              .firstOrNull
              ?.name ??
          '';
      final localSource = _resolveMihonSource(sourceName);
      final restored = Manga(
        source: localSource?.name ??
            (sourceName.isNotEmpty ? sourceName : 'Unknown'),
        sourceId: localSource?.id,
        author: manga.author,
        artist: manga.artist,
        genre: manga.genre,
        imageUrl: manga.thumbnailUrl,
        lang: localSource?.lang ?? 'en',
        link: manga.url,
        name: manga.title,
        status: _convertMihonStatus(manga.status),
        description: manga.description,
        categories: manga.categories
            .map((order) => orderToCategoryId[order])
            .whereType<int>()
            .toList(),
        itemType: ItemType.manga,
        favorite: manga.favorite,
        dateAdded: manga.dateAdded > 0 ? manga.dateAdded : now,
        updatedAt: now,
      );
      isar.mangas.putSync(restored);
      toBuild.add(_MihonMangaBuild(restored, manga));
    }

    for (final entry in toBuild) {
      _restoreMihonManga(entry, settings, now);
    }

    for (final preference in sourcePrefs) {
      isar.sourcePreferences.putSync(preference);
    }

    settings.updatedAt = now;
    isar.settings.putSync(settings);
  });

  _invalidateCommonState(ref);
}

class _MihonMangaBuild {
  _MihonMangaBuild(this.manga, this.backup);

  final Manga manga;
  final MihonManga backup;
}

void _restoreMihonManga(
  _MihonMangaBuild entry,
  Settings settings,
  int now,
) {
  final manga = entry.manga;
  final backup = entry.backup;

  // Mihon keeps history per chapter URL; map each URL back to its chapter so a
  // resume point is only written for a chapter that still exists.
  final urlToChapterId = <String, int>{};
  final chapters = <Chapter>[];
  for (final source in backup.chapters) {
    final chapter = Chapter(
      mangaId: manga.id!,
      name: source.name,
      url: source.url,
      // Watchtower stores dates as strings; the reader sorts them as ints.
      dateUpload: source.dateUpload > 0 ? '${source.dateUpload}' : '',
      isBookmarked: source.bookmark,
      isRead: source.read,
      lastPageRead: source.lastPageRead > 0 ? '${source.lastPageRead}' : '1',
      scanlator: source.scanlator,
      updatedAt: now,
    );
    isar.chapters.putSync(chapter);
    chapter.manga.value = manga;
    chapter.manga.saveSync();
    urlToChapterId[source.url] = chapter.id!;
    chapters.add(chapter);
  }

  // Per-manga chapter display flags travel in `chapterFlags` (bit layout from
  // Mihon's `Manga`): the same toggles Watchtower stores as parallel lists.
  final flags = backup.chapterFlags;
  settings.chapterFilterUnreadList!.add(
    ChapterFilterUnread(mangaId: manga.id, type: _mihonUnreadType(flags)),
  );
  settings.chapterFilterDownloadedList!.add(
    ChapterFilterDownloaded(
      mangaId: manga.id,
      type: _mihonDownloadedType(flags),
    ),
  );
  settings.chapterFilterBookmarkedList!.add(
    ChapterFilterBookmarked(
      mangaId: manga.id,
      type: _mihonBookmarkedType(flags),
    ),
  );
  settings.sortChapterList!.add(
    SortChapter(
      mangaId: manga.id,
      index: _mihonChapterSortIndex(flags),
      reverse: flags & 0x1 == 0x1,
    ),
  );

  // Per-manga reading mode lives in `viewer_flags` (low 3 bits).
  final viewerFlags = backup.viewerFlags ?? backup.viewer;
  settings.personalReaderModeList!.add(
    PersonalReaderMode(
      mangaId: manga.id,
      readerMode: _convertMihonReadingMode(viewerFlags),
    ),
  );

  if (backup.excludedScanlators.isNotEmpty) {
    settings.filterScanlatorList!.add(
      FilterScanlator(
        mangaId: manga.id,
        scanlators: List<String>.from(backup.excludedScanlators),
      ),
    );
  }

  if (chapters.isEmpty) return;

  final history = <History>[];
  for (final read in backup.history) {
    final chapterId = urlToChapterId[read.url];
    if (chapterId == null) continue;
    final chapter = chapters.firstWhere((c) => c.id == chapterId);
    final record = History(
      itemType: ItemType.manga,
      mangaId: manga.id,
      chapterId: chapterId,
      date: read.lastRead > 0 ? '${read.lastRead}' : '$now',
      readingTimeSeconds: read.readDuration > 0 ? read.readDuration : null,
      updatedAt: now,
    )..chapter.value = chapter;
    isar.historys.putSync(record);
    record.chapter.saveSync();
    history.add(record);
  }

  // Older Tachiyomi backups omitted the history block; fall back to the most
  // recent read chapter so "continue reading" still works.
  if (history.isEmpty) {
    final read = chapters.where((c) => c.isRead == true).toList()
      ..sort(
        (a, b) => (int.tryParse(a.dateUpload ?? '0') ?? 0)
            .compareTo(int.tryParse(b.dateUpload ?? '0') ?? 0),
      );
    final latest = read.lastOrNull;
    if (latest != null) {
      final record = History(
        itemType: ItemType.manga,
        mangaId: manga.id,
        chapterId: latest.id,
        date: (latest.dateUpload ?? '').isNotEmpty
            ? latest.dateUpload
            : '$now',
        updatedAt: now,
      )..chapter.value = latest;
      isar.historys.putSync(record);
      record.chapter.saveSync();
    }
  }
}

/// `source_<id>` is Mihon's per-extension SharedPreferences name. Watchtower
/// reuses the same id space for extensions imported from the same repository,
/// so the id is the best available join key.
Source? _resolveMihonSourceByPreferenceKey(String key) {
  final id = int.tryParse(key.replaceFirst('source_', ''));
  if (id == null) return null;
  return isar.sources.getSync(id);
}

Source? _resolveMihonSource(String name) {
  if (name.trim().isEmpty) return null;
  final candidates = isar.sources
      .where()
      .findAllSync()
      .where((s) => (s.name ?? '').toLowerCase() == name.toLowerCase())
      .toList();
  if (candidates.isEmpty) return null;
  return candidates.firstWhere(
    (s) => (s.isAdded ?? false) && (s.isActive ?? false),
    orElse: () => candidates.first,
  );
}

SourcePreference? _mihonSourcePreference(int? sourceId, MihonPreference pref) {
  if (sourceId == null) return null;
  switch (pref.type) {
    case 'bool':
      return SourcePreference(
        sourceId: sourceId,
        key: pref.key,
        switchPreferenceCompat: SwitchPreferenceCompat(
          value: pref.value as bool,
        ),
      );
    case 'string':
      return SourcePreference(
        sourceId: sourceId,
        key: pref.key,
        editTextPreference: EditTextPreference(value: pref.value as String),
      );
    default:
      // Numbers and string sets are stored as their textual form; extension
      // code reads them back through `preferences.get(key)`.
      return SourcePreference(
        sourceId: sourceId,
        key: pref.key,
        editTextPreference: EditTextPreference(value: '${pref.value}'),
      );
  }
}

/// Applies one Mihon app preference onto [settings].
void _applyMihonPreference(Settings settings, MihonPreference pref) {
  final value = pref.value;
  switch (pref.key) {
    // ── Appearance ──────────────────────────────────────────────────────────
    case 'pref_theme_mode_key':
      switch (value) {
        case 'LIGHT':
          settings.themeIsDark = false;
          settings.followSystemTheme = false;
          break;
        case 'DARK':
          settings.themeIsDark = true;
          settings.followSystemTheme = false;
          break;
        default:
          settings.followSystemTheme = true;
      }
      break;
    case 'pref_theme_dark_amoled_key':
      if (value is bool) settings.pureBlackDarkMode = value;
      break;
    case 'relative_time_v2':
      if (value is bool) settings.relativeTimesTamps = value ? 2 : 0;
      break;
    case 'app_date_format':
      if (value is String && value.isNotEmpty) settings.dateFormat = value;
      break;

    // ── Library ─────────────────────────────────────────────────────────────
    case 'pref_display_mode_library':
      settings.displayType = _convertMihonDisplayMode(value);
      break;
    case 'display_category_tabs':
      if (value is bool) settings.libraryShowCategoryTabs = value;
      break;
    case 'display_number_of_items':
      if (value is bool) settings.libraryShowNumbersOfItems = value;
      break;
    case 'display_continue_reading_button':
      if (value is bool) settings.libraryShowContinueReadingButton = value;
      break;
    case 'display_download_badge':
      if (value is bool) settings.libraryDownloadedChapters = value;
      break;
    case 'display_language_badge':
      if (value is bool) settings.libraryShowLanguage = value;
      break;
    case 'pref_filter_library_downloaded_v2':
      settings.libraryFilterMangasDownloadType = _convertMihonTriState(value);
      break;
    case 'pref_filter_library_unread_v2':
      settings.libraryFilterMangasUnreadType = _convertMihonTriState(value);
      break;
    case 'pref_filter_library_started_v2':
      settings.libraryFilterMangasStartedType = _convertMihonTriState(value);
      break;
    case 'pref_filter_library_bookmarked_v2':
      settings.libraryFilterMangasBookMarkedType = _convertMihonTriState(value);
      break;
    case 'library_sorting_mode':
      settings.sortLibraryManga = _convertMihonLibrarySort(value);
      break;
    case 'default_chapter_filter_by_read':
      _setGlobalChapterFilter(
        value,
        (type) => settings.chapterFilterUnreadList!.add(
          ChapterFilterUnread(mangaId: 0, type: type),
        ),
      );
      break;
    case 'default_chapter_filter_by_downloaded':
      _setGlobalChapterFilter(
        value,
        (type) => settings.chapterFilterDownloadedList!.add(
          ChapterFilterDownloaded(mangaId: 0, type: type),
        ),
      );
      break;
    case 'default_chapter_filter_by_bookmarked':
      _setGlobalChapterFilter(
        value,
        (type) => settings.chapterFilterBookmarkedList!.add(
          ChapterFilterBookmarked(mangaId: 0, type: type),
        ),
      );
      break;
    case 'default_chapter_sort_by_source_or_number':
      if (value is int) {
        settings.sortChapterList!.add(
          SortChapter(mangaId: 0, index: _mihonChapterSortIndex(value)),
        );
      }
      break;
    case 'default_chapter_sort_by_ascending_or_descending':
      if (value is int) {
        final existing = settings.sortChapterList!;
        final index = existing
                .where((e) => e.mangaId == 0)
                .toList()
                .firstOrNull
                ?.index ??
            1;
        existing
          ..removeWhere((e) => e.mangaId == 0)
          ..add(
            SortChapter(mangaId: 0, index: index, reverse: value == 0x1),
          );
      }
      break;

    // ── Downloads ───────────────────────────────────────────────────────────
    case 'pref_download_only_over_wifi_key':
      if (value is bool) settings.downloadOnlyOnWifi = value;
      break;
    case 'save_chapter_as_cbz':
      if (value is bool) settings.saveAsCBZArchive = value;
      break;
    case 'remove_after_marked_as_read_key':
      if (value is bool) settings.deleteDownloadAfterReading = value;
      break;
    case 'download_parallel_source_limit':
      if (value is int) settings.concurrentDownloads = value;
      break;

    // ── Reader ──────────────────────────────────────────────────────────────
    case 'pref_enable_transitions_key':
      if (value is bool) settings.animatePageTransitions = value;
      break;
    case 'pref_show_page_number_key':
      if (value is bool) settings.showPagesNumber = value;
      break;
    case 'fullscreen':
      if (value is bool) settings.fullScreenReader = value;
      break;
    case 'crop_borders':
      if (value is bool) settings.cropBorders = value;
      break;
    case 'webtoon_side_padding':
      if (value is int) settings.webtoonSidePadding = value;
      break;
    case 'pref_keep_screen_on_key':
      if (value is bool) settings.keepScreenOnReader = value;
      break;
    case 'pref_default_reading_mode_key':
      if (value is int) {
        settings.defaultReaderMode = _convertMihonReadingMode(value);
      }
      break;

    // ── Network / advanced ──────────────────────────────────────────────────
    case 'default_user_agent':
      if (value is String && value.isNotEmpty) settings.userAgent = value;
      break;
    case 'doh_provider':
      if (value is int) settings.doHProviderId = value;
      break;
    case 'pref_downloaded_only':
      if (value is bool) settings.downloadedOnlyMode = value;
      break;
    case 'incognito_mode':
      if (value is bool) settings.incognitoMode = value;
      break;

    // ── Security ────────────────────────────────────────────────────────────
    case 'use_biometric_lock':
      if (value is bool) settings.appLockEnabled = value;
      break;

    // ── Backup ──────────────────────────────────────────────────────────────
    case 'backup_interval':
      if (value is int) settings.backupFrequency = value;
      break;
  }
}

void _setGlobalChapterFilter(
  Object? value,
  void Function(int type) add,
) {
  if (value is! int) return;
  final type = _mihonTriStateFromFlag(value);
  if (type != null) add(type);
}

int? _mihonTriStateFromFlag(int flag) {
  switch (flag & 0x6) {
    case 0x2:
      return 1;
    case 0x4:
      return 2;
    default:
      return null;
  }
}

int _mihonUnreadType(int flags) {
  switch (flags & 0x6) {
    case 0x2:
      return 1;
    case 0x4:
      return 2;
    default:
      return 0;
  }
}

int _mihonDownloadedType(int flags) {
  switch (flags & 0x18) {
    case 0x8:
      return 1;
    case 0x10:
      return 2;
    default:
      return 0;
  }
}

int _mihonBookmarkedType(int flags) {
  switch (flags & 0x60) {
    case 0x20:
      return 1;
    case 0x40:
      return 2;
    default:
      return 0;
  }
}

/// Mihon `chapterFlags` sorting → Watchtower `SortChapter.index`.
/// Watchtower: 1 = source order (default), 2 = upload date, 3 = name.
int _mihonChapterSortIndex(int flags) {
  switch (flags & 0x300) {
    case 0x200:
      return 2;
    case 0x300:
      return 3;
    default:
      return 1;
  }
}

/// Mihon `TriState` (DISABLED / ENABLED_IS / ENABLED_NOT) → Watchtower 0/1/2.
int _convertMihonTriState(Object? value) {
  switch (value) {
    case 'ENABLED_IS':
      return 1;
    case 'ENABLED_NOT':
      return 2;
    default:
      return 0;
  }
}

DisplayType _convertMihonDisplayMode(Object? value) {
  switch (value) {
    case 'COMFORTABLE_GRID':
      return DisplayType.comfortableGrid;
    case 'LIST':
      return DisplayType.list;
    case 'COVER_ONLY_GRID':
      return DisplayType.coverOnlyGrid;
    default:
      return DisplayType.compactGrid;
  }
}

/// Mihon `"<TYPE>,<DIRECTION>"` → Watchtower sort index + reverse.
SortLibraryManga _convertMihonLibrarySort(Object? value) {
  if (value is! String || value.isEmpty) return SortLibraryManga();
  final parts = value.split(',');
  final index = switch (parts.first) {
    'LAST_READ' => 1,
    'LAST_MANGA_UPDATE' => 2,
    'UNREAD_COUNT' => 3,
    'TOTAL_CHAPTERS' => 4,
    'LATEST_CHAPTER' => 5,
    'DATE_ADDED' => 6,
    _ => 0,
  };
  return SortLibraryManga(
    index: index,
    reverse: parts.length > 1 && parts[1] == 'DESCENDING',
  );
}

ReaderMode _convertMihonReadingMode(int flag) {
  switch (flag & 0x7) {
    case 0x1:
      return ReaderMode.ltr;
    case 0x2:
      return ReaderMode.rtl;
    case 0x3:
      return ReaderMode.vertical;
    case 0x4:
      return ReaderMode.webtoon;
    case 0x5:
      return ReaderMode.verticalContinuous;
    default:
      return ReaderMode.vertical;
  }
}

void _invalidateCommonState(Ref ref) {
  ref.read(synchingProvider(syncId: 1).notifier).clearAllChangedParts(false);
  ref.invalidate(followSystemThemeStateProvider);
  ref.invalidate(themeModeStateProvider);
  ref.invalidate(blendLevelStateProvider);
  ref.invalidate(flexSchemeColorStateProvider);
  ref.invalidate(pureBlackDarkModeStateProvider);
  ref.invalidate(l10nLocaleStateProvider);
  ref.invalidate(navigationOrderStateProvider);
  ref.invalidate(hideItemsStateProvider);
  ref.invalidate(extensionsRepoStateProvider(ItemType.manga));
  ref.invalidate(extensionsRepoStateProvider(ItemType.anime));
  ref.invalidate(extensionsRepoStateProvider(ItemType.novel));
  ref.read(routerCurrentLocationStateProvider.notifier).refresh();
}

/// Mihon `SManga` status → Watchtower [Status].
Status _convertMihonStatus(int idx) {
  switch (idx) {
    case 1:
      return Status.ongoing;
    case 2:
      return Status.completed;
    case 3:
      return Status.publishingFinished;
    case 4:
      return Status.publishingFinished;
    case 5:
      return Status.canceled;
    case 6:
      return Status.onHiatus;
    default:
      return Status.unknown;
  }
}
