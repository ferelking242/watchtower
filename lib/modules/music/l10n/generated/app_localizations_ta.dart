// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get guest => 'விருந்தினர்';

  @override
  String get browse => 'உலாவு';

  @override
  String get search => 'தேடுக';

  @override
  String get library => 'நூலகம்';

  @override
  String get lyrics => 'பாடல் வரிகள்';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get genre_categories_filter => 'வகைகள் அல்லது பாணிகளை வடிகட்டுக...';

  @override
  String get genre => 'பாணி';

  @override
  String get personalized => 'தனிப்பயனாக்கப்பட்ட';

  @override
  String get featured => 'சிறப்பிடம் பெற்ற';

  @override
  String get new_releases => 'புதிய வெளியீடுகள்';

  @override
  String get songs => 'பாடல்கள்';

  @override
  String playing_track(Object track) {
    return '$track இயங்குகிறது';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'இது தற்போதைய வரிசையை அழிக்கும். $track_length பாடல்கள் நீக்கப்படும்\nதொடர விரும்புகிறீர்களா?';
  }

  @override
  String get load_more => 'மேலும் ஏற்றுக';

  @override
  String get playlists => 'பாடல் பட்டியல்கள்';

  @override
  String get artists => 'கலைஞர்கள்';

  @override
  String get albums => 'ஆல்பங்கள்';

  @override
  String get tracks => 'பாடல்கள்';

  @override
  String get downloads => 'பதிவிறக்கங்கள்';

  @override
  String get filter_playlists => 'உங்கள் பாடல் பட்டியல்களை வடிகட்டுக...';

  @override
  String get liked_tracks => 'விரும்பிய பாடல்கள்';

  @override
  String get liked_tracks_description => 'உங்கள் விரும்பிய பாடல்கள் அனைத்தும்';

  @override
  String get playlist => 'பாடல் பட்டியல்';

  @override
  String get create_a_playlist => 'பாடல் பட்டியலை உருவாக்குக';

  @override
  String get update_playlist => 'பாடல் பட்டியலைப் புதுப்பிக்க';

  @override
  String get create => 'உருவாக்கு';

  @override
  String get cancel => 'ரத்து செய்';

  @override
  String get update => 'புதுப்பி';

  @override
  String get playlist_name => 'பாடல் பட்டியல் பெயர்';

  @override
  String get name_of_playlist => 'பாடல் பட்டியலின் பெயர்';

  @override
  String get description => 'விளக்கம்';

  @override
  String get public => 'பொது';

  @override
  String get collaborative => 'கூட்டு';

  @override
  String get search_local_tracks => 'உள்ளூர் பாடல்களைத் தேடுக...';

  @override
  String get play => 'இயக்கு';

  @override
  String get delete => 'அழி';

  @override
  String get none => 'எதுவுமில்லை';

  @override
  String get sort_a_z => 'A-Z வரிசைப்படுத்து';

  @override
  String get sort_z_a => 'Z-A வரிசைப்படுத்து';

  @override
  String get sort_artist => 'கலைஞர் மூலம் வரிசைப்படுத்து';

  @override
  String get sort_album => 'ஆல்பம் மூலம் வரிசைப்படுத்து';

  @override
  String get sort_duration => 'கால அளவு மூலம் வரிசைப்படுத்து';

  @override
  String get sort_tracks => 'பாடல்களை வரிசைப்படுத்து';

  @override
  String currently_downloading(Object tracks_length) {
    return 'தற்போது பதிவிறக்குகிறது ($tracks_length)';
  }

  @override
  String get cancel_all => 'அனைத்தையும் ரத்து செய்';

  @override
  String get refresh => 'Refresh';

  @override
  String get filter_artist => 'கலைஞர்களை வடிகட்டுக...';

  @override
  String followers(Object followers) {
    return '$followers பின்தொடர்பவர்கள்';
  }

  @override
  String get add_artist_to_blacklist => 'கலைஞரை தடைப்பட்டியலில் சேர்க்க';

  @override
  String get top_tracks => 'சிறந்த பாடல்கள்';

  @override
  String get fans_also_like => 'ரசிகர்கள் விரும்புவது';

  @override
  String get loading => 'ஏற்றுகிறது...';

  @override
  String get artist => 'கலைஞர்';

  @override
  String get blacklisted => 'தடைப்பட்டியலில் உள்ளது';

  @override
  String get following => 'பின்தொடர்கிறது';

  @override
  String get follow => 'பின்தொடர்';

  @override
  String get artist_url_copied =>
      'கலைஞர் URL கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது';

  @override
  String added_to_queue(Object tracks) {
    return '$tracks பாடல்கள் வரிசையில் சேர்க்கப்பட்டன';
  }

  @override
  String get filter_albums => 'ஆல்பங்களை வடிகட்டுக...';

  @override
  String get synced => 'ஒத்திசைக்கப்பட்டது';

  @override
  String get plain => 'சாதாரண';

  @override
  String get shuffle => 'கலக்கு';

  @override
  String get search_tracks => 'பாடல்களைத் தேடுக...';

  @override
  String get released => 'வெளியிடப்பட்டது';

  @override
  String error(Object error) {
    return 'பிழை $error';
  }

  @override
  String get title => 'தலைப்பு';

  @override
  String get time => 'நேரம்';

  @override
  String get more_actions => 'மேலும் செயல்கள்';

  @override
  String download_count(Object count) {
    return 'பதிவிறக்கு ($count)';
  }

  @override
  String add_count_to_playlist(Object count) {
    return '($count) பாடல் பட்டியலில் சேர்';
  }

  @override
  String add_count_to_queue(Object count) {
    return '($count) வரிசையில் சேர்';
  }

  @override
  String play_count_next(Object count) {
    return '($count) அடுத்து இயக்கு';
  }

  @override
  String get album => 'ஆல்பம்';

  @override
  String copied_to_clipboard(Object data) {
    return '$data கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது';
  }

  @override
  String add_to_following_playlists(Object track) {
    return '$track பின்வரும் பாடல் பட்டியல்களில் சேர்';
  }

  @override
  String get add => 'சேர்';

  @override
  String added_track_to_queue(Object track) {
    return '$track வரிசையில் சேர்க்கப்பட்டது';
  }

  @override
  String get add_to_queue => 'வரிசையில் சேர்';

  @override
  String track_will_play_next(Object track) {
    return '$track அடுத்து இயக்கப்படும்';
  }

  @override
  String get play_next => 'அடுத்து இயக்கு';

  @override
  String removed_track_from_queue(Object track) {
    return '$track வரிசையிலிருந்து நீக்கப்பட்டது';
  }

  @override
  String get remove_from_queue => 'வரிசையிலிருந்து நீக்கு';

  @override
  String get remove_from_favorites => 'பிடித்தவையிலிருந்து நீக்கு';

  @override
  String get save_as_favorite => 'பிடித்தவையாக சேமி';

  @override
  String get add_to_playlist => 'பாடல் பட்டியலில் சேர்';

  @override
  String get remove_from_playlist => 'பாடல் பட்டியலிலிருந்து நீக்கு';

  @override
  String get add_to_blacklist => 'தடைப்பட்டியலில் சேர்';

  @override
  String get remove_from_blacklist => 'தடைப்பட்டியலிலிருந்து நீக்கு';

  @override
  String get share => 'பகிர்';

  @override
  String get mini_player => 'சிறிய இயக்கி';

  @override
  String get slide_to_seek => 'முன்னோக்கி அல்லது பின்னோக்கி செல்ல சறுக்கவும்';

  @override
  String get shuffle_playlist => 'பாடல் பட்டியலை கலக்கு';

  @override
  String get unshuffle_playlist => 'பாடல் பட்டியலை கலக்காதே';

  @override
  String get previous_track => 'முந்தைய பாடல்';

  @override
  String get next_track => 'அடுத்த பாடல்';

  @override
  String get pause_playback => 'இயக்கத்தை நிறுத்து';

  @override
  String get resume_playback => 'இயக்கத்தை தொடர்';

  @override
  String get loop_track => 'பாடலை சுழற்று';

  @override
  String get no_loop => 'சுழற்சி இல்லை';

  @override
  String get repeat_playlist => 'பாடல் பட்டியலை மீண்டும் இயக்கு';

  @override
  String get queue => 'வரிசை';

  @override
  String get alternative_track_sources => 'மாற்று பாடல் மூலங்கள்';

  @override
  String get download_track => 'பாடலைப் பதிவிறக்கு';

  @override
  String tracks_in_queue(Object tracks) {
    return 'வரிசையில் $tracks பாடல்கள்';
  }

  @override
  String get clear_all => 'அனைத்தையும் அழி';

  @override
  String get show_hide_ui_on_hover => 'மேலே வரும்போது UI ஐக் காட்டு/மறை';

  @override
  String get always_on_top => 'எப்போதும் மேலே';

  @override
  String get exit_mini_player => 'சிறிய இயக்கியிலிருந்து வெளியேறு';

  @override
  String get download_location => 'பதிவிறக்க இடம்';

  @override
  String get local_library => 'உள்ளூர் நூலகம்';

  @override
  String get add_library_location => 'நூலகத்தில் சேர்';

  @override
  String get remove_library_location => 'நூலகத்திலிருந்து நீக்கு';

  @override
  String get account => 'கணக்கு';

  @override
  String get logout => 'வெளியேறு';

  @override
  String get logout_of_this_account => 'இந்த கணக்கிலிருந்து வெளியேறு';

  @override
  String get language_region => 'மொழி & பிராந்தியம்';

  @override
  String get language => 'மொழி';

  @override
  String get system_default => 'கணினி இயல்புநிலை';

  @override
  String get market_place_region => 'சந்தை பிராந்தியம்';

  @override
  String get recommendation_country => 'பரிந்துரை நாடு';

  @override
  String get appearance => 'தோற்றம்';

  @override
  String get layout_mode => 'அமைப்பு முறை';

  @override
  String get override_layout_settings => 'தளவமைப்பு அமைப்புகளை மாற்றியமை';

  @override
  String get adaptive => 'தகவமைப்பு';

  @override
  String get compact => 'சுருக்கமான';

  @override
  String get extended => 'விரிவான';

  @override
  String get theme => 'தீம்';

  @override
  String get dark => 'இருள்';

  @override
  String get light => 'வெளிர்';

  @override
  String get system => 'கணினி வழி';

  @override
  String get accent_color => 'அழுத்த நிறம்';

  @override
  String get sync_album_color => 'ஆல்பம் நிறத்தை ஒத்திசை';

  @override
  String get sync_album_color_description =>
      'ஆல்பம் படத்தின் முக்கிய நிறத்தை அழுத்த நிறமாகப் பயன்படுத்துகிறது';

  @override
  String get playback => 'பின்னணி';

  @override
  String get audio_quality => 'ஒலி தரம்';

  @override
  String get high => 'உயர்';

  @override
  String get low => 'குறைந்த';

  @override
  String get pre_download_play => 'முன்பதிவிறக்கம் மற்றும் இயக்கம்';

  @override
  String get pre_download_play_description =>
      'ஒலியை ஸ்ட்ரீம் செய்வதற்குப் பதிலாக, பைட்டுகளைப் பதிவிறக்கி இயக்கவும் (அதிக பேண்ட்விட்த் பயனர்களுக்கு பரிந்துரைக்கப்படுகிறது)';

  @override
  String get skip_non_music => 'இசையல்லாத பகுதிகளைத் தவிர் (SponsorBlock)';

  @override
  String get blacklist_description =>
      'தடைசெய்யப்பட்ட பாடல்கள் மற்றும் கலைஞர்கள்';

  @override
  String get wait_for_download_to_finish =>
      'தற்போதைய பதிவிறக்கம் முடியும் வரை காத்திருக்கவும்';

  @override
  String get desktop => 'கணினி';

  @override
  String get close_behavior => 'மூடும் நடத்தை';

  @override
  String get close => 'மூடு';

  @override
  String get minimize_to_tray => 'ட்ரேயை குறைக்கவும்';

  @override
  String get show_tray_icon => 'ட்ரே ஐகானைக் காட்டு';

  @override
  String get about => 'பற்றி';

  @override
  String get u_love_spotube =>
      'நீங்கள் Spotube ஐ நேசிக்கிறீர்கள் என்பது எங்களுக்குத் தெரியும்';

  @override
  String get check_for_updates => 'புதுப்பிப்புகளைச் சரிபார்';

  @override
  String get about_spotube => 'Spotube பற்றி';

  @override
  String get blacklist => 'தடைப்பட்டியல்';

  @override
  String get please_sponsor => 'தயவுசெய்து ஆதரவு/நன்கொடை அளியுங்கள்';

  @override
  String get spotube_description =>
      'Spotube, ஒரு லேசான, பல தளங்களில் இயங்கும், அனைவருக்கும் இலவசமான spotify கிளையன்ட்';

  @override
  String get version => 'பதிப்பு';

  @override
  String get build_number => 'கட்டமைப்பு எண்';

  @override
  String get founder => 'நிறுவனர்';

  @override
  String get repository => 'களஞ்சியம்';

  @override
  String get bug_issues => 'பிழை_சிக்கல்கள்';

  @override
  String get made_with => 'வங்காளதேசத்திலிருந்து🇧🇩 ❤️ உருவாக்கப்பட்டது';

  @override
  String get kingkor_roy_tirtho => 'கிங்கர் ராய் திர்தோ';

  @override
  String copyright(Object current_year) {
    return '© 2021-$current_year கிங்கர் ராய் திர்தோ';
  }

  @override
  String get license => 'உரிமம்';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'கவலைப்பட வேண்டாம், உங்கள் சான்றுகள் எதுவும் சேகரிக்கப்படாது அல்லது யாருடனும் பகிரப்படாது';

  @override
  String get know_how_to_login => 'இதை எப்படி செய்வது என்று தெரியவில்லையா?';

  @override
  String get follow_step_by_step_guide =>
      'படிப்படியான வழிகாட்டியைப் பின்பற்றவும்';

  @override
  String cookie_name_cookie(Object name) {
    return '$name நட்புநிரல்';
  }

  @override
  String get fill_in_all_fields => 'அனைத்து களங்களையும் நிரப்பவும்';

  @override
  String get submit => 'சமர்ப்பி';

  @override
  String get exit => 'வெளியேறு';

  @override
  String get previous => 'முந்தைய';

  @override
  String get next => 'அடுத்து';

  @override
  String get done => 'முடிந்தது';

  @override
  String get step_1 => 'முதல் படி';

  @override
  String get first_go_to => 'முதலில், செல்லவேண்டியது';

  @override
  String get something_went_wrong => 'ஏதோ தவறு நடந்துவிட்டது';

  @override
  String get piped_instance => 'Piped சேவையகம் நிகழ்வு';

  @override
  String get piped_description =>
      'பாடல் பொருத்தத்திற்குப் பயன்படுத்த வேண்டிய Piped சேவையகம் நிகழ்வு';

  @override
  String get piped_warning =>
      'அவற்றில் சில நன்றாக வேலை செய்யாமல் இருக்கலாம். எனவே உங்கள் சொந்த ஆபத்தில் பயன்படுத்தவும்';

  @override
  String get invidious_instance => 'Invidious சேவையக நிகழ்வு';

  @override
  String get invidious_description =>
      'பாடல் பொருத்தத்திற்குப் பயன்படுத்த வேண்டிய Invidious சேவையக நிகழ்வு';

  @override
  String get invidious_warning =>
      'அவற்றில் சில நன்றாக வேலை செய்யாமல் இருக்கலாம். எனவே உங்கள் சொந்த ஆபத்தில் பயன்படுத்தவும்';

  @override
  String get generate => 'உருவாக்கு';

  @override
  String track_exists(Object track) {
    return 'பாடல் $track ஏற்கனவே உள்ளது';
  }

  @override
  String get replace_downloaded_tracks =>
      'பதிவிறக்கம் செய்யப்பட்ட அனைத்து பாடல்களையும் மாற்றவும்';

  @override
  String get skip_download_tracks =>
      'பதிவிறக்கம் செய்யப்பட்ட அனைத்து பாடல்களையும் தவிர்க்கவும்';

  @override
  String get do_you_want_to_replace =>
      'ஏற்கனவே உள்ள பாடலை மாற்ற விரும்புகிறீர்களா?';

  @override
  String get replace => 'மாற்று';

  @override
  String get skip => 'தவிர்';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return '$count $type வரை தேர்ந்தெடுக்கவும்';
  }

  @override
  String get select_genres => 'வகைகளைத் தேர்ந்தெடுக்கவும்';

  @override
  String get add_genres => 'வகைகளைச் சேர்க்கவும்';

  @override
  String get country => 'நாடு';

  @override
  String get number_of_tracks_generate =>
      'உருவாக்க வேண்டிய பாடல்களின் எண்ணிக்கை';

  @override
  String get acousticness => 'அகவுஸ்டிக்னெஸ்';

  @override
  String get danceability => 'நடனத்தன்மை';

  @override
  String get energy => 'ஆற்றல்';

  @override
  String get instrumentalness => 'கருவித்தன்மை';

  @override
  String get liveness => 'உயிர்ப்புத்தன்மை';

  @override
  String get loudness => 'ஒலி அளவு';

  @override
  String get speechiness => 'பேச்சுத்தன்மை';

  @override
  String get valence => 'உணர்வு';

  @override
  String get popularity => 'பிரபலம்';

  @override
  String get key => 'இசை குறிப்பு';

  @override
  String get duration => 'கால அளவு (வினாடிகள்)';

  @override
  String get tempo => 'வேகம் (BPM)';

  @override
  String get mode => 'முறை';

  @override
  String get time_signature => 'நேர கையொப்பம்';

  @override
  String get short => 'குறுகிய';

  @override
  String get medium => 'நடுத்தர';

  @override
  String get long => 'நீண்ட';

  @override
  String get min => 'குறைந்தபட்சம்';

  @override
  String get max => 'அதிகபட்சம்';

  @override
  String get target => 'இலக்கு';

  @override
  String get moderate => 'மிதமான';

  @override
  String get deselect_all => 'அனைத்தையும் தேர்வுநீக்கு';

  @override
  String get select_all => 'அனைத்தையும் தேர்ந்தெடு';

  @override
  String get are_you_sure => 'உறுதியாக இருக்கிறீர்களா?';

  @override
  String get generating_playlist =>
      'உங்கள் தனிப்பயன்பாட்டிற்கான பாடல் பட்டியலை உருவாக்குகிறது...';

  @override
  String selected_count_tracks(Object count) {
    return '$count பாடல்கள் தேர்ந்தெடுக்கப்பட்டன';
  }

  @override
  String get download_warning =>
      'நீங்கள் அனைத்து பாடல்களையும் மொத்தமாக பதிவிறக்கினால், நீங்கள் தெளிவாக இசையைத் திருடுகிறீர்கள் மற்றும் இசையின் படைப்பாற்றல் சமூகத்திற்கு சேதம் விளைவிக்கிறீர்கள். நீங்கள் இதை அறிந்திருக்கிறீர்கள் என்று நம்புகிறேன். எப்போதும், கலைஞரின் கடின உழைப்பை மதித்து ஆதரிக்க முயற்சி செய்யுங்கள்';

  @override
  String get download_ip_ban_warning =>
      'மேலும், அதிகப்படியான பதிவிறக்க கோரிக்கைகள் காரணமாக உங்கள் IP YouTube இல் தடைசெய்யப்படலாம். IP தடை என்பது குறைந்தது 2-3 மாதங்களுக்கு அந்த IP சாதனத்திலிருந்து YouTube ஐப் பயன்படுத்த முடியாது (நீங்கள் உள்நுழைந்திருந்தாலும் கூட). இது ஒருபோதும் நடந்தால் Spotube பொறுப்பேற்காது';

  @override
  String get by_clicking_accept_terms =>
      '\'ஏற்றுக்கொள்\' என்பதைக் கிளிக் செய்வதன் மூலம் பின்வரும் விதிமுறைகளுக்கு நீங்கள் ஒப்புக்கொள்கிறீர்கள்:';

  @override
  String get download_agreement_1 =>
      'நான் இசையைத் திருடுகிறேன் என்பது எனக்குத் தெரியும். நான் கெட்டவன்';

  @override
  String get download_agreement_2 =>
      'நான் கலைஞரை முடிந்தவரை ஆதரிப்பேன், அவர்களின் கலைக்கு பணம் செலுத்த எனக்கு பணம் இல்லாததால் மட்டுமே இதைச் செய்கிறேன்';

  @override
  String get download_agreement_3 =>
      'என் IP YouTube இல் தடைசெய்யப்படலாம் என்பதை நான் முழுமையாக அறிவேன், மேலும் என் தற்போதைய செயலால் ஏற்படும் எந்த விபத்துகளுக்கும் Spotube அல்லது அதன் உரிமையாளர்கள்/பங்களிப்பாளர்களை பொறுப்பாக்க மாட்டேன்';

  @override
  String get decline => 'மறு';

  @override
  String get accept => 'ஏற்றுக்கொள்';

  @override
  String get details => 'விவரங்கள்';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'சேனல்';

  @override
  String get likes => 'விருப்பங்கள்';

  @override
  String get dislikes => 'விருப்பமில்லாதவை';

  @override
  String get views => 'பார்வைகள்';

  @override
  String get streamUrl => 'ஸ்ட்ரீம் URL';

  @override
  String get stop => 'நிறுத்து';

  @override
  String get sort_newest => 'புதிதாக சேர்க்கப்பட்டவற்றை வரிசைப்படுத்து';

  @override
  String get sort_oldest => 'பழமையானவற்றை வரிசைப்படுத்து';

  @override
  String get sleep_timer => 'உறக்க நேரம்';

  @override
  String mins(Object minutes) {
    return '$minutes நிமிடங்கள்';
  }

  @override
  String hours(Object hours) {
    return '$hours மணிநேரங்கள்';
  }

  @override
  String hour(Object hours) {
    return '$hours மணிநேரம்';
  }

  @override
  String get custom_hours => 'தனிப்பயன் மணிநேரங்கள்';

  @override
  String get logs => 'பதிவுகள்';

  @override
  String get developers => 'உருவாக்குநர்கள்';

  @override
  String get not_logged_in => 'நீங்கள் உள்நுழையவில்லை';

  @override
  String get search_mode => 'தேடல் முறை';

  @override
  String get audio_source => 'ஒலி மூலம்';

  @override
  String get ok => 'சரி';

  @override
  String get failed_to_encrypt => 'குறியாக்கம் தோல்வியடைந்தது';

  @override
  String get encryption_failed_warning =>
      'Spotube உங்கள் தரவை பாதுகாப்பாக சேமிக்க குறியாக்கத்தைப் பயன்படுத்துகிறது. ஆனால் அவ்வாறு செய்ய முடியவில்லை. எனவே இது பாதுகாப்பற்ற சேமிப்பகத்திற்கு மாறும்\nநீங்கள் லினக்ஸ் பயன்படுத்துகிறீர்கள் என்றால், எந்த ரகசிய சேவையும் (gnome-keyring, kde-wallet, keepassxc போன்றவை) நிறுவப்பட்டுள்ளதா என்பதை உறுதிப்படுத்தவும்';

  @override
  String get querying_info => 'தகவலைக் கேட்கிறது...';

  @override
  String get piped_api_down => 'Piped API செயலிழந்துள்ளது';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'Piped நிகழ்வு $pipedInstance தற்போது செயலிழந்துள்ளது\n\nநிகழ்வை மாற்றவும் அல்லது \'API வகை\'யை அதிகாரப்பூர்வ YouTube API க்கு மாற்றவும்\n\nமாற்றத்திற்குப் பிறகு பயன்பாட்டை மறுதொடக்கம் செய்வதை உறுதிப்படுத்தவும்';
  }

  @override
  String get you_are_offline => 'நீங்கள் தற்போது ஆஃப்லைனில் உள்ளீர்கள்';

  @override
  String get connection_restored => 'உங்கள் இணைய இணைப்பு மீட்டெடுக்கப்பட்டது';

  @override
  String get use_system_title_bar => 'கணினி தலைப்புப் பட்டியைப் பயன்படுத்தவும்';

  @override
  String get crunching_results => 'முடிவுகளை செயலாக்குகிறது...';

  @override
  String get search_to_get_results => 'முடிவுகளைப் பெற தேடவும்';

  @override
  String get use_amoled_mode => 'கருமை நிற இருண்ட தீம்';

  @override
  String get pitch_dark_theme => 'AMOLED முறை';

  @override
  String get normalize_audio => 'ஒலியை சீரமை';

  @override
  String get change_cover => 'அட்டையை மாற்று';

  @override
  String get add_cover => 'அட்டையைச் சேர்';

  @override
  String get restore_defaults => 'இயல்புநிலைகளை மீட்டமை';

  @override
  String get download_music_format => 'இசை பதிவிறக்க வடிவம்';

  @override
  String get streaming_music_format => 'இசை ஸ்ட்ரீமிங் வடிவம்';

  @override
  String get download_music_quality => 'பதிவிறக்க தரம்';

  @override
  String get streaming_music_quality => 'ஸ்ட்ரீமிங் தரம்';

  @override
  String get login_with_lastfm => 'Last.fm உடன் உள்நுழைக';

  @override
  String get connect => 'இணை';

  @override
  String get disconnect_lastfm => 'Last.fm இலிருந்து துண்டி';

  @override
  String get disconnect => 'துண்டி';

  @override
  String get username => 'பயனர்பெயர்';

  @override
  String get password => 'கடவுச்சொல்';

  @override
  String get login => 'உள்நுழைக';

  @override
  String get login_with_your_lastfm => 'உங்கள் Last.fm கணக்குடன் உள்நுழைக';

  @override
  String get scrobble_to_lastfm => 'Last.fm க்கு ஸ்க்ரோபிள் செய்';

  @override
  String get go_to_album => 'ஆல்பத்திற்குச் செல்';

  @override
  String get discord_rich_presence => 'Discord செழுமையான தோற்றம்';

  @override
  String get browse_all => 'அனைத்தையும் உலாவு';

  @override
  String get genres => 'வகைகள்';

  @override
  String get explore_genres => 'வகைகளை ஆராயுங்கள்';

  @override
  String get friends => 'நண்பர்கள்';

  @override
  String get no_lyrics_available =>
      'மன்னிக்கவும், இந்தப் பாடலுக்கான பாடல் வரிகளைக் கண்டுபிடிக்க முடியவில்லை';

  @override
  String get start_a_radio => 'வானொலியைத் தொடங்கு';

  @override
  String get how_to_start_radio => 'வானொலியை எவ்வாறு தொடங்க விரும்புகிறீர்கள்?';

  @override
  String get replace_queue_question =>
      'தற்போதைய வரிசையை மாற்ற விரும்புகிறீர்களா அல்லது அதனுடன் சேர்க்க விரும்புகிறீர்களா?';

  @override
  String get endless_playback => 'முடிவற்ற இயக்கம்';

  @override
  String get delete_playlist => 'பாடல் பட்டியலை நீக்கு';

  @override
  String get delete_playlist_confirmation =>
      'இந்த பாடல் பட்டியலை நீக்க விரும்புகிறீர்களா?';

  @override
  String get local_tracks => 'உள்ளூர் பாடல்கள்';

  @override
  String get local_tab => 'உள்ளூர்';

  @override
  String get song_link => 'பாடல் இணைப்பு';

  @override
  String get skip_this_nonsense => 'இந்த அர்த்தமற்றதைத் தவிர்';

  @override
  String get freedom_of_music => '\"இசையின் சுதந்திரம்\"';

  @override
  String get freedom_of_music_palm => '\"உங்கள் கைகளில் இசையின் சுதந்திரம்\"';

  @override
  String get get_started => 'தொடங்குவோம்';

  @override
  String get youtube_source_description =>
      'பரிந்துரைக்கப்படுகிறது மற்றும் சிறப்பாக செயல்படுகிறது.';

  @override
  String get piped_source_description =>
      'சுதந்திரமாக உணர்கிறீர்களா? YouTube போலவே ஆனால் மிகவும் சுதந்திரமானது.';

  @override
  String get jiosaavn_source_description =>
      'தெற்காசியப் பிராந்தியத்திற்கு சிறந்தது.';

  @override
  String get invidious_source_description =>
      'Piped ஐப் போன்றது ஆனால் அதிக கிடைக்கும் தன்மையுடன்.';

  @override
  String highest_quality(Object quality) {
    return 'உயர்ந்த தரம்: $quality';
  }

  @override
  String get select_audio_source => 'ஒலி மூலத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get endless_playback_description =>
      'வரிசையின் இறுதியில் புதிய பாடல்களை\nதானாகவே சேர்க்கவும்';

  @override
  String get choose_your_region => 'உங்கள் பிராந்தியத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get choose_your_region_description =>
      'இது உங்கள் இருப்பிடத்திற்கான சரியான உள்ளடக்கத்தை\nSpotube காட்ட உதவும்.';

  @override
  String get choose_your_language => 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get help_project_grow => 'இந்த திட்டம் வளர உதவுங்கள்';

  @override
  String get help_project_grow_description =>
      'Spotube ஒரு திறந்த மூல திட்டம். திட்டத்திற்கு பங்களிப்பு செய்வதன் மூலம், பிழைகளைப் புகாரளிப்பதன் மூலம் அல்லது புதிய அம்சங்களைப் பரிந்துரைப்பதன் மூலம் இந்தத் திட்டம் வளர உதவலாம்.';

  @override
  String get contribute_on_github => 'GitHub இல் பங்களியுங்கள்';

  @override
  String get donate_on_open_collective =>
      'Open Collective இல் நன்கொடை அளியுங்கள்';

  @override
  String get browse_anonymously => 'அநாமதேயமாக உலாவுக';

  @override
  String get enable_connect => 'இணைப்பை இயக்கு';

  @override
  String get enable_connect_description =>
      'மற்ற சாதனங்களிலிருந்து Spotube ஐக் கட்டுப்படுத்தவும்';

  @override
  String get devices => 'சாதனங்கள்';

  @override
  String get select => 'தேர்ந்தெடு';

  @override
  String connect_client_alert(Object client) {
    return 'நீங்கள் $client ஆல் கட்டுப்படுத்தப்படுகிறீர்கள்';
  }

  @override
  String get this_device => 'இந்த சாதனம்';

  @override
  String get remote => 'தொலைநிலை';

  @override
  String get stats => 'புள்ளிவிவரங்கள்';

  @override
  String and_n_more(Object count) {
    return 'மற்றும் $count கூடுதலாக';
  }

  @override
  String get recently_played => 'சமீபத்தில் இயக்கியவை';

  @override
  String get browse_more => 'மேலும் உலாவு';

  @override
  String get no_title => 'தலைப்பு இல்லை';

  @override
  String get not_playing => 'இயக்கப்படவில்லை';

  @override
  String get epic_failure => 'மோசமான தோல்வி!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return '$tracks_length பாடல்கள் வரிசையில் சேர்க்கப்பட்டன';
  }

  @override
  String get spotube_has_an_update => 'Spotube க்கு ஒரு புதுப்பிப்பு உள்ளது';

  @override
  String get download_now => 'இப்போது பதிவிறக்கு';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Spotube Nightly $nightlyBuildNum வெளியிடப்பட்டுள்ளது';
  }

  @override
  String release_version(Object version) {
    return 'Spotube v$version வெளியிடப்பட்டுள்ளது';
  }

  @override
  String get read_the_latest => 'சமீபத்திய ';

  @override
  String get release_notes => 'வெளியீட்டு குறிப்புகளைப் படிக்கவும்';

  @override
  String get pick_color_scheme => 'வண்ணத் திட்டத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get save => 'சேமி';

  @override
  String get choose_the_device => 'சாதனத்தைத் தேர்ந்தெடுக்கவும்:';

  @override
  String get multiple_device_connected =>
      'பல சாதனங்கள் இணைக்கப்பட்டுள்ளன.\nஇந்த செயல் நடைபெற வேண்டிய சாதனத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get nothing_found => 'எதுவும் கிடைக்கவில்லை';

  @override
  String get the_box_is_empty => 'பெட்டி காலியாக உள்ளது';

  @override
  String get top_artists => 'சிறந்த கலைஞர்கள்';

  @override
  String get top_albums => 'சிறந்த ஆல்பங்கள்';

  @override
  String get this_week => 'இந்த வாரம்';

  @override
  String get this_month => 'இந்த மாதம்';

  @override
  String get last_6_months => 'கடந்த 6 மாதங்கள்';

  @override
  String get this_year => 'இந்த ஆண்டு';

  @override
  String get last_2_years => 'கடந்த 2 ஆண்டுகள்';

  @override
  String get all_time => 'எல்லா நேரமும்';

  @override
  String powered_by_provider(Object providerName) {
    return '$providerName ஆல் இயக்கப்படுகிறது';
  }

  @override
  String get email => 'மின்னஞ்சல்';

  @override
  String get profile_followers => 'பின்தொடர்பவர்கள்';

  @override
  String get birthday => 'பிறந்த நாள்';

  @override
  String get subscription => 'சந்தா';

  @override
  String get not_born => 'பிறக்கவில்லை';

  @override
  String get hacker => 'ஹேக்கர்';

  @override
  String get profile => 'சுயவிவரம்';

  @override
  String get no_name => 'பெயர் இல்லை';

  @override
  String get edit => 'திருத்து';

  @override
  String get user_profile => 'பயனர் சுயவிவரம்';

  @override
  String count_plays(Object count) {
    return '$count முறை இசைக்கப்பட்டது';
  }

  @override
  String get streaming_fees_hypothetical => 'ஸ்ட்ரீமிங் கட்டணங்கள் (கற்பனை)';

  @override
  String get minutes_listened => 'காலம் கேட்டது';

  @override
  String get streamed_songs => 'ஸ்ட்ரீமிங் செய்யப்பட்ட பாடல்கள்';

  @override
  String count_streams(Object count) {
    return '$count ஸ்ட்ரீம்கள்';
  }

  @override
  String get owned_by_you => 'உங்களால் கொண்டது';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return 'நகலெடுக்கப்பட்டது $shareUrl கிளிப்போர்டுக்காக';
  }

  @override
  String get hipotetical_calculation =>
      '*இது சராசரி ஆன்லைன் இசை ஸ்ட்ரீமிங் தளத்தின் ஒரு ஸ்ட்ரீமிற்கான \$0.003 முதல் \$0.005 வரையிலான கட்டணத்தின் அடிப்படையில் கணக்கிடப்படுகிறது. இது ஒரு கற்பனையான கணக்கீடு ஆகும், இது பயனர்கள் வெவ்வேறு இசை ஸ்ட்ரீமிங் தளங்களில் தங்கள் பாடல்களைக் கேட்டால் கலைஞர்களுக்கு எவ்வளவு பணம் செலுத்தியிருப்பார்கள் என்பது குறித்த நுண்ணறிவை வழங்குகிறது.';

  @override
  String count_mins(Object minutes) {
    return '$minutes நிமிடங்கள்';
  }

  @override
  String get summary_minutes => 'நிமிடங்கள்';

  @override
  String get summary_listened_to_music => 'இசை கேட்டது';

  @override
  String get summary_songs => 'பாடல்கள்';

  @override
  String get summary_streamed_overall => 'மொத்தமாக ஸ்ட்ரீமிங்';

  @override
  String get summary_owed_to_artists => 'கலைஞர்களுக்கு\nஇந்த மாதம் சொந்தமானது';

  @override
  String get summary_artists => 'கலைஞர்கள்';

  @override
  String get summary_music_reached_you => 'இசை உங்களுக்கு வந்தது';

  @override
  String get summary_full_albums => 'முழு ஆல்பங்கள்';

  @override
  String get summary_got_your_love => 'உங்கள் அன்பை பெற்றுக்கொண்டேன்';

  @override
  String get summary_playlists => 'பாடல் பட்டியல்கள்';

  @override
  String get summary_were_on_repeat => 'மீண்டும் மீண்டும் இருந்தன';

  @override
  String total_money(Object money) {
    return 'மொத்தம் $money';
  }

  @override
  String get webview_not_found => 'வெப்வியூ கிடைக்கவில்லை';

  @override
  String get webview_not_found_description =>
      'உங்கள் சாதனத்தில் எந்தவொரு வெப்வியூ இயக்கத்தை நிறுவவில்லை.\nஇது நிறுவப்பட்டிருந்தால், சுற்றுச்சூழல் பாதையில் PATH உள்ளது என்பதை உறுதிபடுத்தவும்\n\nநிறுவித்த பிறகு, செயலியை மறுதொடக்கம் செய்யவும்';

  @override
  String get unsupported_platform => 'அதிர்ஷ்டகாத உருப்படியை ஆதரிக்கவில்லை';

  @override
  String get cache_music => 'இசையை கேஷ் செய்';

  @override
  String get open => 'திறக்கவும்';

  @override
  String get cache_folder => 'கேஷ் அடைவு';

  @override
  String get export => 'ஏற்றுமதி';

  @override
  String get clear_cache => 'கேஷ் அழிக்கவும்';

  @override
  String get clear_cache_confirmation => 'கேஷைப் அழிக்க விரும்புகிறீர்களா?';

  @override
  String get export_cache_files => 'கேஷில் உள்ள கோப்புகளை ஏற்றுமதி செய்யவும்';

  @override
  String found_n_files(Object count) {
    return '$count கோப்புகள் கிடைத்தன';
  }

  @override
  String get export_cache_confirmation =>
      'இந்த கோப்புகளை ஏற்றுமதி செய்ய விரும்புகிறீர்களா?';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return '$filesExported கோப்புகள் ஏற்றுமதி செய்யப்பட்டன, $files கோப்புகளில்';
  }

  @override
  String get undo => 'செயல்தவிர்';

  @override
  String get download_all => 'அனைத்தையும் பதிவிறக்குக';

  @override
  String get add_all_to_playlist => 'அனைத்தையும் பாடல் பட்டியலில் சேர்க்கவும்';

  @override
  String get add_all_to_queue => 'அனைத்தையும் வரிசைப்படுத்து';

  @override
  String get play_all_next => 'அடுத்த உள்ள அனைத்தையும் இயக்கு';

  @override
  String get pause => 'நிறுத்து';

  @override
  String get view_all => 'அனைத்தையும் காண்க';

  @override
  String get no_tracks_added_yet =>
      'உங்கள் பாடல்களை இன்னும் சேர்க்கவில்லை என்றால் தெரியாதே';

  @override
  String get no_tracks => 'இங்கு பாடல்கள் எதுவும் இல்லை';

  @override
  String get no_tracks_listened_yet => 'இன்னும் எதையும் கேள்வியில்லை';

  @override
  String get not_following_artists => 'நீங்கள் எந்த கலைஞரையும் பின்தொடரவில்லை';

  @override
  String get no_favorite_albums_yet =>
      'நீங்கள் இன்னும் எந்த ஆல்பங்களையும் பிடித்தவையாகச் சேர்க்கவில்லை';

  @override
  String get no_logs_found => 'பதிவுகள் எதுவும் கிடைக்கவில்லை';

  @override
  String get youtube_engine => 'YouTube இயந்திரம்';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine நிறுவியதில்லை';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine உங்கள் கணினியில் நிறுவியதில்லை.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'PATH மாறியில் கிடைக்கிறதா என்பதை உறுதிப்படுத்தவும் அல்லது\n$engine செயல் செய்யக்கூடிய முறையை கீழே அமைக்கவும்';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'macOS/Linux/unix போல் OS இல், .zshrc/.bashrc/.bash_profile போன்றவை அமைப்பில் பாதையை PATH அமைப்பது இயலாது.\nநீங்கள்.shell configuration file இல் பாதையை அமைக்க வேண்டும்';

  @override
  String get download => 'பதிவிறக்கு';

  @override
  String get file_not_found => 'கோப்பு கிடைக்கவில்லை';

  @override
  String get custom => 'தனிப்பயன்';

  @override
  String get add_custom_url => 'தனிப்பயன் URL ஐச் சேர்க்கவும்';

  @override
  String get edit_port => 'போர்டு திருத்தவும்';

  @override
  String get port_helper_msg =>
      'இயல்புநிலை -1 ஆகும், இது சீரற்ற எண்ணை குறிக்கிறது. நீங்கள் தீயணைப்பு அமைக்கப்பட்டிருந்தால், இதை அமைப்பது பரிந்துரைக்கப்படுகிறது.';

  @override
  String connect_request(Object client) {
    return '$client க்கு இணைக்க அனுமதிக்கவா?';
  }

  @override
  String get connection_request_denied =>
      'இணைப்பு மறுக்கப்பட்டது. பயனர் அணுகலை மறுத்தார்.';

  @override
  String get an_error_occurred => 'ஒரு பிழை ஏற்பட்டது';

  @override
  String get copy_to_clipboard => 'கிளிப்போர்டுக்கு நகலெடுக்கவும்';

  @override
  String get view_logs => 'பதிவுகளைப் பார்க்கவும்';

  @override
  String get retry => 'மீண்டும் முயற்சிக்கவும்';

  @override
  String get no_default_metadata_provider_selected =>
      'நீங்கள் எந்த இயல்புநிலை மெட்டாடேட்டா வழங்குநரையும் அமைக்கவில்லை';

  @override
  String get manage_metadata_providers =>
      'மெட்டாடேட்டா வழங்குநர்களை நிர்வகிக்கவும்';

  @override
  String get open_link_in_browser => 'இணைப்பை உலாவியில் திறக்கவா?';

  @override
  String get do_you_want_to_open_the_following_link =>
      'பின்வரும் இணைப்பை நீங்கள் திறக்க விரும்புகிறீர்களா';

  @override
  String get unsafe_url_warning =>
      'நம்பத்தகாத மூலங்களிலிருந்து இணைப்புகளைத் திறப்பது பாதுகாப்பற்றதாக இருக்கலாம். எச்சரிக்கையாக இருங்கள்!\nநீங்கள் இணைப்பை உங்கள் கிளிப்போர்டுக்கு நகலெடுக்கலாம்.';

  @override
  String get copy_link => 'இணைப்பை நகலெடுக்கவும்';

  @override
  String get building_your_timeline =>
      'உங்கள் கேட்டலின் அடிப்படையில் உங்கள் காலவரிசையை உருவாக்குகிறது...';

  @override
  String get official => 'அதிகாரபூர்வமானது';

  @override
  String author_name(Object author) {
    return 'ஆசிரியர்: $author';
  }

  @override
  String get third_party => 'மூன்றாம் தரப்பு';

  @override
  String get plugin_requires_authentication =>
      'பிளகின் அங்கீகாரத்தைக் கோருகிறது';

  @override
  String get update_available => 'புதுப்பிப்பு உள்ளது';

  @override
  String get supports_scrobbling => 'ஸ்க்ரோப்ளிங்கை ஆதரிக்கிறது';

  @override
  String get plugin_scrobbling_info =>
      'இந்த பிளகின் உங்கள் கேட்பதின் வரலாற்றை உருவாக்க உங்கள் இசையை ஸ்க்ரோப்ள் செய்கிறது.';

  @override
  String get default_metadata_source => 'இயல்புநிலை மெட்டாடேட்டா மூலம்';

  @override
  String get set_default_metadata_source =>
      'இயல்புநிலை மெட்டாடேட்டா மூலத்தை அமை';

  @override
  String get default_audio_source => 'இயல்புநிலை ஆடியோ மூலம்';

  @override
  String get set_default_audio_source => 'இயல்புநிலை ஆடியோ மூலத்தை அமை';

  @override
  String get set_default => 'இயல்புநிலையாக அமைக்கவும்';

  @override
  String get support => 'ஆதரவு';

  @override
  String get support_plugin_development => 'பிளகின் வளர்ச்சிக்கு ஆதரவு';

  @override
  String can_access_name_api(Object name) {
    return '- **$name** API ஐ அணுக முடியும்';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'இந்த பிளகினை நீங்கள் நிறுவ விரும்புகிறீர்களா?';

  @override
  String get third_party_plugin_warning =>
      'இந்த பிளகின் மூன்றாம் தரப்பு களஞ்சியத்திலிருந்து வருகிறது. நிறுவும் முன் மூலத்தை நீங்கள் நம்புகிறீர்கள் என்பதை உறுதிப்படுத்தவும்.';

  @override
  String get author => 'ஆசிரியர்';

  @override
  String get this_plugin_can_do_following =>
      'இந்த பிளகின் பின்வருவனவற்றைச் செய்ய முடியும்';

  @override
  String get install => 'நிறுவவும்';

  @override
  String get install_a_metadata_provider => 'மெட்டாடேட்டா வழங்குநரை நிறுவவும்';

  @override
  String get no_tracks_playing => 'தற்போது எந்த பாடலும் இயங்கவில்லை';

  @override
  String get synced_lyrics_not_available =>
      'இந்த பாடலுக்கு ஒத்திசைக்கப்பட்ட வரிகள் கிடைக்கவில்லை. தயவுசெய்து';

  @override
  String get plain_lyrics => 'சாதாரண வரிகள்';

  @override
  String get tab_instead => 'தாவலை அதற்கு பதிலாக பயன்படுத்தவும்.';

  @override
  String get disclaimer => 'துறப்பு';

  @override
  String get third_party_plugin_dmca_notice =>
      'ஸ்பாட்யூப் குழு எந்த \"மூன்றாம் தரப்பு\" பிளகின்களுக்கும் எந்தப் பொறுப்பையும் (சட்டரீதியான உட்பட) ஏற்காது.\nதயவுசெய்து உங்கள் சொந்த ஆபத்தில் அவற்றைப் பயன்படுத்தவும். ஏதேனும் பிழைகள்/சிக்கல்களுக்கு, பிளகின் களஞ்சியத்தில் அவற்றைப் புகாரளிக்கவும்.\n\nஏதேனும் ஒரு \"மூன்றாம் தரப்பு\" பிளகின் ஒரு சேவை/சட்ட நிறுவனத்தின் ToS/DMCA ஐ மீறினால், தயவுசெய்து \"மூன்றாம் தரப்பு\" பிளகின் ஆசிரியரையோ அல்லது ஹோஸ்டிங் தளத்தையோ, எ.கா. GitHub/Codeberg, நடவடிக்கை எடுக்கக் கோரவும். மேலே பட்டியலிடப்பட்ட (\"மூன்றாம் தரப்பு\" என பெயரிடப்பட்ட) அனைத்து பொதுவான/சமூகத்தால் பராமரிக்கப்படும் பிளகின்கள். நாங்கள் அவற்றை க்யூரேட் செய்யவில்லை, எனவே அவற்றின் மீது எந்த நடவடிக்கையும் எடுக்க முடியாது.\n\n';

  @override
  String get input_does_not_match_format =>
      'உள்ளீடு தேவையான வடிவத்துடன் பொருந்தவில்லை';

  @override
  String get plugins => 'செருகுநிரல்கள்';

  @override
  String get paste_plugin_download_url =>
      'பதிவிறக்க url அல்லது GitHub/Codeberg repo url அல்லது .smplug கோப்பிற்கான நேரடி இணைப்பை ஒட்டவும்';

  @override
  String get download_and_install_plugin_from_url =>
      'url இலிருந்து பிளகினைப் பதிவிறக்கி நிறுவவும்';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'பிளகினைச் சேர்க்கத் தவறிவிட்டது: $error';
  }

  @override
  String get upload_plugin_from_file => 'கோப்பிலிருந்து பிளகினைப் பதிவேற்றவும்';

  @override
  String get installed => 'நிறுவப்பட்டது';

  @override
  String get available_plugins => 'கிடைக்கக்கூடிய பிளகின்கள்';

  @override
  String get configure_plugins =>
      'உங்கள் சொந்த மெட்டாடேட்டா வழங்குநர் மற்றும் ஆடியோ மூல செருகுநிரல்களை அமைக்கவும்';

  @override
  String get audio_scrobblers => 'ஆடியோ ஸ்க்ரோப்ளர்கள்';

  @override
  String get scrobbling => 'ஸ்க்ரோப்ளிங்';

  @override
  String get source => 'மூலம்: ';

  @override
  String get uncompressed => 'அழுத்தப்படாத';

  @override
  String get dab_music_source_description =>
      'ஆடியோஃபைல்களுக்காக. உயர்தர/லாஸ்லெஸ் ஆடியோ ஸ்ட்ரீம்களை வழங்குகிறது. ISRC அடிப்படையில் துல்லியமான பாடல் பொருத்தம்.';
}
