# Plan — Page extension « Watch » (WatchHomeScreen) : refonte UI + fixes

> Périmètre : la page qui s'ouvre quand on ouvre une extension **watch**
> (`lib/modules/watch/home/watch_home_screen.dart` + `nf_widgets/`).
> Références design : patterns Netflix / Disney+ mobile (flutter_netflix, dribbble/behance streaming dashboards) — hero 16:9 avec scrim dégradé, rangée « Reprendre », headers sans compteurs, grille catalogue centrée.

## Diagnostic (bugs constatés)

| # | Problème | Cause racine |
|---|----------|--------------|
| 1 | Barre du haut devient noire au scroll, mal intégrée | `NfWatchAppBarWidget` : fond `Colors.black * opacity` plein, icônes qui changent de couleur |
| 2 | Image hero beaucoup trop haute | hauteur = `width * 1.6` (portrait !) au lieu d'un ratio paysage |
| 3 | « + Ma liste » ne fait rien | `onMyListTap: () {}` — noop |
| 4 | « Lecture » / « Info » cassés | hero épinglé dans un `Stack` derrière le scroll ; Info = même handler que Lecture, pas de fiche info |
| 5 | Les items passent par-dessus le carousel | hero épinglé (`Positioned`) + spacer dans le scroll → le contenu remonte par-dessus |
| 6 | UI lente / buggée | `setState` sur **chaque** pixel de scroll (rebuild complet de l'écran) |
| 7 | Pas de section historique | inexistante |
| 8 | Catégories peu travaillées | chips basiques |
| 9 | Compteurs dans les titres de sections | badge `${items.length}` inutile |
| 10 | Catalogue collé à gauche | grille edge-to-edge sans marge ni style |
| 11 | Micro recherche non fonctionnel | permission `RECORD_AUDIO` absente du manifest |
| 12 | Retour recherche = flèche pleine | `Icons.arrow_back_rounded` au lieu du chevron `<` |
| 13 | Pas de X dans le champ | pas de suffix clear |
| 14 | Suggestions lentes + moches | résultats re-rendus à chaque frappe ; liste inline plate |

## Exécution

### A. Hero carousel — `nf_widgets/nf_highlight_banner.dart` (réécrit)
- `NfHeroCarousel` : `PageView` auto-rotatif (7 s) sur les 5 premiers items de la liste `banner` (fallback popular).
- **Hauteur** : `width * 0.62`, clampé à `screenH * 0.44` → ratio paysage.
- Scrims dégradés haut (lisibilité status bar) + bas (titre/actions) — plus de bloc noir.
- Indicateur : points de pagination.
- Actions branchées :
  - **Ma liste** → toggle favori Isar (même logique que NfBottomSheet, via helper partagé `nf_favorite.dart`) + haptic + état ✓.
  - **Lecture** → `pushToMangaReaderDetail` (fiche → épisodes).
  - **Info** → `NfBottomSheet` (la box du bas) qui affiche poster, description, genres, lecture.

### B. App bar — `nf_widgets/nf_app_bar.dart`
- Fond : dégradé noir→transparent permanent en haut + backdrop `#010101` fondu **au-delà de 90 px** de scroll (Netflix-like). Icônes toujours blanches.
- Titre de la source en fade-in quand scrolle.
- Piloté par `ValueNotifier<double>` + `ValueListenableBuilder` → **zéro setState** au scroll (fix lag).

### C. Structure home — `watch_home_screen.dart`
- Hero **dans** le `CustomScrollView` (1er sliver) → impossible qu'un item passe dessus. Fin du Stack/spacer.
- Ordre : Hero → **Historique** → Catégories → Rangées contenu → Nouveau & Populaire → Catalogue.
- Scroll listener : seulement le notifier + déclenchement pagination (pas de setState).

### D. Section Historique — `nf_widgets/nf_watch_history_row.dart` (nouveau)
- Stream Isar `getAllHistoryStreamProvider(itemType: source.itemType)` filtré sur la source courante, dédupliqué par manga (plus récent d'abord), max 12.
- Cartes paysage 16:9 : miniature, nom épisode/chapitre, barre de progression fine si `lastPageRead`, overlay play.
- Tap → `chapter.pushToReaderView(context)` (reprendre). Masquée si vide.

### E. Divers home
- Headers de section : titre seul, badge compteur supprimé.
- Catégories : cartes 132×72, radius 12, image + dégradé + bordure subtile.
- Catalogue : header centré entre deux filets, grille centrée (`SliverPadding` horizontal 20), posters arrondis 12 avec bordure blanche subtile + ombre (« l'effet »).

### F. Recherche (inline `_buildSearchView`)
- Retour : chevron `<` (`arrow_back_ios_new_rounded`) dans le bouton circulaire, comme les autres pages.
- Champ pill : suffixe droit = **micro** (vide) / **X** (texte présent) — micro implémenté via `speech_to_text` déjà dépendancé + permission manifest ajoutée ; état « Je vous écoute… » animé.
- Suggestions : debounce 250 ms, **box flottante** arrondie sous la barre (max 5, scrollable, vignette + titre), overlay au-dessus des résultats.
- Résultats lancés uniquement sur submit (clavier « Recherche ») ou tap suggestion → plus de lag à la frappe.
- Fixes entrées : X réinitialise vers la grille populaire, suggestion remplit + lance, retour quitte proprement.

### G. Manifest
- `android/app/src/main/AndroidManifest.xml` : + `RECORD_AUDIO`.

## Fichiers
| Fichier | Action |
|---|---|
| `lib/modules/watch/home/watch_home_screen.dart` | Restructuration (hero sliver, historique, catalogue centré, recherche) |
| `lib/modules/watch/home/nf_widgets/nf_highlight_banner.dart` | Réécrit → `NfHeroCarousel` |
| `lib/modules/watch/home/nf_widgets/nf_app_bar.dart` | Scrim + ValueNotifier |
| `lib/modules/watch/home/nf_widgets/nf_watch_history_row.dart` | Nouveau |
| `lib/modules/watch/home/nf_widgets/nf_favorite.dart` | Nouveau — helper favori Isar partagé |
| `android/app/src/main/AndroidManifest.xml` | Permission micro |
| `docs/PLAN_WATCH_HOME_UI.md` | Ce document |
