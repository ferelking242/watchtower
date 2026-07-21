'use strict';
/**
 * Swagger UI — GET /docs
 *
 * Sert une UI interactive de l'API à partir de server/openapi.yaml.
 * Accessible sans authentification (lecture seule).
 * Aucune dépendance externe : le YAML est servi tel quel, Swagger UI 5 le lit nativement.
 */
const path    = require('path');
const fs      = require('fs');
const express = require('express');

const router = express.Router();

const SPEC_PATH = path.join(__dirname, '../openapi.yaml');

// GET /docs/openapi.yaml — spec brute (Swagger UI 5 accepte le YAML directement)
router.get('/openapi.yaml', (req, res) => {
  try {
    const raw = fs.readFileSync(SPEC_PATH, 'utf8');
    res.setHeader('Content-Type', 'text/yaml; charset=utf-8');
    res.send(raw);
  } catch (e) {
    res.status(500).json({ error: 'Could not load OpenAPI spec: ' + e.message });
  }
});

// GET /docs — UI Swagger (CDN unpkg, pas de dépendance npm)
router.get('/', (req, res) => {
  const host = `${req.protocol}://${req.get('host')}`;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Watchtower API — Documentation</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    body { margin: 0; background: #0a0a0a; }
    .swagger-ui .topbar { background: #111; }
    .swagger-ui .topbar .download-url-wrapper { display: none; }
    .swagger-ui .info .title { color: #fff; }
    .swagger-ui .scheme-container { background: #1a1a1a; padding: 12px 20px; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({
      url: '${host}/docs/openapi.yaml',
      dom_id: '#swagger-ui',
      presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
      layout: 'BaseLayout',
      deepLinking: true,
      tryItOutEnabled: true,
    });
  </script>
</body>
</html>`);
});

module.exports = router;
