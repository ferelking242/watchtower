<a href="https://github.com/ferelking242/watchtower">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:ff6b35,100:ff2e63&height=220&section=header&text=Watchtower&fontSize=80&fontColor=ffffff&animation=fadeIn&fontAlignY=35&desc=Manga%20·%20Anime%20·%20S%C3%A9ries%20·%20Musique%20·%20Novels&descSize=18&descAlignY=55&descAlign=50" width="100%" alt="Watchtower Banner"/>
</a>

<div align="center">

[![Build Debug APK](https://github.com/ferelking242/watchtower/actions/workflows/build-debug.yml/badge.svg)](https://github.com/ferelking242/watchtower/actions/workflows/build-debug.yml)
[![Build Profile APK](https://github.com/ferelking242/watchtower/actions/workflows/build-profile.yml/badge.svg)](https://github.com/ferelking242/watchtower/actions/workflows/build-profile.yml)
[![Build Release APK](https://github.com/ferelking242/watchtower/actions/workflows/build-release.yml/badge.svg)](https://github.com/ferelking242/watchtower/actions/workflows/build-release.yml)
[![Build Server](https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml/badge.svg)](https://github.com/ferelking242/watchtower/actions/workflows/build-server.yml)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/ferelking242/watchtower/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Rust](https://img.shields.io/badge/Rust-B7410E?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![Go](https://img.shields.io/badge/Go-00ADD8?logo=go&logoColor=white)](https://go.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=22&pause=1000&color=FF6B35&center=true&vCenter=true&multiline=true&repeat=true&width=600&height=100&lines=Free+and+open-source+media+hub;Manga+%E2%80%A2+Anime+%E2%80%A2+Series+%E2%80%A2+Music+%E2%80%A2+Novels;Cross-platform+%E2%80%A2+Self-hostable+%E2%80%A2+Extensible" alt="Typing SVG" />

</div>

---

## ✨ Fonctionnalités

<table>
  <tr>
    <td align="center" width="25%">
      <b>📺 Anime & Séries</b><br/>
      <sub>Multi-sources streaming, lecteur intégré</sub>
    </td>
    <td align="center" width="25%">
      <b>📚 Manga & Novels</b><br/>
      <sub>Lecture hors-ligne, chapitres, marque-pages</sub>
    </td>
    <td align="center" width="25%">
      <b>🎵 Musique</b><br/>
      <sub>Lecteur audio, playlists, sources JS</sub>
    </td>
    <td align="center" width="25%">
      <b>🧩 Extensions JS</b><br/>
      <sub>Sources communautaires via QuickJS</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <b>🌐 Cross-platform</b><br/>
      <sub>Android · iOS · Windows · Linux · macOS · Web</sub>
    </td>
    <td align="center">
      <b>☁️ Serveur headless</b><br/>
      <sub>Déploiement cloud (Railway, Render, Docker)</sub>
    </td>
    <td align="center">
      <b>🔒 Anti-bot & TLS</b><br/>
      <sub>Rotation UA, TLS custom via Rust</sub>
    </td>
    <td align="center">
      <b>⚡ Torrent intégré</b><br/>
      <sub>Client BitTorrent Go, streaming HTTP</sub>
    </td>
  </tr>
</table>

---

## 🏗️ Architecture

```
watchtower/
├── lib/                        ← Flutter app
│   ├── modules/                  UI by media (anime, manga, music, novels, player)
│   ├── eval/                     JS/Dart extension engine (QuickJS)
│   ├── remote/                   Embedded HTTP server (shelf — port 4567)
│   ├── services/                 Network, Aria2 downloads, anti-bot
│   ├── ffi/                      C bindings → Go torrent server
│   └── src/rust/                 Rust bindings (EPUB, image, custom TLS)
│
├── server/                     ← Headless Node.js server (cloud)
│   ├── server.js                 Express + QuickJS VM + bridges
│   ├── src/bridges/              HTTP, DOM (Cheerio), crypto, prefs
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── rust/                       ← Rust library (flutter_rust_bridge 2.x)
└── go/                         ← BitTorrent client + HTTP streaming server
```

| Mode | Files | When to use |
|---|---|---|
| **Embedded** | `lib/remote/` — shelf port 4567 | Installed app (phone / desktop) |
| **Headless** | `server/` — standalone Node.js | Cloud: Railway, Render, VPS… |

---

## 📦 Download

| Platform | How to get |
|---|---|
| **Android** (arm64) | [Actions → Build Debug APK](https://github.com/ferelking242/watchtower/actions/workflows/build-debug.yml) |
| **Android** (profile) | [Actions → Build Profile APK](https://github.com/ferelking242/watchtower/actions/workflows/build-profile.yml) |
| **Android** (release) | [Actions → Build Release APK](https://github.com/ferelking242/watchtower/actions/workflows/build-release.yml) |
| **Windows** x64 | [Actions → Build Windows x64](https://github.com/ferelking242/watchtower/actions/workflows/build-windows-x64.yml) |
| **Docker** | `ghcr.io/ferelking242/watchtower-server:latest` |
| **Web** | [watchtower-website-zeta.vercel.app/download](https://watchtower-website-zeta.vercel.app/download/) |

---

## 🚀 Deploy the headless server

### ☁️ One-click

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ferelking242/watchtower&rootDirectory=server)
[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/ferelking242/watchtower)

### 🐳 Docker

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
cp .env.example .env   # fill API_KEY
docker compose up -d
```

### 🟢 Node.js

```bash
cd watchtower/server
npm install
API_KEY=mysecretkey PORT=8080 node server.js
```

---

## 🛠️ Build locally

<details>
<summary><b>Prerequisites</b></summary>

- Flutter SDK **3.38+** / Dart **3.10+**
- Rust (for flutter_rust_bridge bindings)
- Java **17** (Android builds)
- Go **1.21+** (optional — rebuild torrent client)

</details>

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower

flutter pub get
flutter run                                                    # dev
flutter build apk --release --target-platform android-arm64   # Android
flutter build windows                                          # Windows
flutter build linux                                            # Linux
```

---

## 🧰 Tech Stack

<p align="center">
  <img src="https://skillicons.dev/icons?i=flutter,dart,rust,go,nodejs,docker,sqlite" alt="Tech Stack" width="300"/>
</p>

<p align="center">
  <a href="https://github.com/ferelking242/watchtower">
    <img src="https://github-readme-stats.vercel.app/api?username=ferelking242&show_icons=true&theme=radical&hide_border=true&bg_color=0d1117&title_color=ff6b35&icon_color=ff2e63&text_color=c9d1d9" alt="GitHub Stats" />
  </a>
</p>

<p align="center">
  <img src="https://github-readme-stats.vercel.app/api/top-langs/?username=ferelking242&layout=compact&theme=radical&hide_border=true&bg_color=0d1117&title_color=ff6b35&text_color=c9d1d9&langs_count=8" alt="Top Languages" />
</p>

| Layer | Tech |
|---|---|
| UI / App | Flutter 3.38+, Dart 3.10+ |
| State | Riverpod 3.x |
| Local DB | Isar (community fork) |
| Prefs | Hive 2.x |
| Video | media_kit (kodjodevf fork) |
| Navigation | GoRouter 17.x |
| JS Extensions | QuickJS via FFI |
| Rust | flutter_rust_bridge 2.x |
| Go | Aria2 + torrent streaming |
| Server | Node.js 20 + Express + QuickJS VM |
| CI | GitHub Actions |

---

## 🤝 Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feat/my-feature`)
3. Commit your changes
4. Push to the branch and open a PR

---

## 📄 License

Distributed under the **Apache 2.0** License — see [LICENSE](LICENSE).

---

<div align="center">

**Made with ❤️ by the Watchtower community**

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:ff6b35,100:ff2e63&height=80&section=footer" width="100%" alt="Footer"/>

</div>
