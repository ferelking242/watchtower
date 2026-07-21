# AGENT.md — Guide de continuation pour agents IA

> Lis ce fichier en entier avant de coder. Il te donne le contexte complet du projet.

---

## 0. Setup obligatoire

```bash
# Demande le secret GITHUB_PAT à l'utilisateur (scope: repo, workflow)
# Puis clone les deux repos à la racine de ton espace de travail :

git clone https://ferelking242:<GITHUB_PAT>@github.com/ferelking242/watchtower.git
git clone https://ferelking242:<GITHUB_PAT>@github.com/ferelking242/watchtower-real.git
git clone https://ferelking242:<GITHUB_PAT>@github.com/ferelking242/watchtower-website.git

# Config git dans chaque repo
cd watchtower       && git config user.email "agent@replit.com" && git config user.name "Replit Agent" && cd ..
cd watchtower-real  && git config user.email "agent@replit.com" && git config user.name "Replit Agent" && cd ..
cd watchtower-website && git config user.email "agent@replit.com" && git config user.name "Replit Agent" && cd ..
```

---

## 1. Vue d'ensemble du projet

**Watchtower** est une app Flutter open-source (fork Mangayomi) qui lit manga, anime, séries, musique et novels via des extensions JavaScript.

### Repos

| Repo | Rôle | Tech |
|---|---|---|
| `ferelking242/watchtower` | App principale — tout y vit | Flutter + Rust + Go + Node.js |
| `ferelking242/watchtower-real` | UI TikTok-style (feed vertical) | Flutter uniquement — se fusionne dans watchtower |
| `ferelking242/watchtower-website` | Site docs | VitePress, hébergé sur Vercel |

---

## 2. Architecture du repo `watchtower`

```
watchtower/
├── lib/
│   ├── modules/          ← features UI par type média (anime, manga, music, novels, player)
│   ├── eval/             ← moteur JS/Dart (QuickJS) — exécute les extensions
│   ├── remote/           ← serveur HTTP embarqué (shelf) — port 4567
│   ├── services/         ← réseau, téléchargements (Aria2), anti-bot
│   ├── ffi/              ← serveur torrent Go (bindings C)
│   └── src/rust/         ← bindings Rust (EPUB, image, TLS custom)
├── server/               ← Serveur Node.js headless (déploiement cloud)
│   ├── server.js         ← Express + QuickJS VM + bridges
│   ├── src/bridges/      ← HTTP, DOM (Cheerio), crypto, prefs
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── railway.toml
│   └── .env.example
├── deployment/           ← Guides et configs de déploiement
│   ├── README.md         ← Guide complet toutes options de déploiement
│   └── colab_deploy.ipynb
├── render.yaml           ← Config Render (doit rester à la racine)
├── rust/                 ← Bibliothèque Rust (flutter_rust_bridge)
└── go/                   ← Client BitTorrent + streaming HTTP
```

### Deux modes serveur

| Mode | Où | Comment |
|---|---|---|
| **Embarqué** | `lib/remote/` | shelf HTTP — l'app expose le port 4567 |
| **Headless** | `server/` | Node.js autonome — cloud (Railway, Render, Docker…) |

Les deux exécutent les mêmes extensions JS et exposent la même API REST.

---

## 3. Architecture du repo `watchtower-real` (UI Reel)

```
watchtower-real/app/watchtower-real/
├── lib/
│   ├── main.dart                    ← MediaKit.ensureInitialized() + Hive + Riverpod
│   ├── app.dart                     ← ReelApp (MaterialApp.router)
│   ├── shell.dart                   ← Export public : ReelShell (entry pour watchtower)
│   ├── router/router.dart           ← GoRouter
│   ├── core/theme/                  ← tokens, thème dark
│   ├── remote/                      ← RemoteApiClient HTTP → serveur watchtower
│   └── features/
│       └── feed/
│           ├── feed_screen.dart     ← PageView + pool de Players media_kit
│           ├── providers/feed_provider.dart
│           ├── models/feed_item.dart
│           └── widgets/
│               ├── feed_page.dart   ← VideoController(player) + thumbnail fallback
│               ├── feed_header.dart
│               ├── feed_sidebar.dart
│               └── feed_overlay_bottom.dart
├── android/app/
│   ├── build.gradle                 ← applicationId: com.watchtower.reel
│   └── ...
├── .github/workflows/
│   ├── build-apk.yml                ← arm64, keystore depuis secret KEYSTORE_BASE64
│   └── build-ipa.yml                ← TrollStore
└── pubspec.yaml                     ← name: reel
```

**Package Flutter name:** `reel`  
**Android applicationId:** `com.watchtower.reel`  
**Keystore alias:** `reel` / **mot de passe:** `reelwatchtower`

### Preloading pool (implémenté dans feed_screen.dart)

```
Page actuelle → player.play()
Page N±1      → player.open(url, play: false)  ← buffer en avance
Pages hors fenêtre → player.dispose()
```

---

## 4. Architecture multi-UI — comment d'autres UIs fusionnent dans watchtower

### Le principe retenu

**Chaque UI = un repo Flutter indépendant qui est importé via git URL dans pubspec.yaml de watchtower.**

```yaml
# watchtower/pubspec.yaml (quand la fusion est faite)
dependencies:
  reel:                           # package name de watchtower-real
    git:
      url: https://github.com/ferelking242/watchtower-real.git
      path: app/watchtower-real
      ref: main
  # future UI:
  # watchtower_youtube:
  #   git:
  #     url: https://github.com/ferelking242/watchtower-youtube.git
  #     path: app/watchtower-youtube
  #     ref: main
```

Flutter `pub get` tire le code directement — aucune copie de fichiers, aucun patch d'imports.

### Pourquoi cette méthode (vs alternatives)

| Option | Verdict |
|---|---|
| **Git dep pubspec** ✅ | Retenu — Flutter-natif, zéro script CI, hot-reload intact, résolution automatique des deps |
| Monorepo Melos | Bien pour tout-en-un, mais impose de déplacer les repos dans un seul — trop lourd ici |
| CI rsync + patch | Copie de fichiers + patch d'imports = fragile, maintenance élevée |
| Git submodules | Complexe à gérer, HEAD détaché fréquent |
| Flutter flavors | Build-time seulement, pas de switch runtime |

### Convention que chaque repo UI DOIT respecter

1. **Package name snake_case court** (`reel`, `watchtower_yt`, `watchtower_spotify`…)
2. **`lib/shell.dart`** exporte le widget d'entrée :
   ```dart
   export 'features/feed/feed_screen.dart' show FeedScreen;
   ```
3. **Deps partagées** déclarées avec contraintes larges (`^3.0.0`) — watchtower fait l'override final
4. **`lib/main.dart`** reste pour le build standalone (dev), retiré à l'intégration
5. **`ui.json`** (optionnel) : métadonnées (id, label, description, icon)

### Structure dans watchtower après fusion de N UIs

```
watchtower/lib/ui/
├── ui_registry.dart        ← enum UiMode { netflix, tiktok, youtube, … }
├── ui_shell.dart           ← ConsumerWidget qui switche selon UiMode (prefs Hive)
├── netflix/                ← UI actuelle (déjà dans watchtower/lib/modules/)
│   └── netflix_shell.dart
├── tiktok/                 ← depuis package 'reel' (watchtower-real)
│   └── (importé via pubspec git dep, pas de fichiers copiés)
└── youtube/                ← futur
```

```dart
// lib/ui/ui_shell.dart
class UiShell extends ConsumerWidget {
  Widget build(context, ref) => switch (ref.watch(uiModeProvider)) {
    UiMode.netflix => const NetflixShell(),
    UiMode.tiktok  => const FeedScreen(),   // depuis package:reel
    UiMode.youtube => const YoutubeShell(), // depuis package:watchtower_yt
  };
}
```

---

## 5. Site docs (`watchtower-website`)

- Framework : **VitePress**
- Hébergé : **Vercel** → `watchtower-website-zeta.vercel.app`
- Sources : `website/src/`
- Config sidebar : `website/src/.vitepress/config/navigation/sidebar.ts`
- Config navbar  : `website/src/.vitepress/config/navigation/navbar.ts`
- Pages docs     : `website/src/docs/` (markdown)

Pour ajouter une page :
1. Crée `website/src/docs/<section>/<nom>.md`
2. Ajoute l'entrée dans `sidebar.ts`
3. `git add && git commit && git push` → Vercel rebuild automatiquement

---

## 6. Keystore Android (Reel)

Le keystore permanent est stocké encodé en base64 dans le secret GitHub **`KEYSTORE_BASE64`** du repo `watchtower-real`.

```
Alias         : reel
Store password: reelwatchtower
Key password  : reelwatchtower
```

**À faire une seule fois** : aller dans `watchtower-real` → Settings → Secrets → New secret :
- `KEYSTORE_BASE64` = valeur fournie par l'agent ou l'admin
- `KEY_PASSWORD` = `reelwatchtower`
- `STORE_PASSWORD` = `reelwatchtower`

Sans ce secret, le workflow génère un keystore temporaire à chaque build → les mises à jour APK ne fonctionnent pas.

---

## 7. TODOs restants

### watchtower-real (Reel)
- [ ] **`feed_page.dart`** — ajouter tap-and-hold pause, double-tap like
- [ ] **`feed_provider.dart`** — pagination infinie (charger la page suivante quand l'index approche de la fin)
- [ ] **Settings screen** — page de configuration serveur + sélection de source + choix UI
- [ ] **`lib/ui/tiktok/` dans watchtower** — créer le scaffold de dossier et ajouter la git dep dans watchtower/pubspec.yaml
- [ ] **`lib/ui/netflix/` dans watchtower** — renommer l'UI actuelle pour la structure multi-UI

### watchtower (serveur)
- [ ] **`deployment/`** — huggingface Dockerfile + runpod.md déjà documentés, restent à tester
- [ ] **CI merge-ui** — workflow qui PRe automatiquement quand watchtower-real/main est mis à jour (optionnel car on passe par git dep)

### watchtower-website
- [ ] Pages guides vides (`Musique`, `Novels`) → à remplir
- [ ] Page `architecture.md` → diagramme complet two-server + multi-UI

---

## 8. Stack complet

| Couche | Tech |
|---|---|
| App UI principale | Flutter 3.38+, Dart 3.10+ |
| State management | Riverpod 3.x |
| DB locale | Isar (community fork) |
| Prefs | Hive 2.x |
| Video | media_kit (kodjodevf fork) |
| Navigation | GoRouter 17.x |
| Extensions JS | QuickJS (via ffi) |
| Réseau | Dart http 1.x + shelf |
| Rust | flutter_rust_bridge 2.x |
| Go | torrent (Aria2 + streaming) |
| Serveur headless | Node.js 20 + Express + QuickJS VM |
| CI | GitHub Actions |
| Docs | VitePress + Vercel |
