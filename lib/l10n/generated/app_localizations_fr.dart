// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get library => 'Bibliothèque';

  @override
  String get updates => 'Nouveautés';

  @override
  String get history => 'Historique';

  @override
  String get browse => 'Explorer';

  @override
  String get more => 'Plus';

  @override
  String get open_random_entry => 'Ouvrir une entrée au hasard';

  @override
  String get import => 'Importer';

  @override
  String get filter => 'Filtre';

  @override
  String get ignore_filters => 'Ignorer les filtres';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get unread => 'Non lus';

  @override
  String get unwatched => 'Non regardé';

  @override
  String get started => 'Commencé';

  @override
  String get bookmarked => 'Signets';

  @override
  String get sort => 'Trier';

  @override
  String get alphabetically => 'Alphabétiquement';

  @override
  String get last_read => 'Dernier lu';

  @override
  String get last_watched => 'Dernièrement regardé';

  @override
  String get last_update_check => 'Dernière mise à jour';

  @override
  String last_entry_delete_warning(
    num count,
    Object entryType,
    Object entryTypePlural,
    Object mediaType,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tu es en train de supprimer les $count $entryTypePlural de ce $mediaType de ta bibliothèque.',
      one:
          'Tu es en train de supprimer le seul $entryType de ce $mediaType de ta bibliothèque.',
    );
    return '$_temp0\nÇa va aussi supprimer tout le $mediaType de ta bibliothèque.\n\nNote : Les fichiers ne seront pas supprimés.';
  }

  @override
  String get chapter => 'chapitre';

  @override
  String get episode => 'épisode';

  @override
  String get unread_count => 'Nombre de non-lus';

  @override
  String get unwatched_count => 'Nombre non vu';

  @override
  String get latest_chapter => 'Dernier chapitre';

  @override
  String get latest_episode => 'Dernier épisode';

  @override
  String get date_added => 'Date ajoutée';

  @override
  String get display => 'Affichage';

  @override
  String get display_mode => 'Mode d\'affichage';

  @override
  String get compact_grid => 'Grille compacte';

  @override
  String get compression_level => 'Niveau de compression';

  @override
  String compression_info(Object level) {
    return 'La compression plus élevée = moins d\'espace mais plus d\'utilisation CPU. Par défaut: $level';
  }

  @override
  String get comfortable_grid => 'Grille espacée';

  @override
  String get cover_only_grid => 'Grille avec seulement la couverture';

  @override
  String get list => 'Liste';

  @override
  String get badges => 'Badges';

  @override
  String get downloaded_chapters => 'Chapitres téléchargés';

  @override
  String get downloaded_episodes => 'Épisodes téléchargés';

  @override
  String get language => 'Langue';

  @override
  String get local_source => 'Source locale';

  @override
  String get overlay => 'Superposition';

  @override
  String get show_unread_chapters => 'Chapitres non lus';

  @override
  String get random => 'Aléatoire';

  @override
  String get release_date => 'Date de sortie';

  @override
  String get folder_name => 'Nom du dossier';

  @override
  String get chapter_fetch_date => 'Date de récupération du chapitre';

  @override
  String get nsfw_only => 'R18';

  @override
  String get tabs => 'Onglets';

  @override
  String get show_category_tabs => 'Afficher les onglets des catégories';

  @override
  String get show_numbers_of_items => 'Afficher le nombre d’entrées';

  @override
  String get other => 'Autre';

  @override
  String get show_continue_reading_buttons =>
      'Afficher le bouton Continuer la lecture';

  @override
  String get show_continue_watching_buttons =>
      'Afficher les boutons de reprise';

  @override
  String get empty_library => 'Votre bibliothèque est vide';

  @override
  String get search => 'Rechercher...';

  @override
  String get no_recent_updates => 'Aucune mise à jour disponible';

  @override
  String get remove_everything => 'Tout retirer';

  @override
  String get remove_everything_msg =>
      'Êtes-vous sûr(e) ? Tout l\'historique sera effacé.';

  @override
  String get remove_all_update_msg =>
      'Êtes-vous sûr ? Toute la mise à jour sera effacée';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get remove => 'Supprimer';

  @override
  String get remove_history_msg =>
      'Ceci enlèvera la date de lecture de ce chapitre. Êtes-vous sûr(e) ?';

  @override
  String get last_used => 'Dernière utilisée';

  @override
  String get pinned => 'Épinglé';

  @override
  String get sources => 'Sources';

  @override
  String get install => 'Installer';

  @override
  String get update => 'Mettre à jour';

  @override
  String get latest => 'Récents';

  @override
  String get extensions => 'Extensions';

  @override
  String get migrate => 'Migrer';

  @override
  String get mass_migration_title => 'Migration massive';

  @override
  String get mass_migration_preview_items => 'Aperçu des éléments';

  @override
  String get mass_migration_destination_source => 'Destination source';

  @override
  String get mass_migration_no_library_items =>
      'No library items are available for mass migration.';

  @override
  String get mass_migration_no_destination_sources =>
      'No installed destination sources are available.';

  @override
  String get mass_migration_installed => 'Installed';

  @override
  String mass_migration_items_ready_for_review(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items ready for review',
      one: '1 item ready for review',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_item_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_select_destination_source =>
      'Select destination source';

  @override
  String mass_migration_finding_matches(Object source, Object language) {
    return 'Finding matches in $source • $language';
  }

  @override
  String mass_migration_processing_item(int current, int total) {
    return 'Processing item $current of $total';
  }

  @override
  String get mass_migration_waiting_next_item =>
      'Waiting 2 seconds before the next item...';

  @override
  String get mass_migration_waiting_next_migration =>
      'Waiting 2 seconds before the next migration...';

  @override
  String mass_migration_matched_so_far(int count) {
    return 'Matched so far: $count';
  }

  @override
  String mass_migration_no_match_count(int count) {
    return 'No match: $count';
  }

  @override
  String mass_migration_review_matches(Object source) {
    return 'Review matches for $source';
  }

  @override
  String mass_migration_found_matches(int count) {
    return 'Found matches: $count';
  }

  @override
  String mass_migration_no_matches(int count) {
    return 'No matches: $count';
  }

  @override
  String mass_migration_selected_to_migrate(int count) {
    return 'Selected to migrate: $count';
  }

  @override
  String get mass_migration_finish_review => 'Finish review';

  @override
  String mass_migration_migrate_selected(int count) {
    return 'Migrate selected items ($count)';
  }

  @override
  String mass_migration_migrating_selected(Object source) {
    return 'Migrating selected items to $source';
  }

  @override
  String get mass_migration_no_items_selected =>
      'No items selected for migration.';

  @override
  String mass_migration_migrating_item(int current, int total) {
    return 'Migrating item $current of $total';
  }

  @override
  String get mass_migration_complete => 'Mass migration complete';

  @override
  String get mass_migration_complete_success_message =>
      'All selected items were processed successfully.';

  @override
  String get mass_migration_complete_partial_message =>
      'Migration finished with a few items that still need manual attention.';

  @override
  String mass_migration_route_summary(Object source, Object destination) {
    return '$source → $destination';
  }

  @override
  String get mass_migration_processed => 'Processed';

  @override
  String get mass_migration_matched => 'Matched';

  @override
  String get mass_migration_migrated => 'Migrated';

  @override
  String get mass_migration_skipped => 'Skipped';

  @override
  String get mass_migration_failed => 'Failed';

  @override
  String get mass_migration_failed_items => 'Failed Items';

  @override
  String get mass_migration_exit => 'Exit Mass Migration';

  @override
  String get mass_migration_no_destination_match =>
      'No destination match found';

  @override
  String mass_migration_query(Object query) {
    return 'Query: $query';
  }

  @override
  String get mass_migration_skip => 'Skip';

  @override
  String get mass_migration_loading => 'Loading...';

  @override
  String get mass_migration_choose_another_result => 'Choose another result';

  @override
  String get mass_migration_source_chapters => 'Source chapters';

  @override
  String get mass_migration_destination_chapters => 'Destination chapters';

  @override
  String mass_migration_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_source_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count source chapters',
      one: '1 source chapter',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_destination_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destination chapters',
      one: '1 destination chapter',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_no_chapters_found => 'No chapters found.';

  @override
  String mass_migration_and_more_chapters(int count) {
    return 'And $count more...';
  }

  @override
  String get mass_migration_unknown_title => 'Unknown title';

  @override
  String get mass_migration_unknown_match => 'Unknown match';

  @override
  String get mass_migration_unknown_source => 'Unknown source';

  @override
  String get mass_migration_unknown_chapter => 'Unknown chapter';

  @override
  String get migrate_confirm => 'Migrer vers une autre source';

  @override
  String get clean_database => 'Nettoyer la base de données';

  @override
  String cleaned_database(Object x) {
    return 'Base de données nettoyée ! $x entrées supprimées';
  }

  @override
  String get clean_database_desc =>
      'Cela supprimera tous les éléments qui ne sont pas ajoutés à la bibliothèque !';

  @override
  String get incognito_mode => 'Mode navigation privée';

  @override
  String get incognito_mode_description => 'Suspend l\'historique de lecture';

  @override
  String get downloaded_only => 'Téléchargés uniquement';

  @override
  String get downloaded_only_description =>
      'Afficher uniquement les entrées téléchargées dans votre bibliothèque';

  @override
  String get download_queue => 'File de téléchargement';

  @override
  String get categories => 'Catégories';

  @override
  String get statistics => 'Statistiques';

  @override
  String get settings => 'Paramètres';

  @override
  String get about => 'À propos';

  @override
  String get help => 'Aide';

  @override
  String get no_downloads => 'Aucun téléchargement en cours';

  @override
  String get edit_categories => 'Modifier les catégories';

  @override
  String get edit_categories_description =>
      'Vous n\'avez aucune catégorie. Appuyez sur le bouton « + » pour en créer une afin d\'organiser votre bibliothèque.';

  @override
  String get add => 'Ajouter';

  @override
  String get add_category => 'Ajouter une catégorie';

  @override
  String get name => 'Nom';

  @override
  String get category_name_required => '*obligatoire';

  @override
  String get add_category_error_exist =>
      'Une catégorie avec ce nom existe déjà !';

  @override
  String get delete_category => 'Effacer catégorie';

  @override
  String delete_category_msg(Object name) {
    return 'Souhaitez-vous supprimer la catégorie $name?';
  }

  @override
  String get rename_category => 'Renommer la catégorie';

  @override
  String get general => 'Général';

  @override
  String get general_subtitle => 'Langue de l\'application';

  @override
  String get app_language => 'Langue de l\'application';

  @override
  String get default_subtitle_language => 'Langue des sous-titres par défaut';

  @override
  String get appearance => 'Apparence';

  @override
  String get appearance_subtitle => 'Thème, format de la date et de l\'heure';

  @override
  String get theme => 'Thème';

  @override
  String get dark_mode => 'Mode sombre';

  @override
  String get follow_system_theme => 'Suivre le thème du système';

  @override
  String get on => 'Activé';

  @override
  String get off => 'Desactivé';

  @override
  String get pure_black_dark_mode => 'Mode noir pur';

  @override
  String get timestamp => 'Horodatage';

  @override
  String get relative_timestamp => 'Horodatages relatifs';

  @override
  String get relative_timestamp_short => 'Court (Aujourd\'hui, Hier)';

  @override
  String get relative_timestamp_long => 'Long (Court+, il y a n jours)';

  @override
  String get date_format => 'Format de date';

  @override
  String get reader => 'Lecteur';

  @override
  String get reader_manga => 'Lecteur manga';

  @override
  String get refresh => 'Actualiser';

  @override
  String get reader_subtitle => 'Mode de lecture, affichage, navigation';

  @override
  String get default_reading_mode => 'Mode de lecture par défaut';

  @override
  String get reading_mode_vertical => 'Vertical';

  @override
  String get reading_mode_horizontal => 'Horizontal';

  @override
  String get reading_mode_left_to_right => 'De gauche à droite';

  @override
  String get reading_mode_right_to_left => 'De droite à gauche';

  @override
  String get reading_mode_vertical_continuous => 'Vertical continu';

  @override
  String get reading_mode_webtoon => 'Webtoon';

  @override
  String get double_tap_animation_speed =>
      'Vitesse d\'animation du double-clic';

  @override
  String get normal => 'Normale';

  @override
  String get fast => 'Rapide';

  @override
  String get no_animation => 'Sans animation';

  @override
  String get animate_page_transitions => 'Activer les transitions';

  @override
  String get crop_borders => 'Rogner les bordures';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get downloads_subtitle => 'Paramètres de téléchargement';

  @override
  String get download_location => 'Répertoire de téléchargement';

  @override
  String get custom_location => 'Répertoire personnalisé';

  @override
  String get only_on_wifi => 'Uniquement en Wi-Fi';

  @override
  String get save_as_cbz_archive => 'Enregistrer comme archive CBZ';

  @override
  String get delete_download_after_reading => 'Supprimer après la lecture';

  @override
  String get concurrent_downloads => 'Téléchargements simultanés';

  @override
  String get browse_subtitle => 'Sources, extensions, recherche globale';

  @override
  String get only_include_pinned_sources =>
      'N\'inclure que les sources épinglées';

  @override
  String get nsfw_sources => 'Contenu +18';

  @override
  String get nsfw_sources_show =>
      'Afficher dans les listes de sources et d\'extensions';

  @override
  String get nsfw_sources_info =>
      'Ceci n\'empêche pas les extensions non officielles ou potentiellement mal signalées de diffuser du contenu +18 dans l\'application.';

  @override
  String get version => 'Version';

  @override
  String get check_for_update => 'Rechercher des mises à jour';

  @override
  String get logs_on => 'Activer la journalisation';

  @override
  String get share_app_logs => 'Partager les journaux de l\'application';

  @override
  String get no_app_logs => 'Aucun fichier log.txt disponible !';

  @override
  String get failed => 'Échoué !';

  @override
  String n_days_ago(Object days) {
    return 'Il y a $days jours';
  }

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get a_week_ago => 'Il y a une semaine';

  @override
  String get next_week => 'La semaine prochaine';

  @override
  String get add_to_library => 'Ajouter à la bibliothèque';

  @override
  String get added_to_library => 'Ajouté à la bibliothèque';

  @override
  String get completed => 'Terminé';

  @override
  String get ongoing => 'En cours';

  @override
  String get on_hiatus => 'En pause';

  @override
  String get canceled => 'Annulé';

  @override
  String get publishing_finished => 'Publication terminée';

  @override
  String get unknown => 'Inconnue';

  @override
  String get set_categories => 'Ajouter une catégorie';

  @override
  String get edit => 'Modifier';

  @override
  String get in_library => 'Dans la bibliothèque';

  @override
  String get filter_scanlator_groups => 'Filtrer les groupes des traducteurs';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get by_source => 'Par source';

  @override
  String get by_chapter_number => 'Par numéro de chapitre';

  @override
  String get by_episode_number => 'Par numéro d\'épisode';

  @override
  String get by_upload_date => 'Par date de téléversement';

  @override
  String get source_title => 'Titre de la source';

  @override
  String get chapter_number => 'Numéro de chapitre';

  @override
  String get episode_number => 'Numéro d\'épisode';

  @override
  String get share => 'Partager';

  @override
  String n_chapters(Object n) {
    return '$n chapitres';
  }

  @override
  String get no_description => 'Aucune description';

  @override
  String get resume => 'Reprendre';

  @override
  String get read => 'Commencer';

  @override
  String get watch => 'Regarder';

  @override
  String get popular => 'Populaire';

  @override
  String get open_in_browser => 'Ouvrir dans le navigateur';

  @override
  String get clear_cookie => 'Effacer les cookies';

  @override
  String get show_page_number => 'Afficher le numéro des pages';

  @override
  String get from_library => 'De la bibliothèque';

  @override
  String get downloaded_chapter => 'Chapitres téléchargés';

  @override
  String page(Object page) {
    return 'Page $page';
  }

  @override
  String get global_search => 'Recherche globale';

  @override
  String get color_blend_level => 'Mélange des couleurs';

  @override
  String current(Object char) {
    return 'En cours $char';
  }

  @override
  String finished(Object char) {
    return 'Terminé $char';
  }

  @override
  String next(Object char) {
    return 'Suivant $char';
  }

  @override
  String previous(Object char) {
    return 'Précédent $char';
  }

  @override
  String get no_more_chapter => 'C\'était le dernier chapitre';

  @override
  String get no_result => 'Aucun résultat';

  @override
  String get send => 'Envoyer';

  @override
  String get delete => 'Supprimer';

  @override
  String get start_downloading => 'Commencer à télécharger';

  @override
  String get retry => 'Réessayer';

  @override
  String get add_chapters => 'Ajouter des chapitres';

  @override
  String get delete_chapters => 'Supprimer le chapitre ?';

  @override
  String get default0 => 'défaut';

  @override
  String get total_chapters => 'Nombre de chapitres';

  @override
  String get total_episodes => 'Total des épisodes';

  @override
  String get import_local_file => 'Importer des fichiers';

  @override
  String get import_files => 'Fichiers';

  @override
  String get split_epub_chapters => 'Diviser en chapitres';

  @override
  String get split_epub_chapters_description =>
      'Importer chaque chapitre EPUB comme une entrée séparée';

  @override
  String get nothing_read_recently => 'Rien de lu recemment';

  @override
  String get status => 'Statut';

  @override
  String get not_started => 'Pas commencé';

  @override
  String get score => 'Note';

  @override
  String get start_date => 'Date de début';

  @override
  String get finish_date => 'Date de fin';

  @override
  String get reading => 'En cours';

  @override
  String get on_hold => 'En pause';

  @override
  String get dropped => 'Abandonné';

  @override
  String get plan_to_read => 'À lire';

  @override
  String get re_reading => 'Relecture';

  @override
  String get chapters => 'Chapitres';

  @override
  String get add_tracker => 'Ajouter le suivi';

  @override
  String get one_tracker => 'Suivi par 1 service';

  @override
  String n_tracker(Object n) {
    return 'Suivi par $n services';
  }

  @override
  String get tracking => 'Suivi';

  @override
  String get syncing => 'Synchronisation';

  @override
  String get sync_password => 'Mot de passe (au moins 8 caractères)';

  @override
  String get sync_logged => 'Connexion réussie';

  @override
  String get syncing_subtitle =>
      'Synchronisez votre progression sur plusieurs appareils via un serveur auto-hébergé. Consultez notre serveur discord pour plus d\'informations !';

  @override
  String get last_sync_manga => 'Dernière synchro du manga à :';

  @override
  String get last_sync_history => 'Dernière synchro historique au :';

  @override
  String get last_sync_update =>
      'Dernière mise à jour de la synchronisation au :';

  @override
  String get sync_server => 'Adresse du serveur de synchronisation';

  @override
  String get sync_login_invalid_creds => 'E-mail ou mot de passe invalide';

  @override
  String get sync_starting => 'Synchronisation de départ...';

  @override
  String get sync_finished => 'Synchronisation terminée';

  @override
  String get sync_failed => 'Échec de la synchronisation';

  @override
  String get sync_button_sync => 'Synchroniser les progrès';

  @override
  String get sync_button_upload => 'Téléverser uniquement';

  @override
  String get sync_button_upload_info =>
      'Cette opération remplacera complètement les données distantes par les données locales !';

  @override
  String get sync_button_download => 'Télécharger uniquement';

  @override
  String get sync_button_download_info =>
      'Cette opération remplacera complètement les données locales par les données distantes !';

  @override
  String get sync_on => 'Activer la synchronisation';

  @override
  String get sync_auto => 'Synchronisation automatique';

  @override
  String get sync_auto_warning =>
      'La synchronisation automatique est actuellement une fonctionnalité expérimentale !';

  @override
  String get sync_auto_off => 'Désactivé';

  @override
  String get sync_auto_5_minutes => 'Toutes les 5 minutes';

  @override
  String get sync_auto_10_minutes => 'Toutes les 10 minutes';

  @override
  String get sync_auto_30_minutes => 'Toutes les 30 minutes';

  @override
  String get sync_auto_1_hour => 'Toutes les 1 heure';

  @override
  String get sync_auto_3_hours => 'Toutes les 3 heures';

  @override
  String get sync_auto_6_hours => 'Toutes les 6 heures';

  @override
  String get sync_auto_12_hours => 'Toutes les 12 heures';

  @override
  String get server_error => 'Erreur du serveur !';

  @override
  String get dialog_confirm => 'Confirmer';

  @override
  String get description => 'Description';

  @override
  String get reorder_navigation => 'Personnaliser la navigation';

  @override
  String get reorder_navigation_description =>
      'Réorganisez et ajustez chaque navigation selon vos besoins.';

  @override
  String get full_screen_player => 'Utiliser le mode plein écran';

  @override
  String get full_screen_player_info =>
      'Utiliser automatiquement le mode plein écran lors de la lecture d\'une vidéo.';

  @override
  String episode_progress(Object n) {
    return 'Progression: $n';
  }

  @override
  String n_episodes(Object n) {
    return '$n épisodes';
  }

  @override
  String get manga_sources => 'Sources des mangas';

  @override
  String get anime_sources => 'Sources d\'animés';

  @override
  String get novel_sources => 'Sources de romans';

  @override
  String get anime_extensions => 'Extensions Watch';

  @override
  String get manga_extensions => 'Extensions des mangas';

  @override
  String get novel_extensions => 'Extensions de romans';

  @override
  String get extension_settings => 'Paramètres de l\'extension';

  @override
  String get anime => 'Watch';

  @override
  String get manga => 'Manga';

  @override
  String get novel => 'Roman';

  @override
  String get library_no_category_exist =>
      'Vous n\'avez pas encore de catégories';

  @override
  String get watching => 'En lecture';

  @override
  String get plan_to_watch => 'À regarder';

  @override
  String get re_watching => 'Revisionnage';

  @override
  String get episodes => 'Épisodes';

  @override
  String get download => 'Télécharger';

  @override
  String get new_update_available => 'Une nouvelle version est disponible';

  @override
  String app_version(Object v) {
    return 'Version de l\'application : v$v';
  }

  @override
  String get searching_for_updates => 'Vérification des mise à jours';

  @override
  String get no_new_updates_available => 'Aucune mise à jours disponible';

  @override
  String get uninstall => 'Désinstaller';

  @override
  String uninstall_extension(Object ext) {
    return 'Désinstaller l\'extension $ext?';
  }

  @override
  String get langauage => 'Langue';

  @override
  String get extension_detail => 'Informations de l\'extension';

  @override
  String get scale_type => 'Type de mise à l\'échelle';

  @override
  String get scale_type_fit_screen => 'Adapter à l\'écran';

  @override
  String get scale_type_stretch => 'Étirer';

  @override
  String get scale_type_fit_width => 'Adapter à la largeur';

  @override
  String get scale_type_fit_height => 'Adapter à la hauteur';

  @override
  String get scale_type_original_size => 'Taille originale';

  @override
  String get scale_type_smart_fit => 'Adaptation intelligente';

  @override
  String get page_preload_amount => 'Nombre de page à précharger';

  @override
  String get page_preload_amount_subtitle =>
      'Le nombre de pages à précharger pendant la lecture. De plus grandes valeurs rendront la lecture plus fluide au coût d\'un plus grand cache et d\'une plus grande utilisation de données.';

  @override
  String get image_loading_error => 'L\'image n\'a pas pu être chargée';

  @override
  String get add_episodes => 'Ajouter Épisodes';

  @override
  String get video_quality => 'Qualité';

  @override
  String get video_subtitle => 'Sous-titre';

  @override
  String get check_for_extension_updates =>
      'Vérifier les mise à jour d\'extensions';

  @override
  String get auto_extensions_updates => 'Mises à jour auto des extensions';

  @override
  String get auto_extensions_updates_subtitle =>
      'Mettra automatiquement à jour l\'extension lorsqu\'une nouvelle version est disponible.';

  @override
  String get check_for_app_updates =>
      'Vérifier les mises à jour de l\'application au démarrage';

  @override
  String get reading_mode => 'Mode de lecture';

  @override
  String get custom_filter => 'Filtre personnalisé';

  @override
  String get background_color => 'Couleur de fond';

  @override
  String get white => 'Blanc';

  @override
  String get black => 'Noir';

  @override
  String get grey => 'Gris';

  @override
  String get automaic => 'Automatique';

  @override
  String get preferred_domain => 'Domaine préféré';

  @override
  String get load_more => 'Charger plus';

  @override
  String get cancel_all_for_this_series => 'Tout annuler pour cette serie';

  @override
  String get login => 'Connexion';

  @override
  String login_into(Object tracker) {
    return 'Connexion à $tracker';
  }

  @override
  String get email_adress => 'Adresse couriel';

  @override
  String get password => 'Mot de passe';

  @override
  String log_out_from(Object tracker) {
    return 'Se déconnecter de $tracker ?';
  }

  @override
  String get log_out => 'Se déconnecter';

  @override
  String get update_pending => 'Mises à jour en attente';

  @override
  String get update_all => 'Tout mettre à jour';

  @override
  String get backup_and_restore => 'Sauvegarder et restaurer';

  @override
  String get create_backup => 'Créer une sauvegarde';

  @override
  String get create_backup_dialog_title => 'Que voulez-vous sauvegarder ?';

  @override
  String get create_backup_subtitle =>
      'Peut être utilisé pour restaurer la bibliothèque actuelle';

  @override
  String get restore_backup => 'Restaurer une sauvegarde';

  @override
  String get restore_backup_subtitle =>
      'Restaurer la bibliothèque à partir d\'un fichier de sauvegarde';

  @override
  String get automatic_backups => 'Sauvegardes automatiques';

  @override
  String get backup_frequency => 'Fréquence de sauvegarde';

  @override
  String get backup_location => 'Dossier de sauvegarde';

  @override
  String get backup_options => 'Options de sauvegarde';

  @override
  String get backup_options_dialog_title => 'Que voulez-vous sauvegarder ?';

  @override
  String get backup_options_subtitle =>
      'Quelle information inclure dans le fichier de sauvegarde';

  @override
  String get backup_and_restore_warning_info =>
      'Vous devez égalemement conserver des copies des sauvegardes à d\'atures endroits';

  @override
  String get library_entries => 'Entrées de la bibliothèque';

  @override
  String get chapters_and_episode => 'Chapitres et épisodes';

  @override
  String get every_6_hours => 'Toutes les 6 heures';

  @override
  String get every_12_hours => 'Toutes les 12 heures';

  @override
  String get daily => 'Tous les jours';

  @override
  String get every_2_days => 'Tous les 2 jours';

  @override
  String get weekly => 'Chaque semaine';

  @override
  String get restore_backup_warning_title =>
      'La restauration d\'une sauvegarde écrasera toutes les données existantes.\n\nContinuer la restauration ?';

  @override
  String get services => 'Services';

  @override
  String get tracking_warning_info =>
      'Synchronisation à sens unique pour mettre à jour la progression du chapitre dans les services de suivi. Configurez le suivi des entrées individuelles à partir de leur boutton de suivi.';

  @override
  String get use_page_tap_zones => 'Utiliser les zones tactiles';

  @override
  String get manage_trackers => 'Gérer les suivis';

  @override
  String get restore => 'Restaurer';

  @override
  String get backups => 'Sauvegardes';

  @override
  String get by_scanlator => 'Par traducteur';

  @override
  String get by_name => 'Par nom';

  @override
  String get installed => 'Installé';

  @override
  String get auto_scroll => 'Défilement automatique';

  @override
  String get video_audio => 'Audio';

  @override
  String get video_audio_info =>
      'Langues préférées, correction de la hauteur tonale, canaux audio';

  @override
  String get player => 'Lecteur';

  @override
  String get player_video => 'Lecteur vidéo';

  @override
  String get markEpisodeAsSeenSetting =>
      'À quel moment marquer l\'épisode comme vu';

  @override
  String get default_skip_intro_length =>
      'Longueur par défaut du passage de l\'intro';

  @override
  String get default_playback_speed_length =>
      'Longueur par défaut de la vitesse de lecture';

  @override
  String get updateProgressAfterReading =>
      'Synchroniser la progression après lecture';

  @override
  String get no_sources_installed => 'Aucune source installée !';

  @override
  String get show_extensions => 'Afficher les extensions';

  @override
  String get default_skip_forward_skip_length => 'Longueur de saut par défaut';

  @override
  String get aniskip_requires_info =>
      'AniSkip nécessite que l\'anime soit suivi sur MAL ou Anilist pour fonctionner.';

  @override
  String get enable_aniskip => 'Activer AniSkip';

  @override
  String get enable_auto_skip => 'Activer le saut automatique';

  @override
  String get aniskip_button_timeout => 'Délai du bouton';

  @override
  String get skip_opening => 'Passer l\'opening';

  @override
  String get skip_ending => 'Passer l\'ending';

  @override
  String get fullscreen => 'Plein écran';

  @override
  String get update_library => 'Mettre à jour la bibliothèque';

  @override
  String updating_library(Object cur, Object failed, Object max) {
    return 'Mise à jour de la bibliothèque ($cur / $max) - Échec: $failed';
  }

  @override
  String get next_chapter => 'Chapitre suivant';

  @override
  String get next_5_chapters => '5 chapitres suivants';

  @override
  String get next_10_chapters => '10 chapitres suivants';

  @override
  String get next_25_chapters => '25 chapitres suivants';

  @override
  String get all_chapters => 'Tous les chapitres';

  @override
  String get next_episode => 'Épisode suivant';

  @override
  String get next_5_episodes => '5 épisodes suivants';

  @override
  String get next_10_episodes => '10 épisodes suivants';

  @override
  String get next_25_episodes => '25 épisodes suivants';

  @override
  String get all_episodes => 'Tous les épisodes';

  @override
  String get cover_saved => 'Couverture enregistrée';

  @override
  String get set_as_cover => 'Définir comme couverture';

  @override
  String get use_this_as_cover_art =>
      'Utiliser ceci comme illustration de couverture ?';

  @override
  String get save => 'Enregistrer';

  @override
  String get picture_saved => 'Image enregistrée';

  @override
  String get cover_updated => 'Couverture mise à jour';

  @override
  String get include_subtitles => 'Inclure les sous-titres';

  @override
  String get blend_mode_default => 'Par défaut';

  @override
  String get blend_mode_multiply => 'Multiplier';

  @override
  String get blend_mode_screen => 'Écran';

  @override
  String get blend_mode_overlay => 'Incrustation';

  @override
  String get blend_mode_colorDodge => 'Densité Couleur';

  @override
  String get blend_mode_lighten => 'Éclaircir';

  @override
  String get blend_mode_colorBurn => 'Incandescence';

  @override
  String get blend_mode_darken => 'Assombrir';

  @override
  String get blend_mode_difference => 'Différence';

  @override
  String get blend_mode_saturation => 'Saturation';

  @override
  String get blend_mode_softLight => 'Lumière Douce';

  @override
  String get blend_mode_plus => 'Ajout';

  @override
  String get blend_mode_exclusion => 'Exclusion';

  @override
  String get custom_color_filter => 'Filtre de couleur personnalisé';

  @override
  String get color_filter_blend_mode => 'Mode de fusion du filtre de couleur';

  @override
  String get enable_all => 'Activer tout';

  @override
  String get disable_all => 'Désactiver tout';

  @override
  String get font => 'Police';

  @override
  String get color => 'Couleur';

  @override
  String get font_size => 'Taille de police';

  @override
  String get text => 'Texte';

  @override
  String get border => 'Bordure';

  @override
  String get background => 'Arrière-plan';

  @override
  String get no_subtite_warning_message =>
      'N\'a aucun effet car il n\'y a pas de pistes de sous-titres dans cette vidéo';

  @override
  String get grid_size => 'Taille de la grille';

  @override
  String n_per_row(Object n) {
    return '$n par ligne';
  }

  @override
  String get horizontal_continious => 'Horizontal continu';

  @override
  String get edit_code => 'Modifier le code';

  @override
  String get use_libass => 'Activer libass';

  @override
  String get use_libass_info =>
      'Utilisez le rendu des sous-titres basé sur libass pour le backend natif.';

  @override
  String get libass_not_disable_message =>
      'Désactivez `use libass` dans les paramètres du lecteur pour pouvoir personnaliser les sous-titres.';

  @override
  String get torrent_stream => 'Flux Torrent';

  @override
  String get add_torrent => 'Ajouter un torrent';

  @override
  String get enter_torrent_hint_text =>
      'Entrez l\'URL du fichier magnet ou torrent';

  @override
  String get torrent_url => 'URL du torrent';

  @override
  String get or => 'OU';

  @override
  String get advanced => 'Avancé';

  @override
  String get advanced_info => 'Configuration mpv';

  @override
  String get use_native_http_client => 'Utiliser le client HTTP natif';

  @override
  String get use_native_http_client_info =>
      'Il supporte automatiquement les fonctionnalités de la plateforme telles que les VPN, et prend en charge plus de fonctionnalités HTTP telles que HTTP/3 et la gestion personnalisée des redirections.';

  @override
  String n_hour_ago(Object hour) {
    return 'Il y a $hour heure';
  }

  @override
  String n_hours_ago(Object hours) {
    return 'Il y a $hours heures';
  }

  @override
  String n_minute_ago(Object minute) {
    return 'Il y a $minute minute';
  }

  @override
  String n_minutes_ago(Object minutes) {
    return 'Il y a $minutes minutes';
  }

  @override
  String n_day_ago(Object day) {
    return 'Il y a $day jour';
  }

  @override
  String get now => 'maintenant';

  @override
  String library_last_updated(Object lastUpdated) {
    return 'Dernière mise à jour de la bibliothèque : $lastUpdated';
  }

  @override
  String get data_and_storage => 'Données et stockage';

  @override
  String get download_location_info =>
      'Utilisé pour les téléchargements de chapitres';

  @override
  String get storage => 'Stockage';

  @override
  String get clear_chapter_and_episode_cache =>
      'Effacer le cache des chapitres et épisodes';

  @override
  String get cache_cleared => 'Cache effacé';

  @override
  String get clear_chapter_or_episode_cache_on_app_launch =>
      'Effacer le cache des chapitres/épisodes au lancement de l\'application';

  @override
  String get app_settings => 'Paramètres de l\'application';

  @override
  String get sources_settings => 'Paramètres des sources';

  @override
  String get include_sensitive_settings =>
      'Inclure les paramètres sensibles (par ex., jetons de connexion des traceurs)';

  @override
  String get create => 'Créer';

  @override
  String get downloads_are_limited_to_wifi =>
      'Les téléchargements sont limités au Wi-Fi uniquement';

  @override
  String get recommendations => 'Recommandations';

  @override
  String get recommendations_similar => 'similaire';

  @override
  String get recommendations_weights => 'Poids des recommandations';

  @override
  String get recommendations_weights_genre => 'Similarité de genre';

  @override
  String get recommendations_weights_setting => 'Similarité de cadre';

  @override
  String get recommendations_weights_synopsis => 'Similarité d\'histoire';

  @override
  String get recommendations_weights_theme => 'Similarité de thème';

  @override
  String get manga_extensions_repo => 'Dépôt d\'extensions de mangas';

  @override
  String get anime_extensions_repo => 'Dépôt d\'extensions Watch';

  @override
  String get novel_extensions_repo => 'Dépôt d\'extensions de romans';

  @override
  String get custom_dns =>
      'DNS personnalisé (laisser vide pour utiliser le DNS système)';

  @override
  String get android_proxy_server => 'Serveur proxy Android (ApkBridge)';

  @override
  String get get_apk_bridge => 'Obtenir ApkBridge';

  @override
  String get get_sync_server => 'Obtenir le serveur de synchronisation ici';

  @override
  String get undefined => 'Indéfini';

  @override
  String get empty_extensions_repo =>
      'Vous n\'avez aucune URL de dépôt ici. Cliquez sur le bouton plus pour en ajouter une !';

  @override
  String get add_extensions_repo => 'Ajouter une URL de dépôt';

  @override
  String get remove_extensions_repo => 'Supprimer l\'URL du dépôt';

  @override
  String get manage_manga_repo_urls => 'Gérer les URL du dépôt de mangas';

  @override
  String get manage_anime_repo_urls => 'Gérer les URL du dépôt Watch';

  @override
  String get manage_novel_repo_urls => 'Gérer les URL du dépôt de romans';

  @override
  String get url_cannot_be_empty => 'L\'URL ne peut pas être vide';

  @override
  String get url_must_end_with_dot_json => 'L\'URL doit se terminer par .json';

  @override
  String get repo_url => 'URL du dépôt';

  @override
  String get invalid_url_format => 'Format d\'URL invalide';

  @override
  String get clear_all_sources => 'Effacer toutes les sources';

  @override
  String get clear_all_sources_msg =>
      'Cela effacera complètement toutes les sources de l\'application. Êtes-vous sûr de vouloir continuer ?';

  @override
  String get sources_cleared => 'Sources effacées !';

  @override
  String get repo_added => 'Dépôt de sources ajouté !';

  @override
  String get add_repo => 'Ajouter un dépôt ?';

  @override
  String get genre_search_library => 'Rechercher un genre dans la bibliothèque';

  @override
  String get genre_search_source => 'Explorer dans la source';

  @override
  String get source_not_added => 'La source n\'est pas installée !';

  @override
  String get load_own_subtitles => 'Charger vos propres sous-titres...';

  @override
  String get search_subtitles => 'Rechercher des sous-titres en ligne...';

  @override
  String extension_notes(Object notes) {
    return 'Notes : $notes';
  }

  @override
  String get unsupported_repo =>
      'Vous avez essayé d\'ajouter un dépôt qui n\'est pas pris en charge. Veuillez consulter le serveur discord pour obtenir de l\'aide!';

  @override
  String get end_of_chapter => 'Fin du chapitre';

  @override
  String get chapter_completed => 'Chapitre terminé';

  @override
  String get continue_to_next_chapter =>
      'Continuez à faire défiler pour lire le chapitre suivant';

  @override
  String get no_next_chapter => 'Pas de prochain chapitre';

  @override
  String get you_have_finished_reading => 'Vous avez terminé la lecture';

  @override
  String get return_to_the_list_of_chapters =>
      'Retournez à la liste des chapitres';

  @override
  String get hwdec => 'Décodeur matériel';

  @override
  String get enable_hardware_accel => 'Accélération matérielle';

  @override
  String get enable_hardware_accel_info =>
      'Activez/désactivez si vous rencontrez des bugs ou des plantages';

  @override
  String get track_library_navigate => 'Accéder à l\'entrée locale existante';

  @override
  String get track_library_add => 'Ajouter à la bibliothèque locale';

  @override
  String get track_library_add_confirm =>
      'Ajouter l\'élément suivi à la bibliothèque locale';

  @override
  String get track_library_not_logged =>
      'Connectez-vous au tracker correspondant pour utiliser cette fonctionnalité !';

  @override
  String get track_library_switch => 'Changer pour un autre tracker';

  @override
  String get go_back => 'Retour';

  @override
  String get merge_library_nav_mobile =>
      'Fusionner la navigation de la bibliothèque sur mobile';

  @override
  String get enable_discord_rpc => 'Activer Discord RPC';

  @override
  String get hide_discord_rpc_incognito =>
      'Masquer Discord RPC en mode Incognito';

  @override
  String get rpc_show_reading_watching_progress =>
      'Afficher le chapitre actuel dans Discord (nécessite un redémarrage)';

  @override
  String get rpc_show_title => 'Afficher le titre actuel dans Discord';

  @override
  String get rpc_show_cover_image =>
      'Afficher l\'image de couverture actuelle dans Discord';

  @override
  String get sync_enable_histories => 'Synchroniser les données d\'historique';

  @override
  String get sync_enable_updates => 'Synchroniser les données de mise à jour';

  @override
  String get sync_enable_settings => 'Synchroniser les paramètres';

  @override
  String get enable_mpv => 'Activer les shaders / scripts mpv';

  @override
  String get mpv_info => 'Supporte les scripts .js sous mpv/scripts/';

  @override
  String get mpv_redownload =>
      'Retélécharger les fichiers de configuration mpv';

  @override
  String get mpv_redownload_info =>
      'Remplace les anciens fichiers de configuration par les nouveaux !';

  @override
  String get mpv_download =>
      'Les fichiers de configuration MPV sont requis !\nTélécharger maintenant ?';

  @override
  String get custom_buttons => 'Boutons personnalisés';

  @override
  String get custom_buttons_info =>
      'Exécuter du code lua avec des boutons personnalisés';

  @override
  String get custom_buttons_edit => 'Modifier les boutons personnalisés';

  @override
  String get custom_buttons_add => 'Ajouter un bouton personnalisé';

  @override
  String get custom_buttons_added => 'Bouton personnalisé ajouté !';

  @override
  String get custom_buttons_delete => 'Supprimer le bouton personnalisé';

  @override
  String get custom_buttons_text => 'Texte du bouton';

  @override
  String get custom_buttons_text_req => 'Texte du bouton requis';

  @override
  String get custom_buttons_js_code => 'Code lua';

  @override
  String get custom_buttons_js_code_req => 'Code lua requis';

  @override
  String get custom_buttons_js_code_long => 'Code lua (sur appui long)';

  @override
  String get custom_buttons_startup => 'Code lua (au démarrage)';

  @override
  String n_days(Object n) {
    return '$n jours';
  }

  @override
  String get decoder => 'Décodeur';

  @override
  String get decoder_info => 'Décodage matériel, format de pixel, debanding';

  @override
  String get enable_gpu_next => 'Activer gpu-next (Android uniquement)';

  @override
  String get enable_gpu_next_info => 'Un nouveau moteur de rendu vidéo';

  @override
  String get debanding => 'Debanding';

  @override
  String get use_yuv420p => 'Utiliser le format de pixel YUV420P';

  @override
  String get use_yuv420p_info =>
      'Peut corriger les écrans noirs sur certains codecs vidéo, peut également améliorer les performances au détriment de la qualité';

  @override
  String get audio_preferred_languages => 'Langues préférées';

  @override
  String get audio_preferred_languages_info =>
      'Langue(s) audio à sélectionner par défaut sur une vidéo avec plusieurs flux audio, codes de langue à 2/3 lettres (par exemple : fr, en, de). Plusieurs valeurs peuvent être délimitées par une virgule.';

  @override
  String get enable_audio_pitch_correction =>
      'Activer la correction de hauteur tonale audio';

  @override
  String get enable_audio_pitch_correction_info =>
      'Empêche l\'audio de devenir aigu à des vitesses plus rapides et grave à des vitesses plus lentes';

  @override
  String get audio_channels => 'Canaux audio';

  @override
  String get volume_boost_cap => 'Limite d\'amplification du volume';

  @override
  String get internal_player => 'Lecteur interne';

  @override
  String get internal_player_info => 'Progression, contrôles, orientation';

  @override
  String get subtitle_delay_text => 'Délai des sous-titres';

  @override
  String get subtitle_delay => 'Délai (ms)';

  @override
  String get subtitle_speed => 'Vitesse';

  @override
  String get calendar => 'Calendrier';

  @override
  String get schedule => 'Planning';

  @override
  String get calendar_no_data => 'Aucune donnée pour l\'instant.';

  @override
  String get calendar_info =>
      'Le calendrier ne peut prédire le prochain téléversement de chapitre que sur la base des téléversements précédents. Certaines données peuvent ne pas être précises à 100% !';

  @override
  String in_n_day(Object days) {
    return 'dans $days jour';
  }

  @override
  String in_n_days(Object days) {
    return 'dans $days jours';
  }

  @override
  String get clear_library => 'Vider la bibliothèque';

  @override
  String get clear_library_desc =>
      'Choisissez d\'effacer toutes les entrées manga, anime et/ou roman';

  @override
  String get clear_library_input =>
      'Tapez \'manga\', \'anime\' et/ou \'novel\' (séparés par une virgule) pour supprimer toutes les entrées associées';

  @override
  String get watch_order => 'Ordre de visionnage';

  @override
  String get sequels => 'Suites';

  @override
  String get recommendations_similarity => 'Similarité :';

  @override
  String get local_folder_structure => 'Structure d\'un dossier local';

  @override
  String get local_folder => 'Dossiers locaux';

  @override
  String get add_local_folder => 'Ajouter un dossier local';

  @override
  String get rescan_local_folder =>
      'Réanalyser tous les dossiers locaux maintenant';

  @override
  String get export_metadata => 'Exporter les métadonnées';

  @override
  String get exported => 'Exporté';

  @override
  String get text_size => 'Taille du texte :';

  @override
  String get text_align => 'Alignement du texte';

  @override
  String get line_height => 'Hauteur de ligne';

  @override
  String get show_scroll_percentage => 'Afficher le pourcentage de défilement';

  @override
  String get remove_extra_paragraph_spacing =>
      'Supprimer l\'espacement supplémentaire des paragraphes';

  @override
  String select_label_color(Object label) {
    return 'Sélectionner la couleur $label';
  }

  @override
  String get default_user_agent => 'Agent utilisateur par défaut';

  @override
  String get forceLandscapeMode => 'Forcer le mode paysage';

  @override
  String get forceLandscapeModeSubtitle =>
      'Forcer le lecteur à utiliser l\'orientation paysage.';

  @override
  String get dns_over_https => 'DNS-sur-HTTPS (DoH)';

  @override
  String get dns_provider => 'Fournisseur DNS';

  @override
  String get tracked => 'Suivi';

  @override
  String get auth_unlock_msg =>
      'Authentifiez-vous pour déverrouiller Watchtower';

  @override
  String get app_locked => 'Watchtower est verrouillé';

  @override
  String get auth_to_continue => 'Authentifiez-vous pour continuer';

  @override
  String get authenticating => 'Authentification en cours...';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get security => 'Sécurité';

  @override
  String get auth_to_change_security_setting =>
      'Authentifiez-vous pour modifier les paramètres de sécurité';

  @override
  String get app_lock => 'Verrouillage de l\'application';

  @override
  String get require_biometric_or_device_credential =>
      'Exiger l\'authentification biométrique ou les identifiants de l\'appareil pour ouvrir l\'application';

  @override
  String get biometric_or_device_credential_not_available =>
      'L\'authentification biométrique n\'est pas disponible sur cet appareil';

  @override
  String get app_lock_description =>
      'Lorsque le verrouillage de l\'application est activé, vous serez invité à vous authentifier\nchaque fois que vous ouvrez l\'application ou que vous la restaurez à partir de l\'arrière-plan.';

  @override
  String get keep_screen_on => 'Garder l\'écran allumé';

  @override
  String get webtoon_side_padding => 'Remplissage latéral Webtoon';

  @override
  String get show_page_gaps => 'Afficher les écarts entre les pages';

  @override
  String get invert_colors => 'Inverser les couleurs';

  @override
  String get grayscale => 'Niveaux de gris';

  @override
  String get brightness => 'Luminosité';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturation';

  @override
  String get navigation_layout => 'Disposition de navigation';

  @override
  String get nav_layout_default => 'Défaut';

  @override
  String get nav_layout_l_shaped => 'En forme de L';

  @override
  String get nav_layout_kindle => 'Kindle';

  @override
  String get nav_layout_edge => 'Bord';

  @override
  String get nav_layout_right_and_left => 'Droite et gauche';

  @override
  String get nav_layout_disabled => 'Désactivé';

  @override
  String get color_enhancements => 'Améliorations des couleurs';

  @override
  String get total => 'Total';

  @override
  String get mean_per_title => 'Moyenne par titre';

  @override
  String get completion_rate => 'Taux de réussite';

  @override
  String get watching_time => 'Temps de visionnage';

  @override
  String get reading_time => 'Temps de lecture';

  @override
  String average_chapters_per_title(Object title) {
    return 'Chapitres moyens par titre';
  }

  @override
  String get read_percentage => 'Pourcentage lu';

  @override
  String get entries => 'Entrées';

  @override
  String get android_proxy_server_mihon => 'Serveur proxy Android (Mihon)';

  @override
  String get android_proxy_server_mihon_description =>
      'Téléchargez et configurez le serveur proxy requis pour utiliser les extensions Mihon.';

  @override
  String get mihon_proxy_server => 'Serveur proxy Mihon';

  @override
  String get extension_server_intro_with_jre =>
      'Download the proxy server bundle before using Mihon extensions. The bundle includes the JRE and extension server JAR.';

  @override
  String get extension_server_intro_ios =>
      'Download the proxy server JAR before using Mihon extensions. iOS only needs the extension server JAR.';

  @override
  String get checking_files => 'Checking files';

  @override
  String get files_installed => 'Files installed';

  @override
  String get files_missing => 'Files missing';

  @override
  String get update_files => 'Update files';

  @override
  String get up_to_date => 'Up to date';

  @override
  String get choose_location => 'Choose location';

  @override
  String get import_existing_jar => 'Import existing JAR';

  @override
  String get detect_files_in_selected_folder =>
      'Detect files in selected folder';

  @override
  String get preparing_download => 'Preparing download...';

  @override
  String get app_install_location => 'App install location';

  @override
  String get install_location => 'Install location';

  @override
  String get jre_executable => 'JRE executable';

  @override
  String get extension_server_jar => 'Extension server JAR';

  @override
  String get installed_version => 'Installed version';

  @override
  String get latest_version => 'Latest version';

  @override
  String get apkbridge_description =>
      'Use ApkBridge when you need a separate Android device proxy. Set the proxy address here and download the APK from GitHub.';

  @override
  String get set_proxy_address => 'Set proxy address';

  @override
  String get no_newer_proxy_server_release_available =>
      'Aucune nouvelle version du serveur proxy disponible.';

  @override
  String get could_not_check_proxy_server_updates =>
      'Impossible de vérifier les mises à jour du serveur proxy.';

  @override
  String get no_extension_server_bundle_available_for_this_platform =>
      'No extension server bundle is available for this platform.';

  @override
  String failed_to_download_bundle(Object statusCode) {
    return 'Failed to download bundle ($statusCode).';
  }

  @override
  String get downloaded_bundle_missing_expected_files =>
      'The downloaded bundle does not contain the expected files.';

  @override
  String get extension_server_files_ready =>
      'Extension server files are ready.';

  @override
  String get ios_extension_server_import_hint =>
      'On iOS the server is installed inside the app sandbox. Use \"Import existing JAR\" to bring in a downloaded file.';

  @override
  String get select_extension_server_folder => 'Select extension server folder';

  @override
  String get selected_folder_does_not_exist =>
      'The selected folder does not exist.';

  @override
  String get no_extension_server_files_found_in_selected_folder =>
      'No extension server files were found in the selected folder.';

  @override
  String get extension_server_files_linked =>
      'Extension server files were linked.';

  @override
  String get select_extension_server_jar =>
      'Sélectionner le JAR du serveur d\'extension';

  @override
  String get selected_file_could_not_be_accessed =>
      'The selected file could not be accessed.';

  @override
  String get extension_server_jar_imported =>
      'Extension server JAR was imported.';

  @override
  String get could_not_launch_apk_bridge_page =>
      'Could not launch the ApkBridge page.';

  @override
  String get proxy_server_ip_hint =>
      'IP du serveur (ex: 10.0.0.5 ou https://example.com)';

  @override
  String get not_configured => 'Not configured';

  @override
  String get webview => 'Webview';

  @override
  String get tts => 'Synthèse vocale';

  @override
  String get tts_speed => 'Vitesse';

  @override
  String get tts_pitch => 'Tonalité';

  @override
  String get tts_language => 'Langue';

  @override
  String get tts_voice => 'Voix';

  @override
  String get tts_stop => 'Arrêter';

  @override
  String get tts_play => 'Lire';

  @override
  String get tts_pause => 'Pause';

  @override
  String get tts_previous => 'Paragraphe précédent';

  @override
  String get tts_next => 'Paragraphe suivant';

  @override
  String tts_paragraph_progress(Object current, Object total) {
    return 'Paragraphe $current sur $total';
  }

  @override
  String get tts_settings => 'Paramètres TTS';

  @override
  String get tts_default => 'Par défaut';

  @override
  String get view_all => 'Voir tout';

  @override
  String get for_you => 'Pour toi';

  @override
  String get following_tab => 'Suivis';

  @override
  String get explore_tab => 'Explorer';

  @override
  String get browser_dock_tabs => 'Onglets';

  @override
  String get browser_dock_new_tab => 'Nouvel onglet';

  @override
  String get browser_dock_more => 'Plus d\'options';

  @override
  String get browser_dock_collapse => 'Replier la barre';

  @override
  String get browser_dock_expand => 'Afficher la barre';

  @override
  String get catalog_tag_watch => 'À regarder';

  @override
  String get catalog_tag_read => 'À lire';

  @override
  String get catalog_tag_manga => 'Manga';

  @override
  String get catalog_tag_manhwa => 'Manhwa';

  @override
  String get catalog_tag_manhua => 'Manhua';

  @override
  String get catalog_tag_webtoon => 'Webtoon';

  @override
  String get catalog_tag_comics => 'BD et comics';

  @override
  String get catalog_tag_novel => 'Roman';

  @override
  String get catalog_tag_anime => 'Anime';

  @override
  String get catalog_tag_animation => 'Animation';

  @override
  String get catalog_tag_movies => 'Movies';

  @override
  String get catalog_tag_series => 'Series';

  @override
  String get catalog_tag_documentary => 'Documentaires';

  @override
  String get catalog_tag_jav => 'JAV';

  @override
  String get catalog_tag_music => 'Musique';

  @override
  String get catalog_tag_game => 'Jeux';

  @override
  String get catalog_tag_action => 'Action';

  @override
  String get catalog_tag_adventure => 'Aventure';

  @override
  String get catalog_tag_fantasy => 'Fantasy';

  @override
  String get catalog_tag_science_fiction => 'Science-fiction';

  @override
  String get catalog_tag_romance => 'Romance';

  @override
  String get catalog_tag_mystery => 'Mystère';

  @override
  String get catalog_tag_drama => 'Drame';

  @override
  String get catalog_tag_comedy => 'Comédie';

  @override
  String get catalog_tag_horror => 'Horreur';

  @override
  String get catalog_tag_thriller => 'Thriller';

  @override
  String get catalog_tag_historical => 'Historique';

  @override
  String get catalog_tag_slice_of_life => 'Tranche de vie';

  @override
  String get catalog_tag_mecha => 'Mecha';

  @override
  String get catalog_tag_sports => 'Sport';

  @override
  String get catalog_tag_multilingual => 'Multilingue';

  @override
  String get catalog_tag_french => 'Français';

  @override
  String get catalog_tag_english => 'Anglais';

  @override
  String get catalog_tag_spanish => 'Espagnol';

  @override
  String get catalog_tag_german => 'Allemand';

  @override
  String get catalog_tag_italian => 'Italien';

  @override
  String get catalog_tag_portuguese => 'Portugais';

  @override
  String get catalog_tag_japanese => 'Japonais';

  @override
  String get catalog_tag_korean => 'Coréen';

  @override
  String get catalog_tag_chinese => 'Chinois';

  @override
  String get catalog_tag_arabic => 'Arabe';

  @override
  String get catalog_tag_russian => 'Russe';

  @override
  String get catalog_tag_turkish => 'Turc';

  @override
  String get catalog_tag_thai => 'Thaï';

  @override
  String get catalog_tag_indonesian => 'Indonésien';

  @override
  String get catalog_tag_hindi => 'Hindi';

  @override
  String get catalog_tag_vietnamese => 'Vietnamien';

  @override
  String get catalog_tag_polish => 'Polonais';

  @override
  String get catalog_tag_dutch => 'Néerlandais';

  @override
  String get catalog_tag_featured => 'Mis en avant';

  @override
  String get catalog_tag_new => 'Nouveau';

  @override
  String get catalog_tag_popular => 'Populaire';

  @override
  String get catalog_tag_trending => 'Tendance';

  @override
  String get catalog_shelf_watch_popular => 'Populaire à regarder';

  @override
  String get catalog_shelf_read_popular => 'Populaire à lire';

  @override
  String get catalog_shelf_new_watch => 'Nouvelles sources vidéo';

  @override
  String get catalog_shelf_new_read => 'Nouvelles sources de lecture';

  @override
  String get catalog_shelf_new => 'Récemment ajoutées';

  @override
  String get catalog_shelf_recommended => 'Recommandé pour toi';

  @override
  String get catalog_shelf_featured => 'Mises en avant';

  @override
  String get catalog_shelf_movies => 'Films';

  @override
  String get catalog_shelf_series => 'Séries';

  @override
  String get catalog_shelf_anime => 'Anime';

  @override
  String get catalog_shelf_animation => 'Animation';

  @override
  String get catalog_shelf_documentaries => 'Documentaires';

  @override
  String get catalog_shelf_science_fiction => 'Science-fiction';

  @override
  String get catalog_shelf_fantasy => 'Fantasy';

  @override
  String get catalog_shelf_action_adventure => 'Action et aventure';

  @override
  String get catalog_shelf_romance_mystery => 'Romance et mystère';

  @override
  String get catalog_shelf_manga => 'Manga';

  @override
  String get catalog_shelf_manga_manhwa => 'Manga et manhwa';

  @override
  String get catalog_shelf_manhwa => 'Manhwa';

  @override
  String get catalog_shelf_manhua => 'Manhua';

  @override
  String get catalog_shelf_webtoons => 'Webtoons';

  @override
  String get catalog_shelf_comics => 'BD et comics';

  @override
  String get catalog_shelf_novels => 'Romans et light novels';

  @override
  String get catalog_shelf_french => 'Sources françaises';

  @override
  String get catalog_shelf_english => 'Sources anglaises';

  @override
  String get catalog_shelf_multilingual => 'Sources multilingues';

  @override
  String get catalog_shelf_scifi_fantasy => 'Science-fiction et fantasy';

  @override
  String get catalog_shelf_music => 'Musique';

  @override
  String get catalog_shelf_games => 'Jeux';

  @override
  String get catalog_shelf_order_curated =>
      'Mises en avant d\'abord, puis les plus récemment ajoutées';

  @override
  String get catalog_shelf_empty =>
      'Aucune extension ne correspond encore à cette sélection.';

  @override
  String get catalog_see_all => 'Voir tout';

  @override
  String get catalog_back => 'Retour';

  @override
  String get catalog_error => 'Impossible de charger le catalogue.';

  @override
  String marketplace_all_extensions(Object type) {
    return 'Toutes les extensions $type';
  }

  @override
  String catalog_shelf_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions',
      one: '$count extension',
    );
    return '$_temp0';
  }

  @override
  String get marketplace_explore_by_language => 'Explorer par langue';

  @override
  String get marketplace_whole_catalogue => 'Tout le catalogue';

  @override
  String get catalog_shelf_adult_watch => 'Midnight World';

  @override
  String get catalog_shelf_adult_read => 'Midnight Library';

  @override
  String get catalog_shelf_for_you_watch => 'Pour toi · à regarder';

  @override
  String get catalog_shelf_for_you_read => 'Pour toi · à lire';

  @override
  String get catalog_card_see_more => 'Voir plus';

  @override
  String get catalog_card_see_less => 'Voir moins';

  @override
  String get catalog_card_open_site => 'Ouvrir le site';

  @override
  String get catalog_card_open_site_unavailable =>
      'Aucun site pour cette extension';

  @override
  String get plugins_section_builtin => 'Plugins intégrés';

  @override
  String get plugins_section_engines => 'Composants et moteurs';

  @override
  String get plugins_section_empty => 'Aucun plugin disponible.';

  @override
  String get plugins_nfile_title => 'NFile — gestionnaire de fichiers';

  @override
  String get plugins_nfile_description =>
      'Explorateur de fichiers intégré avec lecteurs et outils de gestion.';

  @override
  String get plugins_smart_library_description =>
      'Analyse et organise les vidéos et mangas déjà présents sur l’appareil.';

  @override
  String get plugins_ffmpeg_bundled =>
      'Fourni avec l’application — aucune installation requise.';

  @override
  String get plugins_mpv_description =>
      'Télécharge uniquement mpv.conf, input.conf et les scripts.';

  @override
  String get plugins_action_open => 'Ouvrir';

  @override
  String get plugins_action_info => 'Info';

  @override
  String get plugins_action_install => 'Installer';

  @override
  String get plugins_action_close => 'Fermer';

  @override
  String get plugins_mpv_config_exception =>
      'Le dossier de configuration MPV est indisponible.';

  @override
  String get plugins_ffmpeg_title => 'FFmpeg';

  @override
  String get plugins_ffmpeg_info =>
      'FFmpeg est fourni avec Watchtower. Il réalise un unique muxage en copie de flux des fragments HLS téléchargés (MPEG-TS ou fMP4) vers le fichier MP4 final.\n\nAucun téléchargement, aucun runtime séparé : l’assemblage fonctionne hors ligne et ne dépend d’aucun exécutable externe.';

  @override
  String get plugins_smart_library_title => 'Smart Library';

  @override
  String get plugins_mpv_title => 'Configuration MPV';

  @override
  String get plugins_music_title => 'Plugins Musique';

  @override
  String get catalog_tab_for_you => 'Pour vous';

  @override
  String get catalog_tab_watch => 'Watch';

  @override
  String get catalog_tab_manga => 'Manga';

  @override
  String get catalog_tab_music => 'Musique';

  @override
  String get catalog_tab_games => 'Jeux';

  @override
  String get catalog_tab_novels => 'Romans';

  @override
  String get marketplace_search_results => 'Résultats de recherche';

  @override
  String get marketplace_empty_search_title => 'Aucune extension trouvée';

  @override
  String get marketplace_empty_catalog_title => 'Aucune extension disponible';

  @override
  String get marketplace_empty_search_hint =>
      'Essaie un autre nom ou actualise le catalogue.';

  @override
  String get marketplace_empty_catalog_hint =>
      'Le catalogue est vide pour le moment. Réessaie plus tard.';

  @override
  String get marketplace_empty_semantics => 'Catalogue vide';

  @override
  String get marketplace_settings_tooltip => 'Paramètres du Marketplace';

  @override
  String get marketplace_search_hint => 'Rechercher des extensions';

  @override
  String get marketplace_recent_searches => 'Recherches récentes';

  @override
  String get marketplace_popular_searches => 'Recherches populaires';

  @override
  String get marketplace_browse_by_category => 'Parcourir par catégorie';

  @override
  String get marketplace_nsfw_gate_title => 'Contenu adulte masqué';

  @override
  String get marketplace_nsfw_gate_body =>
      'Active le contenu adulte dans les préférences pour afficher ces extensions.';

  @override
  String get marketplace_nsfw_gate_show => 'Afficher le contenu adulte';

  @override
  String get marketplace_account_title => 'Compte Watchtower';

  @override
  String get marketplace_manage_installed => 'Gérer les extensions installées';

  @override
  String get marketplace_preferences => 'Préférences du Marketplace';

  @override
  String get marketplace_help_feedback => 'Aide et commentaires';

  @override
  String get marketplace_details_title => 'Détails';

  @override
  String marketplace_coming_soon(Object label) {
    return '$label sera disponible prochainement.';
  }

  @override
  String marketplace_source_blurb(Object language, Object kind) {
    return 'Source $language pour découvrir $kind dans Watchtower.';
  }

  @override
  String get marketplace_kind_anime => 'anime et séries';

  @override
  String get marketplace_kind_manga => 'mangas et bandes dessinées';

  @override
  String get marketplace_kind_novel => 'romans et light novels';

  @override
  String get marketplace_kind_music => 'musique et audio';

  @override
  String get marketplace_kind_default => 'contenus';

  @override
  String get marketplace_lang_french => 'français';

  @override
  String get marketplace_lang_english => 'anglais';

  @override
  String get marketplace_lang_multilingual => 'multilingue';

  @override
  String get marketplace_unknown_size => 'Taille inconnue';

  @override
  String marketplace_reviews_count(Object count) {
    return '$count avis';
  }

  @override
  String get marketplace_reviews_unavailable => 'Avis non disponibles';

  @override
  String get marketplace_update => 'Mettre à jour';

  @override
  String get marketplace_extension_installed => 'Extension installée';

  @override
  String get marketplace_about_extension => 'À propos de cette extension';

  @override
  String get marketplace_info_access => 'Accès';

  @override
  String get marketplace_info_community => 'Communauté';

  @override
  String get marketplace_info_repo => 'Dépôt et provenance';

  @override
  String get marketplace_official_repo_note =>
      'Mise à jour via le dépôt officiel Watchtower Extensions.';

  @override
  String get marketplace_ntfy_signals => 'Signaux ntfy';

  @override
  String marketplace_source_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '$count source',
    );
    return '$_temp0';
  }

  @override
  String marketplace_installed_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions installées',
      one: '$count extension installée',
    );
    return '$_temp0';
  }

  @override
  String get marketplace_info_information => 'Informations';

  @override
  String get marketplace_info_technology => 'Technologie';

  @override
  String get marketplace_info_reading => 'Lecture';

  @override
  String get marketplace_info_catalog => 'Catalogue';

  @override
  String get marketplace_info_content => 'Contenu';

  @override
  String get marketplace_access_required => 'Compte requis';

  @override
  String get marketplace_aggregator => 'Agrégateur';

  @override
  String get marketplace_comments => 'Commentaires';

  @override
  String marketplace_available_version(Object version) {
    return 'disponible v$version';
  }

  @override
  String get marketplace_catalog_unavailable => 'Le catalogue est indisponible';

  @override
  String get marketplace_check_connection =>
      'Vérifie ta connexion puis réessaie.';

  @override
  String marketplace_update_available(String version) {
    return 'Mise à jour disponible · v$version';
  }

  @override
  String marketplace_installed_version_label(String version) {
    return 'Installée v$version';
  }

  @override
  String get marketplace_info_size => 'Taille';

  @override
  String get marketplace_load_error => 'Impossible de charger le Marketplace';

  @override
  String get marketplace_search_extension_hint => 'Rechercher une extension…';

  @override
  String get marketplace_search_apps_hint =>
      'Rechercher des applis et des jeux…';

  @override
  String get marketplace_filter_extensions => 'Filtrer les extensions';

  @override
  String get marketplace_search_language_hint => 'Rechercher une langue…';

  @override
  String get marketplace_browse_extensions => 'Parcourir les extensions';

  @override
  String get marketplace_clear_all_filters => 'Effacer tout';

  @override
  String get marketplace_installed_only => 'Installées uniquement';

  @override
  String get marketplace_installed_only_sub =>
      'Masquer les extensions non installées';

  @override
  String get marketplace_updates_available => 'Mises à jour disponibles';

  @override
  String get marketplace_updates_available_sub =>
      'Extensions avec une nouvelle version';

  @override
  String get marketplace_all_option => '(toutes)';

  @override
  String get marketplace_nothing_to_install => 'Rien à installer';

  @override
  String get marketplace_check_updates_subtitle => 'Au démarrage de l’app';

  @override
  String get marketplace_auto_update_subtitle => 'Sans confirmation';

  @override
  String get marketplace_adult_content_title => 'Contenu 18+';

  @override
  String get marketplace_adult_content_subtitle =>
      'Afficher les extensions NSFW';

  @override
  String get marketplace_manage_repositories => 'Gérer les dépôts';

  @override
  String get marketplace_reload_catalogue => 'Recharger le catalogue';

  @override
  String get marketplace_bulk_install => 'Installer en masse';

  @override
  String get marketplace_ntfy_error_subtitle =>
      'Pousser une alerte en cas d’erreur';

  @override
  String get plugins_third_party_confirm_title => 'Installer ce plugin ?';

  @override
  String plugins_third_party_confirm_body(Object owner) {
    return 'Plugin tiers de $owner.\n\nIl accèdera aux APIs déclarées dans son manifest.\n\nAppui long sur la carte pour désinstaller.';
  }

  @override
  String get plugins_auth_required_body =>
      'Ce plugin nécessite une authentification.\nOuvrez le Hub Musique → Paramètres → Sources, sélectionnez ce plugin comme source par défaut, puis appuyez sur « Se connecter ».';

  @override
  String marketplace_error_load_failed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Échec du chargement de $count dépôts',
      one: 'Échec du chargement de $count dépôt',
    );
    return '$_temp0';
  }

  @override
  String marketplace_error_http(Object status, Object url) {
    return 'HTTP $status pour $url';
  }

  @override
  String marketplace_error_empty_response(Object url) {
    return 'Réponse vide pour $url';
  }

  @override
  String marketplace_error_plugin_not_registered(Object name) {
    return 'Le plugin $name n’a pas été enregistré après le téléchargement.';
  }

  @override
  String marketplace_error_generic(Object error) {
    return 'Erreur : $error';
  }

  @override
  String marketplace_error_uninstall(Object error) {
    return 'Erreur désinstallation : $error';
  }

  @override
  String marketplace_error_not_installed(Object name) {
    return 'L’extension $name n’a pas pu être installée. Aucune source active n’a été enregistrée.';
  }

  @override
  String marketplace_error_layout_not_saved(Object name) {
    return 'Le layout UI de $name n’a pas été enregistré.';
  }

  @override
  String marketplace_error_layout_unreadable(Object name) {
    return 'Le layout UI de $name est illisible.';
  }

  @override
  String marketplace_error_categories_not_saved(Object name) {
    return 'Les catégories de $name n’ont pas été enregistrées.';
  }

  @override
  String marketplace_error_content_types_not_saved(Object name) {
    return 'Les types de contenu de $name n’ont pas été enregistrés.';
  }

  @override
  String get marketplace_error_audio_plugin_missing =>
      'Plugin audio introuvable dans le stockage local.';

  @override
  String get marketplace_error_extension_missing =>
      'Extension introuvable dans le stockage local.';

  @override
  String marketplace_uninstall_title(Object name) {
    return 'Désinstaller $name';
  }

  @override
  String get marketplace_uninstall_body =>
      'L’extension sera désinstallée. Réinstallable à tout moment.';

  @override
  String marketplace_uninstalled_toast(Object name) {
    return '$name désinstallée';
  }

  @override
  String marketplace_bulk_install_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Installer $count extensions',
      one: 'Installer $count extension',
    );
    return '$_temp0';
  }

  @override
  String marketplace_bulk_install_confirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions à installer',
      one: '$count extension à installer',
    );
    return '$_temp0';
  }

  @override
  String get marketplace_settings_section_behavior => 'Comportement';

  @override
  String get marketplace_settings_section_repositories => 'Dépôts';

  @override
  String get marketplace_settings_section_cache => 'Cache';

  @override
  String get marketplace_settings_section_actions => 'Actions';

  @override
  String get marketplace_force_reload => 'Forcer rechargement (bypass cache)';

  @override
  String marketplace_installed_toast(Object name) {
    return '$name installée';
  }

  @override
  String get marketplace_repository => 'Dépôt';

  @override
  String get marketplace_default_metadata_provider =>
      'Provider par défaut (métadonnées)';

  @override
  String get marketplace_currently_default => 'Actuellement par défaut';

  @override
  String get marketplace_set_default_provider =>
      'Définir comme provider par défaut';

  @override
  String get marketplace_default_audio_source => 'Source audio par défaut';

  @override
  String get marketplace_set_default_audio_source =>
      'Définir comme source audio par défaut';

  @override
  String get marketplace_update_available_short => 'Màj dispo';

  @override
  String get marketplace_with_updates_short => 'Avec màj';

  @override
  String get marketplace_section_show => 'AFFICHER';

  @override
  String get marketplace_section_active_filters => 'FILTRES ACTIFS';

  @override
  String get marketplace_advanced_filters => 'Filtres avancés';

  @override
  String get marketplace_sort_installed => 'Installées';

  @override
  String marketplace_selected_count(Object count) {
    return '$count sélectionnées';
  }

  @override
  String marketplace_progress(Object done, Object total) {
    return '$done / $total traitées';
  }

  @override
  String marketplace_failed_count(Object count) {
    return '$count échec(s)';
  }

  @override
  String marketplace_size_kb(Object value) {
    return '$value Ko';
  }

  @override
  String marketplace_size_mb(Object value) {
    return '$value Mo';
  }

  @override
  String get marketplace_kind_subtitles =>
      'sous-titres et pistes de sous-titres';

  @override
  String get marketplace_type_subtitles => 'Sous-titres';

  @override
  String get marketplace_got_it => 'Compris';

  @override
  String marketplace_installing_progress(Object done, Object total) {
    return 'Installation… $done/$total';
  }

  @override
  String get browse_installing_all => 'Installation de toutes les extensions…';

  @override
  String browse_installed_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions installées',
      one: '$count extension installée',
    );
    return '$_temp0';
  }

  @override
  String get browse_uninstall_all_title => 'Désinstaller tout';

  @override
  String get browse_uninstall_all_body =>
      'Voulez-vous vraiment désinstaller toutes les extensions installées ?';

  @override
  String browse_uninstalled_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions désinstallées',
      one: '$count extension désinstallée',
    );
    return '$_temp0';
  }

  @override
  String get browse_updating_all => 'Mise à jour de toutes les extensions…';

  @override
  String browse_updated_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions mises à jour',
      one: '$count extension mise à jour',
    );
    return '$_temp0';
  }

  @override
  String get browse_no_active_source => 'Aucune source active installée.';

  @override
  String browse_opening_source(Object name) {
    return 'Ouverture de \"$name\"…';
  }

  @override
  String get browse_global_search_tooltip =>
      'Recherche globale · appui long = diagnostic';

  @override
  String get browse_more_options => 'Plus d\'options';

  @override
  String get browse_custom_sections => 'Mes sections';

  @override
  String get browse_marketplace => 'Marketplace';

  @override
  String get browse_how_to_local_source => 'How To — Source Locale';

  @override
  String get browse_random_source => 'Source aléatoire';

  @override
  String get browse_diagnostic => 'Diagnostic';

  @override
  String get browse_plugins => 'Plugins';

  @override
  String browse_sources_limited(Object lang) {
    return 'Sources limitées à $lang + EN';
  }

  @override
  String get browse_all_languages_restored => 'Toutes les langues réactivées';

  @override
  String get marketplace_tag_adult => 'Adulte';

  @override
  String get marketplace_sort_alpha => 'A → Z';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get notifications_refresh_tooltip => 'Actualiser';

  @override
  String get notifications_load_error =>
      'Impossible de charger les notifications.';

  @override
  String get notifications_checking_updates => 'Vérification des mises à jour…';

  @override
  String get notifications_updates_subtitle =>
      'Tes extensions installées ont une nouvelle version.';

  @override
  String notifications_update_single(Object name) {
    return 'Mise à jour de l’extension $name';
  }

  @override
  String notifications_update_message(Object name) {
    return 'Mise à jour de l’extension $name';
  }

  @override
  String notifications_updates_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mises à jour d’extensions',
      one: '$count mise à jour d’extension',
    );
    return '$_temp0';
  }

  @override
  String get notifications_install_all => 'Tout installer';

  @override
  String get notifications_install => 'Installer';

  @override
  String get notifications_dismiss_update => 'Masquer cette mise à jour';

  @override
  String notifications_updated_toast(Object name) {
    return '$name mise à jour';
  }

  @override
  String notifications_install_failed(Object error) {
    return 'Installation impossible : $error';
  }

  @override
  String notifications_new_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles extensions publiées',
      one: '$count nouvelle extension publiée',
    );
    return '$_temp0';
  }

  @override
  String get notifications_new_subtitle =>
      'Découvre les dernières extensions du catalogue.';

  @override
  String get notifications_browse_marketplace => 'Parcourir le Marketplace';

  @override
  String get notifications_hide => 'Masquer cette notification';

  @override
  String notifications_library_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mises à jour de bibliothèque',
      one: '$count mise à jour de bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String get notifications_library_subtitle =>
      'De nouveaux chapitres sont disponibles.';

  @override
  String get notifications_view_updates => 'Voir les mises à jour';

  @override
  String get notifications_none => 'Aucune nouvelle notification';

  @override
  String get marketplace_search_categories_title => 'Parcourir par catégorie';

  @override
  String get marketplace_search_recommended => 'Recommandations';

  @override
  String get marketplace_search_all_results => 'Tous les résultats';

  @override
  String get marketplace_search_sort => 'Trier';

  @override
  String get marketplace_search_filters => 'Filtres';

  @override
  String get marketplace_search_no_results_title => 'Aucun résultat';

  @override
  String get marketplace_search_no_results_body =>
      'Rien ne correspond à ta recherche.';

  @override
  String get marketplace_sort_recent => 'Récemment ajoutées';

  @override
  String get marketplace_search_sort_title => 'Trier par';

  @override
  String get marketplace_search_suggestions => 'Suggestions';

  @override
  String get marketplace_search_clear => 'Effacer';

  @override
  String marketplace_search_results_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '$count résultat',
    );
    return '$_temp0';
  }

  @override
  String get obNext => 'Suivant';

  @override
  String get obStart => 'Commencer';

  @override
  String get obBack => 'Retour';

  @override
  String get obContinue => 'Continuer';

  @override
  String get obSkipForNow => 'Passer pour l\'instant';

  @override
  String get obEnterWatchtower => 'Accéder à Watchtower';

  @override
  String get obPermissionsTitle => 'Autorisations';

  @override
  String get obPermissionsSubtitle =>
      'Watchtower a besoin de quelques accès pour fonctionner correctement.';

  @override
  String get obOptionalSection => 'OPTIONNEL';

  @override
  String get obPermStorageTitle => 'Stockage';

  @override
  String get obPermStorageSubtitle =>
      'Autoriser « accès à tous les fichiers » pour les téléchargements et Smart Library.';

  @override
  String get obPermStorageIosSubtitle =>
      'Accès sandbox iOS — aucune action requise.';

  @override
  String get obPermNotifTitle => 'Notifications';

  @override
  String get obPermNotifSubtitle =>
      'Téléchargements, mises à jour de la bibliothèque.';

  @override
  String get obPermInstallTitle => 'Installation d\'apps';

  @override
  String get obPermInstallSubtitle =>
      'Installer les mises à jour APK directement depuis l\'app.';

  @override
  String get obPermOverlayTitle => 'Overlay / PiP';

  @override
  String get obPermOverlaySubtitle =>
      'Afficher la vidéo en flottant par-dessus d\'autres apps.';

  @override
  String get obPermBatteryTitle => 'Pas de restriction batterie';

  @override
  String get obPermBatterySubtitle =>
      'Empêche Android de tuer les téléchargements en arrière-plan (Doze, veille).';

  @override
  String get obGrant => 'Autoriser';

  @override
  String get obGranted => 'Accordé';

  @override
  String get obShowcaseHeadline =>
      'Anime, mangas, romans, musique, films, séries et jeux — au même endroit.';

  @override
  String get obSloganWatch => 'Regarde.';

  @override
  String get obSloganRead => 'Lis.';

  @override
  String get obSloganListen => 'Écoute.';

  @override
  String get obSloganAll => 'Tout.';

  @override
  String get obSloganSub => 'Un seul endroit pour tout ce que tu aimes.';

  @override
  String get migTitle => 'Migration';

  @override
  String get migHeadline => 'Emportez votre bibliothèque avec vous.';

  @override
  String get migSpeech =>
      'Vous venez de Mihon, Aniyomi, Mangayomi ou d\'une autre app ? Watchtower lit leurs sauvegardes et leurs dossiers, puis reconstruit ici votre bibliothèque, vos catégories, votre progression de lecture et vos téléchargements.';

  @override
  String get migTabManga => 'Manga';

  @override
  String get migTabAnime => 'Animé';

  @override
  String get migTabUniversal => 'Universel';

  @override
  String get migSearchHint => 'Rechercher une app…';

  @override
  String get migFilterTitle => 'Filtre';

  @override
  String get migFilterPlatform => 'Plateforme';

  @override
  String get migFilterOpenSource => 'Open source uniquement';

  @override
  String get migFilterWithBackup => 'Import de sauvegarde pris en charge';

  @override
  String get migFilterReset => 'Réinitialiser les filtres';

  @override
  String get migSortTitle => 'Trier';

  @override
  String get migSortName => 'Alphabétiquement';

  @override
  String get migSortPlatform => 'Par plateforme';

  @override
  String get migMoreTitle => 'Options';

  @override
  String get migMoreSelectAll => 'Tout sélectionner';

  @override
  String get migMoreClear => 'Effacer la sélection';

  @override
  String get migMoreGuide => 'Guide de migration';

  @override
  String get migMoreRefresh => 'Actualiser';

  @override
  String migAppsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '1 app',
    );
    return '$_temp0';
  }

  @override
  String get migEmptySearch => 'Aucune app ne correspond à votre recherche.';

  @override
  String get migPros => 'Avantages';

  @override
  String get migCons => 'Inconvénients';

  @override
  String get migOfficialSite => 'Site officiel';

  @override
  String get migBackupFormat => 'Format de sauvegarde';

  @override
  String get migPlatforms => 'Plateformes';

  @override
  String get migSupported => 'Import pris en charge';

  @override
  String get migSelect => 'Sélectionner';

  @override
  String get migSelected => 'Sélectionné';

  @override
  String get migWhatToImport => 'Quoi importer';

  @override
  String get migImportLibrary => 'Bibliothèque et catégories';

  @override
  String get migImportLibrarySub =>
      'Titres, couvertures, catégories et état de lecture.';

  @override
  String get migImportDownloads => 'Chapitres téléchargés';

  @override
  String get migImportDownloadsSub =>
      'Copier ou déplacer les fichiers déjà téléchargés par Mihon.';

  @override
  String get migImportHistory => 'Historique de lecture';

  @override
  String get migImportHistorySub =>
      'Reprendre chaque série là où vous vous êtes arrêté.';

  @override
  String get migImportSettings => 'Réglages de l\'app';

  @override
  String get migImportSettingsSub =>
      'Thème, lecteur et préférences de téléchargement.';

  @override
  String get migBackupSource => 'Fichier de sauvegarde';

  @override
  String get migBackupSourceHint =>
      'Choisissez le fichier .tachibk exporté par l\'app.';

  @override
  String get migPickBackup => 'Choisir un fichier';

  @override
  String get migDownloadFolder => 'Dossier des téléchargements';

  @override
  String get migDownloadFolderHint =>
      'Le dossier où l\'autre app a stocké ses téléchargements.';

  @override
  String get migPickFolder => 'Choisir un dossier';

  @override
  String get migNoFile => 'Aucun fichier sélectionné';

  @override
  String get migFileMode => 'Traitement des fichiers';

  @override
  String get migCopy => 'Copier';

  @override
  String get migCopySub => 'Conserve les fichiers originaux.';

  @override
  String get migMove => 'Déplacer';

  @override
  String get migMoveSub => 'Libère l\'espace utilisé par l\'autre app.';

  @override
  String get migScan => 'Analyser';

  @override
  String get migScanning => 'Analyse…';

  @override
  String migScanResultLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées dans la sauvegarde',
      one: '1 entrée dans la sauvegarde',
    );
    return '$_temp0';
  }

  @override
  String migScanResultDownloads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres téléchargés trouvés',
      one: '1 chapitre téléchargé trouvé',
    );
    return '$_temp0';
  }

  @override
  String get migScanResultNone => 'Rien détecté pour l\'instant.';

  @override
  String get migStartImport => 'Lancer l\'import';

  @override
  String get migImporting => 'Import en cours…';

  @override
  String get migImportDone => 'Import terminé';

  @override
  String migImportLibraryDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées importées',
      one: '1 entrée importée',
    );
    return '$_temp0';
  }

  @override
  String migImportDownloadsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements importés',
      one: '1 téléchargement importé',
    );
    return '$_temp0';
  }

  @override
  String get migImportFailed => 'L\'import n\'a pas pu se terminer.';

  @override
  String get migNeedSelection => 'Choisissez au moins un élément à importer.';

  @override
  String get migDetectedApps => 'Apps détectées sur cet appareil';

  @override
  String get migNoDetectedApps =>
      'Aucune donnée d\'une autre app trouvée. Vous pouvez tout de même choisir une sauvegarde.';

  @override
  String get migFeatureTitle => 'Plus qu\'une bibliothèque';

  @override
  String get migFeatureTrackers =>
      'Les trackers et la progression AniList/MAL suivent vos titres.';

  @override
  String get migFeatureSync =>
      'La synchronisation cloud aligne tous vos appareils.';

  @override
  String get migFeatureExtensions =>
      'Installez des extensions pour ajouter des sources.';

  @override
  String get migFeatureSmart =>
      'Smart Library reconstruit vos étagères depuis vos fichiers.';

  @override
  String get migFooterHint =>
      'Tout est traité sur votre appareil. Rien n\'est envoyé.';

  @override
  String get migProMangaReader => 'Application de lecture de mangas';

  @override
  String get migProAnimeWatcher => 'Application de visionnage d\'anime';

  @override
  String get migProLightNovelReader => 'Application de lecture de light novels';

  @override
  String get migProBothAnimeManga => 'Prend en charge l\'anime et le manga';

  @override
  String get migProAnimeLnManga =>
      'Prend en charge anime, light novels et manga';

  @override
  String get migProManySources =>
      'De nombreuses sources d\'extensions disponibles';

  @override
  String get migProManySourcesShort => 'De nombreuses sources disponibles';

  @override
  String get migProOpenSource => 'Open source';

  @override
  String get migProActivelyDeveloped => 'Développement actif';

  @override
  String get migProLongTrackRecord => 'Longue expérience';

  @override
  String get migProCrossPlatform =>
      'Multiplateforme (Android, iOS, Mac, Windows, Linux)';

  @override
  String get migProDesktopPlatforms => 'Compatible Windows, Linux et Mac';

  @override
  String get migProOpenExtensionSystem => 'Système d\'extensions ouvert';

  @override
  String get migProNiceUi => 'Belle interface';

  @override
  String get migProIntegration =>
      'S\'intègre à de nombreuses apps (sauvegardes et extensions)';

  @override
  String get migProTracker => 'Tracker de mangas';

  @override
  String get migProTrackReleases =>
      'Suit les nouvelles sorties de chapitres sur plusieurs sites';

  @override
  String get migProEbookOutput => 'Génère des e-books';

  @override
  String get migProBatchZip => 'Téléchargement .zip par lot';

  @override
  String get migProLargeLibrary => 'Très grande bibliothèque';

  @override
  String get migProMangadexClient => 'Client MangaDex ciblé';

  @override
  String get migProSameAsMihon => 'Tout ce que fait Mihon, et plus';

  @override
  String get migProCombinesForks =>
      'Combine les fonctions de plusieurs forks de Mihon';

  @override
  String get migProEh => 'Intégration E-Hentai et ExHentai';

  @override
  String get migConAndroidOnly => 'Android uniquement';

  @override
  String get migConDesktopOnly => 'Bureau uniquement';

  @override
  String get migConNeedExtension =>
      'Nécessite l\'installation d\'une extension';

  @override
  String get migConExtensionSeparate => 'Extensions installées séparément';

  @override
  String get migConOriginalUnmaintained => 'Dépôt d\'origine plus maintenu';

  @override
  String get migConNotIosStore => 'Absent de l\'App Store iOS';

  @override
  String get migConNeedPlugins => 'Nécessite l\'installation de plugins';

  @override
  String get migConLessPopular => 'Moins populaire';

  @override
  String get migConNewApp => 'App récente, moins populaire';

  @override
  String get migConOnlyMangadex => 'Contenu MangaDex uniquement';

  @override
  String get migConCannotReadOffline => 'Pas de lecture hors ligne';

  @override
  String get migConArchived => 'Dépôt d\'origine archivé';

  @override
  String get migConTorrent => 'Dépend d\'une connexion torrent';

  @override
  String get migConIosDonors => 'Version iOS réservée aux donateurs';

  @override
  String get migConRaw => 'Mangas non traduits (raw)';

  @override
  String get migConBareboneSearch => 'Recherche et filtres minimalistes';

  @override
  String get migConNotDifferent => 'Pas radicalement différent';

  @override
  String get migConRelativelyNew => 'Relativement récent';

  @override
  String get migConMissingNewFeatures =>
      'Il manque des fonctions ajoutées à l\'app parente';

  @override
  String get migDetectedBackup => 'Sauvegarde trouvée';

  @override
  String get migDetectedDownloads => 'Téléchargements trouvés';

  @override
  String get transfer_title => 'Salle de partage';

  @override
  String get transfer_subtitle =>
      'Partagez vos téléchargements avec d\'autres appareils sur le même réseau WiFi, sans internet.';

  @override
  String transfer_chapters_available(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres disponibles à partager',
      one: '1 chapitre disponible à partager',
    );
    return '$_temp0';
  }

  @override
  String get transfer_join_room => 'REJOINDRE LA SALLE';

  @override
  String get transfer_lan_only =>
      'LAN / Hotspot uniquement · aucun serveur externe';

  @override
  String get transfer_devices_in_room => 'Appareils dans la salle';

  @override
  String get transfer_active_downloads => 'Téléchargements en cours';

  @override
  String get transfer_completed => 'Terminés';

  @override
  String transfer_started_download(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Téléchargement de $count fichiers démarré',
      one: 'Téléchargement de 1 fichier démarré',
    );
    return '$_temp0';
  }

  @override
  String get transfer_local_room => 'Salle locale';

  @override
  String get transfer_active => 'ACTIF';

  @override
  String get transfer_my_device => 'Mon appareil';

  @override
  String get transfer_me => 'Moi';

  @override
  String transfer_shared_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount mangas',
      one: '1 manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · $_temp1 partagés';
  }

  @override
  String get transfer_searching_devices => 'Recherche d\'appareils…';

  @override
  String get transfer_same_wifi_hint =>
      'Assurez-vous d\'être sur le même WiFi ou hotspot que les autres appareils.';

  @override
  String get transfer_loading_catalog => 'Chargement du catalogue…';

  @override
  String get transfer_catalog_unavailable => 'Catalogue non disponible';

  @override
  String transfer_catalog_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount mangas',
      one: '1 manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transfer_browse => 'Parcourir';

  @override
  String transfer_file_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0';
  }

  @override
  String get transfer_status_done => 'Terminé';

  @override
  String get transfer_status_failed => 'Échec';

  @override
  String get transfer_catalog_empty => 'Catalogue vide';

  @override
  String get transfer_no_files => 'Aucun fichier disponible';

  @override
  String get transfer_select_chapters => 'Sélectionner des chapitres';

  @override
  String transfer_download_count(Object count) {
    return 'Télécharger ($count)';
  }

  @override
  String get transfer_type_anime => 'ANIME';

  @override
  String get transfer_type_novel => 'ROMAN';

  @override
  String get transfer_type_other => 'AUTRE';

  @override
  String get transfer_type_manga => 'MANGA';

  @override
  String get transfer_howto_title => 'Comment transférer';

  @override
  String get transfer_howto_step1 =>
      'Connectez les deux appareils au même réseau WiFi ou hotspot.';

  @override
  String get transfer_howto_step2 =>
      'Sur l\'autre appareil, ouvrez Téléchargements → Transfert et rejoignez la salle.';

  @override
  String get transfer_howto_step3 =>
      'Touchez un appareil pour parcourir sa bibliothèque, choisissez des chapitres puis téléchargez.';

  @override
  String get transfer_platform_android => 'Android';

  @override
  String get transfer_platform_ios => 'iPhone / iPad';

  @override
  String get transfer_platform_windows => 'Windows';

  @override
  String get transfer_platform_macos => 'macOS';

  @override
  String get transfer_platform_linux => 'Linux';

  @override
  String get transfer_platform_web => 'Web';

  @override
  String get transfer_platform_unknown => 'Appareil';

  @override
  String get copied => 'Copié';

  @override
  String get copied_to_clipboard => 'Copié dans le presse-papiers';

  @override
  String get author_works => 'Oeuvres de cet auteur';

  @override
  String get select_range => 'Sélectionner la plage';

  @override
  String get select_all => 'Tout sélectionner';

  @override
  String get select_invert => 'Inverser la sélection';

  @override
  String get select_none => 'Tout désélectionner';

  @override
  String get download_range => 'Télécharger une plage';

  @override
  String get range_start => 'Début';

  @override
  String get range_end => 'Fin';

  @override
  String get download_range_hint =>
      'Les chapitres entre les deux numéros sont téléchargés, dans l\'ordre de lecture.';

  @override
  String get invalid_range => 'Plage invalide';

  @override
  String get no_comments => 'Aucun commentaire';

  @override
  String get plugins_ffmpeg_ready =>
      'Exécutable vérifié disponible pour les fichiers HLS.';

  @override
  String get plugins_ffmpeg_optional =>
      'Optionnel : la concaténation directe reste utilisée automatiquement.';

  @override
  String get browse_global_search_hint => 'Rechercher dans les extensions…';

  @override
  String get browse_intelligent_search => 'Recherche intelligente';

  @override
  String get browse_intelligent_search_tooltip =>
      'Qu’est-ce que la recherche intelligente ?';

  @override
  String get browse_intelligent_search_help =>
      'Une extension a sa propre recherche : quand elle n’a pas le titre exact, elle renvoie souvent des résultats proches mais non pertinents.\n\nLa recherche intelligente garde ce que l’extension a trouvé, mais ne montre que les résultats dont le nom correspond vraiment à votre recherche. L’algorithme est tolérant : « Narufo » retrouve « Naruto », et une recherche par un autre titre fonctionne aussi (par exemple « Attaque des Titans » pour « Shingeki no Kyojin »).';

  @override
  String get browse_pinned_sources => 'Sources épinglées';

  @override
  String get browse_clear_filters => 'Effacer les filtres';

  @override
  String get browse_filters => 'FILTRES';

  @override
  String get browse_clear => 'Effacer';

  @override
  String get browse_content => 'Contenu';

  @override
  String get browse_all_content => 'Tout le contenu';

  @override
  String get browse_sfw_only => 'SFW uniquement';

  @override
  String get browse_nsfw_only => 'NSFW uniquement';

  @override
  String get browse_source_type => 'Type de source';

  @override
  String get browse_no_source_found => 'Aucune source trouvée';

  @override
  String get browse_no_source_matches_filters =>
      'Aucune source ne correspond\naux filtres actifs';

  @override
  String get browse_try_another_term => 'Essayez un autre terme de recherche';

  @override
  String get browse_reset_filters => 'Réinitialiser les filtres';

  @override
  String get browse_retry_intelligently => 'Réessayer intelligemment';

  @override
  String get browse_got_it => 'Compris';

  @override
  String get browse_understood => 'Compris';

  @override
  String get browse_download_what => 'Que télécharger ?';

  @override
  String get browse_download_options => 'Options de téléchargement';

  @override
  String get browse_download_prompt_search =>
      'Lancez une recherche pour voir les titres à télécharger.';

  @override
  String get browse_from => 'De';

  @override
  String get browse_to => 'À';

  @override
  String get browse_wifi_only => 'Wi-Fi uniquement';

  @override
  String get browse_cbz_archive => 'Archive CBZ';

  @override
  String get browse_cbz_archive_subtitle =>
      'Empaqueter chaque chapitre dans un .cbz';

  @override
  String browse_connections_count(Object count) {
    return '$count connexion(s)';
  }

  @override
  String browse_download_queued(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres en file de téléchargement',
      one: '$count chapitre en file de téléchargement',
    );
    return '$_temp0';
  }

  @override
  String browse_download_failed(Object error) {
    return 'Téléchargement impossible : $error';
  }

  @override
  String get browse_chapter_label => 'Chapitre';

  @override
  String get browse_download_no_link =>
      'Cette entrée n’a pas de lien exploitable.';

  @override
  String get browse_download_no_chapters =>
      'Aucun chapitre disponible pour ce titre.';

  @override
  String get browse_download_no_valid_chapter =>
      'Aucun chapitre valide à télécharger.';

  @override
  String get browse_section_new => 'Nouvelle section';

  @override
  String get browse_section_rename => 'Renommer la section';

  @override
  String get browse_section_rename_short => 'Renommer';

  @override
  String browse_section_delete_title(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get browse_section_delete_body =>
      'La section est supprimée. Les extensions restent installées.';

  @override
  String get browse_section_name_hint => 'Nom de la section';

  @override
  String get browse_section_empty_title => 'Aucune section';

  @override
  String get browse_section_empty_body =>
      'Crée une section (par ex. « Hentai ») puis ajoute-lui les extensions que tu veux y regrouper.';

  @override
  String browse_section_extension_count(Object count) {
    return '$count extension(s)';
  }

  @override
  String get browse_section_add_extensions => 'Ajouter des extensions';

  @override
  String get browse_section_detail_empty =>
      'Cette section est vide. Ajoute des extensions pour les retrouver ici.';

  @override
  String get browse_section_picker_title => 'Extensions de la section';

  @override
  String get browse_section_no_extensions =>
      'Aucune extension installée pour ce type.';

  @override
  String browse_section_add_to(Object name) {
    return 'Ajouter « $name » à une section';
  }

  @override
  String get browse_section_create_first =>
      'Crée d’abord une section depuis le menu ⋮ de l’Explorateur.';

  @override
  String get browse_section_default_name => 'Section';

  @override
  String get browse_validate => 'Valider';

  @override
  String get browse_remove_tooltip => 'Retirer';

  @override
  String get browse_section_options => 'Options de la section';

  @override
  String get browse_section_enable => 'Activer la section';

  @override
  String get browse_section_disable => 'Désactiver la section';

  @override
  String get browse_section_pin => 'Épingler la section';

  @override
  String get browse_section_unpin => 'Désépingler la section';

  @override
  String get browse_load_extensions_failed =>
      'Impossible de charger les extensions';

  @override
  String get browse_check_connection =>
      'Réessaie après avoir vérifié la connexion.';

  @override
  String get browse_install_from_marketplace =>
      'Installe une extension depuis le Marketplace';

  @override
  String get browse_go_to_market => 'Aller au Marketplace';

  @override
  String get browse_no_matching_extension =>
      'Aucune extension ne correspond à la recherche ou aux filtres.';

  @override
  String get browse_scanning_extensions => 'Analyse des extensions…';

  @override
  String get browse_extension_settings => 'Paramètres de l’extension';

  @override
  String get browse_pin => 'Épingler';

  @override
  String get browse_unpin => 'Désépingler';

  @override
  String get browse_filter_installed => 'Extensions installées';

  @override
  String get browse_filter_active_only => 'Sources actives uniquement';

  @override
  String get browse_filter_content_nsfw => 'Contenu et NSFW';

  @override
  String get browse_filter_all_languages => 'Toutes les langues';

  @override
  String browse_filter_language_prefix(Object code) {
    return 'Langue : $code';
  }

  @override
  String get browse_filter_tags => 'Tags des extensions';

  @override
  String browse_filter_tags_count(Object count) {
    return '$count tag(s) sélectionné(s)';
  }

  @override
  String get browse_filter_done => 'Terminé';

  @override
  String get browse_filter_clear_search => 'Effacer la recherche';

  @override
  String get browse_filter_search_installed =>
      'Rechercher une extension installée';

  @override
  String get browse_tag_cloudflare => 'Cloudflare';

  @override
  String get browse_tag_account => 'Compte requis';

  @override
  String get browse_tag_drm => 'DRM';

  @override
  String get browse_tag_aggregator => 'Agrégateur';

  @override
  String get browse_tag_comments => 'Commentaires';

  @override
  String get browse_tag_torrent => 'Torrent';

  @override
  String get browse_tag_update => 'Mise à jour disponible';

  @override
  String get browse_tag_javascript => 'JavaScript';

  @override
  String get browse_tag_dart => 'Dart';

  @override
  String get browse_url_copied => 'URL copiée !';

  @override
  String browse_launch_failed(Object url) {
    return 'Impossible de lancer $url';
  }

  @override
  String get browse_no_local_layout =>
      'Aucun layout local disponible pour cette extension.';

  @override
  String get browse_layout_root_object =>
      'La racine du layout doit être un objet.';

  @override
  String get browse_save_card_failed =>
      'Impossible d’enregistrer la carte de recherche.';

  @override
  String get browse_search_card_saved => 'Carte de recherche enregistrée.';

  @override
  String browse_search_layout_invalid(Object error) {
    return 'Layout de recherche invalide : $error';
  }

  @override
  String get browse_invalid_site_url => 'URL du site invalide.';

  @override
  String get browse_login_open_failed =>
      'Impossible d’ouvrir la page de connexion.';

  @override
  String get browse_session_cleared => 'Session effacée pour cette extension.';

  @override
  String get browse_session_clear_failed =>
      'Impossible d’effacer la session de cette extension.';

  @override
  String get browse_session_checking => 'Vérification de la connexion…';

  @override
  String get browse_session_logging_in => 'Connexion en cours…';

  @override
  String get browse_session_logging_out => 'Déconnexion en cours…';

  @override
  String get browse_session_saved => 'Session du site enregistrée';

  @override
  String browse_session_connected(Object identity) {
    return 'Connecté : $identity';
  }

  @override
  String get browse_session_not_connected => 'Non connecté';

  @override
  String get browse_session_unavailable => 'État de connexion indisponible';

  @override
  String get browse_check_connection_short => 'Vérifier la connexion';

  @override
  String get browse_account_connected => 'Compte connecté';

  @override
  String get browse_account_fallback => 'Compte';

  @override
  String get browse_no_favorites => 'Aucun favori disponible.';

  @override
  String get browse_untitled => 'Sans titre';

  @override
  String browse_more_favorites(Object count) {
    return '+$count autres favoris';
  }

  @override
  String browse_expires_on(Object date) {
    return 'Expire le $date';
  }

  @override
  String get browse_details_unavailable => 'Détails indisponibles';

  @override
  String get browse_premium_status => 'Statut Premium';

  @override
  String get browse_status_unavailable => 'Statut indisponible';

  @override
  String get browse_status_active => 'Actif';

  @override
  String get browse_status_inactive => 'Inactif';

  @override
  String get browse_favorites => 'Favoris';

  @override
  String get browse_edit_base_url => 'Modifier l’URL de base';

  @override
  String get browse_base_url => 'URL de base';

  @override
  String get browse_base_url_updated => 'URL mise à jour !';

  @override
  String get browse_base_url_undefined => 'URL de base non définie.';

  @override
  String get browse_import_cookies => 'Importer des cookies';

  @override
  String get browse_cookies_format =>
      'Collez les cookies au format : clé=valeur; clé2=valeur2';

  @override
  String get browse_cookies_hint => 'session=abc123; token=xyz789';

  @override
  String get browse_cookies_imported => 'Cookies importés !';

  @override
  String get browse_cookies_import_failed =>
      'Erreur lors de l’import des cookies.';

  @override
  String get browse_cookies_none_available =>
      'Aucun cookie disponible pour cette extension.';

  @override
  String get browse_cookies_copied => 'Cookies copiés !';

  @override
  String get browse_cookies_none_stored =>
      'Aucun cookie stocké pour cette extension.';

  @override
  String get browse_export_cookies => 'Exporter les cookies';

  @override
  String get browse_stored_cookies => 'Cookies stockés';

  @override
  String get browse_user_agent => 'User-Agent';

  @override
  String get browse_user_agent_help =>
      'Laissez vide pour utiliser le User-Agent par défaut.';

  @override
  String get browse_reset => 'Réinitialiser';

  @override
  String get browse_user_agent_reset => 'User-Agent réinitialisé.';

  @override
  String get browse_user_agent_updated => 'User-Agent mis à jour !';

  @override
  String get browse_clear_data_title => 'Effacer les données ?';

  @override
  String get browse_clear_data_body =>
      'Cela supprimera toutes les préférences, cookies et données associés à cette extension.';

  @override
  String get browse_clear_data_confirm => 'Effacer';

  @override
  String get browse_data_cleared => 'Données effacées !';

  @override
  String get browse_clear_cache_title => 'Vider le cache ?';

  @override
  String get browse_clear_cache_body =>
      'Cela rechargera les préférences de l’extension depuis la base locale et tentera d’invalider le cache HTTP de cette source. Les cookies ne sont pas affectés.';

  @override
  String get browse_cache_emptied => 'Vider';

  @override
  String get browse_prefs_reloaded =>
      'Préférences rechargées. Rouvrez la source pour actualiser le cache.';

  @override
  String get browse_http_headers => 'En-têtes HTTP';

  @override
  String get browse_no_headers => 'Aucun en-tête défini.';

  @override
  String get browse_headers_copied => 'En-têtes copiés !';

  @override
  String get browse_extension_missing =>
      'Cette extension n’existe plus dans le stockage local.';

  @override
  String get browse_extension_uninstalled => 'Extension désinstallée.';

  @override
  String browse_uninstall_failed(Object error) {
    return 'Erreur lors de la désinstallation : $error';
  }

  @override
  String get browse_uninstall_extension => 'Désinstaller l’extension';

  @override
  String get browse_cookies_deleted => 'Cookies supprimés !';

  @override
  String get browse_import_cookie => 'Importer cookie';

  @override
  String get browse_view_cookies => 'Voir cookies';

  @override
  String get browse_clear_cookies => 'Effacer cookies';

  @override
  String get browse_clear_cache_short => 'Effacer le cache';

  @override
  String get browse_clear_data_short => 'Effacer les données';

  @override
  String get browse_edit_url => 'Modifier l’URL';

  @override
  String get browse_view_headers => 'Voir les en-têtes';

  @override
  String get browse_edit_user_agent => 'Modifier User-Agent';

  @override
  String get browse_obsolete => 'Obsolète';

  @override
  String get browse_not_installed => 'Non installée';

  @override
  String get browse_account_required => 'Compte requis';

  @override
  String get browse_repository => 'Dépôt';

  @override
  String get browse_available => 'Disponible';

  @override
  String get browse_account_and_features => 'Compte et fonctionnalités';

  @override
  String get browse_account_desc =>
      'La connexion et les informations affichées sont propres à cette extension. Les données de session utilisées par ses requêtes restent séparées.';

  @override
  String get browse_account_desc_generic =>
      'Les informations affichées sont fournies par les méthodes déclarées par cette extension.';

  @override
  String get browse_sign_in => 'Se connecter';

  @override
  String get browse_clear_session => 'Effacer la session';

  @override
  String get browse_home_layout => 'Disposition de l’accueil';

  @override
  String get browse_edit_visually => 'Éditer visuellement';

  @override
  String get browse_search_results => 'Résultats de recherche';

  @override
  String get browse_choose_result_card => 'Choisir une carte de résultat';

  @override
  String get browse_extension_word => 'Extension';

  @override
  String get browse_open_settings => 'Ouvrir les paramètres';

  @override
  String get browse_diag_export_report => 'Exporter le rapport';

  @override
  String browse_diag_files_count(Object count) {
    return '$count fichiers';
  }

  @override
  String get browse_diag_summary_view => 'Vue synthèse';

  @override
  String get browse_diag_view_raw => 'Voir le rapport brut';

  @override
  String get browse_diag_copy => 'Copier';

  @override
  String browse_diag_raw_report(Object format) {
    return 'Rapport brut — $format';
  }

  @override
  String browse_diag_chars_count(Object count) {
    return '$count characters';
  }

  @override
  String get browse_diag_tab_extension => 'Extension';

  @override
  String get browse_diag_tab_detail => 'Détail';

  @override
  String get browse_diag_in_progress => 'Diagnostic en cours…';

  @override
  String get browse_diag_waiting => 'En attente du diagnostic';

  @override
  String get browse_diag_test_extension => 'Tester cette extension';

  @override
  String get browse_diag_interrupted =>
      'Diagnostic interrompu — certaines étapes n’ont pas pu être exécutées.';

  @override
  String get browse_diag_retest => 'Retester cette extension';

  @override
  String browse_diag_results_count(Object count) {
    return '$count résultats';
  }

  @override
  String browse_diag_logs(Object label) {
    return 'LOGS — $label';
  }

  @override
  String get browse_diag_no_trace => 'Aucune trace pour cette étape.';

  @override
  String browse_diag_sources_count(Object count) {
    return '$count sources';
  }

  @override
  String browse_diag_page_of(Object page, Object total) {
    return 'Page $page / $total';
  }

  @override
  String get browse_diag_image_unreachable => 'Image inaccessible';

  @override
  String get browse_diag_open_detail => 'Ouvrir le détail';

  @override
  String get browse_diag_no_errors => 'Aucune erreur détectée sur les étapes.';

  @override
  String browse_diag_running(Object label) {
    return 'Diagnostic $label en cours…';
  }

  @override
  String browse_diag_title(Object label) {
    return 'Diagnostic $label';
  }

  @override
  String get browse_diag_no_extension_installed => 'Aucune extension installée';

  @override
  String get browse_diag_change_filters =>
      'Modifiez la recherche ou les filtres depuis le panneau Panel.';

  @override
  String get browse_diag_no_extension_selected =>
      'Aucune extension sélectionnée';

  @override
  String get browse_diag_no_results_yet => 'Pas encore de résultats';

  @override
  String get browse_diag_no_report => 'Aucun rapport';

  @override
  String get browse_diag_control_panel => 'Panel de contrôle';

  @override
  String get browse_diag_all => 'Toutes';

  @override
  String get browse_diag_everything => 'Tout';

  @override
  String get browse_diag_sfw => 'SFW';

  @override
  String get browse_diag_only_errors => 'Afficher uniquement les erreurs';

  @override
  String get browse_diag_only_tested =>
      'Afficher uniquement les extensions testées';

  @override
  String get browse_diag_canceling => 'Annulation…';

  @override
  String get browse_diag_panel => 'Panel';

  @override
  String get browse_diag_results => 'Résultats';

  @override
  String get browse_diag_all_respond => 'Toutes les sources répondent ✓';

  @override
  String browse_diag_unanalyzed(Object count) {
    return '$count non analysée(s)';
  }

  @override
  String browse_diag_remaining(Object count) {
    return '$count restantes';
  }

  @override
  String get browse_diag_restart => 'Relancer';

  @override
  String get browse_diag_err_short => 'Err.';

  @override
  String get browse_diag_tested => 'Testées';

  @override
  String get browse_create_title => 'Créer une extension';

  @override
  String get browse_create_language => 'LANGAGE';

  @override
  String get browse_create_information => 'INFORMATIONS';

  @override
  String get browse_create_name => 'Nom';

  @override
  String get browse_create_name_hint => 'ex : myAnime';

  @override
  String get browse_create_api_url => 'API URL (optionnel)';

  @override
  String get browse_create_icon_url => 'URL icône';

  @override
  String get browse_create_notes => 'Notes';

  @override
  String get browse_create_notes_hint => 'ex : nécessite une connexion';

  @override
  String get browse_create_type => 'TYPE';

  @override
  String get browse_create_source => 'Source';

  @override
  String get browse_create_lang_iso => 'Langue (code ISO)';

  @override
  String get browse_create_lang_hint => 'ex : fr, en, ja';

  @override
  String get browse_create_exists => 'Ce nom d’extension existe déjà.';

  @override
  String get browse_create_native_recommended => 'Native · Recommandé';

  @override
  String get browse_create_js_universal => 'JS universel';

  @override
  String get browse_layout_format => 'Formater (indenté)';

  @override
  String get browse_layout_minify => 'Minifier';

  @override
  String get browse_layout_save => 'Enregistrer le layout';

  @override
  String get browse_layout_placeholder => 'Le JSON du layout apparaîtra ici';

  @override
  String get browse_layout_saving => 'Enregistrement…';

  @override
  String get browse_layout_wrap => 'Retour à la ligne';

  @override
  String get browse_layout_numbers => 'Numéros';

  @override
  String get browse_layout_left => 'Gauche';

  @override
  String get browse_layout_center => 'Centre';

  @override
  String get browse_code_import_file => 'Importer un fichier';

  @override
  String browse_code_file_imported(Object name) {
    return 'Fichier importé : $name';
  }

  @override
  String browse_code_import_error(Object error) {
    return 'Erreur import : $error';
  }

  @override
  String get browse_code_save => 'Sauvegarder';

  @override
  String get browse_code_saved => 'Sauvegardé';

  @override
  String get browse_code_clear_logs => 'Effacer les logs';

  @override
  String get browse_pref_setting => 'Réglage';

  @override
  String get browse_pref_choice => 'Choix';

  @override
  String get browse_pref_multi_choice => 'Choix multiples';

  @override
  String browse_anime_episode(Object number) {
    return 'Épisode $number';
  }

  @override
  String browse_anime_play_failed(Object error) {
    return 'Lecture impossible : $error';
  }

  @override
  String get browse_anime_episode_sources => 'Sources de l’épisode';

  @override
  String get browse_anime_play_episode => 'Lire cet épisode';

  @override
  String browse_local_how_to_title(Object type) {
    return 'Local $type — Comment utiliser';
  }

  @override
  String get browse_alternative => 'Alternatif';

  @override
  String get browse_close => 'Fermer';

  @override
  String get browse_copy => 'Copier';

  @override
  String browse_diag_steps_header(Object media) {
    return 'Étapes — Popular · Latest · Détail · $media';
  }

  @override
  String get browse_diag_videos => 'Vidéos';

  @override
  String get browse_diag_pages => 'Pages';

  @override
  String get browse_diag_not_tested => 'non testé';

  @override
  String browse_diag_lang_filter(Object name) {
    return 'Langue: $name';
  }

  @override
  String browse_diag_type_filter(Object name) {
    return 'Type: $name';
  }

  @override
  String get browse_diag_nsfw_only => 'NSFW seulement';

  @override
  String get browse_diag_sfw_only => 'SFW seulement';

  @override
  String get browse_diag_all_extensions => 'Toutes les extensions';

  @override
  String browse_diag_notify_running(Object label) {
    return 'Diagnostic $label en cours…';
  }

  @override
  String browse_diag_notify_title(Object label) {
    return 'Diagnostic $label';
  }

  @override
  String browse_diag_cancelled(Object done, Object total) {
    return 'Diagnostic annulé — $done / $total analysée(s).';
  }

  @override
  String browse_diag_finished(Object failed, Object ok) {
    return 'Diagnostic terminé — $ok OK · $failed échec(s).';
  }

  @override
  String get browse_diag_cancelling_snack => 'Annulation du diagnostic…';

  @override
  String browse_diag_retest_cancelled(Object name) {
    return 'Retest annulé pour $name.';
  }

  @override
  String browse_diag_retest_ok(Object name) {
    return '✅ $name répond correctement maintenant.';
  }

  @override
  String browse_diag_retest_fail(Object name) {
    return '❌ $name échoue toujours — voir les logs de l’étape.';
  }

  @override
  String get browse_diag_no_report_available =>
      'Aucun rapport disponible — lancez un diagnostic.';

  @override
  String browse_diag_report_copied(Object format) {
    return 'Rapport $format copié ✓';
  }

  @override
  String get browse_diag_no_extension_selected_snack =>
      'Aucune extension sélectionnée — activez-en au moins une.';

  @override
  String get browse_diag_no_extension_filter =>
      'Aucune extension pour ce filtre.';

  @override
  String get browse_diag_ready => 'Prêt à diagnostiquer';

  @override
  String get browse_diag_paused => 'En pause';

  @override
  String get browse_diag_running_state => 'Diagnostic en cours';

  @override
  String get browse_diag_interrupted_state => 'Interrompu';

  @override
  String get browse_diag_complete => 'Diagnostic terminé';

  @override
  String get browse_diag_complete_errors => 'Terminé avec erreurs';

  @override
  String get browse_diag_ready_short => 'Prêt';

  @override
  String browse_diag_extensions_analyzed(
    Object done,
    Object elapsed,
    Object total,
  ) {
    return '$done / $total extensions analysées · $elapsed';
  }

  @override
  String browse_diag_select_hint(Object count) {
    return 'Cochez les extensions à tester · $count sélectionnées';
  }

  @override
  String get browse_diag_panel_type => 'Type';

  @override
  String get browse_diag_panel_content => 'Contenu';

  @override
  String get browse_diag_panel_options => 'Options';

  @override
  String get browse_diag_resume => 'Reprendre';

  @override
  String get browse_diag_pause => 'Pause';

  @override
  String get browse_diag_start => 'Lancer le diagnostic';

  @override
  String get browse_diag_view_extensions => 'Voir les extensions';

  @override
  String get browse_diag_open_panel => 'Ouvrir le Panel';

  @override
  String get browse_diag_back => 'Retour';

  @override
  String get browse_diag_add_extensions =>
      'Ajoutez des extensions depuis le Marketplace avant de lancer un diagnostic.';

  @override
  String get browse_diag_no_extension_filters =>
      'Aucune extension pour ces filtres';

  @override
  String get browse_diag_touch_extension =>
      'Touchez une extension dans la liste pour afficher ses étapes, logs et erreurs détaillées.';

  @override
  String get browse_diag_results_appear =>
      'Les extensions analysées apparaîtront ici avec leurs étapes et logs.';

  @override
  String get browse_diag_run_for_report =>
      'Lancez un diagnostic pour obtenir un rapport détaillé exportable (Markdown, JSON, TXT, CSV).';

  @override
  String browse_diag_step_failed(Object count) {
    return '$count étape(s) en échec — ouvrez chaque étape pour les logs.';
  }

  @override
  String get browse_diag_extension_word => 'Extension';

  @override
  String get browse_diag_analyzing => 'Analyse en cours…';

  @override
  String get browse_diag_waiting_short => 'En attente…';

  @override
  String get browse_local_folder => '📁 Dossier local';

  @override
  String get browse_local_formats => '🗂️ Formats supportés';

  @override
  String get browse_local_organization => '🗃️ Organisation des dossiers';

  @override
  String get browse_local_recommended_structure => 'Structure recommandée :';

  @override
  String get browse_local_tips => 'Astuces';

  @override
  String get browse_local_default => 'Par défaut';

  @override
  String get browse_local_alt => 'Alternatif';

  @override
  String browse_local_default_path(Object type) {
    return 'Sur mon iPhone → Watchtower → Local/$type';
  }

  @override
  String browse_local_alt_path(Object type) {
    return 'Sur mon iPhone → Watchtower → $type';
  }

  @override
  String get browse_local_scan_note =>
      'Watchtower scannera ce dossier automatiquement à l’ouverture de la source locale.';

  @override
  String browse_local_hero_title(Object type) {
    return 'Source Locale $type';
  }

  @override
  String get browse_local_hero_subtitle =>
      'Lis tes fichiers locaux directement depuis ton appareil, sans connexion internet.';

  @override
  String browse_local_tip_source(Object type) {
    return 'Ouvre la source « $type Local » dans Browse → Sources pour voir tes fichiers.';
  }

  @override
  String get browse_local_tip_subfolder =>
      'Crée un sous-dossier par titre pour une meilleure organisation.';

  @override
  String get browse_local_tip_cover =>
      'Un fichier cover.jpg dans le dossier du titre sera utilisé comme couverture.';

  @override
  String get browse_local_tip_pull =>
      'Tire vers le bas sur la bibliothèque locale pour rescanner les fichiers.';

  @override
  String get browse_local_type_music => 'Musique';

  @override
  String get browse_local_type_game => 'Jeu';

  @override
  String get browse_local_type_plugin => 'Plugin';

  @override
  String get browse_create_base_url => 'URL de base';

  @override
  String get browse_account_required_chip => '🔐 Compte requis';

  @override
  String get browse_drm_chip => '🔒 DRM';

  @override
  String browse_version_up(Object version) {
    return '↑ v$version';
  }

  @override
  String browse_version_short(Object version) {
    return 'v$version';
  }

  @override
  String get browse_cookies => 'Cookies';

  @override
  String get browse_user_agent_hint => 'Mozilla/5.0 ...';

  @override
  String get browse_cloudflare => 'Cloudflare';

  @override
  String get settings_remote_bypass_title => 'Serveur de contournement distant';

  @override
  String get settings_remote_bypass_help =>
      'Entrez l’URL de votre instance FlareSolverr (ex : http://192.168.1.10:8191)';

  @override
  String get settings_remote_server_url => 'URL du serveur';

  @override
  String get settings_remote_api_key => 'Clé API (optionnel)';

  @override
  String get settings_remote_timeout => 'Délai d’attente (ms)';

  @override
  String get settings_remote_trigger_mode => 'Mode de déclenchement';

  @override
  String get settings_remote_mode_auto => 'Automatique';

  @override
  String get settings_remote_mode_auto_desc =>
      'Utilise le serveur distant dès que les 2 tentatives locales échouent';

  @override
  String get settings_remote_mode_on_demand => 'Sur demande';

  @override
  String get settings_remote_mode_on_demand_desc =>
      'Utilise le serveur distant uniquement quand vous appuyez sur « Contourner via serveur distant »';

  @override
  String get settings_save => 'Enregistrer';

  @override
  String get settings_clear_database => 'Effacer la base de données';

  @override
  String settings_clear_database_body(Object count) {
    return '$count série(s) non enregistrées dans votre bibliothèque seront supprimées.\n\nCette action est irréversible.';
  }

  @override
  String get settings_clear_image_caches_title =>
      'Vider tous les caches d’images ?';

  @override
  String get settings_clear_image_caches_body =>
      'Les couvertures et les icônes d’extensions seront rechargées au prochain affichage. Vos téléchargements ne sont pas affectés.';

  @override
  String get settings_share_crash_reports =>
      'Partager les rapports de plantage';

  @override
  String get settings_share_crash_reports_desc =>
      'Enregistre les rapports de plantage dans un fichier pour les partager avec les développeurs';

  @override
  String get settings_detailed_reports => 'Rapports détaillés';

  @override
  String get settings_detailed_reports_desc =>
      'Inclut des rapports détaillés dans les traces systèmes (réduit les performances de l’application)';

  @override
  String get settings_onboarding_guide => 'Guide de premier lancement';

  @override
  String get settings_onboarding_guide_desc =>
      'Relancer le tutoriel de démarrage';

  @override
  String get settings_manage_notifications =>
      'Gérer les alertes de l’application';

  @override
  String get settings_disable_battery_optimisation =>
      'Désactiver la fonction d’optimisation de la batterie';

  @override
  String get settings_disable_battery_optimisation_desc =>
      'Facilite les mises à jour et sauvegardes de la bibliothèque en arrière-plan';

  @override
  String get settings_dont_kill_my_app_desc =>
      'Certains fabricants ont mis en place des restrictions supplémentaires sur les applications qui tuent les services d’arrière-plan. Ce site Web contient plus d’informations sur la manière de résoudre ce problème.';

  @override
  String get settings_remote_enable => 'Activer le serveur distant';

  @override
  String settings_remote_connected(Object url) {
    return 'Connecté à $url';
  }

  @override
  String get settings_remote_none_configured =>
      'Aucun serveur configuré — Appuyez sur Configurer';

  @override
  String get settings_remote_configure => 'Configurer le serveur distant';

  @override
  String get settings_remote_configure_desc =>
      'URL, clé API, délai, mode de déclenchement';

  @override
  String get settings_flaresolverr_help =>
      'FlareSolverr est un serveur proxy qui utilise un navigateur headless pour résoudre les challenges Cloudflare. Installez-le sur votre machine ou serveur local et entrez son URL ici.';

  @override
  String get settings_reindex_downloads => 'Réindexe les téléchargements';

  @override
  String get settings_reindex_downloads_desc =>
      'Recherche les fichiers déjà présents sur le disque et corrige les entrées manquantes';

  @override
  String get settings_downloads_not_in_library =>
      'Téléchargés non en bibliothèque';

  @override
  String get settings_downloads_not_in_library_desc =>
      'Ajoute automatiquement à la bibliothèque toutes les séries dont un chapitre est déjà téléchargé';

  @override
  String get settings_clear_database_desc =>
      'Supprimer l’historique des séries qui ne sont pas enregistrées dans votre bibliothèque';

  @override
  String get settings_clear_cookies => 'Effacer les cookies';

  @override
  String get settings_clear_webview_data => 'Effacer les données WebView';

  @override
  String get settings_doh => 'DNS sur HTTPS (DoH)';

  @override
  String get settings_default_user_agent_list =>
      'Liste d’agents utilisateurs par défaut';

  @override
  String get settings_reset_user_agent =>
      'Réinitialiser la liste d’agents utilisateurs';

  @override
  String get settings_icon_cover_cache => 'Cache des icônes et couvertures';

  @override
  String get settings_max_cache_size => 'Taille maximale du cache';

  @override
  String get settings_max_cache_size_desc =>
      'Plafond total de tous les caches d’images. Le plus ancien est supprimé en premier quand la limite est atteinte.';

  @override
  String get settings_clear_icon_cache =>
      'Vider le cache des icônes d’extensions';

  @override
  String get settings_clear_cover_cache =>
      'Vider le cache des couvertures de bibliothèque';

  @override
  String get settings_clear_all_image_caches =>
      'Vider tous les caches d’images';

  @override
  String get settings_refresh_cache_sizes => 'Rafraîchir les tailles de cache';

  @override
  String get settings_refresh_cache_sizes_desc =>
      'Recalcule la taille des caches disque';

  @override
  String settings_current_size(Object size) {
    return 'Taille actuelle : $size';
  }

  @override
  String settings_current_total_size(Object size) {
    return 'Taille totale actuelle : $size';
  }

  @override
  String get settings_refresh_library_covers =>
      'Actualiser les couvertures de la bibliothèque';

  @override
  String get settings_refreshing_covers => 'Actualisation des couvertures…';

  @override
  String get settings_reset_reader_per_series =>
      'Réinitialiser les paramètres du lecteur par série';

  @override
  String get settings_reset_reader_per_series_desc =>
      'Réinitialise le mode de lecture et l’orientation de toutes les séries';

  @override
  String get settings_reset_reader_title =>
      'Réinitialiser les paramètres du lecteur';

  @override
  String get settings_reader_reset_done =>
      'Paramètres du lecteur réinitialisés';

  @override
  String get settings_error => 'Erreur';

  @override
  String get settings_update_library_titles =>
      'Mettre à jour les titres des séries de la bibliothèque';

  @override
  String get settings_update_library_titles_desc =>
      'Attention : si une série est renommée, elle sera supprimée de la file d’attente de téléchargement.';

  @override
  String get settings_updating_titles => 'Mise à jour des titres en cours…';

  @override
  String get settings_no_non_ascii =>
      'Interdire les noms de fichiers non ASCII';

  @override
  String get settings_no_non_ascii_desc =>
      'Assure la compatibilité avec certains supports de stockage qui ne prennent pas en charge Unicode';

  @override
  String get settings_bitmap_threshold =>
      'Seuil de bitmap matériel personnalisé';

  @override
  String get settings_bitmap_threshold_desc =>
      'Si le lecteur charge une image vierge, réduire progressivement le seuil.';

  @override
  String get settings_old_decoder =>
      'Utiliser l’ancien décodeur pour le lecteur de bandes longues';

  @override
  String get settings_old_decoder_desc =>
      'Affecte les performances. Ne l’activer que si la réduction du seuil de bitmap ne résout pas les problèmes d’images vierges';

  @override
  String get settings_custom_display_profile =>
      'Profil d’affichage personnalisé';

  @override
  String get settings_installer => 'Installeur';

  @override
  String get settings_revoke_extra_repo_extensions =>
      'Révoquer les extensions provenant d’un répertoire additionnel';

  @override
  String get settings_revoke_extensions_title => 'Révoquer les extensions';

  @override
  String get settings_revoke_extensions_body =>
      'Toutes les extensions provenant de dépôts additionnels seront révoquées.';

  @override
  String get settings_revoke => 'Révoquer';

  @override
  String get settings_extensions_revoked => 'Extensions révoquées';

  @override
  String get settings_interface_scale => 'Échelle de l’interface';

  @override
  String get settings_interface_scale_desc =>
      'Adapte la taille de l’interface (texte + espacements). Utile pour les petits écrans comme l’iPhone 7.';

  @override
  String settings_default_suffix(Object value) {
    return '$value (défaut)';
  }

  @override
  String get settings_logs_enable_hint =>
      'Activez les logs dans À propos > Développeur pour configurer ces options.';

  @override
  String get settings_log_mode => 'Mode de logging';

  @override
  String get settings_log_suppress_images => 'Supprimer erreurs d’images';

  @override
  String get settings_log_suppress_images_desc =>
      'Ne pas enregistrer les erreurs de logos 404';

  @override
  String get settings_log_active_categories => 'Catégories actives';

  @override
  String get settings_log_customisable => 'personnalisables';

  @override
  String get settings_log_tag_ext => 'Extensions [EXT]';

  @override
  String get settings_log_tag_ext_desc =>
      'Installation, mise à jour, erreurs d’extensions';

  @override
  String get settings_log_tag_install => 'Installation détaillée [INSTALL]';

  @override
  String get settings_log_tag_install_desc =>
      'Chaque étape d’installation/désinstallation';

  @override
  String get settings_log_tag_dl => 'Téléchargements [DL]';

  @override
  String get settings_log_tag_dl_desc =>
      'Progression, reprise, erreurs de téléchargements';

  @override
  String get settings_log_tag_hls => 'HLS streaming [HLS]';

  @override
  String get settings_log_tag_hls_desc =>
      'Segments HLS, manifest, erreurs de stream';

  @override
  String get settings_log_tag_net => 'Réseau [NET]';

  @override
  String get settings_log_tag_net_desc =>
      'Requêtes HTTP, redirections, erreurs réseau';

  @override
  String get settings_log_tag_manga => 'Manga [MANGA]';

  @override
  String get settings_log_tag_manga_desc =>
      'Chargement série, chapitres, métadonnées';

  @override
  String get settings_log_tag_reader => 'Lecteur [READER]';

  @override
  String get settings_log_tag_reader_desc =>
      'Navigation lecteur, zoom, orientation';

  @override
  String get settings_log_tag_page => 'Pages manga [PAGE]';

  @override
  String get settings_log_tag_page_desc =>
      '⚡ Chaque page chargée (très verbeux)';

  @override
  String get settings_log_tag_watch => 'Lecture vidéo [WATCH]';

  @override
  String get settings_log_tag_watch_desc =>
      'Ouverture épisode, buffering, watchdog 60 s';

  @override
  String get settings_log_tag_maint => 'Maintenance [MAINT]';

  @override
  String get settings_log_tag_maint_desc =>
      'Nettoyage cookies, BDD, réindexation, tâches d’arrière-plan';

  @override
  String get settings_log_tag_ui => 'Interface [UI]';

  @override
  String get settings_log_tag_ui_desc => 'Événements et erreurs d’interface';

  @override
  String get settings_log_tag_img => 'Images [IMG]';

  @override
  String get settings_log_tag_img_desc =>
      'Téléchargement des couvertures : cache, réseau, échecs';

  @override
  String get settings_silent_updates => 'Mises à jour silencieuses';

  @override
  String get settings_silent_active =>
      'Actif — les mises à jour s’installent automatiquement sans confirmation.';

  @override
  String get settings_silent_shizuku_required =>
      'Shizuku est nécessaire pour une configuration initiale unique. Appuyez pour configurer.';

  @override
  String get settings_silent_shizuku_not_running =>
      'Shizuku n’est pas démarré. Ouvrez Shizuku puis revenez ici.';

  @override
  String get settings_silent_checking => 'Vérification…';

  @override
  String get settings_auto_install => 'Installation automatique';

  @override
  String get settings_data => 'Données';

  @override
  String get settings_network => 'Réseau';

  @override
  String get settings_reader => 'Lecteur';

  @override
  String get settings_display => 'Affichage';

  @override
  String get settings_advanced_logs => 'Logs avancés';

  @override
  String get settings_background_activity => 'Activité en arrière-plan';

  @override
  String get settings_advanced => 'Avancé';

  @override
  String get settings_remote_section => 'Contournement Cloudflare distant';

  @override
  String get settings_library => 'Bibliothèque';

  @override
  String get settings_cookies_cleared => 'Cookies effacés';

  @override
  String get settings_webview_data_cleared => 'Données WebView effacées';

  @override
  String get settings_cookies_clear_failed =>
      'Erreur lors de la suppression des cookies';

  @override
  String get settings_webview_clear_failed =>
      'Erreur lors de la suppression des données WebView';

  @override
  String settings_db_cleared(Object count) {
    return 'Base de données nettoyée ($count supprimées)';
  }

  @override
  String get settings_clear => 'Effacer';

  @override
  String get settings_empty => 'Vider';

  @override
  String get settings_reindexing => 'Réindexation en cours…';

  @override
  String settings_reindex_done(Object fixed, Object total) {
    return '$fixed chapitre(s) réindexé(s) sur $total';
  }

  @override
  String get settings_checking => 'Vérification en cours…';

  @override
  String settings_added_to_library(Object count) {
    return '$count série(s) ajoutées à la bibliothèque';
  }

  @override
  String settings_bytes_o(Object bytes) {
    return '$bytes o';
  }

  @override
  String settings_bytes_ko(Object value) {
    return '$value Ko';
  }

  @override
  String settings_bytes_mo(Object value) {
    return '$value Mo';
  }

  @override
  String settings_bytes_go(Object value) {
    return '$value Go';
  }

  @override
  String get settings_icon_cache_cleared => 'Cache des icônes vidé';

  @override
  String get settings_cover_cache_cleared => 'Cache des couvertures vidé';

  @override
  String get settings_all_caches_cleared =>
      'Tous les caches d’images ont été vidés';

  @override
  String get settings_user_agent_reset => 'Agent utilisateur réinitialisé';

  @override
  String get settings_user_agent_reset_failed =>
      'Erreur lors de la réinitialisation';

  @override
  String get settings_battery_settings_failed =>
      'Impossible d’ouvrir les paramètres d’optimisation de batterie.\nAllez dans Paramètres > Batterie > Optimisation de batterie.';

  @override
  String get settings_notifications_hint_android =>
      'Ouvrez Paramètres > Notifications pour gérer les alertes.';

  @override
  String get settings_notifications_hint_ios =>
      'Ouvrez les Réglages système pour gérer les notifications.';

  @override
  String get settings_extreme_warning =>
      '⚡ Extreme – tout est logué. RAM +++. À utiliser avec précaution.';

  @override
  String get settings_debug_warning =>
      '⚠ Mode Debug actif – consommation RAM élevée';

  @override
  String get settings_log_mode_normal => 'Normal';

  @override
  String get settings_log_mode_normal_desc =>
      'INFO+ · extensions & installs uniquement';

  @override
  String get settings_log_mode_verbose => 'Verbose';

  @override
  String get settings_log_mode_verbose_desc =>
      'DEBUG+ · réseau, téléchargements, manga, HLS';

  @override
  String get settings_log_mode_debug => 'Debug';

  @override
  String get settings_log_mode_debug_desc =>
      'DEBUG+ · tout sauf lectures page par page';

  @override
  String get settings_log_mode_extreme => 'Extreme';

  @override
  String get settings_log_mode_extreme_desc =>
      '⚡ TOUT logger – chaque page, segment HLS, événement lecteur';

  @override
  String get settings_scale_default => '100% (défaut)';

  @override
  String settings_percent(Object value) {
    return '$value%';
  }

  @override
  String get reader_show_reading_mode => 'Afficher le mode de lecture';

  @override
  String get reader_show_reading_mode_desc =>
      'Affiche la liste des modes de lecture à l’ouverture du lecteur';

  @override
  String get reader_show_tap_zones =>
      'Afficher les zones tactiles (superposition)';

  @override
  String get reader_show_tap_zones_desc =>
      'Affichage bref à l’ouverture du lecteur';

  @override
  String get reader_load_ahead_wifi => 'Précharger uniquement en Wi-Fi';

  @override
  String get reader_load_ahead_wifi_desc =>
      'Économise les données mobiles en ne chargeant que les pages proches de celle en cours de lecture';

  @override
  String get reader_pages_preload => 'Nombre de pages à précharger';

  @override
  String get reader_pages_preload_desc =>
      'Le nombre de pages à précharger pendant la lecture. Une valeur plus élevée rend la lecture plus fluide, au prix d’un cache plus grand et d’une consommation de données plus importante.';

  @override
  String get reader_section_display => 'Affichage';

  @override
  String get reader_default_rotation => 'Rotation par défaut';

  @override
  String get reader_cutout => 'Utiliser la zone de l’encoche';

  @override
  String get reader_show_page_number => 'Afficher le numéro des pages';

  @override
  String get reader_section_eink => 'E-Ink';

  @override
  String get reader_eink_flash => 'Flash lors du changement de page';

  @override
  String get reader_eink_flash_desc =>
      'Réduire le ghosting sur les écrans e-ink';

  @override
  String get reader_section_reading => 'En cours';

  @override
  String get reader_skip_read => 'Passer les chapitres marqués comme lus';

  @override
  String get reader_skip_filtered => 'Passer les chapitres filtrés';

  @override
  String get reader_skip_duplicate => 'Ignorer les chapitres en double';

  @override
  String get reader_always_transition =>
      'Toujours afficher la transition entre les chapitres';

  @override
  String get reader_section_pages => 'Pages';

  @override
  String get reader_invert_tap_zones => 'Inverser les zones tactiles';

  @override
  String get reader_zoom_start => 'Position du zoom initial';

  @override
  String get reader_panorama => 'Panoramique des images larges';

  @override
  String get reader_split_wide => 'Diviser les pages larges';

  @override
  String get reader_rotate_wide =>
      'Tourner les pages larges pour qu’elles rentrent';

  @override
  String get reader_disable_zoom_out => 'Désactiver le zoom arrière';

  @override
  String get reader_disable_zoom_out_desc =>
      'Le double-clic ne fait plus que zoomer';

  @override
  String get reader_section_continuous => 'Bande continue';

  @override
  String get reader_side_padding => 'Décalage latéral';

  @override
  String get reader_menu_hide_sensitivity =>
      'Sensibilité pour masquer le menu lors du défilement';

  @override
  String get reader_section_navigation => 'Navigation';

  @override
  String get reader_volume_buttons => 'Avec les boutons de volume';

  @override
  String get reader_volume_buttons_desc =>
      'Utilisez ▲/▼ pour tourner les pages';

  @override
  String get reader_invert_volume => 'Inverser les boutons de volume';

  @override
  String get reader_volume_forward =>
      '▲ → page suivante  •  ▼ → page précédente';

  @override
  String get reader_volume_backward =>
      '▲ → page précédente  •  ▼ → page suivante';

  @override
  String get reader_vertical_navigator => 'Navigateur de chapitres vertical';

  @override
  String get reader_section_actions => 'Actions';

  @override
  String get reader_long_press_actions =>
      'Afficher les actions en appuyant longuement';

  @override
  String get reader_save_pages_separate =>
      'Enregistrer les pages dans des dossiers séparés';

  @override
  String get reader_option_free => 'Libre';

  @override
  String get reader_option_portrait => 'Portrait';

  @override
  String get reader_option_landscape => 'Paysage';

  @override
  String get reader_option_auto => 'Automatique';

  @override
  String get reader_option_left => 'Gauche';

  @override
  String get reader_option_right => 'Droite';

  @override
  String get reader_option_center => 'Centre';

  @override
  String get reader_option_none => 'Aucun(e)';

  @override
  String get reader_option_both => 'Les deux';

  @override
  String get reader_option_low => 'Basse';

  @override
  String get reader_option_medium => 'Moyenne';

  @override
  String get reader_option_high => 'Haute';

  @override
  String get settings_general_subtitle =>
      'Langue, DNS, recommandations, Discord';

  @override
  String get settings_display_subtitle =>
      'Thème, couleurs, polices, mode sombre';

  @override
  String get settings_library_subtitle =>
      'Catégories, tri, mises à jour automatiques';

  @override
  String get settings_reader_subtitle =>
      'Lecteur manga : page, zoom, sens de lecture';

  @override
  String get settings_player_subtitle =>
      'Lecteur vidéo : qualité, gestes, sous-titres';

  @override
  String get settings_downloads_subtitle =>
      'Dossier, file d’attente, Wi-Fi uniquement';

  @override
  String get settings_auto_backup => 'Sauvegarde automatique';

  @override
  String get settings_auto_backup_subtitle =>
      'Bibliothèque, réglages et cache — survit à la désinstallation';

  @override
  String get settings_tracking_subtitle =>
      'AniList, MyAnimeList, synchronisation du suivi';

  @override
  String get settings_sync_subtitle => 'Sauvegarde cloud et synchronisation';

  @override
  String get settings_browse_subtitle =>
      'Dépôts d’extensions, sources installées';

  @override
  String get settings_security_subtitle =>
      'Verrouillage, mot de passe, biométrie';

  @override
  String get settings_local_sources => 'Sources Locales';

  @override
  String get settings_local_sources_subtitle =>
      'Importer des fichiers depuis un dossier local';

  @override
  String get settings_advanced_subtitle =>
      'Journalisation, cache, options techniques';

  @override
  String get settings_music_hub => 'Music Hub';

  @override
  String get settings_music_hub_subtitle =>
      'Lecteur audio et bibliothèque musicale';

  @override
  String get settings_remote_connection => 'Connexion Distante';

  @override
  String get settings_remote_connection_subtitle =>
      'Accéder à la bibliothèque depuis un navigateur';

  @override
  String get settings_remote_mode => 'Mode Distant';

  @override
  String get settings_remote_mode_subtitle =>
      'Partager la bibliothèque sur le réseau local';

  @override
  String get settings_about_subtitle => 'Version, crédits, licence';

  @override
  String settings_search_no_results(Object query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get settings_search_results => 'Résultats dans les paramètres';

  @override
  String get downloads_section_per_media => 'Par média';

  @override
  String get downloads_watch_engine_subtitle =>
      'Moteur, connexions, épisodes, fillers';

  @override
  String get downloads_manga_subtitle =>
      'Format d’archive, compression, chapitres';

  @override
  String get downloads_wifi_subtitle => 'Connexions, téléchargements Wi-Fi';

  @override
  String get downloads_simultaneous => 'Téléchargements simultanés (max)';

  @override
  String get downloads_speed_limit => 'Limite de vitesse';

  @override
  String get downloads_disk_write_mode => 'Mode d’écriture disque';

  @override
  String get downloads_cards_gestures => 'Cartes & Gestes';

  @override
  String get downloads_cards => 'Cartes de téléchargement';

  @override
  String get downloads_cards_subtitle =>
      'Boutons affichés et actions de balayage';

  @override
  String get downloads_auto_delete => 'Suppression automatique après lecture';

  @override
  String get downloads_quick_nav => 'Navigation rapide (dock)';

  @override
  String get downloads_dock_history => 'Historique dans le dock';

  @override
  String get downloads_dock_updates => 'Mises à jour dans le dock';

  @override
  String get downloads_folder_structure => 'Folder Structure';

  @override
  String get downloads_delete_folder => 'Supprimer le dossier';

  @override
  String get downloads_watchtower_folders => 'Dossiers Watchtower';

  @override
  String get downloads_allow_access => 'Autoriser l’accès';

  @override
  String get settings_idx_title_dns_over_https => 'DNS over HTTPS';

  @override
  String get settings_idx_title_dns_personnalise => 'DNS personnalisé';

  @override
  String get settings_idx_title_user_agent_par_defaut =>
      'User-Agent par défaut';

  @override
  String get settings_idx_title_discord_rich_presence =>
      'Discord Rich Presence';

  @override
  String get settings_idx_title_afficher_la_progression_discord =>
      'Afficher la progression Discord';

  @override
  String get settings_idx_title_mode_tablette => 'Mode tablette';

  @override
  String get settings_idx_title_durees_relatives => 'Durées relatives';

  @override
  String
  get settings_idx_title_rendre_les_images_dans_les_descriptions_de_mangas =>
      'Rendre les images dans les descriptions de mangas';

  @override
  String get settings_idx_title_mode_sombre_pur => 'Mode sombre pur';

  @override
  String get settings_idx_title_niveau_de_melange_des_couleurs =>
      'Niveau de mélange des couleurs';

  @override
  String get settings_idx_title_reorganiser_la_navigation =>
      'Réorganiser la navigation';

  @override
  String get settings_idx_title_interface_effets => 'Interface & Effets';

  @override
  String get settings_idx_title_categorie_par_defaut => 'Catégorie par défaut';

  @override
  String get settings_idx_title_reglages_de_tri_par_categorie =>
      'Réglages de tri par catégorie';

  @override
  String get settings_idx_title_mises_a_jour_automatiques =>
      'Mises à jour automatiques';

  @override
  String
  get settings_idx_title_restrictions_materielles_pour_les_mises_a_jour =>
      'Restrictions matérielles pour les mises à jour';

  @override
  String get settings_idx_title_categories_des_mises_a_jour_inclure_exclure =>
      'Catégories des mises à jour (inclure / exclure)';

  @override
  String get settings_idx_title_actualiser_automatiquement_les_metadonnees =>
      'Actualiser automatiquement les métadonnées';

  @override
  String
  get settings_idx_title_verifier_sil_y_a_une_nouvelle_couverture_ou_synopsis =>
      'Vérifier s’il y a une nouvelle couverture ou synopsis';

  @override
  String get settings_idx_title_mise_a_jour_intelligente =>
      'Mise à jour intelligente';

  @override
  String get settings_idx_title_afficher_le_nombre_de_chapitres_non_lus =>
      'Afficher le nombre de chapitres non lus';

  @override
  String get settings_idx_title_action_de_glisser_a_gauche =>
      'Action de glisser à gauche';

  @override
  String get settings_idx_title_action_de_glisser_a_droite =>
      'Action de glisser à droite';

  @override
  String get settings_idx_title_marquer_un_chapitre_duplique_comme_lu =>
      'Marquer un chapitre dupliqué comme lu';

  @override
  String get settings_idx_title_masquer_les_indicateurs_de_chapitre_manquants =>
      'Masquer les indicateurs de chapitre manquants';

  @override
  String get settings_idx_title_type_de_mise_a_lechelle =>
      'Type de mise à l’échelle';

  @override
  String get settings_idx_title_garder_lecran_allume => 'Garder l’écran allumé';

  @override
  String get settings_idx_title_navigation_par_boutons_de_volume =>
      'Navigation par boutons de volume';

  @override
  String get settings_idx_page_lecteur_video => 'Lecteur Vidéo';

  @override
  String get settings_idx_title_gestes => 'Gestes';

  @override
  String get settings_idx_title_sous_titres => 'Sous-titres';

  @override
  String get settings_idx_title_editeur_de_scripts => 'Éditeur de scripts';

  @override
  String get settings_idx_title_torrent => 'Torrent';

  @override
  String get settings_idx_title_fichiers_utilisateur => 'Fichiers utilisateur';

  @override
  String get settings_idx_page_sources_locales => 'Sources locales';

  @override
  String get settings_idx_title_sources_locales => 'Sources locales';

  @override
  String get settings_idx_title_dont_kill_my_app => 'Don\'t kill my app!';

  @override
  String get settings_idx_page_mode_distant => 'Mode distant';

  @override
  String get settings_idx_title_mode_distant => 'Mode distant';

  @override
  String get settings_search_hint => 'Rechercher dans les paramètres…';

  @override
  String get downloads_simultaneous_title => 'Téléchargements simultanés';

  @override
  String downloads_simultaneous_subtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements en parallèle',
      one: '$count téléchargement en parallèle',
    );
    return '$_temp0';
  }

  @override
  String get downloads_disabled => 'Désactivée';

  @override
  String get downloads_write_part => '.part + reprise';

  @override
  String get downloads_write_part_desc =>
      'Écrit dans un fichier .part puis renomme à la fin. Reprise automatique après interruption ; le partiel reste lisible.';

  @override
  String get downloads_write_prealloc => 'Pré-allocation';

  @override
  String get downloads_write_prealloc_desc =>
      'Réserve la taille finale du fichier avant de télécharger. Évite la fragmentation sur les gros fichiers.';

  @override
  String get downloads_write_direct => 'Direct';

  @override
  String get downloads_write_direct_desc =>
      'Écrit directement au chemin final (ancien comportement). Risque de fichier corrompu si interruption.';

  @override
  String get downloads_section_deletion => 'Suppression';

  @override
  String get downloads_auto_delete_subtitle =>
      'Supprime le fichier une fois le contenu lu/visionné';

  @override
  String get downloads_allow_bookmarked_delete =>
      'Autoriser la suppression des chapitres marqués';

  @override
  String get downloads_allow_bookmarked_delete_subtitle =>
      'Permet de supprimer les chapitres avec un marque-page';

  @override
  String get downloads_dock_history_subtitle =>
      'Affiche l’onglet Historique dans la barre de navigation';

  @override
  String get downloads_dock_updates_subtitle =>
      'Affiche l’onglet Mises à jour dans la barre de navigation';

  @override
  String get downloads_default_folder => 'Par défaut';

  @override
  String get downloads_storage_unavailable_snack =>
      'Le dossier de téléchargement n’est pas accessible. Vérifiez l’espace de stockage puis réessayez.';

  @override
  String get downloads_no_folder =>
      'Aucun dossier de téléchargement n’est disponible.';

  @override
  String get downloads_folder_prepare_failed =>
      'Impossible de préparer le dossier de téléchargement.';

  @override
  String downloads_file_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '$count fichier',
    );
    return '$_temp0';
  }

  @override
  String get downloads_folder_not_created => 'Dossier non encore créé';

  @override
  String get library_settings_title => 'Bibliothèque';

  @override
  String get library_settings_section_updates => 'Mises à jour';

  @override
  String get library_settings_section_behavior => 'Comportement';

  @override
  String get library_settings_categories_subtitle =>
      'Créer, renommer et supprimer vos catégories';

  @override
  String get library_settings_edit_categories_subtitle =>
      'Réorganiser et affecter les titres';

  @override
  String get library_settings_default_category => 'Catégorie par défaut';

  @override
  String get library_settings_per_category_sort =>
      'Rendre les réglages de tri propres à chaque catégorie';

  @override
  String get library_settings_update_restrictions =>
      'Restrictions matérielles pour les mises à jour automatiques';

  @override
  String get library_settings_restrictions => 'Restrictions';

  @override
  String library_settings_restrictions_summary(Object list) {
    return 'Restrictions : $list';
  }

  @override
  String library_settings_categories_summary(Object exclude, Object include) {
    return 'Inclure : $include\nExclure : $exclude';
  }

  @override
  String get library_settings_auto_refresh_metadata =>
      'Actualiser automatiquement les métadonnées';

  @override
  String get library_settings_check_new_cover =>
      'Vérifier s’il y a une nouvelle couverture ou synopsis lors des mises à jour de la bibliothèque';

  @override
  String get library_settings_unread_badge =>
      'Afficher le nombre de chapitres non lus sur l’icône des mises à jour';

  @override
  String get library_settings_swipe_left => 'Action de glisser à gauche';

  @override
  String get library_settings_swipe_right => 'Action de glisser à droite';

  @override
  String get library_settings_mark_duplicate =>
      'Marquer un chapitre dupliqué comme lu';

  @override
  String get library_settings_hide_missing =>
      'Masquer les indicateurs de chapitre manquants';

  @override
  String get library_settings_include => 'Inclure';

  @override
  String get library_settings_exclude => 'Exclure';

  @override
  String get library_settings_no_category => 'Aucune catégorie.';

  @override
  String get library_settings_everything => 'Tout';

  @override
  String get library_settings_charging_only => 'Uniquement en charge';

  @override
  String get library_settings_manual => 'Manuelle';

  @override
  String get library_settings_every_2_days => 'Tous les 2 jours';

  @override
  String get library_settings_every_2_weeks => 'Toutes les 2 semaines';

  @override
  String get library_settings_every_month => 'Chaque mois';

  @override
  String get library_settings_smart_new_chapters =>
      'Nouveaux chapitres uniquement';

  @override
  String get library_settings_always => 'Toujours';

  @override
  String get library_settings_mark_chapter => 'Marquer le chapitre';

  @override
  String get library_settings_mark_as_read => 'Marquer comme lu';

  @override
  String get library_settings_swipe_none => 'Aucun(e)';

  @override
  String get downloads_watch_title => 'Téléchargements — Watch';

  @override
  String get downloads_novel_title => 'Téléchargements — Roman';

  @override
  String get downloads_music_title => 'Téléchargements — Musique';

  @override
  String get downloads_game_title => 'Téléchargements — Jeu';

  @override
  String get downloads_engine_section => 'Moteur de téléchargement';

  @override
  String get downloads_connections_section => 'Connexions';

  @override
  String get downloads_behavior_section => 'Comportement';

  @override
  String get downloads_hls_connections => 'Connexions HLS simultanées';

  @override
  String get downloads_hls_connections_subtitle =>
      'Segments téléchargés en parallèle par épisode';

  @override
  String get downloads_episodes_queue => 'Épisodes simultanés (file)';

  @override
  String get downloads_episodes_queue_subtitle =>
      'Nombre d’épisodes téléchargés en même temps';

  @override
  String get downloads_wifi_only => 'Wi-Fi uniquement';

  @override
  String get downloads_wifi_only_subtitle => 'Télécharger uniquement via Wi-Fi';

  @override
  String get downloads_new_episodes => 'Télécharger les nouveaux épisodes';

  @override
  String get downloads_new_episodes_subtitle =>
      'Télécharge automatiquement les nouveaux épisodes disponibles';

  @override
  String get downloads_filler => 'Autoriser les épisodes filler';

  @override
  String get downloads_filler_subtitle =>
      'Inclure les épisodes filler dans les téléchargements automatiques';

  @override
  String get downloads_anticipatory => 'Téléchargement anticipé';

  @override
  String get downloads_anticipatory_watch_subtitle =>
      'Pré-télécharge pendant le visionnage si les 2 éps suivants sont disponibles';

  @override
  String get downloads_external_section => 'Téléchargeur externe';

  @override
  String get downloads_always_external =>
      'Toujours utiliser un téléchargeur externe';

  @override
  String get downloads_always_external_subtitle =>
      'Délègue chaque téléchargement à l’app externe choisie ci-dessous';

  @override
  String get downloads_no_app => 'Aucune app sélectionnée';

  @override
  String get downloads_no_app_subtitle =>
      'L’application demandera à chaque téléchargement.';

  @override
  String get downloads_preferred_app => 'App de téléchargement préférée';

  @override
  String get downloads_none_app => 'Aucune';

  @override
  String downloads_test_launch(Object name) {
    return 'Tester (lance $name)';
  }

  @override
  String downloads_launched(Object name) {
    return '$name lancé via intent';
  }

  @override
  String downloads_launch_failed(Object name) {
    return 'Échec du lancement de $name (app installée ?)';
  }

  @override
  String get downloads_official_site => 'Site officiel';

  @override
  String get downloads_ext_adm_desc =>
      'Gestionnaire de téléchargement multi-thread pour Android.';

  @override
  String get downloads_ext_1dm_desc =>
      'Téléchargeur rapide avec support HLS et DASH pour Android.';

  @override
  String get downloads_ext_fdm_desc =>
      'Téléchargeur multiplateforme gratuit et open-source.';

  @override
  String get downloads_ext_idm_desc =>
      'Téléchargeur haute vitesse avec reprise (Windows).';

  @override
  String get downloads_ext_jdownloader_desc =>
      'Téléchargeur open-source multiplateforme très populaire.';

  @override
  String get downloads_ext_motrix_desc =>
      'Téléchargeur Aria2 open-source avec interface moderne.';

  @override
  String get downloads_mode_internal => 'Interne';

  @override
  String get downloads_mode_external => 'Externe';

  @override
  String get downloads_mode_internal_desc =>
      'Téléchargeur HLS intégré à l’application. Idéal pour la majorité des streams.';

  @override
  String get downloads_mode_aria2_desc =>
      'Moteur aria2c haute performance. Connexions multiples et reprise des téléchargements.';

  @override
  String get downloads_mode_external_desc =>
      'Délègue à une app externe (ADM, 1DM, FDM, IDM…). Le téléchargement quitte l’application.';

  @override
  String get downloads_mode_zeus_desc =>
      'Extracteur Python (ZeusDL) pour les pages web : TikTok, Facebook, Instagram… sans filigrane.';

  @override
  String get downloads_manga_engine_note =>
      'Le Manga utilise toujours le téléchargeur interne : les pages d’un chapitre sont récupérées en parallèle automatiquement.';

  @override
  String get downloads_archive_section => 'Format d’archive';

  @override
  String get downloads_compression_section => 'Compression';

  @override
  String get downloads_compression_disabled =>
      'Choisissez un format d’archive pour activer la compression.';

  @override
  String get downloads_compression_none =>
      'Aucune recompression : les pages originales sont conservées, seul le rangement ZIP est appliqué (le plus rapide).';

  @override
  String downloads_compression_level(Object level) {
    return 'Niveau $level/9 · les pages sont ré-encodées en JPEG plus léger puis rangées dans l’archive : fichier plus petit, un peu de qualité en moins.';
  }

  @override
  String get downloads_less_compressed => 'Moins compressé';

  @override
  String get downloads_more_compressed => 'Plus compressé';

  @override
  String get downloads_compression_fast => 'Rapide';

  @override
  String get downloads_compression_light => 'Léger';

  @override
  String get downloads_compression_light_plus => 'Léger +';

  @override
  String get downloads_compression_standard => 'Standard';

  @override
  String get downloads_compression_standard_plus => 'Standard +';

  @override
  String get downloads_compression_strong => 'Fort';

  @override
  String get downloads_compression_strong_plus => 'Fort +';

  @override
  String get downloads_compression_intense => 'Intense';

  @override
  String get downloads_compression_intense_plus => 'Intense +';

  @override
  String get downloads_compression_maximum => 'Maximum';

  @override
  String get downloads_archive_cbz_title => 'Comic Book ZIP';

  @override
  String get downloads_archive_cbz_subtitle =>
      'Le plus compatible · images ZIP';

  @override
  String get downloads_archive_cbr_title => 'Comic Book RAR';

  @override
  String get downloads_archive_cbr_subtitle =>
      'Conteneur CBR · lisible partout';

  @override
  String get downloads_archive_cb7_title => 'Comic Book 7-Zip';

  @override
  String get downloads_archive_cb7_subtitle => 'Conteneur CB7 · très compressé';

  @override
  String get downloads_archive_zip_title => 'ZIP standard';

  @override
  String get downloads_archive_zip_subtitle => 'Archive ZIP brute';

  @override
  String get downloads_archive_folder_title => 'Dossier d’images';

  @override
  String get downloads_archive_folder_subtitle =>
      'Aucune archive · accès direct';

  @override
  String get downloads_manga_new_chapters =>
      'Télécharger les nouveaux chapitres';

  @override
  String get downloads_manga_new_chapters_subtitle =>
      'Télécharge automatiquement les nouveaux chapitres disponibles';

  @override
  String get downloads_anticipatory_read => 'Téléchargement anticipé (lecture)';

  @override
  String get downloads_anticipatory_read_subtitle =>
      'Pré-télécharge si le chapitre actuel et le suivant sont déjà présents';

  @override
  String get downloads_delete_after_read => 'Supprimer après lecture';

  @override
  String get downloads_delete_after_read_subtitle =>
      'Supprime le chapitre dès qu’il est marqué comme lu';

  @override
  String get downloads_delete_marked => 'Supprimer même les chapitres marqués';

  @override
  String get downloads_delete_marked_subtitle =>
      'La suppression automatique s’applique aussi aux chapitres avec marque-page';

  @override
  String get downloads_novel_note =>
      'Le Roman utilise le téléchargeur interne via l’extension source. Les chapitres sont sauvegardés en HTML et regroupés par titre.';

  @override
  String get downloads_music_note =>
      'La Musique utilise le téléchargeur interne via l’extension source.';

  @override
  String get downloads_game_note =>
      'Le Jeu utilise le téléchargeur interne via l’extension source.';

  @override
  String get downloads_connections_simultaneous => 'Connexions simultanées';

  @override
  String get downloads_connections_per_chapter =>
      'Connexions parallèles par chapitre';

  @override
  String get downloads_connections_per_download =>
      'Connexions parallèles par téléchargement';

  @override
  String get downloads_chapters_queue => 'Chapitres simultanés (file)';

  @override
  String get downloads_chapters_queue_subtitle =>
      'Nombre de chapitres téléchargés en même temps';

  @override
  String get downloads_items_queue => 'Téléchargements simultanés (file)';

  @override
  String get downloads_items_queue_subtitle =>
      'Nombre d’éléments téléchargés en même temps';

  @override
  String get downloads_cards_buttons_section =>
      'Boutons des cartes de téléchargement';

  @override
  String get downloads_cards_buttons_subtitle =>
      'Choisissez les boutons affichés sur chaque carte de téléchargement.';

  @override
  String get downloads_card_preview => 'Aperçu de la carte';

  @override
  String get downloads_swipe_subtitle =>
      'Action déclenchée en balayant une carte à gauche ou à droite.';

  @override
  String get downloads_swipe_left => 'Balayer à gauche';

  @override
  String get downloads_swipe_right => 'Balayer à droite';

  @override
  String get downloads_no_buttons =>
      'Aucun bouton affiché — balayez pour agir.';

  @override
  String get downloads_storage_format => 'Format de stockage';

  @override
  String get downloads_archive_folder_desc =>
      'Pages vérifiées, conservées dans un dossier.';

  @override
  String get downloads_archive_cbz_desc =>
      'Archive créée après validation de toutes les pages.';

  @override
  String get downloads_archive_zip_desc =>
      'Archive ZIP créée après validation des pages.';

  @override
  String get downloads_archive_unsupported =>
      'Format non pris en charge : un CBZ sera produit.';

  @override
  String get downloads_archive_label_folder => 'Dossier (images)';

  @override
  String get downloads_swipe_pause_resume => 'Pause / Reprendre';

  @override
  String get downloads_swipe_cancel => 'Annuler';

  @override
  String get downloads_swipe_delete => 'Supprimer';

  @override
  String get downloads_swipe_retry => 'Réessayer';

  @override
  String get downloads_swipe_disabled => 'Désactivé';

  @override
  String get downloads_open_folder => 'Ouvrir dossier';

  @override
  String get downloads_swipe_section => 'Actions de balayage';

  @override
  String get queue_title => 'Téléchargements';

  @override
  String get queue_load_error =>
      'Impossible de charger la file de téléchargement.';

  @override
  String queue_unfinished(Object count) {
    return 'Non terminés ($count)';
  }

  @override
  String get queue_manage => 'Gérer';

  @override
  String get queue_empty_watch => 'Aucun téléchargement Watch';

  @override
  String get queue_empty_manga => 'Aucun téléchargement Manga';

  @override
  String get queue_empty_novel => 'Aucun téléchargement Novel';

  @override
  String get queue_empty_music => 'Aucun téléchargement Musique';

  @override
  String get queue_empty_game => 'Aucun téléchargement Jeu';

  @override
  String get queue_download_canceled => 'Téléchargement annulé.';

  @override
  String get queue_chapter_not_found => 'Chapitre introuvable.';

  @override
  String get queue_manage_downloads => 'Gérer les téléchargements';

  @override
  String queue_settings_for(Object name) {
    return 'Paramètres $name';
  }

  @override
  String get queue_act_on_all => 'Agir sur toute la file d’attente';

  @override
  String get queue_stop => 'Arrêter';

  @override
  String get queue_simultaneous => 'Simultanés';

  @override
  String get queue_simultaneous_help =>
      'Nombre de téléchargements parallèles par type et par source';

  @override
  String get queue_density_help =>
      'Densité d’affichage des éléments de la file';

  @override
  String get queue_background => 'Arrière-plan';

  @override
  String get queue_continue_closed => 'Continuer même app fermée';

  @override
  String get queue_background_enabled =>
      'Téléchargement en arrière-plan activé';

  @override
  String get queue_clear_completed => 'Effacer les terminés';

  @override
  String get queue_clear_completed_subtitle =>
      'Retirer de la file les éléments finis';

  @override
  String get queue_completed_removed => 'Terminés supprimés de la file';

  @override
  String queue_simultaneous_for(Object name) {
    return 'Téléchargements parallèles pour $name';
  }

  @override
  String get queue_connections => 'Connexions';

  @override
  String get queue_connections_help =>
      'Connexions parallèles par unité téléchargée';

  @override
  String get queue_segments_per_episode => 'Segments HLS par épisode';

  @override
  String get queue_connections_per_chapter => 'Connexions par chapitre';

  @override
  String queue_params_for(Object name) {
    return 'Paramètres $name';
  }

  @override
  String get queue_delete_series => 'Supprimer la série';

  @override
  String get queue_resume_series => 'Reprendre la série';

  @override
  String get queue_pause_series => 'Pause série';

  @override
  String get queue_pause_series_full => 'Mettre la série en pause';

  @override
  String get queue_hide => 'Masquer';

  @override
  String get queue_challenge_resolved =>
      'Challenge résolu — reprise du téléchargement';

  @override
  String get queue_priority_high => 'Priorité haute activée';

  @override
  String get queue_priority_normal => 'Priorité normale';

  @override
  String get queue_status_completed => 'Terminé';

  @override
  String get queue_status_failed => 'Échec';

  @override
  String get queue_status_canceled => 'Annulé';

  @override
  String get queue_unit_chapter => 'Chapitre';

  @override
  String get queue_unit_episodes => 'épisodes';

  @override
  String get queue_unit_chapters => 'chapitres';

  @override
  String get queue_download_finished => 'Téléchargement terminé';

  @override
  String queue_received(Object size) {
    return '$size reçus';
  }

  @override
  String get queue_transfer => 'Téléchargement';

  @override
  String get queue_quick_actions => 'Actions rapides';

  @override
  String get queue_start => 'Lancer';

  @override
  String get queue_retry => 'Réessayer';

  @override
  String get queue_layout => 'Disposition';

  @override
  String get queue_status_muxing => 'Assemblage';

  @override
  String get queue_status_compressing => 'Compression';

  @override
  String get queue_status_paused => 'En pause';

  @override
  String get queue_status_waiting => 'En attente';

  @override
  String queue_cloudflare_challenge(Object source) {
    return 'Challenge Cloudflare — $source';
  }

  @override
  String get queue_resume => 'Reprendre';

  @override
  String get queue_pause => 'Pause';

  @override
  String get appearance_ui_title => 'Interface & Effets';

  @override
  String get appearance_ui_section_ui => 'UI & DÉCOUVERTE';

  @override
  String get appearance_ui_carousel_style => 'Style Carousel';

  @override
  String get appearance_ui_carousel_synopsis => 'Synopsis dans le Carousel';

  @override
  String get appearance_ui_carousel_synopsis_subtitle =>
      'Afficher la description sous la bannière';

  @override
  String get appearance_ui_glow => 'Effets de Lueur';

  @override
  String get appearance_ui_glow_subtitle =>
      'Ombres lumineuses sur les couvertures';

  @override
  String get appearance_ui_animated_bg => 'Fond animé (détail)';

  @override
  String get appearance_ui_animated_bg_subtitle =>
      'Effet Ken Burns sur les bannières de la fiche';

  @override
  String get appearance_ui_petals => 'Fleurs qui tombent';

  @override
  String get appearance_ui_petals_subtitle =>
      'Animation florale discrète sur les écrans';

  @override
  String get appearance_ui_section_blur => 'FLOU & VERRE';

  @override
  String get appearance_ui_frosted_header => 'En-tête givré';

  @override
  String get appearance_ui_frosted_header_subtitle =>
      'Flou de l’en-tête pendant le défilement';

  @override
  String get appearance_ui_frosted_sheets => 'Feuilles givrées';

  @override
  String get appearance_ui_frosted_sheets_subtitle =>
      'Flou du fond derrière les bottom sheets';

  @override
  String get appearance_ui_blur_intensity => 'Intensité du flou';

  @override
  String get appearance_ui_section_transitions => 'TRANSITIONS & ANIMATIONS';

  @override
  String get appearance_ui_transition_style => 'Style de transition';

  @override
  String get appearance_ui_carousel_classic => 'Classique';

  @override
  String get appearance_ui_carousel_cinematic => 'Cinématique';

  @override
  String get appearance_ui_carousel_compact => 'Compact';

  @override
  String get appearance_ui_transition_fade => 'Fondu';

  @override
  String get appearance_ui_transition_slide => 'Glissement';

  @override
  String get appearance_ui_transition_scale => 'Échelle';

  @override
  String get appearance_ui_transition_none => 'Aucun';

  @override
  String get appearance_display_title => 'Affichage';

  @override
  String get appearance_display_system_default => 'Système (par défaut)';

  @override
  String get appearance_display_date_format => 'Format de date';

  @override
  String get appearance_display_relative_times => 'Durées relatives';

  @override
  String get appearance_display_render_images =>
      'Rendre les images dans les descriptions de mangas';

  @override
  String get appearance_font_picker => 'Police';

  @override
  String get appearance_font_search => 'Rechercher une police…';

  @override
  String get app_language_title => 'Langue de l’application';

  @override
  String get nav_home => 'Accueil';

  @override
  String get general_section_network => 'Réseau';

  @override
  String get general_disabled => 'Désactivé';

  @override
  String get general_close => 'Fermer';

  @override
  String get general_section_recommendations => 'Recommandations';

  @override
  String get general_recommendations_subtitle =>
      'Algorithme, similarité et poids de pertinence';

  @override
  String get general_section_activity => 'Activité';

  @override
  String get general_system_default => 'Système par défaut';

  @override
  String get general_doh_subtitle =>
      'Chiffre vos requêtes DNS pour empêcher votre opérateur ou réseau de voir les sites que vous visitez.';

  @override
  String get general_user_agent_hint =>
      'Ouvre le site, copie ton User Agent, puis colle-le ci-dessus.';

  @override
  String get player_gestures_subtitle => 'Chercher, double tap, contrôles';

  @override
  String get player_subtitles_subtitle =>
      'Langues préférées, liste blanche, liste noire';

  @override
  String get player_script_editor_subtitle =>
      'Modifier et créer de nouveaux scripts et options de script';

  @override
  String get player_torrent_subtitle => 'TorrServer options';

  @override
  String get player_user_files_subtitle =>
      'Scripts, shaders et polices personnalisés';

  @override
  String get player_script_editor_title => 'Éditeur de scripts';

  @override
  String get player_gestures_title => 'Gestes';

  @override
  String get player_double_tap_seek => 'Chercher par double-clic';

  @override
  String get player_double_tap_seek_subtitle =>
      'Avance ou recule dans la vidéo en double-cliquant sur les côtés';

  @override
  String get player_double_tap_duration => 'Durée du double-clic';

  @override
  String player_seconds(Object count) {
    return '$count secondes';
  }

  @override
  String get player_swipe_gestures => 'Gestes de balayage';

  @override
  String get player_swipe_gestures_subtitle =>
      'Balayage horizontal pour chercher, vertical pour le volume et la luminosité';

  @override
  String get player_gesture_overlay => 'Superposition des gestes';

  @override
  String get player_gesture_overlay_subtitle =>
      'Affiche un aperçu pendant un geste';

  @override
  String get player_center_double_tap =>
      'Double-clic au centre pour lecture/pause';

  @override
  String get player_subtitles_title => 'Sous-titres';

  @override
  String get player_preferred_languages => 'Langues préférées';

  @override
  String get player_whitelist => 'Liste blanche';

  @override
  String get player_whitelist_hint => 'Filtres à conserver';

  @override
  String get player_blacklist => 'Liste noire';

  @override
  String get player_blacklist_hint => 'Filtres à masquer';

  @override
  String get player_subtitle_text_size => 'Taille du texte';

  @override
  String get player_custom_buttons => 'Boutons personnalisés';

  @override
  String get player_custom_buttons_subtitle =>
      'Créer et modifier des boutons exécutant du code lua';

  @override
  String get player_load_user_files => 'Charger les fichiers utilisateur';

  @override
  String get player_load_user_files_subtitle =>
      'Exécute les scripts mpv placés dans le dossier utilisateur';

  @override
  String get player_scripts_folder => 'Dossier des scripts';

  @override
  String get player_not_defined => 'Non défini';

  @override
  String get player_not_configured => 'Non configuré';

  @override
  String get player_resume_last_position => 'Reprendre à la dernière position';

  @override
  String get player_resume_last_position_subtitle =>
      'Reprend la lecture là où elle s’est arrêtée';

  @override
  String get player_ask_next_episode => 'Demander l’épisode suivant';

  @override
  String get player_ask_next_episode_subtitle =>
      'Affiche une invite à la fin d’un épisode';

  @override
  String get player_lock_landscape =>
      'Verrouille l’orientation en paysage pendant la lecture';

  @override
  String get player_decoder_mode => 'Mode de décodage';

  @override
  String get player_debanding => 'Désentrelacement';

  @override
  String get player_debanding_subtitle => 'Améliore les vidéos entrelacées';

  @override
  String get player_torrent_prebuffer =>
      'Démarre la lecture dès que suffisamment de morceaux sont disponibles';

  @override
  String get player_keep_audio_channels => 'Conserver les canaux audio';

  @override
  String get player_keep_audio_channels_subtitle =>
      'Ne pas réduire le mixage au stéréo';

  @override
  String get player_load_user_assets =>
      'Charger les scripts, shaders et polices du dossier utilisateur';

  @override
  String get player_orientation_landscape => 'Orientation paysage';

  @override
  String get player_decoder_auto => 'Automatique';

  @override
  String get player_decoder_hw => 'Décodage matériel';

  @override
  String get player_decoder_sw => 'Décodage logiciel';

  @override
  String get settings_search_in_settings => 'Rechercher dans les paramètres…';

  @override
  String get settings_search_tooltip => 'Rechercher';

  @override
  String get settings_close_search => 'Fermer la recherche';

  @override
  String get settings_extensions_display => 'Affichage des extensions';

  @override
  String get settings_layout_list => 'Liste';

  @override
  String get settings_layout_grid => 'Grille';

  @override
  String get settings_layout_extended => 'Étendu';

  @override
  String get settings_remote_server => 'Serveur distant';

  @override
  String get settings_remote_server_subtitle =>
      'Connecter votre appareil pour synchroniser la bibliothèque';

  @override
  String get media_filters_title => 'Filtres';

  @override
  String media_filters_active(Object count) {
    return 'Filtres · $count actif(s)';
  }

  @override
  String get media_clear_filters => 'Retirer les filtres';

  @override
  String get media_apply => 'Appliquer';

  @override
  String get media_done => 'Terminé';

  @override
  String get media_display_mode => 'Mode d\'affichage';

  @override
  String get media_items_per_row => 'Éléments par ligne';

  @override
  String get media_columns_count => 'Nombre de colonnes';

  @override
  String media_columns_n(Object count) {
    return '$count colonnes';
  }

  @override
  String get media_columns_one => '1 colonne';

  @override
  String get media_automatic => 'Automatique';

  @override
  String get media_years => 'Années';

  @override
  String get media_all_years => 'Toutes les années';

  @override
  String get media_genres => 'Genres';

  @override
  String get media_rating => 'Note';

  @override
  String get media_sort => 'Ordre';

  @override
  String get media_search_option => 'Rechercher une option…';

  @override
  String get media_search_page => 'Rechercher dans cette page…';

  @override
  String get media_all => 'Tous';

  @override
  String get media_all_durations => 'Toutes les durées';

  @override
  String get media_all_languages => 'Toutes les langues';

  @override
  String get media_all_qualities => 'Qualité (toutes)';

  @override
  String get media_language => 'Langue';

  @override
  String get media_upper => 'Supérieure';

  @override
  String get media_lower => 'Inférieure';

  @override
  String get media_deselect_all => 'Tout décocher';

  @override
  String get media_download_all => 'Tout télécharger';

  @override
  String media_download_count(Object count) {
    return 'Télécharger $count élément(s)';
  }

  @override
  String media_download_selection(Object count) {
    return 'Télécharger la sélection ($count)';
  }

  @override
  String get media_custom_download => 'Téléchargement personnalisé';

  @override
  String get media_item_count => 'Nombre d\'éléments';

  @override
  String get media_enter_positive => 'Entre un nombre supérieur à zéro.';

  @override
  String get media_nothing_downloadable => 'Aucun élément téléchargeable.';

  @override
  String get media_no_selection => 'Aucune vidéo sélectionnée.';

  @override
  String media_episodes_count(Object count) {
    return '$count épisodes';
  }

  @override
  String get media_episode => 'Épisode';

  @override
  String media_episode_n(Object number) {
    return 'Épisode $number';
  }

  @override
  String media_ep_short(Object number) {
    return 'Ép. $number';
  }

  @override
  String get media_season => 'Saison';

  @override
  String get media_series => 'Série';

  @override
  String get media_tv_movie => 'Téléfilm';

  @override
  String get media_reality => 'Téléréalité';

  @override
  String get media_top_rated => 'Mieux notés';

  @override
  String get media_new_releases => 'Nouveautés';

  @override
  String get media_most_popular => 'Les plus populaires';

  @override
  String get media_top_10_week => 'Top 10 cette semaine';

  @override
  String get media_discover => 'À découvrir';

  @override
  String get media_watch_this_week => 'À voir cette semaine';

  @override
  String get media_watch_tonight => 'À voir ce soir';

  @override
  String get media_categories => 'Catégories';

  @override
  String get media_no_result => 'Aucun résultat';

  @override
  String get media_no_result_filters => 'Aucun résultat pour ces filtres';

  @override
  String get media_load_failed =>
      'Impossible de charger \$title pour le moment.';

  @override
  String get media_no_summary => 'Aucun résumé disponible.';

  @override
  String get media_no_synopsis => 'Aucun synopsis disponible.';

  @override
  String get media_no_similar => 'Aucun titre similaire disponible.';

  @override
  String get media_no_wallpaper => 'Aucun wallpaper disponible.';

  @override
  String get media_no_episode => 'Aucun épisode disponible.';

  @override
  String get media_no_comments => 'Aucun commentaire pour le moment.';

  @override
  String get media_comments_load_failed =>
      'Impossible de charger les commentaires.';

  @override
  String get media_episodes_load_failed =>
      'Impossible de charger les épisodes.';

  @override
  String get media_people_load_failed =>
      'Impossible de charger la distribution.';

  @override
  String get media_details => 'Détails';

  @override
  String get media_details_unavailable => 'Détails indisponibles.';

  @override
  String get media_duration => 'Durée';

  @override
  String get media_episode_duration => 'Durée épisode';

  @override
  String get media_release_date => 'Date de sortie';

  @override
  String get media_first_air_date => 'Première diffusion';

  @override
  String get media_last_episode => 'Dernier épisode';

  @override
  String get media_original_language => 'Langue originale';

  @override
  String get media_spoken_languages => 'Langues parlées';

  @override
  String get media_networks => 'Réseaux';

  @override
  String get media_created_by => 'Créé par';

  @override
  String get media_where_to_watch => 'Où regarder';

  @override
  String get media_popularity => 'Popularité';

  @override
  String get media_add_to_list => 'Ajouter à ma liste';

  @override
  String get media_watch_series => 'Voir la série';

  @override
  String get media_watch_episodes => 'Voir les épisodes';

  @override
  String get media_watch_season => 'Voir la saison';

  @override
  String get media_view_all_languages => 'Voir toutes les langues';

  @override
  String get media_retry => 'Réessayer';

  @override
  String get media_loading_failed_retry => 'Chargement échoué · Réessayer';

  @override
  String get media_prev_chapter => 'Chapitre précédent';

  @override
  String get media_next_chapter => 'Chapitre suivant';

  @override
  String get media_next_episode => 'Prochain épisode';

  @override
  String get media_new_chapter => 'Nouveau chapitre';

  @override
  String get media_next_chapter_soon => 'Prochain chapitre';

  @override
  String get media_latest_releases => 'Dernières sorties';

  @override
  String get media_release_calendar => 'Calendrier des sorties';

  @override
  String get media_recent_results => 'Résultats récents';

  @override
  String get media_resume_reading => 'Reprendre la lecture';

  @override
  String get media_quick_access => 'Accès rapide';

  @override
  String get media_reader_settings => 'Réglages du reader';

  @override
  String get media_brightness => 'Luminosité';

  @override
  String get media_volumes_preview => 'Aperçu des volumes';

  @override
  String get media_upcoming_volumes => 'Volumes à venir';

  @override
  String get media_other_works => 'Autres œuvres de l’univers';

  @override
  String get media_editions_by_language => 'Éditions par langue';

  @override
  String get media_universe_by_country => 'Univers par pays / langue';

  @override
  String get media_trailers => 'Trailers et vidéos';

  @override
  String get media_video => 'Vidéo';

  @override
  String get media_soon => 'Bientôt';

  @override
  String get media_tv => 'Téléfilm';

  @override
  String get media_announced => 'Prévue';

  @override
  String get media_cancelled => 'Annulée';

  @override
  String get media_completed => 'Terminée';

  @override
  String get media_dropped => 'Abandonné';

  @override
  String get media_status_ongoing => 'En cours';

  @override
  String get media_available_channels => 'Chaînes disponibles';

  @override
  String get media_open_channel_failed => 'Impossible d’ouvrir la chaîne';

  @override
  String get media_world_channels =>
      'Accédez aux pages officielles des chaînes depuis Watchtower.';

  @override
  String get media_world_content => 'Explorez des contenus du monde entier.';

  @override
  String get media_european_news => 'Actualités européennes';

  @override
  String get media_international_news => 'Actualités internationales';

  @override
  String get media_no_network => 'Aucune connexion réseau';

  @override
  String get media_connect_internet =>
      'Connectez-vous à Internet pour charger \$title.';

  @override
  String get media_check_connection =>
      'Vérifiez votre Wi-Fi ou vos données mobiles.';

  @override
  String get media_catalog_load_failed =>
      'Impossible de charger le catalogue. Réessayez plus tard.';

  @override
  String get media_hub_unavailable => '\$title est temporairement indisponible';

  @override
  String get media_refine_with_tags => 'Affinez vos recherches avec les tags.';

  @override
  String get media_find_favourite_genres => 'Retrouve tes genres préférés.';

  @override
  String get media_personalise_reading =>
      'Personnalise ton expérience de lecture.';

  @override
  String get media_resume_where_left => 'Reprends là où tu t’es arrêté.';

  @override
  String get media_official_manga =>
      'Manga officiel disponible sur les plateformes légales.';

  @override
  String get media_no_badge => 'Aucun badge publié par cette source.';

  @override
  String get media_remind_me => 'Me le rappeler';

  @override
  String get media_computing_size => 'Calcul du poids…';

  @override
  String get media_fetching_formats => 'Récupération des formats…';

  @override
  String get media_background => 'Arrière-plan';

  @override
  String get media_collapse => 'Réduire';

  @override
  String get media_expand => 'Développer';

  @override
  String media_videos_processed(Object done, Object total) {
    return '$done/$total vidéos traitées';
  }

  @override
  String media_videos_selected(Object size, Object total) {
    return '$total vidéos · $size';
  }

  @override
  String get media_selection_mode => 'Sélection multiple';

  @override
  String get media_finish_selection => 'Terminer la sélection';

  @override
  String get media_quality_all => 'Qualité (toutes)';

  @override
  String get media_language_all => 'Langue (toutes)';

  @override
  String get media_in_5_min => 'Dans 5 min';

  @override
  String get media_quick_summary => 'Résumé rapide';

  @override
  String get media_summary => 'Résumé';

  @override
  String get media_creator => 'Réalisateur :';

  @override
  String get media_read_direction => 'Sens de lecture des planches.';

  @override
  String get media_official_badge => 'SÉRIE';

  @override
  String get media_recent => 'Récents';

  @override
  String get media_bulk_download => 'Télécharger';

  @override
  String media_show_more(Object count) {
    return 'Afficher plus ($count restantes)';
  }

  @override
  String get media_comment_video => 'Vidéo du commentaire';

  @override
  String media_replies(Object count) {
    return '$count réponse';
  }

  @override
  String media_videos_count(Object count) {
    return '$count vidéos';
  }

  @override
  String media_elements_count(Object count) {
    return '$count éléments';
  }

  @override
  String media_element_n(Object number) {
    return 'Élément $number';
  }

  @override
  String get media_queue_added => 'Téléchargements ajoutés à la file : ';

  @override
  String media_queue_cancelled(Object queued) {
    return 'Annulé · $queued ajouté(s), ';
  }

  @override
  String media_queue_failed(Object failed, Object remaining) {
    return '$failed échec(s), $remaining restant(s).';
  }

  @override
  String get media_series_suffix => 'séries';

  @override
  String get media_february => 'février';

  @override
  String get media_august => 'août';

  @override
  String get media_december => 'décembre';

  @override
  String get media_comedy => 'Comédie';

  @override
  String get media_already_downloaded_hidden => 'déjà téléchargé(s) masqué(s)';

  @override
  String get media_first_card => 'première carte';

  @override
  String get media_censored_hint =>
      'Indique si la vidéo est censurée, non censurée ou fuie.';

  @override
  String get media_audio_language_hint => 'Langue de la vidéo';

  @override
  String get media_country_flag_hint =>
      'Drapeau du pays associé à la langue publiée.';

  @override
  String get media_subtitle_flag_hint =>
      'Drapeau de la langue des sous-titres disponibles.';

  @override
  String get media_dub_flag_hint =>
      'Drapeau de la langue du doublage disponible.';

  @override
  String get media_platforms => 'Voir les plateformes';

  @override
  String get media_stats => 'Voir les statistiques';

  @override
  String get media_teams => 'Voir toutes les équipes';

  @override
  String get media_collection => 'Voir la collection';

  @override
  String get media_list => 'Voir la liste';

  @override
  String get media_more_like => 'Top 20 séries comme Superman…';

  @override
  String get media_all_chapters => 'Tous les chapitres';

  @override
  String media_episode_count(Object count) {
    return '$count épisodes';
  }

  @override
  String get media_episodes => 'Épisodes';

  @override
  String get media_grid_comfortable => 'Grille espacée';

  @override
  String get media_grid_compact => 'Grille compacte';

  @override
  String get media_grid_cover_only => 'Grille avec seulement la couverture';

  @override
  String get media_download_nb => 'Télécharger nb';

  @override
  String get media_badge_language => 'Langue de la vidéo';

  @override
  String get media_download_failed => 'Échec du téléchargement';

  @override
  String get media_classic => 'Classique';

  @override
  String get media_type => 'Type';

  @override
  String get media_text_filter_hint => 'Saisir…';

  @override
  String get media_love_shows => 'Shows d\'amour';

  @override
  String get media_talk_shows => 'Talk-shows';

  @override
  String get media_extension_only =>
      'Téléchargement disponible uniquement pour les catalogues d’extension.';

  @override
  String get media_status_paused => 'En pause';

  @override
  String media_queue_queued(Object count) {
    return '$count téléchargement(s) mis en file, ';
  }

  @override
  String media_queue_failed_short(Object count) {
    return '$count échec(s)';
  }

  @override
  String get media_anime => 'Anime';

  @override
  String get media_manga => 'Manga';

  @override
  String get media_movie => 'Film';

  @override
  String get media_animation => 'Animation';

  @override
  String get media_documentary => 'Documentaire';

  @override
  String get media_popular => 'Populaire';

  @override
  String get media_trending => 'Tendance';

  @override
  String get media_favorites => 'Favoris';

  @override
  String get media_a_z => 'A — Z';

  @override
  String get media_options => 'Options';

  @override
  String get media_selection => 'Sélection';
}
