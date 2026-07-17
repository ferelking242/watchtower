# Architecture complète — Watchtower

> Document de référence A-Z. Source de vérité pour tout agent IA.  
> Dernière mise à jour : 2026-07-17

---

## 1. Vue d'ensemble — les 3 repos

```
ferelking242/watchtower          ← APP PRINCIPALE (tout y vit : moteur, serveur, UI)
ferelking242/watchtower-real     ← UI Reel uniquement (feed TikTok-style)
ferelking242/watchtower-website  ← Site de documentation (VitePress / Vercel)
```

### Relations entre les repos

```
watchtower
│  produit l'API REST (shelf port 4567 OU Node.js headless)
│  contient openapi.yaml (source de vérité de l'API)
│  produit les binaires : APK, IPA, Windows, Linux, macOS
│
├── consommé par : watchtower-real (via RemoteApiClient / futur SDK Dart)
└── documenté par : watchtower-website

watchtower-real
│  UI TikTok-style standalone (Flutter)
│  même stack exacte que watchtower (riverpod, isar, media_kit, versions identiques)
│  se fusionne dans watchtower/lib/ui/tiktok/ quand mature
│  package Flutter name : reel
│  Android ID : com.watchtower.reel

watchtower-website
│  VitePress, hébergé Vercel : watchtower-website-zeta.vercel.app
│  Sources : website/src/
│  Sidebar : website/src/.vitepress/config/navigation/sidebar.ts
│  Pages docs : website/src/docs/
│  Push → Vercel rebuild automatiquement
```

---

## 2. watchtower — structure complète

```
watchtower/
├── .agent/                     ← ZONE AGENTS IA (ce dossier)
├── lib/
│   ├── modules/                ← UI par type média
│   │   ├── anime/
│   │   ├── manga/
│   │   ├── music/
│   │   ├── novels/
│   │   └── player/
│   ├── eval/                   ← moteur JS/Dart (QuickJS via FFI)
│   │   └── quickjs/            ← exécute les extensions JS
│   ├── remote/                 ← SERVEUR EMBARQUÉ (shelf, port 4567)
│   │   ├── server.dart         ← démarre le shelf server
│   │   └── routes/             ← /api/sources, /api/ping, etc.
│   ├── services/               ← réseau, anti-bot, downloads
│   │   ├── http/               ← client HTTP avec rotation UA
│   │   ├── cache/              ← cache disque + mémoire
│   │   └── download_manager/   ← Aria2 wrapper
│   ├── ffi/                    ← bindings Go (torrent + streaming)
│   └── src/rust/               ← bindings Rust (EPUB, image, TLS custom)
│
├── server/                     ← SERVEUR HEADLESS NODE.JS (cloud deploy)
│   ├── server.js               ← Express 4 + QuickJS VM + bridges
│   ├── src/
│   │   ├── api.js              ← routes HTTP (même API que lib/remote/)
│   │   ├── js-runtime.js       ← sandbox VM (exécute les extensions)
│   │   ├── extension-registry.js ← télécharge et cache les extensions
│   │   ├── rate-limiter.js     ← token bucket par API key
│   │   └── bridges/
│   │       ├── http-bridge.js  ← requêtes HTTP pour les extensions
│   │       ├── dom-bridge.js   ← sélecteurs CSS/XPath (Cheerio)
│   │       ├── crypto-bridge.js ← AES, déobfuscation
│   │       └── prefs-bridge.js ← préférences fichier par source
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── railway.toml            ← Railway config (doit rester ici)
│   └── .env.example
│
├── deployment/                 ← guides et configs de déploiement
│   ├── README.md               ← toutes les options (Railway, Render, Docker, Colab, HF, RunPod)
│   └── colab_deploy.ipynb
│
├── render.yaml                 ← Render config (DOIT rester à la racine)
├── rust/                       ← bibliothèque Rust (flutter_rust_bridge 2.x)
├── go/                         ← client BitTorrent + serveur streaming HTTP
├── AGENT.md                    ← guide agent (raccourci vers .agent/README.md)
└── README.md                   ← README public du projet
```

---

## 3. Les deux modes serveur

Watchtower expose exactement la même API REST via deux runtimes différents.

| Mode | Fichiers | Port | Utilisé quand |
|---|---|---|---|
| **Embarqué** | `lib/remote/` (Dart/shelf) | 4567 | App Flutter installée sur l'appareil |
| **Headless** | `server/` (Node.js/Express) | 8080 | Cloud : Railway, Render, VPS, Colab… |

Les deux exécutent les mêmes extensions JS mangayomi et retournent les mêmes réponses JSON.

### API REST (les deux modes)

```
GET  /api/ping
GET  /api/sources
GET  /api/sources/:id
GET  /api/sources/:id/popular?page=1
GET  /api/sources/:id/latest?page=1
GET  /api/sources/:id/search?q=&page=1
GET  /api/sources/:id/detail?url=
GET  /api/sources/:id/videos?url=
GET  /api/sources/:id/pages?url=
GET  /api/sources/:id/filters
```

Auth : `X-Api-Key: <clé>` ou `Authorization: Bearer <clé>`

---

## 4. watchtower-real (Reel) — structure complète

```
watchtower-real/
└── app/watchtower-real/        ← Flutter app
    ├── lib/
    │   ├── main.dart           ← MediaKit.ensureInitialized() + Hive + Riverpod
    │   ├── app.dart            ← ReelApp (MaterialApp.router)
    │   ├── shell.dart          ← export public pour intégration dans watchtower
    │   ├── router/
    │   │   └── router.dart     ← GoRouter (/, /connect, /profile)
    │   ├── core/
    │   │   └── theme/          ← tokens, AppTheme.dark
    │   ├── remote/
    │   │   ├── remote_client.dart         ← RemoteApiClient (futur → SDK Dart)
    │   │   ├── remote_config_provider.dart ← URL + apiKey + sourceId (SharedPrefs)
    │   │   └── app_version.dart
    │   ├── utils/log/
    │   │   └── app_file_logger.dart
    │   └── features/
    │       └── feed/
    │           ├── feed_screen.dart       ← PageView vertical + pool Players
    │           ├── providers/
    │           │   └── feed_provider.dart ← FeedNotifier (AsyncNotifier)
    │           ├── models/
    │           │   └── feed_item.dart
    │           └── widgets/
    │               ├── feed_page.dart     ← VideoController(player) + thumbnail
    │               ├── feed_header.dart
    │               ├── feed_sidebar.dart  ← like, comment, share, bookmark
    │               └── feed_overlay_bottom.dart
    ├── android/app/
    │   ├── build.gradle        ← applicationId: com.watchtower.reel, keystore env
    │   └── src/main/AndroidManifest.xml  ← label: "Reel"
    ├── .github/workflows/
    │   ├── build-apk.yml       ← arm64, KEYSTORE_BASE64 secret, artifact: reel-arm64-v8a.apk
    │   └── build-ipa.yml       ← TrollStore, artifact: reel.ipa
    └── pubspec.yaml            ← name: reel
```

### Secrets GitHub configurés dans watchtower-real

| Secret | Valeur | Rôle |
|---|---|---|
| `KEYSTORE_BASE64` | keystore PKCS12 encodé base64 | Signing APK permanent |
| `KEY_PASSWORD` | `reelwatchtower` | Mot de passe clé |
| `STORE_PASSWORD` | `reelwatchtower` | Mot de passe store |

**Alias keystore :** `reel`  
**⚠️ Ne jamais régénérer ce keystore** — les mises à jour APK cesseraient de fonctionner.

### Preloading pool (implémenté)

```
feed_screen.dart maintient Map<int, Player>
Fenêtre active : [currentIndex - 1, currentIndex, currentIndex + 1]
→ page active    : player.play()
→ pages adjacentes : player.open(url, play: false)  ← buffer en avance
→ pages hors fenêtre : player.dispose()
```

---

## 5. watchtower-website — structure

```
watchtower-website/
└── website/src/
    ├── .vitepress/
    │   └── config/navigation/
    │       ├── sidebar.ts      ← ajoute les entrées de pages ici
    │       └── navbar.ts
    └── docs/
        ├── faq/
        ├── extensions/
        └── guides/
            ├── getting-started.md
            ├── remote-server.md      ← ajouté 2026-07-17
            └── ui-architecture.md    ← ajouté 2026-07-17
```

---

## 6. Architecture multi-UI (décision finale)

### Pattern retenu : git dep pubspec.yaml

Chaque UI = un repo Flutter indépendant importé dans watchtower via URL git :

```yaml
# watchtower/pubspec.yaml — à faire quand la fusion est prête
dependencies:
  reel:
    git:
      url: https://github.com/ferelking242/watchtower-real.git
      path: app/watchtower-real
      ref: main
```

**Pourquoi pas Melos ?** → Force à fusionner tous les repos en un seul maintenant.  
**Pourquoi pas CI rsync ?** → Fragile, les imports cassent.  
**Pourquoi git dep ?** → Flutter-natif, zéro infra, hot-reload intact, résolution auto des conflits de versions.

### Structure cible dans watchtower (après fusion)

```
watchtower/lib/ui/
├── ui_registry.dart    ← enum UiMode { netflix, tiktok, youtube… }
├── ui_shell.dart       ← ConsumerWidget qui switche selon prefs Hive
├── netflix/            ← UI actuelle (grille, bibliothèque, onglets)
│   └── netflix_shell.dart
└── tiktok/             ← depuis package:reel (watchtower-real)
    └── (importé via pubspec git dep — aucun fichier copié)
```

### Convention pour tout nouveau repo UI

1. Package Flutter `name:` court et snake_case (`reel`, `watchtower_yt`…)
2. `lib/shell.dart` obligatoire — exporte le widget d'entrée
3. Deps partagées avec contraintes larges (`>=3.0.0 <4.0.0`)
4. `main.dart` garde pour le build standalone en dev

---

## 7. Architecture SDK (planifié)

### Principe fondamental

```
watchtower PRODUIT l'API   ←→   SDKs CONSOMMENT l'API
(ne s'importe pas lui-même)      (importés par Reel, web, scripts…)
```

```
watchtower/server/openapi.yaml   ← source de vérité formelle de l'API
         ↓ openapi-generator
watchtower-sdk-dart   → pub.dev: watchtower_client
watchtower-sdk-js     → npm: @watchtower/client
watchtower-sdk-python → PyPI: watchtower-client
         ↓ utilisé par
watchtower-real (Reel) — remplace RemoteApiClient
futurs repos UI
scripts Colab, bots, web frontends
```

### Ce que le SDK encapsule (chaque langage)

```
WatchtowerClient(url, apiKey)
├── .sources.list()
├── .sources.popular(id, page?)
├── .sources.latest(id, page?)
├── .sources.search(id, query, page?)
├── .sources.detail(id, url)
├── .sources.videos(id, url)
├── .sources.pages(id, url)
└── .ping()
```

Plus : injection auto du header auth, retry avec backoff, modèles typés, gestion d'erreurs.

---

## 8. Stack technique complet

| Couche | Tech | Version |
|---|---|---|
| Langage app | Dart | 3.10+ |
| Framework UI | Flutter | 3.38+ |
| State | Riverpod | 3.1.0 |
| Navigation | GoRouter | 17.2.0 |
| DB locale | Isar community | 3.3.2 |
| Prefs | Hive | 2.2.3 |
| Vidéo | media_kit (kodjodevf fork) | git ref f5796d2 |
| Extensions JS | QuickJS (FFI) | — |
| Rust | flutter_rust_bridge | 2.x |
| Go | torrent + streaming | — |
| Serveur embarqué | shelf | — |
| Serveur headless | Node.js 20 + Express | — |
| CI | GitHub Actions | — |
| Docs | VitePress | — |
| Hosting docs | Vercel | — |

---

## 9. Règles immuables

1. **`render.yaml` reste à la racine de watchtower** — Render le lit depuis là
2. **`server/railway.toml` reste dans `server/`** — Railway le lit depuis le root du service
3. **Le keystore Reel ne change jamais** — `KEYSTORE_BASE64` secret GitHub, alias `reel`
4. **watchtower ne s'importe pas son propre SDK** — il produit l'API, point
5. **Mêmes versions de packages** entre watchtower et watchtower-real pour éviter les conflits à la fusion
6. **Pas de `build_runner`** dans watchtower-real tant qu'il n'y a pas de codegen actif
