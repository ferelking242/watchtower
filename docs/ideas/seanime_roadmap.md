# Watchtower — Feuille de route inspirée de Seanime

> Analyse complète de **Seanime** (`github.com/5rahim/seanime`) et plan exhaustif
> pour enrichir Watchtower. **Ne jamais supprimer les sections existantes —
> tout est additif.**

---

## 1. Architecture comparée

### Seanime (Go + React/TypeScript)

```
single binary (Go)
├── HTTP REST API  (Fiber framework)
├── WebSocket hub  (événements temps réel)
├── SQLite          (GORM ORM)
├── web/            (React buildé, go:embed)
└── internal/
    ├── server          ← routing, startup
    ├── core            ← instance app, config, logger
    ├── library         ← scan fichiers, matching AniList, NFO
    ├── continuity      ← watch history, reprise précise (timestamp)
    ├── mediastream     ← HLS, transcoding, direct stream, proxy
    ├── mediaplayers    ← mpv, VLC, client externe
    ├── torrent         ← client BitTorrent natif (anacrolix)
    ├── debrid          ← AllDebrid, Real-Debrid, etc.
    ├── discordrpc      ← présence Discord temps réel
    ├── extension       ← plugins JS via Goja (moteur JS en Go)
    ├── nakama          ← watch party P2P
    ├── cron            ← tâches planifiées (refresh, vérif épisodes)
    ├── database        ← SQLite : settings, historique, cache méta
    ├── hook            ← bus d'événements inter-modules
    └── handlers/       ← 30+ fichiers d'endpoints REST
```

### Watchtower (Flutter + Go + Rust)

```
Flutter app (Dart)
├── lib/                ← UI + logique Flutter
├── go/                 ← Serveur BitTorrent (CGo → .so/.dll)
│   ├── server.go       ← client anacrolix torrent + worker pool
│   ├── binding/desktop/main.go   ← binding CGo desktop
│   └── binding/mobile/main.go    ← binding mobile
├── rust/               ← HTTP client (rhttp), EPUB, image (flutter_rust_bridge)
│   └── src/
│       ├── api/rhttp/  ← client HTTP performant
│       ├── api/epub.rs ← traitement EPUB
│       └── api/image.rs
└── extensions/anime/   ← Sources JS (AllAnime, Zoro, Crunchyroll…)
    ├── index.json
    └── src/en/*.js
```

---

## 2. Questions fréquentes

### Les extensions Seanime sont-elles compatibles avec Watchtower ?

**Partiellement.** Les deux systèmes utilisent JavaScript comme langage d'extension,
mais l'API surface est différente :

| Aspect | Seanime | Watchtower |
|--------|---------|------------|
| Moteur JS | Goja (Go) | Flutter JS engine (Dart) |
| Format | `.js` CommonJS | `.js` (format Mangayomi) |
| API fetch | `fetch()` via Go | `fetch()` via Dart/Rust |
| Parsing | Cheerio-style via Go | Dart-side |
| Auth | Headers custom | Headers custom |

**Chemin de migration possible** :
- L'API `fetch`, `html.parse`, les headers sont similaires
- Un adaptateur Watchtower→Seanime peut être écrit pour chaque extension
- Les extensions Seanime les plus simples (GET + JSON parse) peuvent être portées manuellement

### Faut-il ajouter du Go ou un autre langage à Watchtower ?

**Non — Watchtower a déjà la stack optimale :**

| Composant | Langage | Usage actuel |
|-----------|---------|--------------|
| UI & logique métier | Dart/Flutter | ✅ déjà en place |
| BitTorrent | **Go** | ✅ `go/server.go` → worker pool, anacrolix |
| HTTP performant | **Rust** | ✅ `rust/src/api/rhttp/` |
| EPUB | **Rust** | ✅ `rust/src/api/epub.rs` |
| Extensions sources | **JavaScript** | ✅ `extensions/anime/*.js` |

**Pistes d'amélioration sans nouveau langage :**
- Étendre le Go pour : scanning fichiers locaux, HLS streaming, Discord RPC
- Étendre le Rust pour : décodage vidéo thumbnail, transcoding léger
- Utiliser les **Dart Isolates** pour la lourde logique Dart en background
- Le système Go actuel peut déjà recevoir un serveur HTTP complet (cf. `server.go`)

---

## 3. Features Seanime — Liste EXHAUSTIVE

### 3.1 Navigation & Layout

| # | Feature | Fichier Seanime source | Priorité |
|---|---------|----------------------|----------|
| N-01 | **Sidebar transparente** (bg-transparent, `BackdropFilter` blur) | `main-sidebar.tsx`, `app-sidebar.tsx` | 🔴 P1 |
| N-02 | **Sidebar hover-expand** (64px→260px, icônes→labels, 300ms) | `main-sidebar.tsx` | 🔴 P1 |
| N-03 | **Smart sidebar overflow** (ResizeObserver auto-unpin items→"More") | `main-sidebar.tsx` | 🟡 P2 |
| N-04 | **User avatar en bas de sidebar** + dropdown (logout, profil) | `SidebarUser` | 🔴 P1 |
| N-05 | **Badges de notification** sur chaque icône nav (count, dot animé) | `VerticalMenuItem.addon` | 🔴 P1 |
| N-06 | **Top Navbar masquable** (`hideTopNavbar` setting) | `top-navbar.tsx` | 🟡 P2 |
| N-07 | **Sidebar Navbar** (items contextuels si top navbar masquée) | `SidebarNavbar` | 🟡 P2 |
| N-08 | **Retour/Avance** boutons en bas sidebar (desktop) | `main-sidebar.tsx` | 🟢 P3 |
| N-09 | **Plugin Sidebar Tray** (icônes injectables par plugins) | `PluginSidebarTray` | 🟢 P3 |
| N-10 | **Top Indefinite Loader** (barre de progression globale pendant loading) | `top-indefinite-loader` | 🟡 P2 |
| N-11 | **Sea Command** (palette de commandes globale, raccourci clavier) | `sea-command.tsx` | 🟡 P2 |
| N-12 | **Drawer mobile sidebar** (slide depuis gauche sur petits écrans) | `AppSidebar` + `Drawer` | 🟡 P2 |

### 3.2 Page d'accueil — Sections modulaires

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| H-01 | **Hero "Continue Watching"** plein écran | Bannière full-bleed, auto-cycle 8s, pause on hover, dots nav, titre animé | 🔴 P1 |
| H-02 | **Carousel épisodes "Continue"** | Row scrollable de cartes 16:9 avec progress bar | 🔴 P1 |
| H-03 | **Discover Header** (lib vide) | Bannière AniList trending quand aucun media en cours | 🟡 P2 |
| H-04 | **Home Screen modulaire** | Sections activables/réordonnables via modal settings | 🟡 P2 |
| H-05 | **Anime Carousel configurable** | Carousel horizontal, options : genre, année, format, tri, adult | 🔴 P1 |
| H-06 | **Manga Carousel configurable** | Idem pour manga | 🔴 P1 |
| H-07 | **My Lists section** | Listes AniList (Current, Repeating, Planning, Paused, Completed, Dropped) | 🟡 P2 |
| H-08 | **Centered Title** | Section titre libre au milieu | 🟢 P3 |
| H-09 | **Anime Schedule Calendar** | Calendrier des épisodes à venir (perso ou global) | 🟡 P2 |
| H-10 | **Local Library Stats** | Widget stats bibliothèque (count, genres, formats) | 🟢 P3 |
| H-11 | **Custom Library Banner** | Image de fond personnalisée pour l'écran biblio | 🟡 P2 |
| H-12 | **Dynamic Library Banner** | Banner auto (cover de l'épisode en cours, change en scrollant) | 🟡 P2 |
| H-13 | **Home Settings Modal** | Modal pour configurer et réordonner les sections | 🟡 P2 |
| H-14 | **Home Toolbar** | Barre d'outils : filtre genre, vue, actions rapides | 🟡 P2 |
| H-15 | **Manga Library Header** | En-tête dynamique pour la section manga | 🟢 P3 |

### 3.3 Cartes & Carousels

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| C-01 | **MediaEntryCard** portrait | Carte poster 200-250px, ratio portrait, hover scale | 🔴 P1 |
| C-02 | **Badge "In Library"** sur carte | Overlay coloré si le media est dans la bibliothèque | 🔴 P1 |
| C-03 | **Preview trailer** au hover | iframe YouTube apparaît au hover sur la carte | 🟡 P2 |
| C-04 | **Score overlay** sur carte | Score AniList en haut à droite (★ 8.7) | 🔴 P1 |
| C-05 | **Format badge** sur carte | TV / Movie / ONA / OVA / Special | 🟡 P2 |
| C-06 | **EpisodeCard** 16:9 | Carte épisode paysage avec thumbnail, titre, numéro | 🔴 P1 |
| C-07 | **Progress bar** sur EpisodeCard | Barre % de visionnage en bas de la carte épisode | 🔴 P1 |
| C-08 | **Mode spoiler** (blur/replace) | Floute ou remplace image/titre si non-visionné | 🟡 P2 |
| C-09 | **Carousel auto-scroll** | Défilement automatique (désactivable) avec stopOnHover | 🔴 P1 |
| C-10 | **CarouselDotButtons** | Boutons dots de navigation sur les carousels | 🟡 P2 |
| C-11 | **dragFree carousel** | Inertie libre au drag (pas de snap strict) | 🟡 P2 |
| C-12 | **Anime info dans EpisodeCard** | Optionnel : titre anime au-dessus du numéro épisode | 🟢 P3 |
| C-13 | **Legacy episode card** | Ancien style carte épisode (mode compact) | 🟢 P3 |
| C-14 | **Smaller carousel size** option | Cartes épisodes plus petites (setting) | 🟢 P3 |
| C-15 | **Blurred background** sur carte | Fond flou extrait de la couverture | 🟢 P3 |
| C-16 | **Adult content veil** | Masquer les contenus adultes (setting AniList) | 🟡 P2 |

### 3.4 Système de Thème

| # | Paramètre | Type | Défaut |
|---|-----------|------|--------|
| T-01 | `disableSidebarTransparency` | bool | false |
| T-02 | `expandSidebarOnHover` | bool | false |
| T-03 | `hideTopNavbar` | bool | false |
| T-04 | `enableColorSettings` | bool | false |
| T-05 | `accentColor` | Color | #6152df |
| T-06 | `backgroundColor` | Color | #070707 |
| T-07 | `sidebarBackgroundColor` | Color | #070707 |
| T-08 | `libraryScreenBannerType` | enum | dynamic |
| T-09 | `libraryScreenCustomBannerImage` | String | "" |
| T-10 | `libraryScreenCustomBannerPosition` | String | "50% 50%" |
| T-11 | `libraryScreenCustomBannerOpacity` | int | 100 |
| T-12 | `libraryScreenCustomBackgroundImage` | String | "" |
| T-13 | `libraryScreenCustomBackgroundOpacity` | int | 10 |
| T-14 | `libraryScreenCustomBackgroundBlur` | String | "" |
| T-15 | `disableLibraryScreenGenreSelector` | bool | false |
| T-16 | `enableMediaPageBlurredBackground` | bool | false |
| T-17 | `enableMediaCardBlurredBackground` | bool | false |
| T-18 | `mediaPageBannerType` | enum | Default |
| T-19 | `mediaPageBannerSize` | enum | Default |
| T-20 | `mediaPageBannerInfoBoxSize` | enum | Fluid |
| T-21 | `disableCarouselAutoScroll` | bool | false |
| T-22 | `smallerEpisodeCarouselSize` | bool | false |
| T-23 | `showEpisodeCardAnimeInfo` | bool | false |
| T-24 | `useLegacyEpisodeCard` | bool | false |
| T-25 | `hideEpisodeCardDescription` | bool | false |
| T-26 | `hideDownloadedEpisodeCardFilename` | bool | false |
| T-27 | `showAnimeUnwatchedCount` | bool | false |
| T-28 | `showMangaUnreadCount` | bool | true |
| T-29 | `continueWatchingDefaultSorting` | enum | AIRDATE_DESC |
| T-30 | `animeLibraryCollectionDefaultSorting` | enum | TITLE |
| T-31 | `mangaLibraryCollectionDefaultSorting` | enum | TITLE |
| T-32 | `animeEntryScreenLayout` | enum | stacked |
| T-33 | `unpinnedMenuItems` | List\<String\> | [] |
| T-34 | `customCSS` | String | "" |
| T-35 | `mobileCustomCSS` | String | "" |

### 3.5 Bibliothèque & Scan

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| L-01 | **Library View** grille/liste | Toggle entre vue grille et vue liste | 🟡 P2 |
| L-02 | **Detailed Library View** | Vue détaillée avec metadata complète | 🟡 P2 |
| L-03 | **Genre Selector** | Filtre par genre dans la bibliothèque | 🟡 P2 |
| L-04 | **Library Stats widget** | Compteurs : total, en cours, terminés, planifiés | 🟢 P3 |
| L-05 | **Unwatched count badge** | Nombre d'épisodes non-vus sur la carte de série | 🟡 P2 |
| L-06 | **Scanner Modal** | Modal de scan avec progression, logs | 🟡 P2 |
| L-07 | **Library Watcher** | Détection auto de nouveaux fichiers (fsnotify) | 🟢 P3 |
| L-08 | **Unmatched files manager** | Gérer les fichiers non-matchés avec AniList | 🟡 P2 |
| L-09 | **Unknown media manager** | Gérer les médias inconnus | 🟡 P2 |
| L-10 | **Scan summaries** | Historique des scans avec détails | 🟢 P3 |
| L-11 | **Library Explorer Drawer** | Explorateur de fichiers locaux (drawer latéral) | 🟢 P3 |
| L-12 | **Streaming-only mode** | Mode sans bibliothèque locale (stream uniquement) | 🟡 P2 |

### 3.6 Lecture & Continuité

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| P-01 | **Continuity watch history** | Reprise précise (timestamp exact) + % completion | 🔴 P1 |
| P-02 | **Minutes remaining** sur EpisodeCard | "~45 min restantes" calculé depuis timestamp | 🟡 P2 |
| P-03 | **Playback Manager** | Suivi lecture automatique, mise à jour AniList | 🟡 P2 |
| P-04 | **Manual Progress Tracking** | Bouton pour marquer épisode vu manuellement | 🟡 P2 |
| P-05 | **Play Next** | Bouton "épisode suivant" depuis n'importe où | 🔴 P1 |
| P-06 | **Playlist Manager** | Créer des playlists d'épisodes, lecture en séquence | 🟢 P3 |
| P-07 | **External player link** | Ouvrir dans mpv, VLC, etc. | 🟢 P3 |
| P-08 | **Native player** (Electron) | Player vidéo intégré (mode desktop) | 🟢 P3 |
| P-09 | **Continue watching sorting** | Trier "en cours" par : airdate, titre, score | 🟡 P2 |
| P-10 | **IntersectionObserver** header | Image du hero change selon l'épisode visible à l'écran | 🟡 P2 |

### 3.7 Torrents & Debrid

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| TR-01 | **Torrent List** | Vue liste des torrents actifs (déjà en Go) | 🟡 P2 |
| TR-02 | **Active torrent count badge** | Compteur en cours / en pause sur l'icône nav | 🟡 P2 |
| TR-03 | **Seeding count** dans label nav | "Torrent list (3 seeding)" | 🟢 P3 |
| TR-04 | **Debrid section** | Intégration AllDebrid / Real-Debrid | 🟢 P3 |
| TR-05 | **Auto-Downloader** | RSS + règles automatiques de téléchargement | 🟡 P2 |
| TR-06 | **Auto-Downloader queue badge** | Count dans la queue sur icône nav | 🟡 P2 |
| TR-07 | **Direct stream** | Streaming direct depuis URL (sans torrent) | 🟡 P2 |
| TR-08 | **qBittorrent / Transmission** | Support multi-client torrent externe | 🟢 P3 |

### 3.8 Extensions & Plugins

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| E-01 | **Extensions page** | Liste, install, update, désactive extensions | 🟡 P2 |
| E-02 | **Extension update badge** | Badge "1" animé si update dispo | 🟡 P2 |
| E-03 | **Plugin sidebar items** | Extensions peuvent injecter des icônes dans la sidebar | 🟢 P3 |
| E-04 | **Plugin webview slots** | Zones injectables dans l'UI (home top, bottom…) | 🟢 P3 |
| E-05 | **Extension Playground** | Éditeur pour tester une extension en live | 🟢 P3 |
| E-06 | **Plugin issues count** | Badge sur Extensions si un plugin a des erreurs | 🟢 P3 |

### 3.9 Social & Sync

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| S-01 | **Discord Rich Presence** | Affiche "En train de regarder X ep Y" sur Discord | 🟡 P2 |
| S-02 | **Nakama watch party** | Mode multijoueur P2P pour regarder ensemble | 🟢 P3 |
| S-03 | **Nakama host/join** | Host la session, affiche liste des peers connectés | 🟢 P3 |
| S-04 | **AniList refresh button** | Bouton dans sidebar pour forcer refresh collection | 🟡 P2 |
| S-05 | **Offline mode / sync** | Mode hors-ligne avec bibliothèque locale | 🟢 P3 |

### 3.10 Media Page (fiche anime/manga)

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| M-01 | **Banner type** configurable | Default / Blur / Dim / Hide (4 modes) | 🟡 P2 |
| M-02 | **Banner size** configurable | Large ou Smaller | 🟢 P3 |
| M-03 | **Info box layout** | Fluid (pleine largeur) ou Boxed | 🟢 P3 |
| M-04 | **Blurred background** de page | Fond flou extrait du banner | 🟡 P2 |
| M-05 | **Media Preview Modal** | Click sur cover → modal avec infos, sans naviguer | 🟡 P2 |
| M-06 | **Audience Score** | Affichage du score moyen AniList avec icône | 🔴 P1 |
| M-07 | **Context menu** épisodes | Clic droit : ajouter playlist, marquer vu, infos | 🟡 P2 |
| M-08 | **Library badge** dans liste | "Dans ma bibliothèque" sur les résultats de search | 🟡 P2 |

### 3.11 Manga

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| MG-01 | **Manga Library** dédiée | Écran bibliothèque manga séparé | 🟡 P2 |
| MG-02 | **Chapter Downloads Drawer** | Drawer de gestion des téléchargements de chapitres | 🟡 P2 |
| MG-03 | **Unread count badge** | Nombre de chapitres non-lus sur la carte | 🟡 P2 |
| MG-04 | **Manga Library Header** dynamique | En-tête dynamique pour la lib manga | 🟢 P3 |

### 3.12 UI Components (boutons & widgets)

| # | Feature | Description | Flutter impl |
|---|---------|-------------|--------------|
| UI-01 | **GlassButton** `primary-glass` | Bouton avec fond primary + BackdropFilter blur | `ClipRRect` + `BackdropFilter` + `ImageFilter.blur` |
| UI-02 | **GlassButton** `gray-glass` | Bouton gris semi-transparent + blur | idem |
| UI-03 | **GlassButton** `white` | Bouton blanc pur | `Container(color: Colors.white)` |
| UI-04 | **Rounded pill buttons** | Border radius 50 pour les CTA principaux | `BorderRadius.circular(50)` |
| UI-05 | **TextGenerateEffect** | Animation de génération lettre par lettre du titre | `AnimatedBuilder` + offset letters |
| UI-06 | **ProgressBar** | Barre fine de progression (sous épisode, dans media page) | `LinearProgressIndicator` custom |
| UI-07 | **Scroll area masquée** | Scrollbar cachée mais scroll actif | `ScrollbarTheme` + opacity 0 |
| UI-08 | **Badge** | Compteur coloré (rouge/vert/bleu) sur icônes | `Stack` + `Positioned` + `Container` circle |
| UI-09 | **HoverCard** | Popup apparaissant au hover sur un élément | `MouseRegion` + `Overlay` |
| UI-10 | **Confirmation Dialog** | Modal "êtes-vous sûr ?" réutilisable | `AlertDialog` widget |
| UI-11 | **Announcement banner** | Bandeau en haut pour annonces importantes | `MaterialBanner` ou custom |
| UI-12 | **Loading overlay with logo** | Écran de chargement avec logo animé | `Stack` + shimmer |
| UI-13 | **Page Wrapper** | Conteneur de page avec padding/animation standard | `AnimatedContainer` + `SafeArea` |
| UI-14 | **Sea Image** | Wrapper image avec loading shimmer + fallback | `ExtendedImage` + custom placeholder |
| UI-15 | **Sea Link** | Lien navigable (internal + external) | `GestureDetector` + `launchUrl` |

### 3.13 Accessibilité & Settings avancés

| # | Feature | Description | Priorité |
|---|---------|-------------|----------|
| A-01 | **Issue Report** | Bouton/modal pour reporter un bug depuis l'app | 🟢 P3 |
| A-02 | **Error Explainer** | Dialog explicatif sur les erreurs techniques | 🟢 P3 |
| A-03 | **Crash log** | Sauvegarde des crashs dans un fichier log | 🟢 P3 |
| A-04 | **Missing episodes loader** | Calcul épisodes manquants vs schedule | 🟡 P2 |
| A-05 | **Update Modal** | Modal de mise à jour self-contained | 🟡 P2 |
| A-06 | **Changelog tour** | Visite guidée des nouvelles fonctionnalités | 🟢 P3 |
| A-07 | **Multiple language support** | i18n (déjà partiellement dans Watchtower) | 🟡 P2 |
| A-08 | **Custom CSS** | Champ libre pour CSS personnalisé | 🟢 P3 |

---

## 4. Implémentation Flutter — Notes techniques

### Sidebar transparente (N-01)

```dart
// Entourer _TabletLayout sidebar avec BackdropFilter
ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface.withValues(alpha: 0.08),
            colorScheme.surface.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: sidebarContent,
    ),
  ),
)
// IMPORTANT : le widget SOUS la sidebar doit peindre quelque chose
// (image, gradient) sinon BackdropFilter n'a aucun effet
// La bannière hero doit s'étendre derrière la sidebar :
// margin: EdgeInsets.only(left: -sidebarWidth)
```

### Hero auto-cycle (H-01)

```dart
late final Timer _autoCycleTimer;
bool _hovering = false;

void _startCycle() {
  _autoCycleTimer = Timer.periodic(
    Duration(seconds: themeSettings.homeHeroCycleDuration ?? 8),
    (_) { if (!_hovering && mounted) _goToNext(); },
  );
}

// Pour détecter le hover :
MouseRegion(
  onEnter: (_) => setState(() => _hovering = true),
  onExit: (_) => setState(() => _hovering = false),
  child: heroWidget,
)
```

### Carousel auto-scroll (C-09)

```dart
// Dans l'initState du carousel widget :
if (!themeSettings.disableCarouselAutoScroll) {
  _autoScrollTimer = Timer.periodic(
    const Duration(milliseconds: 5000),
    (_) {
      if (_ctrl.hasClients && !_isUserScrolling) {
        final next = (_ctrl.page?.round() ?? 0) + 1;
        _ctrl.animateToPage(
          next % itemCount,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    },
  );
}
```

### Home modulaire (H-04)

```dart
// Provider : ordre des sections
@riverpod
class HomeLayoutNotifier extends _$HomeLayoutNotifier {
  List<HomeSection> build() => _box.get('homeLayout') ?? _defaultLayout();

  void reorder(int oldIndex, int newIndex) {
    final list = List<HomeSection>.from(state);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _box.put('homeLayout', list);
  }

  void toggle(String id, bool enabled) {
    state = state.map((s) => s.id == id ? s.copyWith(enabled: enabled) : s).toList();
    _box.put('homeLayout', state);
  }
}

// Section types
enum HomeSectionType {
  continueWatching,   // H-02
  heroBanner,         // H-01
  spotlight,          // section actuelle "Coup de cœur"
  trendingAnime,      // H-05
  trendingManga,      // H-06
  myLibrary,          // L-01
  schedule,           // H-09
  recentlyAdded,
  myLists,            // H-07
}
```

### TextGenerateEffect (UI-05)

```dart
class TextGenerateEffect extends StatefulWidget {
  final String text;
  // Anime le texte lettre par lettre ou mot par mot
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final visibleLength = (text.length * _controller.value).round();
        return Text(text.substring(0, visibleLength));
      },
    );
  }
}
```

---

## 5. Sprints d'implémentation

### Sprint 1 — UI Foundation (immédiat)

```
[UI-01] GlassButton widget (primary-glass, gray-glass, white, pill)
[N-01]  Sidebar transparente + BackdropFilter sur _TabletLayout
[N-02]  Sidebar hover-expand (collapsed=64px / expanded=220px)
[N-04]  User avatar bas de sidebar + dropdown AniList
[N-05]  Badges de notification sur icônes nav (framework)
[C-01]  MediaEntryCard portrait améliorée (score, format, library badge)
[C-04]  Score AniList overlay sur les cartes
[C-06]  EpisodeCard 16:9 avec thumbnail, numéro, titre
[C-07]  Progress bar sur EpisodeCard
[C-09]  Carousel auto-scroll (timer + stopOnHover)
```

### Sprint 2 — Page d'accueil enrichie

```
[H-01]  Hero "Continue Watching" plein écran (auto-cycle, transitions)
[H-02]  Carousel épisodes "Continue" (avec progress bars)
[P-01]  Continuity — stockage timestamp + % dans Hive
[P-05]  Bouton "Play Next" depuis n'importe quelle card
[H-05]  AnimeCarousel configurable (trending, top rated)
[H-06]  MangaCarousel configurable
[M-06]  Audience Score sur la media page
[UI-05] TextGenerateEffect pour le titre du hero
```

### Sprint 3 — Modularité & Thème

```
[H-04]  Home Screen modulaire (sections activables, drag-and-drop)
[H-13]  Home Settings Modal (réordonner, activer/désactiver)
[T-01→T-35] Système de thème avancé (nouveaux paramètres)
[N-11]  Command palette (Sea Command équivalent)
[N-03]  Smart sidebar overflow (auto-unpin)
[C-08]  Mode spoiler épisodes (blur/replace)
[M-01]  Banner type configurable (Blur/Dim/Hide)
[M-05]  Media Preview Modal
```

### Sprint 4 — Features avancées

```
[H-03]  Discover Header dynamique (lib vide → trending AniList)
[H-09]  Schedule Calendar
[S-01]  Discord Rich Presence (étendre go/server.go)
[TR-01] Torrent List page améliorée
[TR-05] Auto-Downloader avec règles RSS
[E-01]  Extensions page
[E-02]  Extension update badge
[P-06]  Playlist Manager
[MG-01] Manga Library Header dynamique
```

---

## 6. Structure de fichiers cible

```
lib/
├── modules/
│   ├── home/
│   │   ├── watchtower_home_screen.dart     ← EXISTANT (améliorer)
│   │   ├── providers/
│   │   │   ├── home_layout_provider.dart   ← NOUVEAU (H-04)
│   │   │   └── continuity_provider.dart    ← NOUVEAU (P-01)
│   │   └── widgets/
│   │       ├── hero_carousel.dart          ← EXISTANT ✓ amélioré
│   │       ├── continue_watching_hero.dart ← NOUVEAU (H-01)
│   │       ├── episode_card.dart           ← NOUVEAU (C-06/C-07)
│   │       ├── media_entry_card.dart       ← NOUVEAU (C-01)
│   │       ├── trending_carousel.dart      ← NOUVEAU (H-05)
│   │       └── text_generate_effect.dart   ← NOUVEAU (UI-05)
│   │
│   ├── main_view/
│   │   ├── main_screen.dart                ← EXISTANT ✓ amélioré
│   │   └── widgets/
│   │       ├── transparent_sidebar.dart    ← NOUVEAU (N-01/N-02)
│   │       ├── sidebar_nav_item.dart       ← NOUVEAU (N-05)
│   │       ├── sidebar_user_widget.dart    ← NOUVEAU (N-04)
│   │       └── glass_button.dart           ← NOUVEAU (UI-01)
│   │
│   └── more/settings/appearance/
│       ├── custom_navigation_settings.dart ← EXISTANT ✓ amélioré
│       ├── home_layout_settings.dart       ← NOUVEAU (H-13)
│       ├── theme_advanced_settings.dart    ← NOUVEAU (T-xx)
│       └── providers/
│           ├── nav_display_state_provider.dart  ← EXISTANT ✓
│           └── theme_settings_provider.dart     ← ÉTENDRE
│
go/
├── server.go          ← torrent existant → étendre avec Discord RPC, HLS
├── binding/
│   ├── desktop/main.go
│   └── mobile/main.go
│
rust/
├── src/
│   ├── api/rhttp/     ← HTTP client
│   ├── api/epub.rs
│   └── api/image.rs   ← étendre avec thumbnail generation
│
extensions/anime/
├── index.json         ← liste des sources
└── src/en/            ← sources JS existantes
```

---

## 7. Seanime features intentionnellement exclues

| Feature | Raison |
|---------|--------|
| Nakama watch party | Complexité P2P, hors scope MVP |
| Custom CSS injection | Pas pertinent en Flutter natif |
| Chromedp (scraping) | Déjà géré par les extensions JS |
| Protocol Buffers `proto/` | Déjà présent dans Watchtower |
| Electron-specific features | Watchtower cible mobile + desktop cross |
| Go full backend (serveur web) | Watchtower = app native, pas web |

---

*Généré le 24/05/2026 — Source : analyse du code Seanime + architecture Watchtower*
*Fichier local, poussé sur GitHub dans `docs/ideas/`*
