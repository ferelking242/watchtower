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

A challenge is only claimed with real evidence. `challenge-platform` and
`turnstile` are in `kWeakChallengeMarkers`: Cloudflare injects that script into
healthy pages and sites embed the widget in their own forms, so they escalate
to a challenge only when the response itself is a refusal (403/429/5xx) or
carries `cf-mitigated: challenge`. Error strings are matched on Cloudflare
phrases (`cloudflare challenge`…), never on the bare word “challenge”.

A challenge is a verdict on the *client*, not on the user. Cloudflare answers
`missav.ws` with `403 + cf-mitigated: challenge` to the extension's native
client while the same URL loads instantly in a WebView, which runs the managed
challenge's JavaScript. There is nothing to click in that case, so the panel
cannot fix it.

Mihon and Aidoku only solve the challenge in a WebView, copy `cf_clearance` into
their HTTP client's cookie jar with a matching User-Agent, and retry natively
(OkHttp/URLSession). Aidoku issue #1034 reports exactly the case we are in:
same cookies, same UA, the native client still refused. Aidoku's proposal there
— perform the blocked request *inside* the browser — is what we implement,
because the native client here is Rust/rustls, whose fingerprint is no
browser's.

The method is split in three files:

* `lib/services/anti_bot/browser_capture.dart` — the engine, the platform
  matrix (`browserCaptureSupportFor`) and one **browser session per host**:
  `headless` on Android, iOS, macOS, Windows and Linux (any OS with a
  registered `flutter_inappwebview` engine), `proxy` on Flutter web (the Worker
  proxy already in `WebProxyInterceptor`, since a page cannot read another
  origin's HTML), `none` otherwise — then the visible panel plus the user
  remain the only path. The session navigates once, waits for the managed
  challenge to clear, then runs `fetch(url, {credentials: 'include'})` **inside
  the accepted page** and returns `{status, body}`. Harvesting `cf_clearance`
  and retrying natively is *not* enough here: Rust/rustls is refused with a
  valid cookie, so the request must stay inside the engine.
* `lib/services/anti_bot/browser_bridge.dart` — the isolate hop. Extension
  code runs in a worker isolate (`isolate_service.dart`), where no platform
  view and no plugin registry exist; a capture attempted there fails instantly
  and silently. The worker sends `{request, reply: SendPort}` to the root
  isolate, which owns the engine and answers with the body. `isolate_service`
  starts the server, passes its port to every worker (including replacements)
  and closes the sessions on `stop()`.
* `lib/services/anti_bot/browser_fetch.dart` — the coordinator: in-flight host
  tracking, the quiet window that keeps notifications silent while a host is
  served, and the choice between the local engine (root isolate) and the
  bridge (worker).

`JsHttpClient` returns the browser's body and status to the extension, so
source code never sees the block — HTML pages and JSON endpoints alike (the old
HTML-only restriction is gone: the body is fetched by the page, not rendered
in a viewer). When the browser cannot obtain the page either (interactive
Turnstile, WAF block, no engine), only then is the user interrupted with the
panel.

Consequence that must not regress: never trust `BrowserCapture.isAvailable`
inside an extension worker. It reads the plugin registry of the current
isolate, which is empty there; use `BrowserFetchService.isSupported`, which
routes through the bridge.

Consequences that must not regress:

* The HTTP client always sends a User-Agent, and it is the one stored for the
extension session. `cf_clearance` is bound to that UA; an empty UA gets a 403
before any challenge, and a UA that differs from the WebView invalidates the
cookie.
* The notification names the blocked *extension* (never a request count), and
its action opens that extension's page, where the panel is inline. There is no
full-screen challenge route any more.
* A headless capture that fails is the only thing that alerts the user;
challenges cleared silently must stay silent.

Covered by `test/extension_home_empty_state_test.dart`,
`test/cloudflare_detection_test.dart`, `test/cloudflare_challenge_url_test.dart`,
`test/bypass_notification_content_test.dart`.

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

## Overlay menus and filter panels (single component)
`lib/utils/adaptive_overlay_menu.dart` is the one glass popup used everywhere;
do not reintroduce a bespoke popup or a filter bottom sheet.

- `AdaptiveOverlayMenuButton` anchors a floating glass panel (`trigger` +
  `contentBuilder`); the Library filter is the reference use.
- `AdaptiveOverlayMenu<T>` renders a `PopupMenuItem` list in that same panel for
  three-dots menus; `AdaptiveOverlayItem` / `AdaptiveOverlaySection` /
  `AdaptiveOverlayDivider` are the in-panel row primitives.
- The caret is drawn by `_CaretPainter`, which also strokes the two slanted
  edges (`edgeColor`). The panel fill is translucent, so without that stroke the
  caret is invisible over a solid app bar (Browse). Keep it.
- The panel is inserted into the Navigator overlay, which has no `Material`
  ancestor: the content is wrapped in `MaterialType.transparency` so the
  `InkWell` rows build. Do not remove that wrapper.
- `lib/modules/media/overlay_filter_menu.dart` holds `ExtensionFilterOverlay`
  (dynamic `getFilterList()` filters) and `CatalogFilterOverlay` (catalogue
  type/year/rating/genre/sort/layout). Both drill down in place, like
  `LibraryFilterSortMenu`. The catalogue filter *state* stays in
  `catalog_filter_sheet.dart`; only the UI moved.
- Every search surface shares `SharedSearchHeader` (chevron back + mic inside
  the field); the filter and three-dots live outside the field, composed by the
  screen. `handleSearchBack` clears the query before leaving.

## Marketplace taxonomy and shelves (do not regress)
The Marketplace discovery pages are built from catalogue **tags**, never from
the extension's name, domain or brand. `lib/models/catalog_taxonomy.dart`
mirrors `tools/catalog_taxonomy.mjs` in `watchtower-extensions`; keep the two
vocabularies in sync.

- `CatalogTaxonomyTags` holds the canonical `contentTags` / `genreTags` /
  `languageTags` / `curationTags`. `filterKnown` drops anything not in the
  vocabulary, so a tag the app does not know is ignored rather than shelved.
- `effectiveTags` prefers the `tags` list an index publishes and falls back to
  facts the entry already has (its `itemType`, its `lang`/`langs`) for an older
  index. Nothing is ever inferred from the name — that is the substring
  matching this system replaces.
- `CatalogShelves` declares every shelf as data (`CatalogShelfSpec`).
  `CatalogShelfBuilder` filters and orders them once, cached in the screen
  (`_shelfCache`, keyed on the entry list identity) so a rebuild does not
  re-scan the catalogue. Do not filter shelves inline in a `build`.
- An adult shelf is the only place adult entries may appear, and only after the
  user opts in: `CatalogShelfSpec.matches` requires **both** `includeNsfw` (the
  shelf asks for it) and `allowNsfw` (the user opted in). The `adult` shelves
  replace the old hard-coded "Midnight World"/"Midnight Library" rows.
- Cards are a fixed geometry (`CatalogCardMetrics`): two rows, two columns per
  shelf, horizontal paging, card width capped so a tablet widens the number of
  visible columns instead of stretching the tiles. Do not reintroduce the
  full-width banner or the long vertical list for discovery.
- `popular`/`trending` are **never** declared: the catalogue carries no usage
  statistic, so the "popular" shelves use a documented deterministic order
  (featured first, then most recently added). Never invent a popularity number.
- New visible strings go through `tool/add_catalog_l10n.py` (idempotent) then
  `flutter gen-l10n`; the generated files under `lib/l10n/generated/` are
  tracked, so commit them with the ARB change.
- A card icon is always `CatalogIcon` (`catalog_widgets.dart`): a network logo
  with an initials fallback. The catalogue cards and the music plugin cards
  share it, so a plugin logo and a source logo can never render differently.
  Do not add a second icon widget.
- The plugin list is the hardcoded `_kKnownRepos` in
  `lib/modules/music/provider/metadata_plugin/core/repositories.dart`. Each
  entry must carry a distinct `iconUrl` under
  `watchtower-extensions/main/assets/plugins/`; two plugins sharing a logo is
  the bug that made Deezer display the Spotify mark, and
  `test/plugin_repository_icon_test.dart` pins the invariant.

## WebView browser chrome and user intent (do not regress)
`lib/modules/webview/webview.dart` has no app bar and no footer toolbar. All
chrome lives in `_BrowserDock`, a pill overlaid on the page (tabs left, "+"
centre, "⋮" right). It is `Positioned` inside the body `Stack`, so it reserves
no layout space; dragging the pill sideways folds it into `_BrowserDockState`'s
collapsed handle against the right edge. Do not reintroduce a header or a
`bottomNavigationBar`.

Video interception is gated on a real user gesture, because sites autoplay and
preload media during a swipe. `UserIntentGate` (`lib/services/user_intent_gate.dart`)
holds a 15 s window; it is marked by the page's `userIntent` JS handler and by
`_handleInterceptedVideo`. Every interception path checks it first -
`shouldOverrideUrlLoading` (`_hasUserIntent`), Android `shouldInterceptRequest`
(`_hasUserIntent`), and the XHR/fetch/hls.js/shaka/video.js hooks in
`_kVideoInterceptJs` (`hasUserIntent()`). Removing a guard brings back the bug
where browsing a listing launched the player.

`hookVideo` listens on `play` only. `loadedmetadata`/`canplay` fired for every
teaser tile the user swiped past. `looksLikeTeaser` skips muted+looping clips,
clips under 20 s, and elements under 6% of the viewport.

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
- **`hls-bitrate=max` is the dominant startup cost, not the probe.**
  Measured with **mpv itself** (the app's runtime) on a live xnxx master
  (360p/480p/1080p, 10 s segments), median time to first frame over 7 runs:

  | opening | probe-info | hls-bitrate | first frame |
  |---|---|---|---|
  | master | default | max | 5793 ms |
  | master | nostreams | max | 5793 ms |
  | master | default | 815104 | 1582 ms |
  | master | nostreams | 815104 | 1512 ms |
  | 480p playlist | nostreams | n/a | 919 ms |

  `max` makes the demuxer start on the 1080p rendition and buffer it before the
  picture appears. So `_applyAdaptiveQuality()` no longer only sets a numeric
  `hls-bitrate`: it now returns the **variant playlist** it resolved and the
  player opens that directly (`openUrl` in `load()`), which is both faster than
  the master and immune to `max`. `nostreams` is a smaller real win (~70 ms).
- **Do not measure libmpv options with the ffmpeg CLI.** An earlier note here
  claimed the probe cost 10.7 s on a throttled link; that number came from an
  `ffmpeg` CLI run, and the CLI cannot express `demuxer-lavf-probe-info` at all
  (there is no `-probe_info` option — it fails with `Unrecognized option`). Use
  `tools/mpv_startup_bench.mjs` in the extensions repo, which drives real mpv.
  The historic xnxx "Could not open codec" failure came from
  `demuxer-lavf-analyzeduration=0.1`, not from `nostreams`.
- **Skip `avformat_find_stream_info()` on HLS, with a retry as the safety
  net.** `demuxer-lavf-probe-info=nostreams` is forced in
  `_tuneStartupForNetworkStreams()`, which stops ffmpeg fetching the head of
  every rendition of a multi-rendition master in parallel. When a container
  really does need the probe, `load()` calls `_restoreFullProbe()` to set
  `probe-info=auto` and re-opens once. That recovery is gated on a codec error
  **or a silent watchdog**: an attempt that produced no frame and no error
  message is exactly what an unprobeable container looks like, and gating on
  the error alone left the recovery unreachable (the watchdog path completes
  without ever setting `_lastError`).
- **`demuxer-lavf-analyzeduration=1`**, never `0.1`: `0.1` removes the
  extradata window the HLS decoder needs (reproduced "Could not open codec"
  on a multi-rendition TS stream).
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


## Extension artwork needs the extension's headers (do not regress)
Some extension CDNs are hotlink-protected and the app must send the headers the
extension declares. But do not treat "hotlink protection" as the first
explanation for covers that all show a placeholder — measure first.

Measured on Harimanga (`img-r1.2xstorage.com`, Cloudflare) on 2026-10-26 from a
plain client: `Referer: https://www.harimanga.co.uk/` → `200 image/webp`, and
the same URL **without any header also returned `200`**; 25 parallel requests
did not trigger a `429`. The same `200` held with the app's Android UA, the
extension's desktop UA, and no UA at all. So the "no Referer → 403" story did
not reproduce, and it was not the cause of the all-placeholder bug.

The real cause was on the extension side: it rewrote every cover URL onto a
sharded mirror and `cdn.zinmanga1.com` only carries a slice of the catalogue
(`/thumb/alexandrite-knight.webp` → `200` on `img-r1`, `404` on `cdn`). The site
already emits a working mirror per cover in the card markup, so the extension
must return that URL unchanged (see the extension's `harimanga.js`).

- `ContentImage` is the single consumer of the scope: it reads
  `ExtensionImageHeaders.of(context)` when no explicit `headers` are passed.
  Screens install `ExtensionImageHeaders` at their root with
  `ref.watch(headersProvider(...))`, which is what makes every nested card send
  the headers. A new extension screen that renders covers must install it too,
  or its artwork silently falls back to placeholders.
- A pushed route does **not** inherit the scope. `TmdbMoviesListScreen`, which
  is what every "tout voir" / see-all action opens, installs it itself from
  `widget.extensionSource`. This was the 2026-10-29 Harimanga bug: the home and
  search covers loaded, but every see-all page showed placeholders because its
  log lines read `ref=NONE ua=NONE` while the home ones read
  `ref=www.harimanga.co.uk ua=yes`. Any new screen reached through
  `Navigator.push` must install the scope on its own; the log line's `ref=` /
  `ua=` pair is the fastest way to tell which side of the push you are on.
- Any widget that calls `cachedNetworkImage` directly instead of going through
  `ContentImage` bypasses the scope and must read `ExtensionImageHeaders.of`
  itself (see `_CatalogListRow`, `AppGenreTile`).
- The detail view was never affected: it has always passed the extension
  headers to `cachedNetworkImage` explicitly.
- Debug aid: `custom_extended_image_provider.dart` logs a headers summary and
  the failing status on each cover request (`NET-START`, retry, final failure),
  and `cached_network.dart` logs render failures with `headers=oui|NON`. Use
  those before blaming the CDN.


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

## HLS startup path (do not regress)
- `getVideoList` and the player's ABR probe read the **same** master playlist.
  `HlsPlaylistCache` (`lib/services/hls_variant_resolver.dart`) is what keeps
  that to one request: `expandHlsVariants` stores the body, `HlsAdaptiveProbe`
  reuses it. The cache is TTL-bounded (30 s) and size-bounded (16 entries), so
  it can only ever save a request, never serve a stale rendition list.
- The ABR probe runs **before** the first `open()`, so its whole cost is
  startup latency. It is bounded twice: `requestTimeout` per request and
  `totalBudget` (1.8 s) for the sequence. Per-request timeouts alone do not
  bound it — a CDN answering each request just under the limit would stack
  them. A timed-out probe must return `null` (mpv keeps `hls-bitrate=max`),
  never throw.
- Never bound a `Future<String>` with `.timeout(onTimeout: () => null)`: that
  throws `type '() => Null' is not a subtype of type
  '(() => FutureOr<String>)?'` because `FutureOr<String>` is not nullable. It
  only *looks* safe when the callee is declared `Future<String?>`; any
  non-nullable stub (a test double, a future caller) turns the call into a
  silent no-op. Wrap in a nullable-returning helper that catches the timeout
  instead (see `_fetchTextOrNull` / `_fetchRangeOrNull`).


## Settings navigation (Mihon/Aniyomi parity)
- Every settings subpage uses `SettingsSubpageScaffold`
  (`lib/modules/more/settings/widgets/settings_subpage_scaffold.dart`): the
  title collapses into the app bar header on scroll and the page carries its own
  back arrow and search action. Icons come from the `Broken` icon font
  (`lib/core/icon_fonts/broken_icons.dart`), never `Icons.*` — mixing the two is
  what produced the "broken icons" reports.
- Subpages animate with the Bare Browser transition
  (`settings_subpage_route.dart`, `bareSettingsTransitions`): the page slides in
  from the right while the one behind shifts left and dims. New settings routes
  must be added to `bareSettingsRoutes`, otherwise they fall back to the default
  page transition and the header no longer behaves like the rest.
- Search is global: `lib/modules/more/settings/widgets/settings_search_index.dart`
  lists every option with its `page` and `route`. A new setting that is not in
  that index is invisible to search, so add an entry when you add a tile.

## Dock / rail highlight
- `_FloatingDock` selects by route string, but `_ClassicDock` (bottom
  `NavigationBar`) and the tablet `NavigationRail` select by **index**. Every
  library route must therefore map to the Hub entry explicitly
  (`main_screen.dart`: `libLocationRegex` → `_enableLibSwitch`), or the previous
  tab stays highlighted when a library page opens.

## Volume-key page navigation
- The native bridge is `com.watchtower.app.volume_keys` (Android
  `MainActivity.dispatchKeyEvent`, iOS `AppDelegate`), surfaced as
  `VolumeKeyChannel` (`lib/modules/manga/reader/services/volume_key_channel.dart`).
  The reader subscribes in `_initVolumeButtonNavigation` and unsubscribes on
  dispose. Toggling the preference inside the reader must take effect live —
  `reader_view.dart` listens to `volumeButtonNavigationStateProvider` in `build`
  for exactly that reason; do not move the subscription back to `initState` only.

## Library automatic updates
- `LibraryAutoUpdater` (`lib/services/library_auto_updater.dart`) is started and
  stopped by `MainScreen` (start in `_initializeTimers`, stop in `dispose`). The
  due-date maths lives in the pure `isLibraryUpdateDue` helper so it can be
  unit-tested without a Hive box; keep it pure.
- Swipe actions run through `LibrarySwipeWrapper` +
  `runLibrarySwipeAction` (`lib/modules/library/services/library_swipe_actions.dart`),
  wired into both the grid and list library views. The swipe never dismisses the
  card; it fires the action and snaps back.

## Marketplace catalogue loading
- The Marketplace fetches its catalogues from
  `raw.githubusercontent.com/ferelking242/watchtower-extensions/main/index/*.json`
  in `_loadAll` (`marketplace_screen.dart`). The list is the single
  `kMarketplaceIndexPaths` const (`manga`, `watch`, `novel`, `music`, `game`,
  `subtitles`); the loader and the jsDelivr purge both read it, because they
  used to be two hand-kept copies and `index/subtitles.json` was missing from
  both, which is why its 5 sources (itemType 7) never reached the app. Add a
  catalogue in one place only. `index/plugins.json` is a different shape (an
  object, not an array) and is read by the CLI only.
- Route tabs and type labels on the raw `itemType`, not on `ItemType`: subtitle
  providers publish `7`, which the enum cannot represent, so `contentType`
  clamps it and the entry would land under Games. `contentType` is only for the
  Isar install path; a legacy entry defaults `itemType` to `contentType.index`,
  so the mapping is unchanged for it.
- `parseMarketplaceIndex` (`@visibleForTesting`) is the single parse entry
  point. It de-duplicates by `id`, **not** by name: two extensions may share a
  display name (`SpankBang` ships `spankbang.js` and `spankbang_new.js`, plus
  `AnimeSongLyrics`, `AniPool`, `DonghuaStream`, `YouTube Music`). A name-keyed
  rule silently dropped one of each pair from the whole Marketplace. The
  extensions repo's `tools/validate-extensions.mjs` fails on a repeated id and
  warns on a reused name, so keep the two in step.
- Tags come from the index `tags` list (`effectiveTags`, `catalog_entry.dart`).
  Never infer a category from the extension name or domain.
