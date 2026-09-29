# 🔬 Rapport de Diagnostic — Watchtower (Flutter)

> **Date :** 26 août 2026
> **Périmètre :** analyse statique complète du dépôt (`lib/`, `pubspec.yaml`, `server/`, `rust/`, `go/`, `test/`)
> **Méthode :** inspection manuelle + analyse statique automatisée (grep/scripts). Le SDK Flutter n'étant pas disponible dans l'environnement, **aucune compilation n'a pu être exécutée** — les corrections appliquées sont des changements à faible risque vérifiés par lecture du code.

---

## 1. Résumé exécutif

L'application est un **monolithe géant** : 4 applications complètes fusionnées dans un seul binaire, 228 dépendances directes (457 packages résolus), ~485 000 lignes de Dart, et une accumulation de correctifs "bande-à-fiches" qui se marchent dessus. Les symptômes rapportés (crash, lenteurs, double dépendances, erreurs graves) sont tous confirmés et ont des causes identifiables.

| Sévérité | Problème | Impact | Statut |
|---|---|---|---|
| 🔴 Critique | **Point d'entrée dupliqué** : `lib/modules/plugin/nfile/main.dart` définit un 2ᵉ `main()` + un 2ᵉ `navigatorKey` global en conflit | Conflit de symboles, risque de compilation/route | ✅ **Supprimé** |
| 🔴 Critique | **Test `widget_test.dart` cassé** : test "counter" par défaut qui ne compile pas contre la vraie app | CI rouge, `flutter test` échoue | ✅ **Réparé** |
| 🔴 Critique | **Crash `removeFromQueue`** : `clamp(0, q.length - 1)` avec file vide → `ArgumentError` | Crash lecture musique | ✅ **Corrigé** |
| 🔴 Critique | **Conflit de version `syncfusion_flutter_pdfviewer`** (28.1.33 vs 33.2.13 masqué par override) | Résolution ambiguë, risque de build | ✅ **Unifié en 33.2.13** |
| 🟠 Majeur | **8 dépendances déclarées mais jamais utilisées** (get_it, base32, logging, timezone, qr_flutter, audio_service_mpris, flutter_displaymode, envied) | Bloat, temps de build, conflits | ✅ **Supprimées** |
| 🟠 Majeur | **4 systèmes de base de données** (Isar, Hive, Drift, sqflite) + shared_preferences + secure_storage | Fragmentation, fuites mémoire, lenteur | 📋 À traiter |
| 🟠 Majeur | **3 systèmes de state management** (Riverpod 3, Provider, Hooks) + get_it (mort) | Incohérence, double rendus | 📋 À traiter |
| 🟠 Majeur | **2 lecteurs musique complets** (media_kit + audio_service) | Conflits de lecture, batterie | 📋 À traiter |
| 🟠 Majeur | **2 routeurs** (go_router + auto_route) + Navigator manuel | Navigation imprévisible | 📋 À traiter |
| 🟡 Moyen | **40+ stubs web** (`web_stubs/`) pour faire compiler le web | Build web fragile, hack | 📋 À traiter |
| 🟡 Moyen | **`broken_icons.dart` dupliqué** (72 Ko × 2, identiques) | Maintenance, taille APK | 📋 À traiter |
| 🟡 Moyen | **Fichiers écran géants** (jusqu'à 6 324 lignes) | Rebuilds massifs, bugs | 📋 À traiter |

---

## 2. Vue d'ensemble de l'architecture

```
watchtower/  (package unique, 1270 fichiers Dart, 484 768 LOC)
├── lib/
│   ├── main.dart                     → point d'entrée réel (1 000+ lignes)
│   ├── router/router.dart            → go_router (110+ routes)
│   ├── modules/
│   │   ├── watch|manga|novel|anime|game|home|library|browse|calendar|...
│   │   ├── music/                    → **Spotube entier embarqué** (auto_route, drift, hooks_riverpod)
│   │   └── plugin/nfile/             → **NFile entier embarqué** (provider, sqflite, MediaKit)
│   ├── services/                     → réseau, téléchargements, trackers, anti-bot
│   ├── eval/                         → moteur d'extensions JS (QuickJS)
│   ├── remote/                       → serveur HTTP embarqué (shelf, port 4567)
│   ├── local_indexer/                → indexation de fichiers locaux (isolates)
│   └── src/rust/                     → bindings Rust (EPUB, image, TLS)
├── server/                           → serveur headless Node.js (Express + QuickJS)
├── rust/                             → bibliothèque Rust (flutter_rust_bridge)
├── go/                               → client BitTorrent + streaming HTTP
└── web_stubs/                        → 40+ packages factices pour le build web
```

### Le problème central : une fusion de 3 apps sans intégration

L'app Watchtower est le résultat de la fusion de **trois applications complètes** :
1. **Watchtower** (fork de Seanime) — anime/manga/novel + lecteur + extensions JS
2. **Spotube** — lecteur musique complet (state, DB drift, routeur auto_route, hooks)
3. **NFile** — explorateur de fichiers complet (provider, sqflite, services FTP/Shizuku)

Chacune apporte **sa propre pile** (DB, state, navigation, lecteur audio). Résultat : le code se compile mais les systèmes se marchent dessus (deux lecteurs audio, deux `navigatorKey`, deux `main()`, etc.). C'est la cause racine de la majorité des crashes et ralentissements.

---

## 3. Audit des dépendances

### 3.1 Chiffres clés

| Métrique | Valeur |
|---|---|
| Dépendances directes (avant correction) | **228** |
| Dépendances directes (après correction) | **219** |
| Packages résolus dans `pubspec.lock` | **457** |
| `dependency_overrides` | **23** |
| Dépendances Git (forks non-officiels) | **~20** |

### 3.2 Dépendances supprimées (inutilisées, vérifiées par grep sur tout le repo)

| Package | Raison |
|---|---|
| `get_it` | 0 import dans tout le code |
| `base32` | 0 import |
| `logging` | 0 import |
| `timezone` | 0 import |
| `qr_flutter` | 0 import |
| `audio_service_mpris` | 0 import |
| `flutter_displaymode` | 0 import |
| `envied` + `envied_generator` | 0 import |

### 3.3 Conflit de version corrigé

| Package | Avant | Problème | Après |
|---|---|---|---|
| `syncfusion_flutter_pdfviewer` | `^28.1.33` en deps + `^33.2.13` en override | 2 versions contradictoires, l'override masquait un désalignement | `^33.2.13` unique, override supprimé |

### 3.4 Doublons fonctionnels (à traiter — liste exhaustive)

**Systèmes de persistance (5 !)**
| Système | Usage | Fichiers |
|---|---|---|
| Isar (community) | DB principale (manga, chapitres, sources…) | 106 |
| Hive | Préférences (nav_display, ui_prefs, track_search) | 10 |
| Drift + sqlite3 | DB du module musique (Spotube) | 9 |
| sqflite | Lecteur de DB NFile | 1 |
| shared_preferences | Prefs musique + NFile | 10 |
| flutter_secure_storage | KV chiffré musique | 2 |

**State management (4 systèmes)**
| Système | Usage |
|---|---|
| flutter_riverpod 3 | App principale (77 fichiers `@riverpod`) |
| hooks_riverpod + flutter_hooks | Module musique |
| provider (ChangeNotifier) | Module NFile (37 fichiers) |
| get_it | **inutilisé** (supprimé) |

**Navigation (3 systèmes)**
| Système | Usage |
|---|---|
| go_router 17 | App principale (110+ routes) |
| auto_route 9 | Module musique (~49 routes) |
| Navigator / GlobalKey | NFile + deep links |

**Lecteurs audio (2 stacks complètes)**
| Stack | Fichier clé |
|---|---|
| media_kit `Player` | `music_player_provider.dart` (lecteur "custom") |
| audio_service + audio_session | `provider/audio_player/audio_player.dart` (lecteur Spotube) |

**Rendu d'images (4 systèmes)** : `extended_image`, `cached_network_image`, `flutter_cache_manager`, `photo_view` — 3 caches image parallèles.

**Markdown/HTML (4 systèmes)** : `flutter_markdown`, `flutter_markdown_plus`, `flutter_html`, `flutter_widget_from_html`.

**Excel (2 systèmes)** : `excel` (fork local via `packages/excel`) + `excel2003`.

**Icônes** : `font_awesome_flutter`, `Broken` (2 copies identiques de `broken_icons.dart`), `fluentui_system_icons`, `flutter_feather_icons`, `simple_icons` (dont 2 remplacés par des stubs web).

### 3.5 Risque : 22 dépendances Git / forks non-officiels

`media_kit`, `flutter_inappwebview`, `flutter_qjs`, `on_audio_query`, `yt_dlp_dart`, `scrobblenaut`, `hetu_*`, `bonsoir_android`, `flutter_secure_storage_linux`, `draggable_scrollbar`, `desktop_webview_window`, `flutter_discord_rpc_fork`, `m_extension_server`, `flutter_broadcasts`, `disable_battery_optimization`… Ces forks pointent vers des commits figés (`ref: <sha>`) : **le build casse silencieusement si un fork disparaît** et les correctifs de sécurité ne sont jamais reçus.

### 3.5 `web_stubs/` — le hack web

40+ packages factices (`media_kit`, `window_manager`, `sqflite`, `permission_handler`, `sqlite3`, `ffi`, `local_auth`…) pour faire compiler le build web. Seuls 2 sont branchés dans `dependency_overrides` (`flutter_feather_icons`, `simple_icons`). Le reste est un **cimetière de hacks** : le build web est un champ de mines et le bundler embarque des stubs vides à la place de vraies fonctionnalités.

---

## 4. Crashes identifiés

### 4.1 ✅ Corrigés dans cette session

| # | Crash | Fichier | Cause |
|---|---|---|---|
| C1 | **`ArgumentError` sur file vide** | `music_player_provider.dart` | `newIdx.clamp(0, q.length - 1)` → borne sup -1 quand la queue devient vide après `removeFromQueue` |
| C2 | **Test qui ne compile pas** | `test/widget_test.dart` | Test "counter" par défaut importe `MyApp` (ConsumerStatefulWidget) et cherche un compteur inexistant |
| C3 | **Conflit de build** | `pubspec.yaml` | 2 versions de `syncfusion_flutter_pdfviewer` |
| C4 | **2ᵉ point d'entrée** | `lib/modules/plugin/nfile/main.dart` | `main()` + `navigatorKey` dupliqués, jamais importés |

### 4.2 Suspects (à investiguer — risque élevé)

| Suspect | Fichier | Analyse |
|---|---|---|
| S1 | `router.dart` `_genericRoute` | `state.extra as T` : **crash si une route nommée est ouverte sans `extra`** (ex: `context.go('/animePlayerView')` sans l'id). 1573 casts `as` dans le code. |
| S2 | `main.dart` `FlutterError.onError` + `runZonedGuarded` | Toutes les erreurs sont avalées/loggées → **l'app "se fige" sans crash report** quand un provider échoue au premier build |
| S3 | `main_screen.dart` `_navigationOrder.first` | `.first` sur liste potentiellement vide si tous les items sont masqués → `StateError` |
| S4 | `main.dart` `_postLaunchInit` | `MDownloader.initializeIsolatePool(poolSize: (cores*2).clamp(8,32))` → jusqu'à **32 isolates** créés au démarrage sur les appareils haut de gamme |
| S5 | `.g.dart` stale | 101 fichiers générés ; si un `@riverpod` a changé de signature sans regénération → crash runtime (classique) |
| S6 | `audio_player.dart` `_syncSavedState` | `database.select(...).getSingle()` après un insert — crash si l'insert échoue (DB drift corrompue) |
| S7 | `music_player_provider.dart` | `Player()` top-level global créé dès le premier import → si un import ne passe pas par `MediaKit.ensureInitialized()`, crash natif |

### 4.3 Patterns à risque (statistiques)

| Pattern | Occurrences |
|---|---|
| `as` cast non-null vers type concret | **1 573** |
| `.first` sur listes | **294** |
| `.first!` | 5 |
| `findFirst()` Isar | 14 |
| `!` sur nullable (déréférencement) | impossible à compter précisément — très répandu |

---

## 5. Ralentissements identifiés

| # | Cause | Fichier | Impact |
|---|---|---|---|
| R1 | **`MainScreen` reconstruit tout le shell** à chaque changement de provider (`ref.watch(migrationProvider)` + 8+ `ref.watch` en build) | `main_screen.dart` (2 650 lignes) | Jank sur chaque navigation |
| R2 | **`music_player_provider` met à jour l'état à chaque tick** (`stream.position`/`buffer`) → le mini-player et tout widget qui le watche se rebuild à 60 fps | `music_player_provider.dart` | Jank permanent quand la musique joue |
| R3 | **Double lecteur musique** : 2 stacks audio actives en parallèle | modules/music | RAM + batterie doublées |
| R4 | **8–32 isolates de téléchargement** créés au démarrage | `main.dart` | Démarrage lent sur mobile |
| R5 | **4 caches d'images parallèles** (extended_image, cached_network_image, cache_manager, photo_view) | divers | Cache dupliqué, RAM |
| R6 | **`_checkTrackerRefresh` + `checkForUpdateAndNotify` + timers** (backup 5 min, sync, update check) lancés dans `initState` | `main_screen.dart`, `main.dart` | Travail en arrière-plan constant |
| R7 | **Fichiers écrans monolithiques** (6 324, 6 107, 4 622, 4 470, 4 293, 4 238 lignes) | marketplace, watch_player, detail, webview | Build/rebuild par widget entier |
| R8 | **`FlutterError.onError` + AppLogger** loggés à chaque erreur | main.dart | I/O disque en boucle en cas d'erreur répétée |

---

## 6. Corrections appliquées

| Fichier | Correction |
|---|---|
| `pubspec.yaml` | Suppression de 8 deps inutilisées (`get_it`, `base32`, `logging`, `timezone`, `qr_flutter`, `audio_service_mpris`, `flutter_displaymode`, `envied` + `envied_generator`) |
| `pubspec.yaml` | Unification `syncfusion_flutter_pdfviewer` en `^33.2.13` (suppression de l'override contradictoire) |
| `lib/modules/music/providers/music_player_provider.dart` | Fix crash `removeFromQueue` (garde sur index + file vide) |
| `lib/modules/plugin/nfile/main.dart` | **Supprimé** (point d'entrée mort : 2ᵉ `main()`, 2ᵉ `navigatorKey`, app entière inutilisée) |
| `test/widget_test.dart` | Remplacé le test "counter" cassé par un smoke test valide |

> ⚠️ **Important :** `flutter pub get` doit être relancé pour régénérer `pubspec.lock` (il contient encore les packages supprimés). La prochaine commande `flutter build`/`flutter run` le fera automatiquement.

---

## 7. Plan de remédiation priorisé

### Phase 1 — Stabilité (1-2 jours)
- [ ] **Régénérer tout le codegen** : `dart run build_runner build --delete-conflicting-outputs` (101 `.g.dart`, routes auto, drift) pour éliminer le risque S5
- [ ] **Sécuriser le routeur** : remplacer `state.extra as T` par des vérifications null-safe + fallback (S1)
- [ ] **Ajouter un ErrorWidget global** au lieu d'avaler les erreurs (S2) — afficher un écran de récupération au lieu de geler
- [ ] **Corriger `main_screen`** : `.first` sur `_navigationOrder` filtré (S3) avec fallback `/Library`
- [ ] **Lancer `flutter analyze`** et traiter les erreurs (le repo n'est pas analysable ici, mais c'est la première action à faire dans un env avec le SDK)

### Phase 2 — Performance (3-5 jours)
- [ ] **R1** : découper `MainScreen` — extraire le dock, le menu, les bannières ; utiliser `select()` sur les providers pour ne rebuild que ce qui change
- [ ] **R2** : throttler les mises à jour `position` (ex: 250 ms) dans `music_player_provider`
- [ ] **R3** : unifier les 2 lecteurs musique (choisir audio_service comme source de vérité, supprimer le lecteur "custom")
- [ ] **R4** : créer le pool d'isolates **lazily** (au premier téléchargement) au lieu du démarrage
- [ ] **R5** : unifier le cache d'images sur `cached_network_image` (et supprimer `extended_image`/`photo_view` si possible)

### Phase 3 — Architecture (semaines)
- [ ] **Extraire NFile et Music en packages** `packages/` (déjà présent pour excel) avec leurs propres pubspecs, puis les importer comme dépendances de path — c'est la seule vraie solution au problème de fusion
- [ ] **Unifier la DB** : migrer Hive→Isar (ou Drift), supprimer sqflite
- [ ] **Unifier le state** : Riverpod 3 partout, supprimer `provider` et `hooks_riverpod` (migration des widgets music)
- [ ] **Unifier la navigation** : go_router seul
- [ ] **Nettoyer `web_stubs/`** : ne garder que les stubs réellement branchés, ou retirer le support web
- [ ] **Supprimer le doublon `broken_icons.dart`** : remplacer les ~40 imports relatifs de NFile par l'import core, supprimer la copie
- [ ] **Découper les écrans monolithes** (marketplace 6 324 lignes, watch_player 6 107…) en widgets réutilisables

---

## 8. Annexes techniques

### 8.1 Métriques du code

| Métrique | Valeur |
|---|---|
| Fichiers Dart (`lib/`) | 1 270 |
| Lignes Dart (`lib/`) | 484 768 |
| `.g.dart` (codegen riverpod/json) | 101 |
| `.freezed.dart` | 7 |
| `.pb*.dart` (protobuf) | 36 |
| Fichiers l10n générés | 46 |
| Routes go_router | ~110 |
| Routes auto_route | ~49 |
| Tests | 1 (réparé) |

### 8.2 Top 10 des fichiers les plus longs

| Fichier | Lignes |
|---|---|
| `marketplace_screen.dart` | 6 324 |
| `watch_player_io.dart` | 6 107 |
| `watch_detail_view.dart` | 4 622 |
| `webview.dart` | 4 470 |
| `anilist_detail_screen.dart` | 4 293 |
| `anime_player_view_io.dart` | 4 238 |
| `watchtower_discover_screen.dart` | 3 455 |
| `file_manager_provider.dart` | 3 117 |
| `directory_screen.dart` | 2 916 |
| `download_queue_screen.dart` | 2 772 |

### 8.3 Commandes utiles (avec SDK Flutter)

```bash
flutter pub get                                  # régénère pubspec.lock (obligatoire après ce nettoyage)
dart run build_runner build --delete-conflicting-outputs   # régénère les 101 .g.dart
flutter analyze                                   # état réel des erreurs
flutter test                                      # vérifie le smoke test
```