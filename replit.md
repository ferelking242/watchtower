# Watchtower

## Overview

Flutter media app forked from Mangayomi, rebranded as **Watchtower**. Supports anime watching, manga reading, and **light novel reading**. Includes a ZeusDL-powered adult content extension system.

## Website (artifacts/aniyomi-website)

VitePress documentation website for Watchtower. Deployed at `/aniyomi-website/`.

### Website Key Files
- `src/index.md` — home page with features (Anime & Manga, Light Novels, Tracking, etc.)
- `src/.vitepress/config.ts` — main VitePress config, base URL `/aniyomi-website/`
- `src/.vitepress/config/navigation/navbar.ts` — top navigation (Get, Docs dropdown, News, Community dropdown)
- `src/.vitepress/config/navigation/sidebar.ts` — sidebar navigation including LN reader guide
- `src/.vitepress/theme/data/release.data.ts` — GitHub release loader (ferelking242/watchtower), has fallback for missing releases
- `src/.vitepress/theme/data/changelogs.data.ts` — GitHub changelogs loader (ferelking242/watchtower)
- `src/docs/guides/light-novel-reader.md` — complete LN reader guide (added)
- `src/docs/faq/general.md` — general FAQ (LN support confirmed, content types listed)

## Download System (Overhauled)

### Engine Architecture
- `watchtower/lib/services/download_manager/download_settings_service.dart` — JSON-based settings (DownloadMode, SwipeAction enums). Avoids Isar schema migrations.
- `watchtower/lib/services/download_manager/engines/download_engine.dart` — Abstract `DownloadEngine` interface.
- `watchtower/lib/services/download_manager/engines/zeus_dl_engine.dart` — ZeusDL subprocess engine (yt-dlp fork). Calls `zeusdl`/`yt-dlp` binary via `Process.start`. Supports pause (SIGSTOP) and resume (SIGCONT) on Linux/macOS.
- `watchtower/lib/services/download_manager/engine_selector.dart` — `EngineSelector.select()` chooses FK/internal vs ZeusDL based on mode, URL type, and failure history.

### Download Modes (4 modes)
1. **Internal Downloader** — FK built-in only (manga, images, simple files)
2. **FK Fallback Zeus** — Internal first, auto-switches to ZeusDL on failure *(default)*
3. **ZeusDL** — ZeusDL only (best for protected streams, HLS, anti-bot sites)
4. **Auto** — Intelligent detection based on URL and source type

### Providers
- `DownloadModeState`, `SwipeLeftActionState`, `SwipeRightActionState` — Riverpod notifiers, persisted via `DownloadSettingsService`.
- `DownloadQueueState` — In-memory notifier tracking: paused IDs, engine map (FK/ZDL badge), retry counts, speeds.

### Download Queue Screen
- Global actions: Pause All, Resume All, Stop All, Delete Completed, Retry Failed.
- Per-item: pause/resume toggle, retry, cancel buttons. Animated progress bar.
- Engine badge (FK or ZDL in purple). PAUSED badge. Retry count indicator.
- Configurable swipe left/right actions (Pause/Resume, Cancel, Delete, Retry, None).

### M3u8 Downloader Improvements
- `_buildEffectiveHeaders()` — Injects Referer, Origin, User-Agent, cookies.
- 403 retry with header refresh (prevents "403 Forbidden" stream failures).
- `_withRetry<T>()` — Generic exponential-backoff retry helper.
- `refererUrl` constructor param — lets the caller supply the source page URL as Referer.

## Browse Page — Extensions & Sources

### Tags
- **NSFW** (rouge) — affiché pour toute extension avec `isNsfw: true`
- **ZEUS** (bleu) — affiché pour toute extension avec `sourceCodeLanguage == SourceCodeLanguage.javascript` (extensions ZeusDL/MProvider)

### Fichiers clés
- `watchtower/lib/modules/browse/extension/widgets/extension_list_tile_widget.dart` — tile extension avec tags NSFW + ZEUS
- `watchtower/lib/modules/browse/sources/widgets/source_list_tile.dart` — tile source avec tags NSFW + ZEUS
- `watchtower/lib/modules/browse/extension/extension_screen.dart` — sections pliables par langue avec compteurs exacts
- `watchtower/lib/modules/browse/sources/sources_screen.dart` — sections pliables par langue avec compteurs exacts

### Fonctionnalités
- Compteur exact sur chaque section (Updates, Installed, Available total, et chaque langue)
- Sections par langue pliables/dépliables avec animation (InkWell + AnimatedRotation)
- État de collapse maintenu dans `Map<String, bool> _collapsed`

## Android Optimisation

- `minifyEnabled true` + `shrinkResources true` en release (R8/ProGuard)
- ABI splits : `arm64-v8a`, `armeabi-v7a`, `x86_64` + universalApk
- `proguard-rules.pro` créé avec règles Flutter, Kotlin, Isar, OkHttp

## Repos Externes

- `zeusdl/` — Clone git de `ferelking242/zeusdl` (fork de ZeusDL, basé sur yt-dlp)
- `external-projects/AnymeX/` — Clone de référence `RyanYuuki/AnymeX` (Flutter multiservice tracker)

## Stack

- **App**: Flutter (Dart) — `watchtower/`
- **Extensions**: JavaScript (ZeusDL / MProvider format)
- **Extensions repo**: `ferelking242/watchtower-extensions` on GitHub
- **Default repos seeded on first launch**: Keiyoushi (manga), Aniyomi (anime), Watchtower Extensions (NSFW anime), LNReader (novel)

## Key Files

- `watchtower/lib/main.dart` — app entry point, title "Watchtower"
- `watchtower/android/app/src/main/AndroidManifest.xml` — app label
- `watchtower/lib/modules/main_view/main_screen.dart` — dock order
- `watchtower/lib/modules/more/settings/reader/providers/reader_state_provider.dart` — dock items enum
- `watchtower/lib/modules/more/more_screen.dart` — branding
- `watchtower/lib/modules/more/about/about_screen.dart` — about screen branding
- `watchtower/lib/providers/storage_provider.dart` — default repos seeded on first run
- `extensions/index.min.json` — local mirror of GitHub extension index

## Dock Order

Watch → Manga → Novel → History → Updates → Browse → More

## Extensions on GitHub

12 adult video extensions at `ferelking242/watchtower-extensions`:
- XNXX, XVideos, PornHub, SpankBang, xHamster, Eporner, RedTube, YouPorn, Tube8, TXXX, Beeg, TNAFlix
- All use ZeusDL `MProvider` class, `sourceCodeLanguage: 1` (JavaScript), `itemType: 1` (anime/video)
- Index URL: `https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/index.min.json`
