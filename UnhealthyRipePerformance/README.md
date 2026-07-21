<p align="center">
  <img src="assets/app_icons/icon-red.png" width="110" alt="Watchtower"/>
</p>

<h1 align="center">Watchtower</h1>

<p align="center">
  <b>Manga · Anime · Séries · Musique · Novels</b><br/>
  Gratuit · Open-source · Cross-platform
</p>

<p align="center">
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml/badge.svg" alt="Android"/>
  </a>
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml/badge.svg" alt="iOS"/>
  </a>
  <a href="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml">
    <img src="https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml/badge.svg" alt="Server"/>
  </a>
  <a href="https://github.com/ferelking242/watchtower/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/licence-Apache%202.0-blue.svg" alt="Licence"/>
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter" alt="Flutter"/>
</p>

<p align="center">
  <a href="https://watchtower-website-zeta.vercel.app/">🌐 Site web</a>
  &nbsp;·&nbsp;
  <a href="https://watchtower-website-zeta.vercel.app/download/">📥 Télécharger</a>
  &nbsp;·&nbsp;
  <a href="deployment/README.md">🚀 Déployer</a>
  &nbsp;·&nbsp;
  <a href="CHANGELOG.md">📋 Changelog</a>
</p>

---

## ✨ Fonctionnalités

<table>
  <tr>
    <td align="center" width="25%">📺<br/><b>Anime & Séries</b><br/><sub>Streaming multi-sources, lecteur intégré</sub></td>
    <td align="center" width="25%">📚<br/><b>Manga & Novels</b><br/><sub>Lecture hors-ligne, chapitres, marque-pages</sub></td>
    <td align="center" width="25%">🎵<br/><b>Musique</b><br/><sub>Lecteur audio, playlists, sources JS</sub></td>
    <td align="center" width="25%">🧩<br/><b>Extensions JS</b><br/><sub>Sources communautaires via QuickJS</sub></td>
  </tr>
  <tr>
    <td align="center">🌐<br/><b>Cross-platform</b><br/><sub>Android · iOS · Windows · Linux · macOS · Web</sub></td>
    <td align="center">☁️<br/><b>Serveur headless</b><br/><sub>Déploiement cloud (Railway, Render, Docker)</sub></td>
    <td align="center">🔒<br/><b>Anti-bot & TLS</b><br/><sub>Rotation UA, TLS custom via Rust</sub></td>
    <td align="center">⚡<br/><b>Torrent intégré</b><br/><sub>Client BitTorrent Go, streaming HTTP</sub></td>
  </tr>
</table>

---

## 🏗️ Architecture

Watchtower repose sur **trois couches** qui partagent exactement les mêmes extensions JS :

```
watchtower/
├── lib/                        ← Application Flutter principale
│   ├── modules/                  · UI par média (anime, manga, music, novels, player)
│   ├── eval/                     · Moteur d'extensions JS/Dart (QuickJS)
│   ├── remote/                   · Serveur HTTP embarqué (shelf — port 4567)
│   ├── services/                 · Réseau, téléchargements Aria2, anti-bot
│   ├── ffi/                      · Bindings C → serveur torrent Go
│   └── src/rust/                 · Bindings Rust (EPUB, image, TLS custom)
│
├── server/                     ← Serveur headless Node.js (cloud)
│   ├── server.js                 · Express + QuickJS VM + bridges
│   ├── src/bridges/              · HTTP, DOM (Cheerio), crypto, prefs
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .env.example
│
├── deployment/                 ← Configs & guides de déploiement
│   ├── README.md                 · Toutes les options (Railway, Render, Docker, Colab…)
│   ├── render.yaml               · Config Render (symlink depuis la racine)
│   └── colab_deploy.ipynb
│
├── rust/                       ← Bibliothèque Rust (flutter_rust_bridge 2.x)
└── go/                         ← Client BitTorrent + serveur streaming HTTP
```

### Deux modes serveur, mêmes extensions

| Mode | Fichiers | Quand l'utiliser |
|---|---|---|
| **Embarqué** | `lib/remote/` — shelf port 4567 | App installée (téléphone / desktop) |
| **Headless** | `server/` — Node.js autonome | Cloud : Railway, Render, VPS, Colab… |

---

## 📦 Télécharger

| Plateforme | Comment obtenir |
|---|---|
| **Android** (arm64) | [Actions → Build ARMv8](https://github.com/ferelking242/watchtower/actions/workflows/build-arm64-debug.yml) |
| **iOS** (TrollStore) | [Actions → Build IPA](https://github.com/ferelking242/watchtower/actions/workflows/build-ios-ipa.yml) |
| **Windows** x64 | [Actions → Build Windows](https://github.com/ferelking242/watchtower/actions/workflows/build-windows-x64.yml) |
| **Docker** | `ghcr.io/ferelking242/watchtower-server:latest` |
| **Web** | [watchtower-website-zeta.vercel.app/download](https://watchtower-website-zeta.vercel.app/download/) |

---

## 🚀 Déployer le serveur headless

### ☁️ One-click

| Plateforme | Bouton |
|---|---|
| **Railway** | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ferelking242/watchtower&rootDirectory=server) |
| **Render** | [![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/ferelking242/watchtower) |
| **Google Colab** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ferelking242/watchtower/blob/main/deployment/colab_deploy.ipynb) |

> 📖 **[Guide complet de déploiement →](deployment/README.md)**  
> Railway · Render · Docker · Colab · HuggingFace · RunPod

### 🐳 Docker — démarrage rapide

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
cp .env.example .env   # remplis API_KEY
docker compose up -d
```

### 🟢 Node.js direct

```bash
cd watchtower/server
npm install
API_KEY=mysecretkey PORT=8080 node server.js
```

---

## 🛠️ Build local

<details>
<summary><b>Prérequis</b></summary>

- Flutter SDK **3.38+**
- Dart **3.10+**
- Rust (pour les bindings flutter_rust_bridge)
- Java **17** (build Android)
- Go **1.21+** (optionnel — pour recompiler le client torrent)

</details>

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower

flutter pub get
flutter run                                                          # dev
flutter build apk --release --target-platform android-arm64         # Android
flutter build ipa                                                    # iOS
flutter build windows                                                # Windows
flutter build linux                                                  # Linux
```

> ℹ️ Les builds de release sont gérés par **GitHub Actions** — voir `.github/workflows/`.

---

## 🔗 Écosystème

| Repo | Rôle |
|---|---|
| [ferelking242/watchtower](https://github.com/ferelking242/watchtower) | App principale — moteur, serveur, UI |
| [ferelking242/watchtower-real](https://github.com/ferelking242/watchtower-real) | UI TikTok-style (feed vertical — fusion prévue) |
| [ferelking242/watchtower-website](https://github.com/ferelking242/watchtower-website) | Site de documentation (VitePress / Vercel) |

---

## 🧰 Stack technique

<p align="left">
  <img src="https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Rust-flutter--rust--bridge-B7410E?logo=rust&logoColor=white" alt="Rust"/>
  <img src="https://img.shields.io/badge/Go-torrent-00ADD8?logo=go&logoColor=white" alt="Go"/>
  <img src="https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white" alt="Node.js"/>
  <img src="https://img.shields.io/badge/Docker-ghcr.io-2496ED?logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/QuickJS-extensions-yellow" alt="QuickJS"/>
</p>

| Couche | Tech |
|---|---|
| UI / App | Flutter 3.38+, Dart 3.10+ |
| State | Riverpod 3.x |
| DB locale | Isar (community fork) |
| Préférences | Hive 2.x |
| Vidéo | media_kit (kodjodevf fork) |
| Navigation | GoRouter 17.x |
| Extensions JS | QuickJS via FFI |
| Rust | flutter_rust_bridge 2.x |
| Go | Aria2 + streaming torrent |
| Serveur headless | Node.js 20 + Express + QuickJS VM |
| CI | GitHub Actions |
| Docs | VitePress + Vercel |

---

## 📄 Licence

Distribué sous licence **Apache 2.0** — voir [LICENSE](LICENSE).
