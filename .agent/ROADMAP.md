# Roadmap — Watchtower

> Statuts : ✅ Fait | 🚧 En cours | 📋 Planifié | ❌ Abandonné  
> Dernière mise à jour : 2026-07-17

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

## Phase 1 — SDK (📋 Planifié, priorité haute)

| Tâche | Statut | Repo cible | Notes |
|---|---|---|---|
| `server/openapi.yaml` | 📋 | watchtower | Spec formelle de l'API — source de vérité |
| Swagger UI embarqué dans le serveur | 📋 | watchtower | `GET /docs` → UI interactive |
| Créer `ferelking242/watchtower-sdk-dart` | 📋 | nouveau repo | Extraire `RemoteApiClient` de Reel |
| Modèles typés Dart (`Source`, `FeedItem`…) | 📋 | watchtower-sdk-dart | Depuis les réponses JSON actuelles |
| Retry + backoff dans SDK Dart | 📋 | watchtower-sdk-dart | Exponentiel, max 3 tentatives |
| Remplacer `RemoteApiClient` dans Reel par le SDK | 📋 | watchtower-real | `pubspec.yaml` git dep |
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
| Pagination infinie dans `feed_provider.dart` | 📋 | watchtower-real | Charger page suivante quand index → fin |
| Settings screen (URL + API key + source) | 📋 | watchtower-real | Actuellement hardcodé dans SharedPrefs |
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
