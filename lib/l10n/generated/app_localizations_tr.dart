// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get library => 'Kütüphane';

  @override
  String get updates => 'Güncellemeler';

  @override
  String get history => 'Geçmiş';

  @override
  String get browse => 'Gözat';

  @override
  String get more => 'Daha Fazla';

  @override
  String get open_random_entry => 'Rastgele Giriş Aç';

  @override
  String get import => 'İçe Aktar';

  @override
  String get filter => 'Filtre';

  @override
  String get ignore_filters => 'Filtreleri yok say';

  @override
  String get downloaded => 'İndirildi';

  @override
  String get unread => 'Okunmamış';

  @override
  String get unwatched => 'İzlenmemiş';

  @override
  String get started => 'Başladı';

  @override
  String get bookmarked => 'Yer İmleri';

  @override
  String get sort => 'Sırala';

  @override
  String get alphabetically => 'Alfabetik Olarak';

  @override
  String get last_read => 'Son Okunan';

  @override
  String get last_watched => 'Son İzlenen';

  @override
  String get last_update_check => 'Son Güncelleme Kontrolü';

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
          'Kitaplığından bu $mediaType’nin tüm $count $entryTypePlural’ini siliyorsun.',
      one: 'Kitaplığından bu $mediaType’nin tek $entryType’ünü siliyorsun.',
    );
    return '$_temp0\nBu işlem $mediaType’nin tamamını da kütüphanenden kaldıracak.\n\nNot: Dosyalar silinmeyecek.';
  }

  @override
  String get chapter => 'bölüm';

  @override
  String get episode => 'bölüm';

  @override
  String get unread_count => 'Okunmamış Sayısı';

  @override
  String get unwatched_count => 'İzlenmemiş Sayısı';

  @override
  String get latest_chapter => 'Son Bölüm';

  @override
  String get latest_episode => 'Son Bölüm';

  @override
  String get date_added => 'Eklenme Tarihi';

  @override
  String get display => 'Görüntüle';

  @override
  String get display_mode => 'Görüntüleme Modu';

  @override
  String get compact_grid => 'Kompakt Izgara';

  @override
  String get compression_level => 'Sıkıştırma düzeyi';

  @override
  String compression_info(Object level) {
    return 'Sıkıştırma ne kadar yüksek olursa, yedekleme dosyası o kadar az yer kaplar ancak daha fazla CPU kullanır. Varsayılan: $level';
  }

  @override
  String get comfortable_grid => 'Rahat Izgara';

  @override
  String get cover_only_grid => 'Sadece Kapak Izgarası';

  @override
  String get list => 'Liste';

  @override
  String get badges => 'Rozetler';

  @override
  String get downloaded_chapters => 'İndirilen Bölümler';

  @override
  String get downloaded_episodes => 'İndirilen Bölümler';

  @override
  String get language => 'Dil';

  @override
  String get local_source => 'Yerel Kaynak';

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
  String get tabs => 'Sekmeler';

  @override
  String get show_category_tabs => 'Kategori Sekmelerini Göster';

  @override
  String get show_numbers_of_items => 'Öğe Sayılarını Göster';

  @override
  String get other => 'Diğer';

  @override
  String get show_continue_reading_buttons =>
      'Okumaya Devam Et Düğmelerini Göster';

  @override
  String get show_continue_watching_buttons =>
      'İzlemeye Devam Et Düğmelerini Göster';

  @override
  String get empty_library => 'Boş Kütüphane';

  @override
  String get search => 'Ara...';

  @override
  String get no_recent_updates => 'Yakın Zamanda Güncelleme Yok';

  @override
  String get remove_everything => 'Her Şeyi Kaldır';

  @override
  String get remove_everything_msg => 'Emin misiniz? Tüm geçmiş silinecek';

  @override
  String get remove_all_update_msg => 'Emin misiniz? Tüm güncelleme silinecek';

  @override
  String get ok => 'Tamam';

  @override
  String get cancel => 'İptal';

  @override
  String get remove => 'Kaldır';

  @override
  String get remove_history_msg =>
      'Bu, bu bölümün okunma tarihini kaldıracaktır. Emin misiniz?';

  @override
  String get last_used => 'Son Kullanılan';

  @override
  String get pinned => 'Sabitle';

  @override
  String get sources => 'Kaynaklar';

  @override
  String get install => 'Yükle';

  @override
  String get update => 'Güncelle';

  @override
  String get latest => 'En Yeni';

  @override
  String get extensions => 'Uzantılar';

  @override
  String get migrate => 'Taşı';

  @override
  String get mass_migration_title => 'Toplu taşıma';

  @override
  String get mass_migration_preview_items => 'Öğeleri önizle';

  @override
  String get mass_migration_destination_source => 'Hedef kaynak';

  @override
  String get mass_migration_no_library_items =>
      'Toplu taşıma için uygun kütüphane öğesi yok.';

  @override
  String get mass_migration_no_destination_sources =>
      'Yüklü hedef kaynak bulunamadı.';

  @override
  String get mass_migration_installed => 'Yüklendi';

  @override
  String mass_migration_items_ready_for_review(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe incelenmeye hazır',
      one: '1 öğe incelenmeye hazır',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_item_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe',
      one: '1 öğe',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_select_destination_source => 'Hedef kaynağı seçin';

  @override
  String mass_migration_finding_matches(Object source, Object language) {
    return '$source • $language içinde eşleşmeler aranıyor';
  }

  @override
  String mass_migration_processing_item(int current, int total) {
    return 'Öğe işleniyor: $current / $total';
  }

  @override
  String get mass_migration_waiting_next_item =>
      'Sıradaki öğeden önce 2 saniye bekleniyor...';

  @override
  String get mass_migration_waiting_next_migration =>
      'Sıradaki taşımadan önce 2 saniye bekleniyor...';

  @override
  String mass_migration_matched_so_far(int count) {
    return 'Şu ana kadar eşleşen: $count';
  }

  @override
  String mass_migration_no_match_count(int count) {
    return 'Eşleşme yok: $count';
  }

  @override
  String mass_migration_review_matches(Object source) {
    return '$source için eşleşmeleri incele';
  }

  @override
  String mass_migration_found_matches(int count) {
    return 'Bulunan eşleşmeler: $count';
  }

  @override
  String mass_migration_no_matches(int count) {
    return 'Eşleşme yok: $count';
  }

  @override
  String mass_migration_selected_to_migrate(int count) {
    return 'Taşınmak üzere seçilen: $count';
  }

  @override
  String get mass_migration_finish_review => 'İncelemeyi bitir';

  @override
  String mass_migration_migrate_selected(int count) {
    return 'Seçilen öğeleri taşı ($count)';
  }

  @override
  String mass_migration_migrating_selected(Object source) {
    return 'Seçilen öğeler $source kaynağına taşınıyor';
  }

  @override
  String get mass_migration_no_items_selected => 'Taşıma için öğe seçilmedi.';

  @override
  String mass_migration_migrating_item(int current, int total) {
    return 'Öğe taşınıyor: $current / $total';
  }

  @override
  String get mass_migration_complete => 'Toplu taşıma tamamlandı';

  @override
  String get mass_migration_complete_success_message =>
      'Seçilen tüm öğeler başarıyla işlendi.';

  @override
  String get mass_migration_complete_partial_message =>
      'Taşıma bitti ancak bazı öğeler hala manuel ilgi gerektiriyor.';

  @override
  String mass_migration_route_summary(Object source, Object destination) {
    return '$source → $destination';
  }

  @override
  String get mass_migration_processed => 'İşlendi';

  @override
  String get mass_migration_matched => 'Eşleşti';

  @override
  String get mass_migration_migrated => 'Taşındı';

  @override
  String get mass_migration_skipped => 'Atlandı';

  @override
  String get mass_migration_failed => 'Başarısız';

  @override
  String get mass_migration_failed_items => 'Başarısız Öğeler';

  @override
  String get mass_migration_exit => 'Toplu Taşımadan Çık';

  @override
  String get mass_migration_no_destination_match =>
      'Hedef eşleşmesi bulunamadı';

  @override
  String mass_migration_query(Object query) {
    return 'Sorgu: $query';
  }

  @override
  String get mass_migration_skip => 'Atla';

  @override
  String get mass_migration_loading => 'Yükleniyor...';

  @override
  String get mass_migration_choose_another_result => 'Başka bir sonuç seçin';

  @override
  String get mass_migration_source_chapters => 'Kaynak bölümler';

  @override
  String get mass_migration_destination_chapters => 'Hedef bölümler';

  @override
  String mass_migration_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bölüm',
      one: '1 bölüm',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_source_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kaynak bölümü',
      one: '1 kaynak bölümü',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_destination_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hedef bölümü',
      one: '1 hedef bölümü',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_no_chapters_found => 'Bölüm bulunamadı.';

  @override
  String mass_migration_and_more_chapters(int count) {
    return 'Ve $count tane daha...';
  }

  @override
  String get mass_migration_unknown_title => 'Bilinmeyen başlık';

  @override
  String get mass_migration_unknown_match => 'Bilinmeyen eşleşme';

  @override
  String get mass_migration_unknown_source => 'Bilinmeyen kaynak';

  @override
  String get mass_migration_unknown_chapter => 'Bilinmeyen bölüm';

  @override
  String get migrate_confirm => 'Başka bir kaynağa geç';

  @override
  String get clean_database => 'Veritabanını temizle';

  @override
  String cleaned_database(Object x) {
    return 'Veritabanı temizlendi! $x giriş kaldırıldı';
  }

  @override
  String get clean_database_desc =>
      'Bu, kütüphaneye eklenmeyen tüm öğeleri kaldıracaktır!';

  @override
  String get incognito_mode => 'Gizli Mod';

  @override
  String get incognito_mode_description => 'Okuma geçmişini duraklatır';

  @override
  String get downloaded_only => 'Sadece indirilmiş';

  @override
  String get downloaded_only_description =>
      'Kütüphanenizde yalnızca indirilmiş girişleri göster';

  @override
  String get download_queue => 'İndirme Kuyruğu';

  @override
  String get categories => 'Kategoriler';

  @override
  String get statistics => 'İstatistikler';

  @override
  String get settings => 'Ayarlar';

  @override
  String get about => 'Hakkında';

  @override
  String get help => 'Yardım';

  @override
  String get no_downloads => 'İndirme Yok';

  @override
  String get edit_categories => 'Kategorileri Düzenle';

  @override
  String get edit_categories_description =>
      'Henüz kategoriniz yok. Kütüphanenizi organize etmek için bir tane oluşturmak için artı düğmesine dokunun';

  @override
  String get add => 'Ekle';

  @override
  String get add_category => 'Kategori Ekle';

  @override
  String get name => 'İsim';

  @override
  String get category_name_required => '*Gerekli';

  @override
  String get add_category_error_exist => 'Bu isimde zaten bir kategori var!';

  @override
  String get delete_category => 'Kategoriyi Sil';

  @override
  String delete_category_msg(Object name) {
    return '$name kategorisini silmek istiyor musunuz?';
  }

  @override
  String get rename_category => 'Kategoriyi Yeniden Adlandır';

  @override
  String get general => 'Genel';

  @override
  String get general_subtitle => 'Uygulama dili';

  @override
  String get app_language => 'Uygulama dili';

  @override
  String get default_subtitle_language => 'Varsayılan altyazı dili';

  @override
  String get appearance => 'Görünüm';

  @override
  String get appearance_subtitle => 'Tema, tarih ve saat formatı';

  @override
  String get theme => 'Tema';

  @override
  String get dark_mode => 'Karanlık Mod';

  @override
  String get follow_system_theme => 'Sistem temasını takip et';

  @override
  String get on => 'Açık';

  @override
  String get off => 'Kapalı';

  @override
  String get pure_black_dark_mode => 'Saf Siyah Karanlık Mod';

  @override
  String get timestamp => 'Zaman Damgası';

  @override
  String get relative_timestamp => 'Göreceli Zaman Damgası';

  @override
  String get relative_timestamp_short => 'Kısa (Bugün, Dün)';

  @override
  String get relative_timestamp_long => 'Uzun (Kısa+, n gün önce)';

  @override
  String get date_format => 'Tarih Formatı';

  @override
  String get reader => 'Okuyucu';

  @override
  String get reader_manga => 'Manga reader';

  @override
  String get refresh => 'Yenile';

  @override
  String get reader_subtitle => 'Okuma modu, görüntüleme, navigasyon';

  @override
  String get default_reading_mode => 'Varsayılan Okuma Modu';

  @override
  String get reading_mode_vertical => 'Dikey';

  @override
  String get reading_mode_horizontal => 'Yatay';

  @override
  String get reading_mode_left_to_right => 'Soldan Sağa';

  @override
  String get reading_mode_right_to_left => 'Sağdan Sola';

  @override
  String get reading_mode_vertical_continuous => 'Sürekli Dikey';

  @override
  String get reading_mode_webtoon => 'Webtoon';

  @override
  String get double_tap_animation_speed => 'Çift Dokunma Animasyon Hızı';

  @override
  String get normal => 'Normal';

  @override
  String get fast => 'Hızlı';

  @override
  String get no_animation => 'Animasyon Yok';

  @override
  String get animate_page_transitions => 'Sayfa Geçişlerini Animasyonla';

  @override
  String get crop_borders => 'Kenarları Kırp';

  @override
  String get downloads => 'İndirilenler';

  @override
  String get downloads_subtitle => 'İndirme ayarları';

  @override
  String get download_location => 'İndirme Yeri';

  @override
  String get custom_location => 'Özel Yer';

  @override
  String get only_on_wifi => 'Sadece Wifi Üzerinde';

  @override
  String get save_as_cbz_archive => 'CBZ Arşivi Olarak Kaydet';

  @override
  String get delete_download_after_reading => 'Okuduktan sonra indirmeyi sil';

  @override
  String get concurrent_downloads => 'Eş zamanlı indirmeler';

  @override
  String get browse_subtitle => 'Kaynaklar, genel arama';

  @override
  String get only_include_pinned_sources =>
      'Sadece Sabitlenmiş Kaynakları Dahil Et';

  @override
  String get nsfw_sources => 'NSFW (+18) Kaynaklar';

  @override
  String get nsfw_sources_show => 'Kaynak ve uzantı listelerinde göster';

  @override
  String get nsfw_sources_info =>
      'Bu, resmi olmayan veya potansiyel olarak yanlış işaretlenmiş uzantıların uygulama içinde NSFW (18+) içerikleri yüzeye çıkarmasını engellemez';

  @override
  String get version => 'Versiyon';

  @override
  String get check_for_update => 'Güncelleme Kontrol Et';

  @override
  String get logs_on => 'Günlük kaydını etkinleştir';

  @override
  String get share_app_logs => 'Uygulama günlüklerini paylaş';

  @override
  String get no_app_logs => 'log.txt dosyası yok!';

  @override
  String get failed => 'Başarısız!';

  @override
  String n_days_ago(Object days) {
    return '$days gün önce';
  }

  @override
  String get today => 'Bugün';

  @override
  String get yesterday => 'Dün';

  @override
  String get a_week_ago => 'Bir Hafta Önce';

  @override
  String get next_week => 'Gelecek hafta';

  @override
  String get add_to_library => 'Kütüphaneye Ekle';

  @override
  String get added_to_library => 'Added to library';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get ongoing => 'Devam Ediyor';

  @override
  String get on_hiatus => 'Ara Verildi';

  @override
  String get canceled => 'İptal Edildi';

  @override
  String get publishing_finished => 'Yayımlama Tamamlandı';

  @override
  String get unknown => 'Bilinmiyor';

  @override
  String get set_categories => 'Kategorileri Ayarla';

  @override
  String get edit => 'Düzenle';

  @override
  String get in_library => 'Kütüphanede';

  @override
  String get filter_scanlator_groups => 'Tarama Gruplarını Filtrele';

  @override
  String get reset => 'Sıfırla';

  @override
  String get by_source => 'Kaynağa Göre';

  @override
  String get by_chapter_number => 'Bölüm Numarasına Göre';

  @override
  String get by_episode_number => 'Bölüm Sayısına Göre';

  @override
  String get by_upload_date => 'Yükleme Tarihine Göre';

  @override
  String get source_title => 'Kaynak Başlığı';

  @override
  String get chapter_number => 'Bölüm Numarası';

  @override
  String get episode_number => 'Bölüm Sayısı';

  @override
  String get share => 'Paylaş';

  @override
  String n_chapters(Object n) {
    return '$n bölüm';
  }

  @override
  String get no_description => 'Açıklama Yok';

  @override
  String get resume => 'Devam Et';

  @override
  String get read => 'Oku';

  @override
  String get watch => 'İzle';

  @override
  String get popular => 'Popüler';

  @override
  String get open_in_browser => 'Tarayıcıda Aç';

  @override
  String get clear_cookie => 'Çerezi Temizle';

  @override
  String get show_page_number => 'Sayfa Numarasını Göster';

  @override
  String get from_library => 'Kütüphaneden';

  @override
  String get downloaded_chapter => 'İndirilen Bölüm';

  @override
  String page(Object page) {
    return 'Sayfa $page';
  }

  @override
  String get global_search => 'Genel Arama';

  @override
  String get color_blend_level => 'Renk Karışımı Seviyesi';

  @override
  String current(Object char) {
    return 'Şu Anki $char';
  }

  @override
  String finished(Object char) {
    return 'Bitmiş $char';
  }

  @override
  String next(Object char) {
    return 'Sonraki $char';
  }

  @override
  String previous(Object char) {
    return 'Önceki $char';
  }

  @override
  String get no_more_chapter => 'Başka Bölüm Yok';

  @override
  String get no_result => 'Sonuç Yok';

  @override
  String get send => 'Gönder';

  @override
  String get delete => 'Sil';

  @override
  String get start_downloading => 'İndirmeye Hemen Başla';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get add_chapters => 'Bölümler Ekle';

  @override
  String get delete_chapters => 'Bölüm Sil?';

  @override
  String get default0 => 'Varsayılan';

  @override
  String get total_chapters => 'Toplam Bölümler';

  @override
  String get total_episodes => 'Toplam Bölümler';

  @override
  String get import_local_file => 'Yerel Dosya İçe Aktar';

  @override
  String get import_files => 'Dosyalar';

  @override
  String get split_epub_chapters => 'Bölümlere ayır';

  @override
  String get split_epub_chapters_description =>
      'Her EPUB bölümünü ayrı bir giriş olarak içe aktar';

  @override
  String get nothing_read_recently => 'Son Zamanlarda Okunan Bir Şey Yok';

  @override
  String get status => 'Durum';

  @override
  String get not_started => 'Başlamadı';

  @override
  String get score => 'Puan';

  @override
  String get start_date => 'Başlangıç Tarihi';

  @override
  String get finish_date => 'Bitiş Tarihi';

  @override
  String get reading => 'Okuyor';

  @override
  String get on_hold => 'Beklemede';

  @override
  String get dropped => 'Bırakıldı';

  @override
  String get plan_to_read => 'Okumak İçin Planla';

  @override
  String get re_reading => 'Tekrar Okuyor';

  @override
  String get chapters => 'Bölümler';

  @override
  String get add_tracker => 'Takip Ekle';

  @override
  String get one_tracker => '1 Takip';

  @override
  String n_tracker(Object n) {
    return '$n Takip';
  }

  @override
  String get tracking => 'Takip Ediliyor';

  @override
  String get syncing => 'Senkrone etme';

  @override
  String get sync_password => 'Şifre (en az 8 karakter)';

  @override
  String get sync_logged => 'Giriş başarılı';

  @override
  String get syncing_subtitle =>
      'İlerlemenizi kendi barındırdığınız bir \nserver aracılığıyla birden fazla cihaz arasında senkronize edin. Daha fazla bilgi için discord sunucumuza göz atın!';

  @override
  String get last_sync_manga => 'Son manga senkronizasyonu:';

  @override
  String get last_sync_history => 'Son tarih senkronizasyonu:';

  @override
  String get last_sync_update => 'Son güncelleme senkronizasyonu:';

  @override
  String get sync_server => 'Senkronizasyon Sunucu Adresi';

  @override
  String get sync_login_invalid_creds => 'Geçersiz e-posta veya şifre';

  @override
  String get sync_starting => 'Senkronizasyonu başlatıyorum.';

  @override
  String get sync_finished => 'Senkronizasyon tamamlandı';

  @override
  String get sync_failed => 'Senkronizasyon başarısız';

  @override
  String get sync_button_sync => 'İlerlemeyi senkronize et';

  @override
  String get sync_button_upload => 'Sadece yükle';

  @override
  String get sync_button_upload_info =>
      'Bu işlem uzak verileri yerel verilerle tamamen değiştirecektir!';

  @override
  String get sync_button_download => 'Sadece indir';

  @override
  String get sync_button_download_info =>
      'Bu işlem yerel verileri uzak verilerle tamamen değiştirecektir!';

  @override
  String get sync_on => 'Senkronizasyonu etkinleştir';

  @override
  String get sync_auto => 'Otomatik senkronizasyon';

  @override
  String get sync_auto_warning =>
      'Otomatik senkronizasyon şu anda deneysel bir özelliktir!';

  @override
  String get sync_auto_off => 'Kapalı';

  @override
  String get sync_auto_5_minutes => 'Her 5 dakikada bir';

  @override
  String get sync_auto_10_minutes => 'Her 10 dakikada bir';

  @override
  String get sync_auto_30_minutes => 'Her 30 dakikada bir';

  @override
  String get sync_auto_1_hour => 'Her 1 saatte bir';

  @override
  String get sync_auto_3_hours => 'Her 3 saatte bir';

  @override
  String get sync_auto_6_hours => 'Her 6 saatte bir';

  @override
  String get sync_auto_12_hours => 'Her 12 saatte bir';

  @override
  String get server_error => 'Sunucu hatası!';

  @override
  String get dialog_confirm => 'Onayla';

  @override
  String get description => 'Açıklama';

  @override
  String get reorder_navigation => 'Gezinmeyi özelleştir';

  @override
  String get reorder_navigation_description =>
      'Gezinmeyi ihtiyaçlarınıza göre yeniden düzenleyin ve ayarlayın.';

  @override
  String get full_screen_player => 'Tam ekran kullan';

  @override
  String get full_screen_player_info =>
      'Bir video oynatıldığında otomatik olarak tam ekran kullan.';

  @override
  String episode_progress(Object n) {
    return 'İlerleme: $n';
  }

  @override
  String n_episodes(Object n) {
    return '$n bölüm';
  }

  @override
  String get manga_sources => 'Manga Kaynakları';

  @override
  String get anime_sources => 'Anime Kaynakları';

  @override
  String get novel_sources => 'Hikaye Kaynakları';

  @override
  String get anime_extensions => 'Anime Uzantıları';

  @override
  String get manga_extensions => 'Manga Uzantıları';

  @override
  String get novel_extensions => 'Hikaye Uzantıları';

  @override
  String get extension_settings => 'Uzantı ayarları';

  @override
  String get anime => 'Anime';

  @override
  String get manga => 'Manga';

  @override
  String get novel => 'Hikaye';

  @override
  String get library_no_category_exist => 'Henüz hiç kategoriniz yok';

  @override
  String get watching => 'İzliyor';

  @override
  String get plan_to_watch => 'İzlemek İçin Planla';

  @override
  String get re_watching => 'Tekrar İzliyor';

  @override
  String get episodes => 'Bölümler';

  @override
  String get download => 'İndir';

  @override
  String get new_update_available => 'Yeni güncelleme mevcut';

  @override
  String app_version(Object v) {
    return 'Uygulama Sürümü : v$v';
  }

  @override
  String get searching_for_updates => 'Güncellemeler aranıyor...';

  @override
  String get no_new_updates_available => 'Yeni güncelleme yok';

  @override
  String get uninstall => 'Kaldır';

  @override
  String uninstall_extension(Object ext) {
    return '$ext uzantısını kaldır?';
  }

  @override
  String get langauage => 'Dil';

  @override
  String get extension_detail => 'Uzantı detayı';

  @override
  String get scale_type => 'Ölçek Türü';

  @override
  String get scale_type_fit_screen => 'Ekrana Sığdır';

  @override
  String get scale_type_stretch => 'Esnet';

  @override
  String get scale_type_fit_width => 'Genişliğe Sığdır';

  @override
  String get scale_type_fit_height => 'Yüksekliğe Sığdır';

  @override
  String get scale_type_original_size => 'Orijinal Boyut';

  @override
  String get scale_type_smart_fit => 'Akıllı Sığdırma';

  @override
  String get page_preload_amount => 'Sayfa Ön Yükleme Miktarı';

  @override
  String get page_preload_amount_subtitle =>
      'Okurken ön yüklenen sayfa miktarı. Daha yüksek değerler, daha yüksek önbellek ve ağ kullanımı pahasına daha pürüzsüz bir okuma deneyimi sağlar.';

  @override
  String get image_loading_error => 'Bu resim yüklenemedi';

  @override
  String get add_episodes => 'Bölümler Ekle';

  @override
  String get video_quality => 'Kalite';

  @override
  String get video_subtitle => 'Altyazı';

  @override
  String get check_for_extension_updates =>
      'Uzantı güncellemelerini kontrol et';

  @override
  String get auto_extensions_updates => 'Otomatik Uzantı Güncellemeleri';

  @override
  String get auto_extensions_updates_subtitle =>
      'Yeni bir sürümü mevcut olduğunda uzantıyı otomatik olarak günceller.';

  @override
  String get check_for_app_updates =>
      'Uygulama başlatıldığında güncellemeleri kontrol et';

  @override
  String get reading_mode => 'Okuma Modu';

  @override
  String get custom_filter => 'Özel Filtre';

  @override
  String get background_color => 'Arka Plan Rengi';

  @override
  String get white => 'Beyaz';

  @override
  String get black => 'Siyah';

  @override
  String get grey => 'Gri';

  @override
  String get automaic => 'Otomatik';

  @override
  String get preferred_domain => 'Tercih Edilen Alan';

  @override
  String get load_more => 'Daha Fazla Yükle';

  @override
  String get cancel_all_for_this_series => 'Bu Seri İçin Tümünü İptal Et';

  @override
  String get login => 'Giriş Yap';

  @override
  String login_into(Object tracker) {
    return '$tracker Oturum Aç';
  }

  @override
  String get email_adress => 'E-posta Adresi';

  @override
  String get password => 'Şifre';

  @override
  String log_out_from(Object tracker) {
    return '$tracker Oturumu Kapat?';
  }

  @override
  String get log_out => 'Oturumu Kapat';

  @override
  String get update_pending => 'Güncelleme Bekleniyor';

  @override
  String get update_all => 'Tümünü Güncelle';

  @override
  String get backup_and_restore => 'Yedekle ve Geri Yükle';

  @override
  String get create_backup => 'Yedek Oluştur';

  @override
  String get create_backup_dialog_title => 'Ne yedeklemek istiyorsun?';

  @override
  String get create_backup_subtitle =>
      'Mevcut kütüphaneyi geri yüklemek için kullanılabilir';

  @override
  String get restore_backup => 'Yedeği Geri Yükle';

  @override
  String get restore_backup_subtitle =>
      'Yedek dosyasından kütüphaneyi geri yükle';

  @override
  String get automatic_backups => 'Otomatik Yedeklemeler';

  @override
  String get backup_frequency => 'Yedekleme Sıklığı';

  @override
  String get backup_location => 'Yedekleme Konumu';

  @override
  String get backup_options => 'Yedekleme Seçenekleri';

  @override
  String get backup_options_dialog_title => 'Ne yedeklemek istiyorsun?';

  @override
  String get backup_options_subtitle =>
      'Yedek dosyasına hangi bilgilerin dahil edileceği';

  @override
  String get backup_and_restore_warning_info =>
      'Yedeklerin başka yerlerde de kopyalarını tutmalısınız';

  @override
  String get library_entries => 'Kütüphane Girişleri';

  @override
  String get chapters_and_episode => 'Bölümler ve Bölüm';

  @override
  String get every_6_hours => 'Her 6 Saatte Bir';

  @override
  String get every_12_hours => 'Her 12 Saatte Bir';

  @override
  String get daily => 'Günlük';

  @override
  String get every_2_days => 'Her 2 Günde Bir';

  @override
  String get weekly => 'Haftalık';

  @override
  String get restore_backup_warning_title =>
      'Bir yedeği geri yüklemek mevcut tüm verilerin üzerine yazacaktır.\n\nGeri yüklemeye devam et?';

  @override
  String get services => 'Hizmetler';

  @override
  String get tracking_warning_info =>
      'İzleme hizmetlerinde bölüm ilerlemesini güncellemek için tek yönlü senkronizasyon. Bireysel girişler için izlemeyi, izleme düğmesinden ayarlayın.';

  @override
  String get use_page_tap_zones => 'Sayfa Dokunma Bölgelerini Kullan';

  @override
  String get manage_trackers => 'İzleyicileri Yönet';

  @override
  String get restore => 'Geri Yükle';

  @override
  String get backups => 'Yedekler';

  @override
  String get by_scanlator => 'Taramacıya Göre';

  @override
  String get by_name => 'İsme Göre';

  @override
  String get installed => 'Yüklendi';

  @override
  String get auto_scroll => 'Otomatik Kaydırma';

  @override
  String get video_audio => 'Ses';

  @override
  String get video_audio_info =>
      'Tercih edilen diller, perde düzeltmesi, ses kanalları';

  @override
  String get player => 'Oyuncu';

  @override
  String get player_video => 'Video player';

  @override
  String get markEpisodeAsSeenSetting =>
      'Bölümün izlendiği olarak işaretleneceği nokta';

  @override
  String get default_skip_intro_length => 'Varsayılan Giriş Atla süresi';

  @override
  String get default_playback_speed_length => 'Varsayılan Oynatma hızı süresi';

  @override
  String get updateProgressAfterReading =>
      'Okuduktan Sonra İlerlemeyi Güncelle';

  @override
  String get no_sources_installed => 'Hiçbir kaynak yüklü değil!';

  @override
  String get show_extensions => 'uzantıları göster';

  @override
  String get default_skip_forward_skip_length =>
      'Varsayılan ileri atlama atlama uzunluğu';

  @override
  String get aniskip_requires_info =>
      'AniSkip, çalışması için animenin MAL veya Anilist ile takip edilmesini gerektirir.';

  @override
  String get enable_aniskip => 'AniSkip\'i Etkinleştir';

  @override
  String get enable_auto_skip => 'Otomatik Atla\'yı Etkinleştir';

  @override
  String get aniskip_button_timeout => 'Düğme Zaman Aşımı';

  @override
  String get skip_opening => 'Açılışı atla';

  @override
  String get skip_ending => 'Sonu atla';

  @override
  String get fullscreen => 'Tam ekran';

  @override
  String get update_library => 'Kütüphaneyi güncelle';

  @override
  String updating_library(Object cur, Object failed, Object max) {
    return 'Kütüphaneyi güncelleme ($cur / $max) - Başarısız: $failed';
  }

  @override
  String get next_chapter => 'Sonraki bölüm';

  @override
  String get next_5_chapters => 'Sonraki 5 bölüm';

  @override
  String get next_10_chapters => 'Sonraki 10 bölüm';

  @override
  String get next_25_chapters => 'Sonraki 25 bölüm';

  @override
  String get all_chapters => 'Tüm bölümler';

  @override
  String get next_episode => 'Sonraki Bölüm';

  @override
  String get next_5_episodes => 'Sonraki 5 Bölüm';

  @override
  String get next_10_episodes => 'Sonraki 10 Bölüm';

  @override
  String get next_25_episodes => 'Sonraki 25 Bölüm';

  @override
  String get all_episodes => 'Tüm bölümler';

  @override
  String get cover_saved => 'Kapak kaydedildi';

  @override
  String get set_as_cover => 'Kapak olarak ayarla';

  @override
  String get use_this_as_cover_art => 'Bu resmi kapak sanatı olarak kullan?';

  @override
  String get save => 'Kaydet';

  @override
  String get picture_saved => 'Resim kaydedildi';

  @override
  String get cover_updated => 'Kapak güncellendi';

  @override
  String get include_subtitles => 'Altyazıları dahil et';

  @override
  String get blend_mode_default => 'Varsayılan';

  @override
  String get blend_mode_multiply => 'Çarpma';

  @override
  String get blend_mode_screen => 'Ekran';

  @override
  String get blend_mode_overlay => 'Örtüşme';

  @override
  String get blend_mode_colorDodge => 'RenkDodge';

  @override
  String get blend_mode_lighten => 'Açık';

  @override
  String get blend_mode_colorBurn => 'RenkYakma';

  @override
  String get blend_mode_darken => 'Karart';

  @override
  String get blend_mode_difference => 'Fark';

  @override
  String get blend_mode_saturation => 'Doygunluk';

  @override
  String get blend_mode_softLight => 'YumuşakIşık';

  @override
  String get blend_mode_plus => 'Artı';

  @override
  String get blend_mode_exclusion => 'Dışlama';

  @override
  String get custom_color_filter => 'Özel renk filtresi';

  @override
  String get color_filter_blend_mode => 'Renk filtresi karışım modu';

  @override
  String get enable_all => 'Tümünü Etkinleştir';

  @override
  String get disable_all => 'Tümünü Devre Dışı Bırak';

  @override
  String get font => 'Yazı Tipi';

  @override
  String get color => 'Renk';

  @override
  String get font_size => 'Yazı Boyutu';

  @override
  String get text => 'Metin';

  @override
  String get border => 'Kenarlık';

  @override
  String get background => 'Arka Plan';

  @override
  String get no_subtite_warning_message =>
      'Bu videoda altyazı parçaları olmadığı için etkisi yok';

  @override
  String get grid_size => 'Kılavuz Boyutu';

  @override
  String n_per_row(Object n) {
    return '$n satır başına';
  }

  @override
  String get horizontal_continious => 'Yatay sürekli';

  @override
  String get edit_code => 'Kodu düzenle';

  @override
  String get use_libass => 'libass\'ı etkinleştir';

  @override
  String get use_libass_info =>
      'Yerel arka uç için libass tabanlı altyazı rendere etmeyi kullanın.';

  @override
  String get libass_not_disable_message =>
      'Altyazıları özelleştirmek için oyuncu ayarlarında `libass kullan` seçeneğini devre dışı bırakın.';

  @override
  String get torrent_stream => 'Torrent Akışı';

  @override
  String get add_torrent => 'Torrent ekle';

  @override
  String get enter_torrent_hint_text =>
      'Manyetik veya torrent dosyası URL\'sini girin';

  @override
  String get torrent_url => 'Torrent URL\'si';

  @override
  String get or => 'VEYA';

  @override
  String get advanced => 'Gelişmiş';

  @override
  String get advanced_info => 'mpv yapılandırması';

  @override
  String get use_native_http_client => 'Yerel http istemcisini kullan';

  @override
  String get use_native_http_client_info =>
      'otomatik olarak VPN\'ler gibi platform özelliklerini destekler, HTTP/3 gibi daha fazla HTTP özelliğini ve özel yönlendirme işlemlerini destekler';

  @override
  String n_hour_ago(Object hour) {
    return '$hour saat önce';
  }

  @override
  String n_hours_ago(Object hours) {
    return '$hours saat önce';
  }

  @override
  String n_minute_ago(Object minute) {
    return '$minute dakika önce';
  }

  @override
  String n_minutes_ago(Object minutes) {
    return '$minutes dakika önce';
  }

  @override
  String n_day_ago(Object day) {
    return '$day gün önce';
  }

  @override
  String get now => 'şimdi';

  @override
  String library_last_updated(Object lastUpdated) {
    return 'Kütüphane son güncelleme: $lastUpdated';
  }

  @override
  String get data_and_storage => 'Veri ve depolama';

  @override
  String get download_location_info => 'Bölüm indirmeleri için kullanılır';

  @override
  String get storage => 'Depolama';

  @override
  String get clear_chapter_and_episode_cache =>
      'Bölüm ve bölüm önbelleğini temizle';

  @override
  String get cache_cleared => 'Önbellek temizlendi';

  @override
  String get clear_chapter_or_episode_cache_on_app_launch =>
      'Uygulama açıldığında bölüm/bölüm önbelleğini temizle';

  @override
  String get app_settings => 'Uygulama ayarları';

  @override
  String get sources_settings => 'Kaynak ayarları';

  @override
  String get include_sensitive_settings =>
      'Hassas ayarları dahil et (ör. izleyici giriş token\'ları)';

  @override
  String get create => 'Oluştur';

  @override
  String get downloads_are_limited_to_wifi =>
      'İndirmeler yalnızca Wi-Fi ile sınırlıdır';

  @override
  String get recommendations => 'Öneriler';

  @override
  String get recommendations_similar => 'benzer';

  @override
  String get recommendations_weights => 'Öneri ağırlıkları';

  @override
  String get recommendations_weights_genre => 'Tür benzerliği';

  @override
  String get recommendations_weights_setting => 'Ortam benzerliği';

  @override
  String get recommendations_weights_synopsis => 'Hikaye benzerliği';

  @override
  String get recommendations_weights_theme => 'Tema benzerliği';

  @override
  String get manga_extensions_repo => 'Manga uzantıları deposu';

  @override
  String get anime_extensions_repo => 'Anime uzantıları deposu';

  @override
  String get novel_extensions_repo => 'Roman uzantıları deposu';

  @override
  String get custom_dns =>
      'Özel DNS (sistem DNS\'ini kullanmak için boş bırakın)';

  @override
  String get android_proxy_server => 'Android Proxy Sunucusu (ApkBridge)';

  @override
  String get get_apk_bridge => 'ApkBridge\'i edinin';

  @override
  String get get_sync_server => 'Senkronizasyon Sunucusunu buradan alın';

  @override
  String get undefined => 'Tanımsız';

  @override
  String get empty_extensions_repo =>
      'Burada hiçbir depo URL\'si yok. Bir tane eklemek için artı düğmesine tıklayın!';

  @override
  String get add_extensions_repo => 'Depo URL\'si ekle';

  @override
  String get remove_extensions_repo => 'Depo URL\'sini kaldır';

  @override
  String get manage_manga_repo_urls => 'Manga depo URL\'lerini yönet';

  @override
  String get manage_anime_repo_urls => 'Anime depo URL\'lerini yönet';

  @override
  String get manage_novel_repo_urls => 'Roman depo URL\'lerini yönet';

  @override
  String get url_cannot_be_empty => 'URL boş olamaz';

  @override
  String get url_must_end_with_dot_json => 'URL .json ile bitmelidir';

  @override
  String get repo_url => 'Depo URL\'si';

  @override
  String get invalid_url_format => 'Geçersiz URL formatı';

  @override
  String get clear_all_sources => 'Tüm kaynakları temizle';

  @override
  String get clear_all_sources_msg =>
      'Bu, uygulamadaki tüm kaynakları tamamen temizleyecektir. Devam etmek istediğinizden emin misiniz?';

  @override
  String get sources_cleared => 'Kaynaklar temizlendi!';

  @override
  String get repo_added => 'Kaynak deposu eklendi!';

  @override
  String get add_repo => 'Depo ekle?';

  @override
  String get genre_search_library => 'Kütüphanede tür ara';

  @override
  String get genre_search_source => 'Kaynağı keşfet';

  @override
  String get source_not_added => 'Kaynak yüklenmedi!';

  @override
  String get load_own_subtitles => 'Kendi altyazılarınızı yükleyin...';

  @override
  String get search_subtitles => 'Çevrimiçi altyazı ara...';

  @override
  String extension_notes(Object notes) {
    return 'Notlar: $notes';
  }

  @override
  String get unsupported_repo =>
      'Desteklenmeyen bir depo eklemeye çalıştınız. Lütfen destek için discord sunucusunu kontrol edin!';

  @override
  String get end_of_chapter => 'Bölüm sonu';

  @override
  String get chapter_completed => 'Bölüm tamamlandı';

  @override
  String get continue_to_next_chapter =>
      'Bir sonraki bölümü okumak için kaydırmaya devam edin';

  @override
  String get no_next_chapter => 'Sonraki bölüm yok';

  @override
  String get you_have_finished_reading => 'Okumayı bitirdiniz';

  @override
  String get return_to_the_list_of_chapters => 'Bölüm listesine dön';

  @override
  String get hwdec => 'Donanım kod çözücü';

  @override
  String get enable_hardware_accel => 'Donanım hızlandırma';

  @override
  String get enable_hardware_accel_info =>
      'Hata veya çökmelerle karşılaşırsanız açın/kapatın';

  @override
  String get track_library_navigate => 'Mevcut yerel girişe git';

  @override
  String get track_library_add => 'Yerel kütüphaneye ekle';

  @override
  String get track_library_add_confirm =>
      'İzlenen öğeyi yerel kütüphaneye ekle';

  @override
  String get track_library_not_logged =>
      'Bu özelliği kullanmak için ilgili izleyicide oturum açın!';

  @override
  String get track_library_switch => 'Başka bir izleyiciye geç';

  @override
  String get go_back => 'Geri dön';

  @override
  String get merge_library_nav_mobile =>
      'Mobilde kütüphane gezinmesini birleştir';

  @override
  String get enable_discord_rpc => 'Discord RPC\'yi etkinleştir';

  @override
  String get hide_discord_rpc_incognito => 'Gizli modda Discord RPC\'yi gizle';

  @override
  String get rpc_show_reading_watching_progress =>
      'Discord\'da mevcut bölümü göster (yeniden başlatma gerektirir)';

  @override
  String get rpc_show_title => 'Discord\'da mevcut başlığı göster';

  @override
  String get rpc_show_cover_image => 'Discord\'da mevcut kapak resmini göster';

  @override
  String get sync_enable_histories => 'Geçmiş verilerini senkronize et';

  @override
  String get sync_enable_updates => 'Güncelleme verilerini senkronize et';

  @override
  String get sync_enable_settings => 'Ayarları senkronize et';

  @override
  String get enable_mpv => 'mpv gölgelendiricilerini / betiklerini etkinleştir';

  @override
  String get mpv_info => 'mpv/scripts/ altında .js betiklerini destekler';

  @override
  String get mpv_redownload => 'mpv yapılandırma dosyalarını yeniden indir';

  @override
  String get mpv_redownload_info =>
      'Eski yapılandırma dosyalarını yenileriyle değiştirir!';

  @override
  String get mpv_download =>
      'MPV yapılandırma dosyaları gerekli!\nŞimdi indir?';

  @override
  String get custom_buttons => 'Özel düğmeler';

  @override
  String get custom_buttons_info => 'Özel düğmelerle lua kodu çalıştır';

  @override
  String get custom_buttons_edit => 'Özel düğmeleri düzenle';

  @override
  String get custom_buttons_add => 'Özel düğme ekle';

  @override
  String get custom_buttons_added => 'Özel düğme eklendi!';

  @override
  String get custom_buttons_delete => 'Özel düğmeyi sil';

  @override
  String get custom_buttons_text => 'Düğme metni';

  @override
  String get custom_buttons_text_req => 'Düğme metni gerekli';

  @override
  String get custom_buttons_js_code => 'lua kodu';

  @override
  String get custom_buttons_js_code_req => 'lua kodu gerekli';

  @override
  String get custom_buttons_js_code_long => 'lua kodu (uzun basışta)';

  @override
  String get custom_buttons_startup => 'lua kodu (başlangıçta)';

  @override
  String n_days(Object n) {
    return '$n gün';
  }

  @override
  String get decoder => 'Kod çözücü';

  @override
  String get decoder_info => 'Donanım kod çözme, piksel formatı, debanding';

  @override
  String get enable_gpu_next => 'gpu-next\'i etkinleştir (sadece Android)';

  @override
  String get enable_gpu_next_info => 'Yeni video işleme motoru';

  @override
  String get debanding => 'Debanding';

  @override
  String get use_yuv420p => 'YUV420P piksel formatını kullan';

  @override
  String get use_yuv420p_info =>
      'Bazı video codec\'lerinde siyah ekranları düzeltebilir, kalite pahasına performansı da artırabilir';

  @override
  String get audio_preferred_languages => 'Tercih edilen diller';

  @override
  String get audio_preferred_languages_info =>
      'Birden fazla ses akışına sahip bir videoda varsayılan olarak seçilecek ses dil(ler)i, 2/3 harfli dil kodları (örn: tr, en, ja). Birden fazla değer virgülle ayrılabilir.';

  @override
  String get enable_audio_pitch_correction =>
      'Ses perdesi düzeltmeyi etkinleştir';

  @override
  String get enable_audio_pitch_correction_info =>
      'Daha yüksek hızlarda sesin tiz, daha düşük hızlarda pes olmasını önler';

  @override
  String get audio_channels => 'Ses kanalları';

  @override
  String get volume_boost_cap => 'Ses yükseltme sınırı';

  @override
  String get internal_player => 'Dahili oynatıcı';

  @override
  String get internal_player_info => 'İlerleme, kontroller, yönelim';

  @override
  String get subtitle_delay_text => 'Altyazı gecikmesi';

  @override
  String get subtitle_delay => 'Gecikme (ms)';

  @override
  String get subtitle_speed => 'Hız';

  @override
  String get calendar => 'Takvim';

  @override
  String get schedule => 'Planning';

  @override
  String get calendar_no_data => 'Henüz veri yok.';

  @override
  String get calendar_info =>
      'Takvim, bir sonraki bölüm yüklemesini yalnızca eski yüklemelere göre tahmin edebilir. Bazı veriler %100 doğru olmayabilir!';

  @override
  String in_n_day(Object days) {
    return '$days gün içinde';
  }

  @override
  String in_n_days(Object days) {
    return '$days gün içinde';
  }

  @override
  String get clear_library => 'Kütüphaneyi temizle';

  @override
  String get clear_library_desc =>
      'Tüm manga, anime ve/veya roman girişlerini temizlemeyi seçin';

  @override
  String get clear_library_input =>
      'İlgili tüm girişleri kaldırmak için \'manga\', \'anime\' ve/veya \'novel\' yazın (virgülle ayrılmış)';

  @override
  String get watch_order => 'İzleme sırası';

  @override
  String get sequels => 'Devam filmleri';

  @override
  String get recommendations_similarity => 'Benzerlik:';

  @override
  String get local_folder_structure => 'Yerel klasör yapısı';

  @override
  String get local_folder => 'Yerel klasörler';

  @override
  String get add_local_folder => 'Yerel klasör ekle';

  @override
  String get rescan_local_folder => 'Tüm yerel klasörleri şimdi yeniden tara';

  @override
  String get export_metadata => 'Meta verileri dışa aktar';

  @override
  String get exported => 'Dışa aktarıldı';

  @override
  String get text_size => 'Metin Boyutu:';

  @override
  String get text_align => 'Metin Hizalama';

  @override
  String get line_height => 'Satır Yüksekliği';

  @override
  String get show_scroll_percentage => 'Kaydırma Yüzdesini Göster';

  @override
  String get remove_extra_paragraph_spacing =>
      'Ekstra Paragraf Aralığını Kaldır';

  @override
  String select_label_color(Object label) {
    return '$label Rengini Seç';
  }

  @override
  String get default_user_agent => 'Varsayılan Kullanıcı Aracısı';

  @override
  String get forceLandscapeMode => 'Yatay Modu Zorla';

  @override
  String get forceLandscapeModeSubtitle =>
      'Oynatıcıyı yatay yönelim kullanmaya zorla.';

  @override
  String get dns_over_https => 'DNS-over-HTTPS (DoH)';

  @override
  String get dns_provider => 'DNS Sağlayıcısı';

  @override
  String get tracked => 'İzlendi';

  @override
  String get auth_unlock_msg =>
      'Mangayomi\'yi kilitlemek için kimliğinizi doğrulayın';

  @override
  String get app_locked => 'Mangayomi kilitli';

  @override
  String get auth_to_continue => 'Devam etmek için kimliğinizi doğrulayın';

  @override
  String get authenticating => 'Kimlik doğrulanıyor...';

  @override
  String get unlock => 'Kilit Aç';

  @override
  String get security => 'Güvenlik';

  @override
  String get auth_to_change_security_setting =>
      'Güvenlik ayarlarını değiştirmek için kimliğinizi doğrulayın';

  @override
  String get app_lock => 'Uygulama Kilidi';

  @override
  String get require_biometric_or_device_credential =>
      'Uygulamayı açmak için biyometrik kimlik doğrulamak veya cihaz kimlik bilgileri gerekir';

  @override
  String get biometric_or_device_credential_not_available =>
      'Biyometrik kimlik doğrulama bu cihazda kullanılamaz';

  @override
  String get app_lock_description =>
      'Uygulama kilidi etkinleştirildiğinde, uygulamayı her açtığınızda veya arka plandan döndüğünüzde kimlik doğrulaması yapmanız istenir.';

  @override
  String get keep_screen_on => 'Ekranı Açık Tut';

  @override
  String get webtoon_side_padding => 'Webtoon Yan Dolgusu';

  @override
  String get show_page_gaps => 'Sayfa Boşluklarını Göster';

  @override
  String get invert_colors => 'Renkleri Ters Çevir';

  @override
  String get grayscale => 'Gri Tonlama';

  @override
  String get brightness => 'Parlaklık';

  @override
  String get contrast => 'Kontrast';

  @override
  String get saturation => 'Doyum';

  @override
  String get navigation_layout => 'Navigasyon Düzeni';

  @override
  String get nav_layout_default => 'Varsayılan';

  @override
  String get nav_layout_l_shaped => 'L Şekil';

  @override
  String get nav_layout_kindle => 'Kindle';

  @override
  String get nav_layout_edge => 'Kenar';

  @override
  String get nav_layout_right_and_left => 'Sağ ve Sol';

  @override
  String get nav_layout_disabled => 'Devre Dışı';

  @override
  String get color_enhancements => 'Renk İyileştirmeleri';

  @override
  String get total => 'Toplam';

  @override
  String get mean_per_title => 'Başlık başına ortalama';

  @override
  String get completion_rate => 'Tamamlanma oranı';

  @override
  String get watching_time => 'İzleme süresi';

  @override
  String get reading_time => 'Okuma süresi';

  @override
  String average_chapters_per_title(Object title) {
    return 'Başlık başına ortalama bölüm';
  }

  @override
  String get read_percentage => 'Okuma yüzdesi';

  @override
  String get entries => 'Girdiler';

  @override
  String get android_proxy_server_mihon => 'Android Proxy Sunucusu (Mihon)';

  @override
  String get android_proxy_server_mihon_description =>
      'Mihon eklentilerini kullanmak için gereken proxy sunucusunu indirin ve yapılandırın.';

  @override
  String get mihon_proxy_server => 'Mihon proxy sunucusu';

  @override
  String get extension_server_intro_with_jre =>
      'Mihon eklentilerini kullanmadan önce proxy sunucu paketini indirin. Paket, JRE ve eklenti sunucusu JAR dosyasını içerir.';

  @override
  String get extension_server_intro_ios =>
      'Mihon eklentilerini kullanmadan önce proxy sunucusu JAR dosyasını indirin. iOS için sadece eklenti sunucusu JAR dosyası gereklidir.';

  @override
  String get checking_files => 'Dosyalar kontrol ediliyor';

  @override
  String get files_installed => 'Dosyalar yüklendi';

  @override
  String get files_missing => 'Dosyalar eksik';

  @override
  String get update_files => 'Dosyaları güncelle';

  @override
  String get up_to_date => 'Güncel';

  @override
  String get choose_location => 'Konum seç';

  @override
  String get import_existing_jar => 'Mevcut JAR dosyasını içe aktar';

  @override
  String get detect_files_in_selected_folder =>
      'Seçilen klasördeki dosyaları algıla';

  @override
  String get preparing_download => 'İndirme hazırlanıyor...';

  @override
  String get app_install_location => 'Uygulama yükleme konumu';

  @override
  String get install_location => 'Yükleme konumu';

  @override
  String get jre_executable => 'JRE yürütülebilir dosyası';

  @override
  String get extension_server_jar => 'Eklenti sunucusu JAR\'ı';

  @override
  String get installed_version => 'Yüklü sürüm';

  @override
  String get latest_version => 'Son sürüm';

  @override
  String get apkbridge_description =>
      'Ayrı bir Android cihaz proxy\'sine ihtiyacınız olduğunda ApkBridge kullanın. Proxy adresini buradan ayarlayın ve APK\'yı GitHub\'dan indirin.';

  @override
  String get set_proxy_address => 'Proxy adresini ayarla';

  @override
  String get no_newer_proxy_server_release_available =>
      'Daha yeni bir proxy sunucusu sürümü mevcut değil.';

  @override
  String get could_not_check_proxy_server_updates =>
      'Proxy sunucusu güncellemeleri kontrol edilemedi.';

  @override
  String get no_extension_server_bundle_available_for_this_platform =>
      'Bu platform için sunucu paketi mevcut değil.';

  @override
  String failed_to_download_bundle(Object statusCode) {
    return 'Paket indirme başarısız oldu ($statusCode).';
  }

  @override
  String get downloaded_bundle_missing_expected_files =>
      'İndirilen paket beklenen dosyaları içermiyor.';

  @override
  String get extension_server_files_ready =>
      'Eklenti sunucusu dosyaları hazır.';

  @override
  String get ios_extension_server_import_hint =>
      'iOS\'ta sunucu uygulama sandbox\'ı içine yüklenir. İndirilen bir dosyayı getirmek için \"Mevcut JAR dosyasını içe aktar\" seçeneğini kullanın.';

  @override
  String get select_extension_server_folder =>
      'Eklenti sunucusu klasörünü seçin';

  @override
  String get selected_folder_does_not_exist => 'Seçilen klasör mevcut değil.';

  @override
  String get no_extension_server_files_found_in_selected_folder =>
      'Seçilen klasörde eklenti sunucusu dosyası bulunamadı.';

  @override
  String get extension_server_files_linked =>
      'Eklenti sunucusu dosyaları bağlandı.';

  @override
  String get select_extension_server_jar =>
      'Eklenti sunucusu JAR dosyasını seçin';

  @override
  String get selected_file_could_not_be_accessed =>
      'Seçilen dosyaya erişilemedi.';

  @override
  String get extension_server_jar_imported =>
      'Eklenti sunucusu JAR\'ı içe aktarıldı.';

  @override
  String get could_not_launch_apk_bridge_page =>
      'ApkBridge sayfası başlatılamadı.';

  @override
  String get proxy_server_ip_hint =>
      'Sunucu IP\'si (örn. 10.0.0.5 veya https://example.com)';

  @override
  String get not_configured => 'Yapılandırılmadı';

  @override
  String get webview => 'Webview';

  @override
  String get tts => 'Metinden Sese';

  @override
  String get tts_speed => 'Hız';

  @override
  String get tts_pitch => 'Perde';

  @override
  String get tts_language => 'Dil';

  @override
  String get tts_voice => 'Ses';

  @override
  String get tts_stop => 'Durdur';

  @override
  String get tts_play => 'Oynat';

  @override
  String get tts_pause => 'Duraklat';

  @override
  String get tts_previous => 'Önceki paragraf';

  @override
  String get tts_next => 'Sonraki paragraf';

  @override
  String tts_paragraph_progress(Object current, Object total) {
    return 'Paragraf $current / $total';
  }

  @override
  String get tts_settings => 'TTS Ayarları';

  @override
  String get tts_default => 'Varsayılan';

  @override
  String get view_all => 'View all';

  @override
  String get for_you => 'For you';

  @override
  String get following_tab => 'Following';

  @override
  String get explore_tab => 'Explore';

  @override
  String get browser_dock_tabs => 'Sekmeler';

  @override
  String get browser_dock_new_tab => 'Yeni sekme';

  @override
  String get browser_dock_more => 'Diğer seçenekler';

  @override
  String get browser_dock_collapse => 'Çubuğu daralt';

  @override
  String get browser_dock_expand => 'Çubuğu göster';

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
  String get browse_custom_sections => 'Bölümlerim';

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
  String get transfer_title => 'Paylaşım odası';

  @override
  String get transfer_subtitle =>
      'İndirmelerinizi aynı WiFi ağındaki diğer cihazlarla internet olmadan paylaşın.';

  @override
  String transfer_chapters_available(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Paylaşılacak $count bölüm var',
      one: 'Paylaşılacak 1 bölüm var',
    );
    return '$_temp0';
  }

  @override
  String get transfer_join_room => 'ODAYA KATIL';

  @override
  String get transfer_lan_only => 'Yalnızca LAN / hotspot · harici sunucu yok';

  @override
  String get transfer_devices_in_room => 'Odadaki cihazlar';

  @override
  String get transfer_active_downloads => 'Devam eden indirmeler';

  @override
  String get transfer_completed => 'Tamamlandı';

  @override
  String transfer_started_download(num count) {
    return '$count dosyanın indirilmesi başladı';
  }

  @override
  String get transfer_local_room => 'Yerel oda';

  @override
  String get transfer_active => 'ETKİN';

  @override
  String get transfer_my_device => 'Cihazım';

  @override
  String get transfer_me => 'Ben';

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
      other: '$chapterCount bölüm',
      one: '1 bölüm',
    );
    return '$_temp0 · $_temp1 paylaşıldı';
  }

  @override
  String get transfer_searching_devices => 'Cihazlar aranıyor…';

  @override
  String get transfer_same_wifi_hint =>
      'Diğer cihazlarla aynı WiFi veya hotspotta olduğunuzdan emin olun.';

  @override
  String get transfer_loading_catalog => 'Katalog yükleniyor…';

  @override
  String get transfer_catalog_unavailable => 'Katalog kullanılamıyor';

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
      other: '$chapterCount bölüm',
      one: '1 bölüm',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transfer_browse => 'Gözat';

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
  String get transfer_status_done => 'Tamamlandı';

  @override
  String get transfer_status_failed => 'Başarısız';

  @override
  String get transfer_catalog_empty => 'Boş katalog';

  @override
  String get transfer_no_files => 'Kullanılabilir dosya yok';

  @override
  String get transfer_select_chapters => 'Bölümleri seç';

  @override
  String transfer_download_count(Object count) {
    return 'İndir ($count)';
  }

  @override
  String get transfer_type_anime => 'ANIME';

  @override
  String get transfer_type_novel => 'ROMAN';

  @override
  String get transfer_type_other => 'DİĞER';

  @override
  String get transfer_type_manga => 'MANGA';

  @override
  String get transfer_howto_title => 'Nasıl aktarılır';

  @override
  String get transfer_howto_step1 =>
      'Her iki cihazı da aynı WiFi ağına veya hotspotta bağlayın.';

  @override
  String get transfer_howto_step2 =>
      'Diğer cihazda İndirmeler → Transfert yolunu açıp odaya katılın.';

  @override
  String get transfer_howto_step3 =>
      'Kitaplığına göz atmak için bir cihaza dokunun, bölümleri seçip indirin.';

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
  String get transfer_platform_unknown => 'Cihaz';

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
}
