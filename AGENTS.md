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
- The Windows NSIS installer banner/header in
  `.github/workflows/build-windows-x64.yml` must draw the eye, not a hand-coded
  tower. It renders `assets/app_icons/icon.png` directly.
