# Plan 01 — Architecture multi-UI

> Statut global : ✅ Décision prise / 📋 Implémentation à faire  
> Dernière mise à jour : 2026-07-17

---

## Contexte

Watchtower veut supporter plusieurs interfaces graphiques (TikTok-style, Netflix-style, YouTube-style…) développées dans des repos séparés et fusionnées dans l'app principale à terme. L'utilisateur peut switcher entre les UIs dans les Paramètres à runtime, sans redémarrer l'app.

---

## Décision finale : git dep pubspec.yaml ✅

Chaque UI = un repo Flutter indépendant importé dans `watchtower/pubspec.yaml` via URL git.

```yaml
# watchtower/pubspec.yaml
dependencies:
  reel:                                  # UI TikTok (watchtower-real)
    git:
      url: https://github.com/ferelking242/watchtower-real.git
      path: app/watchtower-real
      ref: main

  # watchtower_yt:                       # UI YouTube (futur)
  #   git:
  #     url: https://github.com/ferelking242/watchtower-youtube.git
  #     path: app/watchtower-youtube
  #     ref: main
```

### Pourquoi cette méthode

| Alternative analysée | Rejet |
|---|---|
| **Melos monorepo** | Force à déplacer tous les repos dans un seul dossier immédiatement — rupture |
| **CI rsync + patch imports** | Fragile : les chemins cassent, imports à patcher à la main après chaque sync |
| **Git submodules** | HEAD détaché fréquent, synchronisation complexe, mauvaise DX |
| **Flutter flavors** | Seulement build-time — impossible de switcher à runtime |
| **git dep pubspec** ✅ | Flutter-natif, zéro infra supplémentaire, hot-reload intact, pub résout les conflits |

---

## Structure cible dans watchtower

### Fichiers à créer (Phase 2)

**`lib/ui/ui_registry.dart`**
```dart
enum UiMode { netflix, tiktok }

class UiMeta {
  final UiMode mode;
  final String label;
  final String description;
  final IconData icon;
  const UiMeta({required this.mode, required this.label,
                required this.description, required this.icon});
}

const kUiRegistry = [
  UiMeta(
    mode: UiMode.netflix,
    label: 'Classique',
    description: 'Bibliothèque, grille, navigation par onglets',
    icon: Icons.grid_view_rounded,
  ),
  UiMeta(
    mode: UiMode.tiktok,
    label: 'Reel',
    description: 'Feed vertical plein-écran, scroll infini',
    icon: Icons.swipe_up_rounded,
  ),
];
```

**`lib/ui/ui_shell.dart`**
```dart
// Lit la préférence UiMode depuis Hive
// Switche sans redémarrer l'app
class UiShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(uiModeProvider)) {
      UiMode.netflix => const NetflixShell(),   // UI actuelle
      UiMode.tiktok  => const FeedScreen(),     // depuis package:reel
    };
  }
}
```

**`lib/ui/netflix/netflix_shell.dart`**
```dart
// Wrapper de l'UI existante — ne touche pas au code actuel
class NetflixShell extends StatelessWidget {
  // ... reprend le MaterialApp.router actuel de watchtower
}
```

### Ce que chaque UI partage (zéro duplication)

| Ressource | Emplacement dans watchtower | Shared |
|---|---|---|
| DB Isar | `lib/services/db/` | ✅ |
| Moteur extensions | `lib/eval/` | ✅ |
| Cache réseau | `lib/services/cache/` | ✅ |
| Providers globaux | `lib/providers/` | ✅ |
| Download manager | `lib/services/download_manager/` | ✅ |
| media_kit plugin | pubspec.yaml | ✅ |

---

## Convention — tout nouveau repo UI DOIT respecter

### 1. Package name
Court, snake_case, sans préfixe `watchtower_` si possible.  
Ex : `reel`, `watchtower_yt`, `watchtower_spotify`

### 2. Structure obligatoire
```
app/<nom>/
├── lib/
│   ├── shell.dart              ← OBLIGATOIRE : export du widget d'entrée
│   ├── main.dart               ← pour le build standalone (dev uniquement)
│   └── features/<nom>/
│       └── <nom>_screen.dart   ← widget racine de l'UI
└── pubspec.yaml                ← name: <nom>, deps avec contraintes larges
```

### 3. `lib/shell.dart` obligatoire
```dart
library <nom>;
export 'features/<nom>/<nom>_screen.dart' show <Nom>Screen;
```

### 4. Dépendances partagées — contraintes larges
```yaml
dependencies:
  flutter_riverpod: ">=3.0.0 <4.0.0"   # large, watchtower fait l'override
  isar_community: ">=3.0.0 <4.0.0"
  media_kit:
    git:
      url: https://github.com/kodjodevf/media-kit.git
      path: media_kit
      ref: f5796d287b642548e7e703bbc592f01dd7b1befe  # même ref que watchtower
```

---

## Cycle de vie d'une UI

```
1. DÉVELOPPEMENT
   → Repo UI standalone
   → flutter run → build APK/IPA propre
   → Connexion au serveur watchtower via RemoteApiClient / SDK Dart

2. INTÉGRATION
   → watchtower/pubspec.yaml : git dep ajouté
   → lib/ui/<nom>/ créé
   → ui_registry.dart : entrée ajoutée
   → ui_shell.dart : case ajouté
   → flutter pub get → Flutter résout tout

3. ACTIVATION
   → Paramètres → Interface → liste des UIs disponibles
   → UiShell switche instantanément
```

---

## Checklist pour ajouter une nouvelle UI

- [ ] Créer repo `ferelking242/watchtower-<nom>`
- [ ] Respecter la structure (shell.dart obligatoire)
- [ ] Aligner les versions de packages avec watchtower
- [ ] Tester le build standalone
- [ ] Ajouter git dep dans `watchtower/pubspec.yaml`
- [ ] Créer `lib/ui/<nom>/` dans watchtower
- [ ] Ajouter `UiMode.<nom>` dans `ui_registry.dart`
- [ ] Ajouter `case` dans `ui_shell.dart`
- [ ] Ajouter entrée dans Settings
- [ ] Mettre à jour `ROADMAP.md`
