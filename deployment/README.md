# Watchtower — Deploy the Headless Server

Le serveur headless (`server/`) expose les extensions Watchtower via une API REST.  
Déployable partout où Node.js 20 tourne.

---

## Comparatif des options

| Option | Coût | Persistance | Facilité | Idéal pour |
|---|---|---|---|---|
| **Railway** | Gratuit (hobby) | ✅ Permanent | ⭐⭐⭐ | Production personnelle |
| **Render** | Gratuit (spin-down) | ✅ Permanent | ⭐⭐⭐ | Production légère |
| **Docker local** | Gratuit | ✅ Permanent | ⭐⭐ | VPS / NAS / Homelab |
| **Node.js direct** | Gratuit | ✅ Permanent | ⭐⭐⭐ | Dev / VPS simple |
| **Google Colab** | Gratuit | ❌ Session only | ⭐⭐⭐ | Test rapide |
| **Hugging Face** | Gratuit | ⚠️ Cold start | ⭐⭐ | Démo publique |
| **RunPod** | Payant | ✅ Pod running | ⭐⭐ | GPU + perf |

---

## Railway (recommandé)

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ferelking242/watchtower&rootDirectory=server)

Ou manuellement :
1. Fork ce repo
2. Railway → **New Project → Deploy from GitHub**
3. Root directory : `server`
4. Env vars : `API_KEY=mysecretkey`
5. Deploy → URL HTTPS automatique

Config : `server/railway.toml`

---

## Render

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/ferelking242/watchtower)

Config : `render.yaml` (racine du repo)

---

## Docker (local / VPS)

```bash
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
cp .env.example .env          # → remplis API_KEY
docker compose up -d
curl http://localhost:8080/api/ping
```

Config : `server/Dockerfile` + `server/docker-compose.yml`

---

## Node.js direct

```bash
cd watchtower/server
npm install
API_KEY=mysecretkey PORT=8080 node server.js
```

---

## Google Colab (session temporaire)

Ouvre **[colab_deploy.ipynb](colab_deploy.ipynb)** dans Google Colab.  
Remplace `API_KEY` et `NGROK_TOKEN` (gratuit sur ngrok.com), puis **Run all**.  
→ Copie l'URL ngrok dans l'app.

---

## Hugging Face Spaces

1. Crée un Space → runtime **Docker**
2. Upload le contenu de `server/`
3. Ajoute `API_KEY` dans les Secrets du Space
4. Le `Dockerfile` est déjà compatible HF (port 8080, user non-root)

---

## RunPod

```bash
# Dans le terminal du pod (Linux + Node 20)
git clone https://github.com/ferelking242/watchtower.git
cd watchtower/server
npm ci
API_KEY=yourkey PORT=8080 node server.js &
```
Expose le port `8080` dans les paramètres réseau du pod.

---

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `PORT` | `8080` | Port HTTP |
| `API_KEY` | _(vide = ouvert)_ | Clé auth pour `/api/*` |
| `EXTENSIONS_REPO_URL` | mangayomi-extensions/main | Catalogue d'extensions |
| `CACHE_TTL_MS` | `300000` | TTL cache (5 min) |
| `CACHE_DIR` | `/data/cache` | Répertoire cache disque |
| `PREFS_DIR` | `/data/prefs` | Préférences par source |
| `RATE_WINDOW_MS` | `60000` | Fenêtre rate limit |
| `RATE_MAX_TOKENS` | `60` | Max requêtes par fenêtre |

---

## Connecter l'app

App → **Paramètres → Serveur distant → URL du serveur** → colle ton URL → entre ta `API_KEY`.
