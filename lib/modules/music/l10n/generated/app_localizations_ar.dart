// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get guest => 'ضيف';

  @override
  String get browse => 'تصفح';

  @override
  String get search => 'بحث';

  @override
  String get library => 'مكتبة';

  @override
  String get lyrics => 'كلمات';

  @override
  String get settings => 'إعدادات';

  @override
  String get genre_categories_filter => 'تصفية الفئات أو الأنواع...';

  @override
  String get genre => 'النوع';

  @override
  String get personalized => 'شخصية';

  @override
  String get featured => 'متميز';

  @override
  String get new_releases => 'الإصدارات الجديدة';

  @override
  String get songs => 'أغاني';

  @override
  String playing_track(Object track) {
    return 'تشغيل $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'سيؤدي هذا إلى مسح قائمة الانتظار الحالية. $track_length ستتم إزالة المقطوعات\nهل تريد الإستمرار؟';
  }

  @override
  String get load_more => 'تحميل المزيد';

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String get artists => 'فنانون';

  @override
  String get albums => 'ألبومات';

  @override
  String get tracks => 'مقطوعات';

  @override
  String get downloads => 'تنزيلات';

  @override
  String get filter_playlists => 'تصفية قوائم التشغيل الخاصة بك...';

  @override
  String get liked_tracks => 'المقطوعات التي أعجبتك';

  @override
  String get liked_tracks_description => 'جميع المقطوعات التي أعجبتك';

  @override
  String get playlist => 'قائمة التشغيل';

  @override
  String get create_a_playlist => 'إنشاء قائمة تشغيل';

  @override
  String get update_playlist => 'تحديث قائمة التشغيل';

  @override
  String get create => 'إنشاء';

  @override
  String get cancel => 'إلغاء';

  @override
  String get update => 'تحديث';

  @override
  String get playlist_name => 'اسم قائمة التشغيل';

  @override
  String get name_of_playlist => 'اسم قائمة التشغيل';

  @override
  String get description => 'وصف';

  @override
  String get public => 'عام';

  @override
  String get collaborative => 'تعاوني';

  @override
  String get search_local_tracks => 'بحث عن مقطوعات محلية';

  @override
  String get play => 'تشغيل';

  @override
  String get delete => 'حذف';

  @override
  String get none => 'لا شيء';

  @override
  String get sort_a_z => 'الترتيب من A-Z';

  @override
  String get sort_z_a => 'الترتيب من Z-A';

  @override
  String get sort_artist => 'الترتيب حسب الفنان';

  @override
  String get sort_album => 'فرز حسب الألبوم';

  @override
  String get sort_duration => 'ترتيب حسب المدة';

  @override
  String get sort_tracks => 'ترتيب المقطوعات';

  @override
  String currently_downloading(Object tracks_length) {
    return 'يتم التنزيل ($tracks_length)';
  }

  @override
  String get cancel_all => 'إلغاء الكل';

  @override
  String get refresh => 'Refresh';

  @override
  String get filter_artist => 'تصفية الفنانين...';

  @override
  String followers(Object followers) {
    return '$followers متابعون';
  }

  @override
  String get add_artist_to_blacklist => 'إضافة فنان إلى القائمة السوداء';

  @override
  String get top_tracks => 'أهم المقطوعات الصوتية';

  @override
  String get fans_also_like => 'المعجبون يحبون أيضاً';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get artist => 'فنان';

  @override
  String get blacklisted => 'في القائمة السوداء';

  @override
  String get following => 'يتابع';

  @override
  String get follow => 'تابع';

  @override
  String get artist_url_copied => 'تم نسخ عنوان URL للفنان إلى الحافظة';

  @override
  String added_to_queue(Object tracks) {
    return 'تم إضافة المقطوعات إلى قائمة الإنتظار $tracks';
  }

  @override
  String get filter_albums => 'تصفية الألبومات...';

  @override
  String get synced => 'تم المزامنة';

  @override
  String get plain => 'سهل';

  @override
  String get shuffle => 'خلط';

  @override
  String get search_tracks => 'يحث عن مقطوعات';

  @override
  String get released => 'تم الإصدار';

  @override
  String error(Object error) {
    return 'خطأ $error';
  }

  @override
  String get title => 'عنوان';

  @override
  String get time => 'وقت';

  @override
  String get more_actions => 'المزيد من الإجراءات';

  @override
  String download_count(Object count) {
    return 'تنزيل ($count)';
  }

  @override
  String add_count_to_playlist(Object count) {
    return 'إضافة ($count) إلى قائمة التشغيل';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'إضافة ($count) إلى قائمة الإنتظار';
  }

  @override
  String play_count_next(Object count) {
    return 'تشغيل ($count) التالي';
  }

  @override
  String get album => 'ألبوم';

  @override
  String copied_to_clipboard(Object data) {
    return 'تم النسخ $data إلى الحافظة';
  }

  @override
  String add_to_following_playlists(Object track) {
    return 'إضافة $track إلى قوائم التشغيل التالية';
  }

  @override
  String get add => 'إضافة';

  @override
  String added_track_to_queue(Object track) {
    return 'تم الإضافة $track إلى قائمة الإنتظار';
  }

  @override
  String get add_to_queue => 'إضافة إلى قائمة التشغيل';

  @override
  String track_will_play_next(Object track) {
    return '$track سيتم تشغيل التالي';
  }

  @override
  String get play_next => 'تشغيل التالي';

  @override
  String removed_track_from_queue(Object track) {
    return 'تم الإزالة $track من قائمة الإنتظار';
  }

  @override
  String get remove_from_queue => 'إزالة من قائمة الإنتظار';

  @override
  String get remove_from_favorites => 'إزالة من المفضلة';

  @override
  String get save_as_favorite => 'حفظ كمفضل';

  @override
  String get add_to_playlist => 'إضافة إلى قائمة التشغيل';

  @override
  String get remove_from_playlist => 'إزالة من قائمة التشغيل';

  @override
  String get add_to_blacklist => 'إضافة إلى القائمة السوداء';

  @override
  String get remove_from_blacklist => 'إزالة من القائمة السوداء';

  @override
  String get share => 'مشاكرة';

  @override
  String get mini_player => 'مشغل مصغر';

  @override
  String get slide_to_seek => 'قم بالتمرير للبحث للأمام أو للخلف';

  @override
  String get shuffle_playlist => 'قائمة تشغيل عشوائية';

  @override
  String get unshuffle_playlist => 'إلغاء ترتيب قائمة التشغيل';

  @override
  String get previous_track => 'المقطوعة السابقة';

  @override
  String get next_track => 'مقطوعة جديدة';

  @override
  String get pause_playback => 'إيقاف التشغيل مؤقتًا';

  @override
  String get resume_playback => 'استئناف التشغيل';

  @override
  String get loop_track => 'تشغيل المقطوعة بشكل لا نهائي';

  @override
  String get no_loop => 'بدون تكرار';

  @override
  String get repeat_playlist => 'تكرار قائمة التشغيل';

  @override
  String get queue => 'قائمة الإنتظار';

  @override
  String get alternative_track_sources => 'مصادر مقطوعات بديلة';

  @override
  String get download_track => 'تنزيل المقطوعة';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks المقطوعات في قائمة الإنتظار';
  }

  @override
  String get clear_all => 'مسح الكل';

  @override
  String get show_hide_ui_on_hover => 'إظهار/إخفاء واجهة المستخدم عند التمرير';

  @override
  String get always_on_top => 'دائما في القمة';

  @override
  String get exit_mini_player => 'خروج من المشغل المصغر';

  @override
  String get download_location => 'تنزيل الموقع';

  @override
  String get local_library => 'المكتبة المحلية';

  @override
  String get add_library_location => 'أضف إلى المكتبة';

  @override
  String get remove_library_location => 'إزالة من المكتبة';

  @override
  String get account => 'حساب';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logout_of_this_account => 'تسجيل الخروج من هذا الحساب';

  @override
  String get language_region => 'اللغة والمنطقة';

  @override
  String get language => 'لغة';

  @override
  String get system_default => 'لغة النظام الإفتراضية';

  @override
  String get market_place_region => 'منطقة السوق';

  @override
  String get recommendation_country => 'بلد التوصية';

  @override
  String get appearance => 'مظهر';

  @override
  String get layout_mode => 'وضع التخطيط';

  @override
  String get override_layout_settings =>
      'تجاوز إعدادات وضع التخطيط سريع الاستجابة';

  @override
  String get adaptive => 'متكيف';

  @override
  String get compact => 'مدمج';

  @override
  String get extended => 'ممتد';

  @override
  String get theme => 'مظهر';

  @override
  String get dark => 'داكن';

  @override
  String get light => 'ساطعt';

  @override
  String get system => 'حسب النظام';

  @override
  String get accent_color => 'لون تمييز';

  @override
  String get sync_album_color => 'مزامنة لون الألبوم';

  @override
  String get sync_album_color_description =>
      'يستخدم اللون السائد لصورة الألبوم باعتباره لون التمييز';

  @override
  String get playback => 'التشغيل';

  @override
  String get audio_quality => 'جودة الصوت';

  @override
  String get high => 'مرتفعة';

  @override
  String get low => 'منخفضة';

  @override
  String get pre_download_play => 'التحميل المسبق والتشغيل';

  @override
  String get pre_download_play_description =>
      'بدلاً من دفق الصوت، قم بتنزيل وحدات البايت وتشغيلها بدلاً من ذلك (موصى به لمستخدمي Bandwidth)';

  @override
  String get skip_non_music => 'تخطي المقاطع غير الموسيقية (SponsorBlock)';

  @override
  String get blacklist_description =>
      'المقطوعات والفنانون المدرجون في القائمة السوداء';

  @override
  String get wait_for_download_to_finish =>
      'يرجى الانتظار حتى انتهاء التنزيل الحالي';

  @override
  String get desktop => 'سطح المكتب';

  @override
  String get close_behavior => 'إغلاق التصرف';

  @override
  String get close => 'إغلاق';

  @override
  String get minimize_to_tray => 'تصغير إلى الدرج';

  @override
  String get show_tray_icon => 'إظهار أيقونات درج النظام';

  @override
  String get about => 'حول';

  @override
  String get u_love_spotube => 'نحن نعلم أنك تحب Spotube';

  @override
  String get check_for_updates => 'تحقق من وجود تحديثات';

  @override
  String get about_spotube => 'حول Spotube';

  @override
  String get blacklist => 'قائمة سوداء';

  @override
  String get please_sponsor => 'يرجى دعم/التبرع';

  @override
  String get spotube_description =>
      'Spotube، عميل Spotify خفيف الوزن ومتعدد المنصات ومجاني للجميع';

  @override
  String get version => 'إصدار';

  @override
  String get build_number => 'رقم البنية';

  @override
  String get founder => 'الموئسس';

  @override
  String get repository => 'المستودع';

  @override
  String get bug_issues => 'أخطاء+مشاكل';

  @override
  String get made_with => 'صُنع باستخدام ❤️ في بنغلاديش🇧🇩';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return '© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'الترخيص';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'لا تقلق، لن يتم جمع أي من بيانات الخاصة بك أو مشاركتها مع أي شخص';

  @override
  String get know_how_to_login => 'لا تعرف كيف تفعل هذا؟';

  @override
  String get follow_step_by_step_guide => 'اتبع الدليل خطوة بخطوة';

  @override
  String cookie_name_cookie(Object name) {
    return '$name كوكيز';
  }

  @override
  String get fill_in_all_fields => 'يرجى تعبئة جميع الحقول';

  @override
  String get submit => 'إرسال';

  @override
  String get exit => 'خروج';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get done => 'تم';

  @override
  String get step_1 => 'الخطوة 1';

  @override
  String get first_go_to => 'أولا، اذهب إلى';

  @override
  String get something_went_wrong => 'هناك خطأ ما';

  @override
  String get piped_instance => 'مثيل خادم Piped';

  @override
  String get piped_description =>
      'مثيل خادم Piped الذي سيتم استخدامه لمطابقة المقطوعة';

  @override
  String get piped_warning =>
      'البعض منهم قد لا يعمل بشكل جيد. لذلك استخدمه على مسؤوليتك';

  @override
  String get invidious_instance => 'مثيل خادم Invidious';

  @override
  String get invidious_description =>
      'مثيل خادم Invidious المستخدم لمطابقة المسارات';

  @override
  String get invidious_warning =>
      'قد لا تعمل بعض الخوادم بشكل جيد. استخدمها على مسؤوليتك الخاصة';

  @override
  String get generate => 'إنشاء';

  @override
  String track_exists(Object track) {
    return 'المقطوعة $track بالفعل موجودة';
  }

  @override
  String get replace_downloaded_tracks =>
      'استبدل جميع المقطوعات التي تم تنزيلها';

  @override
  String get skip_download_tracks =>
      'تخطي تنزيل كافة المقطوعات التي تم تنزيلها';

  @override
  String get do_you_want_to_replace => 'هل تريد استبدال المقطوعة الحالية؟';

  @override
  String get replace => 'إستبدال';

  @override
  String get skip => 'تخطي';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'إختر ما يصل إلى $count $type';
  }

  @override
  String get select_genres => 'حدد الأنواع';

  @override
  String get add_genres => 'أضف الأنواع';

  @override
  String get country => 'دولة';

  @override
  String get number_of_tracks_generate =>
      'عدد المسارات المقطوعات المراد توليدها';

  @override
  String get acousticness => 'صوتية';

  @override
  String get danceability => 'قدرة على الرقص';

  @override
  String get energy => 'طاقة';

  @override
  String get instrumentalness => 'نفعية';

  @override
  String get liveness => 'حيوية';

  @override
  String get loudness => 'بريق';

  @override
  String get speechiness => 'كلام';

  @override
  String get valence => 'تكافؤ';

  @override
  String get popularity => 'شعبية';

  @override
  String get key => 'مفتاح';

  @override
  String get duration => 'مدة (s)';

  @override
  String get tempo => 'Tempo (BPM)';

  @override
  String get mode => 'Mode';

  @override
  String get time_signature => 'توقيع الوقت';

  @override
  String get short => 'قصير';

  @override
  String get medium => 'متوسط';

  @override
  String get long => 'طويل';

  @override
  String get min => 'أدنى';

  @override
  String get max => 'أقصى';

  @override
  String get target => 'هدف';

  @override
  String get moderate => 'معتدل';

  @override
  String get deselect_all => 'الغاء تحديد الكل';

  @override
  String get select_all => 'اختر الكل';

  @override
  String get are_you_sure => 'هل أنت متأكد؟';

  @override
  String get generating_playlist => 'جارٍ إنشاء قائمة التشغيل المخصصة...';

  @override
  String selected_count_tracks(Object count) {
    return 'مقطوعات $count مختارة';
  }

  @override
  String get download_warning =>
      'إذا قمت بتنزيل جميع المقاطع الصوتية بكميات كبيرة، فمن الواضح أنك تقوم بقرصنة الموسيقى وتسبب الضرر للمجتمع الإبداعي للموسيقى. أتمنى أن تكون على علم بهذا. حاول دائمًا احترام ودعم العمل الجاد للفنان';

  @override
  String get download_ip_ban_warning =>
      'بالمناسبة، يمكن أن يتم حظر عنوان IP الخاص بك على YouTube بسبب طلبات التنزيل الزائدة عن المعتاد. يعني حظر IP أنه لا يمكنك استخدام YouTube (حتى إذا قمت بتسجيل الدخول) لمدة تتراوح بين شهرين إلى ثلاثة أشهر على الأقل من جهاز IP هذا. ولا يتحمل Spotube أي مسؤولية إذا حدث هذا على الإطلاق';

  @override
  String get by_clicking_accept_terms =>
      'بالنقر على \"قبول\"، فإنك توافق على الشروط التالية:';

  @override
  String get download_agreement_1 => 'أعلم أنني أقوم بقرصنة الموسيقى. انا سيئ';

  @override
  String get download_agreement_2 =>
      'سأدعم الفنان أينما أستطيع، وأنا أفعل هذا فقط لأنني لا أملك المال لشراء أعمالهم الفنية';

  @override
  String get download_agreement_3 =>
      'أدرك تمامًا أنه يمكن حظر عنوان IP الخاص بي على YouTube ولا أحمل Spotube أو مالكيه/مساهميه المسؤولية عن أي حوادث ناجمة عن الإجراء الحالي الخاص بي';

  @override
  String get decline => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get details => 'تفاصيل';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'قناة';

  @override
  String get likes => 'إعجابات';

  @override
  String get dislikes => 'عدم الإعجابات';

  @override
  String get views => 'مشاهدات';

  @override
  String get streamUrl => 'عنوان URL البث';

  @override
  String get stop => 'إيقاف';

  @override
  String get sort_newest => 'الترتيب حسب الأقدم';

  @override
  String get sort_oldest => 'الترتيب حسب الأقدم';

  @override
  String get sleep_timer => 'مؤقت النوم';

  @override
  String mins(Object minutes) {
    return '$minutes دقائق';
  }

  @override
  String hours(Object hours) {
    return '$hours ساعات';
  }

  @override
  String hour(Object hours) {
    return '$hours ساعة';
  }

  @override
  String get custom_hours => 'ساعات مخصصة';

  @override
  String get logs => 'سجلات';

  @override
  String get developers => 'المطورون';

  @override
  String get not_logged_in => 'لم تقم بتسجيل الدخول';

  @override
  String get search_mode => 'وضع البحث';

  @override
  String get audio_source => 'مصدر الصوت';

  @override
  String get ok => 'حسسناً';

  @override
  String get failed_to_encrypt => 'فشل في التشفير';

  @override
  String get encryption_failed_warning =>
      'يستخدم Spotube التشفير لتخزين بياناتك بشكل آمن. لكنها فشلت في القيام بذلك. لذلك سيعود الأمر إلى التخزين غير الآمن\nإذا كنت تستخدم Linux، فيرجى التأكد من تثبيت أي خدمة سرية (gnome-keyring، kde-wallet، keepassxc، إلخ)';

  @override
  String get querying_info => 'جارٍ الاستعلام عن معلومات...';

  @override
  String get piped_api_down => 'Piped API معطلة';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'المثيل الموجه $pipedInstance معطل حاليًا\n\nيمكنك إما تغيير المثيل أو تغيير \'نوع API\' إلى YouTube API الرسمي\n\nتأكد من إعادة تشغيل التطبيق بعد التغيير';
  }

  @override
  String get you_are_offline => 'أنت غير متصل حالياً';

  @override
  String get connection_restored => 'تمت استعادة اتصالك بالإنترنت';

  @override
  String get use_system_title_bar => 'استخدم شريط عنوان النظام';

  @override
  String get crunching_results => 'تدمير النتائج';

  @override
  String get search_to_get_results => 'إبحث للحصول على النتائج';

  @override
  String get use_amoled_mode => 'استخدم وضع AMOLED';

  @override
  String get pitch_dark_theme => 'موضوع دارت الأسود الفحمي';

  @override
  String get normalize_audio => 'تطبيع الصوت';

  @override
  String get change_cover => 'تغيير الغلاف';

  @override
  String get add_cover => 'إضافة غلاف';

  @override
  String get restore_defaults => 'استعادة الإعدادات الافتراضية';

  @override
  String get download_music_format => 'تنسيق تنزيل الموسيقى';

  @override
  String get streaming_music_format => 'تنسيق بث الموسيقى';

  @override
  String get download_music_quality => 'جودة تنزيل الموسيقى';

  @override
  String get streaming_music_quality => 'جودة بث الموسيقى';

  @override
  String get login_with_lastfm => 'تسجيل الدخول باستخدام Last.fm';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect_lastfm => 'قطع الاتصال بـ Last.fm';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get login_with_your_lastfm =>
      'تسجيل الدخول باستخدام حساب Last.fm الخاص بك';

  @override
  String get scrobble_to_lastfm => 'تسجيل الاستماع على Last.fm';

  @override
  String get go_to_album => 'الانتقال إلى الألبوم';

  @override
  String get discord_rich_presence => 'وجود ديسكورد الغني';

  @override
  String get browse_all => 'تصفح الكل';

  @override
  String get genres => 'الأنواع الموسيقية';

  @override
  String get explore_genres => 'استكشاف الأنواع';

  @override
  String get friends => 'أصدقاء';

  @override
  String get no_lyrics_available =>
      'عذرًا، تعذر العثور على كلمات الأغنية لهذه العنصر';

  @override
  String get start_a_radio => 'بدء راديو';

  @override
  String get how_to_start_radio => 'كيف تريد بدء الراديو؟';

  @override
  String get replace_queue_question =>
      'هل تريد استبدال قائمة التشغيل الحالية أم إضافة إليها؟';

  @override
  String get endless_playback => 'تشغيل بلا نهاية';

  @override
  String get delete_playlist => 'حذف قائمة التشغيل';

  @override
  String get delete_playlist_confirmation =>
      'هل أنت متأكد أنك تريد حذف هذه قائمة التشغيل؟';

  @override
  String get local_tracks => 'المسارات المحلية';

  @override
  String get local_tab => 'محلي';

  @override
  String get song_link => 'رابط الأغنية';

  @override
  String get skip_this_nonsense => 'تخطي هذه الهراء';

  @override
  String get freedom_of_music => '“حرية الموسيقى”';

  @override
  String get freedom_of_music_palm => '“حرية الموسيقى في متناول يدك”';

  @override
  String get get_started => 'لنبدأ';

  @override
  String get youtube_source_description => 'موصى به ويعمل بشكل أفضل.';

  @override
  String get piped_source_description =>
      'تشعر بالحرية؟ نفس يوتيوب ولكن أكثر حرية.';

  @override
  String get jiosaavn_source_description => 'الأفضل لمنطقة جنوب آسيا.';

  @override
  String get invidious_source_description => 'مشابه لـ Piped ولكن بتوافر أعلى';

  @override
  String highest_quality(Object quality) {
    return 'أعلى جودة: $quality';
  }

  @override
  String get select_audio_source => 'اختر مصدر الصوت';

  @override
  String get endless_playback_description =>
      'إلحاق الأغاني الجديدة تلقائيًا\nإلى نهاية قائمة التشغيل';

  @override
  String get choose_your_region => 'اختر منطقتك';

  @override
  String get choose_your_region_description =>
      'سيساعدك هذا في عرض المحتوى المناسب\nلموقعك.';

  @override
  String get choose_your_language => 'اختر لغتك';

  @override
  String get help_project_grow => 'ساعد في نمو هذا المشروع';

  @override
  String get help_project_grow_description =>
      'Spotube هو مشروع مفتوح المصدر. يمكنك مساعدة هذا المشروع في النمو عن طريق المساهمة في المشروع، أو الإبلاغ عن الأخطاء، أو اقتراح ميزات جديدة.';

  @override
  String get contribute_on_github => 'المساهمة على GitHub';

  @override
  String get donate_on_open_collective => 'التبرع على Open Collective';

  @override
  String get browse_anonymously => 'تصفح بشكل مجهول';

  @override
  String get enable_connect => 'تمكين الاتصال';

  @override
  String get enable_connect_description =>
      'التحكم في Spotube من الأجهزة الأخرى';

  @override
  String get devices => 'الأجهزة';

  @override
  String get select => 'اختر';

  @override
  String connect_client_alert(Object client) {
    return 'أنت تتم التحكم بواسطة $client';
  }

  @override
  String get this_device => 'هذا الجهاز';

  @override
  String get remote => 'بعيد';

  @override
  String get stats => 'إحصائيات';

  @override
  String and_n_more(Object count) {
    return 'و $count أكثر';
  }

  @override
  String get recently_played => 'تم تشغيله مؤخرًا';

  @override
  String get browse_more => 'تصفح المزيد';

  @override
  String get no_title => 'بدون عنوان';

  @override
  String get not_playing => 'غير مشغل';

  @override
  String get epic_failure => 'فشل كبير!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return 'تمت إضافة $tracks_length مسارات إلى قائمة الانتظار';
  }

  @override
  String get spotube_has_an_update => 'يوجد تحديث لسبوتيوب';

  @override
  String get download_now => 'تحميل الآن';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'تم إصدار سبوتيوب الليلي $nightlyBuildNum';
  }

  @override
  String release_version(Object version) {
    return 'تم إصدار سبوتيوب v$version';
  }

  @override
  String get read_the_latest => 'اقرأ الأحدث';

  @override
  String get release_notes => 'ملاحظات الإصدار';

  @override
  String get pick_color_scheme => 'اختر نظام الألوان';

  @override
  String get save => 'حفظ';

  @override
  String get choose_the_device => 'اختر الجهاز:';

  @override
  String get multiple_device_connected =>
      'تم توصيل أجهزة متعددة.\nاختر الجهاز الذي تريد إجراء هذه العملية عليه';

  @override
  String get nothing_found => 'لم يتم العثور على شيء';

  @override
  String get the_box_is_empty => 'الصندوق فارغ';

  @override
  String get top_artists => 'أفضل الفنانين';

  @override
  String get top_albums => 'أفضل الألبومات';

  @override
  String get this_week => 'هذا الأسبوع';

  @override
  String get this_month => 'هذا الشهر';

  @override
  String get last_6_months => 'آخر 6 أشهر';

  @override
  String get this_year => 'هذا العام';

  @override
  String get last_2_years => 'آخر سنتين';

  @override
  String get all_time => 'كل الوقت';

  @override
  String powered_by_provider(Object providerName) {
    return 'مدعوم من $providerName';
  }

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get profile_followers => 'المتابعين';

  @override
  String get birthday => 'عيد الميلاد';

  @override
  String get subscription => 'اشتراك';

  @override
  String get not_born => 'لم يولد';

  @override
  String get hacker => 'هاكر';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get no_name => 'بدون اسم';

  @override
  String get edit => 'تعديل';

  @override
  String get user_profile => 'ملف المستخدم';

  @override
  String count_plays(Object count) {
    return '$count تشغيلات';
  }

  @override
  String get streaming_fees_hypothetical => 'رسوم البث (افتراضية)';

  @override
  String get minutes_listened => 'الدقائق المستمعة';

  @override
  String get streamed_songs => 'الأغاني المذاعة';

  @override
  String count_streams(Object count) {
    return '$count بث';
  }

  @override
  String get owned_by_you => 'مملوك لك';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return 'تم نسخ $shareUrl إلى الحافظة';
  }

  @override
  String get hipotetical_calculation =>
      '*تمّ الحساب بمعدّل دفعة تتراوح بين 0.003–0.005 دولار أمريكي لكل تشغيل على منصات الموسيقى عبر الإنترنت. هذا حساب افتراضي لتوضيح للمستخدم مقدار ما كان سيدفعه للفنانين لو استمع إلى أغنيتهم على منصات مختلفة.';

  @override
  String count_mins(Object minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get summary_minutes => 'الدقائق';

  @override
  String get summary_listened_to_music => 'استمعت إلى الموسيقى';

  @override
  String get summary_songs => 'أغاني';

  @override
  String get summary_streamed_overall => 'بث بشكل عام';

  @override
  String get summary_owed_to_artists => 'مدين للفنانين\nهذا الشهر';

  @override
  String get summary_artists => 'الفنانين';

  @override
  String get summary_music_reached_you => 'وصلت إليك الموسيقى';

  @override
  String get summary_full_albums => 'ألبومات كاملة';

  @override
  String get summary_got_your_love => 'حصلت على حبك';

  @override
  String get summary_playlists => 'قوائم التشغيل';

  @override
  String get summary_were_on_repeat => 'كانت على التكرار';

  @override
  String total_money(Object money) {
    return 'المجموع $money';
  }

  @override
  String get webview_not_found => 'لم يتم العثور على Webview';

  @override
  String get webview_not_found_description =>
      'لم يتم تثبيت بيئة تشغيل Webview على جهازك.\nإذا كانت مثبتة، تأكد من وجودها في environment PATH\n\nبعد التثبيت، أعد تشغيل التطبيق';

  @override
  String get unsupported_platform => 'المنصة غير مدعومة';

  @override
  String get cache_music => 'تخزين الموسيقى مؤقتًا';

  @override
  String get open => 'فتح';

  @override
  String get cache_folder => 'مجلد التخزين المؤقت';

  @override
  String get export => 'تصدير';

  @override
  String get clear_cache => 'مسح التخزين المؤقت';

  @override
  String get clear_cache_confirmation => 'هل تريد مسح التخزين المؤقت؟';

  @override
  String get export_cache_files => 'تصدير الملفات المخزنة مؤقتًا';

  @override
  String found_n_files(Object count) {
    return 'تم العثور على $count ملف';
  }

  @override
  String get export_cache_confirmation => 'هل تريد تصدير هذه الملفات إلى';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return 'تم تصدير $filesExported من أصل $files ملفات';
  }

  @override
  String get undo => 'تراجع';

  @override
  String get download_all => 'تنزيل الكل';

  @override
  String get add_all_to_playlist => 'إضافة الكل إلى قائمة التشغيل';

  @override
  String get add_all_to_queue => 'إضافة الكل إلى القائمة';

  @override
  String get play_all_next => 'تشغيل الكل بعد ذلك';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get view_all => 'عرض الكل';

  @override
  String get no_tracks_added_yet => 'يبدو أنك لم تضف أي مسارات بعد';

  @override
  String get no_tracks => 'يبدو أنه لا يوجد أي مسارات هنا';

  @override
  String get no_tracks_listened_yet => 'يبدو أنك لم تستمع إلى أي شيء بعد';

  @override
  String get not_following_artists => 'أنت لا تتابع أي فنانين';

  @override
  String get no_favorite_albums_yet =>
      'يبدو أنك لم تضف أي ألبومات إلى المفضلة بعد';

  @override
  String get no_logs_found => 'لم يتم العثور على سجلات';

  @override
  String get youtube_engine => 'محرك يوتيوب';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine غير مثبت';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine غير مثبت في نظامك.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'تأكد من أنه متاح في متغير PATH أو\nحدد المسار الكامل للملف القابل للتنفيذ $engine أدناه';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'في أنظمة macOS/Linux/Unix مثل الأنظمة، لن يعمل تعيين المسار في .zshrc/.bashrc/.bash_profile وما إلى ذلك.\nيجب تعيين المسار في ملف تكوين الصدفة';

  @override
  String get download => 'تنزيل';

  @override
  String get file_not_found => 'الملف غير موجود';

  @override
  String get custom => 'مخصص';

  @override
  String get add_custom_url => 'إضافة URL مخصص';

  @override
  String get edit_port => 'تعديل المنفذ';

  @override
  String get port_helper_msg =>
      'القيمة الافتراضية هي -1 والتي تشير إلى رقم عشوائي. إذا كان لديك جدار ناري مُعد، يُوصى بتعيين هذا.';

  @override
  String connect_request(Object client) {
    return 'السماح لـ $client بالاتصال؟';
  }

  @override
  String get connection_request_denied =>
      'تم رفض الاتصال. المستخدم رفض الوصول.';

  @override
  String get an_error_occurred => 'حدث خطأ';

  @override
  String get copy_to_clipboard => 'نسخ إلى الحافظة';

  @override
  String get view_logs => 'عرض السجلات';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get no_default_metadata_provider_selected =>
      'لم تقُم بتعيين مزود بيانات افتراضي';

  @override
  String get manage_metadata_providers => 'إدارة مزوّدي البيانات';

  @override
  String get open_link_in_browser => 'فتح الرابط في المتصفح؟';

  @override
  String get do_you_want_to_open_the_following_link =>
      'هل ترغب في فتح الرابط التالي؟';

  @override
  String get unsafe_url_warning =>
      'قد يكون فتح الروابط من مصادر غير موثوقة غير آمن. تحرّ الحذر!\nيمكنك أيضًا نسخ الرابط إلى الحافظة.';

  @override
  String get copy_link => 'نسخ الرابط';

  @override
  String get building_your_timeline =>
      'جاري بناء المخطط الزمني استنادًا إلى استماعاتك...';

  @override
  String get official => 'رسمي';

  @override
  String author_name(Object author) {
    return 'المؤلّف: $author';
  }

  @override
  String get third_party => 'طرف ثالث';

  @override
  String get plugin_requires_authentication => 'تتطلّب الإضافة تسجيل الدخول';

  @override
  String get update_available => 'تحديث متوفر';

  @override
  String get supports_scrobbling => 'يدعم التتبع (scrobbling)';

  @override
  String get plugin_scrobbling_info =>
      'تقوم هذه الإضافة بتتبع مقاطعك الموسيقية لإنشاء سجل الاستماع الخاص بك.';

  @override
  String get default_metadata_source => 'مصدر البيانات الوصفية الافتراضي';

  @override
  String get set_default_metadata_source =>
      'تعيين مصدر البيانات الوصفية الافتراضي';

  @override
  String get default_audio_source => 'مصدر الصوت الافتراضي';

  @override
  String get set_default_audio_source => 'تعيين مصدر الصوت الافتراضي';

  @override
  String get set_default => 'تعيين كافتراضي';

  @override
  String get support => 'الدعم';

  @override
  String get support_plugin_development => 'دعم تطوير الإضافات';

  @override
  String can_access_name_api(Object name) {
    return '- يمكن الوصول إلى واجهة برمجة التطبيقات **$name**';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'هل ترغب في تثبيت هذه الإضافة؟';

  @override
  String get third_party_plugin_warning =>
      'هذه الإضافة من مستودع طرف ثالث. تأكد من موثوقية المصدر قبل التثبيت.';

  @override
  String get author => 'المؤلف';

  @override
  String get this_plugin_can_do_following => 'يمكن لهذه الإضافة القيام بما يلي';

  @override
  String get install => 'تثبيت';

  @override
  String get install_a_metadata_provider => 'تثبيت مزوّد بيانات';

  @override
  String get no_tracks_playing => 'لا توجد مقاطع تعمل حاليًا';

  @override
  String get synced_lyrics_not_available =>
      'الكلمات المتزامنة غير متوفرة لهذه الأغنية. يُرجى استخدام';

  @override
  String get plain_lyrics => 'الكلمات العادية';

  @override
  String get tab_instead => 'بدلاً من ذلك، استخدم التبويب.';

  @override
  String get disclaimer => 'إخلاء المسؤولية';

  @override
  String get third_party_plugin_dmca_notice =>
      'لا تتحمّل فريق Spotube أي مسؤولية (بما في ذلك القانونية) عن أي من الإضافات “لطرف ثالث”.\nاستخدمها على مسؤوليتك الخاصّة. لأيّة أخطاء/مشكلات، يُرجى الإبلاغ عنها في مستودع الإضافة.\n\nإذا كانت أي إضافة “لطرف ثالث” تنتهك شروط الخدمة أو قانون DMCA الخاص بأي خدمة أو كيان قانوني، فيُرجى طلب اتخاذ إجراء من مؤلف الإضافة أو منصة الاستضافة مثل GitHub/Codeberg. الإضافات المدرجة كـ “لطرف ثالث” هي مفعّلة ومُدارة من المجتمع، وليس لدينا صلاحية إدارتها أو التدخل فيها.\n\n';

  @override
  String get input_does_not_match_format =>
      'المدخل لا يتوافق مع التنسيق المطلوب';

  @override
  String get plugins => 'الإضافات';

  @override
  String get paste_plugin_download_url =>
      'الصق رابط التنزيل أو GitHub/Codeberg أو رابط مباشر لملف .smplug';

  @override
  String get download_and_install_plugin_from_url =>
      'تنزيل وتثبيت الإضافة من رابط';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'فشل في إضافة الإضافة: $error';
  }

  @override
  String get upload_plugin_from_file => 'رفع الإضافة من ملف';

  @override
  String get installed => 'تم التثبيت';

  @override
  String get available_plugins => 'الإضافات المتوفّرة';

  @override
  String get configure_plugins =>
      'قم بتكوين مزود البيانات الوصفية ومكونات مصدر الصوت الخاصة بك';

  @override
  String get audio_scrobblers => 'أجهزة تتبع الصوت';

  @override
  String get scrobbling => 'التتبع';

  @override
  String get source => 'المصدر: ';

  @override
  String get uncompressed => 'غير مضغوط';

  @override
  String get dab_music_source_description =>
      'لمحبي الصوتيات. يوفر تدفقات صوتية عالية الجودة/بدون فقدان. مطابقة دقيقة للمسارات بناءً على ISRC.';
}
