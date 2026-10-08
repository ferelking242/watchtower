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
- `--cli source <id|name> <operation> [--repo DIR] [--url …] [--query …]`
  → legacy repo-backed operation runner used by `scripts/test-eporner.py`.
  Not a registry command; handled before the registry lookup.
- `--cli help`, `--cli version` → no runtime boot.

Commands that need the database still boot `CliRuntime.boot()` and open Isar.
`WATCHTOWER_EXTENSIONS_DIR` overrides the default `watchtower-extensions` path.

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
