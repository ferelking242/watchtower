# Watchtower Headless Server

Exposes Watchtower JS extensions as an HTTP API — deployable on any VPS, Heroku, Railway, or Docker host.

## Architecture

```
server/
├── server.js          # Entry point (Express)
├── src/
│   ├── api.js                  # HTTP routes
│   ├── js-runtime.js           # Node.js VM sandbox (mirrors flutter_qjs)
│   ├── extension-registry.js   # Load extensions from remote repo
│   ├── rate-limiter.js         # Token-bucket rate limiting
│   └── bridges/
│       ├── http-bridge.js      # HTTP requests for extension JS
│       ├── dom-bridge.js       # DOM / CSS selector / XPath
│       ├── crypto-bridge.js    # AES, deobfuscator, JS unpacker
│       ├── prefs-bridge.js     # File-based key-value preferences
│       └── extractors.js       # Video host extractors
```

## Quick Start

### Docker (recommended)

```bash
cd server
cp .env.example .env   # set API_KEY
docker compose up -d
```

### Node.js directly

```bash
cd server
npm install
API_KEY=mysecretkey node server.js
```

### Colab (one-liner)

```python
import subprocess, os
os.makedirs('/content/server', exist_ok=True)
subprocess.Popen(['node', 'server.js'], cwd='/content/server',
                 env={**os.environ, 'API_KEY': 'mykey', 'PORT': '8080'})
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `API_KEY` | _(empty = open)_ | Required key for all `/api/*` routes (except `/api/ping`) |
| `EXTENSIONS_REPO_URL` | mangayomi-extensions/main | Base URL of the extensions catalogue |
| `CACHE_TTL_MS` | `300000` | Cache TTL for extension catalogue and JS files (ms) |
| `CACHE_DIR` | `data/cache` | Directory for on-disk cache |
| `PREFS_DIR` | `data/prefs` | Directory for per-source preferences |
| `RATE_WINDOW_MS` | `60000` | Rate limit window (ms) |
| `RATE_MAX_TOKENS` | `60` | Max requests per window per API key |

## API Reference

All routes (except `/api/ping`) require:
- `X-Api-Key: <key>` header  **or**
- `Authorization: Bearer <key>` header

### `GET /api/ping`
Health check. Returns `{"status":"ok","version":"0.1.0"}`.

### `GET /api/sources`
List all non-NSFW sources.

### `GET /api/sources/:id`
Single source metadata. NSFW sources → 403.

### `GET /api/sources/:id/popular?page=1`
Popular items page.

### `GET /api/sources/:id/latest?page=1`
Latest updates page.

### `GET /api/sources/:id/search?q=query&page=1`
Search.

### `GET /api/sources/:id/detail?url=...`
Full item detail (chapters/episodes).

### `GET /api/sources/:id/videos?url=...`
Video stream list for a given episode URL.

### `GET /api/sources/:id/pages?url=...`
Page image list for a given chapter URL.

### `GET /api/sources/:id/filters`
Filter list for the source.

## NSFW Policy

NSFW sources (where `isNsfw === true`) are **hard-blocked** at the API level — they return 403 and never appear in `/api/sources`, regardless of any parameter. This matches the same hard exclusion in the mobile remote server.
