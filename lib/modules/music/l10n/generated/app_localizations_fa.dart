// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get guest => 'مهمان';

  @override
  String get browse => 'مرور';

  @override
  String get search => 'جستجو';

  @override
  String get library => 'مجموعه';

  @override
  String get lyrics => 'متن';

  @override
  String get settings => 'تنظیمات';

  @override
  String get genre_categories_filter => 'دسته ها یا ژانر ها را فیلتر کنید';

  @override
  String get genre => 'ژانر';

  @override
  String get personalized => ' شخصی سازی شده';

  @override
  String get featured => 'ویژه';

  @override
  String get new_releases => 'آخرین انتشارات';

  @override
  String get songs => 'آهنگ ها';

  @override
  String playing_track(Object track) {
    return 'درحال پخش $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'با این کار صف فعلی پاک می شود. $track_length آهنگ از صف حذف میشود\n؟آیا ادامه میدهید';
  }

  @override
  String get load_more => 'بارگذاری بیشتر';

  @override
  String get playlists => 'لیست های پخش';

  @override
  String get artists => 'هنرمندان';

  @override
  String get albums => 'آلبوم ها';

  @override
  String get tracks => 'آهنگ ها';

  @override
  String get downloads => 'بارگیری شده ها';

  @override
  String get filter_playlists => 'لیست پخش خود را فیلتر کنید...';

  @override
  String get liked_tracks => 'آهنگ های مورد علاقه';

  @override
  String get liked_tracks_description => 'همه آهنگ های دوست داشتنی شما';

  @override
  String get playlist => 'لیست پخش';

  @override
  String get create_a_playlist => 'ساخت لیست پخش';

  @override
  String get update_playlist => 'بروز کردن لیست پخش';

  @override
  String get create => 'ساختن';

  @override
  String get cancel => 'لغو';

  @override
  String get update => 'بروز رسانی';

  @override
  String get playlist_name => 'نام لیست پخش';

  @override
  String get name_of_playlist => 'نام لیست پخش';

  @override
  String get description => 'توضیحات';

  @override
  String get public => 'عمومی';

  @override
  String get collaborative => 'مبتنی بر همکاری';

  @override
  String get search_local_tracks => 'جستجوی آهنگ های محلی...';

  @override
  String get play => 'پخش';

  @override
  String get delete => 'حذف';

  @override
  String get none => 'هیچ کدام';

  @override
  String get sort_a_z => 'مرتب سازی بر اساس حروف الفبا';

  @override
  String get sort_z_a => 'مرتب سازی برعکس حروف الفبا';

  @override
  String get sort_artist => 'مرتب سازی بر اساس هنرمند';

  @override
  String get sort_album => 'مرتب سازی بر اساس آلبوم';

  @override
  String get sort_duration => 'مرتب کردن بر اساس مدت زمان';

  @override
  String get sort_tracks => 'مرتب سازی آهنگ ها';

  @override
  String currently_downloading(Object tracks_length) {
    return 'در حال بارگیری ($tracks_length)';
  }

  @override
  String get cancel_all => 'لغو همه';

  @override
  String get refresh => 'Refresh';

  @override
  String get filter_artist => 'فیلتر کردن هنرمند...';

  @override
  String followers(Object followers) {
    return '$followers دنبال کننده';
  }

  @override
  String get add_artist_to_blacklist => 'اضافه کردن هنرمند به لیست سیاه';

  @override
  String get top_tracks => 'بهترین آهنگ ها';

  @override
  String get fans_also_like => 'طرفداران هم دوست داشتند';

  @override
  String get loading => 'بارگزاری...';

  @override
  String get artist => 'هنرمند';

  @override
  String get blacklisted => 'در لیست سیاه قرار گرفته است';

  @override
  String get following => 'دنبال کننده';

  @override
  String get follow => 'دنبال کردن';

  @override
  String get artist_url_copied => 'لینک هنرمند در کلیپ بورد کپی شد';

  @override
  String added_to_queue(Object tracks) {
    return 'تعداد $tracks آهنگ به صف اضافه شد';
  }

  @override
  String get filter_albums => 'فیلتر کردن آلبوم...';

  @override
  String get synced => 'همگام سازی شد';

  @override
  String get plain => 'ساده';

  @override
  String get shuffle => 'تصادفی';

  @override
  String get search_tracks => 'جستجوی آهنگ ها...';

  @override
  String get released => 'منتشر شده';

  @override
  String error(Object error) {
    return 'خطا $error';
  }

  @override
  String get title => 'عنوان';

  @override
  String get time => 'زمان';

  @override
  String get more_actions => 'اقدامات بیشتر';

  @override
  String download_count(Object count) {
    return 'دانلود ($count)';
  }

  @override
  String add_count_to_playlist(Object count) {
    return 'اضافه کردن ($count) به لیست پخش';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'اضافه کردن ($count) به صف';
  }

  @override
  String play_count_next(Object count) {
    return 'پخش ($count) بعدی';
  }

  @override
  String get album => 'آلبوم';

  @override
  String copied_to_clipboard(Object data) {
    return '$data در کلیپ بورد کپی شد';
  }

  @override
  String add_to_following_playlists(Object track) {
    return 'اضافه کردن $track به لیست پخش زیر';
  }

  @override
  String get add => 'اضافه کردن';

  @override
  String added_track_to_queue(Object track) {
    return '$track به لیست پخش اضافه شد';
  }

  @override
  String get add_to_queue => 'اضافه کردن به صف';

  @override
  String track_will_play_next(Object track) {
    return '$track پخش خواهد شد';
  }

  @override
  String get play_next => 'پخش آهنگ بعدی';

  @override
  String removed_track_from_queue(Object track) {
    return '$track از لیست پخش حذف شد';
  }

  @override
  String get remove_from_queue => 'از لیست پخش حذف شد';

  @override
  String get remove_from_favorites => 'از علاقمندی ها حدف شد';

  @override
  String get save_as_favorite => 'ذخیره به عنوان علاقمندی ها';

  @override
  String get add_to_playlist => 'به لیست پخش اضافه کردن';

  @override
  String get remove_from_playlist => 'از لیست پخش حذف کردن';

  @override
  String get add_to_blacklist => 'به لیست سیاه اضافه کردن';

  @override
  String get remove_from_blacklist => 'از لیست سیاه حذف کردن';

  @override
  String get share => 'اشتراک گذاری';

  @override
  String get mini_player => 'پخش کننده ';

  @override
  String get slide_to_seek => 'برای جستجو عقب یا جلو بکشید';

  @override
  String get shuffle_playlist => 'پخش تصادفی';

  @override
  String get unshuffle_playlist => 'خاموش کردن پخش تصادفی';

  @override
  String get previous_track => 'آهنگ قبلی';

  @override
  String get next_track => 'آهنگ بعدی';

  @override
  String get pause_playback => 'توقف آهنگ';

  @override
  String get resume_playback => 'ادامه آهنگ';

  @override
  String get loop_track => 'تکرار آهنگ';

  @override
  String get no_loop => 'بدون حلقه';

  @override
  String get repeat_playlist => 'تکرار لیست پخش';

  @override
  String get queue => 'صف';

  @override
  String get alternative_track_sources => ' منبع آهنگ را جاگزین کردن ';

  @override
  String get download_track => 'بارگیری آهنگ';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks آهنگ در صف';
  }

  @override
  String get clear_all => 'همه را حدف کن';

  @override
  String get show_hide_ui_on_hover => 'نمایش/پنهان رابط کاربری در حالت شناور';

  @override
  String get always_on_top => 'همیشه روشن';

  @override
  String get exit_mini_player => 'از پخش کننده خارج شوید';

  @override
  String get download_location => 'محل بارگیری';

  @override
  String get local_library => 'کتابخانه محلی';

  @override
  String get add_library_location => 'اضافه کردن به کتابخانه';

  @override
  String get remove_library_location => 'حذف از کتابخانه';

  @override
  String get account => 'حساب کاربری';

  @override
  String get logout => 'خارج شدن';

  @override
  String get logout_of_this_account => 'از حساب کاربری خارج شوید';

  @override
  String get language_region => 'زبان و منطقه ';

  @override
  String get language => 'زبان ';

  @override
  String get system_default => 'پیش فرض سیستم';

  @override
  String get market_place_region => 'منطقه';

  @override
  String get recommendation_country => 'کشور های پیشنهادی';

  @override
  String get appearance => 'ظاهر';

  @override
  String get layout_mode => 'حالت چیدمان';

  @override
  String get override_layout_settings =>
      'تنطیمات حالت واکنشگرای چیدمان را لغو کن';

  @override
  String get adaptive => 'قابل تطبیق';

  @override
  String get compact => 'فشرده';

  @override
  String get extended => 'گسترده';

  @override
  String get theme => 'تم';

  @override
  String get dark => 'تاریک';

  @override
  String get light => 'روشن';

  @override
  String get system => 'سیستم';

  @override
  String get accent_color => 'رنگ تاکیدی';

  @override
  String get sync_album_color => 'هنگام سازی رنگ البوم';

  @override
  String get sync_album_color_description =>
      'از رنگ البوم هنرمند به عنوان رنگ تاکیدی استفاده میکند';

  @override
  String get playback => 'پخش';

  @override
  String get audio_quality => 'کیفیت صدا';

  @override
  String get high => 'زیاد';

  @override
  String get low => 'کم';

  @override
  String get pre_download_play => 'دانلود و پخش کنید';

  @override
  String get pre_download_play_description =>
      'به جای پخش جریانی صدا، بایت ها را دانلود کنید و به جای آن پخش کنید (برای کاربران با پهنای باند بالاتر توصیه می شود)';

  @override
  String get skip_non_music => 'رد شدن از پخش های غیر موسیقی (SponsorBlock)';

  @override
  String get blacklist_description => 'آهنگ ها و هنرمند های در لیست سیاه';

  @override
  String get wait_for_download_to_finish =>
      'لطفا صبر کنید تا دانلود آهنگ جاری تمام شود';

  @override
  String get desktop => 'میز کار';

  @override
  String get close_behavior => 'رفتار نزدیک';

  @override
  String get close => 'بستن';

  @override
  String get minimize_to_tray => 'پتجره را کوچک کنید';

  @override
  String get show_tray_icon => 'نماد را نمایش بده';

  @override
  String get about => 'درباره';

  @override
  String get u_love_spotube => 'دوست داریدSpotubeما میدانیم شما ';

  @override
  String get check_for_updates => 'بروزرسانی را بررسی کنید';

  @override
  String get about_spotube => 'Spotube درباره';

  @override
  String get blacklist => 'لیست سیاه';

  @override
  String get please_sponsor => 'لطفا کمک/حمایت کنید';

  @override
  String get spotube_description =>
      'یک برنامه سبک و مولتی پلتفرم و رایگان برای همه استSpotube';

  @override
  String get version => 'نسخه';

  @override
  String get build_number => 'شماره ساخت';

  @override
  String get founder => 'بنیانگذار';

  @override
  String get repository => 'مخزن';

  @override
  String get bug_issues => 'اشکال+مسایل';

  @override
  String get made_with => '🇧🇩ساخته شده با ❤️ در بنگلادش';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return '© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'مجوز';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'نگران نباشید هیچ کدوما از اعتبارات شما جمع اوری نمیشود یا با کسی اشتراک گزاشته نمیشود';

  @override
  String get know_how_to_login => 'نمیدانی چگونه این کار را انجام بدهی؟';

  @override
  String get follow_step_by_step_guide => 'راهنما را گام به گام دنبال کنید';

  @override
  String cookie_name_cookie(Object name) {
    return '$name کوکی';
  }

  @override
  String get fill_in_all_fields => 'لطفا تمام فلید ها را پر کنید';

  @override
  String get submit => 'ثبت';

  @override
  String get exit => 'خروج';

  @override
  String get previous => 'قبلی';

  @override
  String get next => 'بعدی ';

  @override
  String get done => 'اتمام';

  @override
  String get step_1 => 'گام 1';

  @override
  String get first_go_to => 'اول برو داخل ';

  @override
  String get something_went_wrong => 'اشتباهی رخ داده';

  @override
  String get piped_instance => 'مشکل در ارتباط با سرور';

  @override
  String get piped_description => 'مشکل در ارتباط با سرور در دریافت آهنگ ها';

  @override
  String get piped_warning =>
      'برخی از آنها ممکن است خوب کارنکند.بنابراین با مسولیت خود استفاده کنید';

  @override
  String get invidious_instance => 'نمونه سرور Invidious';

  @override
  String get invidious_description => 'نمونه سرور Invidious برای تطبیق آهنگ';

  @override
  String get invidious_warning =>
      'برخی از نمونه‌ها ممکن است به خوبی کار نکنند. با احتیاط استفاده کنید';

  @override
  String get generate => 'ایجاد';

  @override
  String track_exists(Object track) {
    return 'آهنگ $track وجود دارد';
  }

  @override
  String get replace_downloaded_tracks =>
      'همه ی آهنگ های دانلود شده را جایگزین کنید';

  @override
  String get skip_download_tracks => 'همه ی آهنگ های دانلود شده را رد کنید';

  @override
  String get do_you_want_to_replace =>
      'ایا میخواهید آهنگ های موجود جایگزین کنید؟';

  @override
  String get replace => 'جایگزین کردن';

  @override
  String get skip => 'رد کردن';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'انتخاب کنید تا $count $type';
  }

  @override
  String get select_genres => 'ژانر ها را انتخاب کنید';

  @override
  String get add_genres => 'ژانر را اطافه کنید';

  @override
  String get country => 'کشور';

  @override
  String get number_of_tracks_generate => 'تعداد آهنگ های ساخته شده';

  @override
  String get acousticness => 'آکوستیک';

  @override
  String get danceability => 'رقصیدن';

  @override
  String get energy => 'انرژی';

  @override
  String get instrumentalness => 'بی کلام';

  @override
  String get liveness => 'حس زندگی';

  @override
  String get loudness => 'صدای بلند';

  @override
  String get speechiness => 'دکلمه';

  @override
  String get valence => 'ظرفیت';

  @override
  String get popularity => 'محبوبیت';

  @override
  String get key => 'کلید';

  @override
  String get duration => 'مدت زمان (ثانیه)';

  @override
  String get tempo => 'تمپو (BPM)';

  @override
  String get mode => 'حالت';

  @override
  String get time_signature => 'امضای زمان';

  @override
  String get short => 'کوتاه';

  @override
  String get medium => 'متوسط';

  @override
  String get long => 'بلند';

  @override
  String get min => 'حداقل';

  @override
  String get max => 'حداکثر';

  @override
  String get target => 'هدف';

  @override
  String get moderate => 'حد وسط';

  @override
  String get deselect_all => 'همه را لغو انتخاب کنید';

  @override
  String get select_all => 'همه را انتخاب کنید';

  @override
  String get are_you_sure => 'ایا مطمعن هستید؟';

  @override
  String get generating_playlist => ' درحال ایجاد لیست پخش سفارشی شما';

  @override
  String selected_count_tracks(Object count) {
    return 'آهنگ انتخاب شده $count';
  }

  @override
  String get download_warning =>
      'اگر همه ی آهنگ ها را به صورت انبو دانلود کنید به وضوح در حال دزدی موسقی هستید و در حال اسیب وارد کردن به جامه ی خلاق هنری می باشید .امیدوارم که از این موضوع اگاه باشید .همیشه سعی کنید به کار سخت هنرمند اخترام بگذارید.';

  @override
  String get download_ip_ban_warning =>
      'راستی آی پی شما می تواند در یوتوب به دلیل درخواست های دانلود بیش از حد معمول مسدود شود. بلوک آی پی به این معنی است که شما نمی توانید از یوتوب (حتی اگر وارد سیستم شده باشید) حداقل 2-3 ماه از آن دستگاه آی پی استفاده کنید. و Spotube هیچ مسئولیتی در صورت وقوع این اتفاق ندارد';

  @override
  String get by_clicking_accept_terms =>
      'با کلیک بر روی قبول با شرایط زیر موافقت می کنید:';

  @override
  String get download_agreement_1 => 'من میدانم در حال دزدی هستم .من بد هستم';

  @override
  String get download_agreement_2 =>
      'من هر کجا ک بتوانم از هنرمندان حمایت میکنم اما این کارا فقط به دلیل اینکه توانایی مالی ندارم انجام میدهم';

  @override
  String get download_agreement_3 =>
      'من کاملا میدانم که از طرف یوتوب بلاک میشم و این برنامه و مالکان را مسول این حادثه نمیدانم.';

  @override
  String get decline => 'قبول نکردن';

  @override
  String get accept => 'قبول';

  @override
  String get details => 'جزئیات';

  @override
  String get youtube => 'یوتیوب';

  @override
  String get channel => 'کانال';

  @override
  String get likes => 'دوست داشتن';

  @override
  String get dislikes => 'دوست نداشتن';

  @override
  String get views => 'بازدید';

  @override
  String get streamUrl => 'لینک اثر';

  @override
  String get stop => 'توقف';

  @override
  String get sort_newest => 'مرتب سازی بر اساس جدید ترین اضافه شده';

  @override
  String get sort_oldest => 'مرتب سازی بر اساس قدیمی ترین اضافه شده';

  @override
  String get sleep_timer => 'زمان خواب';

  @override
  String mins(Object minutes) {
    return '$minutes دقیقه';
  }

  @override
  String hours(Object hours) {
    return '$hours ساعت';
  }

  @override
  String hour(Object hours) {
    return '$hours ساعت';
  }

  @override
  String get custom_hours => 'ساعت سفارشی';

  @override
  String get logs => 'رسید خطا';

  @override
  String get developers => 'توسعه دهنده ها';

  @override
  String get not_logged_in => 'شما وارد نشده اید ';

  @override
  String get search_mode => 'حالت جستجو';

  @override
  String get audio_source => 'منبع صدا';

  @override
  String get ok => 'باشد';

  @override
  String get failed_to_encrypt => 'رمز گذاری نشده';

  @override
  String get encryption_failed_warning =>
      'Spotube از رمزگذاری برای ذخیره ایمن داده های شما استفاده می کند. اما موفق به انجام این کار نشد. بنابراین به فضای ذخیره‌سازی ناامن تبدیل می‌شود\nاگر از لینوکس استفاده می‌کنید، لطفاً مطمئن شوید که سرویس مخفی (gnome-keyring، kde-wallet، keepassxc و غیره) را نصب کرده‌اید.';

  @override
  String get querying_info => 'جستجو درباره ';

  @override
  String get piped_api_down => 'ایراد در سرور';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'به دلیل مشکل $pipedInstance ارتباط با سرور مقدور نیست\n\nنمونه را تغییر دهید یا «نوع API» را به API رسمی YouTube تغییر دهید\n\nحتماً پس از تغییر، برنامه را دوباره راه‌اندازی کنید';
  }

  @override
  String get you_are_offline => 'شما در حال حاضر افلاین هستید ';

  @override
  String get connection_restored => 'اتصال به اینترنت شما بازیابی شد ';

  @override
  String get use_system_title_bar => 'از نوار عنوان سیستم استفاده کنید ';

  @override
  String get crunching_results => 'نتایج خرد کردن...';

  @override
  String get search_to_get_results => 'جستجو کنید تا به نتیجه برسید';

  @override
  String get use_amoled_mode => 'استفاده از حالت AMOLED';

  @override
  String get pitch_dark_theme => 'تم تیره دارت';

  @override
  String get normalize_audio => 'نرمال کردن صدا';

  @override
  String get change_cover => 'تغییر جلد';

  @override
  String get add_cover => 'افزودن جلد';

  @override
  String get restore_defaults => 'بازیابی پیش فرض ها';

  @override
  String get download_music_format => 'فرمت دانلود موسیقی';

  @override
  String get streaming_music_format => 'فرمت پخش آنلاین موسیقی';

  @override
  String get download_music_quality => 'کیفیت دانلود موسیقی';

  @override
  String get streaming_music_quality => 'کیفیت پخش آنلاین موسیقی';

  @override
  String get login_with_lastfm => 'ورود با Last.fm';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect_lastfm => 'قطع ارتباط با Last.fm';

  @override
  String get disconnect => 'قطع ارتباط';

  @override
  String get username => 'نام کاربری';

  @override
  String get password => 'رمز عبور';

  @override
  String get login => 'ورود';

  @override
  String get login_with_your_lastfm => 'ورود با حساب کاربری Last.fm خود';

  @override
  String get scrobble_to_lastfm => 'Scrobble به Last.fm';

  @override
  String get go_to_album => 'رفتن به آلبوم';

  @override
  String get discord_rich_presence => 'حضور غنی دیسکورد';

  @override
  String get browse_all => 'مرور همه';

  @override
  String get genres => 'ژانرها';

  @override
  String get explore_genres => 'استکشاف ژانرها';

  @override
  String get friends => 'دوستان';

  @override
  String get no_lyrics_available =>
      'متاسفیم، قادر به یافتن متن این قطعه نیستیم';

  @override
  String get start_a_radio => 'شروع یک رادیو';

  @override
  String get how_to_start_radio => 'چگونه می‌خواهید رادیو را شروع کنید؟';

  @override
  String get replace_queue_question =>
      'آیا می‌خواهید لیست پخش فعلی را جایگزین کنید یا به آن اضافه کنید؟';

  @override
  String get endless_playback => 'پخش بی‌پایان';

  @override
  String get delete_playlist => 'حذف لیست پخش';

  @override
  String get delete_playlist_confirmation =>
      'آیا مطمئن هستید که می‌خواهید این لیست پخش را حذف کنید؟';

  @override
  String get local_tracks => 'موسیقی‌های محلی';

  @override
  String get local_tab => 'محلی';

  @override
  String get song_link => 'پیوند آهنگ';

  @override
  String get skip_this_nonsense => 'این احمقانه را بگذرانید';

  @override
  String get freedom_of_music => '“آزادی موسیقی”';

  @override
  String get freedom_of_music_palm => '“آزادی موسیقی در دستان شما”';

  @override
  String get get_started => 'بیایید شروع کنیم';

  @override
  String get youtube_source_description => 'پیشنهاد شده و بهترین عمل می‌کند.';

  @override
  String get piped_source_description =>
      'احساس آزادی می‌کنید؟ مانند یوتیوب اما بیشتر آزاد.';

  @override
  String get jiosaavn_source_description => 'بهترین برای منطقه جنوب آسیا.';

  @override
  String get invidious_source_description =>
      'شبیه Piped اما با در دسترس بودن بیشتر';

  @override
  String highest_quality(Object quality) {
    return 'بالاترین کیفیت: $quality';
  }

  @override
  String get select_audio_source => 'انتخاب منبع صوتی';

  @override
  String get endless_playback_description =>
      'خودکار اضافه کردن آهنگ‌های جدید\nبه انتهای صف';

  @override
  String get choose_your_region => 'منطقه خود را انتخاب کنید';

  @override
  String get choose_your_region_description =>
      'این به Spotube کمک می‌کند تا محتوای مناسبی را برای موقعیت شما نشان دهد.';

  @override
  String get choose_your_language => 'زبان خود را انتخاب کنید';

  @override
  String get help_project_grow => 'کمک به رشد این پروژه';

  @override
  String get help_project_grow_description =>
      'Spotube یک پروژه متن باز است. شما می‌توانید با به پروژه کمک کردن، گزارش دادن اشکالات یا پیشنهاد ویژگی‌های جدید، به این پروژه کمک کنید.';

  @override
  String get contribute_on_github => 'مشارکت در GitHub';

  @override
  String get donate_on_open_collective => 'کمک مالی در Open Collective';

  @override
  String get browse_anonymously => 'مرور به صورت ناشناس';

  @override
  String get enable_connect => 'فعال‌سازی اتصال';

  @override
  String get enable_connect_description => 'کنترل Spotube از دیگر دستگاه‌ها';

  @override
  String get devices => 'دستگاه‌ها';

  @override
  String get select => 'انتخاب';

  @override
  String connect_client_alert(Object client) {
    return 'شما توسط $client کنترل می‌شوید';
  }

  @override
  String get this_device => 'این دستگاه';

  @override
  String get remote => 'راه‌دور';

  @override
  String get stats => 'آمار';

  @override
  String and_n_more(Object count) {
    return 'و $count بیشتر';
  }

  @override
  String get recently_played => 'اخیراً پخش شده';

  @override
  String get browse_more => 'بیشتر مرور کنید';

  @override
  String get no_title => 'بدون عنوان';

  @override
  String get not_playing => 'در حال پخش نیست';

  @override
  String get epic_failure => 'شکست حماسی!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return '$tracks_length ترک به صف اضافه شد';
  }

  @override
  String get spotube_has_an_update => 'Spotube یک بروزرسانی دارد';

  @override
  String get download_now => 'اکنون دانلود کنید';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'نسخه شبانه Spotube $nightlyBuildNum منتشر شد';
  }

  @override
  String release_version(Object version) {
    return 'نسخه Spotube v$version منتشر شد';
  }

  @override
  String get read_the_latest => 'آخرین‌ها را بخوانید';

  @override
  String get release_notes => 'یادداشت‌های انتشار';

  @override
  String get pick_color_scheme => 'طرح رنگ را انتخاب کنید';

  @override
  String get save => 'ذخیره';

  @override
  String get choose_the_device => 'دستگاه را انتخاب کنید:';

  @override
  String get multiple_device_connected =>
      'چندین دستگاه متصل هستند.\nدستگاهی را انتخاب کنید که می‌خواهید این عملیات بر روی آن انجام شود';

  @override
  String get nothing_found => 'چیزی پیدا نشد';

  @override
  String get the_box_is_empty => 'جعبه خالی است';

  @override
  String get top_artists => 'بهترین هنرمندان';

  @override
  String get top_albums => 'بهترین آلبوم‌ها';

  @override
  String get this_week => 'این هفته';

  @override
  String get this_month => 'این ماه';

  @override
  String get last_6_months => '۶ ماه گذشته';

  @override
  String get this_year => 'امسال';

  @override
  String get last_2_years => '۲ سال گذشته';

  @override
  String get all_time => 'همیشه';

  @override
  String powered_by_provider(Object providerName) {
    return 'توسط $providerName پشتیبانی شده است';
  }

  @override
  String get email => 'ایمیل';

  @override
  String get profile_followers => 'دنبال‌کنندگان';

  @override
  String get birthday => 'تولد';

  @override
  String get subscription => 'اشتراک';

  @override
  String get not_born => 'متولد نشده';

  @override
  String get hacker => 'هکر';

  @override
  String get profile => 'پروفایل';

  @override
  String get no_name => 'بدون نام';

  @override
  String get edit => 'ویرایش';

  @override
  String get user_profile => 'پروفایل کاربر';

  @override
  String count_plays(Object count) {
    return '$count پخش';
  }

  @override
  String get streaming_fees_hypothetical => 'هزینه‌های پخش (فرضی)';

  @override
  String get minutes_listened => 'دقایق گوش داده شده';

  @override
  String get streamed_songs => 'ترانه‌های پخش شده';

  @override
  String count_streams(Object count) {
    return '$count پخش';
  }

  @override
  String get owned_by_you => 'توسط شما مالکیت شده';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl به کلیپ‌بورد کپی شد';
  }

  @override
  String get hipotetical_calculation =>
      '*این محاسبه بر اساس میانگین پرداخت به ازای هر پخش (0.003 تا 0.005 دلار) در پلتفرم‌های استریم موزیک آنلاین انجام شده است. این یک محاسبه فرضی است که به کاربر دیدی از مقدار پرداختی به هنرمندان در صورت گوش دادن به آهنگ آن‌ها در پلتفرم‌های مختلف ارائه می‌دهد.';

  @override
  String count_mins(Object minutes) {
    return '$minutes دقیقه';
  }

  @override
  String get summary_minutes => 'دقیقه‌ها';

  @override
  String get summary_listened_to_music => 'به موسیقی گوش داده شده';

  @override
  String get summary_songs => 'ترانه‌ها';

  @override
  String get summary_streamed_overall => 'پخش شده به طور کلی';

  @override
  String get summary_owed_to_artists => 'به هنرمندان بدهکار است\nاین ماه';

  @override
  String get summary_artists => 'هنرمندان';

  @override
  String get summary_music_reached_you => 'موسیقی به شما رسیده است';

  @override
  String get summary_full_albums => 'آلبوم‌های کامل';

  @override
  String get summary_got_your_love => 'عشق شما را به دست آورد';

  @override
  String get summary_playlists => 'لیست‌های پخش';

  @override
  String get summary_were_on_repeat => 'در تکرار بودند';

  @override
  String total_money(Object money) {
    return 'مجموع $money';
  }

  @override
  String get webview_not_found => 'وب‌ویو پیدا نشد';

  @override
  String get webview_not_found_description =>
      'هیچ اجرای وب‌ویو روی دستگاه شما نصب نشده است.\nدر صورت نصب، مطمئن شوید که در environment PATH قرار دارد\n\nپس از نصب، برنامه را مجدداً راه‌اندازی کنید';

  @override
  String get unsupported_platform => 'پلتفرم پشتیبانی نمی‌شود';

  @override
  String get cache_music => 'موسیقی در حافظه موقت';

  @override
  String get open => 'باز کردن';

  @override
  String get cache_folder => 'پوشه حافظه موقت';

  @override
  String get export => 'صادر کردن';

  @override
  String get clear_cache => 'پاک کردن حافظه موقت';

  @override
  String get clear_cache_confirmation =>
      'آیا می‌خواهید حافظه موقت را پاک کنید؟';

  @override
  String get export_cache_files => 'صادر کردن فایل‌های حافظه موقت';

  @override
  String found_n_files(Object count) {
    return '$count فایل یافت شد';
  }

  @override
  String get export_cache_confirmation =>
      'آیا می‌خواهید این فایل‌ها را صادر کنید به';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return '$filesExported از $files فایل صادر شد';
  }

  @override
  String get undo => 'بازگشت';

  @override
  String get download_all => 'دانلود همه';

  @override
  String get add_all_to_playlist => 'افزودن همه به لیست پخش';

  @override
  String get add_all_to_queue => 'افزودن همه به صف';

  @override
  String get play_all_next => 'پخش همه بعدی';

  @override
  String get pause => 'مکث';

  @override
  String get view_all => 'مشاهده همه';

  @override
  String get no_tracks_added_yet =>
      'به نظر می‌رسد هنوز هیچ آهنگی اضافه نکرده‌اید.';

  @override
  String get no_tracks => 'به نظر می‌رسد هیچ آهنگی در اینجا وجود ندارد.';

  @override
  String get no_tracks_listened_yet => 'به نظر می‌رسد هنوز چیزی نشنیده‌اید.';

  @override
  String get not_following_artists => 'شما هیچ هنرمندی را دنبال نمی‌کنید.';

  @override
  String get no_favorite_albums_yet =>
      'به نظر می‌رسد هنوز هیچ آلبومی را به علاقه‌مندی‌هایتان اضافه نکرده‌اید.';

  @override
  String get no_logs_found => 'هیچ لاگی پیدا نشد';

  @override
  String get youtube_engine => 'موتور YouTube';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine نصب نشده است';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine در سیستم شما نصب نشده است.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'اطمینان حاصل کنید که در متغیر PATH موجود است یا\nآدرس مطلق فایل اجرایی $engine را در زیر تنظیم کنید.';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'در macOS/Linux/سیستم‌عامل‌های مشابه Unix، تنظیم مسیر در .zshrc/.bashrc/.bash_profile و غیره کار نمی‌کند.\nباید مسیر را در فایل پیکربندی شل تنظیم کنید.';

  @override
  String get download => 'دانلود';

  @override
  String get file_not_found => 'فایل پیدا نشد';

  @override
  String get custom => 'شخصی‌سازی شده';

  @override
  String get add_custom_url => 'اضافه کردن URL سفارشی';

  @override
  String get edit_port => 'ویرایش پورت';

  @override
  String get port_helper_msg =>
      'پیش‌فرض -1 است که نشان‌دهنده یک عدد تصادفی است. اگر فایروال شما پیکربندی شده است، توصیه می‌شود این را تنظیم کنید.';

  @override
  String connect_request(Object client) {
    return 'آیا اجازه می‌دهید $client متصل شود؟';
  }

  @override
  String get connection_request_denied =>
      'اتصال رد شد. کاربر دسترسی را رد کرد.';

  @override
  String get an_error_occurred => 'خطایی رخ داد';

  @override
  String get copy_to_clipboard => 'کپی به کلیپ‌بورد';

  @override
  String get view_logs => 'مشاهده لاگ‌ها';

  @override
  String get retry => 'دوباره تلاش کن';

  @override
  String get no_default_metadata_provider_selected =>
      'هیچ ارائه‌دهندهٔ پیش‌فرض متادیتا تعیین نکرده‌اید';

  @override
  String get manage_metadata_providers => 'مدیریت ارائه‌دهندگان متادیتا';

  @override
  String get open_link_in_browser => 'باز کردن لینک در مرورگر؟';

  @override
  String get do_you_want_to_open_the_following_link =>
      'آیا می‌خواهید لینک زیر را باز کنید؟';

  @override
  String get unsafe_url_warning =>
      'باز کردن لینک از منابع نامطمئن می‌تواند ناامن باشد. مراقب باشید!\nهمچنین می‌توانید لینک را در کلیپ‌بورد خود کپی کنید.';

  @override
  String get copy_link => 'کپی لینک';

  @override
  String get building_your_timeline =>
      'در حال ساخت جدول زمانی بر اساس شنیده‌هایتان…';

  @override
  String get official => 'رسمی';

  @override
  String author_name(Object author) {
    return 'نویسنده: $author';
  }

  @override
  String get third_party => 'سوم‌شخص';

  @override
  String get plugin_requires_authentication => 'افزونه نیاز به احراز هویت دارد';

  @override
  String get update_available => 'به‌روزرسانی در دسترس است';

  @override
  String get supports_scrobbling => 'پشتیبانی از اسکراب‌بلینگ';

  @override
  String get plugin_scrobbling_info =>
      'این افزونه موسیقی شما را اسکراب می‌کند تا تاریخچهٔ شنیداری‌تان را تولید کند.';

  @override
  String get default_metadata_source => 'منبع پیش‌فرض فراداده';

  @override
  String get set_default_metadata_source => 'تنظیم منبع پیش‌فرض فراداده';

  @override
  String get default_audio_source => 'منبع پیش‌فرض صوت';

  @override
  String get set_default_audio_source => 'تنظیم منبع پیش‌فرض صوت';

  @override
  String get set_default => 'تنظیم به عنوان پیش‌فرض';

  @override
  String get support => 'پشتیبانی';

  @override
  String get support_plugin_development => 'حمایت از توسعهٔ افزونه';

  @override
  String can_access_name_api(Object name) {
    return '- می‌تواند به API **$name** دسترسی پیدا کند';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'می‌خواهید این افزونه را نصب کنید؟';

  @override
  String get third_party_plugin_warning =>
      'این افزونه از مخزن شخص ثالث آمده است. لطفاً قبل از نصب از منابع آن مطمئن شوید.';

  @override
  String get author => 'نویسنده';

  @override
  String get this_plugin_can_do_following =>
      'این افزونه می‌تواند موارد زیر را انجام دهد';

  @override
  String get install => 'نصب';

  @override
  String get install_a_metadata_provider => 'نصب یک ارائه‌دهندهٔ متادیتا';

  @override
  String get no_tracks_playing => 'در حال‌ حاضر هیچ تراکی در حال پخش نیست';

  @override
  String get synced_lyrics_not_available =>
      'متن هم‌زمان‌شده برای این آهنگ در دسترس نیست. لطفاً از';

  @override
  String get plain_lyrics => 'متن ساده';

  @override
  String get tab_instead => 'به‌جای آن از کلید Tab استفاده کنید.';

  @override
  String get disclaimer => 'سلب مسئولیت';

  @override
  String get third_party_plugin_dmca_notice =>
      'تیم Spotube هیچ مسئولیتی (حتی قانونی) در قبال افزونه‌های \"شخص ثالث\" ندارد. از آن‌ها به‌خاطر خود استفاده کنید. برای خطاها/مشکلات، لطفاً در مخزن افزونه گزارش دهید.\n\nاگر هر افزونهٔ \"شخص ثالث\" قوانین ToS/DMCA سرویس یا نهاد قانونی را نقض کند، لطفاً از نویسندهٔ افزونه یا پلتفرم میزبانی (مثل GitHub/Codeberg) درخواست اقدام کنید. افزونه‌هایی که با برچسب \"شخص ثالث\" مشخص شده‌اند، عمومی هستند و توسط جامعه نگهداری می‌شوند؛ ما آن‌ها را تغییر یا مدیریت نمی‌کنیم و نمی‌توانیم دخالت کنیم.\n\n';

  @override
  String get input_does_not_match_format =>
      'ورودی با قالب مورد نیاز تطابق ندارد';

  @override
  String get plugins => 'افزونه‌ها';

  @override
  String get paste_plugin_download_url =>
      'URL دانلود یا مخزن GitHub/Codeberg یا لینک مستقیم فایل .smplug را الصاق کنید';

  @override
  String get download_and_install_plugin_from_url =>
      'دانلود و نصب افزونه از طریق لینک';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'افزونه اضافه نشد: $error';
  }

  @override
  String get upload_plugin_from_file => 'بارگذاری افزونه از فایل';

  @override
  String get installed => 'نصب شد';

  @override
  String get available_plugins => 'افزونه‌های موجود';

  @override
  String get configure_plugins =>
      'افزونه‌های منبع صوت و ارائه‌دهنده فراداده خود را پیکربندی کنید';

  @override
  String get audio_scrobblers => 'اسکراب‌بلرهای صوتی';

  @override
  String get scrobbling => 'اسکراب‌بلینگ';

  @override
  String get source => 'منبع: ';

  @override
  String get uncompressed => 'بدون فشرده‌سازی';

  @override
  String get dab_music_source_description =>
      'مخصوص علاقه‌مندان صدا. ارائه‌دهنده استریم‌های باکیفیت/بدون افت. تطبیق دقیق آهنگ بر اساس ISRC.';
}
