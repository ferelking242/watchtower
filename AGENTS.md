# Repository notes

## CLI headless contract (CI)

`watchtower --cli …` must work without a graphical session and without Isar for
the database-free commands. CI (`.github/workflows/build-server.yml`,
`test-cli-contract.yml`) runs, on Linux, with `Xvfb` + `DISPLAY` set:

- `--cli doctor --json` → exit 0, JSON with `native: true` and
  `quickJs.available: true`. It probes the real extension engine via
  `getIsolateService` + `withExtensionService` and never opens Isar.
- `--cli extensions list --repo DIR --json` → exit 0, JSON with `sources`
  (list), `total == len(sources)`, `failures == []`. Loads the local
  `watchtower-extensions` checkout directly.
- `--cli extensions test --repo DIR --mode deep|load … --report FILE --json`
  → saved report must equal stdout; report has `total`/`failed`.
- Both commands share the app's diagnostic filters. `CliExtensionFilter`
  (`lib/cli/runtime/cli_extension_catalog.dart`) mirrors the app's
  `BrowseSourceFilters`: `--lang fr,en` (comma-separated and/or repeated),
  `--nsfw`/`--sfw`, `--engine javascript|dart`, `--tag cloudflare|account|drm|
  aggregator|comments|torrent|update|javascript|dart`, `--query`, `--only IDS`,
  `--type`. Unknown tag/engine values exit 64. Filters are applied on the
  resolved `Source`, so a CLI selection is exactly the subset the app tests.
  The workflow `Verify extension filters select the expected subset` asserts
  this against the real catalogue (deterministic, no network).
- `--cli source <id|name> <operation> [--repo DIR] [--url …] [--query …]`
  → legacy repo-backed operation runner used by `scripts/test-eporner.py`.
  Not a registry command; handled before the registry lookup.
- `--cli help`, `--cli version` → no runtime boot.

Commands that need the database still boot `CliRuntime.boot()` and open Isar.
`WATCHTOWER_EXTENSIONS_DIR` overrides the default `watchtower-extensions` path.

## Cloudflare bypass contract

The bypass WebView must open the exact URL that failed, never the site root:
the root usually loads with no challenge, so the panel would look already
solved while the extension stays broken. Extensions therefore embed the
failing URL in the error message (`https?://\S+` as the last token).
`extensionFailedUrl()` / `extensionErrorTitle()` /
`extensionRequestFailureMessage()` in
`lib/modules/watch/home/extension_home_empty_state.dart` extract it and pick a
specific heading (HTTP code, Cloudflare block, connection error). The old
catch-all "Impossible de charger le contenu" must not come back.

Covered by `test/extension_home_empty_state_test.dart`,
`test/cloudflare_detection_test.dart`, `test/cloudflare_challenge_url_test.dart`.

## Local verification (mirrors CI)

Flutter 3.47.2. Useful commands:

```
dart format --output=none --set-exit-if-changed lib/cli
flutter analyze --no-pub lib/cli
flutter test test/watchtower_cli_arguments_test.dart
flutter test test/download_queue_grouping_test.dart test/image_download_response_test.dart
```

Note: in `flutter test`, `flutter_tester` has no bundled Rust/QuickJS symbols,
so `doctor --json` reports `quickJs.available: false` and exits 1 locally. That
is expected; the release Linux bundle links the real engine and passes in CI.

## CI triggers

`Build Release APK` (`build-release.yml`) and
`Watchtower CLI and download contract tests` (`test-cli-contract.yml`) both run
on every push to `main`. Their `paths` filters must list every source a job
actually exercises, otherwise a fix can land without the job that covers it
re-running — the failing check then stays red on the fixed commit. The contract
suite runs `extension_home_empty_state_test.dart`, which drives the Cloudflare
bypass panel, so `lib/modules/anti_bot/**` and `lib/services/anti_bot/**` are
part of its filter.

`gh workflow run` returns HTTP 403 with the integration token (workflow-dispatch
needs a scope it lacks). To re-trigger a workflow, push a commit that touches a
path in its filter.

## Build notifications

Every build workflow posts to ntfy with `$COMMIT_MESSAGE`, injected from
`github.event.head_commit.message` through a step-level `env:` block. Do not put
that expression directly in `run:`: a commit subject containing an apostrophe
(e.g. `Détails de l'erreur`) closes the shell quoting and the step fails with
`unexpected EOF while looking for matching '` (exit 2) after an otherwise
successful, signed build. Only the notification step fails in that case — check
the failing step name before treating a red `Build Release APK` as a code bug.

## Branding invariants (do not regress)
- The only real logo is the geometric **eye** (`assets/app_icons/icon.png`,
  transparent background). The old **tower** artwork was removed in `03b2750c`;
  no tower silhouette may be reintroduced.
- Launcher icons on every platform are regenerated from that single file, so the
  correct place to change the logo is `assets/app_icons/icon.png` only.
- Splash logos (`assets/app_icons/splash_logo.png` and
  `android/app/src/main/res/drawable-nodpi/splash_logo.png`) must keep a
  **transparent** background: the native launch surface supplies the colour.
- Android 12+ must ship an **adaptive** launcher icon. Without
  `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` the system
  wraps the transparent legacy `launcher_icon.png` in its default **white**
  shape — the white box seen at launch. The adaptive background is the dark
  `@color/ic_launcher_background` (`values/ic_launcher_background.xml`), the
  foreground is the re-padded eye from `scripts/generate_adaptive_icon.py`.
  The Android 12 splash icon background must also stay dark
  (`@color/splash_background`), never `@android:color/transparent`.
- The Windows NSIS installer banner/header in
  `.github/workflows/build-windows-x64.yml` must draw the eye, not a hand-coded
  tower. It renders `assets/app_icons/icon.png` directly.

## Local indexer / normalizer invariants
- `sanitizePersistedUrl` (`lib/services/http/persisted_request_metadata.dart`)
  must rebuild the URI instead of `Uri.replace`. `replace` always emits the
  separators of the components it is given, so passing an empty query/fragment
  appends `?#` and corrupts every cached page URL. Absent components must stay
  absent. Covered by `test/persisted_request_metadata_test.dart` and
  `test/page_url_cache_test.dart`.
- `DiscoveryStage._isInExcludedDir` must only inspect path segments **below**
  the scan root. Looking at ancestors made a library living under a folder
  named `tmp`/`cache`/`temp` scan to nothing.
- The Smart Library discovery test writes real file bytes: `File.create` yields
  0 bytes, which `minimumFileSize` (1) rejects.
- The name normalizer reads volume/chapter from parent folders for manga
  (`/Manga/Berserk/Vol. 2/page.cbz`) and ignores release-group tokens glued by
  a dash (`...x265-GROUP`). Covered by `test/smart_library_normalizer_test.dart`.

## Known non-blocking analyzer noise
`flutter analyze` reports ~1.6k issues but **0 errors**. The
`deprecated_member_use` set has been driven to **0** (Radio→`RadioGroup`,
`SharePlus.instance.share(ShareParams(...))`, `value`→`initialValue`,
`Matrix4.scale/translate`→`scaleByDouble/translateByDouble`,
`ScreenBrightness().application`/`setApplicationScreenBrightness`,
`SizeTransition.axisAlignment`→`alignment`,
`SpeechListenOptions.listenFor`, `HomeWidget.registerInteractivityCallback`,
`onReorder`→`onReorderItem`, `cacheExtent`→`scrollCacheExtent`). Remaining
issues are `use_build_context_synchronously` and similar infos. Do not treat
the count as a failure.

When migrating `DropdownButtonFormField.value`→`initialValue`, add a
`key: ValueKey(currentValue)` so the field still reflects a value changed
outside the field (its internal `FormField` state no longer re-syncs on
`didUpdateWidget`).

Two web-only stubs (`lib/modules/watch/detail/watch_player_stub.dart`,
`lib/modules/anime/anime_player_view_web.dart`) still `import 'dart:html'`;
they are not compiled for the mobile target, so the deprecation is suppressed
with `// ignore_for_file: … deprecated_member_use` rather than risking a
`package:web` rewrite.

## Component gallery
The developer gallery (`lib/modules/dev/component_gallery_screen.dart`) and the
production home screens render the *same* widgets. The contract:

- `GalleryComponentCatalog.descriptors` is the single source of truth for the
  199 components. Every descriptor resolves through
  `LayoutComponentRegistry.resolve(id)`, which carries a `galleryFamily`.
  `ExtensionLayoutPreview` (used by `WatchExtensionHomeScreen`, and therefore by
  `MangaHomeScreen`) delegates to `GalleryComponentRenderer.section` whenever
  `definition.galleryFamily != null`, so a card fixed once is fixed everywhere.
- `GalleryComponentPalette.common` must expose **every** key the renderer reads
  via `ctx.text/number/decimal/flag`. `test/gallery_component_renderer_test.dart`
  enforces this; add the parameter to the palette when a card starts reading a
  new key, otherwise layout.json cannot configure it.
- Duplicate visual variants (e.g. `season-detail`, `home-genre-tile`,
  `home-popular-rail`, `home-read-rail`, `landscape-discovery`, `top-movies`,
  `must-watch`) stay resolvable for old layouts but are `selectable: false`, so
  they leave the picker while old layout JSON keeps working.
- `tool/gallery_preview_generator.dart` renders all 199 components to
  `build/gallery_previews/<id>.png` (cropped to content) and prints
  `OVERFLOW_ID <id>` for any `RenderFlex` overflow. It is the fastest way to
  catch a clipped/truncated card: run
  `flutter test tool/gallery_preview_generator.dart` and expect `overflows: 0`.
- Cards must size themselves from their content. `MediaLandscapeRail` derives its
  height from the 16:9 card plus reserved text space; `MangaChapterNextCard`
  wraps its subtitle in `Flexible` with `maxLines: 1` + ellipsis. Do not
  reintroduce a fixed `height:` on a rail whose text can wrap.
- `AnimeDiscoveryScreen` (`/AnimeLibrary`, the 2nd Hub tab) is the reference
  consumer: genres and studios render through `app-genre-tile`, "Top 10 Anime"
  through `top-anime`, movie rails through `landscape`. Reach for an existing
  catalog id before adding a bespoke section — the point of the gallery is that
  a card fixed once is fixed everywhere.
- `ContentItem.imageUrl` is the wide artwork used by single-visual cards
  (`app-genre-tile`, `genre`); `ContentItem.fromAnilist` fills it from
  `AnilistMedia.bestBackdrop` (banner, then portrait cover).
- Every "see all" and genre/studio tile opens the shared catalogue page
  (`TmdbMoviesListScreen.anilist` via `/anilistBrowse`). Keep a single
  implementation: pass an `AnilistBrowseFilter` (`sort`, `studioId`, `genre`,
  `format`, `country`) rather than adding a new browse screen.
- `enrichCategoryImages` (`category_row.dart`) is the genre-artwork selector:
  exact genre matches are claimed first, then remaining tiles get unused
  artwork, and no two tiles share a picture. Keep it pure so it stays unit
  testable.

## Formatting caveat
`dart format lib/cli` is clean (that is the CI-enforced path). Running
`dart format lib/` with the local SDK rewrites ~740 files because the tree was
formatted with a different page width; **do not** mass-reformat `lib/`, it
produces a huge diff unrelated to any fix. Format only the files you touch.

## Video player startup invariants (do not regress)
The inline player (`lib/modules/watch/detail/watch_player_io.dart`) used to
stall for seconds before the first frame while the extension itself resolved in
~1 s. Three causes, all fixed - do not reintroduce them:

- **`duration` is not the "ready" signal.** `mpv` only learns the duration of an
  HLS stream after demuxing the whole playlist, so waiting on
  `_player.stream.duration` held the loading overlay well past the point where
  the picture was already decodable. Playback is now declared ready on the first
  non-zero `_player.stream.position` (fallbacks: non-zero `duration` for
  audio-only, non-null `width`). Those listeners are subscribed *after*
  `open()`, inside `loadSubs()`.
- **libmpv's defaults are for local files.**
  `_tuneStartupForNetworkStreams()` sets `demuxer-lavf-analyzeduration=1`
  (libavformat otherwise spends up to 5 s in `avformat_find_stream_info()`) and
  `cache-on-disk=no` (media_kit's default writes the packet cache to disk). It
  runs once, before the first `open()`. Avoid also lowering `probesize`
  (`demuxer-lavf-probesize`): it governs codec detection, and the
  `analyzeduration` cap already bounds probe time, so shrinking the byte window
  would only risk misdetecting on slower sources.
- **Never skip `avformat_find_stream_info()` on an HLS/TS source.**
  `demuxer-lavf-probe-info=nostreams` was briefly forced here (mirroring mpv's
  `low-latency` profile) and broke *every* HLS attempt on xnxx: without the
  probe mpv cannot read the H.264 extradata, decoder init fails with
  "Could not open codec" after ~4.6 s, and the player falls back to the MP4
  source - a 4.6 s stall the user sees as "the app is slow". The option is only
  safe where the container already carries full codec parameters, which is why
  mpv ships it inside `[low-latency]` (never as a default) and never alone.
  Keep `probe-info` at its `auto` default: mpv's `format_hack.skipinfo` already
  skips the probe for mp4/matroska and only the probe call can set `skipinfo`.
- **`demuxer-lavf-analyzeduration=1`** bounds the probe without removing it.
  Going lower (`0.1`) removes the extradata window the HLS decoder needs.
- **The Dart HTTP probe must never gate playback.** `_probeStreamStatus()` only
  logs the CDN status; it is started with `unawaited()`. Awaiting it delayed
  `open()` by up to its 5 s response timeout.
- **Log the options that were actually applied.** `_tuneStartupForNetworkStreams()`
  reads each option back with `getProperty` and logs the map. `setProperty`
  silently ignores an unknown name/type, so without the read-back a rejected
  tuning is indistinguishable from a tuning that had no effect.

`switchQuality()` must also call `_tuneStartupForNetworkStreams()` before its
`open()`. Only the code paths are covered by inspection: there is no Flutter SDK
in the agent environment, so this file is not compiled or unit-tested locally.

`_player.open()` is awaited through a `.timeout(8 s)` that completes the
attempt with `false`. The 10 s watchdog only starts counting once `open()`
returns, so an unbounded await on a stalled CDN socket would freeze the whole
quality loop instead of falling back.

### HLS rendition selection (do not regress)
Neither backend adapts on its own: FFmpeg's HLS demuxer reads `hls-bitrate`
**once** at `open()` and never switches, and libmpv exposes no client-side ABR.
Its `max` default is therefore a static "always take the heaviest rendition"
policy — the browser equivalent (hls.js) instead starts on a level that fits
the measured throughput. On a connection slower than the top rendition this is
what makes the app buffer where the site plays, and no amount of buffering
tuning fixes it.

- `lib/services/hls_adaptive_quality.dart` measures throughput on a **real
  media segment** (a playlist is ~1 KB and only times round-trip latency) and
  derives the `hls-bitrate` value to set before `open()`. Bounded end to end
  (~400 ms on a normal link, 1.5 s worst case per request); any failure returns
  `null` and leaves the default, so it can never make playback worse.
- A rendition is only chosen when the master advertises a plausible
  `BANDWIDTH`; below the lightest one it forces that lightest rendition rather
  than letting mpv pick the heaviest.
- `_applyAdaptiveQuality()` runs on the **first** attempt only: a retry exists
  because that rendition already failed, so re-probing would just add latency
  to the fallback. `switchQuality()` must re-run it, since `hls-bitrate` is
  read at `open()` time.
- Do **not** set `cache-pause-initial=yes`: it waits for the read-ahead to fill
  before the first frame, which is the startup delay this player removes.
- The rendition list shown in the picker comes from
  `lib/services/hls_variant_resolver.dart` (`expandHlsVariants`), which parses
  the master the extension returned as a single opaque "Auto" entry. Entries
  are ordered by ascending bitrate so they double as step-down fallbacks.
  Extensions must not list renditions themselves.

## Extension call scheduling invariants (do not regress)
One source runs on **one** non-reentrant extension runtime
(`ExtensionServiceRegistry._queues`, keyed by source). Every call for that
source is therefore serialized, and a slow decorative call delays the call that
starts the video.

- `ExtensionServiceRegistry.priorityFor` buckets calls: `0` playback
  (`getVideoList`/`getHeaders`/`getPageList`), `2` decorative tabs
  (`getRecommendations`/`getComments`/`getSuggestions`), `1` everything else.
  Dequeue order is lowest bucket first, FIFO within a bucket.
  `test/extension_call_priority_test.dart` pins this ordering; adding a tier
  means extending `_ExtensionSourceQueue._buckets` too.
- `watch_detail_view.dart` builds both tabs eagerly via `TabBarView`, so
  `getRecommendations` (Pour vous) and `getComments` (Commentaires, via
  `_CommentsSection.initState`) used to fire during the same frame as the
  post-frame callback that calls `_player.load()`. Both are now gated on
  `_player.loadedChapterId != null && !_player.hasVideoUrl && !_player.loadFailed`
  and un-gated by the tab listener (`_recommendationsRequested` /
  `_commentsRequested`) so a user can still open them while playback resolves.
  Keep those latches when touching the tabs, otherwise the tabs spin forever.
- `getRecommendations`/`getComments` must stay `serviceType:`-tagged all the way
  through `isolate_service.dart` (both the isolate worker and
  `_runOnMainThread`); an untagged call lands in bucket 1 and can again block
  playback.
- The queued action + completer must be owned by the `_ExtensionCall`, not by
  the `pump()` closure in `ExtensionServiceRegistry.run`. Because each
  invocation creates its own `pump()` but they all drain the *shared* queue, a
  `pump()` that closed over the caller's `action` ran the wrong extension
  method for a call that had queued behind another — `getVideoList`/`getRecommendations`
  returned the pending `getDetail` `MManga` ("type 'MManga' is not a subtype of
  type 'List<Video>'") and the player loaded forever. `test/extension_queue_dispatch_test.dart`
  pins this.
- `isolate_service.dart`'s response listener must never `complete` via an
  unguarded `data as T`: a wrong-typed payload threw inside the listener and
  left the caller's future uncompleted (infinite spinner). Cast inside a `try`
  and `completeError` on mismatch.


## Item naming conventions (do not regress)
`Manga` is the **shared** Isar model for every medium — manga, watch, novel,
music, game, plugin (`ItemType`). `MangaReaderDetail` (`/manga-reader/detail`)
therefore renders both `MangaDetailsView` and `WatchDetailView`. Legacy names
must not leak into watch code paths or logs:

- `ItemType.anime` is the **watch** type (`ItemTypeLocalization.localized` maps
  it to `l10n.watch`). Prefer `isWatch`/`LogTag.watch` over "anime" when the
  intent is "a watchable video".
- A watch entry must never log under `LogTag.manga`. `manga_detail_main.dart`
  reads `isar.mangas.getSync(id)?.itemType` and picks `LogTag.watch` + the
  `watchId=` label for `ItemType.anime`, `LogTag.manga` + `mangaId=` otherwise.
- `AppLogger.log` already prints the `tag:` as a bracketed prefix. Do not repeat
  it in the message: `tag: LogTag.watch` plus a `'[WATCH] …'` message renders as
  `[WATCH] [WATCH] …`. Same for every other tag.
- `MManga`/`MPages` are the extension-boundary DTOs (`lib/eval/model/`); `Manga`
  is the persisted model. Keep that split — do not rename `MManga` to `Manga`.


## Rust dependency invariants (do not regress)
- The Android/iOS/Linux/Windows native builds compile `rust/Cargo.toml`. It now
  pins `zip = "9.0.3"`, the **only** zip release still published: every earlier
  version (3.0.0 through 8.6.0) was yanked from crates.io, so a loose `8.x`/`3.x`
  requirement fails dependency resolution before any code compiles
  (`failed to select a version for the requirement 'zip = "^8.5.0"'`).
- `epub 2.1.5` pins `zip = "^3.0.0"`, which is yanked, so the registry copy of
  `epub` is unresolvable too. `rust/vendor/epub` is the same 2.1.5 source with
  only its zip call sites adapted to zip 9, wired in via `[patch.crates-io]`.
  Delete the patch and the vendor directory only once epub-rs publishes a
  zip-9-compatible release.
- `rust/Cargo.lock` is committed so the resolved graph (including `zip 9.0.3`)
  cannot silently drift onto a yanked or incompatible version. Regenerate with
  `cargo generate-lockfile` in `rust/` when dependencies change.
- Two zip 9 API breaks matter here: `ZipArchive::file_names()` now yields
  `ZipResult<Cow<str>>` (was `&str`), and `ZipFile::name()` returns
  `ZipResult<Cow<str>>` (was `&str`). Both call sites are adapted.
