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
}
