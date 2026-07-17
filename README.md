<p align="center">
  <img src="assets/app_icons/icon-red.png" width="120" alt="Watchtower"/>
</p>

<h1 align="center">Watchtower</h1>

<p align="center">
  <b>Manga · Anime · Movies · Music · Novels — free, open-source, cross-platform</b>
</p>

<p align="center">
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml/badge.svg" alt="Build APK"/>
  </a>
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml/badge.svg" alt="Build IPA"/>
  </a>
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml/badge.svg" alt="Build Server"/>
  </a>
</p>

---

## 📦 Download

| Platform | Link |
|---|---|
| **Android APK** (arm64) | [Actions → Build ARMv8](https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml) |
| **iOS IPA** (TrollStore) | [Actions → Build IPA](https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml) |
| **Windows** | [Actions → Build Windows](https://github.com/ferelking242/watchtower/actions/workflows/build-windows-x64.yml) |
| **Docker image** | `ghcr.io/ferelking242/watchtower-server:latest` |

---

## 🏗️ Architecture

```
watchtower/
├── lib/
│   ├── modules/       ← UI (anime, manga, music, novels, player, library…)
│   ├── eval/          ← JS & Dart extension execution engine (QuickJS)
│   ├── remote/        ← Embedded HTTP server (shelf) — remote API on port 4567
│   ├── services/      ← Networking, downloads (Aria2), anti-bot bypass
│   ├── ffi/           ← Go torrent server (C bindings)
│   └── src/rust/      ← Rust bindings (EPUB, image processing, TLS)
├── server/            ← Standalone Node.js headless server (deploy to cloud)
│   ├── server.js
│   └── src/           ← HTTP bridges, JS runtime, extension registry
├── rust/              ← Rust library (flutter_rust_bridge)
└── go/                ← Go BitTorrent client + HTTP streaming server
```

**Two server modes — same extensions:**

| Mode | How | When to use |
|---|---|---|
| **Embedded** (`lib/remote/`) | Flutter app exposes port 4567 via `shelf` | App running on phone/desktop |
| **Headless** (`server/`) | Standalone Node.js process | Cloud (Railway, Render, VPS, Colab…) |

Both modes run the same JS extensions and expose the same REST API.

---

## 🚀 Deploy the Headless Server

### ☁️ One-click cloud

| Platform | Button |
|---|---|
| **Railway** | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ferelking242/watchtower&rootDirectory=server) |
| **Render** | [![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/ferelking242/watchtower) |
| **Google Colab** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ferelking242/watchtower/blob/main/colab_deploy.ipynb) |

### 🐳 Docker (local / VPS)

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server

cp .env.example .env        # → set API_KEY
docker compose up -d

curl http://localhost:8080/api/ping
# {"status":"ok","version":"0.1.0"}
```

### 🟢 Node.js direct

```bash
cd watchtower/server
npm install
API_KEY=mysecretkey PORT=8080 node server.js
```

### 🤗 Hugging Face Spaces

Create a Space → **Docker** runtime → copy `server/` contents → add `API_KEY` secret.

### ⚗️ Google Colab (free, session-based)

Open [colab_deploy.ipynb](colab_deploy.ipynb) → fill in API key + ngrok token → **Run all** → copy the public URL into the app settings.

### 🏃 RunPod

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
npm ci
API_KEY=yourkey PORT=8080 node server.js &
```
Expose port `8080` in the pod network settings.

---

## 📱 Connect the App to Your Server

**Settings → Remote Server → Server URL** → paste your URL → enter your `API_KEY`.

---

## 🔧 Server Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `API_KEY` | _(empty = open)_ | Auth key for all `/api/*` routes |
| `EXTENSIONS_REPO_URL` | mangayomi-extensions/main | Extensions catalogue base URL |
| `CACHE_TTL_MS` | `300000` | Cache TTL (5 min) |
| `CACHE_DIR` | `/data/cache` | On-disk cache |
| `PREFS_DIR` | `/data/prefs` | Per-source preferences |
| `RATE_WINDOW_MS` | `60000` | Rate limit window |
| `RATE_MAX_TOKENS` | `60` | Max requests per window |

---

## 🛠️ Build the App Locally

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower

# Requires: Flutter SDK 3.38+, Rust toolchain, Java 17
flutter pub get
flutter run
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

---

## 🔗 Related

- **[watchtower-real](https://github.com/ferelking242/watchtower-real)** — TikTok-style feed UI (will be integrated into this app)

---

## 📄 License

Apache 2.0
