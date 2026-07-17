# Plan 02 — Architecture SDK

> Statut global : 📋 Planifié — à implémenter  
> Dernière mise à jour : 2026-07-17

---

## Principe fondamental

```
watchtower  =  PRODUCTEUR de l'API   (ne s'importe jamais lui-même)
SDK         =  CONSOMMATEUR de l'API (importé par Reel, web, scripts…)
```

Watchtower expose une API REST. Des SDKs l'encapsulent pour chaque écosystème.  
C'est le même modèle que Supabase, Stripe, Twilio.

---

## Pourquoi des SDKs

**Sans SDK (situation actuelle) :**
```
watchtower-real → RemoteApiClient maison (HTTP brut)
futur-ui-youtube → recrée un RemoteApiClient maison
futur-web → recrée le même code en JS
Colab → code HTTP à la main
```

**Avec SDK :**
```
watchtower-real → import watchtower_client; client.sources.popular(id)
futur-ui-youtube → import watchtower_client; même API
futur-web → import @watchtower/client; même API
Colab → pip install watchtower-client; même API
```

Un endpoint change → on patche le SDK → tous les clients héritent via `pub get` / `npm update`.

---

## Étape 0 : openapi.yaml (prérequis)

**Fichier :** `watchtower/server/openapi.yaml`

OpenAPI 3.1 est un YAML/JSON qui décrit formellement l'API :
- tous les endpoints, paramètres, réponses
- schémas des modèles (`Source`, `FeedItem`, `VideoStream`…)
- méthode d'authentification

À partir de ce fichier, `openapi-generator-cli` génère des SDKs dans n'importe quel langage automatiquement.

**Structure cible :**
```yaml
openapi: 3.1.0
info:
  title: Watchtower API
  version: 1.0.0
  description: |
    API REST exposée par le serveur Watchtower (embarqué shelf ou headless Node.js).
    Même API, deux runtimes.

servers:
  - url: http://localhost:4567   # embarqué
  - url: http://localhost:8080   # headless

paths:
  /api/ping:
    get:
      operationId: ping
      summary: Health check
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PingResponse'

  /api/sources:
    get:
      operationId: listSources
      security:
        - ApiKey: []
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Source'

  /api/sources/{id}/popular:
    get:
      operationId: getPopular
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
        - name: page
          in: query
          schema: { type: integer, default: 1 }
      security:
        - ApiKey: []
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ItemsPage'

  # ... /latest, /search, /detail, /videos, /pages, /filters

components:
  schemas:
    Source:
      type: object
      required: [id, name, lang]
      properties:
        id:        { type: string }
        name:      { type: string }
        lang:      { type: string }
        version:   { type: integer }
        isNsfw:    { type: boolean }
        itemType:  { type: string, enum: [video, manga, music, novel] }

    FeedItem:
      type: object
      properties:
        id:           { type: string }
        title:        { type: string }
        thumbnailUrl: { type: string }
        videoUrl:     { type: string }
        sourceId:     { type: string }
        author:       { type: string }
        likes:        { type: integer }
        views:        { type: integer }

    ItemsPage:
      type: object
      properties:
        items:   { type: array, items: { $ref: '#/components/schemas/FeedItem' } }
        hasNext: { type: boolean }
        page:    { type: integer }

  securitySchemes:
    ApiKey:
      type: apiKey
      in: header
      name: X-Api-Key
```

---

## SDK Dart — `ferelking242/watchtower-sdk-dart`

**Package pub.dev :** `watchtower_client`  
**Priorité :** Haute (remplace `RemoteApiClient` dans Reel)

### Structure
```
watchtower-sdk-dart/
├── lib/
│   ├── watchtower_client.dart      ← export public
│   └── src/
│       ├── client.dart             ← WatchtowerClient (classe principale)
│       ├── http_client.dart        ← retry, auth header, timeout
│       ├── exceptions.dart         ← WatchtowerException, NetworkException
│       ├── models/
│       │   ├── source.dart
│       │   ├── feed_item.dart
│       │   ├── video_stream.dart
│       │   ├── manga_page.dart
│       │   └── items_page.dart
│       └── endpoints/
│           ├── sources_endpoint.dart
│           └── ping_endpoint.dart
├── test/
│   └── client_test.dart
└── pubspec.yaml
```

### API Dart
```dart
// Usage dans Reel ou tout autre client Flutter
final client = WatchtowerClient(
  url: 'https://mon-serveur.railway.app',
  apiKey: 'mysecretkey',
  timeout: const Duration(seconds: 15),
);

final sources = await client.sources.list();
final page    = await client.sources.popular('redgifs', page: 1);
final detail  = await client.sources.detail('redgifs', url: '...');
final streams = await client.sources.videos('redgifs', url: '...');
final ok      = await client.ping();
```

### Import dans Reel (après création du SDK)
```yaml
# watchtower-real/pubspec.yaml
dependencies:
  watchtower_client:
    git:
      url: https://github.com/ferelking242/watchtower-sdk-dart.git
      ref: main
```

```dart
// Reel : remplace RemoteApiClient par WatchtowerClient
// remote/remote_client.dart → supprimé ou réduit à un wrapper fin
```

---

## SDK JavaScript/TypeScript — `ferelking242/watchtower-sdk-js`

**Package npm :** `@watchtower/client`  
**Priorité :** Moyenne (web + Colab)

### API TS
```typescript
import { WatchtowerClient } from '@watchtower/client'

const client = new WatchtowerClient({
  url: 'https://mon-serveur.railway.app',
  apiKey: 'mysecretkey',
})

const sources = await client.sources.list()
const page    = await client.sources.popular('redgifs', { page: 1 })
```

### Usage Colab (remplacement du notebook actuel)
```python
# colab_deploy.ipynb — simplifié avec le SDK Python
!pip install watchtower-client
from watchtower import WatchtowerClient
client = WatchtowerClient(url=NGROK_URL, api_key=API_KEY)
for item in client.sources.popular('redgifs'): print(item.video_url)
```

---

## SDK Python — `ferelking242/watchtower-sdk-python`

**Package PyPI :** `watchtower-client`  
**Priorité :** Basse (scripts, Colab)

---

## Génération automatique depuis openapi.yaml

Une fois `server/openapi.yaml` écrit :

```bash
# Génère le SDK Dart
npx @openapitools/openapi-generator-cli generate \
  -i server/openapi.yaml \
  -g dart \
  -o ../watchtower-sdk-dart

# Génère le SDK TypeScript-Fetch
npx @openapitools/openapi-generator-cli generate \
  -i server/openapi.yaml \
  -g typescript-fetch \
  -o ../watchtower-sdk-js

# Génère le SDK Python
npx @openapitools/openapi-generator-cli generate \
  -i server/openapi.yaml \
  -g python \
  -o ../watchtower-sdk-python
```

Le CI peut regénérer automatiquement les SDKs à chaque modification de `openapi.yaml`.

---

## Ordre d'implémentation recommandé

1. ✏️ Écrire `server/openapi.yaml` (2-3h)
2. 🔧 Créer `watchtower-sdk-dart` manuellement (extraire RemoteApiClient de Reel)
3. 🔄 Mettre à jour Reel pour utiliser le SDK
4. ⚙️ Ajouter Swagger UI dans le serveur (`GET /docs`)
5. 🤖 Automatiser la génération JS + Python depuis openapi.yaml
