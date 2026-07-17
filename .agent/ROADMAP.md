# Roadmap — Watchtower

> Statuts : ✅ Fait | 🚧 En cours | 📋 Planifié | ❌ Abandonné  
> Dernière mise à jour : 2026-07-17

---

## Session 2026-07-17 (agent session 4) — ajouts

| Tâche | Statut | Repo | Notes |
|---|---|---|---|
| Double-tap like (animation cœur) | ✅ | watchtower-real | `_HeartBurst` HookWidget, scale+opacity, positionné au tap |
| Long-press pause | ✅ | watchtower-real | `onLongPressStart/End/Cancel`, indicateur visuel |
| Progress bar vidéo (thin bottom) | ✅ | watchtower-real | `_VideoProgressBar` StreamBuilder position/duration |
| Fix CI APK workflow (keystore) | ✅ | watchtower-real | Décode KEYSTORE_BASE64, fallback keytool, build release |
| Fix CI IPA workflow (Xcode 16 signing) | ✅ | watchtower-real | Patch pbxproj + Podfile après flutter create → no-codesign |

---

## Session 2026-07-17 (agent session 3) — ajouts

| Tâche | Statut | Repo | Notes |
|---|---|---|---|
| Fix `valueOrNull` → `.asData?.value` | ✅ | watchtower-real | Bug Riverpod 3.x dans `connect_screen.dart` |
| Pagination infinie feed | ✅ | watchtower-real | `loadMore()` dans FeedNotifier + déclencheur onPageChanged |
| Spinner "loading more" | ✅ | watchtower-real | `_LoadingMoreIndicator` + `loadingMoreProvider` |

---

## Session 2026-07-17 (agent) — ajouts

| Tâche | Statut | Repo | Notes |
|---|---|---|---|
| Serveur headless lancé ici (Replit) | ✅ | watchtower | Node.js 20, port 8080, `/api/ping` OK, 114 sources |
| `ProfileScreen` — page Compte | ✅ | watchtower-real | AppBar + icône 3-barres → /connect |
| `FriendsScreen` — page Amis | ✅ | watchtower-real | Tabs Suggérés/Abonnements, follow animé |
| `InboxScreen` — page Boîte | ✅ | watchtower-real | Tabs Tout/Mentions/Activité, badge unread |
| Routes /profile /friends /inbox | ✅ | watchtower-real | router.dart mis à jour |
| Bottom nav branchée sur les pages | ✅ | watchtower-real | Amis→/friends Boîte→/inbox Profil→/profile |
| Config serveur retirée de l'accueil | ✅ | watchtower-real | /connect accessible via Profil → 3-barres |
| Fix build APK : dependency_overrides | ✅ | watchtower-real | media_kit_video conflit @HEAD corrigé |
| Build APK déclenché (CI) | 🚧 | watchtower-real | run in_progress après fix |

---

## Phase 0 — Fondations (✅ Complété)

| Tâche | Statut | Date | Notes |
|---|---|---|---|
| Fork Mangayomi → watchtower | ✅ | — | Repo principal `ferelking242/watchtower` |
| README.md watchtower réécrit | ✅ | 2026-07-17 | Logo, badges, architecture, deploy buttons |
| Serveur headless Node.js dans `server/` | ✅ | 2026-07-17 | Express + QuickJS VM + bridges |
| Dossier `deployment/` propre | ✅ | 2026-07-17 | README multi-options, colab déplacé |
| CI `build-server.yml` watchtower | ✅ | 2026-07-17 | Smoke test Node 20 + Docker push GHCR |
| Repo `watchtower-real` créé | ✅ | — | UI TikTok-style standalone |
| Rename watchtower-real → Reel | ✅ | 2026-07-17 | package: reel, ID: com.watchtower.reel |
| Keystore permanent Reel | ✅ | 2026-07-17 | PKCS12 openssl, secrets GitHub configurés |
| Preloading pool media_kit dans Reel | ✅ | 2026-07-17 | Pool [i-1, i, i+1] Players |
| migration video_player → media_kit (Reel) | ✅ | 2026-07-17 | feed_page.dart réécrit |
| Suppression build_runner/codegen Reel | ✅ | 2026-07-17 | Build plus rapide |
| `lib/shell.dart` dans Reel | ✅ | 2026-07-17 | Export public pour intégration watchtower |
| Site docs VitePress | ✅ | — | watchtower-website-zeta.vercel.app |
| Page docs `/guides/remote-server` | ✅ | 2026-07-17 | Guide complet deploy serveur |
| Page docs `/guides/ui-architecture` | ✅ | 2026-07-17 | Pattern git dep, convention repos UI |
| Dossier `.agent/` dans watchtower | ✅ | 2026-07-17 | Ce dossier |
| `AGENT.md` dans watchtower | ✅ | 2026-07-17 | Guide rapide pour agents |

---

## Session 2026-07-17 (agent session 5) — ajouts

| Tâche | Statut | Repo | Notes |
|---|---|---|---|
| Exposer `getRaw()` dans SDK Dart | ✅ | watchtower-sdk-dart | GET brut avec retry+auth — commit c211df4 |
| Remplacer `RemoteApiClient` par adaptateur SDK | ✅ | watchtower-real | pubspec git dep + remote_client.dart réécrit — commit ceba6fd |

---

## Phase 1 — SDK (✅ Complété pour Reel)

| Tâche | Statut | Repo cible | Notes |
|---|---|---|---|
| `server/openapi.yaml` | ✅ | watchtower | Spec OpenAPI 3.1 complète — 10 endpoints, tous les schémas |
| Swagger UI embarqué dans le serveur | ✅ | watchtower | `GET /docs` + `GET /docs/openapi.yaml` — aucune dépendance npm |
| Créer `ferelking242/watchtower-sdk-dart` | ✅ | nouveau repo | Repo créé, SDK complet écrit |
| Modèles typés Dart (`Source`, `FeedItem`…) | ✅ | watchtower-sdk-dart | Source, FeedItem, ItemsPage, ContentDetail, VideoStream, MangaPage, Filter |
| Retry + backoff dans SDK Dart | ✅ | watchtower-sdk-dart | Exponentiel 300ms→600ms→1200ms, max 3 tentatives |
| Tests SDK Dart | ✅ | watchtower-sdk-dart | Couverture ping, list, popular, videos, detail, pages, retry |
| Exposer `getRaw()` dans SDK Dart | ✅ | watchtower-sdk-dart | GET brut avec retry+auth pour clients nécessitant la réponse brute |
| Remplacer `RemoteApiClient` dans Reel par le SDK | ✅ | watchtower-real | Adaptateur thin — interface identique, internalement WatchtowerClient |
| Créer `ferelking242/watchtower-sdk-js` | 📋 | nouveau repo | TypeScript, npm `@watchtower/client` |
| SDK Python (optionnel phase 1) | 📋 | nouveau repo | PyPI `watchtower-client`, pour Colab |

---

## Phase 2 — Multi-UI dans watchtower (📋 Planifié)

| Tâche | Statut | Fichier cible | Notes |
|---|---|---|---|
| `lib/ui/ui_registry.dart` | 📋 | watchtower | `enum UiMode { netflix, tiktok }` |
| `lib/ui/ui_shell.dart` | 📋 | watchtower | ConsumerWidget switcher selon Hive prefs |
| `lib/ui/netflix/netflix_shell.dart` | 📋 | watchtower | Wrapper de l'UI actuelle |
| Git dep `reel` dans `watchtower/pubspec.yaml` | 📋 | watchtower | Tire watchtower-real via URL git |
| Setting "Interface" dans les paramètres | 📋 | watchtower | Choix netflix / tiktok |
| Tests de non-régression UI netflix | 📋 | watchtower | Vérifier que l'UI actuelle reste intacte |

---

## Phase 3 — Reel (features manquantes)

| Tâche | Statut | Fichier cible | Notes |
|---|---|---|---|
| Pagination infinie dans `feed_provider.dart` | ✅ | watchtower-real | loadMore() déclenché quand index ≥ items.length - 3 |
| Settings screen (URL + API key + source) | ✅ | watchtower-real | ConnectScreen (/connect) — déjà complet depuis session 1 |
| Double-tap like sur `feed_page.dart` | 📋 | watchtower-real | Animation cœur style TikTok |
| Long-press pause sur `feed_page.dart` | 📋 | watchtower-real | Pause pendant le hold |
| Progress bar vidéo (fine, bottom) | 📋 | watchtower-real | Style TikTok : trait fin en bas |
| Tab "Pour toi" / "Suivis" fonctionnels | 📋 | watchtower-real | Actuellement tab 0 = pour toi seulement |
| Renommer repo GitHub `watchtower-real` → `watchtower-reel` | 📋 | GitHub (manuel) | Action utilisateur sur github.com/settings |

---

## Phase 4 — Futurs repos UI

| UI | Repo | Statut | Notes |
|---|---|---|---|
| YouTube-style | `watchtower-youtube` | 📋 | Thumbnails horizontaux, playlists |
| Spotify-style | `watchtower-spotify` | 📋 | Pour la musique uniquement |

---

## Décisions architecturales figées

| Décision | Pourquoi | Date |
|---|---|---|
| Multi-UI via git dep pubspec (pas Melos) | Melos impose un monorepo immédiat | 2026-07-17 |
| SDK : watchtower PRODUIT, ne CONSOMME pas | Il est le serveur | 2026-07-17 |
| Keystore Reel permanent openssl PKCS12 | Updates APK fonctionnels | 2026-07-17 |
| `render.yaml` à la racine watchtower | Render le lit depuis là | 2026-07-17 |
| Pas de codegen dans watchtower-real | Pas de @riverpod ou @IsarCollection actifs | 2026-07-17 |
