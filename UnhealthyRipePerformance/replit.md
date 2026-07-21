# Watchtower

Application Flutter multimédia — manga, anime, séries, musique, novels. Module Watch Netflix-style pour sources streaming, avec serveur headless Node.js et extensions JS/Dart.

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
- `lib/modules/manga/` — module manga/anime (lecture, sources, bibliothèque).
- `lib/models/` — Isar entity models (`Manga`, `Source`, etc.).
- `lib/services/` — Riverpod provider services for extension data.
- `server/` — Serveur Node.js headless (déploiement cloud), registry extensions.
- `rust/` — Bindings Rust (EPUB, image, TLS custom via flutter_rust_bridge).
- `go/` — Client BitTorrent + serveur streaming HTTP.

## Rules

- **Never touch** `manga_home_screen.dart` (unrelated module, must stay pristine).
- Push after each discrete fix; monitor CI; ntfy only on green.
- Commit message format: `fix: <short description>`.

## User preferences

- French-speaking user — UI strings in French.
- CI-first workflow: no local build required, push to GitHub and let Actions do the work.
- ntfy.sh notification (`ntfy.sh/watchtower`) only after confirmed green CI build.