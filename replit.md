# Watchtower

Flutter fork of [Mangayomi](https://github.com/kodjodevf/mangayomi), featuring a Netflix-inspired "Watch" module for streaming sources.

## Build & CI

- **Local toolchain is not needed** — builds happen via GitHub Actions CI.
  - Workflow: "Build Flutter Web" on push to `main`.
  - After a green build, send ntfy notification to `ntfy.sh/watchtower`.
- SDK requirement: Dart `^3.10.0` / Flutter `3.38.x` (set in CI via `subosito/flutter-action`).
- Local Flutter 3.27.4 / Dart 3.6.2 (nix `flutter327`) will **not** satisfy `pub get` — this is expected and fine.

## Project structure

- `lib/modules/watch/` — Netflix-style Watch module (home, detail, search).
  - `home/watch_home_screen.dart` — main home screen (pull-to-refresh, search, catalogue).
  - `home/nf_widgets/` — Netflix-adapted UI components.
- `lib/modules/manga/` — standard manga/anime module (Mangayomi base).
- `lib/models/` — Isar entity models (`Manga`, `Source`, etc.).
- `lib/services/` — Riverpod provider services for extension data.

## Rules

- **Never touch** `manga_home_screen.dart` (unrelated module, must stay pristine).
- Push after each discrete fix; monitor CI; ntfy only on green.
- Commit message format: `fix: <short description>`.

## User preferences

- French-speaking user — UI strings in French.
- CI-first workflow: no local build required, push to GitHub and let Actions do the work.
- ntfy.sh notification (`ntfy.sh/watchtower`) only after confirmed green CI build.
