// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/sync_preference.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class StorageProvider {
  static final StorageProvider _instance = StorageProvider._internal();
  StorageProvider._internal();
  factory StorageProvider() => _instance;

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    Permission permission = Permission.manageExternalStorage;
    if (await permission.isGranted) return true;
    if (await permission.request().isGranted) {
      return true;
    }
    return false;
  }

  Future<void> deleteBtDirectory() async {
    final btDir = Directory(await _btDirectoryPath());
    if (await btDir.exists()) await btDir.delete(recursive: true);
  }

  Future<void> deleteTmpDirectory() async {
    final tmpDir = Directory(await _tempDirectoryPath());
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  }

  Future<Directory?> getDefaultDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory("/storage/emulated/0/Watchtower/");
    } else {
      final dir = await getApplicationDocumentsDirectory();
      // The documents dir in iOS is already named "Watchtower".
      // Appending "Watchtower" to the documents dir would create
      // unnecessarily nested Watchtower/Watchtower/ folder.
      if (Platform.isIOS) return dir;
      directory = Directory(path.join(dir.path, 'Watchtower'));
    }
    return directory;
  }

  Future<Directory?> getMpvDirectory() async {
    final defaultDirectory = await getDefaultDirectory();
    String dbDir = path.join(defaultDirectory!.path, 'mpv');
    await Directory(dbDir).create(recursive: true);
    return Directory(dbDir);
  }

  Future<Directory?> getExtensionServerDirectory() async {
    final defaultDirectory = await getDefaultDirectory();
    String dbDir = path.join(defaultDirectory!.path, 'extension_server');
    await Directory(dbDir).create(recursive: true);
    return Directory(dbDir);
  }

  Future<Directory?> getBtDirectory() async {
    final dbDir = await _btDirectoryPath();
    await createDirectorySafely(dbDir);
    return Directory(dbDir);
  }

  Future<String> _btDirectoryPath() async {
    final defaultDirectory = await getDefaultDirectory();
    return path.join(defaultDirectory!.path, 'torrents');
  }

  Future<Directory?> getTmpDirectory() async {
    final tmpPath = await _tempDirectoryPath();
    await createDirectorySafely(tmpPath);
    return Directory(tmpPath);
  }

  Future<Directory> getCacheDirectory(String? imageCacheFolderName) async {
    final cacheImagesDirectory = path.join(
      (await getApplicationCacheDirectory()).path,
      imageCacheFolderName ?? 'cacheimagecover',
    );
    return Directory(cacheImagesDirectory);
  }

  Future<Directory> createCacheDirectory(String? imageCacheFolderName) async {
    final cachePath = await getCacheDirectory(imageCacheFolderName);
    await createDirectorySafely(cachePath.path);
    return cachePath;
  }

  Future<String> _tempDirectoryPath() async {
    final defaultDirectory = await getDirectory();
    return path.join(defaultDirectory!.path, 'tmp');
  }

  Future<Directory?> getIosBackupDirectory() async {
    final defaultDirectory = await getDefaultDirectory();
    String dbDir = path.join(defaultDirectory!.path, 'backup');
    await createDirectorySafely(dbDir);
    return Directory(dbDir);
  }

  Future<Directory?> getDirectory() async {
    Directory? directory;
    String dPath = "";
    try {
      final setting = isar.settings.getSync(227);
      dPath = setting?.downloadLocation ?? "";
    } catch (e) {
      debugPrint("Could not get downloadLocation from Isar settings: $e");
    }
    if (Platform.isAndroid) {
      directory = Directory(
        dPath.isEmpty ? "/storage/emulated/0/Watchtower/" : "$dPath/",
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final p = dPath.isEmpty ? dir.path : dPath;
      // The documents dir in iOS is already named "Watchtower".
      // Appending "Watchtower" to the documents dir would create
      // unnecessarily nested Watchtower/Watchtower/ folder.
      if (Platform.isIOS) return Directory(p);
      directory = Directory(path.join(p, 'Watchtower'));
    }
    return directory;
  }

  Future<Directory?> getMangaMainDirectory(Chapter chapter) async {
    final manga = chapter.manga.value!;
    final itemType = chapter.manga.value!.itemType;
    final itemTypePath = itemType == ItemType.manga
        ? "Manga"
        : itemType == ItemType.anime
        ? "Anime"
        : "Novel";
    final dir = await getDirectory();
    return Directory(
      path.join(
        dir!.path,
        'downloads',
        itemTypePath,
        '${manga.source} (${manga.lang!.toUpperCase()})',
        manga.name!.replaceForbiddenCharacters('_'),
      ),
    );
  }

  Future<Directory?> getMangaChapterDirectory(
    Chapter chapter, {
    Directory? mangaMainDirectory,
  }) async {
    final basedir = mangaMainDirectory ?? await getMangaMainDirectory(chapter);
    String scanlator = chapter.scanlator?.isNotEmpty ?? false
        ? "${chapter.scanlator!.replaceForbiddenCharacters('_')}_"
        : "";
    return Directory(
      path.join(
        basedir!.path,
        scanlator + chapter.name!.replaceForbiddenCharacters('_').trim(),
      ),
    );
  }

  Future<Directory?> getDatabaseDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    String dbDir;
    if (Platform.isAndroid) return dir;
    if (Platform.isIOS) {
      // Put the database files inside /databases like on Windows, Linux
      // So they are not just in the app folders root dir
      dbDir = path.join(dir.path, 'databases');
    } else {
      dbDir = path.join(dir.path, 'Watchtower', 'databases');
    }
    await createDirectorySafely(dbDir);
    return Directory(dbDir);
  }

  Future<Directory?> getGalleryDirectory() async {
    String gPath;
    if (Platform.isAndroid) {
      gPath = "/storage/emulated/0/Pictures/Watchtower/";
    } else {
      gPath = path.join((await getDirectory())!.path, 'Pictures');
    }
    await createDirectorySafely(gPath);
    return Directory(gPath);
  }

  Future<void> createDirectorySafely(String dirPath) async {
    final dir = Directory(dirPath);
    try {
      await dir.create(recursive: true);
    } catch (_) {
      if (await requestPermission()) {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          debugPrint('Initial directory creation failed for $dirPath: $e');
        }
      } else {
        debugPrint('Permission denied. Cannot create: $dirPath');
      }
    }
  }

  Future<Isar> initDB(String? path, {bool inspector = false}) async {
    Directory? dir;
    if (path == null) {
      dir = await getDatabaseDirectory();
    } else {
      dir = Directory(path);
    }

    final isar = await Isar.open(
      [
        MangaSchema,
        ChangedPartSchema,
        ChapterSchema,
        CategorySchema,
        CustomButtonSchema,
        UpdateSchema,
        HistorySchema,
        DownloadSchema,
        SourceSchema,
        SettingsSchema,
        TrackPreferenceSchema,
        TrackSchema,
        SyncPreferenceSchema,
        SourcePreferenceSchema,
        SourcePreferenceStringValueSchema,
      ],
      directory: dir!.path,
      name: "watchtowerDb",
      inspector: inspector,
    );
    final watchtowerExtensionsRepo = Repo(
      jsonUrl:
          'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/index.min.json',
      name: 'Watchtower Extensions',
    );

    try {
      final settings = await isar.settings.filter().idEqualTo(227).findFirst();
      if (settings == null) {
        await isar.writeTxn(
          () async => isar.settings.put(
            Settings(
              mangaExtensionsRepo: [watchtowerExtensionsRepo],
              animeExtensionsRepo: [watchtowerExtensionsRepo],
              novelExtensionsRepo: [watchtowerExtensionsRepo],
            ),
          ),
        );
      } else {
        bool needsUpdate = false;
        if (settings.mangaExtensionsRepo == null ||
            settings.mangaExtensionsRepo!.isEmpty) {
          settings.mangaExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        if (settings.animeExtensionsRepo == null ||
            settings.animeExtensionsRepo!.isEmpty) {
          settings.animeExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        if (settings.novelExtensionsRepo == null ||
            settings.novelExtensionsRepo!.isEmpty) {
          settings.novelExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        // Remove any old 3rd-party repos and replace with watchtower-only
        final onlyWatchtower =
            (r) => r.jsonUrl?.contains('ferelking242/watchtower-extensions') == true;
        final hasExtraManga = settings.mangaExtensionsRepo!.any((r) => !onlyWatchtower(r));
        final hasExtraAnime = settings.animeExtensionsRepo!.any((r) => !onlyWatchtower(r));
        final hasExtraNovel = settings.novelExtensionsRepo!.any((r) => !onlyWatchtower(r));
        if (hasExtraManga) {
          settings.mangaExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        if (hasExtraAnime) {
          settings.animeExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        if (hasExtraNovel) {
          settings.novelExtensionsRepo = [watchtowerExtensionsRepo];
          needsUpdate = true;
        }
        if (needsUpdate) {
          await isar.writeTxn(() async => isar.settings.put(settings));
        }
      }
    } catch (_) {
      if (await requestPermission()) {
        try {
          final settings = await isar.settings
              .filter()
              .idEqualTo(227)
              .findFirst();
          if (settings == null) {
            await isar.writeTxn(
              () async => isar.settings.put(
                Settings(
                  mangaExtensionsRepo: [watchtowerExtensionsRepo],
                  animeExtensionsRepo: [watchtowerExtensionsRepo],
                  novelExtensionsRepo: [watchtowerExtensionsRepo],
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint("Failed after retry with permission: $e");
        }
      } else {
        debugPrint("Permission denied during Database init fallback.");
      }
    }

    final prefs = await isar.trackPreferences
        .filter()
        .syncIdIsNotNull()
        .findAll();
    await isar.writeTxn(() async {
      for (final pref in prefs) {
        await isar.trackPreferences.put(pref..refreshing = true);
      }
    });

    final customButton = await isar.customButtons
        .filter()
        .idIsNotNull()
        .findFirst();
    if (customButton == null) {
      await isar.writeTxn(() async {
        await isar.customButtons.put(
          CustomButton(
            title: "+85 s",
            codePress:
                """local intro_length = mp.get_property_native("user-data/current-anime/intro-length")
aniyomi.right_seek_by(intro_length)""",
            codeLongPress:
                """aniyomi.int_picker("Change intro length", "%ds", 0, 255, 1, "user-data/current-anime/intro-length")""",
            codeStartup: """function update_button(_, length)
  if length ~= nil then
    if length == 0 then
          aniyomi.hide_button()
          return
        else
          aniyomi.show_button()
        end
    aniyomi.set_button_title("+" .. length .. " s")
  end
end

if \$isPrimary then
  mp.observe_property("user-data/current-anime/intro-length", "number", update_button)
end""",
            isFavourite: true,
            pos: 0,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });
    }

    return isar;
  }
}
