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

Covers and reader pages follow the same rule. A host can serve its HTML to the
browser session while refusing every **image** to the native client with the
same `403 + cf-mitigated: challenge` — `manga-scantrad.io` does exactly that,
whatever the headers (no header, UA alone, UA + Referer + Sec-Fetch all
tested). The fix is not a header: `CustomExtendedNetworkImageProvider` asks
`BrowserFetchService` for the bytes when the native response carries a
Cloudflare marker (`_looksLikeCloudflareRefusal`, so a plain 404 keeps the fast
placeholder path). That request sets `binary: true`, which makes the in-page
script read `arrayBuffer()` and base64 it — `response.text()` would corrupt a
WebP/JPEG. Two details are load-bearing: the session navigates to `pageUrl`
(the image's origin, or the reader page) because a WebView opened straight on
an image never clears the challenge, and the base64 payload is written to a
**sibling global** so the poll loop re-reads a small status object instead of
re-serializing the whole image on every tick.

The navigation target is chosen by **host**, not by the declared page. When the
cover lives on a CDN host distinct from the site (`img.1porn.tv` covers while
the extension declares a `www.1porn.tv` Referer), the in-page `fetch()` is
cross-origin and the CDN sends no `Access-Control-Allow-Origin`, so the browser
rejects the served bytes (`TypeError: Failed to fetch`) even though the image
was returned. The request must be issued from the image's own origin, which is
same-origin with itself; `_loadCoverViaBrowser` therefore keeps the declared
page only when `declaredHost == imageHost`, and otherwise navigates to the
image URL itself.

Navigating to the *image URL* (not the host root) is the load-bearing part.
Some image CDNs answer their root with a hard error page — `https://img.1porn.tv/`
returns `403 Forbidden` + `nginx` as `text/html` — and such a root can also sit
behind a fresh managed challenge, so a session parked there either never becomes
ready or burns the whole solve budget. The image URL is the exact resource: it
loads as an image document (`200`, `content-type: image/jpeg`, title `1.jpg
(744×420)`), so the probe sees `normal`, and a `fetch()` of that same URL is
same-origin and returns the bytes. Verified that a session on one image can
`fetch()` *other* images of the same host (200, ~35–82 KB each), so one session
still serves a whole shelf.

Consequences that must not regress:

* A challenge solved in the hidden session is watched **in the background** and
  the session is **kept** when the solve budget runs out (it is only dropped
  when the page is a human-only block). Tearing the session down on the
  per-request deadline restarted the solve from zero for each of a layout's
  shelves, so a slow source returned `items=0` on every one.
* A source that declares `hasCloudflare` gets its hidden session **pre-warmed**
  when it is opened (`BrowserCapture.prewarm`), so the challenge solves while
  the extension compiles instead of stalling the first shelf.

* The HTTP client always sends a User-Agent, and it is the one stored for the
extension session. `cf_clearance` is bound to that UA; an empty UA gets a 403
before any challenge, and a UA that differs from the WebView invalidates the
cookie.
* The hidden capture session **restores the stored cookies as-is, including
`cf_clearance`** (`MClient.restoreCookiesToWebView`) — and must navigate with
the same User-Agent those cookies were minted under
(`MClient.userAgentForRequests`, i.e. the stored session UA). Cloudflare binds
the clearance to the exact UA that solved the challenge. Deleting the cookie
(`skipCfClearance: true`) was tried and reverted: it forces the session to
re-solve the challenge from scratch, and an offscreen Android WebView does not
manage it — the section comes back empty (`items=0`) while the workers time
out, on a device where the cookie was perfectly valid. Leaving the engine
default UA was also wrong for the same binding reason: a stored clearance
minted under the session UA was replayed under the WebView's own UA, so
Cloudflare re-served the interstitial until the solve deadline and **every**
section returned `items=0` with the workers timing out (`the browser session
could not clear the challenge`). The UA override must stay on the session.
* The notification names the blocked *extension* (never a request count), and
its action opens that extension's page, where the panel is inline. There is no
full-screen challenge route any more.
* A headless capture that fails is the only thing that alerts the user;
challenges cleared silently must stay silent.

### Downloads from a browser-only host

The same verdict applies to **media**, not just to the extension's own fetches.
A source can hand the extension the CDN URL and its headers while Cloudflare
refuses that URL to the app's native client — `surrit.com` (MissAV's HLS host)
does: the same UA and Referer that mpv plays the stream with get a `403` from
`HttpClient`, because the verdict is on the client fingerprint, not the
request. So the HLS path replays the refused request in the browser session
too:

* `M3u8Downloader._getM3u8Body` (`lib/services/download_manager/m3u8/`) falls
  back to `BrowserFetchService.fetch` when the playlist stays non-200 after the
  header retry — without it the download dies at "Failed to get TS list".
* `_segmentViaBrowser` in `lib/services/download_manager/download_isolate_pool.dart`
  does the same for a segment, using `binary: true` so the in-page
  `arrayBuffer()` returns the raw TS bytes. The download workers reach the
  engine through `BrowserBridge.connect`; `_WorkerInit` carries the browser
  server port (NOT the task port, whose listener only knows the handshake).
* Both are best-effort: a failure keeps the native error. Only `403/429/5xx`
  triggers the replay (a `404` will not be fixed by the browser), it is tried
  once per segment, and a host that needed it once is remembered in
  `_browserRequiredHosts` so later segments skip the doomed native attempt.
  `_browserSegmentGate` caps browser-replayed segments at 3 in flight, because
  each payload crosses the bridge as base64.
* The replay defaults `pageUrl` to the media host's own `scheme://host/`. The
  session must land on an HTML page to clear the challenge (a WebView opened
  straight on a playlist or a `.ts` never resolves it — the same rule the image
  path follows), and staying on the media origin keeps the later fetch
  same-origin so the browser does not need CORS to hand the bytes back.
  **MissAV/Surrit is the exception:** use the exact MissAV `Referer` page as
  `pageUrl` for Surrit playlists and segments. Its native client can receive a
  plain 403 without Cloudflare markers, and starting the browser on the media
  URL never creates a usable HTML session. Retrying from the source page keeps
  the browser's origin and Referer aligned with the request that initiated
  playback; keep this exception limited to that source/CDN pair.
* **Surrit needs an uncredentialed, referrer-carrying request.** The MissAV
  page is `missav.ws` and the media is `surrit.com`, so the in-page `fetch()` is
  always cross-origin. Surrit answers `Access-Control-Allow-Origin:
  https://missav.ws` but sends **no `Access-Control-Allow-Credentials`**, so the
  default `credentials: 'include'` makes the browser discard a perfectly good
  `200` as `TypeError: Failed to fetch` — this, not the 403, is what killed
  every download. It also refuses a media request with no missav.ws `Referer`,
  and MissAV serves `Referrer-Policy: same-origin`, which strips that referrer
  from a cross-origin request. The fix is on the request, not the headers:
  `omitCredentials: true` plus an explicit `referrer`/`referrerPolicy:
  'unsafe-url'` for Surrit (`BrowserCaptureRequest.omitCredentials` /
  `.referrer` / `.referrerPolicy`, resolved by `BrowserFetchService.isMissAvMediaUrl`
  and `missAvMediaReferrer`). `Referer`/`Origin` stay in
  `kForbiddenBrowserFetchHeaders`: the engine owns them, and `fetch()`'s
  `referrer` option is the only way to set them.
* A host whose native client was already challenged is remembered per isolate
  (`BrowserFetchService.markNativeChallenged` / `nativeProbeIsPointless`) and
  the next GET on it goes straight to the browser. The verdict is on the client
  fingerprint, not the request, so the native probe could only ever burn a
  round-trip — a dozen home shelves paid it once each.

`sourceId` threads from the download provider through `M3u8Downloader` and
`M3u8DownloadParams` so the session can restore the right cookies.

#### FFmpeg is the transport of last resort for a blocked CDN

The browser replay above fixes a *fetch* refused by Cloudflare, but it cannot
fix a CDN that refuses the app's HTTP client while the *player* streams the very
same URL. Surrit is exactly that: `curl`, `wget` and Python get `200` with the
extension's headers, `dart:io` `HttpClient` gets `403` for every header
combination (the verdict is on the TLS/HTTP fingerprint, not the request), and
the WebView replay also fails — the accepted MissAV page serves
`Content-Security-Policy: connect-src 'self'`, so the in-page `fetch()` is
blocked by the page's own CSP (`TypeError: Failed to fetch`) even though the
player loads the same bytes.

The player works because it is FFmpeg/libavformat, whose TLS/HTTP stack the CDN
accepts. `FfmpegHlsEngine`
(`lib/services/download_manager/engines/ffmpeg_hls_engine.dart`) reuses that
stack: it hands the whole playlist to the bundled FFmpegKit
(`ffmpeg_kit_flutter_new`, the Full+GPL variant, so HTTPS/HLS are compiled in)
with the extension's headers, remuxes to MP4 and writes the file. The download
provider reaches it only after the isolate downloader *and* its browser replay
have failed (`download_provider.dart`, the `anime/HLS→FFmpeg` branch), so a
source FFmpeg can serve costs the fallback a normal download and nothing more.
Generic by construction — no per-source branch — and the caller is where a new
exception belongs, not the engine.

`buildArguments` forwards `Referer`/`User-Agent` through `-referer`/`-user_agent`
and everything else (Origin, Cookie, Authorization, Accept*, Sec-Fetch-*) through
one `-headers` block; it drops the headers the transport owns (`Host`,
`Connection`, `Content-Length`, `Accept-Encoding`) so FFmpeg never sends a
duplicated value. `-rw_timeout` aborts a stalled CDN and the engine targets
`<file>.mp4.part`, promoting it only on a successful exit, so a crash cannot
leave a truncated video in place of the download. Covered by
`test/ffmpeg_hls_engine_test.dart`.

Covered by `test/extension_home_empty_state_test.dart`,
`test/cloudflare_detection_test.dart`, `test/cloudflare_challenge_url_test.dart`,
`test/bypass_notification_content_test.dart`.

## Logging performance budget (do not regress)
Verbose/Extreme modes must never stall the UI isolate. Measured causes of the
"app freezes while it logs" reports, and the guards that now prevent them:

- **`AppLogger.log` filters before it formats.** The flood budget runs first:
  Debug/Info are capped at 400 entries/second, Warning/Error always pass (a
  real failure must never be swallowed), and the discarded count is reported as
  a single `[LOG] N lignes supprimées` line so a truncated log is never silent.
  Do not move `sanitizeLogText`/`StringBuffer` work above that gate.
- **Extension workers only forward what the root will keep.** The root pushes
  `AppLogger.workerFilterSnapshot` to every worker right after the handshake
  (`kWorkerLogFilterKey`, see `GetIsolateService`) and again from
  `_loadSettings()` through `setLogFilterBroadcaster`. A worker therefore drops
  filtered records before sanitising + JSON-encoding + the isolate hop.
- **The session file is written in batches.** `_queueFileWrite` appends to a
  buffer drained every 400 ms or at 48 KB. The old path chained a `Future` per
  entry and ran `parent.create(recursive: true)` + `exists()` on **every** line:
  two syscalls per log line on the UI isolate. The recreate path now runs only
  when a write actually throws (`_reopenLogSink`). `flush()` (log viewer, share,
  dispose) drains the buffer first.
- **The floating overlay coalesces frames.** Lines land in `_incoming` and are
  folded into at most one rebuild per 120 ms; the folded tree is cached in
  `_view` and only recomputed when `_viewDirty` is set (new lines, filter,
  search, fold, clear). RegExp patterns are `static final` — they used to be
  compiled **per row, per rebuild** (two per row over 250 rows) — every
  `GoogleFonts.jetBrainsMono` result is cached per colour, and the list rows are
  `Text` under one `SelectionArea` instead of one `SelectableText` per row.
- **The Logs screen is bounded.** It reads at most the last 2 MB of the daily
  file (`_readLogTail`) and parses at most 20 000 lines. Error/warning/success
  counts and the tag list are computed once at parse time (they were three
  full scans of `_lines` per build), `_LogLine.lower` caches each line's
  lower-case form for search, and typing in the search field is debounced
  (180 ms) instead of rescanning the file on every keystroke.

## Serial network/IO loops are a performance bug (do not regress)
The app's "slow" reports trace back to `for (final x in xs) { await get(x); }`
loops, where every independent request waits for the previous one. Use the
bounded pool in `lib/utils/concurrency.dart` instead:

- `mapParallel(items, maxConcurrent, task)` → results in input order; pass
  `propagateErrors: false` to keep going (a failed slot is `null`).
- `forEachParallel(items, maxConcurrent, task)` for side-effecting work.

Rules of thumb:
- **Per-source extension calls stay serialized by design.** One source runs on
  one non-reentrant extension runtime (`ExtensionServiceRegistry._queues`), so
  firing several calls for the *same* source in parallel buys nothing. Parallelize
  across *different* sources, or plain network/disk work that touches no runtime.
- Bulk extension work (auto-update in `fetch_sources_list.dart`, "update all"
  in `browse_screen.dart`, install-all in `notifications_screen.dart`/`main.dart`,
  repo URL probing in `main._checkValidUrls`) uses a pool of 4.
- Disk probes scale higher: `get_chapter_pages.dart` checks every page's
  `File.exists()` with a pool of 8 (a 200-page chapter used to pay 200 serial
  syscalls). `video_file_meta.dart`'s HLS size probes run together (5).

## Network hardening: connection caps, retry, heavy-decode offload
`lib/utils/retry.dart` adds `retry(task, policy: RetryPolicy(...))`:
exponential backoff + full jitter, transient-only (socket/timeout errors and
5xx/429; 404 and parse errors fail fast). Use it for **idempotent** calls
(GET/HEAD, metadata probes) — it is wired into the extension-index fetch and the
HLS/`Range: bytes=0-0` probes. Never wrap a POST that is not idempotent.

Connection limits matter as much as the pool size. Dart's `HttpClient` has
`maxConnectionsPerHost == null` (unbounded) by default, so a burst of parallel
extension calls can open a socket per request. The shared/single-host clients
cap it: `MClient.defaultClient` (12), the DoH resolver's long-lived client (6),
WebDAV (6), and `video_file_meta._open` (6). The DoH client used to be rebuilt
per lookup — a full TCP+TLS handshake on the critical path of *every* request
when DoH is enabled; it is now a `static final` shared instance.

Heavy pure-CPU decoding must not run on the UI isolate. `fetch_sources_list.dart`
decodes extension-index bodies larger than `_isolateDecodeThreshold` (256 KB)
via `compute()`, mirroring the existing pattern in `marketplace_screen.dart`.

## Automatic backup must not compete with the first frame
`AutoBackupService` copies the whole Isar file, so it is the most expensive
routine the app runs. It waits `_startupSnapshotDelay` (12 s) before the launch
snapshot, and automatic snapshots (launch, 30 min timer, background) are skipped
when the last one is younger than `_autoBackupMinInterval` (10 min) — switching
apps used to copy the database on every single lifecycle pause. Explicit actions
(the "Sauvegarder" button, re-enabling the feature) pass `force: true` and are
never skipped.

## Git workflow: a single branch, `main`

This repo has one long-lived branch, `main`. Everything lands on `main`; there
are no feature branches. Do not open a PR branch for routine work, and do not
leave finished work on a side branch: commit it on `main` and push `main`.

- Before pushing, `git fetch origin && git merge origin/main` so the push is a
  fast-forward. If a merge is needed, resolve it (keep both sides of an
  append-only file such as this one) and run `flutter test` before pushing.
- `main` is the source of truth for the build: the release workflows build from
  it. A fix that lives only on a side branch does not ship.

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
- `DiscoveryStage` must never do one `Directory.list(recursive: true)`: that
  stream aborts on the first `FileSystemException`, and
  `/storage/emulated/0/Android/data` is always unreadable (even with
  MANAGE_EXTERNAL_STORAGE), so the whole scan yielded nothing and the library
  stayed empty. `_walk()` lists folder by folder and skips unreadable subtrees.
- Android 10+ MediaStore rows are `content://…/<id>` URIs: their extension is
  `''`, which `DiscoveryStage` rejects, so the files vanished. The real
  extension comes from `AndroidMediaStore.extensionOf()` (displayName, then
  MIME). `analysisName` is the displayName only for `content://` rows — a real
  path must keep its full path so the `/Anime/` folder signal survives.
- `_removeMissingIndexedItems` and `FileCache.purgeOrphans` must skip
  `content://` paths: `File().existsSync()` can never resolve them, so they
  looked deleted on every scan.
- `SmartLibraryScreen._scanRoots()` requests `requestVideoPermission()` /
  `requestMediaPermission()` (never bare `requestPermission()`), then adds
  `/storage/emulated/0` or the well-known media folders, and an incremental
  scan starts automatically when the screen opens.

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
- Display density is shared through `catalog_filter_sheet.dart`:
  `CatalogLayout` (`grid`, `comfortable`, `list`, `compact`, `coverOnly`) plus
  `catalogLayoutLabel`, `catalogDisplayColumns`, `catalogLayoutTitleOnCover`
  and `catalogLayoutShowTitle`. Every catalogue grid (library, studios,
  "see all", people, extension search) must resolve its columns and title
  treatment through these helpers so the modes stay identical.
- `ExtensionFilterOverlay` renders the "Affichage" drill only when
  `onLayoutChanged` is passed; pass `layout`/`columns` plus the two callbacks
  to expose the same modes as `CatalogFilterOverlay`. `PosterCard.showTitle`
  turns the cover-only grid mode on.
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
- The download-queue cards are the 2026-11-10 case of the same trap:
  `_CoverThumbnail` and `MbThumb` are plain `StatelessWidget`s that call
  `cachedNetworkImage` directly and never inherited a scope, so every
  parent/series and child cover fetched headerless (`ref=NONE ua=NONE`) and
  showed a placeholder. They now take explicit `headers`/`sourceId` and the
  callers pass `ref.watch(headersProvider(...))` built from the row's manga.
- The detail view was never affected: it has always passed the extension
  headers to `cachedNetworkImage` explicitly.
- Debug aid: `custom_extended_image_provider.dart` logs a headers summary and
  the failing status on each cover request (`NET-START`, retry, final failure),
  and `cached_network.dart` logs render failures with `headers=oui|NON`. Use
  those before blaming the CDN.

### Headers must be cheap (do not regress)

`headersProvider` is watched by **every visible cover**, so its body runs once
per card per rebuild and must stay O(1) after the first call for a source:

- It memoises the result map by source signature and borrows the runtime from
  `ExtensionServiceRegistry.get` (one service per source). Do **not** go back to
  `getExtensionService(source)` + `service.dispose()`: that booted and tore down
  a QuickJS interpreter per card and was the main library jank/RAM cause.
- `getSource` (`lib/utils/utils.dart`) must query by indexed `id` / `lang+name`,
  not `isar.sources.where().findAllSync().where(...)`. It has 20+ call sites and
  runs on the UI thread; the Dart-side scan made it O(sources) per call.
- Library cards read `downloadedChapterIdsProvider` (a `Set<int>`) for the
  download badge. Never run a per-chapter `isar.downloads...findAllSync()` loop
  inside a card build — that was O(cards × chapters) synchronous Isar queries.
- `Manga.isLocalArchive` and `Chapter.isRead` are nullable: read them with
  `?? false` / `!= true`, not `!`. A `!` on one entry threw and blanked the
  whole grid.

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


## HLS download assembly (do not regress)
- Assembly has exactly **one** method: join the completed fragments in playlist
  order, then a single FFmpeg stream-copy mux into MP4 (`FfmpegMergeService`).
  There is no second "raw concatenation" fallback; a silent fallback is what
  once published a corrupt file as a finished download.
- Concatenate *before* FFmpeg, never with the `concat` demuxer. The demuxer
  re-probes every input as its own container, so a bare fMP4 media segment
  (`moof`/`mdat` without a `moov`) is rejected: the mux then exits 0 and writes
  a streamless ~260-byte file. Byte-joining `init.mp4` + media segments is the
  only method correct for both MPEG-TS and fMP4/CMAF.
- The mux must pass `-f mp4`. Output goes to `<name>.mp4.part` for an atomic
  write, and FFmpeg infers the muxer from the output extension; `.part` matches
  nothing, so without `-f mp4` every mux aborts with "Unable to choose an output
  format" (exit 234).
- FFmpeg is a **bundled** native library (`ffmpeg_kit_flutter_new`), not an
  installable runtime. `android/build.gradle` substitutes the plugin's
  full-GPL artifact with `min-gpl`; `android/app/build.gradle` keeps
  `minSdkVersion 24` because the AAR requires it. Linux desktop builds need
  `libjson-glib-dev`, which the two Linux workflows install. See
  `docs/FFMPEG_MANAGEMENT.md`.
- The `temp/` segment directory is deleted only **after** a successful merge, so
  a failed merge keeps its resumable fragments.
- A download file name must be truncated to `kMaxDownloadNameBytes` (239, see
  `lib/utils/extensions/string_extensions_io.dart`) **before** its extension is
  appended. The assembler writes `<name>.mp4.part.joined` — 16 bytes past the
  final name — and one path component is capped at 255 bytes (`NAME_MAX`) on
  Linux, Android and iOS. An unbounded long episode title otherwise aborts the
  merge with `File name too long` (errno 36) *after* the whole episode has been
  downloaded. Every site that derives the `<name>.mp4` path from a chapter or
  episode title applies the same bound so lookups, deletes and shares resolve
  the file the downloader actually wrote.
- The assembly + mux is a **second pass**: it is announced once through the
  `DownloadProgress.isMerging` flag before `_mergeTsToMp4` runs. That event
  carries no counters; it must not overwrite the stored transfer totals. The
  queue turns it into the golden indeterminate bar (the same one the manga
  archive packer uses, via `ArchiveProgressStore.markIndeterminate`), labelled
  "Assemblage" for anime. Without it the bar sat at 100% for the whole mux and
  the download looked stalled. The marker is cleared in the HLS `finally` block
  whether the merge succeeds or fails.

## Manga archive conversion (do not regress)
- From compression level 1 up, each page is decoded and re-encoded as an
  optimised JPEG; that re-encode is the whole cost of building a CBZ and is pure
  CPU work. It used to run one page at a time inside the archive isolate, which
  left every core but one idle for the whole chapter — the "download is stuck at
  processing" report. `_packRecompressed`
  (`lib/modules/manga/download/providers/convert_to_cbz.dart`) now splits the
  pages into `numberOfProcessors - 1` (capped at 6) chunks and recompresses each
  chunk in its own isolate via `Isolate.run`, then rebuilds the archive **by
  index** so the page order is byte-for-byte what the sequential loop produced.
  `includedFiles` and the archive must both be filled in the final ordered pass,
  never from a worker as it finishes — workers complete out of order.
- Level 0 stores the original bytes and does no per-page work, so it keeps the
  inline sequential loop (fastest, bounded memory, deterministic order).
- A page that cannot be read is recorded in `missingFiles` (the archive is then
  refused) rather than silently dropped; a page that cannot be *decoded* keeps
  its original bytes (`_recompressJpeg` returns null). Covered by
  `test/manga_archive_conversion_test.dart`.


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

## Onboarding showcase (slogan page performance)
- `lib/modules/onboarding/onboarding_screen.dart` holds the two animated pages.
  The slogan page used to build **450 cards** (5 lanes × 2 copies × 45 items),
  each with a `BoxShadow` and four gradients, all rebuilt on every `setState`,
  while off-screen `PageView` pages kept their tickers running. That is what
  made it crash and stutter. Keep the fixes in place:
  - `OnboardingShowcaseConfig` owns every geometry/count tunable. Do not
    re-hardcode lane counts, card sizes or cycle durations in the screen.
  - Cards are capped per lane (`maxItems`) and the slogan pool is capped too;
    raise a cap only with a measurement.
  - Each page exposes `enabled:` to its `TickerMode` from `_currentPage`, so
    only the visible page animates. A `PageView` keeps off-screen pages alive.
  - `showcaseMotionDisabled(context)` honours the platform "reduce motion"
    setting; when set, the lane controller and the lane-rotation timer stop.
  - Cards pass `loadingWidget: SizedBox.shrink()` to `cachedNetworkImage`:
    the default `_SkeletonShimmer` owns one `AnimationController` each, so
    dozens of loading posters meant dozens of live tickers. The card already
    paints its own gradient placeholder.
- `OnboardingMediaService` fills lanes from keyless sources (AniList GraphQL,
  iTunes Search, Steam featured, TMDB images) and falls back to
  `OnboardingFallbackCatalog` when a source is unreachable or needs a token.
  AniList wraps its payload in a top-level `data` object — read
  `body['data']['Page']['media']`.
- `DeviceCapabilities.ramTierForMB` is the single source of truth for RAM
  tiers; `deviceRamTierFromMB` in the showcase config reuses it (a reading of
  `0`, i.e. desktop/web/unknown, is treated as `high` for the showcase only).
- Regression tests: `test/onboarding_showcase_test.dart` (config + catalogue),
  `test/onboarding_media_service_test.dart` (real parsing via a `MockClient`
  transport), `test/onboarding_screen_layout_test.dart` (layout at phone /
  tablet / desktop sizes, plus reduce-motion). The screen animates forever, so
  these use `pump`, never `pumpAndSettle`.
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

## Réglages (parité Mihon / Aniyomi)
- Les écrans vivent sous `lib/modules/more/settings/<section>` et sont listés
  par `settings_screen.dart` : Général (`/general`), Affichage (`/appearance`,
  renommé depuis « Apparence »), Bibliothèque (`/librarySettings`), Lecteur
  manga (`/readerMode`), Lecteur vidéo (`/playerOverview`), puis
  téléchargements, tracking, sync, sécurité, avancé, widgets.
- Chaque sous-page est un `SettingsSubpageScaffold` : il monte le titre en
  en-tête au scroll et fournit le `<` de retour et la recherche. La recherche
  est globale (`settings_search_index.dart`) et couvre les sous-pages, pas
  seulement la page ouverte — ajouter une entrée là-bas, pas dans la page.
- Les icônes viennent toutes de `core/icon_fonts/broken_icons.dart` (`Broken.*`).
  Ne jamais mélanger avec `Icons.*` : l'incohérence est visible et a déjà
  cassé l'en-tête des paramètres.
- Les préférences runtime sont des providers Riverpod dans
  `settings/<section>/providers/`. Un réglage qui n'est lu que par l'écran de
  réglages est un stub : le lecteur/le hub doit le `watch`/`read` pour que le
  changement s'applique. Exemple : `volumeButtonNavigationStateProvider` est
  écouté dans `reader_view.dart` (`ref.listen`) pour activer/désactiver le
  listener matériel sans rouvrir le chapitre.
- Navigation par boutons de volume : `volume_controller` ne reçoit plus
  `VOLUME_CHANGED_ACTION` sur Android 13+. `VolumeKeyChannel`
  (`modules/manga/reader/services/volume_key_channel.dart`) passe par
  `MainActivity.dispatchKeyEvent`, qui avale les touches et pousse la direction
  sur un EventChannel — le volume système ne bouge donc pas.
- États hors-ligne : ne jamais afficher un `ClientException`/`SocketException`
  brut. `isOfflineContentError` (`modules/widgets/offline_content_state.dart`)
  détecte le cas et `OfflineContentState` montre une animation Lottie, un
  message court et un bouton vers les réglages réseau
  (`openNetworkSettings`, `utils/system_settings.dart`).
- TorrServer : `_baseUrl` (`services/torrent_server.dart`) préfère l'URL saisie
  par l'utilisateur (`normaliseTorrServerUrl`, Hive `player_prefs`) au serveur
  embarqué. Ne pas réintroduire la lecture directe de `btServerPort`.

## Extension update detection (do not regress)
- The catalogue pins every `sourceCodeUrl` to a commit
  (`…@<sha>/src/…`). That makes an edited extension a *new URL*, but the
  installer only looked at `version`. An author who edits an extension and
  forgets to bump `version` therefore publishes a fix the app never downloads:
  the index still says `0.4.12` while pointing at the `0.4.11` code, and
  `compareVersions` sees nothing to install. That is exactly what hid the
  2026-10-26 Harimanga cover fix — 45/72 covers were still rewritten onto the
  incomplete `cdn.zinmanga1.com` mirror, so the home, search and "see all"
  screens showed placeholders for weeks.
- `extensionRevisionChanged` (`fetch_sources_list.dart`) closes the loop by
  treating a changed `@<rev>` as an update. Only a *revision* difference counts:
  two URLs that differ merely by host (fork, jsDelivr ↔ raw) serve the same
  bytes and must not trigger a re-download on every catalogue refresh.
- When auto-update is off, the pending revision is stored in
  `pendingSourceRevision` (metadata envelope, like `pendingUiLayoutVersion`)
  and **`sourceCodeUrl` is left on the installed pin**. Do not "record" the new
  pin there: the download pass detects the pending work by comparing that pin
  with the catalogue, so writing it early makes the update offer itself forever
  and never install.
- `test/extension_revision_change_test.dart` pins both invariants. Bump
  `version` when publishing an extension anyway — the revision check is a
  safety net, not a licence to skip the bump.

## Sauvegarde automatique (auto backup) — ne pas régresser
- `AutoBackupService` (`lib/services/auto_backup_service.dart`) écrit un
  instantané de la base Isar, des boxes Hive et des SharedPreferences dans un
  dossier caché `.backup` **à la racine du dossier de stockage**
  (`/storage/emulated/0/watchtower/.backup` sur Android). Ce dossier est sur le
  stockage externe, donc il **survit à la désinstallation** ; une réinstallation
  restaure l'instantané avant l'ouverture d'Isar, donc bibliothèque, réglages,
  extensions, historique et téléchargements reviennent intacts.
- L'instantané est pris au lancement, toutes les 30 min, au passage en
  arrière-plan, et à la demande. Le dossier est déclaré dans
  `WatchtowerStorageLayout.managedDirectories`.
- Le point d'entrée utilisateur est **Réglages → Sauvegarde automatique**
  (route `/autoBackup`, écran
  `lib/modules/more/data_and_storage/auto_backup_settings_screen.dart`) : il
  affiche le chemin exact du dossier, l'état activé/désactivé, la date de la
  dernière sauvegarde et les boutons Sauvegarder / Restaurer.
- La restauration manuelle ne peut pas échanger la base Isar tant qu'elle est
  ouverte : elle restaure Hive + préférences tout de suite et pose un marqueur
  `pending_restore.flag`, appliqué au prochain lancement avant `Isar.open`.
- `backupNow` pose le drapeau `_backupInFlight` **avant** le premier `await`.
  Le snapshot de lancement et un passage en arrière-plan peuvent se déclencher
  à la même seconde ; quand les deux franchissaient la garde *après* un
  rendu, ils partageaient le même fichier de transit `<db>.pending` et le
  `rename` du perdant échouait avec `No such file or directory` (errno 2) —
  d'où un « AutoBackup: snapshot failed » juste à côté d'un snapshot réussi.
  Rendre la garde synchrone fait échouer le second appelant immédiatement.
- Il n'y a **qu'un seul lecteur vidéo** : la route anime rend `WatchDetailView`.
  Le second lecteur parallèle (`anime_player_view_io.dart` et ses widgets) a
  été supprimé — ne pas le réintroduire.

## Import de sauvegardes Mihon / Tachiyomi (`.tachibk`)
- L'importeur vit dans
  `lib/modules/more/data_and_storage/providers/mihon_backup.dart` et lit
  directement le flux protobuf (pas de zip) ; `restore.dart` route les
  fichiers `.tachibk`/`.proto.gz` vers `restoreMihonBackupProvider`.
- Le schéma `.proto` du dépôt est périmé : le schéma réel est en Kotlin dans
  `app/src/main/java/eu/kanade/tachiyomi/data/backup/models/*.kt` (Mihon). S'y
  fier pour les numéros de champ.
- **`PreferenceValue` est une `sealed class` écrite sans `@ProtoOneOf`** :
  kotlinx la sérialise en `{champ 1 = nom de classe (string), champ 2 = message
  concret (bytes)}`, et le message concret contient une seule valeur au champ 1.
  Lire le champ 1 comme la valeur décode tout en nom de classe (bug corrigé).
- Les chaînes protobuf sont de l'**UTF-8** : décoder avec `utf8.decode`, jamais
  `String.fromCharCodes` (sinon titres/auteurs/genres non-ASCII en mojibake).
- Champs `BackupManga` utiles : 1 source, 2 url, 3 title, 4 artist, 5 author,
  6 description, 7 genre, 8 status, 9 thumbnailUrl, 13 dateAdded, 14 viewer,
  16 chapters, 17 categories, 18 tracking, 100 favorite, 101 chapterFlags,
  103 viewer_flags, 104 history.

## Démarrage : aucune étape ne doit bloquer la première frame (ne pas régresser)
- `main()` n'a qu'un objectif : atteindre `runApp`. Toute étape avant
  `runApp` passe par `_startupStage` (nom + timeout + durée journalisée). Une
  exception qui s'échappe d'une étape laisse l'écran de démarrage natif affiché
  indéfiniment — c'est exactement ce que les utilisateurs décrivent comme
  « l'app crash au lancement ». Ne jamais réintroduire un `await` nu sur un
  service externe (keystore, keychain, Hive, base de données, fichiers).
- `Isar.open` est le seul échec toléré : `initDB` fait déjà 3 tentatives
  (éviction du handle zombie + suppression des fichiers). Si les 3 échouent,
  l'app démarre quand même et l'erreur est journalisée ; ne pas revenir au
  comportement « splash pour toujours ».
- Les boîtes Hive s'ouvrent via `_openHiveBoxSafely`, qui supprime et recrée
  une boîte corrompue (kill pendant une écriture) au lieu de faire échouer le
  lancement.
- Le pool de workers d'extension (jusqu'à 4 isolates, chacun relisant les
  données de dates `intl`) ne doit pas être attendu avant `runApp` :
  `GetIsolateService.start()` est lancé en `unawaited`, et `start()` est
  mémoïsé (`_startFuture`) pour qu'un appel concurrent n'ouvre pas un second
  pool complet.
- `LibraryAutoUpdater` attend 45 s sur un démarrage à froid : une mise à jour
  complète de la bibliothèque lancée à t=0 se superpose au premier rendu, aux
  shelves d'accueil et aux décodages d'images.
- `prewarmHomeHeroImages()` est plafonné par `DeviceCapabilities.ramTier`
  (0 image en tier `low`, 4 en `mid`, 8 en `high`) : le cache image ne fait que
  20 Mo sur un appareil à faible RAM, où préchauffer une douzaine de bannières
  pleine résolution provoque decode → éviction → decode, au pire moment.
- Les grosses sérialisations restent hors isolate UI : `jsonEncode` de la
  sauvegarde passe par `compute`, et les tailles de dossier se cumulent avec
  `File.length()` (asynchrone), jamais `lengthSync()`.

## Onboarding : la page Migration est un écran d'onboarding, pas une route
- L'ordre est : showcase → slogan → **migration** → permissions. Le
  `PageView` de `OnboardingScreen` construit les voisins, donc chaque page non
  visible est enveloppée dans `TickerMode(enabled: _currentPage == i)` ;
  ajouter une page sans ce garde-fou remet deux animations en marche en même
  temps. Le nombre de points de l'indicateur et la borne de `_next()`
  (`_currentPage < 3`) doivent suivre le nombre de pages.
- L'import ne réinvente aucun parseur : la bibliothèque passe par
  `restoreMihonBackup` (`.tachibk` / `.proto.gz`), les chapitres téléchargés
  par le scanner de bibliothèque locale (`local/`). `MigrationApp
  .importSupported` décide si la moitié « bibliothèque » est proposée, donc la
  page n'offre jamais un import qu'elle ne peut pas honorer.
- `restoreMihonBackup` écrit bibliothèque + catégories + historique +
  réglages d'un bloc. `importHistory` / `importSettings` sont honorés en
  *élagant* après coup (vider `isar.historys`, remettre les réglages
  précédents), pas en modifiant le restaurateur.
- `MigrationLogoOrbit` suit la convention du showcase :
  `showcaseMotionDisabled(context)` coupe l'animation et la fige. Tout nouveau
  widget animé de l'onboarding doit lire ce même flag, sinon le test
  « reduce-motion » échoue.
- Les tests de widgets d'onboarding doivent fournir
  `AppLocalizations.localizationsDelegates` / `supportedLocales` : les pages
  lisent `context.l10n` et lèvent une erreur de null-check sans le delegate.
- Les clés `ob*` / `mig*` sont injectées par `tools/l10n_onboarding_migration.py`
  (idempotent) puis `flutter gen-l10n`. Toute nouvelle clé doit passer par ce
  script pour que `app_fr.arb` reste une vraie traduction et que le test de
  parité ARB passe.

## Compteurs de pages manga (ne pas régresser)
- `succeeded`/`total` d'une ligne `Download` sont des **octets** pour l'anime et
  des **pages** pour le manga. Une vieille ligne manga a déjà stocké des octets
  dans `total`, ce qui affichait « 1/1048576 pages » (un million) pour une série
  de 30 ou 60 chapitres. Toute valeur qui ne peut pas être un vrai nombre de
  pages doit être ignorée par `trustedMangaPageCount` (borne
  `maxTrustedMangaPages`, `lib/services/download_manager/download_size.dart`).
- `mangaChapterProgress` (`download_queue_progress.dart`) est le seul endroit qui
  décide du dénominateur : il filtre le stocké **et** le live, retombe sur le
  live quand le stocké est pourri, sinon sur une barre indéterminée.
- `setProgress` (`download_provider.dart`) ne doit **jamais** réécrire un
  dénominateur non fiable dans Isar : une ligne manga corrompue repart à 0/0,
  sinon le « ~1M » se republie à chaque tick.
- Réglages par type (Watch, Manga, Roman, Musique, Jeu) : clés dans
  `DownloadSettingsService`, providers dans `downloads_state_provider.dart`
  (`.g.dart` édité à la main car `riverpod_generator` 4.0.0 plante avec
  l'analyzer 9.0.0). La feuille « Gérer » ouvre chaque type **dans la feuille**
  (`_openType`), sans changer de route. Un seul `_SimultaneousRow` par type
  (5 lignes), chacune avec son chevron « > » qui bascule la feuille sur
  `_InlineTypeDownloadSettings` pour ce type.
- Le pill « Transférer » de la file de téléchargement ouvre la salle de partage
  en **panneau** (`showTransferPanel` → `TransferScreen(asPanel: true)`), jamais
  via `context.push('/transfer')` : la route plein écran reste pour les autres
  entrées. En mode panneau, la salle ne s'arrête à la fermeture que si le
  panneau l'a lui-même démarrée (`_ownsRoom`) ; un salon déjà actif survit.

## Android TV / Leanback (ne pas régresser)
- Le `AndroidManifest.xml` porte les deux launchers (`LAUNCHER` téléphone +
  `LEANBACK_LAUNCHER` TV) et déclare `android.software.leanback` et
  `android.hardware.touchscreen` en `required="false"` : l'APK s'installe sur
  les deux et apparaît sur l'écran d'accueil TV. Ne jamais retirer l'un des deux
  intent-filters ni repasser une de ces features en `required="true"`.
- ABI : `build-release.yml` et `build-android-tv.yml` produisent **arm64-v8a
  uniquement** (`--target-platform android-arm64`, filtre ABI dans
  `build.gradle`). La majorité des TV/box Android et des Fire TV modernes sont
  arm64 ; une TV 32-bit (`armeabi-v7a`) a besoin d'un build
  `-PwatchtowerCiAbis` depuis `build-all-platforms.yml`.
- Le workflow dédié `build-android-tv.yml` (arm64 + x86_64 pour émulateurs) est
  **actif** et publie la release glissante `android-tv-latest`
  (`watchtower-tv-arm64.apk`, `watchtower-tv-x86_64.apk` + `.sha256`). Un APK TV
  n'est pas un APK Android téléphone : toujours tester la build TV, pas
  `build-release.yml`. Le dispatch `workflow_dispatch` exige un token avec le
  scope `workflow` (un PAT sans ce scope renvoie 403
  « Resource not accessible by integration »).

## CI — release multi-plateformes (ne pas régresser)
- `build-all-platforms.yml` construit web, tous les ABI Android (+ universal),
  Android TV, Linux, Windows, macOS, iOS (sideload + simulateur). Le job
  `publish-release` ne s'exécute **que si toutes** les builds sont vertes, puis
  publie `v<major>.<minor>.<run_number>` avec des notes propres
  (`scripts/release_notes.py`, style Mihon) et des noms d'assets normalisés.
- Le job TV de `build-all-platforms.yml` **construit de vrais APK** signés
  (arm64-v8a et x86_64) via `flutter build apk --release --target-platform …`,
  pas un `.7z` renommé : un utilisateur TV attend un APK installable. L'artifact
  `android-tv-universal` contient `watchtower-tv-arm64.apk` et
  `watchtower-tv-x86_64.apk` ; `publish-release` les copie par **nom de fichier**
  (`copy_named`), sinon les deux assets seraient le même APK (le helper `copy`
  ne prend que le premier fichier du dossier).
- Le pub-cache est **restauré d'un run à l'autre** : un paquet déjà patché
  revient modifié et le patch suivant devient un no-op (ou échoue). Les étapes
  qui patchent `desktop_webview_window` (Linux) et
  `flutter_inappwebview_{linux,macos}` suppriment d'abord ces dossiers du cache
  puis relancent `flutter pub get`, et leurs patchs sont **idempotents**.
- iOS : `libc` est **épinglé à 0.2.191** dans `rust/Cargo.lock`. En 0.2.190 les
  symboles `_dyld_*` sont `#[cfg(target_os = "macos")]`, donc `backtrace`
  (via `allo-isolate`) ne compile pas pour `aarch64-apple-ios(-sim)` (E0425).
- macOS : le patch CI de `flutter_inappwebview_macos` doit déplacer la conformité
  `ASWebAuthenticationPresentationContextProviding` dans une **extension**
  `@available(macOS 10.15, *)`, pas annoter la méthode dans la classe : le
  protocole exige 10.14, donc un témoin 10.15 est refusé par Xcode.
- Web : les littéraux entiers de `pseudom` (CSSParser) dépassent 2^53 et
  `dart2js` échoue. Le patch doit couvrir **toutes** les racines du pub-cache,
  échouer si `pseudom` est absent, échouer si un littéral hors-bornes reste, et
  `flutter pub get` doit tourner **avant** le patch.

## Lecture partielle : un épisode interrompu se joue sur sa vraie timeline
- Le `.mp4` fusionné n'existe qu'après la fusion ; un téléchargement HLS
  interrompu n'offre donc aucun fichier jouable. Les fragments présents sont
  assemblés en une playlist locale (`partial.m3u8`) que mpv ouvre directement.
- `segments.json` (écrit par `M3u8Downloader._writeSegmentManifest` à partir des
  `#EXTINF`) fige l'ordre de la playlist et la durée de chaque fragment : c'est
  ce qui permet de restituer la timeline d'origine. Le fragment
  d'initialisation fMP4 est stocké à part (`initSegmentName`) pour être émis via
  `#EXT-X-MAP`.
- `PartialPlaybackPlan` (pur, testé) est la seule source de vérité pour la
  correspondance **compressed** (ce qui est sur le disque) ↔ **real** (la vraie
  durée de l'épisode). Toute position affichée ou demandée passe par lui ;
  comparer directement à `player.state.position`/`duration` réintroduit le bug
  de la timeline compressée.
- Un seek qui tombe dans un trou est redirigé vers le fragment suivant
  (`resolveSeek`), jamais laissé sur une donnée absente. Les trous sont peints
  sur la piste par `_PartialSliderTrackShape`, par-dessus la progression : un
  trou doit rester visible même quand la tête de lecture l'a dépassé.
- La durée réelle (et non celle de mpv) est persistée : `_watchActualDuration`
  ignore la durée mpv tant qu'un `partialPlan` est actif, sinon la longueur de
  l'épisode serait écrasée par celle des seuls fragments présents.
- `PartialPlaybackResolver` tolère les liens Isar non chargés/absents
  (`_resolveChapter` / `_resolveManga`) et accepte un `Chapter` déjà résolu
  pour éviter une relecture Isar quand l'appelant le détient déjà.

## File de téléchargement : « play » doit toujours ouvrir l'épisode
- La vignette (poster) est le point de clic naturel : `MbThumb` / `_CoverThumbnail`
  acceptent un `onTap` optionnel et enveloppent alors toute l'image (pas
  seulement le petit glyphe play central) dans un `GestureDetector`. Sans
  `onTap`, aucun détecteur n'est inséré. Ne pas remettre un `InkWell` autour de
  la ligne entière : les lignes de série replient/déplient le groupe au tap.
- Le bouton play/pause d'une carte reste un contrôle de transfert : il ne route
  vers `onOpen` que lorsque `isComplete`. Un téléchargement en cours n'a donc
  pas de bouton « lire » ; c'est la vignette qui ouvre la lecture.
- `_openDownload` route les épisodes vidéo directement vers
  `/animePlayerView` (le lecteur unique) au lieu de `pushToReaderView`. Cela
  contourne volontairement le filtre « source active » de ce dernier : un
  épisode téléchargé doit se lire depuis le disque même si sa source a été
  supprimée, et un épisode partiel lit les fragments déjà présents.
