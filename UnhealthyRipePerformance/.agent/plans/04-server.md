# Plan 04 — Serveur headless

> Statut global : ✅ Implémenté / 📋 Améliorations planifiées  
> Dernière mise à jour : 2026-07-17

---

## Contexte

Watchtower expose une API REST de deux façons :

| Mode | Runtime | Fichiers | Port par défaut |
|---|---|---|---|
| **Embarqué** | Dart / shelf | `lib/remote/` | 4567 |
| **Headless** | Node.js 20 / Express | `server/` | 8080 |

Les deux modes exécutent exactement les mêmes extensions JS mangayomi et retournent les mêmes réponses JSON. L'API est identique.

---

## Architecture du serveur headless (`server/`)

```
server/
├── server.js                  ← point d'entrée Express
│                                 - charge les bridges
│                                 - monte les routes api.js
│                                 - démarre HTTP
│
└── src/
    ├── api.js                 ← routes HTTP
    │                             GET /api/ping
    │                             GET /api/sources
    │                             GET /api/sources/:id
    │                             GET /api/sources/:id/popular
    │                             GET /api/sources/:id/latest
    │                             GET /api/sources/:id/search
    │                             GET /api/sources/:id/detail
    │                             GET /api/sources/:id/videos
    │                             GET /api/sources/:id/pages
    │                             GET /api/sources/:id/filters
    │
    ├── js-runtime.js          ← sandbox Node VM
    │                             exécute le code JS des extensions
    │                             injecte les bridges (http, dom, crypto, prefs)
    │                             timeout configurable par requête
    │
    ├── extension-registry.js  ← gestionnaire d'extensions
    │                             télécharge depuis EXTENSIONS_REPO_URL
    │                             cache disque dans CACHE_DIR
    │                             TTL : CACHE_TTL_MS (défaut 5min)
    │                             liste filtre les sources isNsfw: true
    │
    ├── rate-limiter.js        ← token bucket par clé API
    │                             fenêtre : RATE_WINDOW_MS (défaut 60s)
    │                             max tokens : RATE_MAX_TOKENS (défaut 60)
    │
    └── bridges/
        ├── http-bridge.js     ← requêtes HTTP pour les extensions
        │                         rotation User-Agent
        │                         timeout, retry, follow redirects
        ├── dom-bridge.js      ← sélecteurs CSS et XPath (Cheerio)
        ├── crypto-bridge.js   ← AES-CBC/GCM, déobfuscation JS
        └── prefs-bridge.js    ← préférences persistées par source (JSON fichier)
```

---

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `PORT` | `8080` | Port HTTP |
| `API_KEY` | *(vide = API ouverte)* | Clé d'auth globale |
| `EXTENSIONS_REPO_URL` | mangayomi-extensions/main | Catalogue extensions |
| `CACHE_TTL_MS` | `300000` | TTL cache extensions (5 min) |
| `CACHE_DIR` | `/data/cache` | Cache disque |
| `PREFS_DIR` | `/data/prefs` | Préférences par source |
| `RATE_WINDOW_MS` | `60000` | Fenêtre rate limit |
| `RATE_MAX_TOKENS` | `60` | Requêtes max par fenêtre |
| `NODE_ENV` | `production` | Environnement |

---

## Options de déploiement

Voir `deployment/README.md` pour le guide complet.

| Plateforme | Config | Statut |
|---|---|---|
| Railway | `server/railway.toml` | ✅ One-click |
| Render | `render.yaml` (racine repo) | ✅ One-click |
| Docker local | `server/Dockerfile` + `server/docker-compose.yml` | ✅ |
| Google Colab | `deployment/colab_deploy.ipynb` | ✅ Temporaire |
| Hugging Face | Docker compatible HF | ✅ Documenté |
| Node.js direct | `cd server && npm start` | ✅ |

**⚠️ `server/railway.toml` doit rester dans `server/`** — Railway le lit depuis le root du service.  
**⚠️ `render.yaml` doit rester à la racine du repo** — Render le lit depuis là.

---

## CI — `build-server.yml`

```yaml
# .github/workflows/build-server.yml dans watchtower
# Déclenché : push sur main + PR

Steps :
  1. Node.js 20
  2. npm ci dans server/
  3. node server.js --dry-run (smoke test import)
  4. docker build (si Docker disponible)
  5. push image vers ghcr.io/ferelking242/watchtower-server:latest
```

---

## Améliorations planifiées

| Amélioration | Priorité | Notes |
|---|---|---|
| `server/openapi.yaml` | 🔴 Haute | Prérequis du plan SDK |
| `GET /docs` → Swagger UI | 🟡 Moyenne | swagger-ui-express |
| WebSocket watch-mode | 🟢 Basse | Pour feed temps réel |
| Authentification multi-clés | 🟢 Basse | API keys par utilisateur |
| Métriques `/metrics` (Prometheus) | 🟢 Basse | Pour monitoring cloud |

---

## Comment l'API est consommée

```
Mode embarqué (port 4567) :
  Reel se connecte à http://<ip-du-téléphone>:4567
  → watchtower doit tourner sur l'appareil

Mode headless (URL cloud) :
  Reel se connecte à https://mon-app.railway.app
  → watchtower-server tourne en cloud, accessible partout
```

L'utilisateur configure l'URL dans :
- **Reel** : Settings screen → "URL du serveur" + "API Key"
- **watchtower** (futur) : Paramètres → Serveur distant

---

## Politique NSFW (implémentée)

Les sources marquées `isNsfw: true` dans les extensions sont filtrées au niveau de `extension-registry.js`. Elles ne retournent **jamais** dans `GET /api/sources`, quelle que soit la configuration. Retourne `403` si appelée directement.
