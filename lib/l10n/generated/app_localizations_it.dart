// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get library => 'Biblioteca';

  @override
  String get updates => 'Aggiornamenti';

  @override
  String get history => 'Cronologia';

  @override
  String get browse => 'Sfoglia';

  @override
  String get more => 'Altro';

  @override
  String get open_random_entry => 'Apri voce casuale';

  @override
  String get import => 'Importa';

  @override
  String get filter => 'Filtro';

  @override
  String get ignore_filters => 'Ignora filtri';

  @override
  String get downloaded => 'Scaricato';

  @override
  String get unread => 'Non letto';

  @override
  String get unwatched => 'Non guardato';

  @override
  String get started => 'Iniziato';

  @override
  String get bookmarked => 'Segnalibro';

  @override
  String get sort => 'Ordina';

  @override
  String get alphabetically => 'Alfabeticamente';

  @override
  String get last_read => 'Ultima lettura';

  @override
  String get last_watched => 'Ultima visione';

  @override
  String get last_update_check => 'Ultimo controllo aggiornamenti';

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
          'Stai eliminando tutti e $count $entryTypePlural di questo $mediaType dalla tua libreria.',
      one:
          'Stai eliminando l’unico $entryType di questo $mediaType dalla tua libreria.',
    );
    return '$_temp0\nQuesto rimuoverà anche tutto il $mediaType dalla tua libreria.\n\nNota: I file non saranno eliminati.';
  }

  @override
  String get chapter => 'capitolo';

  @override
  String get episode => 'episodio';

  @override
  String get unread_count => 'Conteggio non letti';

  @override
  String get unwatched_count => 'Conteggio non guardati';

  @override
  String get latest_chapter => 'Ultimo capitolo';

  @override
  String get latest_episode => 'Ultimo episodio';

  @override
  String get date_added => 'Data aggiunta';

  @override
  String get display => 'Visualizza';

  @override
  String get display_mode => 'Modalità visualizzazione';

  @override
  String get compact_grid => 'Griglia compatta';

  @override
  String get compression_level => 'Livello di compressione';

  @override
  String compression_info(Object level) {
    return 'Maggiore è la compressione, minore sarà lo spazio occupato dal backup, ma richiederà più CPU. Predefinito: $level';
  }

  @override
  String get comfortable_grid => 'Griglia confortevole';

  @override
  String get cover_only_grid => 'Griglia solo copertina';

  @override
  String get list => 'Lista';

  @override
  String get badges => 'Distintivi';

  @override
  String get downloaded_chapters => 'Capitoli scaricati';

  @override
  String get downloaded_episodes => 'Episodi scaricati';

  @override
  String get language => 'Lingua';

  @override
  String get local_source => 'Fonte locale';

  @override
  String get overlay => 'Overlay';

  @override
  String get show_unread_chapters => 'Unread chapters';

  @override
  String get random => 'Random';

  @override
  String get release_date => 'Release date';

  @override
  String get folder_name => 'Folder name';

  @override
  String get chapter_fetch_date => 'Chapter fetch date';

  @override
  String get nsfw_only => 'R18';

  @override
  String get tabs => 'Schede';

  @override
  String get show_category_tabs => 'Mostra schede categoria';

  @override
  String get show_numbers_of_items => 'Mostra numeri degli elementi';

  @override
  String get other => 'Altro';

  @override
  String get show_continue_reading_buttons =>
      'Mostra pulsanti di lettura continua';

  @override
  String get show_continue_watching_buttons =>
      'Mostra pulsanti continua a guardare';

  @override
  String get empty_library => 'Biblioteca vuota';

  @override
  String get search => 'Cerca...';

  @override
  String get no_recent_updates => 'Nessun aggiornamento recente';

  @override
  String get remove_everything => 'Rimuovi tutto';

  @override
  String get remove_everything_msg =>
      'Sei sicuro? Tutta la cronologia sarà persa';

  @override
  String get remove_all_update_msg =>
      'Sei sicuro? L\'intero aggiornamento verrà eliminato';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annulla';

  @override
  String get remove => 'Rimuovi';

  @override
  String get remove_history_msg =>
      'Questo rimuoverà la data di lettura di questo capitolo. Sei sicuro?';

  @override
  String get last_used => 'Ultimo usato';

  @override
  String get pinned => 'Fissato';

  @override
  String get sources => 'Fonti';

  @override
  String get install => 'Installa';

  @override
  String get update => 'Aggiorna';

  @override
  String get latest => 'Più recente';

  @override
  String get extensions => 'Estensioni';

  @override
  String get migrate => 'Migra';

  @override
  String get mass_migration_title => 'Migrazione di massa';

  @override
  String get mass_migration_preview_items => 'Anteprima elementi';

  @override
  String get mass_migration_destination_source => 'Fonte di destinazione';

  @override
  String get mass_migration_no_library_items =>
      'Nessun elemento della libreria disponibile per la migrazione di massa.';

  @override
  String get mass_migration_no_destination_sources =>
      'Nessuna fonte di destinazione installata disponibile.';

  @override
  String get mass_migration_installed => 'Installato';

  @override
  String mass_migration_items_ready_for_review(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi pronti per la revisione',
      one: '1 elemento pronto per la revisione',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_item_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_select_destination_source =>
      'Seleziona fonte di destinazione';

  @override
  String mass_migration_finding_matches(Object source, Object language) {
    return 'Ricerca corrispondenze in $source • $language';
  }

  @override
  String mass_migration_processing_item(int current, int total) {
    return 'Elaborazione elemento $current di $total';
  }

  @override
  String get mass_migration_waiting_next_item =>
      'Attesa di 2 secondi prima del prossimo elemento...';

  @override
  String get mass_migration_waiting_next_migration =>
      'Attesa di 2 secondi prima della prossima migrazione...';

  @override
  String mass_migration_matched_so_far(int count) {
    return 'Corrispondenze trovate finora: $count';
  }

  @override
  String mass_migration_no_match_count(int count) {
    return 'Nessuna corrispondenza: $count';
  }

  @override
  String mass_migration_review_matches(Object source) {
    return 'Rivedi corrispondenze per $source';
  }

  @override
  String mass_migration_found_matches(int count) {
    return 'Corrispondenze trovate: $count';
  }

  @override
  String mass_migration_no_matches(int count) {
    return 'Nessuna corrispondenza: $count';
  }

  @override
  String mass_migration_selected_to_migrate(int count) {
    return 'Selezionati per la migrazione: $count';
  }

  @override
  String get mass_migration_finish_review => 'Termina revisione';

  @override
  String mass_migration_migrate_selected(int count) {
    return 'Migra elementi selezionati ($count)';
  }

  @override
  String mass_migration_migrating_selected(Object source) {
    return 'Migrazione degli elementi selezionati verso $source';
  }

  @override
  String get mass_migration_no_items_selected =>
      'Nessun elemento selezionato per la migrazione.';

  @override
  String mass_migration_migrating_item(int current, int total) {
    return 'Migrazione elemento $current di $total';
  }

  @override
  String get mass_migration_complete => 'Migrazione di massa completata';

  @override
  String get mass_migration_complete_success_message =>
      'Tutti gli elementi selezionati sono stati elaborati correttamente.';

  @override
  String get mass_migration_complete_partial_message =>
      'Migrazione terminata con alcuni elementi che richiedono attenzione manuale.';

  @override
  String mass_migration_route_summary(Object source, Object destination) {
    return '$source → $destination';
  }

  @override
  String get mass_migration_processed => 'Elaborati';

  @override
  String get mass_migration_matched => 'Corrispondenti';

  @override
  String get mass_migration_migrated => 'Migrati';

  @override
  String get mass_migration_skipped => 'Salati';

  @override
  String get mass_migration_failed => 'Falliti';

  @override
  String get mass_migration_failed_items => 'Elementi falliti';

  @override
  String get mass_migration_exit => 'Esci dalla migrazione di massa';

  @override
  String get mass_migration_no_destination_match =>
      'Nessuna corrispondenza nella destinazione';

  @override
  String mass_migration_query(Object query) {
    return 'Query: $query';
  }

  @override
  String get mass_migration_skip => 'Salta';

  @override
  String get mass_migration_loading => 'Caricamento...';

  @override
  String get mass_migration_choose_another_result =>
      'Scegli un altro risultato';

  @override
  String get mass_migration_source_chapters => 'Capitoli sorgente';

  @override
  String get mass_migration_destination_chapters => 'Capitoli destinazione';

  @override
  String mass_migration_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_source_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli sorgente',
      one: '1 capitolo sorgente',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_destination_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli destinazione',
      one: '1 capitolo destinazione',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_no_chapters_found => 'Nessun capitolo trovato.';

  @override
  String mass_migration_and_more_chapters(int count) {
    return 'E altri $count...';
  }

  @override
  String get mass_migration_unknown_title => 'Titolo sconosciuto';

  @override
  String get mass_migration_unknown_match => 'Corrispondenza sconosciuta';

  @override
  String get mass_migration_unknown_source => 'Fonte sconosciuta';

  @override
  String get mass_migration_unknown_chapter => 'Capitolo sconosciuto';

  @override
  String get migrate_confirm => 'Migrare a un\'altra fonte';

  @override
  String get clean_database => 'Pulire il database';

  @override
  String cleaned_database(Object x) {
    return 'Database pulito! $x voci rimosse';
  }

  @override
  String get clean_database_desc =>
      'Questo eliminerà tutti gli elementi che non sono stati aggiunti alla libreria!';

  @override
  String get incognito_mode => 'Modalità Incognito';

  @override
  String get incognito_mode_description => 'Sospende la cronologia di lettura';

  @override
  String get downloaded_only => 'Solo scaricati';

  @override
  String get downloaded_only_description =>
      'Mostra solo le voci scaricate nella tua libreria';

  @override
  String get download_queue => 'Coda di download';

  @override
  String get categories => 'Categorie';

  @override
  String get statistics => 'Statistiche';

  @override
  String get settings => 'Impostazioni';

  @override
  String get about => 'Informazioni';

  @override
  String get help => 'Aiuto';

  @override
  String get no_downloads => 'Nessun download';

  @override
  String get edit_categories => 'Modifica categorie';

  @override
  String get edit_categories_description =>
      'Non hai categorie. Tocca il pulsante più per crearne una per organizzare la tua biblioteca';

  @override
  String get add => 'Aggiungi';

  @override
  String get add_category => 'Aggiungi categoria';

  @override
  String get name => 'Nome';

  @override
  String get category_name_required => '*Richiesto';

  @override
  String get add_category_error_exist =>
      'Una categoria con questo nome esiste già!';

  @override
  String get delete_category => 'Elimina categoria';

  @override
  String delete_category_msg(Object name) {
    return 'Vuoi eliminare la categoria $name?';
  }

  @override
  String get rename_category => 'Rinomina categoria';

  @override
  String get general => 'Generale';

  @override
  String get general_subtitle => 'Lingua app';

  @override
  String get app_language => 'Lingua app';

  @override
  String get default_subtitle_language => 'Lingua predefinita dei sottotitoli';

  @override
  String get appearance => 'Aspetto';

  @override
  String get appearance_subtitle => 'Tema, formato data e ora';

  @override
  String get theme => 'Tema';

  @override
  String get dark_mode => 'Modalità scura';

  @override
  String get follow_system_theme => 'Segui il tema del sistema';

  @override
  String get on => 'Attivo';

  @override
  String get off => 'Disattivo';

  @override
  String get pure_black_dark_mode => 'Modalità scura nero puro';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get relative_timestamp => 'Timestamp relativo';

  @override
  String get relative_timestamp_short => 'Breve (Oggi, Ieri)';

  @override
  String get relative_timestamp_long => 'Lungo (Breve+, n giorni fa)';

  @override
  String get date_format => 'Formato data';

  @override
  String get reader => 'Lettore';

  @override
  String get reader_manga => 'Manga reader';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get reader_subtitle =>
      'Modalità di lettura, visualizzazione, navigazione';

  @override
  String get default_reading_mode => 'Modalità di lettura predefinita';

  @override
  String get reading_mode_vertical => 'Verticale';

  @override
  String get reading_mode_horizontal => 'Orizzontale';

  @override
  String get reading_mode_left_to_right => 'Da sinistra a destra';

  @override
  String get reading_mode_right_to_left => 'Da destra a sinistra';

  @override
  String get reading_mode_vertical_continuous => 'Verticale continuo';

  @override
  String get reading_mode_webtoon => 'Webtoon';

  @override
  String get double_tap_animation_speed => 'Velocità animazione doppio tocco';

  @override
  String get normal => 'Normale';

  @override
  String get fast => 'Veloce';

  @override
  String get no_animation => 'Nessuna animazione';

  @override
  String get animate_page_transitions => 'Anima transizioni pagina';

  @override
  String get crop_borders => 'Taglia bordi';

  @override
  String get downloads => 'Download';

  @override
  String get downloads_subtitle => 'Impostazioni download';

  @override
  String get download_location => 'Posizione download';

  @override
  String get custom_location => 'Posizione personalizzata';

  @override
  String get only_on_wifi => 'Solo su wifi';

  @override
  String get save_as_cbz_archive => 'Salva come archivio CBZ';

  @override
  String get delete_download_after_reading =>
      'Elimina download dopo la lettura';

  @override
  String get concurrent_downloads => 'Download simultanei';

  @override
  String get browse_subtitle => 'Fonti, ricerca globale';

  @override
  String get only_include_pinned_sources => 'Includi solo fonti fissate';

  @override
  String get nsfw_sources => 'Fonti NSFW (+18)';

  @override
  String get nsfw_sources_show => 'Mostra nelle liste di fonti ed estensioni';

  @override
  String get nsfw_sources_info =>
      'Ciò non impedisce che estensioni non ufficiali o potenzialmente contrassegnate in modo errato mostrino contenuti NSFW (18+) all\'interno dell\'app';

  @override
  String get version => 'Versione';

  @override
  String get check_for_update => 'Controlla aggiornamenti';

  @override
  String get logs_on => 'Abilita registrazione';

  @override
  String get share_app_logs => 'Condividi i log dell\'app';

  @override
  String get no_app_logs => 'Nessun file log.txt disponibile!';

  @override
  String get failed => 'Fallito!';

  @override
  String n_days_ago(Object days) {
    return '$days giorni fa';
  }

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get a_week_ago => 'Una settimana fa';

  @override
  String get next_week => 'Prossima settimana';

  @override
  String get add_to_library => 'Aggiungi alla biblioteca';

  @override
  String get added_to_library => 'Added to library';

  @override
  String get completed => 'Completato';

  @override
  String get ongoing => 'In corso';

  @override
  String get on_hiatus => 'In pausa';

  @override
  String get canceled => 'Annullato';

  @override
  String get publishing_finished => 'Pubblicazione completata';

  @override
  String get unknown => 'Sconosciuto';

  @override
  String get set_categories => 'Imposta categorie';

  @override
  String get edit => 'Modifica';

  @override
  String get in_library => 'Nella libreria';

  @override
  String get filter_scanlator_groups => 'Filtra gruppi scanlator';

  @override
  String get reset => 'Reset';

  @override
  String get by_source => 'Per fonte';

  @override
  String get by_chapter_number => 'Per numero di capitolo';

  @override
  String get by_episode_number => 'Per numero di episodio';

  @override
  String get by_upload_date => 'Per data di caricamento';

  @override
  String get source_title => 'Titolo della fonte';

  @override
  String get chapter_number => 'Numero del capitolo';

  @override
  String get episode_number => 'Numero dell\'episodio';

  @override
  String get share => 'Condividi';

  @override
  String n_chapters(Object n) {
    return '$n capitoli';
  }

  @override
  String get no_description => 'Nessuna descrizione';

  @override
  String get resume => 'Riprendi';

  @override
  String get read => 'Leggi';

  @override
  String get watch => 'Guarda';

  @override
  String get popular => 'Popolare';

  @override
  String get open_in_browser => 'Apri nel browser';

  @override
  String get clear_cookie => 'Cancella cookie';

  @override
  String get show_page_number => 'Mostra numero di pagina';

  @override
  String get from_library => 'Dalla libreria';

  @override
  String get downloaded_chapter => 'Capitolo scaricato';

  @override
  String page(Object page) {
    return 'Pagina $page';
  }

  @override
  String get global_search => 'Ricerca globale';

  @override
  String get color_blend_level => 'Livello di fusione colore';

  @override
  String current(Object char) {
    return 'Corrente $char';
  }

  @override
  String finished(Object char) {
    return 'Finito $char';
  }

  @override
  String next(Object char) {
    return 'Prossimo $char';
  }

  @override
  String previous(Object char) {
    return 'Precedente $char';
  }

  @override
  String get no_more_chapter => 'Non ci sono altri capitoli';

  @override
  String get no_result => 'Nessun risultato';

  @override
  String get send => 'Invia';

  @override
  String get delete => 'Elimina';

  @override
  String get start_downloading => 'Inizia a scaricare ora';

  @override
  String get retry => 'Riprova';

  @override
  String get add_chapters => 'Aggiungi capitoli';

  @override
  String get delete_chapters => 'Eliminare capitolo?';

  @override
  String get default0 => 'Predefinito';

  @override
  String get total_chapters => 'Totale capitoli';

  @override
  String get total_episodes => 'Episodi totali';

  @override
  String get import_local_file => 'Importa file locale';

  @override
  String get import_files => 'File';

  @override
  String get split_epub_chapters => 'Dividi in capitoli';

  @override
  String get split_epub_chapters_description =>
      'Importa ogni capitolo EPUB come voce separata';

  @override
  String get nothing_read_recently => 'Niente letto di recente';

  @override
  String get status => 'Stato';

  @override
  String get not_started => 'Non iniziato';

  @override
  String get score => 'Punteggio';

  @override
  String get start_date => 'Data di inizio';

  @override
  String get finish_date => 'Data di fine';

  @override
  String get reading => 'In lettura';

  @override
  String get on_hold => 'In attesa';

  @override
  String get dropped => 'Abbandonato';

  @override
  String get plan_to_read => 'Da leggere';

  @override
  String get re_reading => 'Rilettura';

  @override
  String get chapters => 'Capitoli';

  @override
  String get add_tracker => 'Aggiungi tracciamento';

  @override
  String get one_tracker => '1 tracciamento';

  @override
  String n_tracker(Object n) {
    return '$n tracciamenti';
  }

  @override
  String get tracking => 'Tracciamento';

  @override
  String get syncing => 'Sincronizzazione';

  @override
  String get sync_password => 'Password (almeno 8 caratteri)';

  @override
  String get sync_logged => 'Accesso riuscito';

  @override
  String get syncing_subtitle =>
      'Sincronizza i tuoi progressi su più dispositivi tramite un server discord auto-ospitato. Per maggiori informazioni, visita il nostro server discord!';

  @override
  String get last_sync_manga => 'Ultima sincronizzazione del manga a:';

  @override
  String get last_sync_history => 'Ultima storia sincronizzata a:';

  @override
  String get last_sync_update => 'Ultimo aggiornamento: sincronizzazione a:';

  @override
  String get sync_server => 'Indirizzo del server di sincronizzazione';

  @override
  String get sync_login_invalid_creds => 'Email o password non validi';

  @override
  String get sync_starting => 'Avvio della sincronizzazione...';

  @override
  String get sync_finished => 'Sincronizzazione terminata';

  @override
  String get sync_failed => 'Sincronizzazione fallita';

  @override
  String get sync_button_sync => 'Sincronizza progressi';

  @override
  String get sync_button_upload => 'Solo carica';

  @override
  String get sync_button_upload_info =>
      'Questa operazione sostituirà completamente i dati remoti con i dati locali!';

  @override
  String get sync_button_download => 'Solo scarica';

  @override
  String get sync_button_download_info =>
      'Questa operazione sostituirà completamente i dati locali con i dati remoti!';

  @override
  String get sync_on => 'Abilita sincronizzazione';

  @override
  String get sync_auto => 'Sincronizzazione automatica';

  @override
  String get sync_auto_warning =>
      'La sincronizzazione automatica è attualmente una funzione sperimentale!';

  @override
  String get sync_auto_off => 'Disattivato';

  @override
  String get sync_auto_5_minutes => 'Ogni 5 minuti';

  @override
  String get sync_auto_10_minutes => 'Ogni 10 minuti';

  @override
  String get sync_auto_30_minutes => 'Ogni 30 minuti';

  @override
  String get sync_auto_1_hour => 'Ogni 1 ora';

  @override
  String get sync_auto_3_hours => 'Ogni 3 ore';

  @override
  String get sync_auto_6_hours => 'Ogni 6 ore';

  @override
  String get sync_auto_12_hours => 'Ogni 12 ore';

  @override
  String get server_error => 'Errore del server!';

  @override
  String get dialog_confirm => 'Conferma';

  @override
  String get description => 'Descrizione';

  @override
  String get reorder_navigation => 'Personalizza navigazione';

  @override
  String get reorder_navigation_description =>
      'Riorganizza e regola ogni navigazione in base alle tue esigenze.';

  @override
  String get full_screen_player => 'Usa schermo intero';

  @override
  String get full_screen_player_info =>
      'Usa automaticamente lo schermo intero durante la riproduzione di un video.';

  @override
  String episode_progress(Object n) {
    return 'Progresso: $n';
  }

  @override
  String n_episodes(Object n) {
    return '$n episodi';
  }

  @override
  String get manga_sources => 'Fonti Manga';

  @override
  String get anime_sources => 'Fonti Anime';

  @override
  String get novel_sources => 'Fonti romanzo';

  @override
  String get anime_extensions => 'Estensioni Anime';

  @override
  String get manga_extensions => 'Estensioni Manga';

  @override
  String get novel_extensions => 'Estensioni romanzo';

  @override
  String get extension_settings => 'Impostazioni estensione';

  @override
  String get anime => 'Anime';

  @override
  String get manga => 'Manga';

  @override
  String get novel => 'Romanzo';

  @override
  String get library_no_category_exist => 'Non hai ancora nessuna categoria';

  @override
  String get watching => 'Guardando';

  @override
  String get plan_to_watch => 'In programma di guardare';

  @override
  String get re_watching => 'Rivisualizzazione';

  @override
  String get episodes => 'Episodi';

  @override
  String get download => 'Scarica';

  @override
  String get new_update_available => 'Nuovo aggiornamento disponibile';

  @override
  String app_version(Object v) {
    return 'Versione dell\'app: v$v';
  }

  @override
  String get searching_for_updates => 'Ricerca aggiornamenti in corso...';

  @override
  String get no_new_updates_available =>
      'Nessun nuovo aggiornamento disponibile';

  @override
  String get uninstall => 'Disinstalla';

  @override
  String uninstall_extension(Object ext) {
    return 'Disinstallare estensione $ext?';
  }

  @override
  String get langauage => 'Lingua';

  @override
  String get extension_detail => 'Dettaglio estensione';

  @override
  String get scale_type => 'Tipo di scala';

  @override
  String get scale_type_fit_screen => 'Adatta allo schermo';

  @override
  String get scale_type_stretch => 'Stira';

  @override
  String get scale_type_fit_width => 'Adatta alla larghezza';

  @override
  String get scale_type_fit_height => 'Adatta all\'altezza';

  @override
  String get scale_type_original_size => 'Dimensione originale';

  @override
  String get scale_type_smart_fit => 'Adattamento intelligente';

  @override
  String get page_preload_amount => 'Quantità di pagine da precaricare';

  @override
  String get page_preload_amount_subtitle =>
      'Il numero di pagine da precaricare durante la lettura. Valori più alti risultano in un\'esperienza di lettura più fluida, a costo di un maggiore uso di cache e di rete.';

  @override
  String get image_loading_error => 'Questa immagine non può essere caricata';

  @override
  String get add_episodes => 'Aggiungi episodi';

  @override
  String get video_quality => 'Qualità';

  @override
  String get video_subtitle => 'Sottotitolo';

  @override
  String get check_for_extension_updates => 'Verifica aggiornamenti estensione';

  @override
  String get auto_extensions_updates =>
      'Aggiornamenti automatici delle estensioni';

  @override
  String get auto_extensions_updates_subtitle =>
      'Aggiorna automaticamente l\'estensione quando è disponibile una nuova versione.';

  @override
  String get check_for_app_updates =>
      'Controlla gli aggiornamenti dell\'app all\'avvio';

  @override
  String get reading_mode => 'Modalità di lettura';

  @override
  String get custom_filter => 'Filtro personalizzato';

  @override
  String get background_color => 'Colore di sfondo';

  @override
  String get white => 'Bianco';

  @override
  String get black => 'Nero';

  @override
  String get grey => 'Grigio';

  @override
  String get automaic => 'Automatico';

  @override
  String get preferred_domain => 'Dominio preferito';

  @override
  String get load_more => 'Carica altri';

  @override
  String get cancel_all_for_this_series => 'Annulla tutto per questa serie';

  @override
  String get login => 'Accedi';

  @override
  String login_into(Object tracker) {
    return 'Accedi a $tracker';
  }

  @override
  String get email_adress => 'Indirizzo email';

  @override
  String get password => 'Password';

  @override
  String log_out_from(Object tracker) {
    return 'Esci da $tracker?';
  }

  @override
  String get log_out => 'Esci';

  @override
  String get update_pending => 'Aggiornamento in attesa';

  @override
  String get update_all => 'Aggiorna tutto';

  @override
  String get backup_and_restore => 'Backup e ripristino';

  @override
  String get create_backup => 'Crea backup';

  @override
  String get create_backup_dialog_title => 'Cosa vuoi eseguire il backup?';

  @override
  String get create_backup_subtitle =>
      'Può essere utilizzato per ripristinare la libreria corrente';

  @override
  String get restore_backup => 'Ripristina backup';

  @override
  String get restore_backup_subtitle =>
      'Ripristina la libreria dal file di backup';

  @override
  String get automatic_backups => 'Backup automatici';

  @override
  String get backup_frequency => 'Frequenza di backup';

  @override
  String get backup_location => 'Posizione del backup';

  @override
  String get backup_options => 'Opzioni di backup';

  @override
  String get backup_options_dialog_title => 'Cosa vuoi eseguire il backup?';

  @override
  String get backup_options_subtitle =>
      'Quali informazioni includere nel file di backup';

  @override
  String get backup_and_restore_warning_info =>
      'È consigliabile conservare copie dei backup in altri luoghi';

  @override
  String get library_entries => 'Voci della libreria';

  @override
  String get chapters_and_episode => 'Capitoli ed episodi';

  @override
  String get every_6_hours => 'Ogni 6 ore';

  @override
  String get every_12_hours => 'Ogni 12 ore';

  @override
  String get daily => 'Giornaliero';

  @override
  String get every_2_days => 'Ogni 2 giorni';

  @override
  String get weekly => 'Settimanale';

  @override
  String get restore_backup_warning_title =>
      'Ripristinare un backup sovrascriverà tutti i dati esistenti.\n\nContinuare il ripristino?';

  @override
  String get services => 'Servizi';

  @override
  String get tracking_warning_info =>
      'Sincronizzazione unidirezionale per aggiornare il progresso dei capitoli nei servizi di tracciamento. Imposta il tracciamento per le singole voci dal loro pulsante di tracciamento.';

  @override
  String get use_page_tap_zones => 'Usa zone di tocco pagina';

  @override
  String get manage_trackers => 'Gestisci tracciatori';

  @override
  String get restore => 'Ripristina';

  @override
  String get backups => 'Backup';

  @override
  String get by_scanlator => 'Per scanlator';

  @override
  String get by_name => 'Per nome';

  @override
  String get installed => 'Installato';

  @override
  String get auto_scroll => 'Scorrimento automatico';

  @override
  String get video_audio => 'Audio';

  @override
  String get video_audio_info =>
      'Lingue preferite, correzione dell\'intonazione, canali audio';

  @override
  String get player => 'Giocatore';

  @override
  String get player_video => 'Video player';

  @override
  String get markEpisodeAsSeenSetting =>
      'In quale momento contrassegnare l\'episodio come visto';

  @override
  String get default_skip_intro_length =>
      'Durata predefinita per saltare l\'introduzione';

  @override
  String get default_playback_speed_length =>
      'Durata predefinita per la velocità di riproduzione';

  @override
  String get updateProgressAfterReading =>
      'Aggiorna il progresso dopo aver letto';

  @override
  String get no_sources_installed => 'Nessuna fonte installata!';

  @override
  String get show_extensions => 'Mostra estensioni';

  @override
  String get default_skip_forward_skip_length =>
      'Lunghezza predefinita del salto in avanti';

  @override
  String get aniskip_requires_info =>
      'AniSkip richiede che l\'anime sia tracciato con MAL o Anilist per funzionare.';

  @override
  String get enable_aniskip => 'Abilita AniSkip';

  @override
  String get enable_auto_skip => 'Abilita l\'auto-skip';

  @override
  String get aniskip_button_timeout => 'Timeout del pulsante';

  @override
  String get skip_opening => 'Salta apertura';

  @override
  String get skip_ending => 'Salta finale';

  @override
  String get fullscreen => 'Schermo intero';

  @override
  String get update_library => 'Aggiorna libreria';

  @override
  String updating_library(Object cur, Object failed, Object max) {
    return 'Aggiornamento della libreria ($cur / $max) - Fallito: $failed';
  }

  @override
  String get next_chapter => 'Capitolo successivo';

  @override
  String get next_5_chapters => 'Prossimi 5 capitoli';

  @override
  String get next_10_chapters => 'Prossimi 10 capitoli';

  @override
  String get next_25_chapters => 'Prossimi 25 capitoli';

  @override
  String get all_chapters => 'Tutti i capitoli';

  @override
  String get next_episode => 'Prossimo episodio';

  @override
  String get next_5_episodes => 'Prossimi 5 episodi';

  @override
  String get next_10_episodes => 'Prossimi 10 episodi';

  @override
  String get next_25_episodes => 'Prossimi 25 episodi';

  @override
  String get all_episodes => 'Tutti gli episodi';

  @override
  String get cover_saved => 'Copertina salvata';

  @override
  String get set_as_cover => 'Imposta come copertina';

  @override
  String get use_this_as_cover_art => 'Usare questo come copertina?';

  @override
  String get save => 'Salva';

  @override
  String get picture_saved => 'Immagine salvata';

  @override
  String get cover_updated => 'Copertina aggiornata';

  @override
  String get include_subtitles => 'Includi sottotitoli';

  @override
  String get blend_mode_default => 'Predefinito';

  @override
  String get blend_mode_multiply => 'Moltiplicare';

  @override
  String get blend_mode_screen => 'Schermo';

  @override
  String get blend_mode_overlay => 'Sovrapposizione';

  @override
  String get blend_mode_colorDodge => 'Schiarire colore';

  @override
  String get blend_mode_lighten => 'Schiarire';

  @override
  String get blend_mode_colorBurn => 'Bruciare colore';

  @override
  String get blend_mode_darken => 'Scurire';

  @override
  String get blend_mode_difference => 'Differenza';

  @override
  String get blend_mode_saturation => 'Saturazione';

  @override
  String get blend_mode_softLight => 'Luce soffusa';

  @override
  String get blend_mode_plus => 'Più';

  @override
  String get blend_mode_exclusion => 'Esclusione';

  @override
  String get custom_color_filter => 'Filtro colore personalizzato';

  @override
  String get color_filter_blend_mode =>
      'Modalità di miscelazione del filtro colore';

  @override
  String get enable_all => 'Abilita tutto';

  @override
  String get disable_all => 'Disabilita tutto';

  @override
  String get font => 'Carattere';

  @override
  String get color => 'Colore';

  @override
  String get font_size => 'Dimensione del carattere';

  @override
  String get text => 'Testo';

  @override
  String get border => 'Bordo';

  @override
  String get background => 'Sfondo';

  @override
  String get no_subtite_warning_message =>
      'Non ha effetto perché non ci sono tracce sottotitoli in questo video';

  @override
  String get grid_size => 'Dimensione griglia';

  @override
  String n_per_row(Object n) {
    return '$n per riga';
  }

  @override
  String get horizontal_continious => 'Orizzontale continuo';

  @override
  String get edit_code => 'Modifica codice';

  @override
  String get use_libass => 'Abilita libass';

  @override
  String get use_libass_info =>
      'Usa il rendering dei sottotitoli basato su libass per il backend nativo.';

  @override
  String get libass_not_disable_message =>
      'Disabilita `use libass` nelle impostazioni del lettore per poter personalizzare i sottotitoli.';

  @override
  String get torrent_stream => 'Streaming Torrent';

  @override
  String get add_torrent => 'Aggiungi torrent';

  @override
  String get enter_torrent_hint_text =>
      'Inserisci magnet o URL del file torrent';

  @override
  String get torrent_url => 'URL torrent';

  @override
  String get or => 'O';

  @override
  String get advanced => 'Avanzate';

  @override
  String get advanced_info => 'Configurazione mpv';

  @override
  String get use_native_http_client => 'Usa il client HTTP nativo';

  @override
  String get use_native_http_client_info =>
      'Supporta automaticamente le funzionalità della piattaforma come le VPN, supporta più funzionalità HTTP come HTTP/3 e la gestione dei reindirizzamenti personalizzati.';

  @override
  String n_hour_ago(Object hour) {
    return '$hour ora fa';
  }

  @override
  String n_hours_ago(Object hours) {
    return '$hours ore fa';
  }

  @override
  String n_minute_ago(Object minute) {
    return '$minute minuto fa';
  }

  @override
  String n_minutes_ago(Object minutes) {
    return '$minutes minuti fa';
  }

  @override
  String n_day_ago(Object day) {
    return '$day giorno fa';
  }

  @override
  String get now => 'adesso';

  @override
  String library_last_updated(Object lastUpdated) {
    return 'Libreria aggiornata l\'ultima volta: $lastUpdated';
  }

  @override
  String get data_and_storage => 'Dati e archiviazione';

  @override
  String get download_location_info => 'Usato per i download dei capitoli';

  @override
  String get storage => 'Archiviazione';

  @override
  String get clear_chapter_and_episode_cache =>
      'Cancella cache dei capitoli ed episodi';

  @override
  String get cache_cleared => 'Cache cancellata';

  @override
  String get clear_chapter_or_episode_cache_on_app_launch =>
      'Cancella cache dei capitoli/episodi all\'avvio dell\'app';

  @override
  String get app_settings => 'Impostazioni app';

  @override
  String get sources_settings => 'Impostazioni fonti';

  @override
  String get include_sensitive_settings =>
      'Includi impostazioni sensibili (es. token di login del tracker)';

  @override
  String get create => 'Crea';

  @override
  String get downloads_are_limited_to_wifi =>
      'I download sono limitati solo al Wi-Fi';

  @override
  String get recommendations => 'Raccomandazioni';

  @override
  String get recommendations_similar => 'simile';

  @override
  String get recommendations_weights => 'Pesi di raccomandazione';

  @override
  String get recommendations_weights_genre => 'Similarità di genere';

  @override
  String get recommendations_weights_setting => 'Similarità di ambientazione';

  @override
  String get recommendations_weights_synopsis => 'Similarità di storia';

  @override
  String get recommendations_weights_theme => 'Similarità di tema';

  @override
  String get manga_extensions_repo => 'Repository delle estensioni manga';

  @override
  String get anime_extensions_repo => 'Repository delle estensioni anime';

  @override
  String get novel_extensions_repo => 'Repository delle estensioni romanzi';

  @override
  String get custom_dns =>
      'DNS personalizzato (lascia vuoto per usare il DNS di sistema)';

  @override
  String get android_proxy_server => 'Server proxy Android (ApkBridge)';

  @override
  String get get_apk_bridge => 'Ottieni ApkBridge';

  @override
  String get get_sync_server => 'Ottieni il server di sincronizzazione qui';

  @override
  String get undefined => 'Non definito';

  @override
  String get empty_extensions_repo =>
      'Non hai alcun URL di repository qui. Fai clic sul pulsante più per aggiungerne uno!';

  @override
  String get add_extensions_repo => 'Aggiungi URL del repository';

  @override
  String get remove_extensions_repo => 'Rimuovi URL del repository';

  @override
  String get manage_manga_repo_urls => 'Gestisci gli URL del repository manga';

  @override
  String get manage_anime_repo_urls => 'Gestisci gli URL del repository anime';

  @override
  String get manage_novel_repo_urls =>
      'Gestisci gli URL del repository romanzi';

  @override
  String get url_cannot_be_empty => 'L\'URL non può essere vuoto';

  @override
  String get url_must_end_with_dot_json => 'L\'URL deve terminare con .json';

  @override
  String get repo_url => 'URL del repository';

  @override
  String get invalid_url_format => 'Formato URL non valido';

  @override
  String get clear_all_sources => 'Cancella tutte le fonti';

  @override
  String get clear_all_sources_msg =>
      'Questo cancellerà completamente tutte le fonti dall\'app. Sei sicuro di voler continuare?';

  @override
  String get sources_cleared => 'Fonti cancellate!';

  @override
  String get repo_added => 'Repository delle fonti aggiunto!';

  @override
  String get add_repo => 'Aggiungere repository?';

  @override
  String get genre_search_library => 'Cerca genere nella libreria';

  @override
  String get genre_search_source => 'Esplora nella fonte';

  @override
  String get source_not_added => 'La fonte non è installata!';

  @override
  String get load_own_subtitles => 'Carica i tuoi sottotitoli...';

  @override
  String get search_subtitles => 'Cerca sottotitoli online...';

  @override
  String extension_notes(Object notes) {
    return 'Note: $notes';
  }

  @override
  String get unsupported_repo =>
      'Hai provato ad aggiungere un repository non supportato. Controlla il server discord per ricevere supporto!';

  @override
  String get end_of_chapter => 'Fine del capitolo';

  @override
  String get chapter_completed => 'Capitolo completato';

  @override
  String get continue_to_next_chapter =>
      'Continua a scorrere per leggere il prossimo capitolo';

  @override
  String get no_next_chapter => 'Nessun capitolo successivo';

  @override
  String get you_have_finished_reading => 'Hai finito di leggere';

  @override
  String get return_to_the_list_of_chapters =>
      'Ritorna all\'elenco dei capitoli';

  @override
  String get hwdec => 'Decodificatore hardware';

  @override
  String get enable_hardware_accel => 'Accelerazione hardware';

  @override
  String get enable_hardware_accel_info =>
      'Attiva/disattiva se stai riscontrando bug o crash';

  @override
  String get track_library_navigate => 'Vai alla voce locale esistente';

  @override
  String get track_library_add => 'Aggiungi alla libreria locale';

  @override
  String get track_library_add_confirm =>
      'Aggiungi elemento tracciato alla libreria locale';

  @override
  String get track_library_not_logged =>
      'Accedi al tracker corrispondente per usare questa funzione!';

  @override
  String get track_library_switch => 'Passa a un altro tracker';

  @override
  String get go_back => 'Indietro';

  @override
  String get merge_library_nav_mobile =>
      'Unisci navigazione libreria su mobile';

  @override
  String get enable_discord_rpc => 'Attiva Discord RPC';

  @override
  String get hide_discord_rpc_incognito =>
      'Nascondi Discord RPC in modalità Incognito';

  @override
  String get rpc_show_reading_watching_progress =>
      'Mostra capitolo corrente su Discord (richiede riavvio)';

  @override
  String get rpc_show_title => 'Mostra titolo corrente su Discord';

  @override
  String get rpc_show_cover_image =>
      'Mostra immagine di copertina corrente su Discord';

  @override
  String get sync_enable_histories => 'Sincronizza dati cronologia';

  @override
  String get sync_enable_updates => 'Sincronizza dati aggiornamenti';

  @override
  String get sync_enable_settings => 'Sincronizza impostazioni';

  @override
  String get enable_mpv => 'Attiva shader / script mpv';

  @override
  String get mpv_info => 'Supporta script .js in mpv/scripts/';

  @override
  String get mpv_redownload => 'Riscarica file di configurazione mpv';

  @override
  String get mpv_redownload_info =>
      'Sostituisce i vecchi file di configurazione con quelli nuovi!';

  @override
  String get mpv_download =>
      'I file di configurazione MPV sono richiesti!\nScarica ora?';

  @override
  String get custom_buttons => 'Pulsanti personalizzati';

  @override
  String get custom_buttons_info =>
      'Esegui codice lua con pulsanti personalizzati';

  @override
  String get custom_buttons_edit => 'Modifica pulsanti personalizzati';

  @override
  String get custom_buttons_add => 'Aggiungi pulsante personalizzato';

  @override
  String get custom_buttons_added => 'Pulsante personalizzato aggiunto!';

  @override
  String get custom_buttons_delete => 'Elimina pulsante personalizzato';

  @override
  String get custom_buttons_text => 'Testo del pulsante';

  @override
  String get custom_buttons_text_req => 'Testo del pulsante richiesto';

  @override
  String get custom_buttons_js_code => 'Codice lua';

  @override
  String get custom_buttons_js_code_req => 'Codice lua richiesto';

  @override
  String get custom_buttons_js_code_long =>
      'Codice lua (su pressione prolungata)';

  @override
  String get custom_buttons_startup => 'Codice lua (all\'avvio)';

  @override
  String n_days(Object n) {
    return '$n giorni';
  }

  @override
  String get decoder => 'Decodificatore';

  @override
  String get decoder_info => 'Decodifica hardware, formato pixel, debanding';

  @override
  String get enable_gpu_next => 'Attiva gpu-next (solo Android)';

  @override
  String get enable_gpu_next_info => 'Un nuovo motore di rendering video';

  @override
  String get debanding => 'Debanding';

  @override
  String get use_yuv420p => 'Usa formato pixel YUV420P';

  @override
  String get use_yuv420p_info =>
      'Può risolvere schermi neri su alcuni codec video, può anche migliorare le prestazioni a scapito della qualità';

  @override
  String get audio_preferred_languages => 'Lingue preferite';

  @override
  String get audio_preferred_languages_info =>
      'Lingua(e) audio da selezionare per impostazione predefinita su un video con più flussi audio, codici lingua di 2/3 lettere (es: it, en, es). Valori multipli possono essere delimitati da virgola.';

  @override
  String get enable_audio_pitch_correction =>
      'Attiva correzione intonazione audio';

  @override
  String get enable_audio_pitch_correction_info =>
      'Impedisce all\'audio di diventare acuto a velocità più elevate e grave a velocità più basse';

  @override
  String get audio_channels => 'Canali audio';

  @override
  String get volume_boost_cap => 'Limite amplificazione volume';

  @override
  String get internal_player => 'Lettore interno';

  @override
  String get internal_player_info => 'Progresso, controlli, orientamento';

  @override
  String get subtitle_delay_text => 'Ritardo sottotitoli';

  @override
  String get subtitle_delay => 'Ritardo (ms)';

  @override
  String get subtitle_speed => 'Velocità';

  @override
  String get calendar => 'Calendario';

  @override
  String get schedule => 'Planning';

  @override
  String get calendar_no_data => 'Nessun dato ancora.';

  @override
  String get calendar_info =>
      'Il calendario può solo prevedere il prossimo caricamento del capitolo in base ai caricamenti precedenti. Alcuni dati potrebbero non essere accurati al 100%!';

  @override
  String in_n_day(Object days) {
    return 'tra $days giorno';
  }

  @override
  String in_n_days(Object days) {
    return 'tra $days giorni';
  }

  @override
  String get clear_library => 'Cancella libreria';

  @override
  String get clear_library_desc =>
      'Scegli di cancellare tutte le voci di manga, anime e/o novel';

  @override
  String get clear_library_input =>
      'Digita \'manga\', \'anime\' e/o \'novel\' (separati da virgola) per rimuovere tutte le voci correlate';

  @override
  String get watch_order => 'Ordine di visione';

  @override
  String get sequels => 'Sequel';

  @override
  String get recommendations_similarity => 'Similarità:';

  @override
  String get local_folder_structure => 'Struttura di una cartella locale';

  @override
  String get local_folder => 'Cartelle locali';

  @override
  String get add_local_folder => 'Aggiungi cartella locale';

  @override
  String get rescan_local_folder => 'Rianalizza tutte le cartelle locali ora';

  @override
  String get export_metadata => 'Esporta metadati';

  @override
  String get exported => 'Esportato';

  @override
  String get text_size => 'Dimensione testo:';

  @override
  String get text_align => 'Allineamento testo';

  @override
  String get line_height => 'Altezza linea';

  @override
  String get show_scroll_percentage => 'Mostra percentuale di scorrimento';

  @override
  String get remove_extra_paragraph_spacing =>
      'Rimuovi spaziatura extra tra paragrafi';

  @override
  String select_label_color(Object label) {
    return 'Seleziona colore $label';
  }

  @override
  String get default_user_agent => 'Agente predefinito';

  @override
  String get forceLandscapeMode => 'Forza modalità paesaggio';

  @override
  String get forceLandscapeModeSubtitle =>
      'Forza il lettore a utilizzare l\'orientamento orizzontale.';

  @override
  String get dns_over_https => 'DNS-over-HTTPS (DoH)';

  @override
  String get dns_provider => 'Provider DNS';

  @override
  String get tracked => 'Monitorato';

  @override
  String get auth_unlock_msg => 'Autenticati per sbloccare Mangayomi';

  @override
  String get app_locked => 'Mangayomi è bloccato';

  @override
  String get auth_to_continue => 'Autenticati per continuare';

  @override
  String get authenticating => 'Autenticazione in corso...';

  @override
  String get unlock => 'Sblocca';

  @override
  String get security => 'Sicurezza';

  @override
  String get auth_to_change_security_setting =>
      'Autenticati per modificare le impostazioni di sicurezza';

  @override
  String get app_lock => 'Blocco app';

  @override
  String get require_biometric_or_device_credential =>
      'Richiede l\'autenticazione biometrica o le credenziali del dispositivo per aprire l\'app';

  @override
  String get biometric_or_device_credential_not_available =>
      'L\'autenticazione biometrica non è disponibile su questo dispositivo';

  @override
  String get app_lock_description =>
      'Quando il blocco dell\'app è abilitato, ti verrà richiesto di autenticarti\\ndevice ogni volta che apri l\'app o torni ad essa dallo sfondo.';

  @override
  String get keep_screen_on => 'Mantieni lo schermo acceso';

  @override
  String get webtoon_side_padding => 'Spaziatura laterale Webtoon';

  @override
  String get show_page_gaps => 'Mostra spazi tra pagine';

  @override
  String get invert_colors => 'Colori invertiti';

  @override
  String get grayscale => 'Scala di grigi';

  @override
  String get brightness => 'Luminosità';

  @override
  String get contrast => 'Contrasto';

  @override
  String get saturation => 'Saturazione';

  @override
  String get navigation_layout => 'Layout di navigazione';

  @override
  String get nav_layout_default => 'Predefinito';

  @override
  String get nav_layout_l_shaped => 'A forma di L';

  @override
  String get nav_layout_kindle => 'Kindle';

  @override
  String get nav_layout_edge => 'Bordo';

  @override
  String get nav_layout_right_and_left => 'Destra e sinistra';

  @override
  String get nav_layout_disabled => 'Disabilitato';

  @override
  String get color_enhancements => 'Miglioramenti dei colori';

  @override
  String get total => 'Totale';

  @override
  String get mean_per_title => 'Media per titolo';

  @override
  String get completion_rate => 'Tasso di completamento';

  @override
  String get watching_time => 'Tempo di visione';

  @override
  String get reading_time => 'Tempo di lettura';

  @override
  String average_chapters_per_title(Object title) {
    return 'Media capitoli per titolo';
  }

  @override
  String get read_percentage => 'Percentuale di lettura';

  @override
  String get entries => 'Voci';

  @override
  String get android_proxy_server_mihon => 'Server Proxy Android (Mihon)';

  @override
  String get android_proxy_server_mihon_description =>
      'Scarica e configura il server proxy necessario per utilizzare le estensioni Mihon.';

  @override
  String get mihon_proxy_server => 'Server proxy Mihon';

  @override
  String get extension_server_intro_with_jre =>
      'Scarica il pacchetto server proxy prima di usare le estensioni Mihon. Include JRE e JAR del server.';

  @override
  String get extension_server_intro_ios =>
      'Scarica il file JAR del server proxy prima di usare le estensioni Mihon. Su iOS serve solo il JAR del server.';

  @override
  String get checking_files => 'Controllo file';

  @override
  String get files_installed => 'File installati';

  @override
  String get files_missing => 'File mancanti';

  @override
  String get update_files => 'Aggiorna file';

  @override
  String get up_to_date => 'Aggiornato';

  @override
  String get choose_location => 'Scegli posizione';

  @override
  String get import_existing_jar => 'Importa JAR esistente';

  @override
  String get detect_files_in_selected_folder =>
      'Rileva file nella cartella selezionata';

  @override
  String get preparing_download => 'Preparazione download...';

  @override
  String get app_install_location => 'Posizione installazione app';

  @override
  String get install_location => 'Posizione installazione';

  @override
  String get jre_executable => 'Eseguibile JRE';

  @override
  String get extension_server_jar => 'JAR server estensioni';

  @override
  String get installed_version => 'Versione installata';

  @override
  String get latest_version => 'Ultima versione';

  @override
  String get apkbridge_description =>
      'Usa ApkBridge quando ti serve un proxy separato per il dispositivo Android. Imposta l\'indirizzo qui e scarica l\'APK da GitHub.';

  @override
  String get set_proxy_address => 'Imposta indirizzo proxy';

  @override
  String get no_newer_proxy_server_release_available =>
      'Nessuna nuova versione del server proxy disponibile.';

  @override
  String get could_not_check_proxy_server_updates =>
      'Impossibile verificare gli aggiornamenti del server proxy.';

  @override
  String get no_extension_server_bundle_available_for_this_platform =>
      'Nessun pacchetto server estensioni disponibile per questa piattaforma.';

  @override
  String failed_to_download_bundle(Object statusCode) {
    return 'Download del pacchetto fallito ($statusCode).';
  }

  @override
  String get downloaded_bundle_missing_expected_files =>
      'Il pacchetto scaricato non contiene i file previsti.';

  @override
  String get extension_server_files_ready =>
      'File del server estensioni pronti.';

  @override
  String get ios_extension_server_import_hint =>
      'Su iOS il server è installato nella sandbox dell\'app. Usa \"Importa JAR esistente\" per caricare un file scaricato.';

  @override
  String get select_extension_server_folder =>
      'Seleziona cartella del server estensioni';

  @override
  String get selected_folder_does_not_exist =>
      'La cartella selezionata non esiste.';

  @override
  String get no_extension_server_files_found_in_selected_folder =>
      'Nessun file trovato nella cartella selezionata.';

  @override
  String get extension_server_files_linked =>
      'File del server estensioni collegati.';

  @override
  String get select_extension_server_jar =>
      'Seleziona JAR del server estensioni';

  @override
  String get selected_file_could_not_be_accessed =>
      'Impossibile accedere al file selezionato.';

  @override
  String get extension_server_jar_imported =>
      'JAR del server estensioni importato.';

  @override
  String get could_not_launch_apk_bridge_page =>
      'Impossibile aprire la pagina di ApkBridge.';

  @override
  String get proxy_server_ip_hint =>
      'IP del server (es. 10.0.0.5 o https://example.com)';

  @override
  String get not_configured => 'Non configurato';

  @override
  String get webview => 'Webview';

  @override
  String get tts => 'Da testo a voce';

  @override
  String get tts_speed => 'Velocità';

  @override
  String get tts_pitch => 'Tono';

  @override
  String get tts_language => 'Lingua';

  @override
  String get tts_voice => 'Voce';

  @override
  String get tts_stop => 'Stop';

  @override
  String get tts_play => 'Riproduci';

  @override
  String get tts_pause => 'Pausa';

  @override
  String get tts_previous => 'Paragrafo precedente';

  @override
  String get tts_next => 'Paragrafo successivo';

  @override
  String tts_paragraph_progress(Object current, Object total) {
    return 'Paragrafo $current di $total';
  }

  @override
  String get tts_settings => 'Impostazioni TTS';

  @override
  String get tts_default => 'Predefinito';

  @override
  String get view_all => 'View all';

  @override
  String get for_you => 'For you';

  @override
  String get following_tab => 'Following';

  @override
  String get explore_tab => 'Explore';

  @override
  String get browser_dock_tabs => 'Schede';

  @override
  String get browser_dock_new_tab => 'Nuova scheda';

  @override
  String get browser_dock_more => 'Altre opzioni';

  @override
  String get browser_dock_collapse => 'Comprimi la barra';

  @override
  String get browser_dock_expand => 'Mostra la barra';

  @override
  String get catalog_tag_watch => 'Watch';

  @override
  String get catalog_tag_read => 'Read';

  @override
  String get catalog_tag_manga => 'Manga';

  @override
  String get catalog_tag_manhwa => 'Manhwa';

  @override
  String get catalog_tag_manhua => 'Manhua';

  @override
  String get catalog_tag_webtoon => 'Webtoon';

  @override
  String get catalog_tag_comics => 'Comics';

  @override
  String get catalog_tag_novel => 'Novel';

  @override
  String get catalog_tag_anime => 'Anime';

  @override
  String get catalog_tag_animation => 'Animation';

  @override
  String get catalog_tag_movies => 'Movies';

  @override
  String get catalog_tag_series => 'Series';

  @override
  String get catalog_tag_documentary => 'Documentaries';

  @override
  String get catalog_tag_jav => 'JAV';

  @override
  String get catalog_tag_music => 'Music';

  @override
  String get catalog_tag_game => 'Games';

  @override
  String get catalog_tag_action => 'Action';

  @override
  String get catalog_tag_adventure => 'Adventure';

  @override
  String get catalog_tag_fantasy => 'Fantasy';

  @override
  String get catalog_tag_science_fiction => 'Sci-Fi';

  @override
  String get catalog_tag_romance => 'Romance';

  @override
  String get catalog_tag_mystery => 'Mystery';

  @override
  String get catalog_tag_drama => 'Drama';

  @override
  String get catalog_tag_comedy => 'Comedy';

  @override
  String get catalog_tag_horror => 'Horror';

  @override
  String get catalog_tag_thriller => 'Thriller';

  @override
  String get catalog_tag_historical => 'Historical';

  @override
  String get catalog_tag_slice_of_life => 'Slice of Life';

  @override
  String get catalog_tag_mecha => 'Mecha';

  @override
  String get catalog_tag_sports => 'Sports';

  @override
  String get catalog_tag_multilingual => 'Multilingual';

  @override
  String get catalog_tag_french => 'French';

  @override
  String get catalog_tag_english => 'English';

  @override
  String get catalog_tag_spanish => 'Spanish';

  @override
  String get catalog_tag_german => 'German';

  @override
  String get catalog_tag_italian => 'Italian';

  @override
  String get catalog_tag_portuguese => 'Portuguese';

  @override
  String get catalog_tag_japanese => 'Japanese';

  @override
  String get catalog_tag_korean => 'Korean';

  @override
  String get catalog_tag_chinese => 'Chinese';

  @override
  String get catalog_tag_arabic => 'Arabic';

  @override
  String get catalog_tag_russian => 'Russian';

  @override
  String get catalog_tag_turkish => 'Turkish';

  @override
  String get catalog_tag_thai => 'Thai';

  @override
  String get catalog_tag_indonesian => 'Indonesian';

  @override
  String get catalog_tag_hindi => 'Hindi';

  @override
  String get catalog_tag_vietnamese => 'Vietnamese';

  @override
  String get catalog_tag_polish => 'Polish';

  @override
  String get catalog_tag_dutch => 'Dutch';

  @override
  String get catalog_tag_featured => 'Featured';

  @override
  String get catalog_tag_new => 'New';

  @override
  String get catalog_tag_popular => 'Popular';

  @override
  String get catalog_tag_trending => 'Trending';

  @override
  String get catalog_shelf_watch_popular => 'Popular to watch';

  @override
  String get catalog_shelf_read_popular => 'Popular to read';

  @override
  String get catalog_shelf_new_watch => 'New watch sources';

  @override
  String get catalog_shelf_new_read => 'New reading sources';

  @override
  String get catalog_shelf_new => 'Recently added';

  @override
  String get catalog_shelf_recommended => 'Recommended for you';

  @override
  String get catalog_shelf_featured => 'Featured';

  @override
  String get catalog_shelf_movies => 'Movies';

  @override
  String get catalog_shelf_series => 'Series';

  @override
  String get catalog_shelf_anime => 'Anime';

  @override
  String get catalog_shelf_animation => 'Animation';

  @override
  String get catalog_shelf_documentaries => 'Documentaries';

  @override
  String get catalog_shelf_science_fiction => 'Sci-Fi';

  @override
  String get catalog_shelf_fantasy => 'Fantasy';

  @override
  String get catalog_shelf_action_adventure => 'Action and adventure';

  @override
  String get catalog_shelf_romance_mystery => 'Romance and mystery';

  @override
  String get catalog_shelf_manga => 'Manga';

  @override
  String get catalog_shelf_manga_manhwa => 'Manga and manhwa';

  @override
  String get catalog_shelf_manhwa => 'Manhwa';

  @override
  String get catalog_shelf_manhua => 'Manhua';

  @override
  String get catalog_shelf_webtoons => 'Webtoons';

  @override
  String get catalog_shelf_comics => 'Comics and graphic novels';

  @override
  String get catalog_shelf_novels => 'Novels and light novels';

  @override
  String get catalog_shelf_french => 'French sources';

  @override
  String get catalog_shelf_english => 'English sources';

  @override
  String get catalog_shelf_multilingual => 'Multilingual sources';

  @override
  String get catalog_shelf_scifi_fantasy => 'Sci-Fi and fantasy';

  @override
  String get catalog_shelf_music => 'Music';

  @override
  String get catalog_shelf_games => 'Games';

  @override
  String get catalog_shelf_order_curated =>
      'Featured first, then most recently added';

  @override
  String get catalog_shelf_empty => 'No extension matches this selection yet.';

  @override
  String get catalog_see_all => 'See all';

  @override
  String get catalog_back => 'Back';

  @override
  String get catalog_error => 'Could not load the catalogue.';

  @override
  String marketplace_all_extensions(Object type) {
    return 'All $type extensions';
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
  String get marketplace_explore_by_language => 'Explore by language';

  @override
  String get marketplace_whole_catalogue => 'The whole catalogue';

  @override
  String get catalog_shelf_adult_watch => 'Midnight World';

  @override
  String get catalog_shelf_adult_read => 'Midnight Library';

  @override
  String get catalog_shelf_for_you_watch => 'For you · to watch';

  @override
  String get catalog_shelf_for_you_read => 'For you · to read';

  @override
  String get catalog_card_see_more => 'See more';

  @override
  String get catalog_card_see_less => 'See less';

  @override
  String get catalog_card_open_site => 'Open the website';

  @override
  String get catalog_card_open_site_unavailable =>
      'No website for this extension';

  @override
  String get plugins_section_builtin => 'Built-in plugins';

  @override
  String get plugins_section_engines => 'Components and engines';

  @override
  String get plugins_section_empty => 'No plugin available.';

  @override
  String get plugins_nfile_title => 'NFile — file manager';

  @override
  String get plugins_nfile_description =>
      'Built-in file explorer with players and management tools.';

  @override
  String get plugins_smart_library_description =>
      'Scans and organises the videos and mangas already on the device.';

  @override
  String get plugins_ffmpeg_bundled =>
      'Bundled with the app — no installation required.';

  @override
  String get plugins_mpv_description =>
      'Downloads only mpv.conf, input.conf and the scripts.';

  @override
  String get plugins_action_open => 'Open';

  @override
  String get plugins_action_info => 'Info';

  @override
  String get plugins_action_install => 'Install';

  @override
  String get plugins_action_close => 'Close';

  @override
  String get plugins_mpv_config_exception =>
      'The MPV configuration folder is unavailable.';

  @override
  String get plugins_ffmpeg_title => 'FFmpeg';

  @override
  String get plugins_ffmpeg_info =>
      'FFmpeg is bundled with Watchtower. It performs a single stream-copy mux of the downloaded HLS fragments (MPEG-TS or fMP4) into the final MP4.\n\nNo download, no separate runtime: assembly works offline and does not depend on an external executable.';

  @override
  String get plugins_smart_library_title => 'Smart Library';

  @override
  String get plugins_mpv_title => 'MPV configuration';

  @override
  String get plugins_music_title => 'Music plugins';

  @override
  String get catalog_tab_for_you => 'For you';

  @override
  String get catalog_tab_watch => 'Watch';

  @override
  String get catalog_tab_manga => 'Manga';

  @override
  String get catalog_tab_music => 'Music';

  @override
  String get catalog_tab_games => 'Games';

  @override
  String get catalog_tab_novels => 'Novels';

  @override
  String get marketplace_search_results => 'Search results';

  @override
  String get marketplace_empty_search_title => 'No extension found';

  @override
  String get marketplace_empty_catalog_title => 'No extension available';

  @override
  String get marketplace_empty_search_hint =>
      'Try another name or refresh the catalogue.';

  @override
  String get marketplace_empty_catalog_hint =>
      'The catalogue is empty right now. Try again later.';

  @override
  String get marketplace_empty_semantics => 'Empty catalogue';

  @override
  String get marketplace_settings_tooltip => 'Marketplace settings';

  @override
  String get marketplace_search_hint => 'Search extensions';

  @override
  String get marketplace_recent_searches => 'Recent searches';

  @override
  String get marketplace_popular_searches => 'Popular searches';

  @override
  String get marketplace_browse_by_category => 'Browse by category';

  @override
  String get marketplace_nsfw_gate_title => 'Adult content hidden';

  @override
  String get marketplace_nsfw_gate_body =>
      'Enable adult content in the preferences to show these extensions.';

  @override
  String get marketplace_nsfw_gate_show => 'Show adult content';

  @override
  String get marketplace_account_title => 'Watchtower account';

  @override
  String get marketplace_manage_installed => 'Manage installed extensions';

  @override
  String get marketplace_preferences => 'Marketplace preferences';

  @override
  String get marketplace_help_feedback => 'Help and feedback';

  @override
  String get marketplace_details_title => 'Details';

  @override
  String marketplace_coming_soon(Object label) {
    return '$label is coming soon.';
  }

  @override
  String marketplace_source_blurb(Object language, Object kind) {
    return '$language source to discover $kind in Watchtower.';
  }

  @override
  String get marketplace_kind_anime => 'anime and series';

  @override
  String get marketplace_kind_manga => 'mangas and comics';

  @override
  String get marketplace_kind_novel => 'novels and light novels';

  @override
  String get marketplace_kind_music => 'music and audio';

  @override
  String get marketplace_kind_default => 'content';

  @override
  String get marketplace_lang_french => 'French';

  @override
  String get marketplace_lang_english => 'English';

  @override
  String get marketplace_lang_multilingual => 'multilingual';

  @override
  String get marketplace_unknown_size => 'Unknown size';

  @override
  String marketplace_reviews_count(Object count) {
    return '$count reviews';
  }

  @override
  String get marketplace_reviews_unavailable => 'No reviews available';

  @override
  String get marketplace_update => 'Update';

  @override
  String get marketplace_extension_installed => 'Extension installed';

  @override
  String get marketplace_about_extension => 'About this extension';

  @override
  String get marketplace_info_access => 'Access';

  @override
  String get marketplace_info_community => 'Community';

  @override
  String get marketplace_info_repo => 'Repository and provenance';

  @override
  String get marketplace_official_repo_note =>
      'Updated through the official Watchtower Extensions repository.';

  @override
  String get marketplace_ntfy_signals => 'ntfy signals';

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
      other: '$count extensions installed',
      one: '$count extension installed',
    );
    return '$_temp0';
  }

  @override
  String get marketplace_info_information => 'Information';

  @override
  String get marketplace_info_technology => 'Technology';

  @override
  String get marketplace_info_reading => 'Reading';

  @override
  String get marketplace_info_catalog => 'Catalogue';

  @override
  String get marketplace_info_content => 'Content';

  @override
  String get marketplace_access_required => 'Account required';

  @override
  String get marketplace_aggregator => 'Aggregator';

  @override
  String get marketplace_comments => 'Comments';

  @override
  String marketplace_available_version(Object version) {
    return 'available v$version';
  }

  @override
  String get marketplace_catalog_unavailable => 'The catalogue is unavailable';

  @override
  String get marketplace_check_connection =>
      'Check your connection and try again.';

  @override
  String marketplace_update_available(String version) {
    return 'Update available · v$version';
  }

  @override
  String marketplace_installed_version_label(String version) {
    return 'Installed v$version';
  }

  @override
  String get marketplace_info_size => 'Size';

  @override
  String get marketplace_load_error => 'Could not load the marketplace';

  @override
  String get marketplace_search_extension_hint => 'Search an extension…';

  @override
  String get marketplace_search_apps_hint => 'Search apps and games…';

  @override
  String get marketplace_filter_extensions => 'Filter extensions';

  @override
  String get marketplace_search_language_hint => 'Search a language…';

  @override
  String get marketplace_browse_extensions => 'Browse extensions';

  @override
  String get marketplace_clear_all_filters => 'Clear all';

  @override
  String get marketplace_installed_only => 'Installed only';

  @override
  String get marketplace_installed_only_sub =>
      'Hide extensions that are not installed';

  @override
  String get marketplace_updates_available => 'Updates available';

  @override
  String get marketplace_updates_available_sub =>
      'Extensions with a new version';

  @override
  String get marketplace_all_option => '(all)';

  @override
  String get marketplace_nothing_to_install => 'Nothing to install';

  @override
  String get marketplace_check_updates_subtitle => 'When the app starts';

  @override
  String get marketplace_auto_update_subtitle => 'Without confirmation';

  @override
  String get marketplace_adult_content_title => '18+ content';

  @override
  String get marketplace_adult_content_subtitle => 'Show NSFW extensions';

  @override
  String get marketplace_manage_repositories => 'Manage repositories';

  @override
  String get marketplace_reload_catalogue => 'Reload the catalogue';

  @override
  String get marketplace_bulk_install => 'Bulk install';

  @override
  String get marketplace_ntfy_error_subtitle => 'Push an alert on error';

  @override
  String get plugins_third_party_confirm_title => 'Install this plugin?';

  @override
  String plugins_third_party_confirm_body(Object owner) {
    return 'Third-party plugin from $owner.\n\nIt will access the APIs declared in its manifest.\n\nLong-press the card to uninstall.';
  }

  @override
  String get plugins_auth_required_body =>
      'This plugin requires authentication.\nOpen Music Hub → Settings → Sources, select this plugin as the default source, then tap “Sign in”.';

  @override
  String marketplace_error_load_failed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Failed to load $count repositories',
      one: 'Failed to load $count repository',
    );
    return '$_temp0';
  }

  @override
  String marketplace_error_http(Object status, Object url) {
    return 'HTTP $status for $url';
  }

  @override
  String marketplace_error_empty_response(Object url) {
    return 'Empty response for $url';
  }

  @override
  String marketplace_error_plugin_not_registered(Object name) {
    return 'Plugin $name was not registered after the download.';
  }

  @override
  String marketplace_error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String marketplace_error_uninstall(Object error) {
    return 'Uninstall error: $error';
  }

  @override
  String marketplace_error_not_installed(Object name) {
    return 'Extension $name could not be installed. No active source was recorded.';
  }

  @override
  String marketplace_error_layout_not_saved(Object name) {
    return 'The UI layout of $name was not saved.';
  }

  @override
  String marketplace_error_layout_unreadable(Object name) {
    return 'The UI layout of $name is unreadable.';
  }

  @override
  String marketplace_error_categories_not_saved(Object name) {
    return 'The categories of $name were not saved.';
  }

  @override
  String marketplace_error_content_types_not_saved(Object name) {
    return 'The content types of $name were not saved.';
  }

  @override
  String get marketplace_error_audio_plugin_missing =>
      'Audio plugin not found in local storage.';

  @override
  String get marketplace_error_extension_missing =>
      'Extension not found in local storage.';

  @override
  String marketplace_uninstall_title(Object name) {
    return 'Uninstall $name';
  }

  @override
  String get marketplace_uninstall_body =>
      'The extension will be uninstalled. It can be reinstalled at any time.';

  @override
  String marketplace_uninstalled_toast(Object name) {
    return '$name uninstalled';
  }

  @override
  String marketplace_bulk_install_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Install $count extensions',
      one: 'Install $count extension',
    );
    return '$_temp0';
  }

  @override
  String marketplace_bulk_install_confirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions to install',
      one: '$count extension to install',
    );
    return '$_temp0';
  }

  @override
  String get marketplace_settings_section_behavior => 'Behavior';

  @override
  String get marketplace_settings_section_repositories => 'Repositories';

  @override
  String get marketplace_settings_section_cache => 'Cache';

  @override
  String get marketplace_settings_section_actions => 'Actions';

  @override
  String get marketplace_force_reload => 'Force reload (bypass cache)';

  @override
  String marketplace_installed_toast(Object name) {
    return '$name installed';
  }

  @override
  String get marketplace_repository => 'Repository';

  @override
  String get marketplace_default_metadata_provider =>
      'Default metadata provider';

  @override
  String get marketplace_currently_default => 'Currently the default';

  @override
  String get marketplace_set_default_provider => 'Set as default provider';

  @override
  String get marketplace_default_audio_source => 'Default audio source';

  @override
  String get marketplace_set_default_audio_source =>
      'Set as default audio source';

  @override
  String get marketplace_update_available_short => 'Update available';

  @override
  String get marketplace_with_updates_short => 'With updates';

  @override
  String get marketplace_section_show => 'SHOW';

  @override
  String get marketplace_section_active_filters => 'ACTIVE FILTERS';

  @override
  String get marketplace_advanced_filters => 'Advanced filters';

  @override
  String get marketplace_sort_installed => 'Installed';

  @override
  String marketplace_selected_count(Object count) {
    return '$count selected';
  }

  @override
  String marketplace_progress(Object done, Object total) {
    return '$done / $total processed';
  }

  @override
  String marketplace_failed_count(Object count) {
    return '$count failed';
  }

  @override
  String marketplace_size_kb(Object value) {
    return '$value KB';
  }

  @override
  String marketplace_size_mb(Object value) {
    return '$value MB';
  }

  @override
  String get marketplace_kind_subtitles => 'subtitles and caption tracks';

  @override
  String get marketplace_type_subtitles => 'Subtitles';

  @override
  String get marketplace_got_it => 'Got it';

  @override
  String marketplace_installing_progress(Object done, Object total) {
    return 'Installing… $done/$total';
  }

  @override
  String get browse_installing_all => 'Installing all extensions…';

  @override
  String browse_installed_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions installed',
      one: '$count extension installed',
    );
    return '$_temp0';
  }

  @override
  String get browse_uninstall_all_title => 'Uninstall all';

  @override
  String get browse_uninstall_all_body =>
      'Really uninstall every installed extension?';

  @override
  String browse_uninstalled_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions uninstalled',
      one: '$count extension uninstalled',
    );
    return '$_temp0';
  }

  @override
  String get browse_updating_all => 'Updating all extensions…';

  @override
  String browse_updated_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions updated',
      one: '$count extension updated',
    );
    return '$_temp0';
  }

  @override
  String get browse_no_active_source => 'No active source installed.';

  @override
  String browse_opening_source(Object name) {
    return 'Opening \"$name\"…';
  }

  @override
  String get browse_global_search_tooltip =>
      'Global search · long-press = diagnostic';

  @override
  String get browse_more_options => 'More options';

  @override
  String get browse_custom_sections => 'Le mie sezioni';

  @override
  String get browse_marketplace => 'Marketplace';

  @override
  String get browse_how_to_local_source => 'How To — Local Source';

  @override
  String get browse_random_source => 'Random source';

  @override
  String get browse_diagnostic => 'Diagnostic';

  @override
  String get browse_plugins => 'Plugins';

  @override
  String browse_sources_limited(Object lang) {
    return 'Sources limited to $lang + EN';
  }

  @override
  String get browse_all_languages_restored => 'All languages re-enabled';

  @override
  String get marketplace_tag_adult => 'Adult';

  @override
  String get marketplace_sort_alpha => 'A → Z';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get notifications_refresh_tooltip => 'Refresh';

  @override
  String get notifications_load_error => 'Could not load the notifications.';

  @override
  String get notifications_checking_updates => 'Checking for updates…';

  @override
  String get notifications_updates_subtitle =>
      'Your installed extensions have a new version.';

  @override
  String notifications_update_single(Object name) {
    return '$name extension update';
  }

  @override
  String notifications_update_message(Object name) {
    return '$name extension update';
  }

  @override
  String notifications_updates_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extension updates',
      one: '$count extension update',
    );
    return '$_temp0';
  }

  @override
  String get notifications_install_all => 'Install all';

  @override
  String get notifications_install => 'Install';

  @override
  String get notifications_dismiss_update => 'Hide this update';

  @override
  String notifications_updated_toast(Object name) {
    return '$name updated';
  }

  @override
  String notifications_install_failed(Object error) {
    return 'Install failed: $error';
  }

  @override
  String notifications_new_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new extensions published',
      one: '$count new extension published',
    );
    return '$_temp0';
  }

  @override
  String get notifications_new_subtitle =>
      'Discover the latest extensions in the catalogue.';

  @override
  String get notifications_browse_marketplace => 'Browse the Marketplace';

  @override
  String get notifications_hide => 'Hide this notification';

  @override
  String notifications_library_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count library updates',
      one: '$count library update',
    );
    return '$_temp0';
  }

  @override
  String get notifications_library_subtitle => 'New chapters are available.';

  @override
  String get notifications_view_updates => 'View updates';

  @override
  String get notifications_none => 'No new notification';

  @override
  String get marketplace_search_categories_title => 'Browse by category';

  @override
  String get marketplace_search_recommended => 'Recommended';

  @override
  String get marketplace_search_all_results => 'All results';

  @override
  String get marketplace_search_sort => 'Sort';

  @override
  String get marketplace_search_filters => 'Filters';

  @override
  String get marketplace_search_no_results_title => 'No result';

  @override
  String get marketplace_search_no_results_body =>
      'Nothing matches your search.';

  @override
  String get marketplace_sort_recent => 'Recently added';

  @override
  String get marketplace_search_sort_title => 'Sort by';

  @override
  String get marketplace_search_suggestions => 'Suggestions';

  @override
  String get marketplace_search_clear => 'Clear';

  @override
  String marketplace_search_results_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get obNext => 'Next';

  @override
  String get obStart => 'Get started';

  @override
  String get obBack => 'Back';

  @override
  String get obContinue => 'Continue';

  @override
  String get obSkipForNow => 'Skip for now';

  @override
  String get obEnterWatchtower => 'Enter Watchtower';

  @override
  String get obPermissionsTitle => 'Permissions';

  @override
  String get obPermissionsSubtitle =>
      'Watchtower needs a few permissions to run properly.';

  @override
  String get obOptionalSection => 'OPTIONAL';

  @override
  String get obPermStorageTitle => 'Storage';

  @override
  String get obPermStorageSubtitle =>
      'Allow full file access for downloads and Smart Library.';

  @override
  String get obPermStorageIosSubtitle =>
      'iOS sandbox access — no action required.';

  @override
  String get obPermNotifTitle => 'Notifications';

  @override
  String get obPermNotifSubtitle => 'Downloads and library update alerts.';

  @override
  String get obPermInstallTitle => 'App installation';

  @override
  String get obPermInstallSubtitle =>
      'Install APK updates directly from the app.';

  @override
  String get obPermOverlayTitle => 'Overlay / PiP';

  @override
  String get obPermOverlaySubtitle =>
      'Show the video floating over other apps.';

  @override
  String get obPermBatteryTitle => 'No battery restriction';

  @override
  String get obPermBatterySubtitle =>
      'Stops Android from killing background downloads (Doze, standby).';

  @override
  String get obGrant => 'Allow';

  @override
  String get obGranted => 'Granted';

  @override
  String get obShowcaseHeadline =>
      'Anime, manga, novels, music, films, series and games — all in one place.';

  @override
  String get obSloganWatch => 'Watch.';

  @override
  String get obSloganRead => 'Read.';

  @override
  String get obSloganListen => 'Listen.';

  @override
  String get obSloganAll => 'All.';

  @override
  String get obSloganSub => 'One place for everything you love.';

  @override
  String get migTitle => 'Migration';

  @override
  String get migHeadline => 'Bring your library with you.';

  @override
  String get migSpeech =>
      'Coming from Mihon, Aniyomi, Mangayomi or another app? Watchtower reads their backups and folders, then rebuilds your library, categories, reading progress and downloads here.';

  @override
  String get migTabManga => 'Manga';

  @override
  String get migTabAnime => 'Anime';

  @override
  String get migTabUniversal => 'Universal';

  @override
  String get migSearchHint => 'Search an app…';

  @override
  String get migFilterTitle => 'Filter';

  @override
  String get migFilterPlatform => 'Platform';

  @override
  String get migFilterOpenSource => 'Open source only';

  @override
  String get migFilterWithBackup => 'Backup import supported';

  @override
  String get migFilterReset => 'Reset filters';

  @override
  String get migSortTitle => 'Sort';

  @override
  String get migSortName => 'Alphabetically';

  @override
  String get migSortPlatform => 'By platform';

  @override
  String get migMoreTitle => 'Options';

  @override
  String get migMoreSelectAll => 'Select all apps';

  @override
  String get migMoreClear => 'Clear selection';

  @override
  String get migMoreGuide => 'Migration guide';

  @override
  String get migMoreRefresh => 'Refresh';

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
  String get migEmptySearch => 'No app matches your search.';

  @override
  String get migPros => 'Pros';

  @override
  String get migCons => 'Cons';

  @override
  String get migOfficialSite => 'Official site';

  @override
  String get migBackupFormat => 'Backup format';

  @override
  String get migPlatforms => 'Platforms';

  @override
  String get migSupported => 'Import supported';

  @override
  String get migSelect => 'Select';

  @override
  String get migSelected => 'Selected';

  @override
  String get migWhatToImport => 'What to import';

  @override
  String get migImportLibrary => 'Library and categories';

  @override
  String get migImportLibrarySub =>
      'Titles, covers, categories and read state.';

  @override
  String get migImportDownloads => 'Downloaded chapters';

  @override
  String get migImportDownloadsSub =>
      'Copy or move the files Mihon already downloaded.';

  @override
  String get migImportHistory => 'Reading history';

  @override
  String get migImportHistorySub => 'Resume each series where you stopped.';

  @override
  String get migImportSettings => 'App settings';

  @override
  String get migImportSettingsSub => 'Theme, reader and download preferences.';

  @override
  String get migBackupSource => 'Backup file';

  @override
  String get migBackupSourceHint =>
      'Pick the .tachibk backup exported by the app.';

  @override
  String get migPickBackup => 'Choose a file';

  @override
  String get migDownloadFolder => 'Downloads folder';

  @override
  String get migDownloadFolderHint =>
      'The folder where the other app stored its downloads.';

  @override
  String get migPickFolder => 'Choose a folder';

  @override
  String get migNoFile => 'No file selected';

  @override
  String get migFileMode => 'File handling';

  @override
  String get migCopy => 'Copy';

  @override
  String get migCopySub => 'Keeps the original files in place.';

  @override
  String get migMove => 'Move';

  @override
  String get migMoveSub => 'Frees the space the other app used.';

  @override
  String get migScan => 'Scan';

  @override
  String get migScanning => 'Scanning…';

  @override
  String migScanResultLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries in the backup',
      one: '1 entry in the backup',
    );
    return '$_temp0';
  }

  @override
  String migScanResultDownloads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded chapters found',
      one: '1 downloaded chapter found',
    );
    return '$_temp0';
  }

  @override
  String get migScanResultNone => 'Nothing detected yet.';

  @override
  String get migStartImport => 'Start import';

  @override
  String get migImporting => 'Importing…';

  @override
  String get migImportDone => 'Import complete';

  @override
  String migImportLibraryDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries imported',
      one: '1 entry imported',
    );
    return '$_temp0';
  }

  @override
  String migImportDownloadsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads imported',
      one: '1 download imported',
    );
    return '$_temp0';
  }

  @override
  String get migImportFailed => 'The import could not finish.';

  @override
  String get migNeedSelection => 'Pick at least one thing to import.';

  @override
  String get migDetectedApps => 'Apps detected on this device';

  @override
  String get migNoDetectedApps =>
      'No other app data found. You can still pick a backup manually.';

  @override
  String get migFeatureTitle => 'More than a library';

  @override
  String get migFeatureTrackers =>
      'Trackers and AniList/MAL progress follow your titles.';

  @override
  String get migFeatureSync => 'Cloud sync keeps every device aligned.';

  @override
  String get migFeatureExtensions => 'Install extensions to add new sources.';

  @override
  String get migFeatureSmart =>
      'Smart Library rebuilds shelves from your files.';

  @override
  String get migFooterHint =>
      'Everything is processed on your device. Nothing is uploaded.';

  @override
  String get migProMangaReader => 'Manga reading app';

  @override
  String get migProAnimeWatcher => 'Anime watching app';

  @override
  String get migProLightNovelReader => 'Light novel reading app';

  @override
  String get migProBothAnimeManga => 'Supports both anime and manga';

  @override
  String get migProAnimeLnManga => 'Supports anime, light novels and manga';

  @override
  String get migProManySources => 'Many extension sources available';

  @override
  String get migProManySourcesShort => 'Many sources available';

  @override
  String get migProOpenSource => 'Open source';

  @override
  String get migProActivelyDeveloped => 'Actively developed';

  @override
  String get migProLongTrackRecord => 'Long track record';

  @override
  String get migProCrossPlatform =>
      'Cross platform (Android, iOS, Mac, Windows, Linux)';

  @override
  String get migProDesktopPlatforms => 'Supports Windows, Linux and Mac';

  @override
  String get migProOpenExtensionSystem => 'Open extension system';

  @override
  String get migProNiceUi => 'Nice user interface';

  @override
  String get migProIntegration =>
      'Integrates with many other apps (backups and extensions)';

  @override
  String get migProTracker => 'Manga tracker';

  @override
  String get migProTrackReleases => 'Tracks new chapter releases across sites';

  @override
  String get migProEbookOutput => 'Generates e-book output';

  @override
  String get migProBatchZip => 'Batch .zip download';

  @override
  String get migProLargeLibrary => 'Very large library';

  @override
  String get migProMangadexClient => 'Focused MangaDex client';

  @override
  String get migProSameAsMihon => 'Everything Mihon does, plus more';

  @override
  String get migProCombinesForks =>
      'Combines features from several Mihon forks';

  @override
  String get migProEh => 'E-Hentai and ExHentai integration';

  @override
  String get migConAndroidOnly => 'Android only';

  @override
  String get migConDesktopOnly => 'Desktop only';

  @override
  String get migConNeedExtension => 'Need to install an extension to use';

  @override
  String get migConExtensionSeparate => 'Extensions installed separately';

  @override
  String get migConOriginalUnmaintained =>
      'Original repository no longer maintained';

  @override
  String get migConNotIosStore => 'Not in the iOS App Store';

  @override
  String get migConNeedPlugins => 'Need to install plugins to use';

  @override
  String get migConLessPopular => 'Less popular';

  @override
  String get migConNewApp => 'New app, less popular';

  @override
  String get migConOnlyMangadex => 'Only MangaDex content';

  @override
  String get migConCannotReadOffline => 'Cannot read offline';

  @override
  String get migConArchived => 'Original repository archived';

  @override
  String get migConTorrent => 'Depends on a torrent connection';

  @override
  String get migConIosDonors => 'iOS build only for donors';

  @override
  String get migConRaw => 'Manga are untranslated (raw)';

  @override
  String get migConBareboneSearch => 'Bare-bones search and filter';

  @override
  String get migConNotDifferent => 'Not drastically different';

  @override
  String get migConRelativelyNew => 'Relatively new';

  @override
  String get migConMissingNewFeatures =>
      'Missing features added in the parent app';

  @override
  String get migDetectedBackup => 'Backup found';

  @override
  String get migDetectedDownloads => 'Downloads found';

  @override
  String get transfer_title => 'Sala di condivisione';

  @override
  String get transfer_subtitle =>
      'Condividi i tuoi download con altri dispositivi sulla stessa rete WiFi, senza internet.';

  @override
  String transfer_chapters_available(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli disponibili da condividere',
      one: '1 capitolo disponibile da condividere',
    );
    return '$_temp0';
  }

  @override
  String get transfer_join_room => 'UNISCITI ALLA SALA';

  @override
  String get transfer_lan_only => 'Solo LAN / hotspot · nessun server esterno';

  @override
  String get transfer_devices_in_room => 'Dispositivi nella sala';

  @override
  String get transfer_active_downloads => 'Download in corso';

  @override
  String get transfer_completed => 'Completati';

  @override
  String transfer_started_download(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download di $count file avviato',
      one: 'Download di 1 file avviato',
    );
    return '$_temp0';
  }

  @override
  String get transfer_local_room => 'Sala locale';

  @override
  String get transfer_active => 'ATTIVO';

  @override
  String get transfer_my_device => 'Il mio dispositivo';

  @override
  String get transfer_me => 'Io';

  @override
  String transfer_shared_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount manga',
      one: '1 manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · $_temp1 condivisi';
  }

  @override
  String get transfer_searching_devices => 'Ricerca dispositivi…';

  @override
  String get transfer_same_wifi_hint =>
      'Assicurati di essere sulla stessa rete WiFi o hotspot degli altri dispositivi.';

  @override
  String get transfer_loading_catalog => 'Caricamento catalogo…';

  @override
  String get transfer_catalog_unavailable => 'Catalogo non disponibile';

  @override
  String transfer_catalog_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount manga',
      one: '1 manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transfer_browse => 'Sfoglia';

  @override
  String transfer_file_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get transfer_status_done => 'Completato';

  @override
  String get transfer_status_failed => 'Non riuscito';

  @override
  String get transfer_catalog_empty => 'Catalogo vuoto';

  @override
  String get transfer_no_files => 'Nessun file disponibile';

  @override
  String get transfer_select_chapters => 'Seleziona capitoli';

  @override
  String transfer_download_count(Object count) {
    return 'Scarica ($count)';
  }

  @override
  String get transfer_type_anime => 'ANIME';

  @override
  String get transfer_type_novel => 'ROMANZO';

  @override
  String get transfer_type_other => 'ALTRO';

  @override
  String get transfer_type_manga => 'MANGA';

  @override
  String get transfer_howto_title => 'Come trasferire';

  @override
  String get transfer_howto_step1 =>
      'Collega entrambi i dispositivi alla stessa rete WiFi o hotspot.';

  @override
  String get transfer_howto_step2 =>
      'Sull\'altro dispositivo, apri Download → Transfert e unisciti alla sala.';

  @override
  String get transfer_howto_step3 =>
      'Tocca un dispositivo per sfogliarne la libreria, scegli i capitoli e scarica.';

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
  String get transfer_platform_unknown => 'Dispositivo';

  @override
  String get copied => 'Copied';

  @override
  String get copied_to_clipboard => 'Copied to clipboard';

  @override
  String get author_works => 'Works by this author';

  @override
  String get select_range => 'Select range';

  @override
  String get select_all => 'Select all';

  @override
  String get select_invert => 'Invert selection';

  @override
  String get select_none => 'Deselect all';

  @override
  String get download_range => 'Download a range';

  @override
  String get range_start => 'Start';

  @override
  String get range_end => 'End';

  @override
  String get download_range_hint =>
      'Chapters between the two numbers are downloaded, in reading order.';

  @override
  String get invalid_range => 'Invalid range';

  @override
  String get no_comments => 'No comments yet';

  @override
  String get plugins_ffmpeg_ready => 'Verified binary available for HLS files.';

  @override
  String get plugins_ffmpeg_optional =>
      'Optional: direct concatenation is used automatically.';

  @override
  String get browse_global_search_hint => 'Search extensions…';

  @override
  String get browse_intelligent_search => 'Intelligent search';

  @override
  String get browse_intelligent_search_tooltip => 'What is intelligent search?';

  @override
  String get browse_intelligent_search_help =>
      'An extension has its own search: when it does not have the exact title, it often returns near results that are not relevant.\n\nIntelligent search keeps what the extension found, but only shows the results whose name really matches your search. The algorithm is tolerant: “Narufo” finds “Naruto”, and searching by another title works too (for example “Attack on Titan” for “Shingeki no Kyojin”).';

  @override
  String get browse_pinned_sources => 'Pinned sources';

  @override
  String get browse_clear_filters => 'Clear filters';

  @override
  String get browse_filters => 'FILTERS';

  @override
  String get browse_clear => 'Clear';

  @override
  String get browse_content => 'Content';

  @override
  String get browse_all_content => 'All content';

  @override
  String get browse_sfw_only => 'SFW only';

  @override
  String get browse_nsfw_only => 'NSFW only';

  @override
  String get browse_source_type => 'Source type';

  @override
  String get browse_no_source_found => 'No source found';

  @override
  String get browse_no_source_matches_filters =>
      'No source matches\nthe active filters';

  @override
  String get browse_try_another_term => 'Try another search term';

  @override
  String get browse_reset_filters => 'Reset filters';

  @override
  String get browse_retry_intelligently => 'Retry intelligently';

  @override
  String get browse_got_it => 'Got it';

  @override
  String get browse_understood => 'Got it';

  @override
  String get browse_download_what => 'What to download?';

  @override
  String get browse_download_options => 'Download options';

  @override
  String get browse_download_prompt_search =>
      'Run a search to see the titles you can download.';

  @override
  String get browse_from => 'From';

  @override
  String get browse_to => 'To';

  @override
  String get browse_wifi_only => 'Wi-Fi only';

  @override
  String get browse_cbz_archive => 'CBZ archive';

  @override
  String get browse_cbz_archive_subtitle => 'Package each chapter in a .cbz';

  @override
  String browse_connections_count(Object count) {
    return '$count connection(s)';
  }

  @override
  String browse_download_queued(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters queued for download',
      one: '$count chapter queued for download',
    );
    return '$_temp0';
  }

  @override
  String browse_download_failed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get browse_chapter_label => 'Chapter';

  @override
  String get browse_download_no_link => 'This entry has no usable link.';

  @override
  String get browse_download_no_chapters =>
      'No chapter available for this title.';

  @override
  String get browse_download_no_valid_chapter =>
      'No valid chapter to download.';

  @override
  String get browse_section_new => 'New section';

  @override
  String get browse_section_rename => 'Rename section';

  @override
  String get browse_section_rename_short => 'Rename';

  @override
  String browse_section_delete_title(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String get browse_section_delete_body =>
      'The section is deleted. The extensions stay installed.';

  @override
  String get browse_section_name_hint => 'Section name';

  @override
  String get browse_section_empty_title => 'No section';

  @override
  String get browse_section_empty_body =>
      'Create a section (e.g. “Hentai”) then add the extensions you want to group in it.';

  @override
  String browse_section_extension_count(Object count) {
    return '$count extension(s)';
  }

  @override
  String get browse_section_add_extensions => 'Add extensions';

  @override
  String get browse_section_detail_empty =>
      'This section is empty. Add extensions to find them here.';

  @override
  String get browse_section_picker_title => 'Section extensions';

  @override
  String get browse_section_no_extensions =>
      'No extension installed for this type.';

  @override
  String browse_section_add_to(Object name) {
    return 'Add “$name” to a section';
  }

  @override
  String get browse_section_create_first =>
      'First create a section from the ⋮ menu of the Explorer.';

  @override
  String get browse_section_default_name => 'Section';

  @override
  String get browse_validate => 'Validate';

  @override
  String get browse_remove_tooltip => 'Remove';

  @override
  String get browse_section_options => 'Section options';

  @override
  String get browse_section_enable => 'Enable section';

  @override
  String get browse_section_disable => 'Disable section';

  @override
  String get browse_section_pin => 'Pin section';

  @override
  String get browse_section_unpin => 'Unpin section';

  @override
  String get browse_load_extensions_failed => 'Could not load extensions';

  @override
  String get browse_check_connection => 'Retry after checking your connection.';

  @override
  String get browse_install_from_marketplace =>
      'Install an extension from the Marketplace';

  @override
  String get browse_go_to_market => 'Go to Marketplace';

  @override
  String get browse_no_matching_extension =>
      'No extension matches the search or the filters.';

  @override
  String get browse_scanning_extensions => 'Scanning extensions…';

  @override
  String get browse_extension_settings => 'Extension settings';

  @override
  String get browse_pin => 'Pin';

  @override
  String get browse_unpin => 'Unpin';

  @override
  String get browse_filter_installed => 'Installed extensions';

  @override
  String get browse_filter_active_only => 'Active sources only';

  @override
  String get browse_filter_content_nsfw => 'Content and NSFW';

  @override
  String get browse_filter_all_languages => 'All languages';

  @override
  String browse_filter_language_prefix(Object code) {
    return 'Language: $code';
  }

  @override
  String get browse_filter_tags => 'Extension tags';

  @override
  String browse_filter_tags_count(Object count) {
    return '$count tag(s) selected';
  }

  @override
  String get browse_filter_done => 'Done';

  @override
  String get browse_filter_clear_search => 'Clear search';

  @override
  String get browse_filter_search_installed => 'Search an installed extension';

  @override
  String get browse_tag_cloudflare => 'Cloudflare';

  @override
  String get browse_tag_account => 'Account required';

  @override
  String get browse_tag_drm => 'DRM';

  @override
  String get browse_tag_aggregator => 'Aggregator';

  @override
  String get browse_tag_comments => 'Comments';

  @override
  String get browse_tag_torrent => 'Torrent';

  @override
  String get browse_tag_update => 'Update available';

  @override
  String get browse_tag_javascript => 'JavaScript';

  @override
  String get browse_tag_dart => 'Dart';

  @override
  String get browse_url_copied => 'URL copied!';

  @override
  String browse_launch_failed(Object url) {
    return 'Could not launch $url';
  }

  @override
  String get browse_no_local_layout =>
      'No local layout available for this extension.';

  @override
  String get browse_layout_root_object => 'The layout root must be an object.';

  @override
  String get browse_save_card_failed => 'Could not save the search card.';

  @override
  String get browse_search_card_saved => 'Search card saved.';

  @override
  String browse_search_layout_invalid(Object error) {
    return 'Invalid search layout: $error';
  }

  @override
  String get browse_invalid_site_url => 'Invalid site URL.';

  @override
  String get browse_login_open_failed => 'Could not open the login page.';

  @override
  String get browse_session_cleared => 'Session cleared for this extension.';

  @override
  String get browse_session_clear_failed =>
      'Could not clear this extension’s session.';

  @override
  String get browse_session_checking => 'Checking connection…';

  @override
  String get browse_session_logging_in => 'Signing in…';

  @override
  String get browse_session_logging_out => 'Signing out…';

  @override
  String get browse_session_saved => 'Site session saved';

  @override
  String browse_session_connected(Object identity) {
    return 'Connected: $identity';
  }

  @override
  String get browse_session_not_connected => 'Not connected';

  @override
  String get browse_session_unavailable => 'Connection status unavailable';

  @override
  String get browse_check_connection_short => 'Check connection';

  @override
  String get browse_account_connected => 'Connected account';

  @override
  String get browse_account_fallback => 'Account';

  @override
  String get browse_no_favorites => 'No favorite available.';

  @override
  String get browse_untitled => 'Untitled';

  @override
  String browse_more_favorites(Object count) {
    return '+$count more favorites';
  }

  @override
  String browse_expires_on(Object date) {
    return 'Expires $date';
  }

  @override
  String get browse_details_unavailable => 'Details unavailable';

  @override
  String get browse_premium_status => 'Premium status';

  @override
  String get browse_status_unavailable => 'Status unavailable';

  @override
  String get browse_status_active => 'Active';

  @override
  String get browse_status_inactive => 'Inactive';

  @override
  String get browse_favorites => 'Favorites';

  @override
  String get browse_edit_base_url => 'Edit base URL';

  @override
  String get browse_base_url => 'Base URL';

  @override
  String get browse_base_url_updated => 'URL updated!';

  @override
  String get browse_base_url_undefined => 'Base URL not set.';

  @override
  String get browse_import_cookies => 'Import cookies';

  @override
  String get browse_cookies_format =>
      'Paste cookies as: key=value; key2=value2';

  @override
  String get browse_cookies_hint => 'session=abc123; token=xyz789';

  @override
  String get browse_cookies_imported => 'Cookies imported!';

  @override
  String get browse_cookies_import_failed => 'Error importing cookies.';

  @override
  String get browse_cookies_none_available =>
      'No cookie available for this extension.';

  @override
  String get browse_cookies_copied => 'Cookies copied!';

  @override
  String get browse_cookies_none_stored =>
      'No stored cookie for this extension.';

  @override
  String get browse_export_cookies => 'Export cookies';

  @override
  String get browse_stored_cookies => 'Stored cookies';

  @override
  String get browse_user_agent => 'User-Agent';

  @override
  String get browse_user_agent_help =>
      'Leave empty to use the default User-Agent.';

  @override
  String get browse_reset => 'Reset';

  @override
  String get browse_user_agent_reset => 'User-Agent reset.';

  @override
  String get browse_user_agent_updated => 'User-Agent updated!';

  @override
  String get browse_clear_data_title => 'Clear data?';

  @override
  String get browse_clear_data_body =>
      'This will delete all preferences, cookies and data associated with this extension.';

  @override
  String get browse_clear_data_confirm => 'Clear';

  @override
  String get browse_data_cleared => 'Data cleared!';

  @override
  String get browse_clear_cache_title => 'Clear cache?';

  @override
  String get browse_clear_cache_body =>
      'This reloads the extension preferences from the local database and tries to invalidate this source’s HTTP cache. Cookies are not affected.';

  @override
  String get browse_cache_emptied => 'Empty';

  @override
  String get browse_prefs_reloaded =>
      'Preferences reloaded. Reopen the source to refresh the cache.';

  @override
  String get browse_http_headers => 'HTTP headers';

  @override
  String get browse_no_headers => 'No header defined.';

  @override
  String get browse_headers_copied => 'Headers copied!';

  @override
  String get browse_extension_missing =>
      'This extension no longer exists in local storage.';

  @override
  String get browse_extension_uninstalled => 'Extension uninstalled.';

  @override
  String browse_uninstall_failed(Object error) {
    return 'Error while uninstalling: $error';
  }

  @override
  String get browse_uninstall_extension => 'Uninstall extension';

  @override
  String get browse_cookies_deleted => 'Cookies deleted!';

  @override
  String get browse_import_cookie => 'Import cookie';

  @override
  String get browse_view_cookies => 'View cookies';

  @override
  String get browse_clear_cookies => 'Clear cookies';

  @override
  String get browse_clear_cache_short => 'Clear cache';

  @override
  String get browse_clear_data_short => 'Clear data';

  @override
  String get browse_edit_url => 'Edit URL';

  @override
  String get browse_view_headers => 'View headers';

  @override
  String get browse_edit_user_agent => 'Edit User-Agent';

  @override
  String get browse_obsolete => 'Outdated';

  @override
  String get browse_not_installed => 'Not installed';

  @override
  String get browse_account_required => 'Account required';

  @override
  String get browse_repository => 'Repository';

  @override
  String get browse_available => 'Available';

  @override
  String get browse_account_and_features => 'Account and features';

  @override
  String get browse_account_desc =>
      'The connection and displayed information are specific to this extension. The session data used by its requests stays separate.';

  @override
  String get browse_account_desc_generic =>
      'The displayed information is provided by the methods declared by this extension.';

  @override
  String get browse_sign_in => 'Sign in';

  @override
  String get browse_clear_session => 'Clear session';

  @override
  String get browse_home_layout => 'Home layout';

  @override
  String get browse_edit_visually => 'Edit visually';

  @override
  String get browse_search_results => 'Search results';

  @override
  String get browse_choose_result_card => 'Choose a result card';

  @override
  String get browse_extension_word => 'Extension';

  @override
  String get browse_open_settings => 'Open settings';

  @override
  String get browse_diag_export_report => 'Export report';

  @override
  String browse_diag_files_count(Object count) {
    return '$count files';
  }

  @override
  String get browse_diag_summary_view => 'Summary view';

  @override
  String get browse_diag_view_raw => 'View raw report';

  @override
  String get browse_diag_copy => 'Copy';

  @override
  String browse_diag_raw_report(Object format) {
    return 'Raw report — $format';
  }

  @override
  String browse_diag_chars_count(Object count) {
    return '$count characters';
  }

  @override
  String get browse_diag_tab_extension => 'Extension';

  @override
  String get browse_diag_tab_detail => 'Detail';

  @override
  String get browse_diag_in_progress => 'Diagnostic in progress…';

  @override
  String get browse_diag_waiting => 'Waiting for diagnostic';

  @override
  String get browse_diag_test_extension => 'Test this extension';

  @override
  String get browse_diag_interrupted =>
      'Diagnostic interrupted — some steps could not run.';

  @override
  String get browse_diag_retest => 'Retest this extension';

  @override
  String browse_diag_results_count(Object count) {
    return '$count results';
  }

  @override
  String browse_diag_logs(Object label) {
    return 'LOGS — $label';
  }

  @override
  String get browse_diag_no_trace => 'No trace for this step.';

  @override
  String browse_diag_sources_count(Object count) {
    return '$count sources';
  }

  @override
  String browse_diag_page_of(Object page, Object total) {
    return 'Page $page / $total';
  }

  @override
  String get browse_diag_image_unreachable => 'Image unreachable';

  @override
  String get browse_diag_open_detail => 'Open detail';

  @override
  String get browse_diag_no_errors => 'No error detected on the steps.';

  @override
  String browse_diag_running(Object label) {
    return 'Diagnostic $label in progress…';
  }

  @override
  String browse_diag_title(Object label) {
    return 'Diagnostic $label';
  }

  @override
  String get browse_diag_no_extension_installed => 'No extension installed';

  @override
  String get browse_diag_change_filters =>
      'Change the search or the filters from the Panel.';

  @override
  String get browse_diag_no_extension_selected => 'No extension selected';

  @override
  String get browse_diag_no_results_yet => 'No results yet';

  @override
  String get browse_diag_no_report => 'No report';

  @override
  String get browse_diag_control_panel => 'Control panel';

  @override
  String get browse_diag_all => 'All';

  @override
  String get browse_diag_everything => 'Everything';

  @override
  String get browse_diag_sfw => 'SFW';

  @override
  String get browse_diag_only_errors => 'Show only errors';

  @override
  String get browse_diag_only_tested => 'Show only tested extensions';

  @override
  String get browse_diag_canceling => 'Canceling…';

  @override
  String get browse_diag_panel => 'Panel';

  @override
  String get browse_diag_results => 'Results';

  @override
  String get browse_diag_all_respond => 'All sources respond ✓';

  @override
  String browse_diag_unanalyzed(Object count) {
    return '$count not analyzed';
  }

  @override
  String browse_diag_remaining(Object count) {
    return '$count remaining';
  }

  @override
  String get browse_diag_restart => 'Restart';

  @override
  String get browse_diag_err_short => 'Err.';

  @override
  String get browse_diag_tested => 'Tested';

  @override
  String get browse_create_title => 'Create an extension';

  @override
  String get browse_create_language => 'LANGUAGE';

  @override
  String get browse_create_information => 'INFORMATION';

  @override
  String get browse_create_name => 'Name';

  @override
  String get browse_create_name_hint => 'e.g. myAnime';

  @override
  String get browse_create_api_url => 'API URL (optional)';

  @override
  String get browse_create_icon_url => 'Icon URL';

  @override
  String get browse_create_notes => 'Notes';

  @override
  String get browse_create_notes_hint => 'e.g. requires a connection';

  @override
  String get browse_create_type => 'TYPE';

  @override
  String get browse_create_source => 'Source';

  @override
  String get browse_create_lang_iso => 'Language (ISO code)';

  @override
  String get browse_create_lang_hint => 'e.g. fr, en, ja';

  @override
  String get browse_create_exists => 'This extension name already exists.';

  @override
  String get browse_create_native_recommended => 'Native · Recommended';

  @override
  String get browse_create_js_universal => 'Universal JS';

  @override
  String get browse_layout_format => 'Format (indented)';

  @override
  String get browse_layout_minify => 'Minify';

  @override
  String get browse_layout_save => 'Save layout';

  @override
  String get browse_layout_placeholder => 'The layout JSON will appear here';

  @override
  String get browse_layout_saving => 'Saving…';

  @override
  String get browse_layout_wrap => 'Word wrap';

  @override
  String get browse_layout_numbers => 'Numbers';

  @override
  String get browse_layout_left => 'Left';

  @override
  String get browse_layout_center => 'Center';

  @override
  String get browse_code_import_file => 'Import a file';

  @override
  String browse_code_file_imported(Object name) {
    return 'File imported: $name';
  }

  @override
  String browse_code_import_error(Object error) {
    return 'Import error: $error';
  }

  @override
  String get browse_code_save => 'Save';

  @override
  String get browse_code_saved => 'Saved';

  @override
  String get browse_code_clear_logs => 'Clear logs';

  @override
  String get browse_pref_setting => 'Setting';

  @override
  String get browse_pref_choice => 'Choice';

  @override
  String get browse_pref_multi_choice => 'Multiple choice';

  @override
  String browse_anime_episode(Object number) {
    return 'Episode $number';
  }

  @override
  String browse_anime_play_failed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get browse_anime_episode_sources => 'Episode sources';

  @override
  String get browse_anime_play_episode => 'Play this episode';

  @override
  String browse_local_how_to_title(Object type) {
    return 'Local $type — How to use';
  }

  @override
  String get browse_alternative => 'Alternative';

  @override
  String get browse_close => 'Close';

  @override
  String get browse_copy => 'Copy';

  @override
  String browse_diag_steps_header(Object media) {
    return 'Steps — Popular · Latest · Detail · $media';
  }

  @override
  String get browse_diag_videos => 'Videos';

  @override
  String get browse_diag_pages => 'Pages';

  @override
  String get browse_diag_not_tested => 'not tested';

  @override
  String browse_diag_lang_filter(Object name) {
    return 'Language: $name';
  }

  @override
  String browse_diag_type_filter(Object name) {
    return 'Type: $name';
  }

  @override
  String get browse_diag_nsfw_only => 'NSFW only';

  @override
  String get browse_diag_sfw_only => 'SFW only';

  @override
  String get browse_diag_all_extensions => 'All extensions';

  @override
  String browse_diag_notify_running(Object label) {
    return 'Diagnostic $label in progress…';
  }

  @override
  String browse_diag_notify_title(Object label) {
    return 'Diagnostic $label';
  }

  @override
  String browse_diag_cancelled(Object done, Object total) {
    return 'Diagnostic cancelled — $done / $total analyzed.';
  }

  @override
  String browse_diag_finished(Object failed, Object ok) {
    return 'Diagnostic finished — $ok OK · $failed failed.';
  }

  @override
  String get browse_diag_cancelling_snack => 'Canceling the diagnostic…';

  @override
  String browse_diag_retest_cancelled(Object name) {
    return 'Retest cancelled for $name.';
  }

  @override
  String browse_diag_retest_ok(Object name) {
    return '✅ $name now responds correctly.';
  }

  @override
  String browse_diag_retest_fail(Object name) {
    return '❌ $name still fails — see the step logs.';
  }

  @override
  String get browse_diag_no_report_available =>
      'No report available — run a diagnostic.';

  @override
  String browse_diag_report_copied(Object format) {
    return '$format report copied ✓';
  }

  @override
  String get browse_diag_no_extension_selected_snack =>
      'No extension selected — enable at least one.';

  @override
  String get browse_diag_no_extension_filter => 'No extension for this filter.';

  @override
  String get browse_diag_ready => 'Ready to diagnose';

  @override
  String get browse_diag_paused => 'Paused';

  @override
  String get browse_diag_running_state => 'Diagnostic in progress';

  @override
  String get browse_diag_interrupted_state => 'Interrupted';

  @override
  String get browse_diag_complete => 'Diagnostic finished';

  @override
  String get browse_diag_complete_errors => 'Finished with errors';

  @override
  String get browse_diag_ready_short => 'Ready';

  @override
  String browse_diag_extensions_analyzed(
    Object done,
    Object elapsed,
    Object total,
  ) {
    return '$done / $total extensions analyzed · $elapsed';
  }

  @override
  String browse_diag_select_hint(Object count) {
    return 'Check the extensions to test · $count selected';
  }

  @override
  String get browse_diag_panel_type => 'Type';

  @override
  String get browse_diag_panel_content => 'Content';

  @override
  String get browse_diag_panel_options => 'Options';

  @override
  String get browse_diag_resume => 'Resume';

  @override
  String get browse_diag_pause => 'Pause';

  @override
  String get browse_diag_start => 'Start the diagnostic';

  @override
  String get browse_diag_view_extensions => 'View extensions';

  @override
  String get browse_diag_open_panel => 'Open the Panel';

  @override
  String get browse_diag_back => 'Back';

  @override
  String get browse_diag_add_extensions =>
      'Add extensions from the Marketplace before running a diagnostic.';

  @override
  String get browse_diag_no_extension_filters =>
      'No extension for these filters';

  @override
  String get browse_diag_touch_extension =>
      'Tap an extension in the list to show its steps, logs and detailed errors.';

  @override
  String get browse_diag_results_appear =>
      'Analyzed extensions will appear here with their steps and logs.';

  @override
  String get browse_diag_run_for_report =>
      'Run a diagnostic to get a detailed, exportable report (Markdown, JSON, TXT, CSV).';

  @override
  String browse_diag_step_failed(Object count) {
    return '$count step(s) failed — open each step for the logs.';
  }

  @override
  String get browse_diag_extension_word => 'Extension';

  @override
  String get browse_diag_analyzing => 'Analyzing…';

  @override
  String get browse_diag_waiting_short => 'Waiting…';

  @override
  String get browse_local_folder => '📁 Local folder';

  @override
  String get browse_local_formats => '🗂️ Supported formats';

  @override
  String get browse_local_organization => '🗃️ Folder organization';

  @override
  String get browse_local_recommended_structure => 'Recommended structure:';

  @override
  String get browse_local_tips => 'Tips';

  @override
  String get browse_local_default => 'Default';

  @override
  String get browse_local_alt => 'Alternative';

  @override
  String browse_local_default_path(Object type) {
    return 'On my iPhone → Watchtower → Local/$type';
  }

  @override
  String browse_local_alt_path(Object type) {
    return 'On my iPhone → Watchtower → $type';
  }

  @override
  String get browse_local_scan_note =>
      'Watchtower will scan this folder automatically when the local source opens.';

  @override
  String browse_local_hero_title(Object type) {
    return 'Local source $type';
  }

  @override
  String get browse_local_hero_subtitle =>
      'Read your local files directly from your device, without an internet connection.';

  @override
  String browse_local_tip_source(Object type) {
    return 'Open the \"$type Local\" source in Browse → Sources to see your files.';
  }

  @override
  String get browse_local_tip_subfolder =>
      'Create a subfolder per title for better organization.';

  @override
  String get browse_local_tip_cover =>
      'A cover.jpg file in the title folder will be used as the cover.';

  @override
  String get browse_local_tip_pull =>
      'Pull down on the local library to rescan the files.';

  @override
  String get browse_local_type_music => 'Music';

  @override
  String get browse_local_type_game => 'Game';

  @override
  String get browse_local_type_plugin => 'Plugin';

  @override
  String get browse_create_base_url => 'Base URL';

  @override
  String get browse_account_required_chip => '🔐 Account required';

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
  String get settings_remote_bypass_title => 'Remote bypass server';

  @override
  String get settings_remote_bypass_help =>
      'Enter the URL of your FlareSolverr instance (e.g. http://192.168.1.10:8191)';

  @override
  String get settings_remote_server_url => 'Server URL';

  @override
  String get settings_remote_api_key => 'API key (optional)';

  @override
  String get settings_remote_timeout => 'Timeout (ms)';

  @override
  String get settings_remote_trigger_mode => 'Trigger mode';

  @override
  String get settings_remote_mode_auto => 'Automatic';

  @override
  String get settings_remote_mode_auto_desc =>
      'Uses the remote server as soon as the 2 local attempts fail';

  @override
  String get settings_remote_mode_on_demand => 'On demand';

  @override
  String get settings_remote_mode_on_demand_desc =>
      'Uses the remote server only when you tap \"Bypass via remote server\"';

  @override
  String get settings_save => 'Save';

  @override
  String get settings_clear_database => 'Clear the database';

  @override
  String settings_clear_database_body(Object count) {
    return '$count series not saved in your library will be deleted.\n\nThis action cannot be undone.';
  }

  @override
  String get settings_clear_image_caches_title => 'Clear all image caches?';

  @override
  String get settings_clear_image_caches_body =>
      'Covers and extension icons will be downloaded again the next time they are shown. Your downloads are not affected.';

  @override
  String get settings_share_crash_reports => 'Share crash reports';

  @override
  String get settings_share_crash_reports_desc =>
      'Writes crash reports to a file so you can share them with the developers';

  @override
  String get settings_detailed_reports => 'Detailed reports';

  @override
  String get settings_detailed_reports_desc =>
      'Adds detailed reports to the system traces (reduces app performance)';

  @override
  String get settings_onboarding_guide => 'First-launch guide';

  @override
  String get settings_onboarding_guide_desc => 'Restart the startup tutorial';

  @override
  String get settings_manage_notifications => 'Manage the app alerts';

  @override
  String get settings_disable_battery_optimisation =>
      'Disable battery optimisation';

  @override
  String get settings_disable_battery_optimisation_desc =>
      'Makes background library updates and backups easier';

  @override
  String get settings_dont_kill_my_app_desc =>
      'Some manufacturers add extra restrictions on apps that kill background services. This website has more information on how to fix it.';

  @override
  String get settings_remote_enable => 'Enable the remote server';

  @override
  String settings_remote_connected(Object url) {
    return 'Connected to $url';
  }

  @override
  String get settings_remote_none_configured =>
      'No server configured — Tap Configure';

  @override
  String get settings_remote_configure => 'Configure the remote server';

  @override
  String get settings_remote_configure_desc =>
      'URL, API key, timeout, trigger mode';

  @override
  String get settings_flaresolverr_help =>
      'FlareSolverr is a proxy server that uses a headless browser to solve Cloudflare challenges. Install it on your machine or a local server and enter its URL here.';

  @override
  String get settings_reindex_downloads => 'Reindex the downloads';

  @override
  String get settings_reindex_downloads_desc =>
      'Scans the files already on disk and fixes the missing entries';

  @override
  String get settings_downloads_not_in_library =>
      'Downloads not in the library';

  @override
  String get settings_downloads_not_in_library_desc =>
      'Automatically adds to the library every series with a downloaded chapter';

  @override
  String get settings_clear_database_desc =>
      'Delete the history of the series that are not saved in your library';

  @override
  String get settings_clear_cookies => 'Clear cookies';

  @override
  String get settings_clear_webview_data => 'Clear the WebView data';

  @override
  String get settings_doh => 'DNS over HTTPS (DoH)';

  @override
  String get settings_default_user_agent_list => 'Default user-agent list';

  @override
  String get settings_reset_user_agent => 'Reset the user-agent list';

  @override
  String get settings_icon_cover_cache => 'Icon and cover cache';

  @override
  String get settings_max_cache_size => 'Maximum cache size';

  @override
  String get settings_max_cache_size_desc =>
      'Total ceiling for every image cache. The oldest entry is removed first when the limit is reached.';

  @override
  String get settings_clear_icon_cache => 'Clear the extension icon cache';

  @override
  String get settings_clear_cover_cache => 'Clear the library cover cache';

  @override
  String get settings_clear_all_image_caches => 'Clear all image caches';

  @override
  String get settings_refresh_cache_sizes => 'Refresh the cache sizes';

  @override
  String get settings_refresh_cache_sizes_desc =>
      'Recalculates the disk cache sizes';

  @override
  String settings_current_size(Object size) {
    return 'Current size: $size';
  }

  @override
  String settings_current_total_size(Object size) {
    return 'Current total size: $size';
  }

  @override
  String get settings_refresh_library_covers => 'Refresh the library covers';

  @override
  String get settings_refreshing_covers => 'Refreshing covers…';

  @override
  String get settings_reset_reader_per_series =>
      'Reset the reader settings per series';

  @override
  String get settings_reset_reader_per_series_desc =>
      'Resets the reading mode and orientation of every series';

  @override
  String get settings_reset_reader_title => 'Reset the reader settings';

  @override
  String get settings_reader_reset_done => 'Reader settings reset';

  @override
  String get settings_error => 'Error';

  @override
  String get settings_update_library_titles =>
      'Update the library series titles';

  @override
  String get settings_update_library_titles_desc =>
      'Warning: if a series is renamed, it will be removed from the download queue.';

  @override
  String get settings_updating_titles => 'Updating titles…';

  @override
  String get settings_no_non_ascii => 'Forbid non-ASCII file names';

  @override
  String get settings_no_non_ascii_desc =>
      'Keeps compatibility with some storage media that do not support Unicode';

  @override
  String get settings_bitmap_threshold => 'Custom hardware bitmap threshold';

  @override
  String get settings_bitmap_threshold_desc =>
      'If the reader shows a blank image, lower the threshold gradually.';

  @override
  String get settings_old_decoder =>
      'Use the old decoder for the long-strip reader';

  @override
  String get settings_old_decoder_desc =>
      'Affects performance. Only enable it if lowering the bitmap threshold does not fix the blank image issues';

  @override
  String get settings_custom_display_profile => 'Custom display profile';

  @override
  String get settings_installer => 'Installer';

  @override
  String get settings_revoke_extra_repo_extensions =>
      'Revoke extensions from an additional repository';

  @override
  String get settings_revoke_extensions_title => 'Revoke the extensions';

  @override
  String get settings_revoke_extensions_body =>
      'Every extension coming from additional repositories will be revoked.';

  @override
  String get settings_revoke => 'Revoke';

  @override
  String get settings_extensions_revoked => 'Extensions revoked';

  @override
  String get settings_interface_scale => 'Interface scale';

  @override
  String get settings_interface_scale_desc =>
      'Adapts the interface size (text + spacing). Useful for small screens like the iPhone 7.';

  @override
  String settings_default_suffix(Object value) {
    return '$value (default)';
  }

  @override
  String get settings_logs_enable_hint =>
      'Enable logs in About > Developer to configure these options.';

  @override
  String get settings_log_mode => 'Logging mode';

  @override
  String get settings_log_suppress_images => 'Suppress image errors';

  @override
  String get settings_log_suppress_images_desc =>
      'Do not record 404 logo errors';

  @override
  String get settings_log_active_categories => 'Active categories';

  @override
  String get settings_log_customisable => 'customisable';

  @override
  String get settings_log_tag_ext => 'Extensions [EXT]';

  @override
  String get settings_log_tag_ext_desc =>
      'Extension installation, update and errors';

  @override
  String get settings_log_tag_install => 'Detailed install [INSTALL]';

  @override
  String get settings_log_tag_install_desc => 'Every install/uninstall step';

  @override
  String get settings_log_tag_dl => 'Downloads [DL]';

  @override
  String get settings_log_tag_dl_desc => 'Download progress, resume and errors';

  @override
  String get settings_log_tag_hls => 'HLS streaming [HLS]';

  @override
  String get settings_log_tag_hls_desc =>
      'HLS segments, manifest and stream errors';

  @override
  String get settings_log_tag_net => 'Network [NET]';

  @override
  String get settings_log_tag_net_desc =>
      'HTTP requests, redirects and network errors';

  @override
  String get settings_log_tag_manga => 'Manga [MANGA]';

  @override
  String get settings_log_tag_manga_desc =>
      'Series, chapters and metadata loading';

  @override
  String get settings_log_tag_reader => 'Reader [READER]';

  @override
  String get settings_log_tag_reader_desc =>
      'Reader navigation, zoom and orientation';

  @override
  String get settings_log_tag_page => 'Manga pages [PAGE]';

  @override
  String get settings_log_tag_page_desc => '⚡ Every loaded page (very verbose)';

  @override
  String get settings_log_tag_watch => 'Video playback [WATCH]';

  @override
  String get settings_log_tag_watch_desc =>
      'Episode opening, buffering, 60 s watchdog';

  @override
  String get settings_log_tag_maint => 'Maintenance [MAINT]';

  @override
  String get settings_log_tag_maint_desc =>
      'Cookie cleanup, database, reindexing and background tasks';

  @override
  String get settings_log_tag_ui => 'Interface [UI]';

  @override
  String get settings_log_tag_ui_desc => 'Interface events and errors';

  @override
  String get settings_log_tag_img => 'Images [IMG]';

  @override
  String get settings_log_tag_img_desc =>
      'Cover downloads: cache, network and failures';

  @override
  String get settings_silent_updates => 'Silent updates';

  @override
  String get settings_silent_active =>
      'Active — updates install automatically without confirmation.';

  @override
  String get settings_silent_shizuku_required =>
      'Shizuku is required for a one-time setup. Tap to configure.';

  @override
  String get settings_silent_shizuku_not_running =>
      'Shizuku is not running. Open Shizuku and come back here.';

  @override
  String get settings_silent_checking => 'Checking…';

  @override
  String get settings_auto_install => 'Automatic install';

  @override
  String get settings_data => 'Data';

  @override
  String get settings_network => 'Network';

  @override
  String get settings_reader => 'Reader';

  @override
  String get settings_display => 'Display';

  @override
  String get settings_advanced_logs => 'Advanced logs';

  @override
  String get settings_background_activity => 'Background activity';

  @override
  String get settings_advanced => 'Advanced';

  @override
  String get settings_remote_section => 'Remote Cloudflare bypass';

  @override
  String get settings_library => 'Library';

  @override
  String get settings_cookies_cleared => 'Cookies cleared';

  @override
  String get settings_webview_data_cleared => 'WebView data cleared';

  @override
  String get settings_cookies_clear_failed => 'Could not delete the cookies';

  @override
  String get settings_webview_clear_failed =>
      'Could not delete the WebView data';

  @override
  String settings_db_cleared(Object count) {
    return 'Database cleaned ($count deleted)';
  }

  @override
  String get settings_clear => 'Clear';

  @override
  String get settings_empty => 'Empty';

  @override
  String get settings_reindexing => 'Reindexing…';

  @override
  String settings_reindex_done(Object fixed, Object total) {
    return '$fixed of $total chapter(s) reindexed';
  }

  @override
  String get settings_checking => 'Checking…';

  @override
  String settings_added_to_library(Object count) {
    return '$count series added to the library';
  }

  @override
  String settings_bytes_o(Object bytes) {
    return '$bytes B';
  }

  @override
  String settings_bytes_ko(Object value) {
    return '$value KB';
  }

  @override
  String settings_bytes_mo(Object value) {
    return '$value MB';
  }

  @override
  String settings_bytes_go(Object value) {
    return '$value GB';
  }

  @override
  String get settings_icon_cache_cleared => 'Icon cache cleared';

  @override
  String get settings_cover_cache_cleared => 'Cover cache cleared';

  @override
  String get settings_all_caches_cleared => 'All image caches cleared';

  @override
  String get settings_user_agent_reset => 'User agent reset';

  @override
  String get settings_user_agent_reset_failed => 'Could not reset';

  @override
  String get settings_battery_settings_failed =>
      'Could not open the battery optimisation settings.\nGo to Settings > Battery > Battery optimisation.';

  @override
  String get settings_notifications_hint_android =>
      'Open Settings > Notifications to manage the alerts.';

  @override
  String get settings_notifications_hint_ios =>
      'Open the system Settings to manage the notifications.';

  @override
  String get settings_extreme_warning =>
      '⚡ Extreme – everything is logged. RAM +++. Use with caution.';

  @override
  String get settings_debug_warning => '⚠ Debug mode active – high RAM usage';

  @override
  String get settings_log_mode_normal => 'Normal';

  @override
  String get settings_log_mode_normal_desc =>
      'INFO+ · extensions and installs only';

  @override
  String get settings_log_mode_verbose => 'Verbose';

  @override
  String get settings_log_mode_verbose_desc =>
      'DEBUG+ · network, downloads, manga, HLS';

  @override
  String get settings_log_mode_debug => 'Debug';

  @override
  String get settings_log_mode_debug_desc =>
      'DEBUG+ · everything except page-by-page reads';

  @override
  String get settings_log_mode_extreme => 'Extreme';

  @override
  String get settings_log_mode_extreme_desc =>
      '⚡ Log EVERYTHING – every page, HLS segment, reader event';

  @override
  String get settings_scale_default => '100% (default)';

  @override
  String settings_percent(Object value) {
    return '$value%';
  }

  @override
  String get reader_show_reading_mode => 'Show the reading mode';

  @override
  String get reader_show_reading_mode_desc =>
      'Lists the reading modes when the reader opens';

  @override
  String get reader_show_tap_zones => 'Show the tap zones (overlay)';

  @override
  String get reader_show_tap_zones_desc =>
      'Briefly shown when the reader opens';

  @override
  String get reader_load_ahead_wifi => 'Only preload on Wi-Fi';

  @override
  String get reader_load_ahead_wifi_desc =>
      'Saves mobile data by loading only the pages close to the one you are reading';

  @override
  String get reader_pages_preload => 'Number of pages to preload';

  @override
  String get reader_pages_preload_desc =>
      'How many pages to preload while reading. A higher value makes reading smoother, at the cost of a larger cache and higher data usage.';

  @override
  String get reader_section_display => 'Display';

  @override
  String get reader_default_rotation => 'Default rotation';

  @override
  String get reader_cutout => 'Use the notch area';

  @override
  String get reader_show_page_number => 'Show the page number';

  @override
  String get reader_section_eink => 'E-Ink';

  @override
  String get reader_eink_flash => 'Flash on page change';

  @override
  String get reader_eink_flash_desc => 'Reduces ghosting on e-ink screens';

  @override
  String get reader_section_reading => 'Reading';

  @override
  String get reader_skip_read => 'Skip chapters marked as read';

  @override
  String get reader_skip_filtered => 'Skip filtered chapters';

  @override
  String get reader_skip_duplicate => 'Ignore duplicate chapters';

  @override
  String get reader_always_transition =>
      'Always show the transition between chapters';

  @override
  String get reader_section_pages => 'Pages';

  @override
  String get reader_invert_tap_zones => 'Invert the tap zones';

  @override
  String get reader_zoom_start => 'Initial zoom position';

  @override
  String get reader_panorama => 'Pan wide images';

  @override
  String get reader_split_wide => 'Split wide pages';

  @override
  String get reader_rotate_wide => 'Rotate wide pages to fit';

  @override
  String get reader_disable_zoom_out => 'Disable zooming out';

  @override
  String get reader_disable_zoom_out_desc => 'A double tap now only zooms in';

  @override
  String get reader_section_continuous => 'Continuous strip';

  @override
  String get reader_side_padding => 'Side padding';

  @override
  String get reader_menu_hide_sensitivity =>
      'Sensitivity for hiding the menu while scrolling';

  @override
  String get reader_section_navigation => 'Navigation';

  @override
  String get reader_volume_buttons => 'Use the volume buttons';

  @override
  String get reader_volume_buttons_desc => 'Use ▲/▼ to turn the pages';

  @override
  String get reader_invert_volume => 'Invert the volume buttons';

  @override
  String get reader_volume_forward => '▲ → next page  •  ▼ → previous page';

  @override
  String get reader_volume_backward => '▲ → previous page  •  ▼ → next page';

  @override
  String get reader_vertical_navigator => 'Vertical chapter navigator';

  @override
  String get reader_section_actions => 'Actions';

  @override
  String get reader_long_press_actions => 'Show actions on long press';

  @override
  String get reader_save_pages_separate => 'Save pages in separate folders';

  @override
  String get reader_option_free => 'Free';

  @override
  String get reader_option_portrait => 'Portrait';

  @override
  String get reader_option_landscape => 'Landscape';

  @override
  String get reader_option_auto => 'Automatic';

  @override
  String get reader_option_left => 'Left';

  @override
  String get reader_option_right => 'Right';

  @override
  String get reader_option_center => 'Center';

  @override
  String get reader_option_none => 'None';

  @override
  String get reader_option_both => 'Both';

  @override
  String get reader_option_low => 'Low';

  @override
  String get reader_option_medium => 'Medium';

  @override
  String get reader_option_high => 'High';

  @override
  String get settings_general_subtitle =>
      'Language, DNS, recommendations, Discord';

  @override
  String get settings_display_subtitle => 'Theme, colors, fonts, dark mode';

  @override
  String get settings_library_subtitle =>
      'Categories, sorting, automatic updates';

  @override
  String get settings_reader_subtitle =>
      'Manga reader: pages, zoom, reading direction';

  @override
  String get settings_player_subtitle =>
      'Video player: quality, gestures, subtitles';

  @override
  String get settings_downloads_subtitle => 'Folder, queue, Wi-Fi only';

  @override
  String get settings_auto_backup => 'Automatic backup';

  @override
  String get settings_auto_backup_subtitle =>
      'Library, settings and cache — survives a reinstall';

  @override
  String get settings_tracking_subtitle =>
      'AniList, MyAnimeList, progress sync';

  @override
  String get settings_sync_subtitle => 'Cloud backup and synchronization';

  @override
  String get settings_browse_subtitle =>
      'Extension repositories, installed sources';

  @override
  String get settings_security_subtitle => 'Lock, password, biometrics';

  @override
  String get settings_local_sources => 'Local Sources';

  @override
  String get settings_local_sources_subtitle =>
      'Import files from a local folder';

  @override
  String get settings_advanced_subtitle => 'Logging, cache, technical options';

  @override
  String get settings_music_hub => 'Music Hub';

  @override
  String get settings_music_hub_subtitle => 'Audio player and music library';

  @override
  String get settings_remote_connection => 'Remote Connection';

  @override
  String get settings_remote_connection_subtitle =>
      'Access the library from a browser';

  @override
  String get settings_remote_mode => 'Remote Mode';

  @override
  String get settings_remote_mode_subtitle =>
      'Share the library on the local network';

  @override
  String get settings_about_subtitle => 'Version, credits, license';

  @override
  String settings_search_no_results(Object query) {
    return 'No results for “$query”';
  }

  @override
  String get settings_search_results => 'Results in the settings';

  @override
  String get downloads_section_per_media => 'Per media';

  @override
  String get downloads_watch_engine_subtitle =>
      'Engine, connections, episodes, fillers';

  @override
  String get downloads_manga_subtitle =>
      'Archive format, compression, chapters';

  @override
  String get downloads_wifi_subtitle => 'Connections, Wi-Fi downloads';

  @override
  String get downloads_simultaneous => 'Simultaneous downloads (max)';

  @override
  String get downloads_speed_limit => 'Speed limit';

  @override
  String get downloads_disk_write_mode => 'Disk write mode';

  @override
  String get downloads_cards_gestures => 'Cards & Gestures';

  @override
  String get downloads_cards => 'Download cards';

  @override
  String get downloads_cards_subtitle => 'Buttons shown and swipe actions';

  @override
  String get downloads_auto_delete => 'Delete automatically after reading';

  @override
  String get downloads_quick_nav => 'Quick navigation (dock)';

  @override
  String get downloads_dock_history => 'History in the dock';

  @override
  String get downloads_dock_updates => 'Updates in the dock';

  @override
  String get downloads_folder_structure => 'Folder Structure';

  @override
  String get downloads_delete_folder => 'Delete the folder';

  @override
  String get downloads_watchtower_folders => 'Watchtower folders';

  @override
  String get downloads_allow_access => 'Allow access';

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
  String get settings_search_hint => 'Search in the settings…';

  @override
  String get downloads_simultaneous_title => 'Simultaneous downloads';

  @override
  String downloads_simultaneous_subtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads at a time',
      one: '$count download at a time',
    );
    return '$_temp0';
  }

  @override
  String get downloads_disabled => 'Disabled';

  @override
  String get downloads_write_part => '.part + resume';

  @override
  String get downloads_write_part_desc =>
      'Writes to a .part file then renames it at the end. Resumes automatically after an interruption; the partial file stays readable.';

  @override
  String get downloads_write_prealloc => 'Pre-allocation';

  @override
  String get downloads_write_prealloc_desc =>
      'Reserves the final file size before downloading. Avoids fragmentation on large files.';

  @override
  String get downloads_write_direct => 'Direct';

  @override
  String get downloads_write_direct_desc =>
      'Writes straight to the final path (legacy behaviour). The file may be corrupted if the download is interrupted.';

  @override
  String get downloads_section_deletion => 'Deletion';

  @override
  String get downloads_auto_delete_subtitle =>
      'Deletes the file once the content has been read or watched';

  @override
  String get downloads_allow_bookmarked_delete =>
      'Allow deleting bookmarked chapters';

  @override
  String get downloads_allow_bookmarked_delete_subtitle =>
      'Lets a chapter with a bookmark be deleted';

  @override
  String get downloads_dock_history_subtitle =>
      'Shows the History tab in the navigation bar';

  @override
  String get downloads_dock_updates_subtitle =>
      'Shows the Updates tab in the navigation bar';

  @override
  String get downloads_default_folder => 'Default';

  @override
  String get downloads_storage_unavailable_snack =>
      'The download folder is not accessible. Check the storage space and try again.';

  @override
  String get downloads_no_folder => 'No download folder is available.';

  @override
  String get downloads_folder_prepare_failed =>
      'Could not prepare the download folder.';

  @override
  String downloads_file_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0';
  }

  @override
  String get downloads_folder_not_created => 'Folder not created yet';

  @override
  String get library_settings_title => 'Library';

  @override
  String get library_settings_section_updates => 'Updates';

  @override
  String get library_settings_section_behavior => 'Behavior';

  @override
  String get library_settings_categories_subtitle =>
      'Create, rename and delete your categories';

  @override
  String get library_settings_edit_categories_subtitle =>
      'Reorder and assign titles';

  @override
  String get library_settings_default_category => 'Default category';

  @override
  String get library_settings_per_category_sort =>
      'Keep sort settings per category';

  @override
  String get library_settings_update_restrictions =>
      'Hardware restrictions for automatic updates';

  @override
  String get library_settings_restrictions => 'Restrictions';

  @override
  String library_settings_restrictions_summary(Object list) {
    return 'Restrictions: $list';
  }

  @override
  String library_settings_categories_summary(Object exclude, Object include) {
    return 'Include: $include\nExclude: $exclude';
  }

  @override
  String get library_settings_auto_refresh_metadata =>
      'Automatically refresh metadata';

  @override
  String get library_settings_check_new_cover =>
      'Check for a new cover or synopsis on library updates';

  @override
  String get library_settings_unread_badge =>
      'Show the unread chapter count on the updates icon';

  @override
  String get library_settings_swipe_left => 'Left swipe action';

  @override
  String get library_settings_swipe_right => 'Right swipe action';

  @override
  String get library_settings_mark_duplicate =>
      'Mark a duplicate chapter as read';

  @override
  String get library_settings_hide_missing => 'Hide missing chapter indicators';

  @override
  String get library_settings_include => 'Include';

  @override
  String get library_settings_exclude => 'Exclude';

  @override
  String get library_settings_no_category => 'No category.';

  @override
  String get library_settings_everything => 'Everything';

  @override
  String get library_settings_charging_only => 'Only while charging';

  @override
  String get library_settings_manual => 'Manual';

  @override
  String get library_settings_every_2_days => 'Every 2 days';

  @override
  String get library_settings_every_2_weeks => 'Every 2 weeks';

  @override
  String get library_settings_every_month => 'Every month';

  @override
  String get library_settings_smart_new_chapters => 'New chapters only';

  @override
  String get library_settings_always => 'Always';

  @override
  String get library_settings_mark_chapter => 'Mark chapter';

  @override
  String get library_settings_mark_as_read => 'Mark as read';

  @override
  String get library_settings_swipe_none => 'None';

  @override
  String get downloads_watch_title => 'Downloads — Watch';

  @override
  String get downloads_novel_title => 'Downloads — Novel';

  @override
  String get downloads_music_title => 'Downloads — Music';

  @override
  String get downloads_game_title => 'Downloads — Game';

  @override
  String get downloads_engine_section => 'Download engine';

  @override
  String get downloads_connections_section => 'Connections';

  @override
  String get downloads_behavior_section => 'Behavior';

  @override
  String get downloads_hls_connections => 'Simultaneous HLS connections';

  @override
  String get downloads_hls_connections_subtitle =>
      'Segments downloaded in parallel per episode';

  @override
  String get downloads_episodes_queue => 'Simultaneous episodes (queue)';

  @override
  String get downloads_episodes_queue_subtitle =>
      'Number of episodes downloaded at the same time';

  @override
  String get downloads_wifi_only => 'Wi-Fi only';

  @override
  String get downloads_wifi_only_subtitle => 'Download over Wi-Fi only';

  @override
  String get downloads_new_episodes => 'Download new episodes';

  @override
  String get downloads_new_episodes_subtitle =>
      'Automatically downloads new available episodes';

  @override
  String get downloads_filler => 'Allow filler episodes';

  @override
  String get downloads_filler_subtitle =>
      'Include filler episodes in automatic downloads';

  @override
  String get downloads_anticipatory => 'Anticipatory download';

  @override
  String get downloads_anticipatory_watch_subtitle =>
      'Pre-downloads while watching when the next 2 episodes are available';

  @override
  String get downloads_external_section => 'External downloader';

  @override
  String get downloads_always_external => 'Always use an external downloader';

  @override
  String get downloads_always_external_subtitle =>
      'Hands every download to the external app chosen below';

  @override
  String get downloads_no_app => 'No app selected';

  @override
  String get downloads_no_app_subtitle => 'The app will ask on every download.';

  @override
  String get downloads_preferred_app => 'Preferred download app';

  @override
  String get downloads_none_app => 'None';

  @override
  String downloads_test_launch(Object name) {
    return 'Test (launches $name)';
  }

  @override
  String downloads_launched(Object name) {
    return '$name launched via intent';
  }

  @override
  String downloads_launch_failed(Object name) {
    return 'Could not launch $name (is the app installed?)';
  }

  @override
  String get downloads_official_site => 'Official site';

  @override
  String get downloads_ext_adm_desc =>
      'Multi-threaded download manager for Android.';

  @override
  String get downloads_ext_1dm_desc =>
      'Fast downloader with HLS and DASH support for Android.';

  @override
  String get downloads_ext_fdm_desc =>
      'Free and open-source cross-platform downloader.';

  @override
  String get downloads_ext_idm_desc =>
      'High-speed downloader with resume (Windows).';

  @override
  String get downloads_ext_jdownloader_desc =>
      'Very popular open-source cross-platform downloader.';

  @override
  String get downloads_ext_motrix_desc =>
      'Open-source Aria2 downloader with a modern interface.';

  @override
  String get downloads_mode_internal => 'Internal';

  @override
  String get downloads_mode_external => 'External';

  @override
  String get downloads_mode_internal_desc =>
      'HLS downloader built into the app. Ideal for most streams.';

  @override
  String get downloads_mode_aria2_desc =>
      'High-performance aria2c engine. Multiple connections and download resume.';

  @override
  String get downloads_mode_external_desc =>
      'Hands off to an external app (ADM, 1DM, FDM, IDM…). The download leaves the app.';

  @override
  String get downloads_mode_zeus_desc =>
      'Python extractor (ZeusDL) for web pages: TikTok, Facebook, Instagram… without watermark.';

  @override
  String get downloads_manga_engine_note =>
      'Manga always uses the internal downloader: a chapter’s pages are fetched in parallel automatically.';

  @override
  String get downloads_archive_section => 'Archive format';

  @override
  String get downloads_compression_section => 'Compression';

  @override
  String get downloads_compression_disabled =>
      'Choose an archive format to enable compression.';

  @override
  String get downloads_compression_none =>
      'No recompression: original pages are kept, only ZIP packing is applied (fastest).';

  @override
  String downloads_compression_level(Object level) {
    return 'Level $level/9 · pages are re-encoded to lighter JPEG then packed into the archive: smaller file, a little quality lost.';
  }

  @override
  String get downloads_less_compressed => 'Less compressed';

  @override
  String get downloads_more_compressed => 'More compressed';

  @override
  String get downloads_compression_fast => 'Fast';

  @override
  String get downloads_compression_light => 'Light';

  @override
  String get downloads_compression_light_plus => 'Light +';

  @override
  String get downloads_compression_standard => 'Standard';

  @override
  String get downloads_compression_standard_plus => 'Standard +';

  @override
  String get downloads_compression_strong => 'Strong';

  @override
  String get downloads_compression_strong_plus => 'Strong +';

  @override
  String get downloads_compression_intense => 'Intense';

  @override
  String get downloads_compression_intense_plus => 'Intense +';

  @override
  String get downloads_compression_maximum => 'Maximum';

  @override
  String get downloads_archive_cbz_title => 'Comic Book ZIP';

  @override
  String get downloads_archive_cbz_subtitle => 'Most compatible · ZIP images';

  @override
  String get downloads_archive_cbr_title => 'Comic Book RAR';

  @override
  String get downloads_archive_cbr_subtitle =>
      'CBR container · readable everywhere';

  @override
  String get downloads_archive_cb7_title => 'Comic Book 7-Zip';

  @override
  String get downloads_archive_cb7_subtitle =>
      'CB7 container · highly compressed';

  @override
  String get downloads_archive_zip_title => 'Standard ZIP';

  @override
  String get downloads_archive_zip_subtitle => 'Raw ZIP archive';

  @override
  String get downloads_archive_folder_title => 'Image folder';

  @override
  String get downloads_archive_folder_subtitle => 'No archive · direct access';

  @override
  String get downloads_manga_new_chapters => 'Download new chapters';

  @override
  String get downloads_manga_new_chapters_subtitle =>
      'Automatically downloads new available chapters';

  @override
  String get downloads_anticipatory_read => 'Anticipatory download (reading)';

  @override
  String get downloads_anticipatory_read_subtitle =>
      'Pre-downloads when the current and next chapter are already present';

  @override
  String get downloads_delete_after_read => 'Delete after reading';

  @override
  String get downloads_delete_after_read_subtitle =>
      'Deletes the chapter as soon as it is marked read';

  @override
  String get downloads_delete_marked => 'Delete even bookmarked chapters';

  @override
  String get downloads_delete_marked_subtitle =>
      'Automatic deletion also applies to bookmarked chapters';

  @override
  String get downloads_novel_note =>
      'Novel uses the internal downloader through the source extension. Chapters are saved as HTML and grouped by title.';

  @override
  String get downloads_music_note =>
      'Music uses the internal downloader through the source extension.';

  @override
  String get downloads_game_note =>
      'Game uses the internal downloader through the source extension.';

  @override
  String get downloads_connections_simultaneous => 'Simultaneous connections';

  @override
  String get downloads_connections_per_chapter =>
      'Parallel connections per chapter';

  @override
  String get downloads_connections_per_download =>
      'Parallel connections per download';

  @override
  String get downloads_chapters_queue => 'Simultaneous chapters (queue)';

  @override
  String get downloads_chapters_queue_subtitle =>
      'Number of chapters downloaded at the same time';

  @override
  String get downloads_items_queue => 'Simultaneous items (queue)';

  @override
  String get downloads_items_queue_subtitle =>
      'Number of items downloaded at the same time';

  @override
  String get downloads_cards_buttons_section => 'Download card buttons';

  @override
  String get downloads_cards_buttons_subtitle =>
      'Choose the buttons shown on each download card.';

  @override
  String get downloads_card_preview => 'Card preview';

  @override
  String get downloads_swipe_subtitle =>
      'Action triggered by swiping a card left or right.';

  @override
  String get downloads_swipe_left => 'Swipe left';

  @override
  String get downloads_swipe_right => 'Swipe right';

  @override
  String get downloads_no_buttons => 'No button shown — swipe to act.';

  @override
  String get downloads_storage_format => 'Storage format';

  @override
  String get downloads_archive_folder_desc =>
      'Pages verified, kept in a folder.';

  @override
  String get downloads_archive_cbz_desc =>
      'Archive created after all pages are verified.';

  @override
  String get downloads_archive_zip_desc =>
      'ZIP archive created after pages are verified.';

  @override
  String get downloads_archive_unsupported =>
      'Unsupported format: a CBZ will be produced.';

  @override
  String get downloads_archive_label_folder => 'Folder (images)';

  @override
  String get downloads_swipe_pause_resume => 'Pause / Resume';

  @override
  String get downloads_swipe_cancel => 'Cancel';

  @override
  String get downloads_swipe_delete => 'Delete';

  @override
  String get downloads_swipe_retry => 'Retry';

  @override
  String get downloads_swipe_disabled => 'Disabled';

  @override
  String get downloads_open_folder => 'Open folder';

  @override
  String get downloads_swipe_section => 'Swipe actions';

  @override
  String get queue_title => 'Downloads';

  @override
  String get queue_load_error => 'Could not load the download queue.';

  @override
  String queue_unfinished(Object count) {
    return 'Unfinished ($count)';
  }

  @override
  String get queue_manage => 'Manage';

  @override
  String get queue_empty_watch => 'No Watch download';

  @override
  String get queue_empty_manga => 'No Manga download';

  @override
  String get queue_empty_novel => 'No Novel download';

  @override
  String get queue_empty_music => 'No Music download';

  @override
  String get queue_empty_game => 'No Game download';

  @override
  String get queue_download_canceled => 'Download cancelled.';

  @override
  String get queue_chapter_not_found => 'Chapter not found.';

  @override
  String get queue_manage_downloads => 'Manage downloads';

  @override
  String queue_settings_for(Object name) {
    return '$name settings';
  }

  @override
  String get queue_act_on_all => 'Act on the whole queue';

  @override
  String get queue_stop => 'Stop';

  @override
  String get queue_simultaneous => 'Simultaneous';

  @override
  String get queue_simultaneous_help =>
      'Number of parallel downloads per type and per source';

  @override
  String get queue_density_help => 'Display density of the queue items';

  @override
  String get queue_background => 'Background';

  @override
  String get queue_continue_closed => 'Keep going when the app is closed';

  @override
  String get queue_background_enabled => 'Background downloading enabled';

  @override
  String get queue_clear_completed => 'Clear completed';

  @override
  String get queue_clear_completed_subtitle =>
      'Remove finished items from the queue';

  @override
  String get queue_completed_removed =>
      'Completed items removed from the queue';

  @override
  String queue_simultaneous_for(Object name) {
    return 'Parallel downloads for $name';
  }

  @override
  String get queue_connections => 'Connections';

  @override
  String get queue_connections_help =>
      'Parallel connections per downloaded unit';

  @override
  String get queue_segments_per_episode => 'HLS segments per episode';

  @override
  String get queue_connections_per_chapter => 'Connections per chapter';

  @override
  String queue_params_for(Object name) {
    return '$name settings';
  }

  @override
  String get queue_delete_series => 'Delete the series';

  @override
  String get queue_resume_series => 'Resume the series';

  @override
  String get queue_pause_series => 'Pause the series';

  @override
  String get queue_pause_series_full => 'Pause the series';

  @override
  String get queue_hide => 'Hide';

  @override
  String get queue_challenge_resolved => 'Challenge solved — download resumed';

  @override
  String get queue_priority_high => 'High priority enabled';

  @override
  String get queue_priority_normal => 'Normal priority';

  @override
  String get queue_status_completed => 'Completed';

  @override
  String get queue_status_failed => 'Failed';

  @override
  String get queue_status_canceled => 'Canceled';

  @override
  String get queue_unit_chapter => 'Chapter';

  @override
  String get queue_unit_episodes => 'episodes';

  @override
  String get queue_unit_chapters => 'chapters';

  @override
  String get queue_download_finished => 'Download finished';

  @override
  String queue_received(Object size) {
    return '$size received';
  }

  @override
  String get queue_transfer => 'Transfer';

  @override
  String get queue_quick_actions => 'Quick actions';

  @override
  String get queue_start => 'Start';

  @override
  String get queue_retry => 'Retry';

  @override
  String get queue_layout => 'Layout';

  @override
  String get queue_status_muxing => 'Muxing';

  @override
  String get queue_status_compressing => 'Compressing';

  @override
  String get queue_status_paused => 'Paused';

  @override
  String get queue_status_waiting => 'Waiting';

  @override
  String queue_cloudflare_challenge(Object source) {
    return 'Cloudflare challenge — $source';
  }

  @override
  String get queue_resume => 'Resume';

  @override
  String get queue_pause => 'Pause';

  @override
  String get appearance_ui_title => 'Interface & Effects';

  @override
  String get appearance_ui_section_ui => 'UI & DISCOVERY';

  @override
  String get appearance_ui_carousel_style => 'Carousel style';

  @override
  String get appearance_ui_carousel_synopsis => 'Synopsis in the carousel';

  @override
  String get appearance_ui_carousel_synopsis_subtitle =>
      'Show the description under the banner';

  @override
  String get appearance_ui_glow => 'Glow effects';

  @override
  String get appearance_ui_glow_subtitle => 'Bright shadows on the covers';

  @override
  String get appearance_ui_animated_bg => 'Animated background (detail)';

  @override
  String get appearance_ui_animated_bg_subtitle =>
      'Ken Burns effect on the detail banners';

  @override
  String get appearance_ui_petals => 'Falling petals';

  @override
  String get appearance_ui_petals_subtitle =>
      'Discreet floral animation on the screens';

  @override
  String get appearance_ui_section_blur => 'BLUR & GLASS';

  @override
  String get appearance_ui_frosted_header => 'Frosted header';

  @override
  String get appearance_ui_frosted_header_subtitle =>
      'Header blur while scrolling';

  @override
  String get appearance_ui_frosted_sheets => 'Frosted sheets';

  @override
  String get appearance_ui_frosted_sheets_subtitle =>
      'Background blur behind bottom sheets';

  @override
  String get appearance_ui_blur_intensity => 'Blur intensity';

  @override
  String get appearance_ui_section_transitions => 'TRANSITIONS & ANIMATIONS';

  @override
  String get appearance_ui_transition_style => 'Transition style';

  @override
  String get appearance_ui_carousel_classic => 'Classic';

  @override
  String get appearance_ui_carousel_cinematic => 'Cinematic';

  @override
  String get appearance_ui_carousel_compact => 'Compact';

  @override
  String get appearance_ui_transition_fade => 'Fade';

  @override
  String get appearance_ui_transition_slide => 'Slide';

  @override
  String get appearance_ui_transition_scale => 'Scale';

  @override
  String get appearance_ui_transition_none => 'None';

  @override
  String get appearance_display_title => 'Display';

  @override
  String get appearance_display_system_default => 'System (default)';

  @override
  String get appearance_display_date_format => 'Date format';

  @override
  String get appearance_display_relative_times => 'Relative times';

  @override
  String get appearance_display_render_images =>
      'Render images in manga descriptions';

  @override
  String get appearance_font_picker => 'Font';

  @override
  String get appearance_font_search => 'Search for a font…';

  @override
  String get app_language_title => 'App language';

  @override
  String get nav_home => 'Home';

  @override
  String get general_section_network => 'Network';

  @override
  String get general_disabled => 'Disabled';

  @override
  String get general_close => 'Close';

  @override
  String get general_section_recommendations => 'Recommendations';

  @override
  String get general_recommendations_subtitle =>
      'Algorithm, similarity and relevance weights';

  @override
  String get general_section_activity => 'Activity';

  @override
  String get general_system_default => 'System default';

  @override
  String get general_doh_subtitle =>
      'Encrypts your DNS requests so your carrier or network cannot see the sites you visit.';

  @override
  String get general_user_agent_hint =>
      'Open the site, copy your User-Agent, then paste it above.';

  @override
  String get player_gestures_subtitle => 'Seek, double tap, controls';

  @override
  String get player_subtitles_subtitle =>
      'Preferred languages, whitelist, blacklist';

  @override
  String get player_script_editor_subtitle =>
      'Edit and create new scripts and script options';

  @override
  String get player_torrent_subtitle => 'TorrServer options';

  @override
  String get player_user_files_subtitle => 'Custom scripts, shaders and fonts';

  @override
  String get player_script_editor_title => 'Script editor';

  @override
  String get player_gestures_title => 'Gestures';

  @override
  String get player_double_tap_seek => 'Double-tap to seek';

  @override
  String get player_double_tap_seek_subtitle =>
      'Fast-forward or rewind the video by double-tapping the sides';

  @override
  String get player_double_tap_duration => 'Double-tap duration';

  @override
  String player_seconds(Object count) {
    return '$count seconds';
  }

  @override
  String get player_swipe_gestures => 'Swipe gestures';

  @override
  String get player_swipe_gestures_subtitle =>
      'Horizontal swipe to seek, vertical for volume and brightness';

  @override
  String get player_gesture_overlay => 'Gesture overlay';

  @override
  String get player_gesture_overlay_subtitle =>
      'Shows a preview during a gesture';

  @override
  String get player_center_double_tap => 'Double-tap centre for play/pause';

  @override
  String get player_subtitles_title => 'Subtitles';

  @override
  String get player_preferred_languages => 'Preferred languages';

  @override
  String get player_whitelist => 'Whitelist';

  @override
  String get player_whitelist_hint => 'Filters to keep';

  @override
  String get player_blacklist => 'Blacklist';

  @override
  String get player_blacklist_hint => 'Filters to hide';

  @override
  String get player_subtitle_text_size => 'Text size';

  @override
  String get player_custom_buttons => 'Custom buttons';

  @override
  String get player_custom_buttons_subtitle =>
      'Create and edit buttons that run lua code';

  @override
  String get player_load_user_files => 'Load user files';

  @override
  String get player_load_user_files_subtitle =>
      'Runs the mpv scripts placed in the user folder';

  @override
  String get player_scripts_folder => 'Scripts folder';

  @override
  String get player_not_defined => 'Not set';

  @override
  String get player_not_configured => 'Not configured';

  @override
  String get player_resume_last_position => 'Resume at the last position';

  @override
  String get player_resume_last_position_subtitle =>
      'Resumes playback where it stopped';

  @override
  String get player_ask_next_episode => 'Ask for the next episode';

  @override
  String get player_ask_next_episode_subtitle =>
      'Shows a prompt at the end of an episode';

  @override
  String get player_lock_landscape =>
      'Lock landscape orientation while playing';

  @override
  String get player_decoder_mode => 'Decoding mode';

  @override
  String get player_debanding => 'Debanding';

  @override
  String get player_debanding_subtitle => 'Improves interlaced videos';

  @override
  String get player_torrent_prebuffer =>
      'Starts playback as soon as enough pieces are available';

  @override
  String get player_keep_audio_channels => 'Keep audio channels';

  @override
  String get player_keep_audio_channels_subtitle => 'Do not downmix to stereo';

  @override
  String get player_load_user_assets =>
      'Load scripts, shaders and fonts from the user folder';

  @override
  String get player_orientation_landscape => 'Landscape orientation';

  @override
  String get player_decoder_auto => 'Automatic';

  @override
  String get player_decoder_hw => 'Hardware decoding';

  @override
  String get player_decoder_sw => 'Software decoding';

  @override
  String get settings_search_in_settings => 'Search in settings…';

  @override
  String get settings_search_tooltip => 'Search';

  @override
  String get settings_close_search => 'Close search';

  @override
  String get settings_extensions_display => 'Extensions display';

  @override
  String get settings_layout_list => 'List';

  @override
  String get settings_layout_grid => 'Grid';

  @override
  String get settings_layout_extended => 'Extended';

  @override
  String get settings_remote_server => 'Remote server';

  @override
  String get settings_remote_server_subtitle =>
      'Connect your device to sync the library';

  @override
  String get media_filters_title => 'Filters';

  @override
  String media_filters_active(Object count) {
    return 'Filters · $count active';
  }

  @override
  String get media_clear_filters => 'Remove filters';

  @override
  String get media_apply => 'Apply';

  @override
  String get media_done => 'Done';

  @override
  String get media_display_mode => 'Display mode';

  @override
  String get media_items_per_row => 'Items per row';

  @override
  String get media_columns_count => 'Number of columns';

  @override
  String media_columns_n(Object count) {
    return '$count columns';
  }

  @override
  String get media_columns_one => '1 column';

  @override
  String get media_automatic => 'Automatic';

  @override
  String get media_years => 'Years';

  @override
  String get media_all_years => 'All years';

  @override
  String get media_genres => 'Genres';

  @override
  String get media_rating => 'Rating';

  @override
  String get media_sort => 'Sort';

  @override
  String get media_search_option => 'Search an option…';

  @override
  String get media_search_page => 'Search in this page…';

  @override
  String get media_all => 'All';

  @override
  String get media_all_durations => 'All durations';

  @override
  String get media_all_languages => 'All languages';

  @override
  String get media_all_qualities => 'All qualities';

  @override
  String get media_language => 'Language';

  @override
  String get media_upper => 'Upper';

  @override
  String get media_lower => 'Lower';

  @override
  String get media_deselect_all => 'Deselect all';

  @override
  String get media_download_all => 'Download all';

  @override
  String media_download_count(Object count) {
    return 'Download $count item(s)';
  }

  @override
  String media_download_selection(Object count) {
    return 'Download selection ($count)';
  }

  @override
  String get media_custom_download => 'Custom download';

  @override
  String get media_item_count => 'Number of items';

  @override
  String get media_enter_positive => 'Enter a number greater than zero.';

  @override
  String get media_nothing_downloadable => 'No downloadable item.';

  @override
  String get media_no_selection => 'No video selected.';

  @override
  String media_episodes_count(Object count) {
    return '$count episodes';
  }

  @override
  String get media_episode => 'Episode';

  @override
  String media_episode_n(Object number) {
    return 'Episode $number';
  }

  @override
  String media_ep_short(Object number) {
    return 'Ep. $number';
  }

  @override
  String get media_season => 'Season';

  @override
  String get media_series => 'Series';

  @override
  String get media_tv_movie => 'TV movie';

  @override
  String get media_reality => 'Reality TV';

  @override
  String get media_top_rated => 'Top rated';

  @override
  String get media_new_releases => 'New releases';

  @override
  String get media_most_popular => 'Most popular';

  @override
  String get media_top_10_week => 'Top 10 this week';

  @override
  String get media_discover => 'Discover';

  @override
  String get media_watch_this_week => 'Watch this week';

  @override
  String get media_watch_tonight => 'Watch tonight';

  @override
  String get media_categories => 'Categories';

  @override
  String get media_no_result => 'No result';

  @override
  String get media_no_result_filters => 'No result for these filters';

  @override
  String get media_load_failed => 'Unable to load \$title right now.';

  @override
  String get media_no_summary => 'No summary available.';

  @override
  String get media_no_synopsis => 'No synopsis available.';

  @override
  String get media_no_similar => 'No similar title available.';

  @override
  String get media_no_wallpaper => 'No wallpaper available.';

  @override
  String get media_no_episode => 'No episode available.';

  @override
  String get media_no_comments => 'No comments yet.';

  @override
  String get media_comments_load_failed => 'Unable to load the comments.';

  @override
  String get media_episodes_load_failed => 'Unable to load the episodes.';

  @override
  String get media_people_load_failed => 'Unable to load the cast.';

  @override
  String get media_details => 'Details';

  @override
  String get media_details_unavailable => 'Details unavailable.';

  @override
  String get media_duration => 'Duration';

  @override
  String get media_episode_duration => 'Episode duration';

  @override
  String get media_release_date => 'Release date';

  @override
  String get media_first_air_date => 'First air date';

  @override
  String get media_last_episode => 'Last episode';

  @override
  String get media_original_language => 'Original language';

  @override
  String get media_spoken_languages => 'Spoken languages';

  @override
  String get media_networks => 'Networks';

  @override
  String get media_created_by => 'Created by';

  @override
  String get media_where_to_watch => 'Where to watch';

  @override
  String get media_popularity => 'Popularity';

  @override
  String get media_add_to_list => 'Add to my list';

  @override
  String get media_watch_series => 'Watch the series';

  @override
  String get media_watch_episodes => 'Watch the episodes';

  @override
  String get media_watch_season => 'Watch the season';

  @override
  String get media_view_all_languages => 'View all languages';

  @override
  String get media_retry => 'Retry';

  @override
  String get media_loading_failed_retry => 'Loading failed · Retry';

  @override
  String get media_prev_chapter => 'Previous chapter';

  @override
  String get media_next_chapter => 'Next chapter';

  @override
  String get media_next_episode => 'Next episode';

  @override
  String get media_new_chapter => 'New chapter';

  @override
  String get media_next_chapter_soon => 'Next chapter';

  @override
  String get media_latest_releases => 'Latest releases';

  @override
  String get media_release_calendar => 'Release calendar';

  @override
  String get media_recent_results => 'Recent results';

  @override
  String get media_resume_reading => 'Resume reading';

  @override
  String get media_quick_access => 'Quick access';

  @override
  String get media_reader_settings => 'Reader settings';

  @override
  String get media_brightness => 'Brightness';

  @override
  String get media_volumes_preview => 'Volumes preview';

  @override
  String get media_upcoming_volumes => 'Upcoming volumes';

  @override
  String get media_other_works => 'Other works in the universe';

  @override
  String get media_editions_by_language => 'Editions by language';

  @override
  String get media_universe_by_country => 'Universe by country / language';

  @override
  String get media_trailers => 'Trailers and videos';

  @override
  String get media_video => 'Video';

  @override
  String get media_soon => 'Soon';

  @override
  String get media_tv => 'TV';

  @override
  String get media_announced => 'Announced';

  @override
  String get media_cancelled => 'Cancelled';

  @override
  String get media_completed => 'Completed';

  @override
  String get media_dropped => 'Dropped';

  @override
  String get media_status_ongoing => 'Ongoing';

  @override
  String get media_available_channels => 'Available channels';

  @override
  String get media_open_channel_failed => 'Unable to open the channel';

  @override
  String get media_world_channels =>
      'Access the official channel pages from Watchtower.';

  @override
  String get media_world_content => 'Explore content from around the world.';

  @override
  String get media_european_news => 'European news';

  @override
  String get media_international_news => 'International news';

  @override
  String get media_no_network => 'No network connection';

  @override
  String get media_connect_internet =>
      'Connect to the Internet to load \$title.';

  @override
  String get media_check_connection => 'Check your Wi-Fi or mobile data.';

  @override
  String get media_catalog_load_failed =>
      'Unable to load the catalogue. Try again later.';

  @override
  String get media_hub_unavailable => '\$title is temporarily unavailable';

  @override
  String get media_refine_with_tags => 'Refine your search with the tags.';

  @override
  String get media_find_favourite_genres => 'Find your favourite genres.';

  @override
  String get media_personalise_reading =>
      'Personalise your reading experience.';

  @override
  String get media_resume_where_left => 'Pick up where you left off.';

  @override
  String get media_official_manga =>
      'Official manga available on legal platforms.';

  @override
  String get media_no_badge => 'No badge published by this source.';

  @override
  String get media_remind_me => 'Remind me';

  @override
  String get media_computing_size => 'Computing size…';

  @override
  String get media_fetching_formats => 'Fetching formats…';

  @override
  String get media_background => 'Background';

  @override
  String get media_collapse => 'Collapse';

  @override
  String get media_expand => 'Expand';

  @override
  String media_videos_processed(Object done, Object total) {
    return '$done/$total videos processed';
  }

  @override
  String media_videos_selected(Object size, Object total) {
    return '$total videos · $size';
  }

  @override
  String get media_selection_mode => 'Multiple selection';

  @override
  String get media_finish_selection => 'Finish selection';

  @override
  String get media_quality_all => 'Quality (all)';

  @override
  String get media_language_all => 'Language (all)';

  @override
  String get media_in_5_min => 'In 5 min';

  @override
  String get media_quick_summary => 'Quick summary';

  @override
  String get media_summary => 'Summary';

  @override
  String get media_creator => 'Creator:';

  @override
  String get media_read_direction => 'Panel reading direction.';

  @override
  String get media_official_badge => 'SERIES';

  @override
  String get media_recent => 'Recent';

  @override
  String get media_bulk_download => 'Download';

  @override
  String media_show_more(Object count) {
    return 'Show more ($count left)';
  }

  @override
  String get media_comment_video => 'Comment video';

  @override
  String media_replies(Object count) {
    return '$count replies';
  }

  @override
  String media_videos_count(Object count) {
    return '$count videos';
  }

  @override
  String media_elements_count(Object count) {
    return '$count items';
  }

  @override
  String media_element_n(Object number) {
    return 'Item $number';
  }

  @override
  String get media_queue_added => 'Downloads added to the queue: ';

  @override
  String media_queue_cancelled(Object queued) {
    return 'Cancelled · $queued added, ';
  }

  @override
  String media_queue_failed(Object failed, Object remaining) {
    return '$failed failed, $remaining remaining.';
  }

  @override
  String get media_series_suffix => 'series';

  @override
  String get media_february => 'February';

  @override
  String get media_august => 'August';

  @override
  String get media_december => 'December';

  @override
  String get media_comedy => 'Comedy';

  @override
  String get media_already_downloaded_hidden => 'already downloaded hidden';

  @override
  String get media_first_card => 'first card';

  @override
  String get media_censored_hint =>
      'Whether the video is censored, uncensored or leaked.';

  @override
  String get media_audio_language_hint => 'Video language';

  @override
  String get media_country_flag_hint =>
      'Flag of the country associated with the published language.';

  @override
  String get media_subtitle_flag_hint =>
      'Flag of the available subtitle language.';

  @override
  String get media_dub_flag_hint => 'Flag of the available dub language.';

  @override
  String get media_platforms => 'See platforms';

  @override
  String get media_stats => 'See statistics';

  @override
  String get media_teams => 'See all teams';

  @override
  String get media_collection => 'See the collection';

  @override
  String get media_list => 'See the list';

  @override
  String get media_more_like => 'Top 20 series like Superman…';

  @override
  String get media_all_chapters => 'All chapters';

  @override
  String media_episode_count(Object count) {
    return '$count episodes';
  }

  @override
  String get media_episodes => 'Episodes';

  @override
  String get media_grid_comfortable => 'Spaced grid';

  @override
  String get media_grid_compact => 'Compact grid';

  @override
  String get media_grid_cover_only => 'Cover-only grid';

  @override
  String get media_download_nb => 'Download nb';

  @override
  String get media_badge_language => 'Video language';

  @override
  String get media_download_failed => 'Download failed';

  @override
  String get media_classic => 'Classic';

  @override
  String get media_type => 'Type';

  @override
  String get media_text_filter_hint => 'Type…';

  @override
  String get media_love_shows => 'Love shows';

  @override
  String get media_talk_shows => 'Talk shows';

  @override
  String get media_extension_only =>
      'Download only available for extension catalogues.';

  @override
  String get media_status_paused => 'On hiatus';

  @override
  String media_queue_queued(Object count) {
    return '$count download(s) queued, ';
  }

  @override
  String media_queue_failed_short(Object count) {
    return '$count failed';
  }

  @override
  String get media_anime => 'Anime';

  @override
  String get media_manga => 'Manga';

  @override
  String get media_movie => 'Movie';

  @override
  String get media_animation => 'Animation';

  @override
  String get media_documentary => 'Documentary';

  @override
  String get media_popular => 'Popular';

  @override
  String get media_trending => 'Trending';

  @override
  String get media_favorites => 'Favorites';

  @override
  String get media_a_z => 'A — Z';

  @override
  String get media_options => 'Options';

  @override
  String get media_selection => 'Selection';

  @override
  String get media_remove_from_list => 'Remove from my list';

  @override
  String get media_similar => 'Similar';

  @override
  String get media_media => 'Media';

  @override
  String get media_read_more => 'Read more';

  @override
  String get media_see_all => 'All';

  @override
  String media_wallpapers_count(Object count) {
    return 'Wallpapers ($count)';
  }

  @override
  String get media_no_trailer => 'No trailer available.';

  @override
  String get media_information => 'Information';

  @override
  String get media_title => 'Title';

  @override
  String get media_original_title => 'Original title';

  @override
  String get media_format => 'Format';

  @override
  String get media_status => 'Status';

  @override
  String get media_seasons => 'Seasons';

  @override
  String get media_origin_countries => 'Origin countries';

  @override
  String get media_votes_tmdb => 'TMDB votes';

  @override
  String get media_rating_tmdb => 'TMDB rating';

  @override
  String get media_budget => 'Budget';

  @override
  String get media_revenue => 'Revenue';

  @override
  String get media_in_production => 'In production';

  @override
  String get media_official_site => 'Official site';

  @override
  String get media_countries => 'Countries';

  @override
  String get media_production => 'Production';

  @override
  String get media_released => 'Released';

  @override
  String get media_status_ongoing2 => 'Ongoing';

  @override
  String get media_load_title_failed => 'Unable to load this page';

  @override
  String get media_retry_when_online =>
      'Try again when the connection is available.';

  @override
  String get media_cast_load_failed => 'Unable to load the cast.';

  @override
  String get media_load_page_failed => 'Unable to load this page.';

  @override
  String get media_series_lower => 'series';

  @override
  String get media_no_video_filter => 'No video matches the filter.';

  @override
  String get media_load_failed_retry => 'Load failed · Retry';

  @override
  String get media_job => 'Job';

  @override
  String get media_as => 'As';

  @override
  String get media_born_on => 'Born on';

  @override
  String get media_age => 'Age';

  @override
  String get media_from => 'From';

  @override
  String get media_films => 'movies';

  @override
  String media_videos_loaded(Object loaded, Object more, Object total) {
    return '$loaded / $total videos$more';
  }

  @override
  String get media_see_all_arrow => 'All >';

  @override
  String get media_weight_calculating => 'Computing size…';

  @override
  String media_weight_known(Object size) {
    return 'Computing · $size known';
  }

  @override
  String get media_weight_unavailable => 'Size unavailable';

  @override
  String media_weight_partial(Object size) {
    return '$size known · partial estimate';
  }

  @override
  String media_weight_total(Object size) {
    return '≈ $size total';
  }

  @override
  String get media_no_video_selected => 'No video selected.';

  @override
  String media_download_n_videos(Object count) {
    return 'Download $count video(s)';
  }

  @override
  String get media_auto_best => 'Auto (best)';

  @override
  String get media_if_missing => 'If missing';

  @override
  String get media_higher => 'Higher';

  @override
  String get media_exact => 'Exact';

  @override
  String get media_formats_loading => 'Fetching formats…';

  @override
  String get media_format_unavailable => 'Format unavailable';

  @override
  String get media_all_fem => 'All';

  @override
  String get media_uncheck_all => 'Uncheck all';

  @override
  String get media_check_all => 'Check all';

  @override
  String media_episodes_ratio(Object selected, Object total) {
    return '$selected/$total episodes';
  }

  @override
  String get media_one_video => '1 video';

  @override
  String media_fetching_parallel(Object count) {
    return 'Fetching in parallel · $count items';
  }

  @override
  String media_fetching(Object count) {
    return 'Fetching · $count items';
  }

  @override
  String media_n_videos_size(Object count, Object size) {
    return '$count videos · $size';
  }

  @override
  String media_comments_count(Object count) {
    return '$count comments';
  }

  @override
  String get media_best => 'Best';

  @override
  String get media_no_comment => 'No comment yet.';

  @override
  String media_replies_count(Object count) {
    return '$count reply(ies)';
  }

  @override
  String media_replies_hidden(Object count) {
    return '$count hidden reply(ies)';
  }

  @override
  String get media_chapter => 'Chapter';

  @override
  String get media_see_list => 'See the list';

  @override
  String get media_reading_direction => 'Page reading direction.';

  @override
  String get media_reader_settings_sub => 'Customise your reading experience.';

  @override
  String get media_previous_chapter => 'Previous chapter';

  @override
  String get media_next_chapter_alt => 'Next chapter';

  @override
  String get media_reading_direction_label => 'Reading direction';

  @override
  String get media_see_episodes => 'See the episodes';

  @override
  String get media_see_series => 'See the series';

  @override
  String get media_share => 'Share';

  @override
  String get media_director_colon => 'Director: ';

  @override
  String get marketplace_official => 'Official';

  @override
  String get marketplace_third_party => 'Third-party';

  @override
  String get marketplace_sign_in => 'Sign in';

  @override
  String marketplace_connect_title(Object name) {
    return 'Connection — $name';
  }

  @override
  String get marketplace_plugin_kind_music => 'Music plugin';

  @override
  String get marketplace_topic_metadata => 'Metadata';

  @override
  String get marketplace_topic_audio_source => 'Audio Source';

  @override
  String get watch_home_layout_unavailable =>
      'This extension\'s layout is unavailable.';

  @override
  String watch_home_layout_save_failed(Object error) {
    return 'Failed to save the layout: $error';
  }

  @override
  String get watch_home_layout_not_saved => 'The layout could not be saved.';

  @override
  String get watch_home_hold_section_first =>
      'Hold a section first, then pick “Replace”.';

  @override
  String get watch_home_section_gone =>
      'This section no longer exists in the layout.';

  @override
  String get watch_home_episode_card_incompatible =>
      'This episode card is not compatible with this selection.';

  @override
  String get watch_home_episode_card_grid_only =>
      'Custom episode cards are available on grid sections.';

  @override
  String get watch_home_chapter_card_incompatible =>
      'This chapter card is not compatible with this selection.';

  @override
  String get watch_home_chapter_card_grid_only =>
      'Custom chapter cards are available on grid sections.';

  @override
  String get watch_home_manga_card_incompatible =>
      'This Manga card is not compatible with this selection.';

  @override
  String get watch_home_manga_card_grid_only =>
      'Custom Manga cards are available on grid sections.';

  @override
  String watch_home_preview_refresh_failed(Object error) {
    return 'Layout saved, but the preview could not be refreshed: $error';
  }

  @override
  String get watch_home_no_video_in_playlist =>
      'No video available in this playlist.';

  @override
  String watch_home_playlist_load_failed(Object error) {
    return 'Unable to load the playlist: $error';
  }

  @override
  String get watch_home_default_poster => 'Standard poster';

  @override
  String get watch_home_default_card => 'Default card';

  @override
  String get watch_home_section_actions => 'Actions on this section';

  @override
  String get watch_home_move_up => 'Move one level up';

  @override
  String get watch_home_move_down => 'Move one level down';

  @override
  String get watch_home_replace_component => 'Replace the component';

  @override
  String get watch_home_manga_card_style => 'Manga card style';

  @override
  String get watch_home_episode_card_style => 'Episode card style';

  @override
  String get watch_home_chapter_card_style => 'Chapter card style';

  @override
  String watch_home_current_value(Object value) {
    return 'Current: $value';
  }

  @override
  String get watch_home_delete_section => 'Delete the section';

  @override
  String get watch_home_delete_section_title => 'Delete this section?';

  @override
  String watch_home_delete_section_body(Object title) {
    return '“$title” will be removed from this home.';
  }

  @override
  String get watch_home_no_section =>
      'No section. Use the JSON editor to create one.';

  @override
  String get watch_home_hold_to_edit => 'Hold to edit';

  @override
  String get watch_home_home => 'Home';

  @override
  String get watch_home_component_gallery => 'Component gallery';

  @override
  String get watch_home_json_editor => 'JSON editor';

  @override
  String get watch_home_close_edit_dock => 'Close the edit dock';

  @override
  String get watch_home_open_edit_dock => 'Open the edit dock';

  @override
  String get watch_home_choose_month => 'Choose a month';

  @override
  String get watch_home_source_unavailable =>
      'The source is temporarily unavailable.';

  @override
  String get watch_home_no_content => 'No content';

  @override
  String get watch_home_extension => 'Extension';

  @override
  String watch_home_search_in_source(Object source) {
    return 'Search in $source';
  }

  @override
  String get watch_home_search_in_extension => 'Search in the extension';

  @override
  String get watch_home_search_video_hint =>
      'Search for a video in this extension';

  @override
  String get watch_home_search_failed => 'Search failed';

  @override
  String get watch_home_reel_follow => 'Follow';

  @override
  String get watch_home_reel_following => 'Following';

  @override
  String get watch_home_reel_like => 'Like';

  @override
  String get watch_home_reel_comments => 'Comments';

  @override
  String get watch_home_reel_share => 'Share';

  @override
  String get watch_home_reel_no_comment => 'No comment yet.';

  @override
  String get watch_home_search => 'Search';

  @override
  String get watch_home_collection => 'Collection';

  @override
  String get watch_home_no_episode_from_source =>
      'No numbered episode with a valid URL was provided by this source.';

  @override
  String get watch_home_preview_search_unavailable =>
      'The preview search is temporarily unavailable.';

  @override
  String get watch_home_search_unavailable => 'Search unavailable';

  @override
  String get watch_home_search_source_unavailable =>
      'The source is temporarily unavailable. Retry in a moment.';

  @override
  String watch_home_nothing_matches_query(Object query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String get watch_home_no_chapter_from_source =>
      'No chapter with a valid title and URL was provided by this source.';

  @override
  String source_err_access_denied_http(Object code) {
    return 'Access denied (HTTP $code)';
  }

  @override
  String source_err_not_found_http(Object code) {
    return 'Not found (HTTP $code)';
  }

  @override
  String source_err_rate_limited_http(Object code) {
    return 'Too many requests (HTTP $code)';
  }

  @override
  String source_err_server_http(Object code) {
    return 'Server error (HTTP $code)';
  }

  @override
  String source_err_http(Object code) {
    return 'HTTP error $code';
  }

  @override
  String get source_err_access_blocked => 'Access blocked';

  @override
  String source_err_access_blocked_http(Object code) {
    return 'Access blocked (HTTP $code)';
  }

  @override
  String get source_err_verification_required => 'Verification required';

  @override
  String source_err_verification_required_http(Object code) {
    return 'Verification required (HTTP $code)';
  }

  @override
  String get source_err_connection_dropped => 'Connection dropped';

  @override
  String get source_err_check_network => 'Check your network';

  @override
  String get source_err_access_denied => 'Access denied';

  @override
  String get source_err_no_content => 'No content available';

  @override
  String get source_err_cloudflare_required =>
      'Cloudflare verification required';

  @override
  String get source_err_api_blocked => 'API access blocked';

  @override
  String get source_err_antibot_dropped =>
      'Anti-bot block — connection dropped';

  @override
  String get source_err_connection_failed => 'Connection failed';

  @override
  String get source_err_source_unavailable => 'Source unavailable';

  @override
  String get source_err_empty_box => 'Empty box';

  @override
  String get source_err_cloudflare_needed => 'Cloudflare verification needed';

  @override
  String get source_err_source_connection_failed =>
      'Failed to connect to the source';

  @override
  String get source_err_finish_verification =>
      'Finish the verification in the panel, then retry.';

  @override
  String get source_err_nothing_returned =>
      'The source returned nothing. Retry, or update the extension.';

  @override
  String get source_err_pull_to_refresh => 'Pull down to refresh';

  @override
  String get source_err_details => 'Error details';

  @override
  String get source_err_hide_details => 'Hide details';

  @override
  String get source_err_copy_details => 'Copy the error details';

  @override
  String get source_err_copied => 'Error copied';

  @override
  String get media_trending_week => 'Trending this week';

  @override
  String get media_airing_today => 'Airing today';

  @override
  String get media_on_the_air => 'On the air';

  @override
  String get media_now_playing => 'Now playing';

  @override
  String get media_upcoming => 'Upcoming';

  @override
  String get media_movies => 'Movies';

  @override
  String get media_live_tv => 'Live TV';

  @override
  String get media_library => 'Library';

  @override
  String get media_tv_genres => 'TV genres';

  @override
  String get media_streaming_services => 'Streaming services';

  @override
  String get media_stories => 'Stories';

  @override
  String get media_documentaries => 'Documentaries';

  @override
  String media_docu_prefix(Object name) {
    return 'Docu · $name';
  }

  @override
  String media_max_available(Object count) {
    return 'Maximum available: $count';
  }

  @override
  String get media_continue => 'Continue';

  @override
  String get media_customize_ellipsis => 'Customise…';

  @override
  String get media_untitled => 'Untitled';

  @override
  String get media_catalogue_unavailable => 'Catalogue unavailable';

  @override
  String media_catalogue_load_failed(Object title) {
    return 'Unable to load $title for now.';
  }

  @override
  String get media_back => 'Back';

  @override
  String get media_all_episodes_queued => 'All episodes queued';

  @override
  String media_start_failed(Object error) {
    return 'Unable to start: $error';
  }

  @override
  String get media_reel_mode => 'Reel mode';

  @override
  String media_season_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seasons',
      one: '$count season',
    );
    return '$_temp0';
  }

  @override
  String media_season_n(Object number) {
    return 'Season $number';
  }

  @override
  String get media_synopsis => 'Synopsis';

  @override
  String get media_crew_info => 'Crew & info';

  @override
  String get media_country => 'Country';

  @override
  String get media_director => 'Director';

  @override
  String get media_cast => 'Cast';

  @override
  String get media_unknown => 'Unknown';

  @override
  String get media_licenced => 'Licensed';

  @override
  String get media_add_to_library => 'Add to library';

  @override
  String get media_resources => 'Resources';

  @override
  String get media_provided_by => 'Provided by';

  @override
  String get media_source_options => 'Source options';

  @override
  String get media_refresh => 'Refresh';

  @override
  String get media_choose_season => 'Choose the season';

  @override
  String get media_choose_language => 'Choose the language';

  @override
  String get media_choose_resolution => 'Choose the resolution';

  @override
  String get media_no_episode_available => 'No episode available';

  @override
  String get media_watch_now => 'Watch';

  @override
  String get media_year => 'Year';

  @override
  String get media_no_details => 'No details available';

  @override
  String get media_previews => 'Previews';

  @override
  String media_episodes_label(Object count) {
    return 'Episodes ($count)';
  }

  @override
  String get media_status_ongoing_label => 'Ongoing';

  @override
  String get media_status_completed_label => 'Completed';

  @override
  String get media_status_cancelled_label => 'Cancelled';

  @override
  String get media_status_on_hold_label => 'On hold';

  @override
  String get media_film => 'Movie';

  @override
  String get media_casting => 'Casting';

  @override
  String get media_no_recommendation => 'No recommendation';

  @override
  String get media_suggestions_here => 'Suggestions will appear here.';

  @override
  String get media_anonymous => 'Anonymous';

  @override
  String get media_loading_comments => 'Loading comments…';

  @override
  String media_reply_to(Object author) {
    return 'Reply to $author…';
  }

  @override
  String get media_your_comment => 'Your comment…';

  @override
  String get media_add_comment => 'Add a comment…';

  @override
  String get media_me => 'Me';

  @override
  String get media_just_now => 'just now';

  @override
  String get media_reply => 'Reply';

  @override
  String media_time_ago_hours(Object count) {
    return '${count}h ago';
  }

  @override
  String media_time_ago_days(Object count) {
    return '${count}d ago';
  }

  @override
  String get media_sample_comment_1 =>
      'Great film! The opening parkour scene genuinely took my breath away.';

  @override
  String get media_sample_comment_2 =>
      'Agreed, and the choreography is clearly real, not CGI.';

  @override
  String get media_sample_comment_3 => 'Exactly! You can feel every landing.';

  @override
  String get media_sample_comment_4 =>
      'A performance that is still missed today.';

  @override
  String get media_sample_comment_5 =>
      'The original with the other lead is even better!';

  @override
  String get media_sample_comment_6 => 'French action cinema at its best.';

  @override
  String get media_sample_comment_7 =>
      'The action is good but the plot is fairly predictable. 3.5/5 for me.';

  @override
  String get media_sample_comment_8 =>
      'Just finished it. The ending is satisfying even if you see it coming.';

  @override
  String get media_sample_comment_9 => 'Same, perfect for a relaxed evening.';

  @override
  String get media_not_available => 'N/A';

  @override
  String get media_webview => 'WebView';

  @override
  String get player_fit_contain => 'Fit';

  @override
  String get player_fit_cover => 'Fullscreen';

  @override
  String get player_fit_fill => 'Fill';

  @override
  String get player_fit_height => '↕ Height';

  @override
  String get player_speed_title => 'Playback speed';

  @override
  String get player_speed_short => 'Speed';

  @override
  String get player_unlock => 'Unlock';

  @override
  String get player_capture => 'Capture';

  @override
  String get player_capture_saved => 'Capture saved';

  @override
  String get player_capture_failed => 'Capture failed';

  @override
  String get player_auto => 'Auto';

  @override
  String get player_portrait => 'Portrait';

  @override
  String get player_landscape_left => 'Landscape ←';

  @override
  String get player_landscape_right => 'Landscape →';

  @override
  String get player_orientation => 'Orientation';

  @override
  String player_rotation_toast(Object mode) {
    return 'Rotation: $mode';
  }

  @override
  String player_resume_at(Object time) {
    return 'Resuming at $time';
  }

  @override
  String get player_no_source_to_download => 'No source to download';

  @override
  String get player_already_downloaded =>
      'This resolution is already downloaded';

  @override
  String get player_episode_not_in_library =>
      'Episode not found in the library';

  @override
  String player_download_added(Object quality) {
    return 'Download $quality added';
  }

  @override
  String get player_download_duplicate =>
      'This resolution is already downloaded or in progress';

  @override
  String get player_queue_failed => 'Unable to queue';

  @override
  String get player_quality_label => 'Quality';

  @override
  String get player_download_quality => 'Download · quality';

  @override
  String get player_no_quality => 'No quality';

  @override
  String player_quality_toast(Object quality) {
    return 'Quality: $quality';
  }

  @override
  String get player_track_none => 'None';

  @override
  String player_track_n(Object number) {
    return 'Track $number';
  }

  @override
  String player_subtitle_n(Object number) {
    return 'Subtitle $number';
  }

  @override
  String player_sub_n(Object number) {
    return 'Sub $number';
  }

  @override
  String get player_tab_playback => 'Playback';

  @override
  String get player_tab_audio => 'Audio';

  @override
  String get player_tab_subtitles => 'Subtitles';

  @override
  String get player_seek_interval => 'SEEK INTERVAL';

  @override
  String get player_video_adjust => 'VIDEO ADJUSTMENT';

  @override
  String get player_no_audio_track => 'No audio track';

  @override
  String get player_no_subtitle => 'No subtitle';

  @override
  String get player_disabled => 'Disabled';

  @override
  String get player_disable => 'Disable';

  @override
  String get player_bilingual => 'Bilingual';

  @override
  String get player_subtitle_offset => 'Subtitle offset';

  @override
  String get player_subtitle_style => 'Subtitle style';

  @override
  String get player_style_outline => 'Outline';

  @override
  String get player_style_background => 'Background';

  @override
  String get player_player_settings => 'Player settings';

  @override
  String get player_loop => 'Loop';

  @override
  String get player_loop_none => 'None';

  @override
  String get player_loop_one => 'One';

  @override
  String get player_loop_all => 'All';

  @override
  String get player_brightness => 'Brightness';

  @override
  String get player_more => 'More';

  @override
  String get player_audio_only => 'Audio only';

  @override
  String get player_mirror => 'Mirror';

  @override
  String get player_night_mode => 'Night mode';

  @override
  String get player_loop_episode => 'Episode';

  @override
  String get player_ab_repeat => 'A–B repeat';

  @override
  String get player_ab_set_a => 'Set A';

  @override
  String get player_ab_set_b => 'Set B';

  @override
  String get player_audio_track => 'Audio track';

  @override
  String get player_no_track => 'No track';

  @override
  String get player_episodes => 'Episodes';

  @override
  String get player_no_episode => 'No episode';

  @override
  String player_episode_n(Object number) {
    return 'Episode $number';
  }

  @override
  String player_ep_short(Object number) {
    return 'EP $number';
  }

  @override
  String get player_next_episode_in => 'Next episode in';

  @override
  String get player_play_now => 'Play now';

  @override
  String get player_language => 'Language';

  @override
  String get player_webview_error => 'Watch player queue request failed';

  @override
  String get discover_title => 'Discovery';

  @override
  String get discover_mode_watch => 'Watch';

  @override
  String get discover_mode_manga => 'Manga';

  @override
  String get discover_mode_novel => 'Novel';

  @override
  String get discover_mode_music => 'Music';

  @override
  String get discover_mode_custom => 'Custom';

  @override
  String get discover_type_all => 'All anime';

  @override
  String get discover_type_film => 'Movie';

  @override
  String get discover_type_series => 'TV series';

  @override
  String get discover_type_ova => 'OVA / ONA';

  @override
  String get discover_type_manga => 'Manga';

  @override
  String get discover_type_webtoon => 'Webtoon';

  @override
  String get discover_type_novel => 'Novel';

  @override
  String get discover_type_one_shot => 'One shot';

  @override
  String get discover_sort_trending => 'Trending';

  @override
  String get discover_sort_popularity => 'Popularity';

  @override
  String get discover_sort_score => 'Top rated';

  @override
  String get discover_sort_newest => 'Newest';

  @override
  String get discover_sort_az => 'A–Z';

  @override
  String get discover_season_any => 'All seasons';

  @override
  String get discover_season_winter => 'Winter';

  @override
  String get discover_season_spring => 'Spring';

  @override
  String get discover_season_summer => 'Summer';

  @override
  String get discover_season_fall => 'Fall';

  @override
  String get discover_status_any => 'All statuses';

  @override
  String get discover_status_finished => 'Finished';

  @override
  String get discover_status_releasing => 'Airing';

  @override
  String get discover_status_not_yet_released => 'Not yet released';

  @override
  String get discover_status_cancelled => 'Cancelled';

  @override
  String get discover_status_hiatus => 'On hold';

  @override
  String get discover_score_any => 'All scores';

  @override
  String get discover_clear_filters => 'Clear filters';

  @override
  String get discover_section_sort => 'SORT BY';

  @override
  String get discover_section_display => 'DISPLAY MODE';

  @override
  String get discover_section_grid_size => 'GRID SIZE';

  @override
  String get discover_display_compact => 'Compact grid';

  @override
  String get discover_display_comfortable => 'Comfortable grid';

  @override
  String get discover_display_cinema => 'Cinema';

  @override
  String get discover_display_list => 'List';

  @override
  String get discover_adult_on => 'Adult on';

  @override
  String get discover_adult => 'Adult content';

  @override
  String get discover_filters => 'Filters';

  @override
  String get discover_clear => 'Clear';

  @override
  String get discover_content_type => 'Content type';

  @override
  String get discover_sort_by => 'Sort by';

  @override
  String get discover_genre => 'Genre';

  @override
  String get discover_genres => 'Genres';

  @override
  String get discover_all_genres => 'All genres';

  @override
  String get discover_format => 'Format';

  @override
  String get discover_formats => 'Formats';

  @override
  String get discover_all_formats => 'All formats';

  @override
  String get discover_season => 'Season';

  @override
  String get discover_year => 'Year';

  @override
  String get discover_status => 'Status';

  @override
  String get discover_score_min => 'Min score';

  @override
  String get discover_score_minimum => 'Minimum score';

  @override
  String get discover_load_failed => 'Unable to load';

  @override
  String get discover_retry => 'Retry';

  @override
  String discover_no_results_for(Object query) {
    return 'No results found for $query';
  }

  @override
  String get discover_no_results_hint =>
      'Try another term or change the filters.';

  @override
  String get discover_timeless => 'Timeless';

  @override
  String get discover_choose_extension => 'Choose an extension';

  @override
  String get discover_choose_extension_body =>
      'Select an installed extension to explore its content.';

  @override
  String get discover_select_extension => 'Select an extension';

  @override
  String get discover_reset => 'Reset';

  @override
  String get discover_change => 'Change';

  @override
  String get discover_load_error => 'Loading error';

  @override
  String get discover_no_result => 'No result';

  @override
  String get discover_no_extension_installed => 'No extension installed';

  @override
  String get discover_install_hint =>
      'Install extensions from Browse → Extensions.';

  @override
  String get discover_search => 'Search…';

  @override
  String discover_search_in(Object name) {
    return 'Search in $name…';
  }

  @override
  String get discover_all => 'All';

  @override
  String get discover_sources_label => 'SOURCE';

  @override
  String get discover_extension => 'Extension';

  @override
  String get discover_unknown_title => 'Unknown';

  @override
  String get discover_this_search => 'this search';

  @override
  String get discover_search_start_hint => 'Type your search to start.';

  @override
  String get discover_what_to_read => 'What do you want to read?';

  @override
  String get discover_what_to_watch => 'What do you want to watch?';

  @override
  String get discover_preview_unavailable => 'Preview unavailable';

  @override
  String get discover_channels => 'CHANNELS';

  @override
  String get discover_actresses => 'ACTRESSES';

  @override
  String get discover_videos => 'VIDEOS';

  @override
  String get discover_tmdb_tab_all => 'All';

  @override
  String get discover_tmdb_tab_movies => 'Movies';

  @override
  String get discover_tmdb_tab_series => 'Series';

  @override
  String get discover_tmdb_tab_people => 'Celebrities';

  @override
  String get discover_tmdb_tab_collections => 'Collections';

  @override
  String get discover_tmdb_hint_movie => 'Search a movie…';

  @override
  String get discover_tmdb_hint_series => 'Search a series…';

  @override
  String get discover_tmdb_hint_all => 'Movie, series or celebrity…';

  @override
  String get discover_tmdb_unavailable => 'Search unavailable';

  @override
  String get discover_tmdb_no_celebrity => 'No celebrity';

  @override
  String get discover_tmdb_try_another_name => 'Try another name.';

  @override
  String get discover_tmdb_no_collection => 'No collection';

  @override
  String get discover_tmdb_no_collection_match =>
      'No saga or collection matches.';

  @override
  String get discover_tmdb_try_another_title => 'Try another title.';

  @override
  String get home_tab_all => 'All';

  @override
  String get home_tab_movie => 'Movie';

  @override
  String get home_tab_series => 'Series';

  @override
  String get home_tab_music => 'Music';

  @override
  String get home_tab_anime => 'Anime';

  @override
  String get home_tab_asia => 'Asia';

  @override
  String get home_tab_kids => 'Kids';

  @override
  String get home_tab_western => 'Western';

  @override
  String get home_tab_africa => 'Africa';

  @override
  String get home_tab_tv_short => 'TV Short';

  @override
  String get home_tab_football => 'Football';

  @override
  String get home_tab_games => 'Games';

  @override
  String get home_for_you => 'For you';

  @override
  String get home_search_hint => 'Search a title…';

  @override
  String get home_search_action => 'Search';

  @override
  String get home_offline_banner =>
      'Connection unavailable — showing cached data';

  @override
  String get home_spotlight => 'Featured';

  @override
  String get home_animation => 'Animation';

  @override
  String get home_popular_movies => 'Popular movies';

  @override
  String get home_trending_week => 'Trending this week';

  @override
  String get home_top_rated => 'Top rated';

  @override
  String get home_now_playing => 'Now in theaters';

  @override
  String get home_upcoming => 'Upcoming';

  @override
  String get home_movies => 'Movies';

  @override
  String get home_movies_studio => 'Movies · Studio';

  @override
  String get home_popular_series => 'Popular series';

  @override
  String get home_tv_trending_week => 'TV trending this week';

  @override
  String get home_top_rated_series => 'Top rated series';

  @override
  String get home_watch_tonight => 'Watch tonight';

  @override
  String get home_airing_today => 'Airing today';

  @override
  String get home_airing_now => 'Currently airing';

  @override
  String get home_series => 'Series';

  @override
  String get home_series_studio => 'Series · Studio';

  @override
  String get home_country_fr => 'France';

  @override
  String get home_country_us_uk => 'United States / United Kingdom';

  @override
  String get home_country_kr => 'South Korea';

  @override
  String get home_country_jp => 'Japan';

  @override
  String get home_kids => 'Kids';

  @override
  String get home_kids_sub => 'Cartoons & kids content';

  @override
  String get home_western => 'Western';

  @override
  String get home_western_sub => 'US/EU series & movies';

  @override
  String get home_africa => 'Africa';

  @override
  String get home_africa_sub => 'African content';

  @override
  String get home_football => 'Football';

  @override
  String get home_football_sub => 'Matches & highlights';

  @override
  String get home_games => 'Games';

  @override
  String get home_games_sub => 'ROM library';

  @override
  String get home_tv_short => 'TV Short';

  @override
  String get home_tv_short_sub => 'Mini-series, shorts & short dramas';

  @override
  String get home_mini_dramas => 'Mini-dramas & shorts';

  @override
  String get home_top_rated_short => 'Top rated (short)';

  @override
  String get home_no_movie => 'No movie available';

  @override
  String get home_best_rated => 'Best rated';

  @override
  String get home_explore_genre => 'Explore by genre';

  @override
  String get home_trending_series => 'Trending series';

  @override
  String get home_sagas_long => 'Sagas & long series';

  @override
  String get home_top_popular => 'Top popular';

  @override
  String get home_best_rated_fem => 'Best rated';

  @override
  String get home_kdrama_trending => 'Trending K-Drama';

  @override
  String get home_cdrama_manhua => 'C-Drama / Manhua';

  @override
  String get home_top_asia => 'Top Asia';

  @override
  String get home_open => 'Open';

  @override
  String get home_see_all => 'See all';

  @override
  String get home_view_all => 'View all';

  @override
  String get home_favorite => 'Favourite';

  @override
  String get home_origin => 'Origin';

  @override
  String get home_continue_watching => 'Continue watching';

  @override
  String get home_tonight_pick => 'TONIGHT’S PICK';

  @override
  String get home_recent_releases => 'Recently added';

  @override
  String get home_trending_now => 'Trending now';

  @override
  String get home_top_now => 'Top this week';

  @override
  String get home_drama_k => 'K-Drama';

  @override
  String get home_drama_c => 'C-Drama';

  @override
  String get home_drama_j => 'J-Drama';

  @override
  String get account_guest => 'Guest';

  @override
  String get account_connect_tracker => 'Connect a tracker to sync';

  @override
  String get account_settings => 'Settings';

  @override
  String get account_tracking => 'Tracking';

  @override
  String get account_history => 'History';

  @override
  String get account_downloads => 'Downloads';

  @override
  String get account_about => 'About';

  @override
  String get tmdb_cat_movies => 'Movies';

  @override
  String get tmdb_cat_series => 'Series';

  @override
  String get tmdb_cat_refresh => 'Refresh';

  @override
  String get tmdb_cat_now_playing => 'Now in theaters';

  @override
  String get tmdb_cat_airing_now => 'Currently airing';

  @override
  String get tmdb_cat_airing_today => 'Airing today';

  @override
  String get tmdb_cat_movies_sub =>
      'The movies of the moment, with their TMDB posters and information.';

  @override
  String get tmdb_cat_series_sub =>
      'The series of the moment, with their TMDB posters and information.';

  @override
  String get tmdb_cat_empty => 'No content available.';

  @override
  String tmdb_cat_rating(Object rating) {
    return 'TMDB rating: $rating/10';
  }

  @override
  String tmdb_cat_date(Object date) {
    return 'Date: $date';
  }

  @override
  String get tmdb_cat_catalogue => 'the TMDB catalogue';

  @override
  String get tmdb_cat_load_failed => 'Failed to load TMDB content.';

  @override
  String get home_search_hint_all => 'Movie, series, anime, music…';

  @override
  String get home_search_recent => 'Recent';

  @override
  String get home_search_everyone => 'Everyone is searching';

  @override
  String get home_search_error => 'Search error';

  @override
  String home_search_no_anilist(Object query) {
    return 'No AniList results for “$query”';
  }

  @override
  String get home_search_no_data => 'No data';

  @override
  String get home_search_in_watch => 'Search in Watch';

  @override
  String home_search_in_watch_body(Object query) {
    return 'Search “$query” across all your installed Watch extensions, with filters for language, source and more.';
  }

  @override
  String get home_search_open_watch => 'Open Watch search';

  @override
  String get episode_sources_tracks_failed => 'Unable to load the tracks.';

  @override
  String get episode_sources_title => 'Episode sources';

  @override
  String episode_sources_label(Object number, Object title) {
    return 'Episode $number · $title';
  }

  @override
  String episode_sources_searching(Object checked, Object total) {
    return 'Searching $checked / $total sources';
  }

  @override
  String get episode_sources_no_extension =>
      'No active anime extension is installed.';

  @override
  String get episode_sources_searching_hint =>
      'Searching for the episode on the installed extensions…';

  @override
  String get episode_sources_none => 'No extension offers this episode.';

  @override
  String episode_sources_unanswered(Object count) {
    return '$count source(s) did not respond.';
  }

  @override
  String get episode_sources_extension => 'Extension';

  @override
  String episode_sources_episode_n(Object number) {
    return 'Episode $number';
  }

  @override
  String get episode_sources_view_tracks => 'View quality and subtitles';

  @override
  String get episode_sources_retry_tracks => 'Retry the tracks';

  @override
  String get episode_sources_no_track => 'No video track detected.';

  @override
  String get episode_sources_quality => 'Quality';

  @override
  String get episode_sources_audio => 'Audio';

  @override
  String get episode_sources_subtitles => 'Subtitles';

  @override
  String get episode_sources_subtitles_none => 'Not indicated';

  @override
  String get episode_sources_play => 'Play this episode';

  @override
  String get download_sheet_title => 'Download';

  @override
  String get download_sheet_resources => 'Resources';

  @override
  String get download_sheet_added_by => 'Added by';

  @override
  String get download_sheet_audio_original => 'Original audio';

  @override
  String get download_sheet_select_all => 'Select all';

  @override
  String get download_sheet_website => 'Website';

  @override
  String get download_sheet_source_code => 'Source code';

  @override
  String get download_sheet_no_resource => 'No resource available';

  @override
  String get download_sheet_all_downloaded =>
      'All the qualities are already downloaded.';

  @override
  String get download_sheet_no_link => 'No link available.';

  @override
  String get download_sheet_no_episode => 'No episode available.';

  @override
  String download_sheet_no_link_for(Object name) {
    return 'No link for $name';
  }

  @override
  String download_sheet_open_failed(Object app) {
    return 'Could not open $app — check that it is installed.';
  }

  @override
  String download_sheet_season(Object number) {
    return 'Season $number';
  }

  @override
  String get download_sheet_season_word => 'Season';

  @override
  String get remote_server_title => 'Remote server';

  @override
  String get remote_public_link => 'Public link (SSH tunnel)';

  @override
  String get remote_paste_in_web => 'Paste this link into the web version';

  @override
  String get remote_tunnel_starting => 'Tunnel is starting…';

  @override
  String get remote_tunnel_ssh_hint => 'SSH connection — about 5 seconds';

  @override
  String get remote_local_link => 'Local link (same Wi-Fi network)';

  @override
  String get remote_use_same_network =>
      'Use this if you are on the same network';

  @override
  String get remote_api_key => 'API key';

  @override
  String get remote_api_key_hint =>
      'Add it as ?key=... or as an Authorization: Bearer header on every /api call';

  @override
  String get remote_copy => 'Copy';

  @override
  String get remote_key_copied => 'Key copied';

  @override
  String get remote_regenerate => 'Regenerate (invalidates the old key)';

  @override
  String get remote_new_key => 'New key generated';

  @override
  String get remote_how_to_use => 'How to use';

  @override
  String get remote_how_to_use_body =>
      '1. Copy the public link above\n2. Open Watchtower on the web\n3. Go to Settings → Remote connection\n4. Paste the link and sign in\n5. Every extension and source becomes available';

  @override
  String get remote_how_it_works => 'How it works';

  @override
  String get remote_how_it_works_body =>
      'When Remote Mode is on, your device becomes a server. A public link is created automatically through an SSH tunnel (localhost.run) — reachable from anywhere, with no download and no network setup.\n\nThe web version of Watchtower can then connect to this link to use all your installed extensions and sources.';

  @override
  String get remote_tunnel_unavailable => 'Tunnel unavailable';

  @override
  String get remote_copy_error => 'Copy the error';

  @override
  String get remote_check_connection =>
      'Check your internet connection and try again.';

  @override
  String get remote_error_copied => 'Error copied';

  @override
  String get remote_link_copied => 'Link copied';

  @override
  String get remote_connect_title => 'Connect to the Watchtower server';

  @override
  String get remote_connect_steps =>
      '1. Open Watchtower on your phone or PC\n2. Go to Settings → Remote Mode\n3. Turn the server on, then copy the public link and the API key\n4. Paste them here — the next visit will be automatic';

  @override
  String get remote_server_url_label => 'Server URL';

  @override
  String get remote_api_key_label => 'Server API key';

  @override
  String get remote_show_key => 'Show the key';

  @override
  String get remote_hide_key => 'Hide the key';

  @override
  String get remote_enter_url => 'Enter a server URL.';

  @override
  String get remote_enter_api_key => 'Enter the API key shown in Remote Mode.';

  @override
  String get remote_http_blocked =>
      'HTTP URL blocked by the browser (this page is HTTPS).\nUse the HTTPS public link of the SSH tunnel:\ne.g. https://xxxx.lhr.life';

  @override
  String get remote_timeout_10 =>
      'Timed out (10s) — server unreachable or wrong URL';

  @override
  String get remote_wrong_api_key =>
      'Wrong API key. Copy the key shown in Remote Mode.';

  @override
  String remote_api_unreachable(Object code) {
    return 'The server responds, but its API is unreachable (HTTP $code).';
  }

  @override
  String get remote_connected_sync => 'Server connected — syncing…';

  @override
  String remote_not_found(Object code) {
    return 'Server not found (HTTP $code).\nCheck that Remote Mode is active on your device.';
  }

  @override
  String get remote_timeout_short => 'Timed out';

  @override
  String remote_connect_failed(Object error) {
    return 'Could not connect: $error';
  }

  @override
  String get remote_connecting => 'Connecting…';

  @override
  String get remote_connect => 'Connect';

  @override
  String get about_developer => 'Developer';

  @override
  String get about_check_now => 'Check now';

  @override
  String get about_check_hint => 'Look for the latest available version';

  @override
  String about_up_to_date(Object version) {
    return 'You have the latest version: $version';
  }

  @override
  String get about_read_logs => 'Read the logs';

  @override
  String get about_logs_hint => 'Full, coloured and filterable view';

  @override
  String get about_binary_engines => 'BINARY ENGINES';

  @override
  String get about_choose_engines =>
      'Pick the engines to install for your needs.';

  @override
  String get about_engine_download => 'Download';

  @override
  String get about_aria2_desc =>
      'Multi-connection engine for HTTP, FTP, BitTorrent and Magnet.';

  @override
  String get about_more_engines => 'More engines are coming soon.';

  @override
  String get about_installed => 'Installed';

  @override
  String get about_available => 'Available';

  @override
  String get about_stable => 'Stable';

  @override
  String get about_aria2_tagline =>
      'High-performance multi-connection download engine';

  @override
  String get about_feature_multi => 'Multi-connections';

  @override
  String get about_feature_resume => 'Resume';

  @override
  String get about_feature_open_source => 'Open source';

  @override
  String get about_import_binary => 'Import a local binary';

  @override
  String about_aria2_fetch_failed(Object code) {
    return 'Could not fetch the aria2 release ($code)';
  }

  @override
  String get about_aria2_none => 'No aria2 binary available';

  @override
  String about_aria2_error(Object error) {
    return 'aria2 fetch error: $error';
  }

  @override
  String get about_download_aria2c => 'Download aria2c';

  @override
  String get about_choose_aria2c => 'Choose an aria2c binary';

  @override
  String get about_file_unreachable => 'File unreachable';

  @override
  String about_binary_imported(Object name) {
    return 'aria2c binary imported: $name';
  }

  @override
  String about_import_failed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get about_choose_binary => 'Choose the binary';

  @override
  String get about_compatible => 'Compatible';

  @override
  String get about_all_platforms => 'All platforms';

  @override
  String get about_download_complete => 'Download complete';

  @override
  String get about_download_failed => 'Download failed';

  @override
  String get log_viewer_title => 'Logs';

  @override
  String get log_viewer_copy_all => 'Copy all';

  @override
  String get log_viewer_download_share => 'Download / Share';

  @override
  String get log_viewer_download_txt => 'Download .txt';

  @override
  String get log_viewer_download_md => 'Download .md';

  @override
  String get log_viewer_share => 'Share';

  @override
  String get log_viewer_refresh => 'Refresh';

  @override
  String get log_viewer_options => 'Options';

  @override
  String get log_viewer_overlay_hide => 'Hide overlay';

  @override
  String get log_viewer_overlay_live => 'Live overlay';

  @override
  String get log_viewer_autoscroll_on => 'Auto-scroll ON';

  @override
  String get log_viewer_autoscroll_off => 'Auto-scroll OFF';

  @override
  String get log_viewer_clear_logs => 'Clear the logs';

  @override
  String get log_viewer_filters => 'Filters';

  @override
  String get log_viewer_no_log => 'No log recorded';

  @override
  String get log_viewer_no_result => 'No result';

  @override
  String get log_viewer_clear_filters => 'Clear the filters';

  @override
  String get log_viewer_scroll_bottom => 'Go to the bottom';

  @override
  String log_viewer_line(Object count) {
    return '$count line';
  }

  @override
  String log_viewer_lines(Object count) {
    return '$count lines';
  }

  @override
  String log_viewer_filter(Object query) {
    return ' · filter: \"$query\"';
  }

  @override
  String log_viewer_error(Object count) {
    return '$count error';
  }

  @override
  String log_viewer_errors(Object count) {
    return '$count errors';
  }

  @override
  String log_viewer_warning(Object count) {
    return '$count warning';
  }

  @override
  String log_viewer_warnings(Object count) {
    return '$count warnings';
  }

  @override
  String get log_viewer_filter_hint => 'Filter the logs…';

  @override
  String get log_viewer_content_type => 'Content type';

  @override
  String get log_viewer_show_all => 'Show everything';

  @override
  String get log_viewer_level => 'Level';

  @override
  String get log_viewer_error_level => 'Error';

  @override
  String get log_viewer_warning_level => 'Warning';

  @override
  String get log_viewer_success_level => 'Success';

  @override
  String get log_viewer_info_level => 'Info';

  @override
  String get log_viewer_debug_level => 'Debug';

  @override
  String get log_viewer_tags => 'Tags';

  @override
  String get log_viewer_reset_filters => 'Reset all the filters';

  @override
  String get log_viewer_open_browser => 'Open in the browser';

  @override
  String get log_viewer_cat_extensions => 'Extensions';

  @override
  String get log_viewer_cat_watch => 'Watch';

  @override
  String get log_viewer_cat_manga => 'Manga';

  @override
  String get log_viewer_cat_images => 'Images';

  @override
  String get log_viewer_no_file => 'No log file found';

  @override
  String log_viewer_saved(Object path) {
    return 'Saved: $path';
  }

  @override
  String log_viewer_download_error(Object error) {
    return 'Download error: $error';
  }

  @override
  String get log_viewer_copied => 'Logs copied to the clipboard';

  @override
  String get log_viewer_mode_extreme =>
      '⚡ Extreme – everything is logged. RAM +++. Use with care.';

  @override
  String get log_viewer_mode_debug_warn =>
      '⚠ Debug mode active – high RAM usage';

  @override
  String get browse_diag2_actions => 'Actions';

  @override
  String get browse_diag2_status_ok => 'OK';

  @override
  String get browse_diag2_status_errors => 'Errors';

  @override
  String get browse_diag2_status_running => 'Running';

  @override
  String get browse_diag2_status_idle => 'Waiting';

  @override
  String browse_diag2_paused_progress(Object done, Object total) {
    return 'Paused — $done / $total';
  }

  @override
  String browse_diag2_running_progress(Object done, Object total) {
    return 'Running — $done / $total';
  }

  @override
  String browse_diag2_interrupted_progress(Object done, Object total) {
    return 'Interrupted — $done / $total';
  }

  @override
  String browse_diag2_complete_progress(Object fail, Object ok) {
    return 'Done · $ok OK · $fail error(s)';
  }

  @override
  String browse_diag2_sources_selected(Object count, Object selected) {
    return '$count extensions · $selected selected';
  }

  @override
  String get browse_diag2_cancel_interrupt => 'Cancel / interrupt';

  @override
  String get browse_diag2_reset => 'Reset';

  @override
  String browse_diag2_copy_report(Object format) {
    return 'Copy the report $format';
  }

  @override
  String get browse_diag2_interrupted => 'Interrupted';

  @override
  String browse_diag2_steps_ok(Object ok, Object total) {
    return '$ok/$total steps OK';
  }

  @override
  String browse_diag2_step_errors(Object count) {
    return ' · $count error(s)';
  }

  @override
  String get browse_diag2_search => 'Search';

  @override
  String get browse_diag2_search_hint => 'Search an extension…';

  @override
  String get browse_diag2_status => 'Status';

  @override
  String get browse_diag2_sort => 'Sort';

  @override
  String get browse_diag2_language => 'Language';

  @override
  String browse_diag2_selected_for_diag(Object selected, Object total) {
    return '$selected / $total extensions selected for the diagnostic';
  }

  @override
  String get browse_diag2_select_all => 'Select all';

  @override
  String get browse_diag2_deselect_all => 'Deselect all';

  @override
  String get browse_diag2_reset_filters => 'Reset the filters';

  @override
  String get browse_diag2_sort_name => 'Name';

  @override
  String get browse_diag2_sort_status => 'Status';

  @override
  String get browse_diag2_sort_duration => 'Duration';

  @override
  String get browse_diag2_hint_run =>
      'Run the analysis to test each step (Popular · Latest · Detail · Media).';

  @override
  String get browse_diag2_unknown => 'Unknown';

  @override
  String get browse_diag2_video_preview => 'Video preview';

  @override
  String get browse_diag2_page_preview => 'Page preview';

  @override
  String get browse_diag2_all_ok => 'All OK';

  @override
  String browse_diag2_log_lines_hint(Object count) {
    return '$count log lines — open the detail to read them';
  }

  @override
  String browse_diag2_progress_body(Object done, Object name, Object total) {
    return '$done / $total — $name';
  }

  @override
  String get browse_diag2_restart_diag => 'Relaunch the diagnostic';

  @override
  String get browse_source_pref_setting => 'Setting';

  @override
  String get browse_source_pref_saved_value => 'Saved value';

  @override
  String get browse_save => 'Save';

  @override
  String get browse_layout_none =>
      'No layout JSON is available for this extension.';

  @override
  String browse_layout_load_failed(Object error) {
    return 'Could not load the layout: $error';
  }

  @override
  String get browse_layout_saved => 'Layout saved on this device.';

  @override
  String get browse_layout_line_numbers => 'Line numbers';

  @override
  String get browse_edit_code_saved => 'Saved';

  @override
  String browse_layout_invalid_json(Object error) {
    return 'Invalid JSON: $error';
  }

  @override
  String browse_layout_save_failed(Object error) {
    return 'Could not save: $error';
  }

  @override
  String get browse_layout_view => 'View';

  @override
  String get browse_layout_alignment => 'Alignment';

  @override
  String get browse_layout_schema =>
      'The layout does not match the expected schema.';

  @override
  String browse_layout_title(Object name) {
    return 'Layout JSON · $name';
  }

  @override
  String get browse_layout_align_left => 'Left';

  @override
  String get browse_layout_align_center => 'Center';

  @override
  String get browse_create_extension => 'Create an extension';

  @override
  String get webview_offline_title =>
      'WebView is not available in the web version';

  @override
  String get webview_offline_desc =>
      'Sites cannot be displayed in the browser iframe because of X-Frame-Options policies. Open the link directly.';

  @override
  String webview_text_size_label(Object size) {
    return 'Text size: $size';
  }

  @override
  String get webview_text_normal => 'Normal';

  @override
  String get webview_text_large => 'Large';

  @override
  String get webview_text_xlarge => 'Very large';

  @override
  String get webview_text_normal_full => 'Normal text';

  @override
  String get webview_text_large_full => 'Large text';

  @override
  String get webview_text_xlarge_full => 'Very large text';

  @override
  String get webview_incognito_on => 'Incognito mode enabled — cookies cleared';

  @override
  String get webview_incognito_off => 'Incognito mode disabled';

  @override
  String get webview_url_copied_clipboard => 'URL copied to the clipboard';

  @override
  String get webview_qr_hint => 'Open the URL in an external QR generator';

  @override
  String get webview_copy_url => 'Copy URL';

  @override
  String get webview_close => 'Close';

  @override
  String get webview_no_hidden_elements => 'No hidden element to restore';

  @override
  String get webview_hidden_elements => 'Hidden elements';

  @override
  String get webview_restore_all => 'Restore all';

  @override
  String get webview_restore => 'Restore';

  @override
  String get webview_element_selected => 'Element selected';

  @override
  String get webview_what_to_do => 'What do you want to do?';

  @override
  String webview_hide(Object selector) {
    return 'Hide $selector';
  }

  @override
  String webview_block_domain(Object domain) {
    return 'Block $domain';
  }

  @override
  String webview_mpv_open_failed(Object error) {
    return 'Could not open in MPV: $error';
  }

  @override
  String get webview_address_or_search => 'Address or search';

  @override
  String get webview_clear => 'Clear';

  @override
  String get webview_open => 'Open';

  @override
  String get webview_no_results_found => 'No results found';

  @override
  String get webview_find_in_page => 'Find in page';

  @override
  String get webview_word_or_phrase => 'Word or phrase';

  @override
  String get webview_previous => 'Previous';

  @override
  String get webview_next => 'Next';

  @override
  String get webview_page_source => 'Page source code';

  @override
  String get webview_no_source => 'No source code available.';

  @override
  String get webview_source_read_failed => 'Could not read the source code';

  @override
  String get webview_url_copied => 'URL copied';

  @override
  String get webview_tap_to_block => 'Tap an element to block it';

  @override
  String get webview_cookies_cleared => 'Cookies cleared';

  @override
  String get webview_site_info => 'Site information';

  @override
  String get webview_page_actions => 'Page actions';

  @override
  String get webview_controls => 'Controls';

  @override
  String get webview_copy_link => 'Copy link';

  @override
  String get webview_share => 'Share';

  @override
  String get webview_view_source => 'View the source code';

  @override
  String get webview_clear_cookies => 'Clear cookies';

  @override
  String get webview_translate_page => 'Translate the page';

  @override
  String get webview_download => 'Download';

  @override
  String get webview_create_qr => 'Create a QR code';

  @override
  String get webview_change_orientation => 'Change the orientation';

  @override
  String get webview_fullscreen => 'Fullscreen';

  @override
  String get webview_minimize_window => 'Minimize the window';

  @override
  String get webview_close_webview => 'Close the WebView';

  @override
  String get webview_adblock => 'Ad blocker';

  @override
  String webview_blocked_count(Object count) {
    return '$count blocked';
  }

  @override
  String get webview_disabled => 'Disabled';

  @override
  String get webview_enabled => 'Enabled';

  @override
  String get webview_night_mode => 'Night mode';

  @override
  String get webview_desktop_version => 'Desktop version';

  @override
  String get webview_incognito => 'Private browsing';

  @override
  String get webview_tap_to_change => 'Tap to change';

  @override
  String get webview_select_element => 'Select an element';

  @override
  String get webview_tap_page_element => 'Tap an element on the page';

  @override
  String get webview_reset_rules => 'Reset the rules';

  @override
  String webview_blocked_elements_count(Object count) {
    return '$count blocked element(s)';
  }

  @override
  String get webview_refresh => 'Refresh';

  @override
  String get webview_protection_active => 'Protection on';

  @override
  String get webview_protection_off => 'Protection off';

  @override
  String get webview_pause_site => 'Pause\nthis site';

  @override
  String get webview_pause_30min => 'Pause\n30 min';

  @override
  String get webview_pick_element_short => 'Sel.\nelem.';

  @override
  String webview_restore_short(Object detail) {
    return 'Restore\n$detail';
  }

  @override
  String get webview_elem_short => 'elem.';

  @override
  String get webview_reset_short => 'Reset\nto zero';

  @override
  String get webview_blocked_requests => 'Requests\nblocked';

  @override
  String get webview_hidden_elements_short => 'Hidden\nelements';

  @override
  String get webview_active_rules => 'Active\nrules';

  @override
  String get webview_adblock_settings => 'AdBlock – Settings';

  @override
  String get webview_enable_adblock => 'Enable AdBlock';

  @override
  String get webview_adblock_desc =>
      'Blocks ad domains and injects a CSS/DOM filter';

  @override
  String get webview_statistics => 'Statistics';

  @override
  String get webview_tools => 'Tools';

  @override
  String get webview_select_elements => 'Select elements';

  @override
  String get webview_floating_toolbar => 'Floating toolbar · touch picker';

  @override
  String get webview_reset_rules_desc =>
      'Resets the counter to 0 and clears custom rules';

  @override
  String webview_manually_blocked(Object count) {
    return 'Manually blocked elements ($count)';
  }

  @override
  String webview_more_elements(Object count) {
    return '+$count elements…';
  }

  @override
  String get webview_play_in_watchtower => 'Play in Watchtower';

  @override
  String get webview_back => 'Back';

  @override
  String get webview_qr_code => 'QR code';
}
