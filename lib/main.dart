import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'utils/io_stub.dart';
import 'package:app_links/app_links.dart';
import 'package:collection/collection.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart'
    hide WebViewEnvironment, WebViewEnvironmentSettings;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/home/services/home_prewarm.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/services/auto_backup_service.dart';
import 'package:watchtower/services/cache_storage_manager.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/utils/mock_isar.dart';
import 'package:watchtower/remote/remote_web_sync.dart'
    if (dart.library.io) 'package:watchtower/remote/remote_web_sync_stub.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/track.dart' as track;
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/models/track_search.dart';
import 'package:watchtower/modules/manga/detail/providers/track_state_providers.dart';
import 'package:watchtower/modules/manga/reader/providers/crop_borders_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/storage_usage.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/back_navigation.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/services/fetch_sources_list.dart'
    show hasPendingExtensionUpdate, installExtensionUpdate;
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/src/rust/frb_generated.dart';
import 'package:watchtower/utils/discord_rpc.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/concurrency.dart';
import 'package:watchtower/utils/url_protocol/api.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/display_prefs_provider.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/settings/security/providers/security_state_provider.dart';
import 'package:watchtower/modules/more/settings/security/app_lock_screen.dart';
import 'package:media_kit/media_kit.dart'
    if (dart.library.js_interop) 'utils/media_kit_stub.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:watchtower/modules/onboarding/onboarding_screen.dart';
import 'package:watchtower/modules/onboarding/onboarding_state.dart';
import 'package:watchtower/utils/window_geometry.dart';
import 'package:watchtower/services/anti_bot/browser_bridge.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_service.dart';
import 'package:watchtower/services/mpv_config_service.dart';
import 'package:watchtower/modules/media/widgets/bulk_enqueue_controller.dart';
import 'package:watchtower/services/update_notification_service.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/ui/widgets/desktop_shortcuts.dart';
import 'cli/watchtower_cli.dart'
    if (dart.library.js_interop) 'cli/watchtower_cli_stub.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/kv_store/encrypted_kv_store.dart';
// --- NFile integration ---
import 'package:provider/provider.dart';
import 'package:watchtower/modules/plugin/nfile/providers/file_manager_provider.dart'
    as nfile_fm;
import 'package:watchtower/modules/plugin/nfile/providers/media_provider.dart'
    as nfile_media;
import 'package:watchtower/modules/plugin/nfile/services/preferences_service.dart'
    as nfile_prefs;
import 'package:watchtower/modules/plugin/nfile/services/pin_service.dart'
    as nfile_pin;
import 'package:watchtower/modules/plugin/nfile/services/network_connections_service.dart'
    as nfile_network;
import 'package:watchtower/modules/plugin/nfile/services/recycle_bin_service.dart'
    as nfile_recycle;
import 'package:watchtower/modules/music/l10n/generated/app_localizations.dart'
    as music_l10n;

late Isar isar;
DiscordRPC? discordRpc;
WebViewEnvironment? webViewEnvironment;
String? customDns;

Source? _findSourceForCloudflareUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  if (host == null || host.isEmpty) return null;
  final normalizedHost = host.startsWith('www.') ? host.substring(4) : host;

  Source? match;
  var matchedHostLength = -1;
  try {
    for (final source in isar.sources.where().findAllSync()) {
      final sourceHost = Uri.tryParse(source.baseUrl ?? '')?.host.toLowerCase();
      if (sourceHost == null || sourceHost.isEmpty) continue;
      final normalizedSourceHost = sourceHost.startsWith('www.')
          ? sourceHost.substring(4)
          : sourceHost;
      if (normalizedHost != normalizedSourceHost &&
          !normalizedHost.endsWith('.$normalizedSourceHost')) {
        continue;
      }
      if (normalizedSourceHost.length > matchedHostLength) {
        match = source;
        matchedHostLength = normalizedSourceHost.length;
      }
    }
  } catch (_) {
    return null;
  }
  return match;
}

void _writeCliDiagnostic(String? message, {int? wrapWidth}) {
  if (message != null && message.isNotEmpty) {
    stderr.writeln(message);
  }
}

/// Runs one startup stage behind its own error boundary and timer.
///
/// Everything before `runApp` used to be a hard dependency of the launch. One
/// failing service — a Hive box left corrupt by a kill-during-write, a
/// keychain read that throws on a cold boot, a platform channel that never
/// answers — propagated out of `main()` and left the native splash on screen
/// forever, which users experience as "the app crashes at launch" or "it just
/// sits there". A stage failure is now logged and skipped; the app still
/// reaches its first frame and the failure stays visible in the session log.
Future<void> _startupStage(
  String name,
  Future<void> Function() body, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final sw = Stopwatch()..start();
  try {
    await body().timeout(timeout);
  } catch (e, st) {
    debugPrint(
      '[startup] "$name" failed after ${sw.elapsedMilliseconds} ms: $e',
    );
    AppLogger.log(
      'startup stage "$name" failed: $e',
      logLevel: LogLevel.error,
      error: e,
      stackTrace: st,
    );
  } finally {
    final ms = sw.elapsedMilliseconds;
    // Worth keeping: a stage that eats more than a couple of frames is the
    // first thing to look at when someone reports a slow launch.
    if (ms >= 40) {
      debugPrint('[startup] $name → ${ms}ms');
      AppLogger.log('[startup] $name → ${ms}ms', logLevel: LogLevel.debug);
    }
  }
}

/// Opens a Hive box, recovering from the corruption a kill-during-write leaves
/// behind: Hive then throws on open, and that used to abort the whole launch.
Future<void> _openHiveBoxSafely(String name) async {
  try {
    await Hive.openBox(name);
    return;
  } catch (e, st) {
    debugPrint('[startup] Hive box "$name" failed to open: $e');
    AppLogger.log(
      'Hive box "$name" failed to open — recreating it',
      logLevel: LogLevel.error,
      error: e,
      stackTrace: st,
    );
  }
  try {
    await Hive.deleteBoxFromDisk(name);
    await Hive.openBox(name);
    AppLogger.log(
      'Hive box "$name" recreated after a corrupt open',
      logLevel: LogLevel.info,
    );
  } catch (e, st) {
    debugPrint('[startup] Hive box "$name" unrecoverable: $e');
    AppLogger.log(
      'Hive box "$name" unrecoverable: $e',
      logLevel: LogLevel.error,
      error: e,
      stackTrace: st,
    );
  }
}

void main(List<String> args) async {
  final isCliInvocation = !kIsWeb && args.isNotEmpty && args.first == '--cli';

  // Zone-level catch-all for anything that slips through both layers
  runZonedGuarded(
    () async {
      if (isCliInvocation) {
        // The Linux runner has already started Flutter before Dart main runs.
        // Initialize only the Dart bindings needed by platform channels and
        // extension worker isolates; never start the application's widget tree.
        // Flutter diagnostics are not part of the CLI's machine-readable
        // stdout stream.
        debugPrint = _writeCliDiagnostic;
        WidgetsFlutterBinding.ensureInitialized();
        final exitCode = await runWatchtowerCli(args.skip(1).toList());
        exitCode == 0 ? exit(0) : exit(exitCode);
      }
      final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      final splashClock = Stopwatch()..start();
      // flutter_native_splash only has a generated native/web splash bridge
      // when its generator has run. This project ships a custom Flutter web
      // shell, so preserve/remove are only valid on native platforms.
      if (!kIsWeb) {
        FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
      }
      // Detect real device RAM and apply adaptive image-cache limits.
      // Must run before any other init so the cache is sized correctly from
      // the very first image load. Safe to await — it is a single fast
      // platform-channel call (< 5 ms).
      await DeviceCapabilities.initialize();
      if (!kIsWeb && Platform.isLinux && runWebViewTitleBarWidget(args)) return;

      // Widget-layer errors (build / layout / paint)
      FlutterError.onError = (FlutterErrorDetails details) {
        final msg = details.exceptionAsString();
        // Suppress broken image/asset loading errors (e.g. extension icons 404)
        if (AppLogger.shouldSuppressImageError(msg)) return;
        // Suppress residual shadcn_flutter Tooltip OverlayManager null-check crash.
        // The music module previously used shadcn widgets; some tooltip interactions
        // can still trigger this on hover — it is harmless on mobile.
        final stack = details.stack?.toString() ?? '';
        if (msg.contains('Null check operator') &&
            stack.contains('tooltip.dart'))
          return;
        // Always print to browser console on web so we can diagnose issues
        debugPrint('[FlutterError] $msg\n${details.stack}');
        FlutterError.presentError(details);
        AppLogger.log(
          'FlutterError: $msg\n${details.stack}',
          logLevel: LogLevel.error,
        );
      };

      // Async errors that escape the Flutter framework (PlatformDispatcher)
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        final msg = error.toString();
        // Suppress image loading errors from polluting logs
        if (AppLogger.shouldSuppressImageError(msg)) return true;
        // Always print to browser console on web so we can diagnose issues
        debugPrint('[PlatformDispatcher] $msg\n$stack');
        AppLogger.log(
          'PlatformDispatcher error: $msg\n$stack',
          logLevel: LogLevel.error,
        );
        return true; // handled — prevent app termination
      };

      MediaKit.ensureInitialized();
      if (!kIsWeb) {
        // Wrap each native-library init in its own try-catch.
        // Without this, an UnsatisfiedLinkError (e.g. missing .so in the APK,
        // wrong ABI, or a cargokit compile failure) propagates up through the
        // async function and halts execution BEFORE runApp() is ever called —
        // the app stays frozen on the native splash screen with zero Flutter
        // output and no crash report visible to the user.
        try {
          await RustLib.init();
        } catch (e, st) {
          debugPrint(
            '[main] RustLib.init() failed — app will run without Rust FFI: $e\n$st',
          );
          AppLogger.log(
            'RustLib.init failed: $e\n$st',
            logLevel: LogLevel.error,
          );
        }
        // imgCropIsolate is started lazily in _postLaunchInit(): its
        // `process()` awaits `start()` on first use, so nothing before the
        // first frame needs the isolate. Spawning it here only added an
        // isolate start (plus a second RustLib.init) to the splash.
        // getIsolateService.start() is intentionally called AFTER initDB below.
        // Both the main isolate and the background isolate call StorageProvider().initDB().
        // If a stale DB (schema mismatch from an old build) is on disk, calling them
        // concurrently causes both to race on the delete+retry path, leaving isar
        // uninitialized and crashing every provider that reads isar.settings.
        // Starting the isolate only after the main isolate has successfully opened the DB
        // guarantees the background isolate always sees a clean, valid database.
      }
      if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
        await windowManager.ensureInitialized();
        // A PC layout needs room: below this the desktop shell would collapse
        // into the phone layout and look broken. 800×600 keeps the sidebar and
        // a two-column grid usable.
        await windowManager.setMinimumSize(const Size(800, 600));
        // Hide the window immediately so it doesn't flash a blank white frame
        // while Flutter is still building the first widget tree.
        // It is shown again in addPostFrameCallback below, after the first frame.
        await windowManager.hide();
        await WindowGeometry.restore();
      }
      if (!kIsWeb && Platform.isWindows) {
        registerProtocolHandler("watchtower");
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final availableVersion = await WebViewEnvironment.getAvailableVersion();
        if (availableVersion != null) {
          final document = await getApplicationDocumentsDirectory();
          webViewEnvironment = await WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
              userDataFolder: p.join(document.path, 'flutter_inappwebview'),
            ),
          );
        }
      }
      final storage = StorageProvider();
      if (kIsWeb) {
        const _wtBase =
            'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';
        final _mockIsar = MockIsar()
          ..seed<Settings>(
            227,
            Settings(
              mangaExtensionsRepo: [
                Repo(
                  jsonUrl: '$_wtBase/index/manga.json',
                  name: 'Watchtower – Manga',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
              animeExtensionsRepo: [
                Repo(
                  jsonUrl: '$_wtBase/index/watch.json',
                  name: 'Watchtower – Watch',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
              novelExtensionsRepo: [
                Repo(
                  jsonUrl: '$_wtBase/index/novel.json',
                  name: 'Watchtower – Novels',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
            ),
          );
        // Sync real data from remote server (if configured).
        // seedMockWebData removed — no fake demo data on production web build.
        await syncRemoteDataToMockIsar(_mockIsar);
        isar = _mockIsar;
      } else {
        // Fresh install (no live database) — restore the automatic snapshot
        // left by a previous installation before opening Isar, so the library,
        // settings, extensions and caches come back intact. See
        // AutoBackupService for the snapshot layout.
        await _startupStage('auto-backup fresh-install restore', () async {
          await AutoBackupService.restoreOnFreshInstall();
        }, timeout: const Duration(seconds: 60));
        var dbReady = false;
        try {
          isar = await storage.initDB(null, inspector: false);
          dbReady = true;
        } catch (e, st) {
          // initDB already retries three times after evicting the handle and
          // deleting the files. If it still cannot open, staying on the splash
          // helps nobody: log it, start the app, and let the user reach
          // Settings → Data & storage to restore a snapshot.
          debugPrint('[startup] initDB failed: $e');
          AppLogger.log(
            'initDB failed — starting without a database: $e',
            logLevel: LogLevel.error,
            error: e,
            stackTrace: st,
          );
        }
        // Auto-réparation du record `Settings` : un record corrompu (ex. cache
        // de pages embarqué dont les préfixes de taille dépassent les octets
        // présents → `RangeError (length)` à la désérialisation) rendait
        // TOUTE lecture de settings fautive dans toute l'app, dont le
        // démarrage des téléchargements. On lit+répare dès l'ouverture de la
        // base, avant le moindre écran / scheduler.
        // `isar` is a `late` global: touching it after a failed open throws a
        // LateInitializationError out of `main()`, which is the very freeze
        // this block is here to prevent.
        if (dbReady) healSettingsRecord(isar: isar);
        // _ensureLocalSources() is intentionally deferred to _postLaunchInit().
        // Running it here (before runApp) triggers Isar Rust FFI string_to_bytes
        // malloc on the main thread while memory is tight on iPhone 7 (2 GB).
        // iOS frees background-app RAM only after the foreground app becomes
        // visible — deferring past runApp() gives the system time to do that.
      }
      // Start the background isolate AFTER the DB is open and isar is assigned,
      // but no longer *before* the first frame. Spawning the pool means up to
      // four isolate starts, each re-reading intl date data: easily a second of
      // splash on a mid-range phone. Nothing needs the pool until the first
      // extension call, and `GetIsolateService.get()` awaits `start()` (now
      // memoized), so the launch path only has to kick it off.
      if (!kIsWeb) {
        unawaited(
          getIsolateService.start().then((_) {
            debugPrint(
              '[startup] extension workers ready '
              '(${getIsolateService.workerCount})',
            );
          }).catchError((Object e) {
            debugPrint('[startup] extension workers failed: $e');
          }),
        );
      }

      // Init Hive BEFORE runApp so nav_display providers read persisted values
      // on the very first build instead of falling back to defaults.
      final hivePath = (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
          ? "databases"
          : p.join("Watchtower", "databases");
      await Hive.initFlutter(
        kIsWeb ? null : ((!kIsWeb && Platform.isAndroid) ? "" : hivePath),
      );
      Hive.registerAdapter(TrackSearchAdapter());
      for (final box in const [
        'nav_display',
        'ui_prefs',
        'library_settings',
        'reader_prefs',
        'player_prefs',
      ]) {
        await _openHiveBoxSafely(box);
      }
      // Fresh install: put the snapshotted preference boxes back before any
      // provider reads them. No-op on a normal launch.
      await AutoBackupService.restoreHiveBoxes();

      // --- Music module init ---
      // Both carry their own fallback (see EncryptedKvStoreService.initialize),
      // and the timeout keeps a wedged keychain/keystore from holding the
      // splash hostage on a cold boot.
      await _startupStage(
        'music KV store',
        KVStoreService.initialize,
        timeout: const Duration(seconds: 10),
      );
      if (!kIsWeb) {
        await _startupStage(
          'encrypted KV store',
          EncryptedKvStoreService.initialize,
          timeout: const Duration(seconds: 10),
        );
      }

      // --- NFile service initialisation ---
      try {
        await nfile_prefs.PreferencesService.init();
        await nfile_pin.PinService.init();
        await nfile_network.NetworkConnectionsService.init();
        await nfile_recycle.RecycleBinService.init();
      } catch (e) {
        debugPrint('[NFile] Service init error: $e');
      }

      needsOnboarding = !await onboardingIsComplete();
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => nfile_fm.FileManagerProvider(),
            ),
            ChangeNotifierProvider(create: (_) => nfile_media.MediaProvider()),
          ],
          child: ProviderScope(
            child: MyApp(),
            retry: (retryCount, error) => null,
          ),
        ),
      );
      if (!kIsWeb) {
        // Keep one branded native splash for a short, stable hand-off. Android
        // 12+ owns the system splash; flutter_native_splash keeps it until
        // Flutter has rendered its first frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Fetch + decode the hero artwork while the splash is still up so
          // the home carousel shows posters on its first frame instead of
          // colour blocks. Fire-and-forget: it must never delay the splash
          // removal or block the first frame.
          unawaited(prewarmHomeHeroImages().catchError((_) {}));
          final remaining =
              const Duration(milliseconds: 600) - splashClock.elapsed;
          Future<void>.delayed(
            remaining.isNegative ? Duration.zero : remaining,
            FlutterNativeSplash.remove,
          );
        });
      }
      unawaited(
        _postLaunchInit(storage).catchError((Object e, StackTrace st) {
          // Post-launch work must never surface as an unhandled async error:
          // that is what used to take the whole zone down after the app was
          // already visible.
          debugPrint('[startup] post-launch init failed: $e');
          AppLogger.log(
            'post-launch init failed: $e',
            logLevel: LogLevel.error,
            error: e,
            stackTrace: st,
          );
        }),
      );
    },
    (Object error, StackTrace stack) {
      final msg = error.toString();
      if (AppLogger.shouldSuppressImageError(msg)) return;
      // Always print to browser console on web so we can diagnose issues
      debugPrint('[runZonedGuarded] $msg\n$stack');
      AppLogger.log(
        'runZonedGuarded error: $msg\n$stack',
        logLevel: LogLevel.error,
      );
    },
    // Dart print() bypasses debugPrint and writes directly to stdout otherwise.
    zoneSpecification: isCliInvocation
        ? ZoneSpecification(
            print: (_self, _parent, _zone, line) {
              stderr.writeln(line);
            },
          )
        : null,
  );
}

void _ensureLocalSources() {
  const itemTypes = [ItemType.manga, ItemType.anime, ItemType.novel];
  isar.writeTxnSync(() {
    for (final type in itemTypes) {
      final existing = isar.sources
          .filter()
          .nameEqualTo('local')
          .and()
          .langEqualTo('')
          .and()
          .itemTypeEqualTo(type)
          .findFirstSync();
      if (existing == null) {
        isar.sources.putSync(
          Source()
            ..name = 'local'
            ..lang = ''
            ..isAdded = true
            ..isActive = true
            ..isPinned = false
            ..lastUsed = false
            ..itemType = type,
        );
      } else if (!(existing.isAdded ?? false) ||
          !(existing.isActive ?? false)) {
        isar.sources.putSync(
          existing
            ..isAdded = true
            ..isActive = true,
        );
      }
    }
  });
}

Future<void> _postLaunchInit(StorageProvider storage) async {
  // Deferred from main() — see comment there. Runs after runApp() so iOS has
  // freed background-app memory before the first Isar Rust FFI string alloc.
  if (!kIsWeb) {
    try {
      _ensureLocalSources();
    } catch (e, st) {
      // Only reachable when initDB failed and the `isar` global is unset; it
      // must not stop the rest of the deferred init from running.
      AppLogger.log(
        '_ensureLocalSources failed: $e',
        logLevel: LogLevel.error,
        error: e,
        stackTrace: st,
      );
    }
  }
  // The floating log box and file logging follow the "Logs" switch in
  // À propos > Développeur. Read it here so [AppLogger.init] can skip the
  // whole file sink when logging is off, and so the overlay starts hidden.
  // Guarded: when initDB failed the global is unset and touching it throws.
  var logsEnabled = false;
  try {
    logsEnabled = readSettingsSafely(isar: isar).enableLogs ?? false;
  } catch (_) {}
  AppLogger.setLoggingEnabled(logsEnabled);
  await AppLogger.init();
  // Start the automatic snapshot of the database, Hive boxes and preferences
  // into <storage root>/.backup, so a reinstall can restore everything.
  if (!kIsWeb) unawaited(AutoBackupService.startAutoBackup());
  if (!kIsWeb) {
    // Auto-tune the isolate pool size to the device's CPU count.
    // Use 2× logical-core count so IO-bound work can overlap on each core,
    // clamped to [8, 32] so low-end phones get at least 8 workers and
    // high-end devices don't spawn hundreds of isolates.
    final cores = Platform.numberOfProcessors;
    final poolSize = (cores * 2).clamp(8, 32);
    debugPrint(
      '[main] device has $cores CPU cores → isolate pool size = $poolSize',
    );
    // Lazy init: configure the pool size now but defer isolate creation to
    // the first actual download.  The pool's submit methods already call
    // initialize() on first use — this avoids spawning 8–32 isolates at
    // startup when the user may not download anything in this session.
    DownloadIsolatePool.configure(poolSize: poolSize);
    // The reader's border-crop isolate is not needed before the first frame:
    // `ImageCropIsolate.process()` awaits `start()` on first use. Kick it off
    // here so the isolate (and its second RustLib.init) is warm by the time a
    // reader page asks for a crop, without paying for it during the splash.
    unawaited(
      imgCropIsolate.start().catchError((Object e) {
        debugPrint('[startup] crop isolate start failed: $e');
      }),
    );
  }
  // Hive is already initialized + nav_display opened in main() before runApp.
  // Nothing more to do here for Hive setup.
  // Trim the on-disk image caches down to the user's ceiling once per launch.
  // It runs here (not before runApp) because the walk touches every cache file
  // and must not delay the first frame.
  if (!kIsWeb) {
    unawaited(CacheStorageManager.instance.enforceLimit(force: true));
  }
  if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
    discordRpc = DiscordRPC(applicationId: "1395040506677039157");
    await discordRpc?.initialize();
  }
  if (!kIsWeb) {
    await storage.deleteBtDirectory();
    // iOS: pre-create the download directory tree at launch so the folders
    // appear in the Files app without needing to trigger a download first.
    if (Platform.isIOS) {
      final baseDir = await storage.getDirectory();
      if (baseDir != null) {
        await storage.createDirectorySafely('${baseDir.path}/download');
      }
    }
    // Ensure Watchtower/local folder exists for local media source.
    // Goes through storage.getDirectory() (not a hardcoded /storage/emulated/0/...
    // path) so it correctly falls back to the app-scoped folder when
    // MANAGE_EXTERNAL_STORAGE hasn't been granted, instead of silently
    // failing and leaving the local source permanently empty.
    try {
      final baseDir = await storage.getDirectory();
      if (baseDir != null) {
        final localDir = Directory(p.join(baseDir.path, 'local'));
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
      }
    } catch (_) {}
    // Only init notification service AFTER onboarding is complete.
    // During onboarding the user grants notification permission manually.
    // Calling init() here on first launch would trigger the system dialog
    // immediately without user interaction.
    if (!needsOnboarding) {
      WatchtowerNotificationService.instance.registerExtensionUpdateInstaller(
        _installPendingExtensionsFromNotification,
      );
      unawaited(
        BypassNotificationService.instance.init(
          sourceResolver: _findSourceForCloudflareUrl,
        ),
      );
      unawaited(
        WatchtowerNotificationService.instance.init().then((_) {
          unawaited(
            WatchtowerNotificationService.instance.scheduleWeeklyReminder(),
          );
          unawaited(
            WatchtowerNotificationService.instance.checkForUpdateAndNotify(),
          );
        }),
      );
    }
  }
}

Future<String?> _installPendingExtensionsFromNotification() async {
  final sources = await isar.sources.buildQuery<Source>().findAll();
  final updates =
      sources
          .where(
            (source) =>
                source.isAdded == true &&
                source.isLocal != true &&
                source.sourceCodeLanguage != SourceCodeLanguage.dart &&
                hasPendingExtensionUpdate(source),
          )
          .toList()
        ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

  if (updates.isEmpty) return 'Aucune mise à jour d’extension en attente.';

  var installedCount = 0;
  final failedNames = <String>[];
  // Each extension downloads from its own repo; install them with a bounded
  // pool instead of one after another.
  await forEachParallel<Source>(updates, kNetworkConcurrency, (source) async {
    try {
      await installExtensionUpdate(source);
      installedCount++;
    } catch (error, stackTrace) {
      failedNames.add(source.name ?? 'Extension');
      AppLogger.log(
        'Notification extension update failed for ${source.name}: $error\n$stackTrace',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }, propagateErrors: false);

  if (failedNames.isEmpty) {
    return '$installedCount extension${installedCount == 1 ? '' : 's'} mise'
        '${installedCount == 1 ? '' : 's'} à jour.';
  }
  return '$installedCount installée${installedCount == 1 ? '' : 's'} · '
      '${failedNames.length} échec${failedNames.length == 1 ? '' : 's'} : '
      '${failedNames.join(', ')}';
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver, WindowListener {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? lastUri;
  bool _extensionRefreshInFlight = false;

  /// Gives top-level pages a back destination when the router has nothing to
  /// pop, so a system back press never closes the app from a settings or
  /// download page reached with `go()`.
  WatchtowerBackDispatcher? _backDispatcher;

  String _defaultTabLocation() {
    final hiddenItems = ref.read(hideItemsStateProvider);
    return ref
            .read(navigationOrderStateProvider)
            .where((e) => !hiddenItems.contains(e))
            .firstOrNull ??
        '/WatchtowerHome';
  }

  @override
  void initState() {
    super.initState();
    WatchtowerNotificationService.instance.registerMediaDownloadActionHandler(
      (chapterId, action) =>
          handleMediaDownloadNotificationAction(ref, chapterId, action),
    );
    // A Cloudflare refusal first seen while replaying a request from an
    // extension/download worker is reported to the root isolate (the only one
    // that can raise a notification) through the browser bridge.
    BrowserBridge.onBrowserUnavailable = (url, sourceId) {
      unawaited(
        BypassNotificationService.instance.notifyChallengeDetected(
          url: url,
          sourceId: sourceId,
        ),
      );
    };
    WatchtowerNotificationService.instance.registerDownloadQueueActionHandler(
      BulkEnqueueController.handleNotificationAction,
    );
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
      windowManager.addListener(this);
    }
    initializeDateFormatting();
    customDns = ref.read(customDnsStateProvider);
    if (!kIsWeb) _checkTrackerRefresh();
    if (!kIsWeb) _initDeepLinks();
    if (!kIsWeb) _setupMpvConfig().catchError((_) {});
    unawaited(ref.read(scanLocalLibraryProvider.future));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Show desktop window after the first real Flutter frame to avoid the
      // blank white-screen caused by window_manager hiding the window during
      // initialization without an explicit show() call.
      if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
      }
      // Refresh installed extension repositories once after the first frame.
      // This is the source of truth for both the in-app notification centre
      // and the actionable native notification.
      unawaited(_refreshInstalledExtensionUpdates());
      // Resume persisted queue work even when the user opens another section
      // first. The queue screen also kicks this provider, but downloads should
      // not depend on visiting that screen after an app restart.
      unawaited(ref.read(processDownloadsProvider().future));
      if (ref.read(clearChapterCacheOnAppLaunchStateProvider)) {
        // Watch before calling clearcache to keep it alive, so that _getTotalDiskSpace completes safely
        ref.watch(totalChapterCacheSizeStateProvider);
        ref
            .read(totalChapterCacheSizeStateProvider.notifier)
            .clearCache(showToast: false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!kIsWeb) {
        unawaited(_refreshInstalledExtensionUpdates());
        unawaited(
          WatchtowerNotificationService.instance.checkForUpdateAndNotify(),
        );
        // Re-run mpv setup in case the user just granted storage permission
        // from the onboarding screen or the system Settings app.
        // The function checks permission internally and is idempotent.
        _setupMpvConfig().catchError((_) {});
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Snapshot everything before the process can be killed, so the most
      // recent state survives an uninstall/reinstall.
      if (!kIsWeb) unawaited(AutoBackupService.backupNow());
      if (!kIsWeb && Platform.isLinux) {
        return;
      }
      // Lock the app when going to background (if lock is enabled)
      final lockEnabled = isar.settings.getSync(227)?.appLockEnabled ?? false;
      if (lockEnabled) {
        ref.read(appUnlockedStateProvider.notifier).lock();
      }
    }
  }

  Future<void> _refreshInstalledExtensionUpdates() async {
    if (kIsWeb || _extensionRefreshInFlight) return;
    _extensionRefreshInFlight = true;
    try {
      final types = (await isar.sources.buildQuery<Source>().findAll())
          .where(
            (source) =>
                source.isAdded == true &&
                source.isLocal != true &&
                source.sourceCodeLanguage != SourceCodeLanguage.dart,
          )
          .map((source) => source.itemType)
          .toSet();
      for (final type in types) {
        try {
          await ref.read(
            fetchItemSourcesListProvider(
              id: null,
              reFresh: true,
              itemType: type,
            ).future,
          );
        } catch (error, stack) {
          AppLogger.log(
            'Startup extension update check failed for $type',
            logLevel: LogLevel.warning,
            tag: LogTag.repo,
            error: error,
            stackTrace: stack,
          );
        }
      }
    } finally {
      _extensionRefreshInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final forcedDark = ref.watch(themeModeStateProvider);
    final themeMode = followSystem
        ? ThemeMode.system
        : (forcedDark ? ThemeMode.dark : ThemeMode.light);
    final locale = ref.watch(l10nLocaleStateProvider);
    final router = ref.watch(routerProvider);
    final pageTransStyle = ref.watch(pageTransitionStyleProvider);
    final backDispatcher =
        _backDispatcher ??= WatchtowerBackDispatcher(
          router: () => ref.read(routerProvider),
          defaultLocation: _defaultTabLocation,
        );
    backDispatcher.ensureAttached();

    return MaterialApp.router(
      backButtonDispatcher: backDispatcher,
      theme: ref
          .watch(lightThemeProvider)
          .copyWith(
            pageTransitionsTheme: _buildPageTransitionsTheme(pageTransStyle),
          ),
      darkTheme: ref
          .watch(darkThemeProvider)
          .copyWith(
            pageTransitionsTheme: _buildPageTransitionsTheme(pageTransStyle),
          ),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        music_l10n.AppLocalizations.delegate,
      ],
      supportedLocales: {
        ...AppLocalizations.supportedLocales,
        ...music_l10n.AppLocalizations.supportedLocales,
      }.toList(),
      builder: (context, child) {
        // Rebuild the whole tree when the tablet-mode preference changes so
        // `context.isTablet` (and every layout branching on it) re-evaluates.
        ref.watch(tabletModeProvider);
        if (!kIsWeb && !Platform.isLinux) {
          final isUnlocked = ref.watch(appUnlockedStateProvider);
          final lockEnabled = ref.watch(appLockEnabledStateProvider);
          if (lockEnabled && !isUnlocked) {
            return const AppLockScreen();
          }
        }
        final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        // The mouse back button is a desktop-only affordance: on web the
        // browser already owns Back, so wiring it here would double-navigate.
        if (!kIsWeb && !isMobile) {
          child = _MouseBackButtonHandler(
            router: router,
            child: child ?? const SizedBox.shrink(),
          );
        }
        // Desktop and web get global keyboard shortcuts (sections, search,
        // settings, back/forward) so the app answers to a keyboard the way a
        // PC user expects.
        if (DesktopShortcuts.isEnabled) {
          child = DesktopShortcuts(router: router, child: child!);
        }
        // Apply UI scale from Advanced Settings
        if (Hive.isBoxOpen('advanced_settings')) {
          final box = Hive.box('advanced_settings');
          final uiScale = (box.get('ui_scale', defaultValue: 1.0) as num)
              .toDouble();
          if (uiScale != 1.0) {
            child = MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(uiScale)),
              child: child!,
            );
          }
        }
        return child ?? const SizedBox.shrink();
      },
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      title: 'Watchtower',
      scrollBehavior: AllowScrollBehavior(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
      windowManager.removeListener(this);
      WindowGeometry.save();
    }
    _linkSubscription?.cancel();
    discordRpc?.destroy();
    AppLogger.dispose();
    super.dispose();
  }

  @override
  void onWindowResized() => WindowGeometry.save();

  @override
  void onWindowMoved() => WindowGeometry.save();

  @override
  void onWindowClose() {
    WindowGeometry.save();
    // Workaround for libepoxy error when closing app; caused by media-kit
    if (!kIsWeb && Platform.isLinux) exit(0);
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      if (uri == lastUri) return; // Debouncing Deep Links
      lastUri = uri;
      switch (uri.host) {
        case "add-repo":
          final repoName = uri.queryParameters["repo_name"];
          final repoUrl = uri.queryParameters["repo_url"];
          final mangaRepoUrls = uri.queryParametersAll["manga_url"];
          final animeRepoUrls = uri.queryParametersAll["anime_url"];
          final novelRepoUrls = uri.queryParametersAll["novel_url"];
          final context = navigatorKey.currentContext;
          if (context == null || !context.mounted) return;
          final l10n = context.l10n;
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(l10n.add_repo),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${l10n.name}: ${repoName ?? 'Unknown'}"),
                    const SizedBox(height: 8),
                    Text("URL: ${repoUrl ?? 'Unknown'}"),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text(l10n.cancel),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  FilledButton(
                    child: Text(l10n.add),
                    onPressed: () async {
                      if (context.mounted) Navigator.of(context).pop();

                      final validUrls = await _checkValidUrls([
                        ...mangaRepoUrls ?? [],
                        ...animeRepoUrls ?? [],
                        ...novelRepoUrls ?? [],
                      ]);

                      if (!validUrls) {
                        botToast(l10n.unsupported_repo);
                        return;
                      }

                      void addRepos(ItemType type, List<String>? urls) {
                        if (urls == null) return;
                        final current = ref.read(
                          extensionsRepoStateProvider(type),
                        );
                        final updated = [
                          ...current,
                          ...urls.map(
                            (e) => Repo(
                              name: repoName,
                              jsonUrl: e,
                              website: repoUrl,
                            ),
                          ),
                        ];
                        ref
                            .read(extensionsRepoStateProvider(type).notifier)
                            .set(updated);
                      }

                      addRepos(ItemType.manga, mangaRepoUrls);
                      addRepos(ItemType.anime, animeRepoUrls);
                      addRepos(ItemType.novel, novelRepoUrls);
                      botToast(l10n.repo_added);
                    },
                  ),
                ],
              );
            },
          );
          break;
        case "add-button":
          final buttonDataRaw = uri.queryParametersAll["button"];
          final context = navigatorKey.currentContext;
          if (context == null || !context.mounted || buttonDataRaw == null) {
            return;
          }
          final l10n = context.l10n;
          for (final buttonRaw in buttonDataRaw) {
            final buttonData = jsonDecode(
              utf8.decode(base64.decode(buttonRaw)),
            );
            if (buttonData is Map<String, dynamic>) {
              final customButton = CustomButton.fromJson(buttonData);
              await showDialog(
                context: navigatorKey.currentContext!,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(l10n.custom_buttons_add),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${l10n.name}: ${customButton.title ?? 'Unknown'}",
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: Text(l10n.cancel),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      FilledButton(
                        child: Text(l10n.add),
                        onPressed: () async {
                          if (context.mounted) Navigator.of(context).pop();
                          await isar.writeTxn(() async {
                            await isar.customButtons.put(
                              customButton
                                ..pos = await isar.customButtons.count()
                                ..isFavourite = false
                                ..id = null
                                ..updatedAt =
                                    DateTime.now().millisecondsSinceEpoch,
                            );
                          });
                          botToast(l10n.custom_buttons_added);
                        },
                      ),
                    ],
                  );
                },
              );
            }
          }
          break;
        default:
      }
    });
  }

  Future<bool> _checkValidUrls(List<String> urls) async {
    if (urls.isEmpty) return true;
    final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    // Each URL is an independent host; probing them one at a time made adding
    // several repos wait for the sum of every round-trip.
    final results = await mapParallel<String, bool>(
      urls,
      kNetworkConcurrency,
      (url) async {
        final req = await http.get(Uri.parse(url));
        final sourceList = (jsonDecode(req.body) as List).map(
          (e) => Source.fromJson(e),
        );
        return sourceList.firstOrNull?.name != null;
      },
      propagateErrors: false,
    );
    return results.every((ok) => ok == true);
  }

  Future<void> _setupMpvConfig() async {
    if (kIsWeb) return;
    // Wait for storage permission before touching external storage.
    // On first launch (onboarding not yet complete) the permission is not
    // granted yet — creating directories would throw Permission denied.
    if (!kIsWeb && Platform.isAndroid) {
      final hasPermission = await StorageProvider().requestPermission(
        requestIfNeeded: false,
      );
      if (!hasPermission) {
        debugPrint(
          '_setupMpvConfig: skipped — storage permission not granted yet',
        );
        return;
      }
    }
    final provider = StorageProvider();
    final dir = await provider.getMpvDirectory();
    if (dir == null) return;
    try {
      await MpvConfigService.ensureInstalled(dir);
    } catch (e) {
      debugPrint('_setupMpvConfig: deferred download failed: $e');
    }
  }

  Future<void> _checkTrackerRefresh() async {
    final prefs = await isar.trackPreferences
        .filter()
        .syncIdIsNotNull()
        .findAll();
    for (final pref in prefs) {
      final temp = track.Track(
        syncId: pref.syncId,
        status: track.TrackStatus.completed,
      );
      ref
          .read(
            trackStateProvider(
              track: temp,
              itemType: null,
              widgetRef: ref,
            ).notifier,
          )
          .checkRefresh();
    }
  }
}

class _MouseBackButtonHandler extends StatelessWidget {
  final GoRouter router;
  final Widget child;

  const _MouseBackButtonHandler({required this.router, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kBackMouseButton != 0) {
          if (router.canPop()) router.pop();
        }
      },
      child: child,
    );
  }
}

class AllowScrollBehavior extends MaterialScrollBehavior {
  // This allows the scrollable widgets to be scrolled with touch, mouse, stylus,
  // inverted stylus, trackpad, and unknown pointer devices.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}

// ── Page transition theme helper ─────────────────────────────────────────────

PageTransitionsTheme _buildPageTransitionsTheme(int style) {
  PageTransitionsBuilder builder;
  switch (style) {
    case 1:
      builder =
          const ZoomPageTransitionsBuilder(); // CupertinoPageTransitionsBuilder removed in Flutter 3.32
    case 2:
      builder = const ZoomPageTransitionsBuilder();
    case 3:
      builder = const _NoTransitionBuilder();
    default:
      builder = const FadeUpwardsPageTransitionsBuilder();
  }
  return PageTransitionsTheme(
    builders: {for (final p in TargetPlatform.values) p: builder},
  );
}

class _NoTransitionBuilder extends PageTransitionsBuilder {
  const _NoTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
