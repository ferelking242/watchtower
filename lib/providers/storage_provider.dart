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
import 'package:watchtower/utils/constant.dart';

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

  // Resolves the app's base "Watchtower" folder on Android.
  //
  // Previously this always hardcoded /storage/emulated/0/Watchtower/, even
  // when MANAGE_EXTERNAL_STORAGE was not granted (denied by the user, or
  // blocked entirely by OEMs/Play Protect on some devices/ROMs). In that
  // case every Directory.create() call against that path fails silently
  // (caught in createDirectorySafely, only logged) and every feature that
  // depends on the folder existing — downloads, extension install, local
  // library scan, torrent/tmp dirs — just hangs or silently no-ops, which is
  // what showed up as "the app sits there for minutes, nothing happens".
  //
  // Fix: if the permission isn't granted, fall back to the app's own
  // external-files directory, which Android always grants without any
  // permission prompt. The folder still gets created immediately instead of
  // failing forever, and once the user grants MANAGE_EXTERNAL_STORAGE (or
  // grants it during onboarding) this switches back to the shared location.
  Future<Directory> _androidBaseDirectory() async {
    final hasPermission = await requestPermission(requestIfNeeded: false);
    if (hasPermission) {
      return Directory("/storage/emulated/0/Watchtower/");
    }
    final fallback = await getExternalStorageDirectory();
    if (fallback != null) {
      debugPrint(
        '[StorageProvider] MANAGE_EXTERNAL_STORAGE not granted — '
        'using app-scoped fallback: ${fallback.path}',
      );
      return fallback;
    }
    // Last resort: internal app storage always exists without any permission.
    final internal = await getApplicationDocumentsDirectory();
    return Directory(path.join(internal.path, 'Watchtower'));
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
      directory = await _androidBaseDirectory();
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
      final setting = isar.settings.getSync(kSettingsId);
      dPath = setting?.downloadLocation ?? "";
    } catch (e) {
      debugPrint("Could not get downloadLocation from Isar settings: $e");
    }
    if (!kIsWeb && Platform.isAndroid) {
      directory = dPath.isEmpty
          ? await _androidBaseDirectory()
          : Directory("$dPath/");
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

      // ── Version-gated DB protection ─────────────────────────────────────
        // isar_get_offsets crashes with SIGBUS (uncatchable in Dart) when the
        // on-disk DB was created with a different schema (stale build data).
        // We store a tiny version file next to the DB and wipe the DB files
        // before opening if the version doesn't match — guaranteeing a clean slate.
        const kCurrentDbVersion = '9';
        final versionFile = File('${dir!.path}/watchtowerDb.schema_version');
        try {
          final storedVersion = await versionFile.exists()
              ? await versionFile.readAsString()
              : null;
          if (storedVersion != kCurrentDbVersion) {
            debugPrint('[initDB] DB version mismatch ($storedVersion→$kCurrentDbVersion) — wiping stale files');
            for (final suffix in ['.isar', '.isar.lock', '.isar.tmp']) {
              try {
                final f = File('${dir!.path}/watchtowerDb$suffix');
                if (await f.exists()) await f.delete();
              } catch (_) {}
            }
            await versionFile.writeAsString(kCurrentDbVersion);
          }
        } catch (e) {
          debugPrint('[initDB] version-check error (non-fatal): $e');
        }
        // ─────────────────────────────────────────────────────────────────────

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

    // raw.githubusercontent — always up-to-date, no CDN staleness issues.
    const _wtBase =
        'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';
    const _cdnBase =
        'https://cdn.jsdelivr.net/gh/ferelking242/watchtower-extensions@main';

    final mangaRepo = Repo(
      jsonUrl: '$_wtBase/index/manga.json',
      name: 'Watchtower – Manga',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );
    final watchRepo = Repo(
      jsonUrl: '$_wtBase/index/watch.json',
      name: 'Watchtower – Watch',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );
    final novelRepo = Repo(
      jsonUrl: '$_wtBase/index/novel.json',
      name: 'Watchtower – Novels',
      website: 'https://github.com/ferelking242/watchtower-extensions',
    );

    // Keiyoushi — communauté officielle Mihon/Tachiyomi (manga)
    // 1 468 packages, CI GitHub Actions auto-rebuild à chaque commit
    const _keiyoushiUrl =
        'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
    final keiyoushiMangaRepo = Repo(
      jsonUrl: _keiyoushiUrl,
      name: 'Keiyoushi – Manga (Mihon)',
      website: 'https://keiyoushi.github.io',
    );

    // Aniyomi — extensions anime officielles (Jellyfin, Google Drive…)
    // Les extensions de streaming ont été retirées du repo officiel (pressions légales).
    // Les utilisateurs peuvent ajouter des dépôts communautaires manuellement.
    const _aniyomiUrl =
        'https://raw.githubusercontent.com/aniyomiorg/aniyomi-extensions/repo/index.min.json';
    final aniyomiWatchRepo = Repo(
      jsonUrl: _aniyomiUrl,
      name: 'Aniyomi – Anime',
      website: 'https://aniyomi.org',
    );

    bool _isWatchtowerRepo(Repo r) =>
        r.jsonUrl?.contains('ferelking242/watchtower-extensions') == true;

    // Migrate repo URLs for existing users.
    bool _migrateRepoUrls(List<Repo>? repos) {
      if (repos == null) return false;
      var changed = false;
      for (final r in repos) {
        // A — Watchtower: jsDelivr → raw.githubusercontent (jsDelivr @main is unreliable)
        if (r.jsonUrl?.startsWith(_cdnBase) == true) {
          r.jsonUrl = r.jsonUrl!.replaceFirst(_cdnBase, _wtBase);
          changed = true;
        }
        // B — Mihon: old broken mihonapp/extensions → keiyoushi (real repo)
        if (r.jsonUrl?.contains('mihonapp/extensions') == true) {
          r.jsonUrl = r.jsonUrl!.replaceFirst(
            'https://raw.githubusercontent.com/mihonapp/extensions',
            'https://raw.githubusercontent.com/keiyoushi/extensions',
          );
          changed = true;
        }
        // D — Watchtower: old manga|watch|novel/index.json → index/manga|watch|novel.json
          if (r.jsonUrl?.contains('ferelking242/watchtower-extensions') == true) {
            if (r.jsonUrl!.contains('/manga/index.json')) {
              r.jsonUrl = r.jsonUrl!.replaceFirst('/manga/index.json', '/index/manga.json');
              changed = true;
            } else if (r.jsonUrl!.contains('/watch/index.json')) {
              r.jsonUrl = r.jsonUrl!.replaceFirst('/watch/index.json', '/index/watch.json');
              changed = true;
            } else if (r.jsonUrl!.contains('/novel/index.json')) {
              r.jsonUrl = r.jsonUrl!.replaceFirst('/novel/index.json', '/index/novel.json');
              changed = true;
            }
          }
          // C — dead URL guard (reserved)
        if (r.jsonUrl?.contains('LNReader/lnreader-sources') == true) {
          r.jsonUrl = null; // will be filtered below
          changed = true;
        }
      }
      return changed;
    }

    // Remove repos with null or dead URLs left by migration C.
    List<Repo> _cleanRepos(List<Repo>? repos) =>
        repos?.where((r) => r.jsonUrl != null && r.jsonUrl!.isNotEmpty).toList() ?? [];

    bool _hasRepo(List<Repo>? repos, String urlFragment) =>
        repos?.any((r) => r.jsonUrl?.contains(urlFragment) == true) == true;

    bool _hasRepoUrl(Repo r, String urlFragment) =>
        r.jsonUrl?.contains(urlFragment) == true;

    try {
      final settings = await isar.settings.filter().idEqualTo(227).findFirst();
      if (settings == null) {
        await isar.writeTxn(
          () async => isar.settings.put(
            Settings(
              mangaExtensionsRepo: [mangaRepo],
              animeExtensionsRepo: [watchRepo],
              novelExtensionsRepo: [novelRepo],
            ),
          ),
        );
      } else {
        bool needsUpdate = false;

        // 1 — Migrate broken / outdated URLs
        if (_migrateRepoUrls(settings.mangaExtensionsRepo)) needsUpdate = true;
        if (_migrateRepoUrls(settings.animeExtensionsRepo)) needsUpdate = true;
        if (_migrateRepoUrls(settings.novelExtensionsRepo)) needsUpdate = true;
        settings.mangaExtensionsRepo = _cleanRepos(settings.mangaExtensionsRepo);
        settings.animeExtensionsRepo = _cleanRepos(settings.animeExtensionsRepo);
        settings.novelExtensionsRepo = _cleanRepos(settings.novelExtensionsRepo);

        // 2 — Ensure Watchtower base repos are present (users can add
        //     third-party repos like Keiyoushi or Aniyomi manually via settings)
        if (!_hasRepo(settings.mangaExtensionsRepo, 'index/manga.json')) {
          settings.mangaExtensionsRepo = [...settings.mangaExtensionsRepo!, mangaRepo];
          needsUpdate = true;
        }
        if (!_hasRepo(settings.animeExtensionsRepo, 'index/watch.json')) {
          settings.animeExtensionsRepo = [...settings.animeExtensionsRepo!, watchRepo];
          needsUpdate = true;
        }
        if (!_hasRepo(settings.novelExtensionsRepo, 'index/novel.json')) {
          settings.novelExtensionsRepo = [...settings.novelExtensionsRepo!, novelRepo];
          needsUpdate = true;
        }

        // 3 — Remove Keiyoushi/Aniyomi if forcibly added in an older version
        //     (we no longer push third-party repos onto users without consent)
        final prevMangaLen = settings.mangaExtensionsRepo?.length ?? 0;
        final prevAnimeLen = settings.animeExtensionsRepo?.length ?? 0;
        settings.mangaExtensionsRepo = settings.mangaExtensionsRepo
            ?.where((r) => !_hasRepoUrl(r, 'keiyoushi/extensions'))
            .toList();
        settings.animeExtensionsRepo = settings.animeExtensionsRepo
            ?.where((r) => !_hasRepoUrl(r, 'aniyomiorg/aniyomi-extensions'))
            .toList();
        if ((settings.mangaExtensionsRepo?.length ?? 0) != prevMangaLen) needsUpdate = true;
        if ((settings.animeExtensionsRepo?.length ?? 0) != prevAnimeLen) needsUpdate = true;

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
                mangaExtensionsRepo: [mangaRepo],
                animeExtensionsRepo: [watchRepo],
                novelExtensionsRepo: [novelRepo],
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
