// ignore_for_file: depend_on_referenced_packages
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart' hide Category;
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

  /// Check (and optionally request) MANAGE_EXTERNAL_STORAGE on Android.
  ///
  /// [requestIfNeeded] — when true (default) the real OS dialog / Settings
  /// intent is shown if the permission is not yet granted.  Pass false to
  /// perform a silent status-only check without prompting the user.
  Future<bool> requestPermission({bool requestIfNeeded = true}) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    Permission permission = Permission.manageExternalStorage;
    if (await permission.isGranted) return true;
    if (!requestIfNeeded) return false;
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
    if (!kIsWeb && Platform.isAndroid) {
      directory = Directory("/storage/emulated/0/Watchtower/");
    } else {
      final dir = await getApplicationDocumentsDirectory();
      // The documents dir in iOS is already named "Watchtower".
      // Appending "Watchtower" to the documents dir would create
      // unnecessarily nested Watchtower/Watchtower/ folder.
      if (!kIsWeb && Platform.isIOS) return dir;
      directory = Directory(path.join(dir.path, 'Watchtower'));
    }
    return directory;
  }

  Future<Directory?> getMpvDirectory() async {
    final defaultDirectory = await getDefaultDirectory();
    String dbDir = path.join(defaultDirectory!.path, 'mpv');
    await createDirectorySafely(dbDir);
    return Directory(dbDir);
  }

  Future<Directory?> getExtensionServerDirectory() async {
    final defaultDirectory = await getDefaultDirectory();
    String dbDir = path.join(defaultDirectory!.path, 'extension_server');
    await createDirectorySafely(dbDir);
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
    if (!kIsWeb && Platform.isAndroid) {
      directory = Directory(
        dPath.isEmpty ? "/storage/emulated/0/Watchtower/" : "$dPath/",
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final p = dPath.isEmpty ? dir.path : dPath;
      // The documents dir in iOS is already named "Watchtower".
      // Appending "Watchtower" to the documents dir would create
      // unnecessarily nested Watchtower/Watchtower/ folder.
      if (!kIsWeb && Platform.isIOS) return Directory(p);
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
        ? "Watch"
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
    if (!kIsWeb && Platform.isAndroid) return dir;
    if (!kIsWeb && Platform.isIOS) {
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
    if (!kIsWeb && Platform.isAndroid) {
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
    } catch (e) {
      // Do NOT call requestPermission() here — permissions are granted during
      // onboarding (page 3). Calling it here would open a system dialog at any
      // random point (e.g. when a download starts) which is confusing.
      debugPrint('createDirectorySafely failed for $dirPath: $e');
    }
  }

  Future<Isar> initDB(String? path, {bool inspector = false}) async {
      Directory? dir;
      if (path == null) {
        dir = await getDatabaseDirectory();
      } else {
        dir = Directory(path);
      }

      // If the DB is already open (e.g. called concurrently from an isolate),
      // return the existing instance immediately.
      final existing = Isar.getInstance('watchtowerDb');
      if (existing != null && existing.isOpen) return existing;

      final schemas = [
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
      ];

      // Helper: purge any broken/partial Isar instance stuck in the global
      // registry.  When Isar.open() throws, isar_community may still have
      // registered an empty Isar object (with _collections uninitialised)
      // under the name 'watchtowerDb'.  Returning that object via
      // Isar.getInstance() and assigning it to `isar` causes every
      // subsequent isar.settings access to throw:
      //   LateInitializationError: Field '_collections@...' has not been
      //   initialized.
      // We must close (evict) that zombie before any retry.
      Future<void> evictBrokenInstance() async {
        try {
          final zombie = Isar.getInstance('watchtowerDb');
          if (zombie != null) await zombie.close(deleteFromDisk: false);
        } catch (_) {}
      }

      // Helper: delete the on-disk files so the next open starts fresh.
      Future<void> deleteDbFiles() async {
        for (final suffix in ['.isar', '.isar.lock', '.isar.tmp']) {
          try {
            final f = File('${dir!.path}/watchtowerDb$suffix');
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }

      Isar isar;
      try {
        isar = await Isar.open(
          schemas,
          directory: dir!.path,
          name: "watchtowerDb",
          inspector: inspector,
        );
      } catch (e) {
        final eMsg = e.toString();
        debugPrint('[initDB] Isar.open failed ($eMsg) — evicting zombie, deleting stale DB, retrying');

        // Step 1: evict any zombie Isar registered during the failed open.
        await evictBrokenInstance();

        // Step 2: delete stale on-disk files (schema mismatch from old build).
        await deleteDbFiles();

        // Step 3: first retry on a clean slate.
        try {
          isar = await Isar.open(
            schemas,
            directory: dir!.path,
            name: "watchtowerDb",
            inspector: inspector,
          );
        } catch (e2) {
          debugPrint('[initDB] retry-1 failed ($e2) — evicting again, waiting 500ms, final attempt');

          // The open may have registered another zombie — evict it too.
          await evictBrokenInstance();
          await Future.delayed(const Duration(milliseconds: 500));

          // Step 4: final attempt — let it throw if the DB is unrecoverable.
          isar = await Isar.open(
            schemas,
            directory: dir!.path,
            name: "watchtowerDb",
            inspector: inspector,
          );
        }
      }

    // CDN jsDelivr — faster, globally cached, no GitHub rate limits.
    const _wtBase =
        'https://cdn.jsdelivr.net/gh/ferelking242/watchtower-extensions@main';
    const _oldWtBase =
        'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';

    final mangaRepo = Repo(
      jsonUrl: '$_wtBase/manga/index.json',
      name: 'Watchtower – Manga',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );
    final watchRepo = Repo(
      jsonUrl: '$_wtBase/watch/index.json',
      name: 'Watchtower – Watch',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );
    final novelRepo = Repo(
      jsonUrl: '$_wtBase/novel/index.json',
      name: 'Watchtower – Novels',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );

    // Mihon official extension repos
    const _mihonUrl =
        'https://raw.githubusercontent.com/mihonapp/extensions/repo/index.min.json';
    final mihonMangaRepo = Repo(
      jsonUrl: _mihonUrl,
      name: 'Mihon – Manga',
      website: 'https://mihonapp.netlify.app',
    );
    final mihonWatchRepo = Repo(
      jsonUrl: _mihonUrl,
      name: 'Mihon – Anime',
      website: 'https://mihonapp.netlify.app',
    );

    // LNReader novel sources
    const _lnreaderUrl =
        'https://raw.githubusercontent.com/LNReader/lnreader-sources/main/v2/index.json';
    final lnreaderRepo = Repo(
      jsonUrl: _lnreaderUrl,
      name: 'LNReader – Novels',
      website: 'https://github.com/LNReader/lnreader-sources',
    );

    bool _isWatchtowerRepo(Repo r) =>
        r.jsonUrl?.contains('ferelking242/watchtower-extensions') == true;

    // Migrate raw.githubusercontent URLs → jsDelivr for existing users.
    bool _migrateToJsDelivr(List<Repo>? repos) {
      if (repos == null) return false;
      var changed = false;
      for (final r in repos) {
        if (r.jsonUrl?.startsWith(_oldWtBase) == true) {
          r.jsonUrl = r.jsonUrl!.replaceFirst(_oldWtBase, _wtBase);
          changed = true;
        }
      }
      return changed;
    }

    bool _hasRepo(List<Repo>? repos, String urlFragment) =>
        repos?.any((r) => r.jsonUrl?.contains(urlFragment) == true) == true;

    try {
      final settings = await isar.settings.filter().idEqualTo(227).findFirst();
      if (settings == null) {
        await isar.writeTxn(
          () async => isar.settings.put(
            Settings(
              mangaExtensionsRepo: [mangaRepo, mihonMangaRepo],
              animeExtensionsRepo: [watchRepo, mihonWatchRepo],
              novelExtensionsRepo: [novelRepo, lnreaderRepo],
            ),
          ),
        );
      } else {
        bool needsUpdate = false;

        // 1 — Migrate existing Watchtower URLs to jsDelivr CDN
        if (_migrateToJsDelivr(settings.mangaExtensionsRepo)) needsUpdate = true;
        if (_migrateToJsDelivr(settings.animeExtensionsRepo)) needsUpdate = true;
        if (_migrateToJsDelivr(settings.novelExtensionsRepo)) needsUpdate = true;

        // 2 — Ensure Watchtower base repos are present
        if (!_hasRepo(settings.mangaExtensionsRepo, 'manga/index.json')) {
          settings.mangaExtensionsRepo = [
            ...?settings.mangaExtensionsRepo,
            mangaRepo,
          ];
          needsUpdate = true;
        }
        if (!_hasRepo(settings.animeExtensionsRepo, 'watch/index.json')) {
          settings.animeExtensionsRepo = [
            ...?settings.animeExtensionsRepo,
            watchRepo,
          ];
          needsUpdate = true;
        }
        if (!_hasRepo(settings.novelExtensionsRepo, 'novel/index.json')) {
          settings.novelExtensionsRepo = [
            ...?settings.novelExtensionsRepo,
            novelRepo,
          ];
          needsUpdate = true;
        }

        // 3 — Add Mihon repos if not already present
        if (!_hasRepo(settings.mangaExtensionsRepo, 'mihonapp/extensions')) {
          settings.mangaExtensionsRepo = [
            ...?settings.mangaExtensionsRepo,
            mihonMangaRepo,
          ];
          needsUpdate = true;
        }
        if (!_hasRepo(settings.animeExtensionsRepo, 'mihonapp/extensions')) {
          settings.animeExtensionsRepo = [
            ...?settings.animeExtensionsRepo,
            mihonWatchRepo,
          ];
          needsUpdate = true;
        }

        // 4 — Add LNReader repo if not already present
        if (!_hasRepo(settings.novelExtensionsRepo, 'LNReader/lnreader-sources')) {
          settings.novelExtensionsRepo = [
            ...?settings.novelExtensionsRepo,
            lnreaderRepo,
          ];
          needsUpdate = true;
        }

        if (needsUpdate) {
          await isar.writeTxn(() async => isar.settings.put(settings));
        }
      }
    } catch (e) {
      // DB is already open at this point — the catch covers the settings
      // initialisation block above, NOT the Isar.open() call.  Requesting OS
      // storage permission here makes no sense (Isar uses internal app
      // storage on Android) and could trigger a Settings intent in the middle
      // of startup.  Just retry the write directly.
      debugPrint('[initDB] Settings init failed ($e) — retrying without permission gate');
      try {
        final settings = await isar.settings
            .filter()
            .idEqualTo(227)
            .findFirst();
        if (settings == null) {
          await isar.writeTxn(
            () async => isar.settings.put(
              Settings(
                mangaExtensionsRepo: [mangaRepo, mihonMangaRepo],
                animeExtensionsRepo: [watchRepo, mihonWatchRepo],
                novelExtensionsRepo: [novelRepo, lnreaderRepo],
              ),
            ),
          );
        }
      } catch (e2) {
        debugPrint('[initDB] Settings retry also failed: $e2');
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
