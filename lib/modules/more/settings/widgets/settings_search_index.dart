/// Single source of truth for the settings search.
///
/// The main Settings screen and every settings sub-page search this index, so
/// a query such as "général" or "don't kill" finds the entry wherever it
/// lives — the search is not limited to the rows of the page that is open.
///
/// Page names and row titles are l10n getters, not literals: the results list
/// renders in the active locale, while the matching also considers the raw
/// [keywords] so a French query still finds an English-titled row and vice
/// versa.
library;


import 'package:watchtower/l10n/generated/app_localizations.dart';

/// One searchable settings entry.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.page,
    required this.title,
    required this.route,
    this.keywords = const [],
  });

  /// Localised name of the page that owns the entry (Général, Affichage…).
  final String Function(AppLocalizations l10n) page;

  /// Localised label shown in the results list.
  final String Function(AppLocalizations l10n) title;

  /// Route opened when the result is tapped.
  final String route;

  /// Extra terms the entry should match on (French and English spellings).
  final List<String> keywords;

  bool matches(String query, AppLocalizations l10n) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title(l10n).toLowerCase().contains(q)) return true;
    if (page(l10n).toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// Every searchable settings entry, grouped by owning page.
final List<SettingsSearchEntry> kSettingsSearchIndex = [

  // ── Général ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.settings_idx_title_dns_over_https,
    route: '/general',
    keywords: ['dns', 'doh', 'réseau', 'network', 'chiffrement'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.settings_idx_title_dns_personnalise,
    route: '/general',
    keywords: ['dns', 'custom', 'réseau', 'network'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.settings_idx_title_user_agent_par_defaut,
    route: '/general',
    keywords: ['user agent', 'ua', 'navigateur', 'browser'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.recommendations,
    route: '/recommendations',
    keywords: ['recommandation', 'algorithme', 'similarité', 'poids'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.settings_idx_title_discord_rich_presence,
    route: '/general',
    keywords: ['discord', 'rpc', 'activité', 'activity'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.general,
    title: (l10n) => l10n.settings_idx_title_afficher_la_progression_discord,
    route: '/general',
    keywords: ['discord', 'rpc', 'progression', 'progress'],
  ),
  // ── Affichage ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.app_language,
    route: '/appLanguage',
    keywords: ['langue', 'language', 'locale', 'traduction'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_mode_tablette,
    route: '/appearance',
    keywords: ['tablette', 'tablet', 'auto', 'toujours', 'paysage', 'jamais'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.date_format,
    route: '/appearance',
    keywords: ['date', 'format'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_durees_relatives,
    route: '/appearance',
    keywords: ['durée', 'relative', 'timestamp', 'horodatage', 'aujourd’hui'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_rendre_les_images_dans_les_descriptions_de_mangas,
    route: '/appearance',
    keywords: ['image', 'description', 'manga', 'synopsis'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.theme,
    route: '/appearance',
    keywords: ['thème', 'theme', 'couleur', 'color', 'clair', 'sombre', 'dark'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_mode_sombre_pur,
    route: '/appearance',
    keywords: ['sombre', 'noir', 'pure black', 'amoled', 'dark'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_niveau_de_melange_des_couleurs,
    route: '/appearance',
    keywords: ['mélange', 'blend', 'couleur', 'color'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.font,
    route: '/appearance',
    keywords: ['police', 'font', 'écriture'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_reorganiser_la_navigation,
    route: '/customNavigationSettings',
    keywords: ['navigation', 'réorganiser', 'reorder', 'barre'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.display,
    title: (l10n) => l10n.settings_idx_title_interface_effets,
    route: '/uiSettings',
    keywords: ['interface', 'effets', 'carousel', 'flou', 'blur', 'animation'],
  ),
  // ── Bibliothèque ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.categories,
    route: '/librarySettings',
    keywords: ['catégorie', 'category', 'rangement'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.edit_categories,
    route: '/categories',
    keywords: ['catégorie', 'modifier', 'edit', 'category'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_categorie_par_defaut,
    route: '/librarySettings',
    keywords: ['catégorie', 'défaut', 'default'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_reglages_de_tri_par_categorie,
    route: '/librarySettings',
    keywords: ['tri', 'sort', 'catégorie', 'per-category'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_mises_a_jour_automatiques,
    route: '/librarySettings',
    keywords: ['mise à jour', 'update', 'automatique', 'auto'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_restrictions_materielles_pour_les_mises_a_jour,
    route: '/librarySettings',
    keywords: ['restriction', 'batterie', 'wifi', 'réseau', 'mise à jour'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_categories_des_mises_a_jour_inclure_exclure,
    route: '/librarySettings',
    keywords: ['catégorie', 'inclure', 'exclure', 'mise à jour'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_actualiser_automatiquement_les_metadonnees,
    route: '/librarySettings',
    keywords: ['métadonnées', 'metadata', 'actualiser', 'refresh'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_verifier_sil_y_a_une_nouvelle_couverture_ou_synopsis,
    route: '/librarySettings',
    keywords: ['couverture', 'cover', 'synopsis', 'métadonnées'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_mise_a_jour_intelligente,
    route: '/librarySettings',
    keywords: ['mise à jour', 'intelligente', 'smart update'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_afficher_le_nombre_de_chapitres_non_lus,
    route: '/librarySettings',
    keywords: ['badge', 'chapitres', 'non lus', 'unread', 'icône'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_action_de_glisser_a_gauche,
    route: '/librarySettings',
    keywords: ['glisser', 'swipe', 'gauche', 'left', 'comportement'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_action_de_glisser_a_droite,
    route: '/librarySettings',
    keywords: ['glisser', 'swipe', 'droite', 'right', 'comportement'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_marquer_un_chapitre_duplique_comme_lu,
    route: '/librarySettings',
    keywords: ['dupliqué', 'duplicate', 'lu', 'read'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.library,
    title: (l10n) => l10n.settings_idx_title_masquer_les_indicateurs_de_chapitre_manquants,
    route: '/librarySettings',
    keywords: ['manquant', 'missing', 'indicateur', 'chapitre'],
  ),
  // ── Lecteur manga ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.default_reading_mode,
    route: '/readerMode',
    keywords: ['lecture', 'reading mode', 'vertical', 'webtoon'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.double_tap_animation_speed,
    route: '/readerMode',
    keywords: ['animation', 'double-clic', 'double tap'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.background_color,
    route: '/readerMode',
    keywords: ['fond', 'background', 'couleur', 'noir'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.reader_pages_preload,
    route: '/readerMode',
    keywords: ['précharger', 'preload', 'cache', 'pages'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.settings_idx_title_type_de_mise_a_lechelle,
    route: '/readerMode',
    keywords: ['échelle', 'scale', 'zoom', 'adapter'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.animate_page_transitions,
    route: '/readerMode',
    keywords: ['transitions', 'animation', 'page'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.crop_borders,
    route: '/readerMode',
    keywords: ['rogner', 'crop', 'bordures', 'borders'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.use_page_tap_zones,
    route: '/readerMode',
    keywords: ['zones tactiles', 'tap zones', 'tactile'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.settings_idx_title_garder_lecran_allume,
    route: '/readerMode',
    keywords: ['écran', 'screen on', 'wakelock', 'allumé'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.settings_idx_title_navigation_par_boutons_de_volume,
    route: '/readerMode',
    keywords: ['volume', 'boutons', 'navigation', 'page'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.show_page_gaps,
    route: '/readerMode',
    keywords: ['écarts', 'gaps', 'pages'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.webtoon_side_padding,
    route: '/readerMode',
    keywords: ['webtoon', 'padding', 'latéral', 'side'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.reader_manga,
    title: (l10n) => l10n.navigation_layout,
    route: '/readerMode',
    keywords: ['navigation', 'disposition', 'layout'],
  ),
  // ── Lecteur Vidéo ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.internal_player,
    route: '/playerMode',
    keywords: ['lecteur', 'player', 'progression', 'contrôles', 'orientation'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.decoder,
    route: '/playerDecoderScreen',
    keywords: ['décodeur', 'decoder', 'décodage matériel', 'pixel', 'debanding'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.video_audio,
    route: '/playerAudioScreen',
    keywords: ['audio', 'langues', 'hauteur', 'canaux', 'pitch'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.custom_buttons,
    route: '/customButtonScreen',
    keywords: ['boutons', 'custom', 'lua', 'scripts'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_idx_title_gestes,
    route: '/playerGestureScreen',
    keywords: ['gestes', 'gesture', 'double tap', 'chercher', 'seek', 'balayage', 'swipe'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_idx_title_sous_titres,
    route: '/playerSubtitleScreen',
    keywords: ['sous-titres', 'subtitle', 'langues', 'liste blanche', 'liste noire'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_idx_title_editeur_de_scripts,
    route: '/playerScriptEditor',
    keywords: ['scripts', 'script', 'lua', 'éditeur', 'editor'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_idx_title_torrent,
    route: '/playerTorrentScreen',
    keywords: ['torrent', 'torrserver', 'streaming'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_idx_title_fichiers_utilisateur,
    route: '/playerAdvancedScreen',
    keywords: ['fichiers', 'user files', 'shaders', 'polices', 'fonts'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_lecteur_video,
    title: (l10n) => l10n.settings_advanced,
    route: '/playerAdvancedScreen',
    keywords: ['avancé', 'mpv', 'configuration'],
  ),
  // ── Téléchargements ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.downloads,
    title: (l10n) => l10n.downloads,
    route: '/downloads',
    keywords: ['téléchargement', 'download'],
  ),
  // ── Sauvegarde automatique ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_auto_backup,
    title: (l10n) => l10n.settings_auto_backup,
    route: '/autoBackup',
    keywords: ['sauvegarde', 'backup', 'restauration', 'restore', 'cache', 'réglages', 'settings', 'bibliothèque', 'library', 'désinstallation', 'uninstall'],
  ),
  // ── Suivi ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.tracking,
    title: (l10n) => l10n.tracking,
    route: '/track',
    keywords: ['suivi', 'tracking', 'anilist', 'myanimelist', 'mal'],
  ),
  // ── Synchronisation ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.syncing,
    title: (l10n) => l10n.syncing,
    route: '/sync',
    keywords: ['sync', 'synchronisation', 'cloud'],
  ),
  // ── Explorer ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.browse,
    title: (l10n) => l10n.browse,
    route: '/browseS',
    keywords: ['explorer', 'browse', 'source', 'extension'],
  ),
  // ── Sécurité ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.security,
    title: (l10n) => l10n.security,
    route: '/security',
    keywords: ['sécurité', 'security', 'mot de passe', 'biométrie'],
  ),
  // ── Sources locales ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_sources_locales,
    title: (l10n) => l10n.settings_idx_title_sources_locales,
    route: '/localSources',
    keywords: ['local', 'dossier', 'folder', 'fichier'],
  ),
  // ── Avancé ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_advanced,
    title: (l10n) => l10n.settings_advanced,
    route: '/advanced',
    keywords: ['avancé', 'advanced', 'debug', 'cache', 'logs'],
  ),
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_advanced,
    title: (l10n) => l10n.settings_idx_title_dont_kill_my_app,
    route: '/advanced',
    keywords: ['kill', 'don\'t kill', 'batterie', 'arrière-plan', 'background'],
  ),
  // ── Music Hub ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_music_hub,
    title: (l10n) => l10n.settings_music_hub,
    route: '/MusicLibrary',
    keywords: ['musique', 'music', 'audio'],
  ),
  // ── Mode distant ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.settings_idx_page_mode_distant,
    title: (l10n) => l10n.settings_idx_title_mode_distant,
    route: '/remoteMode',
    keywords: ['distant', 'remote', 'wifi'],
  ),
  // ── À propos ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    page: (l10n) => l10n.about,
    title: (l10n) => l10n.about,
    route: '/about',
    keywords: ['à propos', 'about', 'version', 'info'],
  ),
];

/// Entries matching [query], or every entry when the query is empty.
List<SettingsSearchEntry> searchSettings(
  String query,
  AppLocalizations l10n,
) {
  if (query.trim().isEmpty) return kSettingsSearchIndex;
  return kSettingsSearchIndex.where((e) => e.matches(query, l10n)).toList();
}
