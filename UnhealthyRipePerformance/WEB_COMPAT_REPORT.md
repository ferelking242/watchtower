# Rapport de compatibilité Web — Watchtower

> Généré le 30 juin 2026  
> Plateforme cible : Flutter Web → Vercel

---

## Résumé

| Catégorie | Packages |
|-----------|---------|
| ✅ Compatible web natif | ~20 packages |
| ⚠️ Support partiel (fonctionne avec limitations) | 9 packages |
| 🔧 Stubé (no-op sur web) | 13 packages |
| ❌ Bloquant sans solution simple | 2 packages |

---

## ✅ Packages compatibles web (aucune action requise)

Ces packages ont un support web natif complet :

- `go_router`, `flutter_riverpod`, `riverpod`, `riverpod_annotation`
- `http`, `html`, `crypto`, `convert`
- `extended_image`, `photo_view`, `cached_network_image`, `flutter_cache_manager`
- `hive`, `hive_flutter` → IndexedDB
- `shared_preferences` → localStorage
- `url_launcher` → `window.open()`
- `web_socket_channel` → WebSocket natif
- `flutter_secure_storage` → localStorage fallback
- `connectivity_plus` → Network Information API
- `share_plus` → Web Share API
- `image_picker`, `file_picker` → `<input type="file">`
- `flutter_tts` → SpeechSynthesis API
- `flutter_inappwebview` → `<iframe>` HTML5
- `drift` + `sqlite3` → WASM (nécessite config sqlite3_wasm, voir ci-dessous)

---

## ⚠️ Support partiel

### `isar_community`
- **Web** : IndexedDB via isar_flutter_libs_web
- **Limitation** : Queries complexes (links, filters imbriqués) peuvent planter
- **Action** : Ajouter `isar_community_flutter_libs_web` aux dépendances web
- **Fix possible** : ✅ Oui, 30min de travail

### `flutter_inappwebview`
- **Web** : Rendu en `<iframe>`, postMessage pour la communication JS
- **Limitation** : Pas d'accès aux cookies natifs, pas de WebRTC, user-agent fixe
- **Fix possible** : ✅ Partiel — les extensions qui utilisent le WebView pour auth fonctionnent

### `audio_service`
- **Web** : Media Session API (Chrome/Firefox)
- **Limitation** : Pas de background audio réel sur iOS Safari
- **Fix possible** : ✅ Oui natif

### `sqlite3` + `drift`
- **Web** : sqlite3_wasm disponible mais non configuré
- **Action** : Ajouter `sqlite3_wasm` + config dans `web/` (drift_worker.dart)
- **Fix possible** : ✅ 1-2h de travail

### `wakelock_plus`
- **Stubbé actuellement** mais a un support web natif via Screen Wake Lock API
- **Fix possible** : ✅ Retirer le stub, le package gère tout seul

### `flutter_tts`
- **Web** : SpeechSynthesis API (Chrome, Edge, Safari)
- **Limitation** : Voix limitées selon le navigateur
- **Fix possible** : ✅ Fonctionne nativement

---

## 🔧 Packages stubés (no-op sur web)

Ces packages n'ont pas de support web. Des stubs ont été créés dans `web_stubs/` :

| Package | Stub | Fonctionnalité sur web |
|---------|------|----------------------|
| `media_kit` + `media_kit_video` | ✅ `web_stubs/media_kit/` | ❌ Lecteur vidéo désactivé |
| `flutter_qjs` (QuickJS) | ✅ `web_stubs/flutter_qjs/` | ❌ Extensions JS désactivées |
| `volume_controller` | ✅ `web_stubs/volume_controller/` | ❌ Contrôle volume désactivé |
| `screen_brightness` | ✅ `web_stubs/screen_brightness/` | ❌ Luminosité désactivée |
| `local_notifier` | ✅ `web_stubs/local_notifier/` | ❌ Notifications bureau désactivées |
| `tray_manager` | ✅ `web_stubs/tray_manager/` | ❌ Icône système désactivée |
| `titlebar_buttons` | ✅ `web_stubs/titlebar_buttons/` | ❌ Boutons fenêtre masqués |
| `smtc_windows` | ✅ `web_stubs/smtc_windows/` | ❌ Media Control Windows désactivé |
| `home_widget` | ✅ `web_stubs/home_widget/` | ❌ Widget écran accueil désactivé |
| `metadata_god` | ✅ `web_stubs/metadata_god/` | ❌ Lecture tags audio désactivée |
| `flutter_new_pipe_extractor` | ✅ `web_stubs/flutter_new_pipe_extractor/` | ❌ NewPipe désactivé |
| `window_manager` | ✅ `web_stubs/window_manager/` | ❌ Gestion fenêtre désactivée |
| `desktop_webview_window` | ✅ `web_stubs/desktop_webview_window/` | ❌ WebView desktop désactivé |

---

## ❌ Bloquants sans solution simple

### `rust_lib_watchtower` (flutter_rust_bridge)
- **Problème** : Bibliothèque Rust compilée en FFI natif (`.so`, `.dylib`). Non compatible web tel quel.
- **Solution possible** : Compiler en WASM avec `wasm-pack` + `flutter_rust_bridge` WASM target
- **Effort** : 🔴 Élevé — 2-5 jours de travail
- **Ce qui est affecté** : Lecture EPUB (lib/src/rust/api/epub.dart)
- **Contournement court terme** : Stub no-op pour le web (EPUB non supporté sur web)

### `flutter_new_pipe_extractor` (JVM Android)
- **Problème** : Dépend de la JVM Android via Platform Channel. Impossible sur web.
- **Solution possible** : Réécrire l'engine YouTube en Dart pur + yt-dlp API
- **Effort** : 🔴 Élevé
- **Contournement** : ✅ Déjà stubé, YouTube via `youtube_explode_dart` (pur Dart) fonctionne

---

## 🎯 Ce qui FONCTIONNE sur web (après stubs)

- ✅ Navigation, bibliothèque, paramètres
- ✅ Sources d'extensions (WebView iframe)
- ✅ Lecture manga (images)
- ✅ Lecture romans (EPUB partiellement, Rust stubé)
- ✅ Module musique (Spotube) — audio via `<audio>` HTML5
- ✅ Recherche dans les sources
- ✅ Historique, favoris (Isar IndexedDB)

## ❌ Ce qui NE FONCTIONNE PAS sur web

- ❌ Lecteur vidéo (media_kit/libmpv → pas de support web)
- ❌ Extensions JavaScript (QuickJS → FFI)
- ❌ Téléchargements locaux (dart:io file system)
- ❌ Source locale (système de fichiers)
- ❌ Contrôle volume/luminosité hardware
- ❌ Notifications natives

---

## 🚀 Plan d'amélioration par priorité

### Priorité 1 — Court terme (déjà fait ✅)
- [x] Stubs pour tous les packages non-web
- [x] Déploiement Vercel au lieu de GitHub Pages
- [x] Fix `--base-href /` pour Vercel
- [x] Caching amélioré dans le workflow CI

### Priorité 2 — Moyen terme (1-3 jours)
- [ ] Lecteur vidéo web : intégrer un player HTML5 natif (`<video>`) pour les URLs directes
- [ ] wakelock_plus : retirer le stub, utiliser le support web natif
- [ ] sqlite3 WASM : configurer sqlite3_wasm pour drift (module musique)
- [ ] isar_community_flutter_libs_web : améliorer la DB web

### Priorité 3 — Long terme (1-2 semaines)
- [ ] Rust → WASM : compiler rust_lib_watchtower en WebAssembly pour EPUB web
- [ ] Player vidéo web avancé : chercher fork de media_kit avec support HLS/DASH web
- [ ] Extensions JS → WebWorker : remplacer QuickJS par un moteur JS web natif (dart:js_interop)

---

## 🔧 Setup Vercel (à faire par l'utilisateur)

1. Créer un compte sur https://vercel.com (gratuit)
2. `npm i -g vercel && vercel login`
3. Dans le repo cloné : `vercel` → crée le projet, note `VERCEL_ORG_ID` et `VERCEL_PROJECT_ID`
4. Dans GitHub → Settings → Secrets → ajouter :
   - `VERCEL_TOKEN` (depuis vercel.com → Account → Tokens)
   - `VERCEL_ORG_ID`
   - `VERCEL_PROJECT_ID`
5. Chaque push sur `main` déclenche automatiquement un déploiement Vercel

> Sans les secrets Vercel, le build crée quand même un artifact ZIP téléchargeable depuis GitHub Actions.
