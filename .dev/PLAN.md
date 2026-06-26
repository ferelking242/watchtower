# WATCHTOWER x SPOTUBE — Plan d'intégration complet

> Généré le 2025-06-26
> Spotube repo : `KRTirtho/spotube@master`
> Watchtower repo : `ferelking242/watchtower@main`

---

## 0. Résumé exécutif

On ne crée PAS de nouvelles pages — on prend les fichiers de Spotube tels quels et on adapte uniquement les lignes de "colle framework" dans chaque fichier. Le reste du code (logique Spotify, audio, paroles, providers) reste identique.

**Ce qui change dans chaque fichier Spotube :**

| Point | Spotube | Watchtower | Effort / fichier |
|---|---|---|---|
| Router decorator | `@RoutePage()` | supprimer | 1 ligne |
| Widget base class | `HookConsumerWidget` | `ConsumerStatefulWidget` | 1 ligne + boilerplate |
| Riverpod | `hooks_riverpod ^2.5.1` | `flutter_riverpod ^3.1.0` | changer imports |
| UI framework | `shadcn_flutter` widgets | Material équivalents | Shell + Navigation seulement |
| Navigation | `context.router.push(...)` | `context.push(...)` | ~3 lignes / fichier |
| Package prefix | `package:spotube/` | `package:watchtower/modules/music/` | imports |

**Ce qui NE change PAS :**
- Toute la logique métier (Spotify API, audio engine, lyrics, scrobbling, providers)
- Les providers Riverpod (state logic)
- Les services (audio_player, kv_store, etc.)
- Les modèles de données

---

## 1. Analyse de compatibilité SDK

| | Watchtower | Spotube | Compatible |
|---|---|---|---|
| Dart SDK | `^3.10.0` | `>=3.0.0 <4.0.0` | OK |
| Flutter | dernière stable | `>=3.29.0` | OK |
| Riverpod | `^3.1.0` | `^2.5.1` | adapter imports |
| Router | `go_router ^17` | `auto_route ^9` | adapter navigation |
| DB | `isar_community ^3.3` | `drift ^2.21` | ajouter drift (no conflict) |
| UI Shell | Material | `shadcn_flutter` | Shell seulement |
| Audio | `media_kit` (git kodjodevf) | `media_kit` | même lib |

---

## 2. Dépendances à ajouter dans pubspec.yaml

```yaml
# Audio
audio_service: ^0.18.13
audio_session: ^0.1.19

# Lyrics
lrc: ^1.0.2

# Metadata locale (MP3/FLAC tags)
metadata_god: ^1.1.0

# Color extraction pour artwork
palette_generator: ^0.3.3

# DB Spotube (séparée de isar — aucun conflit)
drift: ^2.21.0
sqlite3_flutter_libs: ^0.5.0

# Icônes Spotube
fluentui_system_icons: ^1.1.234

# Hooks (HookConsumerWidget)
flutter_hooks: ^0.20.5

# Réseau
dio: ^5.4.3

# Connectivité
connectivity_plus: ^6.1.2

# Scrobbling
# scrobblenaut (git KRTirtho/scrobblenaut dart-3-support)

# Stats / durée
duration: ^3.0.12

# Fuzzy search
fuzzywuzzy: ^1.1.6
```

**Conflit critique — Riverpod :**
Spotube utilise `hooks_riverpod ^2.5.1`, Watchtower utilise `flutter_riverpod ^3.1.0`.
Ces deux versions ne peuvent pas coexister dans le même pubspec.

**Décision retenue : garder Riverpod 3.x de Watchtower.**
- On ajoute `flutter_hooks` pour les HookConsumerWidget
- On adapte les appels `ref.watch` / `ref.read` (API identique entre 2.x et 3.x pour les usages de base)
- On importe depuis `package:flutter_riverpod` (pas `hooks_riverpod`)

---

## 3. Adaptation du main.dart

**On garde le main.dart de Watchtower. On y fusionne :**

```dart
// Blocs à ajouter dans Watchtower main() AVANT runApp()

// Audio service (Spotube)
await AudioService.init(
  builder: () => AudioPlayerService(),
  config: const AudioServiceConfig(...),
);

// MediaKit (déjà dans WT pour vidéo)
MediaKit.ensureInitialized(); // deja fait dans WT

// Timezone pour les stats Spotube
tz.initializeTimeZones();
```

**Ce qu'on NE prend PAS du main.dart Spotube :**

| Element | Raison |
|---|---|
| `WidgetsApp` / `MaterialApp` | On garde celui de Watchtower |
| `auto_route` router setup | On garde go_router de WT |
| `shadcn_flutter` theme | On garde le thème WT |
| Discord RPC, SMTC Windows | Optionnel phase 2 |

---

## 4. Nouvelles routes go_router à ajouter

```dart
// Dans lib/router/router.dart
GoRoute(path: '/music',           builder: (_, __) => const MusicHomeScreen()),
GoRoute(path: '/musicSearch',     builder: (_, __) => const MusicSearchScreen()),
GoRoute(path: '/musicLibrary',    builder: (_, __) => const MusicLibraryScreen()),
GoRoute(path: '/musicPlaylist',   builder: (_, state) => MusicPlaylistScreen(id: state.extra as String)),
GoRoute(path: '/musicAlbum',      builder: (_, state) => MusicAlbumScreen(id: state.extra as String)),
GoRoute(path: '/musicArtist',     builder: (_, state) => MusicArtistScreen(id: state.extra as String)),
GoRoute(path: '/musicTrack',      builder: (_, state) => MusicTrackScreen(id: state.extra as String)),
GoRoute(path: '/musicLiked',      builder: (_, __) => const MusicLikedPlaylistScreen()),
GoRoute(path: '/musicQueue',      builder: (_, __) => const MusicQueueScreen()),
GoRoute(path: '/musicConnect',    builder: (_, __) => const MusicConnectScreen()),
GoRoute(path: '/musicStats',      builder: (_, __) => const MusicStatsScreen()),
GoRoute(path: '/musicOnboarding', builder: (_, __) => const MusicOnboardingScreen()),
GoRoute(path: '/musicBlacklist',  builder: (_, __) => const MusicBlacklistScreen()),
GoRoute(path: '/musicScrobbling', builder: (_, __) => const MusicScrobblingScreen()),
GoRoute(path: '/musicLastfm',     builder: (_, __) => const MusicLastfmLoginScreen()),
```

---

## 5. Mapping complet des écrans (63 pages)

| Spotube `lib/pages/` | Watchtower `lib/modules/music/pages/` | Route |
|---|---|---|
| `home/home.dart` | `home/music_home_screen.dart` | `/music` |
| `home/sections/featured.dart` | `home/sections/music_featured.dart` | — |
| `home/sections/sections.dart` | `home/sections/music_sections.dart` | — |
| `home/sections/new_releases.dart` | `home/sections/music_new_releases.dart` | — |
| `home/sections/recent.dart` | `home/sections/music_recent.dart` | — |
| `search/search.dart` | `search/music_search_screen.dart` | `/musicSearch` |
| `search/tabs/all.dart` | `search/tabs/music_search_all.dart` | — |
| `search/tabs/albums.dart` | `search/tabs/music_search_albums.dart` | — |
| `search/tabs/artists.dart` | `search/tabs/music_search_artists.dart` | — |
| `search/tabs/playlists.dart` | `search/tabs/music_search_playlists.dart` | — |
| `search/tabs/tracks.dart` | `search/tabs/music_search_tracks.dart` | — |
| `library/library.dart` | `library/music_library_screen.dart` | `/musicLibrary` |
| `library/user_albums.dart` | `library/music_user_albums.dart` | — |
| `library/user_artists.dart` | `library/music_user_artists.dart` | — |
| `library/user_downloads.dart` | `library/music_user_downloads.dart` | — |
| `library/user_playlists.dart` | `library/music_user_playlists.dart` | — |
| `library/user_local_tracks/user_local_tracks.dart` | `library/music_local_tracks.dart` | — |
| `library/user_local_tracks/local_folder.dart` | `library/music_local_folder.dart` | — |
| `playlist/liked_playlist.dart` | `playlist/music_liked_playlist.dart` | `/musicLiked` |
| `playlist/playlist.dart` | `playlist/music_playlist.dart` | `/musicPlaylist` |
| `album/album.dart` | `album/music_album.dart` | `/musicAlbum` |
| `artist/artist.dart` | `artist/music_artist.dart` | `/musicArtist` |
| `artist/section/footer.dart` | `artist/sections/music_artist_footer.dart` | — |
| `artist/section/header.dart` | `artist/sections/music_artist_header.dart` | — |
| `artist/section/related_artists.dart` | `artist/sections/music_related_artists.dart` | — |
| `artist/section/top_tracks.dart` | `artist/sections/music_top_tracks.dart` | — |
| `player/queue.dart` | `player/music_queue.dart` | `/musicQueue` |
| `player/sources.dart` | `player/music_sources.dart` | — |
| `player/lyrics.dart` | `player/music_player_lyrics.dart` | — |
| `lyrics/lyrics.dart` | `lyrics/music_lyrics.dart` | — |
| `lyrics/mini_lyrics.dart` | `lyrics/music_mini_lyrics.dart` | — |
| `lyrics/plain_lyrics.dart` | `lyrics/music_plain_lyrics.dart` | — |
| `lyrics/synced_lyrics.dart` | `lyrics/music_synced_lyrics.dart` | — |
| `connect/connect.dart` | `connect/music_connect.dart` | `/musicConnect` |
| `connect/control/control.dart` | `connect/music_connect_control.dart` | — |
| `getting_started/getting_started.dart` | `onboarding/music_onboarding.dart` | `/musicOnboarding` |
| `getting_started/sections/greeting.dart` | `onboarding/sections/music_onboarding_greeting.dart` | — |
| `getting_started/sections/playback.dart` | `onboarding/sections/music_onboarding_playback.dart` | — |
| `getting_started/sections/region.dart` | `onboarding/sections/music_onboarding_region.dart` | — |
| `getting_started/sections/support.dart` | `onboarding/sections/music_onboarding_support.dart` | — |
| `lastfm_login/lastfm_login.dart` | `lastfm/music_lastfm_login.dart` | `/musicLastfm` |
| `profile/profile.dart` | `profile/music_profile.dart` | — |
| `track/track.dart` | `track/music_track.dart` | `/musicTrack` |
| `stats/stats.dart` | `stats/music_stats.dart` | `/musicStats` |
| `stats/albums/albums.dart` | `stats/music_stats_albums.dart` | — |
| `stats/artists/artists.dart` | `stats/music_stats_artists.dart` | — |
| `stats/fees/fees.dart` | `stats/music_stats_fees.dart` | — |
| `stats/minutes/minutes.dart` | `stats/music_stats_minutes.dart` | — |
| `stats/playlists/playlists.dart` | `stats/music_stats_playlists.dart` | — |
| `stats/streams/streams.dart` | `stats/music_stats_streams.dart` | — |
| `settings/settings.dart` | `settings/music_settings.dart` | (fusionne dans More) |
| `settings/about.dart` | `settings/music_settings_about.dart` | — |
| `settings/blacklist.dart` | `settings/music_blacklist.dart` | `/musicBlacklist` |
| `settings/logs.dart` | `settings/music_settings_logs.dart` | — |
| `settings/metadata_plugins.dart` | `settings/music_metadata_plugins.dart` | Marketplace Music tab |
| `settings/metadata/metadata_form.dart` | `settings/music_metadata_form.dart` | — |
| `settings/scrobbling/scrobbling.dart` | `settings/music_scrobbling.dart` | `/musicScrobbling` |
| `settings/sections/about.dart` | `settings/sections/music_settings_about.dart` | — |
| `settings/sections/accounts.dart` | `settings/sections/music_settings_accounts.dart` | — |
| `settings/sections/appearance.dart` | `settings/sections/music_settings_appearance.dart` | — |
| `settings/sections/desktop.dart` | `settings/sections/music_settings_desktop.dart` | — |
| `settings/sections/developers.dart` | `settings/sections/music_settings_developers.dart` | — |
| `settings/sections/downloads.dart` | `settings/sections/music_settings_downloads.dart` | — |
| `settings/sections/language_region.dart` | `settings/sections/music_settings_language.dart` | — |
| `settings/sections/playback.dart` | `settings/sections/music_settings_playback.dart` | — |

---

## 6. Mapping Modules/Composants (57 fichiers)

Tous les fichiers `lib/modules/X/` de Spotube vont dans `lib/modules/music/components/X/` dans Watchtower.

| Spotube `lib/modules/` | Watchtower `lib/modules/music/components/` |
|---|---|
| `album/` | `album/` |
| `artist/` | `artist/` |
| `auth/` | `auth/` |
| `connect/` | `connect/` |
| `download_manager/` | `download_manager/` |
| `home/` | `home/` |
| `intl/` | `intl/` |
| `library/` | `library/` |
| `lyrics/` | `lyrics/` |
| `player/` | `player/` |
| `player_overlay/` | `player_overlay/` |
| `playlist/` | `playlist/` |
| `root/` | root_shell/ (NE PAS copier — remplacé par dock WT) |
| `settings/` | `settings/` |
| `stats/` | `stats/` |
| `track/` | `track/` |

---

## 7. Mapping Providers (76 fichiers)

Tous les fichiers `lib/provider/X/` de Spotube vont dans `lib/modules/music/provider/X/`.

| Spotube `lib/provider/` | Watchtower `lib/modules/music/provider/` |
|---|---|
| `audio_player/` | `audio_player/` |
| `blacklist_provider.dart` | `blacklist_provider.dart` |
| `connect/` | `connect/` |
| `database/` | `database/` |
| `discord_provider.dart` | `discord_provider.dart` |
| `download_manager_provider.dart` | `download_manager_provider.dart` |
| `glance/` | `glance/` |
| `history/` | `history/` |
| `local_tracks/` | `local_tracks/` |
| `logs/` | `logs/` |
| `lyrics/` | `lyrics/` |
| `metadata_plugin/` | `metadata_plugin/` |
| `scrobbler/` | `scrobbler/` |
| `server/` | `server/` |
| `skip_segments/` | `skip_segments/` |
| `sleep_timer_provider.dart` | `sleep_timer_provider.dart` |
| `track_options/` | `track_options/` |
| `tray_manager/` | `tray_manager/` |
| `user_preferences/` | `user_preferences/` |
| `volume_provider.dart` | `volume_provider.dart` |
| `youtube_engine/` | `youtube_engine/` |

---

## 8. Mapping Services (37 fichiers)

Tous les fichiers `lib/services/X/` de Spotube vont dans `lib/modules/music/services/X/`.

| Spotube `lib/services/` | Watchtower `lib/modules/music/services/` |
|---|---|
| `audio_player/` | `audio_player/` |
| `cli/` | `cli/` |
| `kv_store/` | `kv_store/` |
| `logger/` | `logger/` |
| `wm_tools/` | `wm_tools/` |

---

## 9. Intégration dans Watchtower UI — Câblage précis

### 9.1 Discovery (`lib/modules/search/watchtower_discover_screen.dart`)
```
Pills : [ Série ] [ Manga ] [ Music ] [ Game ]
                             |
                             +--> MusicSearchScreen
                                  (music_search_screen.dart, page Spotube search.dart intacte)
                                  Zéro modification du contenu de la page
```

### 9.2 Hub (`lib/modules/browse/browse_screen.dart`)
```
Tabs: Watch | Manga | Novel | Music | Game
                              |
                              +--> MusicHomeScreen
                                   (music_home_screen.dart, page Spotube home.dart intacte)
                                   Notre dock WT reste (gère le retour)
                                   Spotube's content dans le body
```

### 9.3 Library (`lib/modules/library/main_library_screen.dart`)
```
Sub-dock pills: Watch | Manga | Novel | Music | Games
                                        |
                                        +--> MusicLibraryScreen
                                             (music_library_screen.dart, page Spotube library.dart)
                                             Avec ses sous-tabs natifs :
                                             Playlists | Artists | Albums | Downloads | Local
```

### 9.4 Marketplace (`lib/modules/browse/marketplace_screen.dart`)
```
Tab Music --> MusicMetadataPluginsScreen
             (music_metadata_plugins.dart, page Spotube metadata_plugins.dart intacte)
```

---

## 10. Règles d'adaptation mécaniques (par fichier)

Pour CHAQUE fichier Spotube copié, appliquer ces 5 transformations :

```
1. Remplacer les imports du package :
   import 'package:spotube/...'        -->  import 'package:watchtower/modules/music/...'
   import 'package:hooks_riverpod/...' -->  import 'package:flutter_riverpod/...'

2. Supprimer :
   @RoutePage()
   import 'package:auto_route/...'

3. Remplacer la classe parente :
   HookConsumerWidget  -->  ConsumerStatefulWidget (+ initState/dispose boilerplate)
   HookWidget          -->  StatefulWidget

4. Remplacer la navigation :
   context.router.push(RouteNom())  -->  context.push('/routeName')
   context.router.pop()             -->  context.pop()

5. Widgets shadcn_flutter uniquement si non disponibles :
   shadcn_flutter.Button(...)  -->  ElevatedButton(...)
   shadcn_flutter.Card(...)    -->  Card(...)
   (Si on ajoute shadcn_flutter dans pubspec WT, cette étape n'est pas nécessaire)
```

---

## 11. Ordre d'implémentation

### Phase 1 — Fondation (ne bloque rien d'autre)
- [ ] Ajouter dépendances dans `pubspec.yaml`
- [ ] Copier `lib/services/` de Spotube --> `lib/modules/music/services/`
- [ ] Copier `lib/provider/` de Spotube --> `lib/modules/music/provider/`
- [ ] Copier modèles DB Spotube --> `lib/modules/music/models/`
- [ ] Adapter les imports (`spotube/` --> `watchtower/modules/music/`)
- [ ] Ajouter init audio dans `main.dart`

### Phase 2 — Player (coeur)
- [ ] Copier `lib/modules/player/` de Spotube
- [ ] Copier `lib/modules/player_overlay/` (mini-player)
- [ ] Injecter mini-player dans `main_screen.dart` de WT (au-dessus du dock)

### Phase 3 — Home + Search (Discovery)
- [ ] Copier `lib/pages/home/` --> `music_home_screen.dart`
- [ ] Copier `lib/pages/search/` --> `music_search_screen.dart`
- [ ] Câbler Discovery pill "Music" --> `music_search_screen.dart`
- [ ] Câbler Hub tab "Music" --> `music_home_screen.dart`

### Phase 4 — Library
- [ ] Copier `lib/pages/library/` --> music library pages
- [ ] Câbler Library sub-dock "Music" --> `music_library_screen.dart`
- [ ] Copier pages : playlist, album, artist, track, lyrics

### Phase 5 — Marketplace plugins
- [ ] Copier `lib/pages/settings/metadata_plugins.dart` --> Marketplace Music tab

### Phase 6 — Settings + Extras
- [ ] Copier `lib/pages/settings/` (blacklist, scrobbling, comptes)
- [ ] Copier stats, connect, onboarding
- [ ] Ajouter routes go_router completes

---

## 12. Estimation de taille

| Categorie | Fichiers | Taille source |
|---|---|---|
| Pages Spotube | 63 | ~800 KB |
| Modules/Composants | 57 | ~1 200 KB |
| Providers | 76 | ~1 500 KB |
| Services | 37 | ~650 KB |
| **Total** | **443** | **~4 152 KB source** |

**Impact sur l'APK final :**
- Code Dart compile efficacement (~3-4x compression)
- Nouvelles bibliothèques natives (audio_service) : +3-5 MB APK
- Estimation totale APK : +7-12 MB vs version actuelle

---

## 13. Ce qu'on NE prend PAS de Spotube

| Fichier Spotube | Raison |
|---|---|
| `lib/main.dart` | On garde celui de WT, on merge seulement l'init audio |
| `lib/collections/routes.dart` + `routes.gr.dart` | On utilise go_router de WT |
| `lib/pages/root/root_app.dart` | Le shell est celui de WT (dock, drawer) |
| `lib/modules/root/` (sidebar, navbar) | Remplace par le dock WT |
| Theme shadcn_flutter | On garde le theme WT |
| Assets splash / icônes app | On garde les assets WT |
| `lib/collections/env.dart` | API keys --> variables d'env WT |
