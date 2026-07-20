# Architecture complète — Watchtower

> Document de référence A-Z. Source de vérité pour tout agent IA.  
> Dernière mise à jour : 2026-07-20

---

## 1. Vue d'ensemble — les 3 repos

```
ferelking242/watchtower          ← APP PRINCIPALE (moteur, serveur, UI — tout y vit)
ferelking242/watchtower-real     ← UI Reel uniquement (feed TikTok-style)
ferelking242/watchtower-website  ← Site de documentation (VitePress / Vercel)
```

### Relations entre les repos

```
watchtower
│  produit l'API REST (shelf port 4567 OU Node.js headless)
│  produit les binaires : APK, IPA, Windows, Linux, macOS
│
├── consommé par : watchtower-real (via RemoteApiClient)
└── documenté par : watchtower-website

watchtower-real
│  UI TikTok-style standalone (Flutter)
│  se fusionne dans watchtower/lib/ui/tiktok/ quand mature
│  package Flutter name : reel
│  Android ID : com.watchtower.reel

watchtower-website
│  VitePress, hébergé Vercel : watchtower-website-zeta.vercel.app
│  Push → Vercel rebuild automatiquement
```

---

## 2. Structure complète du repo `watchtower`

```
watchtower/
│
├── .agent/                       ← Zone agents IA
│   ├── ARCHITECTURE.md             · Ce fichier (source de vérité)
│   ├── README.md                   · Guide de continuation agents
│   ├── ROADMAP.md
│   └── plans/ · transcripts/
│
├── lib/                          ← Application Flutter principale
│   ├── modules/                    · UI par type média
│   │   ├── anime/
│   │   ├── manga/
│   │   ├── music/
│   │   ├── novels/
│   │   └── player/
│   ├── eval/                       · Moteur JS/Dart (QuickJS via FFI)
│   │   └── quickjs/                  exécute les extensions JS
│   ├── remote/                     · Serveur HTTP EMBARQUÉ (shelf, port 4567)
│   │   ├── server.dart
│   │   └── routes/
│   ├── services/                   · Réseau, anti-bot, téléchargements
│   │   ├── http/                     client HTTP + rotation UA
│   │   ├── cache/                    cache disque + mémoire
│   │   └── download_manager/         Aria2 wrapper
│   ├── ffi/                        · Bindings C → serveur torrent Go
│   └── src/rust/                   · Bindings Rust (EPUB, image, TLS custom)
│
├── server/                       ← Serveur HEADLESS Node.js (cloud deploy)
│   ├── server.js                   · Express 4 + QuickJS VM + bridges
│   ├── src/
│   │   ├── api.js                    routes HTTP (même interface que lib/remote/)
│   │   ├── js-runtime.js             sandbox VM — exécute les extensions
│   │   ├── extension-registry.js     télécharge et cache les extensions
│   │   ├── rate-limiter.js           token bucket par API key
│   │   └── bridges/
│   │       ├── http-bridge.js        requêtes HTTP pour les extensions
│   │       ├── dom-bridge.js         sélecteurs CSS/XPath (Cheerio)
│   │       ├── crypto-bridge.js      AES, déobfuscation
│   │       └── prefs-bridge.js       préférences fichier par source
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── railway.toml                · Railway config (reste dans server/)
│   └── .env.example
│
├── deployment/                   ← Configs & guides de déploiement
│   ├── README.md                   · Toutes les options (Railway, Render, Docker, Colab, HF, RunPod)
│   ├── render.yaml                 · Config Render (copie de référence — source de vérité = racine)
│   ├── shorebird.yaml              · Config Shorebird — ARCHIVÉ (service fermé août 2026)
│   └── colab_deploy.ipynb
│
├── rust/                         ← Bibliothèque Rust (flutter_rust_bridge 2.x)
├── go/                           ← Client BitTorrent + serveur streaming HTTP
├── proto/                        ← Protobuf schemas (backup Aniyomi/Mihon)
├── assets/                       ← Images, fonts, animations, icônes
├── docs/                         ← Documentation interne (extensions, settings)
│
├── render.yaml                   ← Config Render (DOIT rester à la racine — Render l'exige)
├── pubspec.yaml                  ← Manifest Flutter (DOIT rester à la racine)
├── analysis_options.yaml         ← Config Dart analyzer (racine exigée)
├── l10n.yaml                     ← Config localisation Flutter (racine exigée)
├── devtools_options.yaml         ← Config Flutter DevTools (racine exigée)
├── ffigen.yaml                   ← Config FFI gen — bindings torrent Go (racine exigée)
├── flutter_rust_bridge.yaml      ← Config FRB — bindings Rust (racine exigée)
│
├── AGENT.md                      ← Raccourci vers .agent/README.md
├── README.md                     ← README public du projet
├── CHANGELOG.md
└── LICENSE                       ← Apache 2.0
```

### Règle sur les YAML à la racine

| Fichier | Obligatoire racine | Pourquoi |
|---|---|---|
| `pubspec.yaml` | ✅ Oui | Flutter SDK l'exige |
| `analysis_options.yaml` | ✅ Oui | Dart analyzer |
| `l10n.yaml` | ✅ Oui | flutter gen-l10n |
| `devtools_options.yaml` | ✅ Oui | Flutter DevTools |
| `ffigen.yaml` | ✅ Oui | flutter pub run ffigen |
| `flutter_rust_bridge.yaml` | ✅ Oui | flutter_rust_bridge CLI |
| `render.yaml` | ✅ Oui | Render le lit depuis la racine du repo |
| `shorebird.yaml` | ❌ Archivé | Service fermé — déplacé dans `deployment/` |

---

## 3. Les deux modes serveur

Watchtower expose exactement la même API REST via deux runtimes différents.

| Mode | Fichiers | Port | Utilisé quand |
|---|---|---|---|
| **Embarqué** | `lib/remote/` (Dart + shelf) | 4567 | App installée sur téléphone ou desktop |
| **Headless** | `server/` (Node.js + Express) | 8080 / 10000 | Déploiement cloud sans app Flutter |

Les extensions JS s'exécutent identiquement dans les deux modes via QuickJS.

---

## 4. Stack technique

| Couche | Tech | Version |
|---|---|---|
| Langage app | Dart | 3.10+ |
| Framework UI | Flutter | 3.38+ |
| State | Riverpod | 3.1.0 |
| Navigation | GoRouter | 17.2.0 |
| DB locale | Isar community | 3.3.2 |
| Préférences | Hive | 2.2.3 |
| Vidéo | media_kit (kodjodevf fork) | git ref f5796d2 |
| Extensions JS | QuickJS (FFI) | — |
| Rust | flutter_rust_bridge | 2.x |
| Go | torrent + streaming | — |
| Serveur embarqué | shelf | — |
| Serveur headless | Node.js 20 + Express | — |
| CI | GitHub Actions | — |
| Docs | VitePress + Vercel | — |

---

## 5. Règles immuables

1. **`render.yaml` reste à la racine de watchtower** — Render le lit depuis là
2. **`server/railway.toml` reste dans `server/`** — Railway le lit depuis le root du service
3. **Le keystore Reel ne change jamais** — `KEYSTORE_BASE64` secret GitHub, alias `reel`
4. **watchtower ne s'importe pas son propre SDK** — il produit l'API, point
5. **Mêmes versions de packages** entre watchtower et watchtower-real pour éviter les conflits à la fusion
6. **Pas de `build_runner`** dans watchtower-real tant qu'il n'y a pas de codegen actif
7. **`shorebird.yaml` est archivé dans `deployment/`** — service fermé, ne plus utiliser

---

## 6. TODOs restants

### watchtower-real (Reel)
- [ ] `feed_page.dart` — tap-and-hold pause, double-tap like
- [ ] `feed_provider.dart` — pagination infinie
- [ ] Settings screen — config serveur + sélection source + choix UI
- [ ] `lib/ui/tiktok/` dans watchtower — scaffold + git dep dans pubspec.yaml
- [ ] `lib/ui/netflix/` dans watchtower — renommer UI actuelle pour structure multi-UI

### watchtower (serveur)
- [ ] `deployment/` — HuggingFace Dockerfile + RunPod.md documentés, à tester
- [ ] CI merge-ui — workflow auto-PR quand watchtower-real/main est mis à jour

### watchtower-website
- [ ] Pages guides vides (Musique, Novels) → à remplir
- [ ] Page `architecture.md` → diagramme complet two-server + multi-UI
