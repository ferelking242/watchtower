# Watchtower Extension System

  > **Version**: 1.0 · **Last Updated**: June 2026

  Watchtower extensions (« plugins ») are lightweight JSON-driven packages that teach the app how to interact with a new source or service — no native code required. This document describes the full lifecycle: manifest structure, UI schema, Zeus plugin API, and the native Flutter renderer.

  ---

  ## 1. Architecture Overview

  ```
  watchtower-extensions/
  ├── index/
  │   └── plugins.json          ← Plugin registry (auto-updated by CI)
  ├── plugins/
  │   ├── _templates/           ← Starter templates
  │   │   └── tiktok-downloader/
  │   └── <vendor>.<slug>/
  │       ├── manifest.json     ← Plugin definition (required)
  │       ├── ui/
  │       │   └── schema.json   ← Native UI layout (optional)
  │       ├── scripts/
  │       │   └── main.py       ← ZeusDL script (optional)
  │       └── README.md
  └── schema.json               ← JSON Schema for manifest validation
  ```

  ---

  ## 2. manifest.json

  Every plugin must include a `manifest.json` at its root.

  ### Full Example

  ```json
  {
    "id": "en.tiktok-downloader",
    "name": "TikTok Downloader",
    "version": "1.0.0",
    "description": "Download TikTok videos and audio.",
    "longDescription": "Full description in Markdown…",
    "author": "ferelking242",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/plugins/en.tiktok-downloader/icon.png",
    "category": "downloader",
    "tags": ["tiktok", "video", "social"],
    "runtimeTypes": ["downloader"],
    "commandScopes": ["download"],
    "networkAccess": ["tiktok.com", "vm.tiktok.com"],
    "requirements": {
      "zeusdl": { "version": ">=1.0.0", "optional": false }
    },
    "ui": "native",
    "screenshots": [],
    "changelog": "Initial release.",
    "downloads": 0,
    "featured": false
  }
  ```

  ### Fields Reference

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `id` | string | ✅ | Unique reverse-DNS identifier: `<lang>.<slug>` |
  | `name` | string | ✅ | Display name |
  | `version` | string | ✅ | Semver string (e.g. `1.2.3`) |
  | `description` | string | ✅ | Short one-line description |
  | `longDescription` | string | — | Markdown-formatted long description |
  | `author` | string | ✅ | GitHub username or display name |
  | `iconUrl` | string | — | HTTPS URL to a PNG or SVG icon (512×512 recommended) |
  | `category` | string | ✅ | One of: `downloader`, `utility`, `media`, `tools`, `theme` |
  | `tags` | string[] | — | Free-form tags for filtering |
  | `runtimeTypes` | string[] | — | Execution modes: `downloader`, `utility` |
  | `commandScopes` | string[] | — | System permissions: `download`, `network`, `file` |
  | `networkAccess` | string[] | — | Domains the plugin accesses |
  | `requirements` | object | — | Binary dependencies (see below) |
  | `ui` | string | — | `"native"` (Flutter renderer) or `"webview"` |
  | `screenshots` | string[] | — | HTTPS URLs to screenshot images |
  | `featured` | boolean | — | `true` = shown in Featured section |

  ### Requirements

  ```json
  "requirements": {
    "zeusdl": { "version": ">=1.0.0", "optional": false },
    "aria2":  { "version": ">=1.36.0", "optional": true  }
  }
  ```

  Currently supported binaries: **`zeusdl`**, **`aria2`**.

  ---

  ## 3. ui/schema.json — Native Flutter UI

  When `manifest.json` sets `"ui": "native"`, Watchtower reads `ui/schema.json` and renders a fully native Flutter UI — no WebView. This means faster load times, consistent design, and offline compatibility.

  ### Example (TikTok Downloader)

  ```json
  {
    "version": 1,
    "title": "TikTok Downloader",
    "subtitle": "Collez une URL TikTok pour télécharger la vidéo.",
    "inputs": [
      {
        "id": "url",
        "type": "url_field",
        "label": "URL TikTok",
        "placeholder": "https://vm.tiktok.com/…",
        "required": true
      },
      {
        "id": "quality",
        "type": "select",
        "label": "Qualité",
        "options": ["Auto", "720p", "1080p", "Audio seul"],
        "default": "Auto"
      },
      {
        "id": "no_watermark",
        "type": "toggle",
        "label": "Sans filigrane",
        "default": true
      }
    ],
    "actions": [
      {
        "id": "download",
        "label": "Télécharger",
        "style": "primary",
        "icon": "download"
      }
    ],
    "output": {
      "type": "log",
      "label": "Progression"
    }
  }
  ```

  ### Input Types

  | Type | Widget | Notes |
  |------|--------|-------|
  | `url_field` | TextField (URL keyboard) + paste button | Validates non-empty on action |
  | `text_field` | TextField (text keyboard) | Free-form text |
  | `select` | DropdownButton | Requires `options` array |
  | `toggle` | SwitchListTile | Boolean on/off |

  ### Action Styles

  | `style` | Appearance |
  |---------|-----------|
  | `primary` | Teal filled button |
  | `secondary` | Dark filled button |

  ### Action Icons

  Available `icon` values: `download`, `play`, `search`, `send`, `check`, `refresh`.

  ### Output Types

  | `type` | Behaviour |
  |--------|----------|
  | `log` | Scrollable monospace log (auto-scrolls to bottom) |

  ---

  ## 4. Zeus Plugin API

  Plugins that require execution use the **ZeusDL** runtime. The runtime launches a Python script in a sandboxed process.

  ### Script location

  `scripts/main.py` (referenced in the plugin's `requirements.zeusdl` entry).

  ### Environment variables injected by Watchtower

  | Variable | Value |
  |----------|-------|
  | `WT_PLUGIN_ID` | Plugin ID (e.g. `en.tiktok-downloader`) |
  | `WT_DOWNLOAD_DIR` | Target download directory for this plugin's category |
  | `WT_ZEUS_CACHE` | Path to `plugins/.cache/zeus/<media>/` |
  | `WT_ACTION` | Action ID triggered (e.g. `download`) |

  Input values are passed as named arguments: `--url`, `--quality`, `--no_watermark`, etc.

  ### Output protocol

  Write lines to **stdout** — Watchtower streams them to the output log in real time. Prefix lines for structured output:

  ```
  PROGRESS:42       ← progress percentage (0–100)
  STATUS:Downloading…   ← status text
  DONE:/path/to/file.mp4  ← completion + file path
  ERROR:message         ← failure message
  ```

  ---

  ## 5. Download Folder Structure

  Watchtower organizes downloads under:

  ```
  /storage/emulated/0/Watchtower/
    video/
      downloads/          ← final video files
      plugins/.cache/zeus/  ← ZeusDL temp/cache files
    music/
      downloads/
      plugins/.cache/zeus/
    manga/
      downloads/
      plugins/.cache/zeus/
    novels/
      downloads/
      plugins/.cache/zeus/
  ```

  Paths are resolved by `WatchtowerFolderService`. On iOS and desktop, the base directory falls back to the app's documents directory.

  ---

  ## 6. Publishing a Plugin

  1. **Fork** [ferelking242/watchtower-extensions](https://github.com/ferelking242/watchtower-extensions)
  2. **Copy** `plugins/_templates/tiktok-downloader/` → `plugins/<lang>.<your-slug>/`
  3. **Fill in** `manifest.json`, add `ui/schema.json` (optional)
  4. **Validate** the manifest against `schema.json` (`npx ajv validate -s schema.json -d plugins/<slug>/manifest.json`)
  5. **Open a Pull Request** — CI validates + auto-updates `index/plugins.json`
  6. Once merged, the plugin appears in the **Marketplace** within 5 minutes

  ---

  ## 7. Plugin Icon Guidelines

  | Attribute | Requirement |
  |-----------|-------------|
  | Format | PNG (preferred) or SVG |
  | Size | 512×512 px |
  | Background | Transparent or solid dark background |
  | Hosting | GitHub raw URL (same repo) |
  | Badge | Watchtower badge auto-applied by the app — do not include it in your icon |

  ---

  *Questions? Open an issue at [ferelking242/watchtower-extensions](https://github.com/ferelking242/watchtower-extensions/issues).*
  