<p align="center">
  <img src="assets/app_icons/icon-red.png" width="120" alt="Watchtower"/>
</p>

<h1 align="center">Watchtower</h1>

<p align="center">
  <strong>Manga · Anime · Séries · Musique · Novels — gratuit, open-source, cross-platform</strong>
</p>

<p align="center">
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml/badge.svg" alt="APK"/>
  </a>&nbsp;
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml/badge.svg" alt="IPA"/>
  </a>&nbsp;
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml/badge.svg" alt="Server"/>
  </a>
</p>

<p align="center">
  <a href="https://watchtower-website-zeta.vercel.app/">🌐 Site web</a> &nbsp;·&nbsp;
  <a href="https://watchtower-website-zeta.vercel.app/download/">📥 Télécharger</a> &nbsp;·&nbsp;
  <a href="deployment/README.md">🚀 Déployer le serveur</a>
</p>

---

## 📦 Télécharger

| Plateforme | Lien |
|---|---|
| **Android APK** (arm64) | [Actions → Build ARMv8](https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml) |
| **iOS IPA** (TrollStore) | [Actions → Build IPA](https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml) |
| **Windows** | [Actions → Build Windows](https://github.com/ferelking242/watchtower/actions/workflows/build-windows-x64.yml) |
| **Docker** | `ghcr.io/ferelking242/watchtower-server:latest` |

---

## 🏗️ Architecture

```
watchtower/
├── lib/
│   ├── modules/        ← UI par média (anime, manga, music, novels, player…)
│   ├── eval/           ← Moteur d'extensions JS/Dart (QuickJS)
│   ├── remote/         ← Serveur HTTP embarqué (shelf) — port 4567
│   ├── services/       ← Réseau, téléchargements (Aria2), anti-bot
│   ├── ffi/            ← Serveur torrent Go (bindings C)
│   └── src/rust/       ← Bindings Rust (EPUB, image, TLS custom)
├── server/             ← Serveur Node.js headless (déploiement cloud)
│   ├── server.js
│   └── src/            ← Bridges HTTP/DOM/Crypto, runtime JS, registry extensions
├── deployment/         ← Configs et guides de déploiement
│   ├── README.md       ← Toutes les options de déploiement
│   └── colab_deploy.ipynb
├── rust/               ← Bibliothèque Rust (flutter_rust_bridge)
└── go/                 ← Client BitTorrent + serveur streaming HTTP
```

### Deux modes serveur, mêmes extensions

| Mode | Comment | Quand l'utiliser |
|---|---|---|
| **Embarqué** (`lib/remote/`) | L'app Flutter expose le port 4567 via `shelf` | App installée sur téléphone/desktop |
| **Headless** (`server/`) | Processus Node.js autonome | Cloud — Railway, Render, VPS, Colab… |

Les deux modes exécutent les mêmes extensions JS et exposent la même API REST.

---

## 🚀 Déployer le serveur headless

### ☁️ One-click cloud

| Plateforme | Bouton |
|---|---|
| **Railway** | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ferelking242/watchtower&rootDirectory=server) |
| **Render** | [![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/ferelking242/watchtower) |
| **Google Colab** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ferelking242/watchtower/blob/main/deployment/colab_deploy.ipynb) |

> 📖 **[Guide complet de déploiement →](deployment/README.md)** (Railway, Render, Docker, Colab, HuggingFace, RunPod)

### 🐳 Docker (local / VPS) — démarrage rapide

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
cp .env.example .env        # → remplis API_KEY
docker compose up -d
curl http://localhost:8080/api/ping
# → {"status":"ok","version":"0.1.0"}
```

### 🟢 Node.js direct

```bash
cd watchtower/server
npm install
API_KEY=mysecretkey PORT=8080 node server.js
```

---

## 📡 API REST

| Endpoint | Description |
|---|---|
| `GET /api/ping` | Health check |
| `GET /api/sources` | Liste des sources |
| `GET /api/sources/:id/popular` | Contenu populaire |
| `GET /api/sources/:id/latest` | Dernières mises à jour |
| `GET /api/sources/:id/search?q=` | Recherche |
| `GET /api/sources/:id/detail?url=` | Détail d'un item |
| `GET /api/sources/:id/videos?url=` | URLs de streaming vidéo |
| `GET /api/sources/:id/pages?url=` | Pages manga |

Auth : `X-Api-Key: <clé>` ou `Authorization: Bearer <clé>`

---

## 📱 Connecter l'app au serveur

**Paramètres → Serveur distant → URL** → colle l'URL → entre ta `API_KEY`.

---

## 🛠️ Build local

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower

# Prérequis : Flutter SDK 3.38+, Rust, Java 17
flutter pub get
flutter run
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

---

## 🔗 Repos liés

| Repo | Rôle |
|---|---|
| [watchtower-real](https://github.com/ferelking242/watchtower-real) | UI TikTok-style feed (sera intégré ici) |
| [watchtower-website](https://github.com/ferelking242/watchtower-website) | Site de documentation |

---

## 📄 Licence

Apache 2.0
