# Watchtower — Catalogue des écrans

## Écrans principaux (ShellRoute / bottom nav)

| Écran | Route | Fichier principal | Description |
|---|---|---|---|
| Bibliothèque | `/Library` | `lib/modules/library/…` | Bibliothèque principale (Watch/Manga/Novel) |
| Accueil Watchtower | `/WatchtowerHome` | `lib/modules/home/watchtower_home_screen.dart` | Fil d'actualités et recommandations |
| Historique | `/history` | `lib/modules/history/…` | Historique de visionnage |
| Mises à jour | `/updates` | `lib/modules/updates/…` | Nouvelles sorties |
| Parcourir | `/browse` | `lib/modules/browse/…` | Sources et extensions |
| Plus | `/more` | `lib/modules/more/more_screen.dart` | Menu paramètres / téléchargements |

## Écrans de contenu

| Écran | Route | Fichier principal | Description |
|---|---|---|---|
| Détail contenu | `/manga-reader/detail` | `lib/modules/watch/detail/watch_detail_view.dart` | Fiche titre : synopsis, épisodes, actions |
| Lecteur anime (web) | `/animePlayerView` | `lib/modules/anime/anime_player_view_web.dart` | Player web avec contrôles, langue, sous-titres |
| Lecteur manga | `/mangaReaderView` | `lib/modules/manga/reader/…` | Lecteur BD/manga |
| Lecteur novel | `/novelReaderView` | `lib/modules/novel/reader/…` | Lecteur roman |

## Écrans téléchargements

| Écran | Route | Fichier principal | Description |
|---|---|---|---|
| File de téléchargements | `/downloadQueue` | `lib/modules/more/download_queue/download_queue_screen.dart` | Liste des téléchargements en cours avec état, actions (Gérer/Transfert) |
| Transfert | `/transfer` | `lib/modules/transfer/transfer_screen.dart` | Envoi/réception de fichiers entre appareils (Wi-Fi local) |

## Bottom sheets (modales)

| Nom | Déclencheur | Fichier | Description |
|---|---|---|---|
| `_DownloadSheet` | Chip "Télécharger" dans la fiche contenu | `watch_detail_view.dart` | Sélection qualité (360P/480P/1080P), épisodes, langue |
| After-download sheet | Après validation du téléchargement | `watch_detail_view.dart` | "Téléchargement N fichier(s)" + Voir/Regarder |
| Gérer sheet | Bouton "Gérer" dans DownloadQueueScreen | `download_queue_screen.dart` | Tout mettre en pause / arrière-plan / Annuler |
| Langue/Sous-titre panel | Bouton "Langue" dans le player web | `anime_player_view_web.dart` | Panneau audio + sous-titres avec toggles |
| Envoyer sheet | Bouton "Envoyer" dans TransferScreen | `transfer_screen.dart` | Scan des appareils proches |
| Recevoir sheet | Bouton "Recevoir" dans TransferScreen | `transfer_screen.dart` | Attente d'un envoi entrant |

## Couleurs design system

| Variable | Valeur | Usage |
|---|---|---|
| `_bg` | `#0E0E0E` | Fond général |
| `_card` | `#1A1A1A` | Cartes / surfaces |
| `_teal` | `#1DB954` | Accent principal (Watchtower green) |
| `_grey` | `#9E9E9E` | Texte secondaire |
| Sheet bg | `#1C1C1C` | Fond des bottom sheets |
| Card dark | `#242424` | Cartes dans les sheets |

## Notes

- Toute navigation entre écrans utilise `go_router` (`context.push('/route')` ou `context.goNamed('name')`).
- Le player web (`anime_player_view_web.dart`) est un remplacement de stub — la lecture vidéo réelle via HLS/DASH n'est pas supportée en Flutter web ; l'UI simule les contrôles.
- Le redesign de `DownloadQueueScreen` conserve toute la logique métier (providers Riverpod, swipe actions, pause/resume/delete/retry) et se concentre uniquement sur la couche visuelle.
