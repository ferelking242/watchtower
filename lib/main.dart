import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'utils/io_stub.dart';
import 'package:app_links/app_links.dart';
import 'package:archive/archive.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart'
    hide WebViewEnvironment, WebViewEnvironmentSettings;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/utils/mock_isar.dart';
import 'package:watchtower/utils/mock_web_data.dart';
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
import 'package:watchtower/modules/more/data_and_storage/providers/storage_usage.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/m_extension_server.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/src/rust/frb_generated.dart';
import 'package:watchtower/utils/discord_rpc.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/url_protocol/api.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/settings/security/providers/security_state_provider.dart';
import 'package:watchtower/modules/more/settings/security/app_lock_screen.dart';
import 'package:media_kit/media_kit.dart'
    if (dart.library.js_interop) 'utils/media_kit_stub.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:watchtower/modules/onboarding/onboarding_screen.dart';
import 'package:watchtower/modules/onboarding/onboarding_state.dart';
import 'package:watchtower/utils/window_geometry.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_service.dart';
import 'package:watchtower/services/update_notification_service.dart';
import 'package:watchtower/services/mihon_auto_sync.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/kv_store/encrypted_kv_store.dart';
import 'package:watchtower/modules/music/l10n/generated/app_localizations.dart'
    as spotube_l10n;


late Isar isar;
DiscordRPC? discordRpc;
WebViewEnvironment? webViewEnvironment;
String? customDns;
void main(List<String> args) async {
  // Zone-level catch-all for anything that slips through both layers
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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
        if (msg.contains('Null check operator') && stack.contains('tooltip.dart')) return;
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
        await RustLib.init();
        await imgCropIsolate.start();
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
                  jsonUrl: '$_wtBase/manga/index.json',
                  name: 'Watchtower – Manga',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
              animeExtensionsRepo: [
                Repo(
                  jsonUrl: '$_wtBase/watch/index.json',
                  name: 'Watchtower – Watch',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
              novelExtensionsRepo: [
                Repo(
                  jsonUrl: '$_wtBase/novel/index.json',
                  name: 'Watchtower – Novels',
                  website:
                      'https://github.com/ferelking242/watchtower-extensions',
                ),
              ],
            ),
          );
        seedMockWebData(_mockIsar);
        // Sync real data from remote server (if configured)
        await syncRemoteDataToMockIsar(_mockIsar);
        isar = _mockIsar;
      } else {
        isar = await storage.initDB(null, inspector: false);
        // _ensureLocalSources() is intentionally deferred to _postLaunchInit().
        // Running it here (before runApp) triggers Isar Rust FFI string_to_bytes
        // malloc on the main thread while memory is tight on iPhone 7 (2 GB).
        // iOS frees background-app RAM only after the foreground app becomes
        // visible — deferring past runApp() gives the system time to do that.
      }
      // Start the background isolate AFTER the DB is open and isar is assigned.
      if (!kIsWeb) {
        await getIsolateService.start();
      }

      // Init Hive BEFORE runApp so nav_display providers read persisted values
      // on the very first build instead of falling back to defaults.
      final hivePath = (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
          ? "databases"
          : p.join("Watchtower", "databases");
      await Hive.initFlutter(kIsWeb ? null : ((!kIsWeb && Platform.isAndroid) ? "" : hivePath));
      Hive.registerAdapter(TrackSearchAdapter());
      await Hive.openBox('nav_display');
      await Hive.openBox('ui_prefs');

      // --- Music module init (Spotube) ---
      await KVStoreService.initialize();
      if (!kIsWeb) {
        await EncryptedKvStoreService.initialize();
      }

      needsOnboarding = !await onboardingIsComplete();
      runApp(ProviderScope(child: MyApp(), retry: (retryCount, error) => null));
      unawaited(_postLaunchInit(storage));
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
      } else if (!(existing.isAdded ?? false) || !(existing.isActive ?? false)) {
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
  if (!kIsWeb) _ensureLocalSources();
  await AppLogger.init();
  if (!kIsWeb) {
    unawaited(MDownloader.initializeIsolatePool(poolSize: 6));
  }
  // Hive is already initialized + nav_display opened in main() before runApp.
  // Nothing more to do here for Hive setup.
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
        for (final sub in ['downloads/Watch', 'downloads/Manga', 'downloads/Novel']) {
          await storage.createDirectorySafely('${baseDir.path}/$sub');
        }
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
    await cfResolutionWebviewServer();
      // Only init notification service AFTER onboarding is complete.
      // During onboarding the user grants notification permission manually.
      // Calling init() here on first launch would trigger the system dialog
      // immediately without user interaction.
      if (!needsOnboarding) {
        unawaited(BypassNotificationService.instance.init());
        unawaited(WatchtowerNotificationService.instance.init().then((_) {
          unawaited(WatchtowerNotificationService.instance.scheduleWeeklyReminder());
          unawaited(WatchtowerNotificationService.instance.checkForUpdateAndNotify());
        }));
      }
  }
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

  @override
  void initState() {
    super.initState();
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
      unawaited(_startExtensionServerAndSync());
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
        unawaited(WatchtowerNotificationService.instance.checkForUpdateAndNotify());
        // Re-run mpv setup in case the user just granted storage permission
        // from the onboarding screen or the system Settings app.
        // The function checks permission internally and is idempotent.
        _setupMpvConfig().catchError((_) {});
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
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

    return MaterialApp.router(
      theme: ref.watch(lightThemeProvider).copyWith(
        pageTransitionsTheme: _buildPageTransitionsTheme(pageTransStyle),
      ),
      darkTheme: ref.watch(darkThemeProvider).copyWith(
        pageTransitionsTheme: _buildPageTransitionsTheme(pageTransStyle),
      ),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        spotube_l10n.AppLocalizations.delegate,
      ],
      supportedLocales: {
          ...AppLocalizations.supportedLocales,
          ...spotube_l10n.AppLocalizations.supportedLocales,
        }.toList(),
      builder: (context, child) {
        if (!kIsWeb && !Platform.isLinux) {
          final isUnlocked = ref.watch(appUnlockedStateProvider);
          final lockEnabled = ref.watch(appLockEnabledStateProvider);
          if (lockEnabled && !isUnlocked) {
            return const AppLockScreen();
          }
        }
        if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
          child = _MouseBackButtonHandler(router: router, child: child ?? const SizedBox.shrink());
        }
        // Apply UI scale from Advanced Settings
          if (Hive.isBoxOpen('advanced_settings')) {
            final box = Hive.box('advanced_settings');
            final uiScale = (box.get('ui_scale', defaultValue: 1.0) as num).toDouble();
            if (uiScale != 1.0) {
              child = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(uiScale),
                ),
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
    MExtensionServerPlatform(ref).stopServer();
    _linkSubscription?.cancel();
    discordRpc?.destroy();
    stopCfResolutionWebviewServer();
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
    final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    for (final url in urls) {
      final req = await http.get(Uri.parse(url));
      try {
        final sourceList = (jsonDecode(req.body) as List).map(
          (e) => Source.fromJson(e),
        );
        if (sourceList.firstOrNull?.name == null) {
          return false;
        }
      } catch (err) {
        return false;
      }
    }
    return true;
  }

  Future<void> _setupMpvConfig() async {
    if (kIsWeb) return;
    // Wait for storage permission before touching external storage.
    // On first launch (onboarding not yet complete) the permission is not
    // granted yet — creating directories would throw Permission denied.
    if (!kIsWeb && Platform.isAndroid) {
      final hasPermission = await StorageProvider()
          .requestPermission(requestIfNeeded: false);
      if (!hasPermission) {
        debugPrint('_setupMpvConfig: skipped — storage permission not granted yet');
        return;
      }
    }
    final provider = StorageProvider();
    final dir = await provider.getMpvDirectory();
    if (dir == null) return;
    final mpvFile = File('${dir.path}/mpv.conf');
    final inputFile = File('${dir.path}/input.conf');
    String shadersDir = p.join(dir.path, 'shaders');
    String scriptsDir = p.join(dir.path, 'scripts');
    try {
      await Directory(shadersDir).create(recursive: true);
      await Directory(scriptsDir).create(recursive: true);
    } catch (e) {
      debugPrint('_setupMpvConfig: failed to create subdirectories: $e');
      return;
    }
    final filesMissing =
        !(await mpvFile.exists()) && !(await inputFile.exists());
    if (filesMissing) {
      try {
        final bytes = await rootBundle.load("assets/watchtower_mpv.zip");
        final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
        for (final file in archive.files) {
          if (file.name == "mpv.conf") {
            await mpvFile.writeAsBytes(file.content);
          } else if (file.name == "input.conf") {
            await inputFile.writeAsBytes(file.content);
          } else if (file.name.startsWith("shaders/") &&
              file.name.endsWith(".glsl")) {
            final shaderFile = File(
              '$shadersDir/${file.name.split("/").last}',
            );
            await shaderFile.writeAsBytes(file.content);
          } else if (file.name.startsWith("scripts/") &&
              (file.name.endsWith(".js") || file.name.endsWith(".lua"))) {
            final scriptFile = File(
              '$scriptsDir/${file.name.split("/").last}',
            );
            await scriptFile.writeAsBytes(file.content);
          }
        }
      } catch (_) {
        // MPV zip asset not available, directories already created above
      }
    }
  }

  Future<void> _startExtensionServerAndSync() async {
      await MExtensionServerPlatform(ref).startServer();
      if (!kIsWeb && Platform.isAndroid) {
        await Future.delayed(const Duration(seconds: 2));
        unawaited(MihonAutoSync.run());
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
      builder = const ZoomPageTransitionsBuilder();   // CupertinoPageTransitionsBuilder removed in Flutter 3.32
    case 2:
      builder = const ZoomPageTransitionsBuilder();
    case 3:
      builder = const _NoTransitionBuilder();
    default:
      builder = const FadeUpwardsPageTransitionsBuilder();
  }
  return PageTransitionsTheme(builders: {
    for (final p in TargetPlatform.values) p: builder,
  });
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
  ) =>
      child;
}
