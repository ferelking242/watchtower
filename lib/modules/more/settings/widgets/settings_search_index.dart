/// Single source of truth for the settings search.
///
/// The main Settings screen and every settings sub-page search this index, so
/// a query such as "général" or "don't kill" finds the entry wherever it
/// lives — the search is not limited to the rows of the page that is open.
library;

/// One searchable settings entry.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.page,
    required this.title,
    required this.route,
    this.keywords = const [],
  });

  /// Human-readable name of the page that owns the entry (Général, Affichage…).
  final String page;

  /// Label shown in the results list.
  final String title;

  /// Route opened when the result is tapped.
  final String route;

  /// Extra terms the entry should match on (French and English spellings).
  final List<String> keywords;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (page.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// Every searchable settings entry, grouped by owning page.
const List<SettingsSearchEntry> kSettingsSearchIndex = [
  // ── Général ───────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Général',
    title: 'DNS over HTTPS',
    route: '/general',
    keywords: ['dns', 'doh', 'réseau', 'network', 'chiffrement'],
  ),
  SettingsSearchEntry(
    page: 'Général',
    title: 'DNS personnalisé',
    route: '/general',
    keywords: ['dns', 'custom', 'réseau', 'network'],
  ),
  SettingsSearchEntry(
    page: 'Général',
    title: 'User-Agent par défaut',
    route: '/general',
    keywords: ['user agent', 'ua', 'navigateur', 'browser'],
  ),
  SettingsSearchEntry(
    page: 'Général',
    title: 'Recommandations',
    route: '/recommendations',
    keywords: ['recommandation', 'algorithme', 'similarité', 'poids'],
  ),
  SettingsSearchEntry(
    page: 'Général',
    title: 'Discord Rich Presence',
    route: '/general',
    keywords: ['discord', 'rpc', 'activité', 'activity'],
  ),
  SettingsSearchEntry(
    page: 'Général',
    title: 'Afficher la progression Discord',
    route: '/general',
    keywords: ['discord', 'rpc', 'progression', 'progress'],
  ),

  // ── Affichage ─────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Affichage',
    title: "Langue de l'application",
    route: '/appLanguage',
    keywords: ['langue', 'language', 'locale', 'traduction'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Mode tablette',
    route: '/appearance',
    keywords: ['tablette', 'tablet', 'auto', 'toujours', 'paysage', 'jamais'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Format de date',
    route: '/appearance',
    keywords: ['date', 'format'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Durées relatives',
    route: '/appearance',
    keywords: ['durée', 'relative', 'timestamp', 'horodatage', 'aujourd’hui'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Rendre les images dans les descriptions de mangas',
    route: '/appearance',
    keywords: ['image', 'description', 'manga', 'synopsis'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Thème',
    route: '/appearance',
    keywords: ['thème', 'theme', 'couleur', 'color', 'clair', 'sombre', 'dark'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Mode sombre pur',
    route: '/appearance',
    keywords: ['sombre', 'noir', 'pure black', 'amoled', 'dark'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Niveau de mélange des couleurs',
    route: '/appearance',
    keywords: ['mélange', 'blend', 'couleur', 'color'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Police',
    route: '/appearance',
    keywords: ['police', 'font', 'écriture'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Réorganiser la navigation',
    route: '/customNavigationSettings',
    keywords: ['navigation', 'réorganiser', 'reorder', 'barre'],
  ),
  SettingsSearchEntry(
    page: 'Affichage',
    title: 'Interface & Effets',
    route: '/uiSettings',
    keywords: ['interface', 'effets', 'carousel', 'flou', 'blur', 'animation'],
  ),

  // ── Bibliothèque ──────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Catégories',
    route: '/librarySettings',
    keywords: ['catégorie', 'category', 'rangement'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Modifier les catégories',
    route: '/categories',
    keywords: ['catégorie', 'modifier', 'edit', 'category'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Catégorie par défaut',
    route: '/librarySettings',
    keywords: ['catégorie', 'défaut', 'default'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Réglages de tri par catégorie',
    route: '/librarySettings',
    keywords: ['tri', 'sort', 'catégorie', 'per-category'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Mises à jour automatiques',
    route: '/librarySettings',
    keywords: ['mise à jour', 'update', 'automatique', 'auto'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Restrictions matérielles pour les mises à jour',
    route: '/librarySettings',
    keywords: ['restriction', 'batterie', 'wifi', 'réseau', 'mise à jour'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Catégories des mises à jour (inclure / exclure)',
    route: '/librarySettings',
    keywords: ['catégorie', 'inclure', 'exclure', 'mise à jour'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Actualiser automatiquement les métadonnées',
    route: '/librarySettings',
    keywords: ['métadonnées', 'metadata', 'actualiser', 'refresh'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Vérifier s’il y a une nouvelle couverture ou synopsis',
    route: '/librarySettings',
    keywords: ['couverture', 'cover', 'synopsis', 'métadonnées'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Mise à jour intelligente',
    route: '/librarySettings',
    keywords: ['mise à jour', 'intelligente', 'smart update'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Afficher le nombre de chapitres non lus',
    route: '/librarySettings',
    keywords: ['badge', 'chapitres', 'non lus', 'unread', 'icône'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Action de glisser à gauche',
    route: '/librarySettings',
    keywords: ['glisser', 'swipe', 'gauche', 'left', 'comportement'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Action de glisser à droite',
    route: '/librarySettings',
    keywords: ['glisser', 'swipe', 'droite', 'right', 'comportement'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Marquer un chapitre dupliqué comme lu',
    route: '/librarySettings',
    keywords: ['dupliqué', 'duplicate', 'lu', 'read'],
  ),
  SettingsSearchEntry(
    page: 'Bibliothèque',
    title: 'Masquer les indicateurs de chapitre manquants',
    route: '/librarySettings',
    keywords: ['manquant', 'missing', 'indicateur', 'chapitre'],
  ),

  // ── Lecteur (manga) ───────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Mode de lecture par défaut',
    route: '/readerMode',
    keywords: ['lecture', 'reading mode', 'vertical', 'webtoon'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: "Vitesse d'animation du double-clic",
    route: '/readerMode',
    keywords: ['animation', 'double-clic', 'double tap'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Couleur de fond',
    route: '/readerMode',
    keywords: ['fond', 'background', 'couleur', 'noir'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Nombre de pages à précharger',
    route: '/readerMode',
    keywords: ['précharger', 'preload', 'cache', 'pages'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Type de mise à l’échelle',
    route: '/readerMode',
    keywords: ['échelle', 'scale', 'zoom', 'adapter'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Activer les transitions',
    route: '/readerMode',
    keywords: ['transitions', 'animation', 'page'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Rogner les bordures',
    route: '/readerMode',
    keywords: ['rogner', 'crop', 'bordures', 'borders'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Utiliser les zones tactiles',
    route: '/readerMode',
    keywords: ['zones tactiles', 'tap zones', 'tactile'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Garder l’écran allumé',
    route: '/readerMode',
    keywords: ['écran', 'screen on', 'wakelock', 'allumé'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Navigation par boutons de volume',
    route: '/readerMode',
    keywords: ['volume', 'boutons', 'navigation', 'page'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Afficher les écarts entre les pages',
    route: '/readerMode',
    keywords: ['écarts', 'gaps', 'pages'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Remplissage latéral Webtoon',
    route: '/readerMode',
    keywords: ['webtoon', 'padding', 'latéral', 'side'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur manga',
    title: 'Disposition de navigation',
    route: '/readerMode',
    keywords: ['navigation', 'disposition', 'layout'],
  ),

  // ── Lecteur Vidéo ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Lecteur interne',
    route: '/playerMode',
    keywords: ['lecteur', 'player', 'progression', 'contrôles', 'orientation'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Décodeur',
    route: '/playerDecoderScreen',
    keywords: ['décodeur', 'decoder', 'décodage matériel', 'pixel', 'debanding'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Audio',
    route: '/playerAudioScreen',
    keywords: ['audio', 'langues', 'hauteur', 'canaux', 'pitch'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Boutons personnalisés',
    route: '/customButtonScreen',
    keywords: ['boutons', 'custom', 'lua', 'scripts'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Gestes',
    route: '/playerGestureScreen',
    keywords: [
      'gestes',
      'gesture',
      'double tap',
      'chercher',
      'seek',
      'balayage',
      'swipe',
    ],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Sous-titres',
    route: '/playerSubtitleScreen',
    keywords: [
      'sous-titres',
      'subtitle',
      'langues',
      'liste blanche',
      'liste noire',
    ],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Éditeur de scripts',
    route: '/playerScriptEditor',
    keywords: ['scripts', 'script', 'lua', 'éditeur', 'editor'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Torrent',
    route: '/playerTorrentScreen',
    keywords: ['torrent', 'torrserver', 'streaming'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Fichiers utilisateur',
    route: '/playerAdvancedScreen',
    keywords: ['fichiers', 'user files', 'shaders', 'polices', 'fonts'],
  ),
  SettingsSearchEntry(
    page: 'Lecteur Vidéo',
    title: 'Avancé',
    route: '/playerAdvancedScreen',
    keywords: ['avancé', 'mpv', 'configuration'],
  ),

  // ── Autres pages ──────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: 'Téléchargements',
    title: 'Téléchargements',
    route: '/downloads',
    keywords: ['téléchargement', 'download'],
  ),
  SettingsSearchEntry(
    page: 'Suivi',
    title: 'Suivi',
    route: '/track',
    keywords: ['suivi', 'tracking', 'anilist', 'myanimelist', 'mal'],
  ),
  SettingsSearchEntry(
    page: 'Synchronisation',
    title: 'Synchronisation',
    route: '/sync',
    keywords: ['sync', 'synchronisation', 'cloud'],
  ),
  SettingsSearchEntry(
    page: 'Explorer',
    title: 'Explorer',
    route: '/browseS',
    keywords: ['explorer', 'browse', 'source', 'extension'],
  ),
  SettingsSearchEntry(
    page: 'Sécurité',
    title: 'Sécurité',
    route: '/security',
    keywords: ['sécurité', 'security', 'mot de passe', 'biométrie'],
  ),
  SettingsSearchEntry(
    page: 'Sources locales',
    title: 'Sources locales',
    route: '/localSources',
    keywords: ['local', 'dossier', 'folder', 'fichier'],
  ),
  SettingsSearchEntry(
    page: 'Avancé',
    title: 'Avancé',
    route: '/advanced',
    keywords: ['avancé', 'advanced', 'debug', 'cache', 'logs'],
  ),
  SettingsSearchEntry(
    page: 'Avancé',
    title: "Don't kill my app!",
    route: '/advanced',
    keywords: ['kill', "don't kill", 'batterie', 'arrière-plan', 'background'],
  ),
  SettingsSearchEntry(
    page: 'Music Hub',
    title: 'Music Hub',
    route: '/MusicLibrary',
    keywords: ['musique', 'music', 'audio'],
  ),
  SettingsSearchEntry(
    page: 'Mode distant',
    title: 'Mode distant',
    route: '/remoteMode',
    keywords: ['distant', 'remote', 'wifi'],
  ),
  SettingsSearchEntry(
    page: 'À propos',
    title: 'À propos',
    route: '/about',
    keywords: ['à propos', 'about', 'version', 'info'],
  ),
];

/// Entries matching [query], or every entry when the query is empty.
List<SettingsSearchEntry> searchSettings(String query) {
  if (query.trim().isEmpty) return kSettingsSearchIndex;
  return kSettingsSearchIndex.where((e) => e.matches(query)).toList();
}
