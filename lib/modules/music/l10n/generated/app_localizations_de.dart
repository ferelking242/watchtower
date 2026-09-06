// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get guest => 'Gast';

  @override
  String get browse => 'Durchsuchen';

  @override
  String get search => 'Suchen';

  @override
  String get library => 'Bibliothek';

  @override
  String get lyrics => 'Songtexte';

  @override
  String get settings => 'Einstellungen';

  @override
  String get genre_categories_filter => 'Filtere Kategorien oder Genres...';

  @override
  String get genre => 'Genre';

  @override
  String get personalized => 'Personalisiert';

  @override
  String get featured => 'Empfohlen';

  @override
  String get new_releases => 'Neue Veröffentlichungen';

  @override
  String get songs => 'Songs';

  @override
  String playing_track(Object track) {
    return 'Wiedergabe: $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'Dadurch wird die aktuelle Warteschlange gelöscht. $track_length Titel werden entfernt.\nMöchten Sie fortfahren?';
  }

  @override
  String get load_more => 'Mehr laden';

  @override
  String get playlists => 'Playlists';

  @override
  String get artists => 'Künstler';

  @override
  String get albums => 'Alben';

  @override
  String get tracks => 'Titel';

  @override
  String get downloads => 'Downloads';

  @override
  String get filter_playlists => 'Filtere deine Playlists...';

  @override
  String get liked_tracks => 'Gefällt mir-Titel';

  @override
  String get liked_tracks_description => 'Alle deine geliketen Titel';

  @override
  String get playlist => 'Playlist';

  @override
  String get create_a_playlist => 'Erstelle eine Playlist';

  @override
  String get update_playlist => 'Wiedergabeliste aktualisieren';

  @override
  String get create => 'Erstellen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get update => 'Aktualisieren';

  @override
  String get playlist_name => 'Playlist-Name';

  @override
  String get name_of_playlist => 'Name der Playlist';

  @override
  String get description => 'Beschreibung';

  @override
  String get public => 'Öffentlich';

  @override
  String get collaborative => 'Kollaborativ';

  @override
  String get search_local_tracks => 'Lokale Titel durchsuchen...';

  @override
  String get play => 'Wiedergabe';

  @override
  String get delete => 'Löschen';

  @override
  String get none => 'Keine';

  @override
  String get sort_a_z => 'Sortieren nach A-Z';

  @override
  String get sort_z_a => 'Sortieren nach Z-A';

  @override
  String get sort_artist => 'Sortieren nach Künstler';

  @override
  String get sort_album => 'Sortieren nach Album';

  @override
  String get sort_duration => 'Nach Dauer sortieren';

  @override
  String get sort_tracks => 'Titel sortieren';

  @override
  String currently_downloading(Object tracks_length) {
    return 'Derzeitige Downloads ($tracks_length)';
  }

  @override
  String get cancel_all => 'Alle abbrechen';

  @override
  String get refresh => 'Refresh';

  @override
  String get filter_artist => 'Künstler filtern...';

  @override
  String followers(Object followers) {
    return '$followers Follower';
  }

  @override
  String get add_artist_to_blacklist =>
      'Künstler zur Schwarzen Liste hinzufügen';

  @override
  String get top_tracks => 'Top-Titel';

  @override
  String get fans_also_like => 'Fans mögen auch';

  @override
  String get loading => 'Laden...';

  @override
  String get artist => 'Künstler';

  @override
  String get blacklisted => 'Auf der Schwarzen Liste';

  @override
  String get following => 'Folgen';

  @override
  String get follow => 'Folgen';

  @override
  String get artist_url_copied => 'Künstler-URL in Zwischenablage kopiert';

  @override
  String added_to_queue(Object tracks) {
    return '$tracks Titel zur Warteschlange hinzugefügt';
  }

  @override
  String get filter_albums => 'Alben filtern...';

  @override
  String get synced => 'Synchronisiert';

  @override
  String get plain => 'Einfach';

  @override
  String get shuffle => 'Zufällige Wiedergabe';

  @override
  String get search_tracks => 'Titel durchsuchen...';

  @override
  String get released => 'Veröffentlicht';

  @override
  String error(Object error) {
    return 'Fehler $error';
  }

  @override
  String get title => 'Titel';

  @override
  String get time => 'Dauer';

  @override
  String get more_actions => 'Weitere Aktionen';

  @override
  String download_count(Object count) {
    return 'Download ($count)';
  }

  @override
  String add_count_to_playlist(Object count) {
    return 'Zu Playlist hinzufügen ($count)';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'Zur Warteschlange hinzufügen ($count)';
  }

  @override
  String play_count_next(Object count) {
    return 'Als nächstes abspielen ($count)';
  }

  @override
  String get album => 'Album';

  @override
  String copied_to_clipboard(Object data) {
    return '$data in Zwischenablage kopiert';
  }

  @override
  String add_to_following_playlists(Object track) {
    return '$track zu folgenden Playlists hinzufügen';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String added_track_to_queue(Object track) {
    return '$track zur Warteschlange hinzugefügt';
  }

  @override
  String get add_to_queue => 'Zur Warteschlange hinzufügen';

  @override
  String track_will_play_next(Object track) {
    return '$track wird als nächstes abgespielt';
  }

  @override
  String get play_next => 'Als nächstes abspielen';

  @override
  String removed_track_from_queue(Object track) {
    return '$track aus der Warteschlange entfernt';
  }

  @override
  String get remove_from_queue => 'Aus der Warteschlange entfernen';

  @override
  String get remove_from_favorites => 'Aus Favoriten entfernen';

  @override
  String get save_as_favorite => 'Als Favorit speichern';

  @override
  String get add_to_playlist => 'Zur Playlist hinzufügen';

  @override
  String get remove_from_playlist => 'Aus der Playlist entfernen';

  @override
  String get add_to_blacklist => 'Zur Schwarzen Liste hinzufügen';

  @override
  String get remove_from_blacklist => 'Aus der Schwarzen Liste entfernen';

  @override
  String get share => 'Teilen';

  @override
  String get mini_player => 'Mini-Player';

  @override
  String get slide_to_seek => 'Zum Vor- oder Zurückspulen ziehen';

  @override
  String get shuffle_playlist => 'Playlist mischen';

  @override
  String get unshuffle_playlist => 'Playlist nicht mehr mischen';

  @override
  String get previous_track => 'Vorheriger Track';

  @override
  String get next_track => 'Nächster Track';

  @override
  String get pause_playback => 'Wiedergabe pausieren';

  @override
  String get resume_playback => 'Wiedergabe fortsetzen';

  @override
  String get loop_track => 'Track wiederholen';

  @override
  String get no_loop => 'Kein Loop';

  @override
  String get repeat_playlist => 'Playlist wiederholen';

  @override
  String get queue => 'Warteschlange';

  @override
  String get alternative_track_sources => 'Alternative Track-Quellen';

  @override
  String get download_track => 'Track herunterladen';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks Tracks in der Warteschlange';
  }

  @override
  String get clear_all => 'Alle löschen';

  @override
  String get show_hide_ui_on_hover => 'UI beim Überfahren anzeigen/ausblenden';

  @override
  String get always_on_top => 'Immer im Vordergrund';

  @override
  String get exit_mini_player => 'Mini-Player verlassen';

  @override
  String get download_location => 'Download-Speicherort';

  @override
  String get local_library => 'Lokale Bibliothek';

  @override
  String get add_library_location => 'Zur Bibliothek hinzufügen';

  @override
  String get remove_library_location => 'Aus der Bibliothek entfernen';

  @override
  String get account => 'Konto';

  @override
  String get logout => 'Abmelden';

  @override
  String get logout_of_this_account => 'Von diesem Konto abmelden';

  @override
  String get language_region => 'Sprache & Region';

  @override
  String get language => 'Sprache';

  @override
  String get system_default => 'Systemstandard';

  @override
  String get market_place_region => 'Marktplatzregion';

  @override
  String get recommendation_country => 'Empfehlungsland';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get layout_mode => 'Layout-Modus';

  @override
  String get override_layout_settings =>
      'Responsiven Layout-Modus-Einstellungen überschreiben';

  @override
  String get adaptive => 'Adaptiv';

  @override
  String get compact => 'Kompakt';

  @override
  String get extended => 'Erweitert';

  @override
  String get theme => 'Design';

  @override
  String get dark => 'Dunkel';

  @override
  String get light => 'Hell';

  @override
  String get system => 'System';

  @override
  String get accent_color => 'Akzentfarbe';

  @override
  String get sync_album_color => 'Albumfarbe synchronisieren';

  @override
  String get sync_album_color_description =>
      'Verwendet die dominante Farbe des Album Covers als Akzentfarbe';

  @override
  String get playback => 'Wiedergabe';

  @override
  String get audio_quality => 'Audioqualität';

  @override
  String get high => 'Hoch';

  @override
  String get low => 'Niedrig';

  @override
  String get pre_download_play => 'Vorab herunterladen und abspielen';

  @override
  String get pre_download_play_description =>
      'Anstatt Audio zu streamen, Bytes herunterladen und abspielen (Empfohlen für Benutzer mit hoher Bandbreite)';

  @override
  String get skip_non_music =>
      'Überspringe Nicht-Musik-Segmente (SponsorBlock)';

  @override
  String get blacklist_description => 'Gesperrte Titel und Künstler';

  @override
  String get wait_for_download_to_finish =>
      'Bitte warten Sie, bis der aktuelle Download abgeschlossen ist';

  @override
  String get desktop => 'Desktop';

  @override
  String get close_behavior => 'Verhalten beim Schließen';

  @override
  String get close => 'Schließen';

  @override
  String get minimize_to_tray => 'In Taskleiste minimieren';

  @override
  String get show_tray_icon => 'Systemsymbol anzeigen';

  @override
  String get about => 'Über';

  @override
  String get u_love_spotube => 'Wir wissen, dass Sie Spotube lieben';

  @override
  String get check_for_updates => 'Nach Updates suchen';

  @override
  String get about_spotube => 'Über Spotube';

  @override
  String get blacklist => 'Gesperrte Titel';

  @override
  String get please_sponsor => 'Bitte unterstützen/Spenden Sie';

  @override
  String get spotube_description =>
      'Spotube, ein leichtgewichtiger, plattformübergreifender und kostenloser Spotify-Client';

  @override
  String get version => 'Version';

  @override
  String get build_number => 'Build-Nummer';

  @override
  String get founder => 'Gründer';

  @override
  String get repository => 'Repository';

  @override
  String get bug_issues => 'Fehler und Probleme';

  @override
  String get made_with => 'Entwickelt mit ❤️ in Bangladesch 🇧🇩';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return '© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'Lizenz';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'Keine Sorge, Ihre Anmeldeinformationen werden nicht erfasst oder mit anderen geteilt';

  @override
  String get know_how_to_login => 'Wissen Sie nicht, wie es geht?';

  @override
  String get follow_step_by_step_guide =>
      'Befolgen Sie die schrittweise Anleitung';

  @override
  String cookie_name_cookie(Object name) {
    return '$name Cookie';
  }

  @override
  String get fill_in_all_fields => 'Bitte füllen Sie alle Felder aus';

  @override
  String get submit => 'Senden';

  @override
  String get exit => 'Beenden';

  @override
  String get previous => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get done => 'Fertig';

  @override
  String get step_1 => 'Schritt 1';

  @override
  String get first_go_to => 'Gehe zuerst zu';

  @override
  String get something_went_wrong => 'Etwas ist schiefgelaufen';

  @override
  String get piped_instance => 'Piped-Serverinstanz';

  @override
  String get piped_description =>
      'Die Piped-Serverinstanz, die zur Titelzuordnung verwendet werden soll';

  @override
  String get piped_warning =>
      'Einige von ihnen funktionieren möglicherweise nicht gut. Verwende sie also auf eigenes Risiko';

  @override
  String get invidious_instance => 'Invidious-Serverinstanz';

  @override
  String get invidious_description =>
      'Die Invidious-Serverinstanz zur Titelerkennung';

  @override
  String get invidious_warning =>
      'Einige Instanzen funktionieren möglicherweise nicht gut. Benutzung auf eigene Gefahr';

  @override
  String get generate => 'Generieren';

  @override
  String track_exists(Object track) {
    return 'Track $track existiert bereits';
  }

  @override
  String get replace_downloaded_tracks =>
      'Alle heruntergeladenen Titel ersetzen';

  @override
  String get skip_download_tracks =>
      'Das Herunterladen aller heruntergeladenen Titel überspringen';

  @override
  String get do_you_want_to_replace =>
      'Möchtest du den vorhandenen Track ersetzen?';

  @override
  String get replace => 'Ersetzen';

  @override
  String get skip => 'Überspringen';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'Wähle bis zu $count $type aus';
  }

  @override
  String get select_genres => 'Genres auswählen';

  @override
  String get add_genres => 'Genres hinzufügen';

  @override
  String get country => 'Land';

  @override
  String get number_of_tracks_generate => 'Anzahl der zu generierenden Titel';

  @override
  String get acousticness => 'Akustik';

  @override
  String get danceability => 'Tanzbarkeit';

  @override
  String get energy => 'Energie';

  @override
  String get instrumentalness => 'Instrumentalität';

  @override
  String get liveness => 'Lebendigkeit';

  @override
  String get loudness => 'Lautstärke';

  @override
  String get speechiness => 'Sprechanteil';

  @override
  String get valence => 'Stimmung';

  @override
  String get popularity => 'Beliebtheit';

  @override
  String get key => 'Tonart';

  @override
  String get duration => 'Dauer (s)';

  @override
  String get tempo => 'Tempo (BPM)';

  @override
  String get mode => 'Modus';

  @override
  String get time_signature => 'Taktart';

  @override
  String get short => 'Kurz';

  @override
  String get medium => 'Mittel';

  @override
  String get long => 'Lang';

  @override
  String get min => 'Min';

  @override
  String get max => 'Max';

  @override
  String get target => 'Ziel';

  @override
  String get moderate => 'Mäßig';

  @override
  String get deselect_all => 'Alle abwählen';

  @override
  String get select_all => 'Alle auswählen';

  @override
  String get are_you_sure => 'Bist du sicher?';

  @override
  String get generating_playlist =>
      'Erstelle deine individuelle Wiedergabeliste...';

  @override
  String selected_count_tracks(Object count) {
    return '$count Titel ausgewählt';
  }

  @override
  String get download_warning =>
      'Wenn du alle Titel in großen Mengen herunterlädst, betreibst du eindeutig Raubkopien von Musik und schadest der kreativen Gesellschaft der Musik. Ich hoffe, dir ist dies bewusst. Versuche immer, die harte Arbeit der Künstler zu respektieren und zu unterstützen.';

  @override
  String get download_ip_ban_warning =>
      'Übrigens, deine IP-Adresse kann aufgrund übermäßiger Downloadanfragen von YouTube gesperrt werden. Eine IP-Sperre bedeutet, dass du YouTube (auch wenn du angemeldet bist) für mindestens 2-3 Monate von diesem IP-Gerät aus nicht nutzen kannst. Spotube übernimmt keine Verantwortung, falls dies jemals geschieht.';

  @override
  String get by_clicking_accept_terms =>
      'Durch Klicken auf \'Akzeptieren\' stimmst du den folgenden Bedingungen zu:';

  @override
  String get download_agreement_1 =>
      'Ich weiß, dass ich Raubkopien von Musik betreibe. Ich bin böse.';

  @override
  String get download_agreement_2 =>
      'Ich werde die Künstler, wo immer ich kann, unterstützen, und ich tue dies nur, weil ich kein Geld habe, um ihre Kunst zu kaufen.';

  @override
  String get download_agreement_3 =>
      'Mir ist vollkommen bewusst, dass meine IP-Adresse auf YouTube gesperrt werden kann, und ich halte Spotube oder seine Eigentümer/Mitarbeiter nicht für etwaige Unfälle verantwortlich, die durch meine derzeitige Handlung verursacht werden.';

  @override
  String get decline => 'Ablehnen';

  @override
  String get accept => 'Akzeptieren';

  @override
  String get details => 'Details';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'Kanal';

  @override
  String get likes => 'Likes';

  @override
  String get dislikes => 'Dislikes';

  @override
  String get views => 'Aufrufe';

  @override
  String get streamUrl => 'Stream-URL';

  @override
  String get stop => 'Stopp';

  @override
  String get sort_newest => 'Nach neuesten Hinzufügungen sortieren';

  @override
  String get sort_oldest => 'Nach ältesten Hinzufügungen sortieren';

  @override
  String get sleep_timer => 'Schlaftimer';

  @override
  String mins(Object minutes) {
    return '$minutes Minuten';
  }

  @override
  String hours(Object hours) {
    return '$hours Stunden';
  }

  @override
  String hour(Object hours) {
    return '$hours Stunde';
  }

  @override
  String get custom_hours => 'Benutzerdefinierte Stunden';

  @override
  String get logs => 'Protokolle';

  @override
  String get developers => 'Entwickler';

  @override
  String get not_logged_in => 'Sie sind nicht angemeldet';

  @override
  String get search_mode => 'Suchmodus';

  @override
  String get audio_source => 'Audioquelle';

  @override
  String get ok => 'OK';

  @override
  String get failed_to_encrypt => 'Verschlüsselung fehlgeschlagen';

  @override
  String get encryption_failed_warning =>
      'Spotube verwendet Verschlüsselung, um Ihre Daten sicher zu speichern. Dies ist jedoch fehlgeschlagen. Daher wird es auf unsichere Speicherung zurückgreifen\nWenn Sie Linux verwenden, stellen Sie bitte sicher, dass Sie Secret-Services wie gnome-keyring, kde-wallet und keepassxc installiert haben';

  @override
  String get querying_info => 'Abfrageinformationen...';

  @override
  String get piped_api_down => 'Die Piped API ist ausgefallen';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'Die Piped-Instanz $pipedInstance ist derzeit nicht verfügbar\n\nEntweder ändern Sie die Instanz oder wechseln Sie den \'API-Typ\' zur offiziellen YouTube API\n\nStellen Sie sicher, dass Sie die App nach der Änderung neu starten';
  }

  @override
  String get you_are_offline => 'Sie sind derzeit offline';

  @override
  String get connection_restored =>
      'Ihre Internetverbindung wurde wiederhergestellt';

  @override
  String get use_system_title_bar => 'System-Titelleiste verwenden';

  @override
  String get crunching_results => 'Ergebnisse werden verarbeitet...';

  @override
  String get search_to_get_results => 'Suche, um Ergebnisse zu erhalten';

  @override
  String get use_amoled_mode => 'AMOLED-Modus verwenden';

  @override
  String get pitch_dark_theme => 'Pitch Black Dart Theme';

  @override
  String get normalize_audio => 'Audio normalisieren';

  @override
  String get change_cover => 'Cover ändern';

  @override
  String get add_cover => 'Cover hinzufügen';

  @override
  String get restore_defaults => 'Standardeinstellungen wiederherstellen';

  @override
  String get download_music_format => 'Musik-Downloadformat';

  @override
  String get streaming_music_format => 'Musik-Streamingformat';

  @override
  String get download_music_quality => 'Musik-Downloadqualität';

  @override
  String get streaming_music_quality => 'Musik-Streamingqualität';

  @override
  String get login_with_lastfm => 'Mit Last.fm anmelden';

  @override
  String get connect => 'Verbinden';

  @override
  String get disconnect_lastfm => 'Last.fm trennen';

  @override
  String get disconnect => 'Trennen';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get login => 'Anmelden';

  @override
  String get login_with_your_lastfm => 'Mit Ihrem Last.fm-Konto anmelden';

  @override
  String get scrobble_to_lastfm => 'Auf Last.fm scrobbeln';

  @override
  String get go_to_album => 'Zum Album gehen';

  @override
  String get discord_rich_presence => 'Discord Rich Presence';

  @override
  String get browse_all => 'Alles durchsuchen';

  @override
  String get genres => 'Genres';

  @override
  String get explore_genres => 'Genres erkunden';

  @override
  String get friends => 'Freunde';

  @override
  String get no_lyrics_available =>
      'Entschuldigung, Texte für diesen Track konnten nicht gefunden werden';

  @override
  String get start_a_radio => 'Radio starten';

  @override
  String get how_to_start_radio => 'Wie möchten Sie das Radio starten?';

  @override
  String get replace_queue_question =>
      'Möchten Sie die aktuelle Wiedergabeliste ersetzen oder hinzufügen?';

  @override
  String get endless_playback => 'Endlose Wiedergabe';

  @override
  String get delete_playlist => 'Wiedergabeliste löschen';

  @override
  String get delete_playlist_confirmation =>
      'Sind Sie sicher, dass Sie diese Wiedergabeliste löschen möchten?';

  @override
  String get local_tracks => 'Lokale Titel';

  @override
  String get local_tab => 'Lokal';

  @override
  String get song_link => 'Lied-Link';

  @override
  String get skip_this_nonsense => 'Diesen Unsinn überspringen';

  @override
  String get freedom_of_music => '“Freiheit der Musik”';

  @override
  String get freedom_of_music_palm =>
      '“Freiheit der Musik in Ihrer Handfläche”';

  @override
  String get get_started => 'Lass uns anfangen';

  @override
  String get youtube_source_description =>
      'Empfohlen und funktioniert am besten.';

  @override
  String get piped_source_description =>
      'Fühlen Sie sich frei? Wie YouTube, aber viel freier.';

  @override
  String get jiosaavn_source_description =>
      'Am besten für die südasiatische Region.';

  @override
  String get invidious_source_description =>
      'Ähnlich wie Piped, aber mit höherer Verfügbarkeit';

  @override
  String highest_quality(Object quality) {
    return 'Höchste Qualität: $quality';
  }

  @override
  String get select_audio_source => 'Audioquelle auswählen';

  @override
  String get endless_playback_description =>
      'Neue Lieder automatisch\nam Ende der Wiedergabeliste hinzufügen';

  @override
  String get choose_your_region => 'Wählen Sie Ihre Region';

  @override
  String get choose_your_region_description =>
      'Dies wird Spotube helfen, Ihnen den richtigen Inhalt\nfür Ihren Standort anzuzeigen.';

  @override
  String get choose_your_language => 'Wählen Sie Ihre Sprache';

  @override
  String get help_project_grow => 'Helfen Sie diesem Projekt zu wachsen';

  @override
  String get help_project_grow_description =>
      'Spotube ist ein Open-Source-Projekt. Sie können diesem Projekt helfen, indem Sie zum Projekt beitragen, Fehler melden oder neue Funktionen vorschlagen.';

  @override
  String get contribute_on_github => 'Auf GitHub beitragen';

  @override
  String get donate_on_open_collective => 'Auf Open Collective spenden';

  @override
  String get browse_anonymously => 'Anonym durchsuchen';

  @override
  String get enable_connect => 'Verbindung aktivieren';

  @override
  String get enable_connect_description =>
      'Spotube von anderen Geräten steuern';

  @override
  String get devices => 'Geräte';

  @override
  String get select => 'Auswählen';

  @override
  String connect_client_alert(Object client) {
    return 'Du wirst von $client gesteuert';
  }

  @override
  String get this_device => 'Dieses Gerät';

  @override
  String get remote => 'Fernbedienung';

  @override
  String get stats => 'Statistiken';

  @override
  String and_n_more(Object count) {
    return 'und $count mehr';
  }

  @override
  String get recently_played => 'Zuletzt gespielt';

  @override
  String get browse_more => 'Mehr durchsuchen';

  @override
  String get no_title => 'Kein Titel';

  @override
  String get not_playing => 'Wird nicht abgespielt';

  @override
  String get epic_failure => 'Episches Versagen!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return '$tracks_length Titel zur Warteschlange hinzugefügt';
  }

  @override
  String get spotube_has_an_update => 'Spotube hat ein Update';

  @override
  String get download_now => 'Jetzt herunterladen';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Spotube Nightly $nightlyBuildNum wurde veröffentlicht';
  }

  @override
  String release_version(Object version) {
    return 'Spotube v$version wurde veröffentlicht';
  }

  @override
  String get read_the_latest => 'Lese die neuesten ';

  @override
  String get release_notes => 'Versionshinweise';

  @override
  String get pick_color_scheme => 'Farbschema wählen';

  @override
  String get save => 'Speichern';

  @override
  String get choose_the_device => 'Wähle das Gerät:';

  @override
  String get multiple_device_connected =>
      'Es sind mehrere Geräte verbunden.\nWähle das Gerät, auf dem diese Aktion ausgeführt werden soll';

  @override
  String get nothing_found => 'Nichts gefunden';

  @override
  String get the_box_is_empty => 'Die Box ist leer';

  @override
  String get top_artists => 'Top-Künstler';

  @override
  String get top_albums => 'Top-Alben';

  @override
  String get this_week => 'Diese Woche';

  @override
  String get this_month => 'Diesen Monat';

  @override
  String get last_6_months => 'Letzte 6 Monate';

  @override
  String get this_year => 'Dieses Jahr';

  @override
  String get last_2_years => 'Letzte 2 Jahre';

  @override
  String get all_time => 'Alle Zeiten';

  @override
  String powered_by_provider(Object providerName) {
    return 'Bereitgestellt von $providerName';
  }

  @override
  String get email => 'Email';

  @override
  String get profile_followers => 'Follower';

  @override
  String get birthday => 'Geburtstag';

  @override
  String get subscription => 'Abonnement';

  @override
  String get not_born => 'Nicht geboren';

  @override
  String get hacker => 'Hacker';

  @override
  String get profile => 'Profil';

  @override
  String get no_name => 'Kein Name';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get user_profile => 'Benutzerprofil';

  @override
  String count_plays(Object count) {
    return '$count Wiedergaben';
  }

  @override
  String get streaming_fees_hypothetical => 'Streaming-Gebühren (hypothetisch)';

  @override
  String get minutes_listened => 'Gehörte Minuten';

  @override
  String get streamed_songs => 'Gestreamte Lieder';

  @override
  String count_streams(Object count) {
    return '$count Streams';
  }

  @override
  String get owned_by_you => 'In Ihrem Besitz';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl in die Zwischenablage kopiert';
  }

  @override
  String get hipotetical_calculation =>
      '*Diese Berechnung basiert auf der durchschnittlichen Auszahlung pro Stream (0,003 USD bis 0,005 USD) auf Online-Musik-Streaming-Plattformen. Sie ist hypothetisch und soll dem Nutzer veranschaulichen, wie viel er den Künstlern bezahlt hätte, wenn er ihren Song auf verschiedenen Streaming-Plattformen gehört hätte.';

  @override
  String count_mins(Object minutes) {
    return '$minutes Minuten';
  }

  @override
  String get summary_minutes => 'Minuten';

  @override
  String get summary_listened_to_music => 'Hat Musik gehört';

  @override
  String get summary_songs => 'Lieder';

  @override
  String get summary_streamed_overall => 'Insgesamt gestreamt';

  @override
  String get summary_owed_to_artists =>
      'Den Künstlern geschuldet\nDiesen Monat';

  @override
  String get summary_artists => 'Künstler';

  @override
  String get summary_music_reached_you => 'Musik hat Sie erreicht';

  @override
  String get summary_full_albums => 'volle Alben';

  @override
  String get summary_got_your_love => 'Hat Ihre Liebe gewonnen';

  @override
  String get summary_playlists => 'Wiedergabelisten';

  @override
  String get summary_were_on_repeat => 'Wurden wiederholt';

  @override
  String total_money(Object money) {
    return 'Gesamt $money';
  }

  @override
  String get webview_not_found => 'Webview nicht gefunden';

  @override
  String get webview_not_found_description =>
      'Es ist keine Webview-Laufzeitumgebung auf Ihrem Gerät installiert.\nFalls installiert, stellen Sie sicher, dass es im environment PATH ist\n\nNach der Installation starten Sie die App neu';

  @override
  String get unsupported_platform => 'Nicht unterstützte Plattform';

  @override
  String get cache_music => 'Musik zwischenspeichern';

  @override
  String get open => 'Öffnen';

  @override
  String get cache_folder => 'Cache-Ordner';

  @override
  String get export => 'Exportieren';

  @override
  String get clear_cache => 'Cache leeren';

  @override
  String get clear_cache_confirmation => 'Möchten Sie den Cache leeren?';

  @override
  String get export_cache_files => 'Cachedateien exportieren';

  @override
  String found_n_files(Object count) {
    return '$count Dateien gefunden';
  }

  @override
  String get export_cache_confirmation =>
      'Möchten Sie diese Dateien exportieren nach';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return '$filesExported von $files Dateien exportiert';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String get download_all => 'Alle herunterladen';

  @override
  String get add_all_to_playlist => 'Alle zur Playlist hinzufügen';

  @override
  String get add_all_to_queue => 'Alle zur Warteschlange hinzufügen';

  @override
  String get play_all_next => 'Alle als Nächstes abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get view_all => 'Alle ansehen';

  @override
  String get no_tracks_added_yet => 'Sie haben noch keine Titel hinzugefügt.';

  @override
  String get no_tracks => 'Es sieht so aus, als ob hier keine Titel sind.';

  @override
  String get no_tracks_listened_yet =>
      'Es scheint, dass Sie noch nichts gehört haben.';

  @override
  String get not_following_artists => 'Sie folgen noch keinem Künstler.';

  @override
  String get no_favorite_albums_yet =>
      'Es sieht so aus, als ob Sie noch keine Alben zu Ihren Favoriten hinzugefügt haben.';

  @override
  String get no_logs_found => 'Keine Protokolle gefunden';

  @override
  String get youtube_engine => 'YouTube-Engine';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine ist nicht installiert';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine ist nicht auf Ihrem System installiert.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'Stellen Sie sicher, dass es im PATH verfügbar ist oder\nsetzen Sie den absoluten Pfad zur $engine ausführbaren Datei unten.';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'In macOS/Linux/unixähnlichen Betriebssystemen funktioniert das Setzen des Pfads in .zshrc/.bashrc/.bash_profile usw. nicht.\nSie müssen den Pfad in der Shell-Konfigurationsdatei festlegen.';

  @override
  String get download => 'Herunterladen';

  @override
  String get file_not_found => 'Datei nicht gefunden';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get add_custom_url => 'Benutzerdefinierte URL hinzufügen';

  @override
  String get edit_port => 'Port bearbeiten';

  @override
  String get port_helper_msg =>
      'Der Standardwert ist -1, was eine zufällige Zahl bedeutet. Wenn Sie eine Firewall konfiguriert haben, wird empfohlen, dies einzustellen.';

  @override
  String connect_request(Object client) {
    return '$client die Verbindung erlauben?';
  }

  @override
  String get connection_request_denied =>
      'Verbindung abgelehnt. Benutzer hat den Zugriff verweigert.';

  @override
  String get an_error_occurred => 'Ein Fehler ist aufgetreten';

  @override
  String get copy_to_clipboard => 'In die Zwischenablage kopieren';

  @override
  String get view_logs => 'Protokolle anzeigen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get no_default_metadata_provider_selected =>
      'Sie haben keinen Standard-Metadatenanbieter festgelegt';

  @override
  String get manage_metadata_providers => 'Metadatenanbieter verwalten';

  @override
  String get open_link_in_browser => 'Link im Browser öffnen?';

  @override
  String get do_you_want_to_open_the_following_link =>
      'Möchten Sie folgenden Link öffnen?';

  @override
  String get unsafe_url_warning =>
      'Das Öffnen von Links aus nicht vertrauenswürdigen Quellen kann unsicher sein. Seien Sie vorsichtig!\nSie können den Link auch in Ihre Zwischenablage kopieren.';

  @override
  String get copy_link => 'Link kopieren';

  @override
  String get building_your_timeline =>
      'Ihr Zeitverlauf wird basierend auf Ihren Hördaten erstellt…';

  @override
  String get official => 'Offiziell';

  @override
  String author_name(Object author) {
    return 'Autor: $author';
  }

  @override
  String get third_party => 'Drittanbieter';

  @override
  String get plugin_requires_authentication =>
      'Plugin erfordert Authentifizierung';

  @override
  String get update_available => 'Update verfügbar';

  @override
  String get supports_scrobbling => 'Unterstützt Scrobbling';

  @override
  String get plugin_scrobbling_info =>
      'Dieses Plugin scrobbelt Ihre Musik, um Ihre Hörhistorie zu erstellen.';

  @override
  String get default_metadata_source => 'Standard-Metadatenquelle';

  @override
  String get set_default_metadata_source =>
      'Standard-Metadatenquelle festlegen';

  @override
  String get default_audio_source => 'Standard-Audioquelle';

  @override
  String get set_default_audio_source => 'Standard-Audioquelle festlegen';

  @override
  String get set_default => 'Als Standard festlegen';

  @override
  String get support => 'Unterstützung';

  @override
  String get support_plugin_development => 'Plugin-Entwicklung unterstützen';

  @override
  String can_access_name_api(Object name) {
    return '- Kann auf **$name**-API zugreifen';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'Möchten Sie dieses Plugin installieren?';

  @override
  String get third_party_plugin_warning =>
      'Dieses Plugin stammt aus einem Drittanbieter-Repository. Bitte stellen Sie sicher, dass Sie der Quelle vertrauen, bevor Sie es installieren.';

  @override
  String get author => 'Autor';

  @override
  String get this_plugin_can_do_following => 'Dieses Plugin kann Folgendes:';

  @override
  String get install => 'Installieren';

  @override
  String get install_a_metadata_provider =>
      'Einen Metadatenanbieter installieren';

  @override
  String get no_tracks_playing => 'Derzeit wird kein Titel abgespielt';

  @override
  String get synced_lyrics_not_available =>
      'Synchronisierte Liedtexte sind für dieses Lied nicht verfügbar. Bitte verwenden Sie stattdessen';

  @override
  String get plain_lyrics => 'Einfache Liedtexte';

  @override
  String get tab_instead => 'stattdessen die Tab-Taste verwenden.';

  @override
  String get disclaimer => 'Haftungsausschluss';

  @override
  String get third_party_plugin_dmca_notice =>
      'Das Spotube-Team übernimmt keine Verantwortung (auch nicht rechtlicher Art) für Plugins \"Drittanbieter\". Nutzen Sie diese auf eigenes Risiko. Für Fehler/Probleme melden Sie sich bitte beim Plugin-Repository.\n\nWenn ein Plugin \"Drittanbieter\" gegen die ToS/DMCA eines Dienstes bzw. gesetzlicher Vorschriften verstößt, wenden Sie sich bitte an den Plugin-Autor oder die Hosting-Plattform (z. B. GitHub/Codeberg), um Maßnahmen zu ergreifen. Die genannten Plugins (mit \"Drittanbieter\"-Kennzeichnung) werden öffentlich und gemeinschaftlich gepflegt. Wir kuratieren sie nicht und können keine Maßnahmen ergreifen.\n\n';

  @override
  String get input_does_not_match_format =>
      'Eingabe entspricht nicht dem geforderten Format';

  @override
  String get plugins => 'Plugins';

  @override
  String get paste_plugin_download_url =>
      'Download-URL, GitHub/Codeberg-Repo-URL oder direkten Link zur .smplug-Datei einfügen';

  @override
  String get download_and_install_plugin_from_url =>
      'Plugin per URL herunterladen und installieren';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'Plugin konnte nicht hinzugefügt werden: $error';
  }

  @override
  String get upload_plugin_from_file => 'Plugin per Datei hochladen';

  @override
  String get installed => 'Installiert';

  @override
  String get available_plugins => 'Verfügbare Plugins';

  @override
  String get configure_plugins =>
      'Richte deine eigenen Metadatenanbieter- und Audioquellen-Plugins ein';

  @override
  String get audio_scrobblers => 'Audio-Scrobbler';

  @override
  String get scrobbling => 'Scrobbling';

  @override
  String get source => 'Quelle: ';

  @override
  String get uncompressed => 'Unkomprimiert';

  @override
  String get dab_music_source_description =>
      'Für Audiophile. Bietet hochwertige/verlustfreie Audiostreams. Präzises ISRC-basiertes Track-Matching.';
}
