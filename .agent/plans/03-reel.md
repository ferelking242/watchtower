# Plan 03 — Reel (watchtower-real)

> Statut global : 🚧 En développement actif  
> Dernière mise à jour : 2026-07-17

---

## Identité

| Propriété | Valeur |
|---|---|
| Repo GitHub | `ferelking242/watchtower-real` |
| Nom display | Reel |
| Package Flutter | `reel` |
| Android ID | `com.watchtower.reel` |
| iOS bundle | `com.watchtower.reel` |
| Keystore alias | `reel` |
| Keystore password | `reelwatchtower` |

---

## Ce que Reel EST

- UI TikTok-style : feed vertical plein-écran, scroll infini
- Flutter uniquement — pas de backend propre
- Consomme l'API serveur watchtower (embedded ou headless)
- Développé séparément pour itérer vite
- **Destination finale :** `watchtower/lib/ui/tiktok/` via git dep pubspec

## Ce que Reel N'EST PAS

- ❌ Un serveur — le serveur est dans watchtower
- ❌ L'app principale — c'est watchtower
- ❌ Un monolithe — il sera importé comme package Flutter

---

## État actuel (2026-07-17)

### ✅ Fait

| Feature | Fichier |
|---|---|
| Feed vertical PageView | `feed_screen.dart` |
| Preloading pool Players [i-1, i, i+1] | `feed_screen.dart` |
| Lecture vidéo media_kit (même fork que watchtower) | `feed_page.dart` |
| Thumbnail fallback pendant buffering | `feed_page.dart` |
| Tap play/pause | `feed_page.dart` |
| Sidebar (like, comment, share, bookmark) | `feed_sidebar.dart` |
| Header flottant avec tabs | `feed_header.dart` |
| Bottom nav bar | `feed_screen.dart` |
| Connexion serveur watchtower | `remote_client.dart` |
| Config serveur URL + API key | `remote_config_provider.dart` |
| Logger fichier | `utils/log/app_file_logger.dart` |
| Build APK arm64 (keystore permanent) | `.github/workflows/build-apk.yml` |
| Build IPA TrollStore | `.github/workflows/build-ipa.yml` |
| Export shell.dart pour intégration watchtower | `lib/shell.dart` |
| MediaKit.ensureInitialized() au démarrage | `main.dart` |
| Rename complet (watchtower_real → reel) | partout |

### 📋 À faire (priorité ordre)

| Feature | Fichier | Priorité |
|---|---|---|
| Pagination infinie feed | `feed_provider.dart` | 🔴 Haute |
| Settings screen (URL + key + source) | nouveau fichier | 🔴 Haute |
| Remplacer RemoteApiClient par SDK Dart | `remote/` | 🔴 Haute (après plan 02) |
| Double-tap like (animation cœur) | `feed_page.dart` | 🟡 Moyenne |
| Long-press pause | `feed_page.dart` | 🟡 Moyenne |
| Progress bar vidéo (thin bottom) | `feed_page.dart` | 🟡 Moyenne |
| Tab "Suivis" fonctionnel | `feed_provider.dart` | 🟡 Moyenne |
| Renommer repo GitHub → `watchtower-reel` | GitHub (manuel) | 🟢 Basse |

---

## Architecture du feed

### Preloading pool (implémenté)

```
FeedScreen maintient : Map<int, Player> pool

Quand currentIndex change :
  alive = {currentIndex-1, currentIndex, currentIndex+1}

  Pour chaque i dans alive :
    si pool[i] n'existe pas :
      pool[i] = Player()
      pool[i].open(Media(items[i].videoUrl), play: false)

  Pour chaque k dans pool.keys où k ∉ alive :
    pool[k].dispose()
    pool.remove(k)

  Page active → pool[currentIndex].play()
  Pages adjacentes → restent ouvertes, buffering en avance
```

### FeedProvider (à compléter : pagination)

```dart
// feed_provider.dart — logique de pagination à ajouter

class FeedNotifier extends AsyncNotifier<List<FeedItem>> {
  int _page = 1;
  bool _hasMore = true;

  // TODO : appeler loadMore() quand l'index approche de items.length - 2
  Future<void> loadMore() async {
    if (!_hasMore) return;
    _page++;
    final newItems = await _loadPage(_page);
    _hasMore = newItems.isNotEmpty;
    state = AsyncData([...state.requireValue, ...newItems]);
  }
}
```

---

## Keystore — règles strictes

```
Fichier      : reel.keystore (PKCS12, openssl-generated)
Alias        : reel
Store pass   : reelwatchtower
Key pass     : reelwatchtower
Validité     : 100 ans (36500 jours)

Secrets GitHub dans ferelking242/watchtower-real :
  KEYSTORE_BASE64  → keystore encodé base64
  KEY_PASSWORD     → reelwatchtower
  STORE_PASSWORD   → reelwatchtower

RÈGLE : ne JAMAIS régénérer ce keystore.
Si on génère un nouveau keystore → signature APK change
→ les utilisateurs ne peuvent plus mettre à jour depuis le store.
```

---

## Versions packages (alignées avec watchtower)

```yaml
flutter_riverpod: ^3.1.0
riverpod:         ^3.1.0
hooks_riverpod:   ^3.0.0
flutter_hooks:    ^0.21.0
hive:             ^2.2.3
hive_flutter:     ^1.1.0
shared_preferences: ^2.3.5
go_router:        ^17.2.0
http:             ^1.6.0
flex_color_scheme: ^8.3.1
cached_network_image: ^3.3.1
media_kit:        git ref f5796d287b642548e7e703bbc592f01dd7b1befe
```

**⚠️ Ne pas changer ces versions sans aligner watchtower en même temps.**

---

## Fusion dans watchtower — quand et comment

**Condition :** Reel est stable, pagination infinie fonctionnelle, settings screen fait.

**Procédure :**
1. Ajouter dans `watchtower/pubspec.yaml` :
   ```yaml
   reel:
     git:
       url: https://github.com/ferelking242/watchtower-real.git
       path: app/watchtower-real
       ref: main
   ```
2. Créer `watchtower/lib/ui/ui_registry.dart` + `ui_shell.dart`
3. Créer `watchtower/lib/ui/netflix/netflix_shell.dart`
4. Ajouter setting "Interface" dans les paramètres watchtower
5. Tester que l'UI netflix reste intacte
6. Tester que l'UI tiktok (Reel) fonctionne dans watchtower

**Après fusion :** `RemoteApiClient` dans Reel est remplacé par les providers Isar/eval de watchtower — plus d'appels HTTP, tout est local.
