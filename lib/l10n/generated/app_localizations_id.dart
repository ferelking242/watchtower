// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get library => 'Perpustakaan';

  @override
  String get updates => 'Pembaruan';

  @override
  String get history => 'Riwayat';

  @override
  String get browse => 'Jelajahi';

  @override
  String get more => 'Lainnya';

  @override
  String get open_random_entry => 'Buka Entri Acak';

  @override
  String get import => 'Impor';

  @override
  String get filter => 'Filter';

  @override
  String get ignore_filters => 'Abaikan filter';

  @override
  String get downloaded => 'Telah Diunduh';

  @override
  String get unread => 'Belum Dibaca';

  @override
  String get unwatched => 'Belum ditonton';

  @override
  String get started => 'Dimulai';

  @override
  String get bookmarked => 'Ditandai';

  @override
  String get sort => 'Urutkan';

  @override
  String get alphabetically => 'Secara Abjad';

  @override
  String get last_read => 'Bacaan Terakhir';

  @override
  String get last_watched => 'Terakhir ditonton';

  @override
  String get last_update_check => 'Pemeriksaan Pembaruan Terakhir';

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
          'Kamu sedang menghapus semua $count $entryTypePlural dari $mediaType ini di perpustakaan kamu.',
      one:
          'Kamu sedang menghapus satu-satunya $entryType dari $mediaType ini di perpustakaan kamu.',
    );
    return '$_temp0\nIni juga akan menghapus seluruh $mediaType dari perpustakaanmu.\n\nCatatan: File-nya sendiri tidak akan dihapus.';
  }

  @override
  String get chapter => 'bab';

  @override
  String get episode => 'episode';

  @override
  String get unread_count => 'Jumlah Belum Dibaca';

  @override
  String get unwatched_count => 'Jumlah belum ditonton';

  @override
  String get latest_chapter => 'Bab Terbaru';

  @override
  String get latest_episode => 'Episode terbaru';

  @override
  String get date_added => 'Tanggal Ditambahkan';

  @override
  String get display => 'Tampilan';

  @override
  String get display_mode => 'Mode Tampilan';

  @override
  String get compact_grid => 'Grid Kompak';

  @override
  String get compression_level => 'Tingkat kompresi';

  @override
  String compression_info(Object level) {
    return 'Semakin tinggi kompresi, semakin sedikit ruang yang digunakan file backup, tetapi menggunakan lebih banyak CPU. Default: $level';
  }

  @override
  String get comfortable_grid => 'Grid Nyaman';

  @override
  String get cover_only_grid => 'Grid Hanya Sampul';

  @override
  String get list => 'Daftar';

  @override
  String get badges => 'Lencana';

  @override
  String get downloaded_chapters => 'Bab yang Diunduh';

  @override
  String get downloaded_episodes => 'Episode yang diunduh';

  @override
  String get language => 'Bahasa';

  @override
  String get local_source => 'Sumber Lokal';

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
  String get tabs => 'Tab';

  @override
  String get show_category_tabs => 'Tampilkan Tab Kategori';

  @override
  String get show_numbers_of_items => 'Tampilkan Jumlah Item';

  @override
  String get other => 'Lainnya';

  @override
  String get show_continue_reading_buttons =>
      'Tampilkan Tombol Lanjutkan Membaca';

  @override
  String get show_continue_watching_buttons =>
      'Tampilkan tombol lanjut menonton';

  @override
  String get empty_library => 'Perpustakaan Kosong';

  @override
  String get search => 'Cari...';

  @override
  String get no_recent_updates => 'Tidak Ada Pembaruan Terbaru';

  @override
  String get remove_everything => 'Hapus Semua';

  @override
  String get remove_everything_msg =>
      'Apakah Anda yakin? Semua riwayat akan hilang';

  @override
  String get remove_all_update_msg =>
      'Apakah Anda yakin? Seluruh pembaruan akan dihapus';

  @override
  String get ok => 'Baik';

  @override
  String get cancel => 'Batal';

  @override
  String get remove => 'Hapus';

  @override
  String get remove_history_msg =>
      'Riwayat bacaan untuk bab ini akan dihapus. Apakah Anda yakin?';

  @override
  String get last_used => 'Terakhir Digunakan';

  @override
  String get pinned => 'Ditandai';

  @override
  String get sources => 'Sumber';

  @override
  String get install => 'Pasang';

  @override
  String get update => 'Perbarui';

  @override
  String get latest => 'Terbaru';

  @override
  String get extensions => 'Ekstensi';

  @override
  String get migrate => 'Migrasi';

  @override
  String get mass_migration_title => 'Migrasi massal';

  @override
  String get mass_migration_preview_items => 'Pratinjau item';

  @override
  String get mass_migration_destination_source => 'Sumber tujuan';

  @override
  String get mass_migration_no_library_items =>
      'Tidak ada item pustaka yang tersedia untuk migrasi massal.';

  @override
  String get mass_migration_no_destination_sources =>
      'Tidak ada sumber tujuan terpasang yang tersedia.';

  @override
  String get mass_migration_installed => 'Terpasang';

  @override
  String mass_migration_items_ready_for_review(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item siap ditinjau',
      one: '1 item siap ditinjau',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_item_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_select_destination_source => 'Pilih sumber tujuan';

  @override
  String mass_migration_finding_matches(Object source, Object language) {
    return 'Mencari kecocokan di $source • $language';
  }

  @override
  String mass_migration_processing_item(int current, int total) {
    return 'Memproses item $current dari $total';
  }

  @override
  String get mass_migration_waiting_next_item =>
      'Menunggu 2 detik sebelum item berikutnya...';

  @override
  String get mass_migration_waiting_next_migration =>
      'Menunggu 2 detik sebelum migrasi berikutnya...';

  @override
  String mass_migration_matched_so_far(int count) {
    return 'Cocok sejauh ini: $count';
  }

  @override
  String mass_migration_no_match_count(int count) {
    return 'Tidak ada kecocokan: $count';
  }

  @override
  String mass_migration_review_matches(Object source) {
    return 'Tinjau kecocokan untuk $source';
  }

  @override
  String mass_migration_found_matches(int count) {
    return 'Kecocokan ditemukan: $count';
  }

  @override
  String mass_migration_no_matches(int count) {
    return 'Tidak ada kecocokan: $count';
  }

  @override
  String mass_migration_selected_to_migrate(int count) {
    return 'Dipilih untuk migrasi: $count';
  }

  @override
  String get mass_migration_finish_review => 'Selesai meninjau';

  @override
  String mass_migration_migrate_selected(int count) {
    return 'Migrasi item terpilih ($count)';
  }

  @override
  String mass_migration_migrating_selected(Object source) {
    return 'Memigrasi item terpilih ke $source';
  }

  @override
  String get mass_migration_no_items_selected =>
      'Tidak ada item yang dipilih untuk migrasi.';

  @override
  String mass_migration_migrating_item(int current, int total) {
    return 'Memigrasi item $current dari $total';
  }

  @override
  String get mass_migration_complete => 'Migrasi massal selesai';

  @override
  String get mass_migration_complete_success_message =>
      'Semua item terpilih berhasil diproses.';

  @override
  String get mass_migration_complete_partial_message =>
      'Migrasi selesai dengan beberapa item yang masih memerlukan perhatian manual.';

  @override
  String mass_migration_route_summary(Object source, Object destination) {
    return '$source → $destination';
  }

  @override
  String get mass_migration_processed => 'Diproses';

  @override
  String get mass_migration_matched => 'Cocok';

  @override
  String get mass_migration_migrated => 'Dimigrasikan';

  @override
  String get mass_migration_skipped => 'Dilompati';

  @override
  String get mass_migration_failed => 'Gagal';

  @override
  String get mass_migration_failed_items => 'Item Gagal';

  @override
  String get mass_migration_exit => 'Keluar dari Migrasi Massal';

  @override
  String get mass_migration_no_destination_match =>
      'Tidak ditemukan kecocokan tujuan';

  @override
  String mass_migration_query(Object query) {
    return 'Kueri: $query';
  }

  @override
  String get mass_migration_skip => 'Lompati';

  @override
  String get mass_migration_loading => 'Memuat...';

  @override
  String get mass_migration_choose_another_result => 'Pilih hasil lain';

  @override
  String get mass_migration_source_chapters => 'Bab sumber';

  @override
  String get mass_migration_destination_chapters => 'Bab tujuan';

  @override
  String mass_migration_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bab',
      one: '1 bab',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_source_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bab sumber',
      one: '1 bab sumber',
    );
    return '$_temp0';
  }

  @override
  String mass_migration_destination_chapter_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bab tujuan',
      one: '1 bab tujuan',
    );
    return '$_temp0';
  }

  @override
  String get mass_migration_no_chapters_found => 'Tidak ada bab ditemukan.';

  @override
  String mass_migration_and_more_chapters(int count) {
    return 'Dan $count lagi...';
  }

  @override
  String get mass_migration_unknown_title => 'Judul tidak dikenal';

  @override
  String get mass_migration_unknown_match => 'Kecocokan tidak dikenal';

  @override
  String get mass_migration_unknown_source => 'Sumber tidak dikenal';

  @override
  String get mass_migration_unknown_chapter => 'Bab tidak dikenal';

  @override
  String get migrate_confirm => 'Migrasi ke sumber lain';

  @override
  String get clean_database => 'Bersihkan basis data';

  @override
  String cleaned_database(Object x) {
    return 'Basis data dibersihkan! $x entri dihapus';
  }

  @override
  String get clean_database_desc =>
      'Ini akan menghapus semua item yang tidak ditambahkan ke perpustakaan!';

  @override
  String get incognito_mode => 'Mode Incognito';

  @override
  String get incognito_mode_description => 'Menghentikan catatan bacaan';

  @override
  String get downloaded_only => 'Hanya yang diunduh';

  @override
  String get downloaded_only_description =>
      'Hanya tampilkan entri yang diunduh di perpustakaan Anda';

  @override
  String get download_queue => 'Antrian Unduhan';

  @override
  String get categories => 'Kategori';

  @override
  String get statistics => 'Statistik';

  @override
  String get settings => 'Pengaturan';

  @override
  String get about => 'Tentang';

  @override
  String get help => 'Bantuan';

  @override
  String get no_downloads => 'Tidak Ada Unduhan';

  @override
  String get edit_categories => 'Edit Kategori';

  @override
  String get edit_categories_description =>
      'Anda belum memiliki kategori. Tekan tombol tambah untuk membuat satu dan mengatur perpustakaan Anda';

  @override
  String get add => 'Tambah';

  @override
  String get add_category => 'Tambah Kategori';

  @override
  String get name => 'Nama';

  @override
  String get category_name_required => '*Diperlukan';

  @override
  String get add_category_error_exist => 'Kategori dengan nama ini sudah ada!';

  @override
  String get delete_category => 'Hapus Kategori';

  @override
  String delete_category_msg(Object name) {
    return 'Apakah Anda ingin menghapus kategori $name?';
  }

  @override
  String get rename_category => 'Ubah Nama Kategori';

  @override
  String get general => 'Umum';

  @override
  String get general_subtitle => 'Bahasa Aplikasi';

  @override
  String get app_language => 'Bahasa Aplikasi';

  @override
  String get default_subtitle_language => 'Bahasa subtitle default';

  @override
  String get appearance => 'Tampilan';

  @override
  String get appearance_subtitle => 'Tema, Format Tanggal dan Waktu';

  @override
  String get theme => 'Tema';

  @override
  String get dark_mode => 'Mode Gelap';

  @override
  String get follow_system_theme => 'Ikuti tema sistem';

  @override
  String get on => 'Aktif';

  @override
  String get off => 'Nonaktif';

  @override
  String get pure_black_dark_mode => 'Mode Gelap Hitam Murni';

  @override
  String get timestamp => 'Cap Waktu';

  @override
  String get relative_timestamp => 'Cap Waktu Relatif';

  @override
  String get relative_timestamp_short => 'Singkat (Hari Ini, Kemarin)';

  @override
  String get relative_timestamp_long =>
      'Panjang (Singkat+, Beberapa Hari Lalu)';

  @override
  String get date_format => 'Format Tanggal';

  @override
  String get reader => 'Pembaca';

  @override
  String get reader_manga => 'Manga reader';

  @override
  String get refresh => 'Segarkan';

  @override
  String get reader_subtitle => 'Mode Baca, Tampilan, Navigasi';

  @override
  String get default_reading_mode => 'Mode Baca Default';

  @override
  String get reading_mode_vertical => 'Vertikal';

  @override
  String get reading_mode_horizontal => 'Horizontal';

  @override
  String get reading_mode_left_to_right => 'Dari Kiri ke Kanan';

  @override
  String get reading_mode_right_to_left => 'Dari Kanan ke Kiri';

  @override
  String get reading_mode_vertical_continuous => 'Vertikal Berkelanjutan';

  @override
  String get reading_mode_webtoon => 'Webtoon';

  @override
  String get double_tap_animation_speed => 'Kecepatan Animasi Double Tap';

  @override
  String get normal => 'Normal';

  @override
  String get fast => 'Cepat';

  @override
  String get no_animation => 'Tanpa Animasi';

  @override
  String get animate_page_transitions => 'Animasikan Transisi Halaman';

  @override
  String get crop_borders => 'Potong Batas';

  @override
  String get downloads => 'Unduhan';

  @override
  String get downloads_subtitle => 'Pengaturan Unduhan';

  @override
  String get download_location => 'Lokasi Unduhan';

  @override
  String get custom_location => 'Lokasi Khusus';

  @override
  String get only_on_wifi => 'Hanya di Wi-Fi';

  @override
  String get save_as_cbz_archive => 'Simpan sebagai Arsip CBZ';

  @override
  String get delete_download_after_reading => 'Hapus unduhan setelah dibaca';

  @override
  String get concurrent_downloads => 'Unduhan bersamaan';

  @override
  String get browse_subtitle => 'Sumber, Pencarian Umum';

  @override
  String get only_include_pinned_sources =>
      'Hanya Sertakan Sumber yang Ditandai';

  @override
  String get nsfw_sources => 'Sumber NSFW (+18)';

  @override
  String get nsfw_sources_show => 'Tampilkan di Daftar Sumber dan Ekstensi';

  @override
  String get nsfw_sources_info =>
      'Ini tidak menghentikan ekstensi tidak resmi atau yang salah klasifikasi dari menampilkan konten NSFW (18+) dalam aplikasi';

  @override
  String get version => 'Versi';

  @override
  String get check_for_update => 'Periksa Pembaruan';

  @override
  String get logs_on => 'Aktifkan pencatatan';

  @override
  String get share_app_logs => 'Bagikan log aplikasi';

  @override
  String get no_app_logs => 'Tidak ada file log.txt tersedia!';

  @override
  String get failed => 'Gagal!';

  @override
  String n_days_ago(Object days) {
    return '$days Hari yang Lalu';
  }

  @override
  String get today => 'Hari Ini';

  @override
  String get yesterday => 'Kemarin';

  @override
  String get a_week_ago => 'Seminggu yang Lalu';

  @override
  String get next_week => 'Minggu depan';

  @override
  String get add_to_library => 'Tambahkan ke Perpustakaan';

  @override
  String get added_to_library => 'Added to library';

  @override
  String get completed => 'Selesai';

  @override
  String get ongoing => 'Berlangsung';

  @override
  String get on_hiatus => 'Ditunda';

  @override
  String get canceled => 'Dibatalkan';

  @override
  String get publishing_finished => 'Penerbitan selesai';

  @override
  String get unknown => 'Tidak diketahui';

  @override
  String get set_categories => 'Tetapkan kategori';

  @override
  String get edit => 'Edit';

  @override
  String get in_library => 'Di perpustakaan';

  @override
  String get filter_scanlator_groups => 'Saring grup scanlator';

  @override
  String get reset => 'Atur ulang';

  @override
  String get by_source => 'Berdasarkan sumber';

  @override
  String get by_chapter_number => 'Berdasarkan nomor bab';

  @override
  String get by_episode_number => 'Menurut nomor episode';

  @override
  String get by_upload_date => 'Berdasarkan tanggal unggah';

  @override
  String get source_title => 'Judul sumber';

  @override
  String get chapter_number => 'Nomor bab';

  @override
  String get episode_number => 'Nomor episode';

  @override
  String get share => 'Bagikan';

  @override
  String n_chapters(Object n) {
    return '$n bab';
  }

  @override
  String get no_description => 'Tidak ada deskripsi';

  @override
  String get resume => 'Lanjutkan';

  @override
  String get read => 'Baca';

  @override
  String get watch => 'Tonton';

  @override
  String get popular => 'Populer';

  @override
  String get open_in_browser => 'Buka di peramban';

  @override
  String get clear_cookie => 'Bersihkan cookie';

  @override
  String get show_page_number => 'Tampilkan nomor halaman';

  @override
  String get from_library => 'Dari perpustakaan';

  @override
  String get downloaded_chapter => 'Bab yang diunduh';

  @override
  String page(Object page) {
    return 'Halaman $page';
  }

  @override
  String get global_search => 'Pencarian global';

  @override
  String get color_blend_level => 'Tingkat campuran warna';

  @override
  String current(Object char) {
    return 'Saat ini $char';
  }

  @override
  String finished(Object char) {
    return 'Selesai $char';
  }

  @override
  String next(Object char) {
    return 'Selanjutnya $char';
  }

  @override
  String previous(Object char) {
    return 'Sebelumnya $char';
  }

  @override
  String get no_more_chapter => 'Tidak ada lagi bab';

  @override
  String get no_result => 'Tidak ada hasil';

  @override
  String get send => 'Kirim';

  @override
  String get delete => 'Hapus';

  @override
  String get start_downloading => 'Mulai mengunduh sekarang';

  @override
  String get retry => 'Coba lagi';

  @override
  String get add_chapters => 'Tambahkan Bab';

  @override
  String get delete_chapters => 'Hapus Bab?';

  @override
  String get default0 => 'Bawaan';

  @override
  String get total_chapters => 'Total Bab';

  @override
  String get total_episodes => 'Total episode';

  @override
  String get import_local_file => 'Impor File Lokal';

  @override
  String get import_files => 'File';

  @override
  String get split_epub_chapters => 'Bagi menjadi bab';

  @override
  String get split_epub_chapters_description =>
      'Impor setiap bab EPUB sebagai entri terpisah';

  @override
  String get nothing_read_recently => 'Tidak ada yang dibaca baru-baru ini';

  @override
  String get status => 'Status';

  @override
  String get not_started => 'Belum dimulai';

  @override
  String get score => 'Skor';

  @override
  String get start_date => 'Tanggal mulai';

  @override
  String get finish_date => 'Tanggal selesai';

  @override
  String get reading => 'Membaca';

  @override
  String get on_hold => 'Ditunda';

  @override
  String get dropped => 'Dihentikan';

  @override
  String get plan_to_read => 'Rencana untuk membaca';

  @override
  String get re_reading => 'Membaca ulang';

  @override
  String get chapters => 'Bab';

  @override
  String get add_tracker => 'Tambah pelacak';

  @override
  String get one_tracker => '1 pelacak';

  @override
  String n_tracker(Object n) {
    return '$n pelacak';
  }

  @override
  String get tracking => 'Pelacakan';

  @override
  String get syncing => 'Sinkronisasi';

  @override
  String get sync_password => 'Kata sandi (minimal 8 karakter)';

  @override
  String get sync_logged => 'Berhasil masuk';

  @override
  String get syncing_subtitle =>
      'Sinkronkan kemajuan Anda di beberapa perangkat melalui \nserver yang dihosting sendiri. Lihat server discord kami untuk info lebih lanjut!';

  @override
  String get last_sync_manga => 'Sinkronisasi manga terakhir di:';

  @override
  String get last_sync_history => 'Sinkronisasi riwayat terakhir pada:';

  @override
  String get last_sync_update => 'Sinkronisasi pembaruan terakhir pada:';

  @override
  String get sync_server => 'Alamat Server Sinkronisasi';

  @override
  String get sync_login_invalid_creds => 'Email atau kata sandi tidak valid';

  @override
  String get sync_starting => 'Memulai sinkronisasi...';

  @override
  String get sync_finished => 'Sinkronisasi selesai';

  @override
  String get sync_failed => 'Sinkronisasi gagal';

  @override
  String get sync_button_sync => 'Sinkronkan progres';

  @override
  String get sync_button_upload => 'Hanya unggah';

  @override
  String get sync_button_upload_info =>
      'Operasi ini akan sepenuhnya menggantikan data jarak jauh dengan data lokal!';

  @override
  String get sync_button_download => 'Hanya unduh';

  @override
  String get sync_button_download_info =>
      'Operasi ini akan sepenuhnya menggantikan data lokal dengan data jarak jauh!';

  @override
  String get sync_on => 'Aktifkan sinkronisasi';

  @override
  String get sync_auto => 'Sinkronisasi otomatis';

  @override
  String get sync_auto_warning =>
      'Sinkronisasi otomatis saat ini adalah fitur eksperimental!';

  @override
  String get sync_auto_off => 'Mati';

  @override
  String get sync_auto_5_minutes => 'Setiap 5 menit';

  @override
  String get sync_auto_10_minutes => 'Setiap 10 menit';

  @override
  String get sync_auto_30_minutes => 'Setiap 30 menit';

  @override
  String get sync_auto_1_hour => 'Setiap 1 jam';

  @override
  String get sync_auto_3_hours => 'Setiap 3 jam';

  @override
  String get sync_auto_6_hours => 'Setiap 6 jam';

  @override
  String get sync_auto_12_hours => 'Setiap 12 jam';

  @override
  String get server_error => 'Kesalahan server!';

  @override
  String get dialog_confirm => 'Konfirmasi';

  @override
  String get description => 'Deskripsi';

  @override
  String get reorder_navigation => 'Sesuaikan navigasi';

  @override
  String get reorder_navigation_description =>
      'Atur ulang dan sesuaikan setiap navigasi sesuai kebutuhan Anda.';

  @override
  String get full_screen_player => 'Gunakan Layar Penuh';

  @override
  String get full_screen_player_info =>
      'Otomatis gunakan layar penuh saat memutar video.';

  @override
  String episode_progress(Object n) {
    return 'Kemajuan: $n';
  }

  @override
  String n_episodes(Object n) {
    return '$n episode';
  }

  @override
  String get manga_sources => 'Sumber Manga';

  @override
  String get anime_sources => 'Sumber Anime';

  @override
  String get novel_sources => 'Sumber Novel';

  @override
  String get anime_extensions => 'Ekstensi Anime';

  @override
  String get manga_extensions => 'Ekstensi Manga';

  @override
  String get novel_extensions => 'Ekstensi Novel';

  @override
  String get extension_settings => 'Pengaturan ekstensi';

  @override
  String get anime => 'Anime';

  @override
  String get manga => 'Manga';

  @override
  String get novel => 'Novel';

  @override
  String get library_no_category_exist => 'Anda belum memiliki kategori';

  @override
  String get watching => 'Menonton';

  @override
  String get plan_to_watch => 'Rencana untuk menonton';

  @override
  String get re_watching => 'Menonton ulang';

  @override
  String get episodes => 'Episode';

  @override
  String get download => 'Unduh';

  @override
  String get new_update_available => 'Pembaruan baru tersedia';

  @override
  String app_version(Object v) {
    return 'Versi Aplikasi : v$v';
  }

  @override
  String get searching_for_updates => 'Mencari pembaruan...';

  @override
  String get no_new_updates_available => 'Tidak ada pembaruan baru';

  @override
  String get uninstall => 'Copot pemasangan';

  @override
  String uninstall_extension(Object ext) {
    return 'Copot pemasangan ekstensi $ext?';
  }

  @override
  String get langauage => 'Bahasa';

  @override
  String get extension_detail => 'Detail ekstensi';

  @override
  String get scale_type => 'Tipe skala';

  @override
  String get scale_type_fit_screen => 'Sesuai layar';

  @override
  String get scale_type_stretch => 'Regangkan';

  @override
  String get scale_type_fit_width => 'Sesuai lebar';

  @override
  String get scale_type_fit_height => 'Sesuai tinggi';

  @override
  String get scale_type_original_size => 'Ukuran asli';

  @override
  String get scale_type_smart_fit => 'Sesuai pintar';

  @override
  String get page_preload_amount => 'Jumlah pramuat halaman';

  @override
  String get page_preload_amount_subtitle =>
      'Jumlah halaman yang akan dimuat sebelumnya saat membaca. Nilai yang lebih tinggi akan menghasilkan pengalaman membaca yang lebih lancar, dengan biaya penggunaan cache dan jaringan yang lebih tinggi.';

  @override
  String get image_loading_error => 'Gambar ini tidak dapat dimuat';

  @override
  String get add_episodes => 'Tambah Episode';

  @override
  String get video_quality => 'Kualitas';

  @override
  String get video_subtitle => 'Subtitle';

  @override
  String get check_for_extension_updates => 'Periksa pembaruan ekstensi';

  @override
  String get auto_extensions_updates => 'Pembaruan ekstensi otomatis';

  @override
  String get auto_extensions_updates_subtitle =>
      'Akan secara otomatis memperbarui ekstensi ketika versi baru tersedia.';

  @override
  String get check_for_app_updates => 'Periksa pembaruan aplikasi saat mulai';

  @override
  String get reading_mode => 'Mode membaca';

  @override
  String get custom_filter => 'Filter khusus';

  @override
  String get background_color => 'Warna latar belakang';

  @override
  String get white => 'Putih';

  @override
  String get black => 'Hitam';

  @override
  String get grey => 'Abu-abu';

  @override
  String get automaic => 'Otomatis';

  @override
  String get preferred_domain => 'Domain pilihan';

  @override
  String get load_more => 'Muat lebih banyak';

  @override
  String get cancel_all_for_this_series => 'Batalkan semua untuk seri ini';

  @override
  String get login => 'Masuk';

  @override
  String login_into(Object tracker) {
    return 'Masuk ke $tracker';
  }

  @override
  String get email_adress => 'Alamat Email';

  @override
  String get password => 'Kata Sandi';

  @override
  String log_out_from(Object tracker) {
    return 'Keluar dari $tracker?';
  }

  @override
  String get log_out => 'Keluar';

  @override
  String get update_pending => 'Pembaruan tertunda';

  @override
  String get update_all => 'Perbarui semua';

  @override
  String get backup_and_restore => 'Cadangan dan Pulihkan';

  @override
  String get create_backup => 'Buat cadangan';

  @override
  String get create_backup_dialog_title => 'Apa yang ingin Anda cadangkan?';

  @override
  String get create_backup_subtitle =>
      'Dapat digunakan untuk memulihkan perpustakaan saat ini';

  @override
  String get restore_backup => 'Pulihkan cadangan';

  @override
  String get restore_backup_subtitle =>
      'Pulihkan perpustakaan dari berkas cadangan';

  @override
  String get automatic_backups => 'Cadangan otomatis';

  @override
  String get backup_frequency => 'Frekuensi cadangan';

  @override
  String get backup_location => 'Lokasi cadangan';

  @override
  String get backup_options => 'Opsi cadangan';

  @override
  String get backup_options_dialog_title => 'Apa yang ingin Anda cadangkan?';

  @override
  String get backup_options_subtitle =>
      'Informasi apa yang akan disertakan dalam berkas cadangan';

  @override
  String get backup_and_restore_warning_info =>
      'Anda harus menyimpan salinan cadangan di tempat lain juga';

  @override
  String get library_entries => 'Entri perpustakaan';

  @override
  String get chapters_and_episode => 'Bab dan episode';

  @override
  String get every_6_hours => 'Setiap 6 jam';

  @override
  String get every_12_hours => 'Setiap 12 jam';

  @override
  String get daily => 'Setiap hari';

  @override
  String get every_2_days => 'Setiap 2 hari';

  @override
  String get weekly => 'Mingguan';

  @override
  String get restore_backup_warning_title =>
      'Memulihkan cadangan akan menimpa semua data yang ada.\n\nLanjutkan pemulihan?';

  @override
  String get services => 'Layanan';

  @override
  String get tracking_warning_info =>
      'Sinkronisasi satu arah untuk memperbarui kemajuan bab dalam layanan pelacakan. Atur pelacakan untuk entri individu dari tombol pelacakannya.';

  @override
  String get use_page_tap_zones => 'Gunakan zona ketukan halaman';

  @override
  String get manage_trackers => 'Kelola pelacak';

  @override
  String get restore => 'Pulihkan';

  @override
  String get backups => 'Cadangan';

  @override
  String get by_scanlator => 'Oleh scanlator';

  @override
  String get by_name => 'Berdasarkan nama';

  @override
  String get installed => 'Terpasang';

  @override
  String get auto_scroll => 'Gulir otomatis';

  @override
  String get video_audio => 'Audio';

  @override
  String get video_audio_info => 'Bahasa pilihan, koreksi nada, kanal audio';

  @override
  String get player => 'Pemain';

  @override
  String get player_video => 'Video player';

  @override
  String get markEpisodeAsSeenSetting =>
      'Pada titik mana menandai episode sebagai terlihat';

  @override
  String get default_skip_intro_length => 'Panjang lewati intro default';

  @override
  String get default_playback_speed_length =>
      'Panjang kecepatan pemutaran default';

  @override
  String get updateProgressAfterReading => 'Perbarui kemajuan setelah membaca';

  @override
  String get no_sources_installed => 'Tidak ada sumber yang terpasang!';

  @override
  String get show_extensions => 'Tampilkan ekstensi';

  @override
  String get default_skip_forward_skip_length =>
      'Panjang lompatan maju default';

  @override
  String get aniskip_requires_info =>
      'AniSkip memerlukan informasi anime dilacak dengan MAL atau Anilist untuk berfungsi.';

  @override
  String get enable_aniskip => 'Aktifkan AniSkip';

  @override
  String get enable_auto_skip => 'Aktifkan pengabaian otomatis';

  @override
  String get aniskip_button_timeout => 'Timeout tombol';

  @override
  String get skip_opening => 'Lewati pembukaan';

  @override
  String get skip_ending => 'Lewati penutupan';

  @override
  String get fullscreen => 'Layar Penuh';

  @override
  String get update_library => 'Perbarui perpustakaan';

  @override
  String updating_library(Object cur, Object failed, Object max) {
    return 'Memperbarui perpustakaan ($cur / $max) - Gagal: $failed';
  }

  @override
  String get next_chapter => 'Berikutnya bab';

  @override
  String get next_5_chapters => '5 bab berikutnya';

  @override
  String get next_10_chapters => '10 bab berikutnya';

  @override
  String get next_25_chapters => '25 bab berikutnya';

  @override
  String get all_chapters => 'Semua bab';

  @override
  String get next_episode => 'Episode berikutnya';

  @override
  String get next_5_episodes => '5 episode berikutnya';

  @override
  String get next_10_episodes => '10 episode berikutnya';

  @override
  String get next_25_episodes => '25 episode berikutnya';

  @override
  String get all_episodes => 'Semua episode';

  @override
  String get cover_saved => 'Sampul disimpan';

  @override
  String get set_as_cover => 'Atur sebagai sampul';

  @override
  String get use_this_as_cover_art => 'Gunakan ini sebagai seni sampul?';

  @override
  String get save => 'Simpan';

  @override
  String get picture_saved => 'Gambar disimpan';

  @override
  String get cover_updated => 'Penutup diperbarui';

  @override
  String get include_subtitles => 'Sertakan subtitle';

  @override
  String get blend_mode_default => 'Standar';

  @override
  String get blend_mode_multiply => 'Kalikan';

  @override
  String get blend_mode_screen => 'Layar';

  @override
  String get blend_mode_overlay => 'Tumpang tindih';

  @override
  String get blend_mode_colorDodge => 'Menghindari warna';

  @override
  String get blend_mode_lighten => 'Mencerahkan';

  @override
  String get blend_mode_colorBurn => 'Bakar warna';

  @override
  String get blend_mode_darken => 'Menggelapkan';

  @override
  String get blend_mode_difference => 'Perbedaan';

  @override
  String get blend_mode_saturation => 'Saturasi';

  @override
  String get blend_mode_softLight => 'Cahaya lembut';

  @override
  String get blend_mode_plus => 'Tambah';

  @override
  String get blend_mode_exclusion => 'Pengecualian';

  @override
  String get custom_color_filter => 'Filter warna kustom';

  @override
  String get color_filter_blend_mode => 'Mode pencampuran filter warna';

  @override
  String get enable_all => 'Aktifkan semua';

  @override
  String get disable_all => 'Nonaktifkan semua';

  @override
  String get font => 'Jenis Huruf';

  @override
  String get color => 'Warna';

  @override
  String get font_size => 'Ukuran Huruf';

  @override
  String get text => 'Teks';

  @override
  String get border => 'Batas';

  @override
  String get background => 'Latar Belakang';

  @override
  String get no_subtite_warning_message =>
      'Tidak berpengaruh karena tidak ada trek subtitle dalam video ini';

  @override
  String get grid_size => 'Ukuran Grid';

  @override
  String n_per_row(Object n) {
    return '$n per baris';
  }

  @override
  String get horizontal_continious => 'Lanjutan Horizontal';

  @override
  String get edit_code => 'Kode Edit';

  @override
  String get use_libass => 'Aktifkan libass';

  @override
  String get use_libass_info =>
      'Gunakan rendering subtitle berbasis libass untuk backend asli.';

  @override
  String get libass_not_disable_message =>
      'Nonaktifkan `gunakan libass` di pengaturan pemutar untuk dapat menyesuaikan subtitle.';

  @override
  String get torrent_stream => 'Aliran Torrent';

  @override
  String get add_torrent => 'Tambahkan torrent';

  @override
  String get enter_torrent_hint_text => 'Masukkan magnet atau URL file torrent';

  @override
  String get torrent_url => 'URL torrent';

  @override
  String get or => 'ATAU';

  @override
  String get advanced => 'Lanjutan';

  @override
  String get advanced_info => 'Konfigurasi mpv';

  @override
  String get use_native_http_client => 'Gunakan klien http asli';

  @override
  String get use_native_http_client_info =>
      'secara otomatis mendukung fitur platform seperti VPN, mendukung lebih banyak fitur HTTP seperti HTTP/3 dan penanganan pengalihan khusus';

  @override
  String n_hour_ago(Object hour) {
    return '$hour jam yang lalu';
  }

  @override
  String n_hours_ago(Object hours) {
    return '$hours jam yang lalu';
  }

  @override
  String n_minute_ago(Object minute) {
    return '$minute menit yang lalu';
  }

  @override
  String n_minutes_ago(Object minutes) {
    return '$minutes menit yang lalu';
  }

  @override
  String n_day_ago(Object day) {
    return '$day hari yang lalu';
  }

  @override
  String get now => 'sekarang';

  @override
  String library_last_updated(Object lastUpdated) {
    return 'Pembaruan terakhir perpustakaan: $lastUpdated';
  }

  @override
  String get data_and_storage => 'Data dan penyimpanan';

  @override
  String get download_location_info => 'Digunakan untuk unduhan bab';

  @override
  String get storage => 'Penyimpanan';

  @override
  String get clear_chapter_and_episode_cache => 'Hapus cache bab dan episode';

  @override
  String get cache_cleared => 'Cache dihapus';

  @override
  String get clear_chapter_or_episode_cache_on_app_launch =>
      'Hapus cache bab/episode saat aplikasi dibuka';

  @override
  String get app_settings => 'Pengaturan aplikasi';

  @override
  String get sources_settings => 'Pengaturan sumber';

  @override
  String get include_sensitive_settings =>
      'Sertakan pengaturan sensitif (misalnya, token login pelacak)';

  @override
  String get create => 'Buat';

  @override
  String get downloads_are_limited_to_wifi =>
      'Unduhan dibatasi hanya untuk Wi-Fi';

  @override
  String get recommendations => 'Rekomendasi';

  @override
  String get recommendations_similar => 'serupa';

  @override
  String get recommendations_weights => 'Bobot rekomendasi';

  @override
  String get recommendations_weights_genre => 'Kesamaan genre';

  @override
  String get recommendations_weights_setting => 'Kesamaan latar';

  @override
  String get recommendations_weights_synopsis => 'Kesamaan cerita';

  @override
  String get recommendations_weights_theme => 'Kesamaan tema';

  @override
  String get manga_extensions_repo => 'Repositori ekstensi manga';

  @override
  String get anime_extensions_repo => 'Repositori ekstensi anime';

  @override
  String get novel_extensions_repo => 'Repositori ekstensi novel';

  @override
  String get custom_dns =>
      'DNS kustom (biarkan kosong untuk menggunakan DNS sistem)';

  @override
  String get android_proxy_server => 'Server Proxy Android (ApkBridge)';

  @override
  String get get_apk_bridge => 'Dapatkan ApkBridge';

  @override
  String get get_sync_server => 'Dapatkan Server Sinkronisasi di sini';

  @override
  String get undefined => 'Tidak terdefinisi';

  @override
  String get empty_extensions_repo =>
      'Anda tidak memiliki URL repositori di sini. Klik tombol tambah untuk menambahkan satu!';

  @override
  String get add_extensions_repo => 'Tambahkan URL repositori';

  @override
  String get remove_extensions_repo => 'Hapus URL repositori';

  @override
  String get manage_manga_repo_urls => 'Kelola URL repositori manga';

  @override
  String get manage_anime_repo_urls => 'Kelola URL repositori anime';

  @override
  String get manage_novel_repo_urls => 'Kelola URL repositori novel';

  @override
  String get url_cannot_be_empty => 'URL tidak boleh kosong';

  @override
  String get url_must_end_with_dot_json => 'URL harus diakhiri dengan .json';

  @override
  String get repo_url => 'URL repositori';

  @override
  String get invalid_url_format => 'Format URL tidak valid';

  @override
  String get clear_all_sources => 'Hapus semua sumber';

  @override
  String get clear_all_sources_msg =>
      'Ini akan sepenuhnya menghapus semua sumber dari aplikasi. Apakah Anda yakin ingin melanjutkan?';

  @override
  String get sources_cleared => 'Sumber dihapus!';

  @override
  String get repo_added => 'Repositori sumber ditambahkan!';

  @override
  String get add_repo => 'Tambahkan repositori?';

  @override
  String get genre_search_library => 'Cari genre di perpustakaan';

  @override
  String get genre_search_source => 'Jelajahi di sumber';

  @override
  String get source_not_added => 'Sumber tidak diinstal!';

  @override
  String get load_own_subtitles => 'Muat subtitle Anda sendiri...';

  @override
  String get search_subtitles => 'Cari subtitle online...';

  @override
  String extension_notes(Object notes) {
    return 'Catatan: $notes';
  }

  @override
  String get unsupported_repo =>
      'Anda telah mencoba menambahkan repositori yang tidak didukung. Silakan periksa server discord untuk mendapatkan dukungan!';

  @override
  String get end_of_chapter => 'Akhir bab';

  @override
  String get chapter_completed => 'Bab selesai';

  @override
  String get continue_to_next_chapter =>
      'Lanjutkan gulir untuk membaca bab berikutnya';

  @override
  String get no_next_chapter => 'Tidak ada bab berikutnya';

  @override
  String get you_have_finished_reading => 'Anda telah selesai membaca';

  @override
  String get return_to_the_list_of_chapters => 'Kembali ke daftar bab';

  @override
  String get hwdec => 'Dekoder perangkat keras';

  @override
  String get enable_hardware_accel => 'Akselerasi perangkat keras';

  @override
  String get enable_hardware_accel_info =>
      'Aktifkan/nonaktifkan jika Anda mengalami bug atau crash';

  @override
  String get track_library_navigate => 'Pergi ke entri lokal yang ada';

  @override
  String get track_library_add => 'Tambahkan ke perpustakaan lokal';

  @override
  String get track_library_add_confirm =>
      'Tambahkan item yang dilacak ke perpustakaan lokal';

  @override
  String get track_library_not_logged =>
      'Masuk ke pelacak yang sesuai untuk menggunakan fitur ini!';

  @override
  String get track_library_switch => 'Beralih ke pelacak lain';

  @override
  String get go_back => 'Kembali';

  @override
  String get merge_library_nav_mobile =>
      'Gabungkan navigasi perpustakaan di ponsel';

  @override
  String get enable_discord_rpc => 'Aktifkan Discord RPC';

  @override
  String get hide_discord_rpc_incognito =>
      'Sembunyikan Discord RPC saat Inkognito';

  @override
  String get rpc_show_reading_watching_progress =>
      'Tampilkan bab saat ini di Discord (memerlukan restart)';

  @override
  String get rpc_show_title => 'Tampilkan judul saat ini di Discord';

  @override
  String get rpc_show_cover_image =>
      'Tampilkan gambar sampul saat ini di Discord';

  @override
  String get sync_enable_histories => 'Sinkronkan data riwayat';

  @override
  String get sync_enable_updates => 'Sinkronkan data pembaruan';

  @override
  String get sync_enable_settings => 'Sinkronkan pengaturan';

  @override
  String get enable_mpv => 'Aktifkan shader / skrip mpv';

  @override
  String get mpv_info => 'Mendukung skrip .js di bawah mpv/scripts/';

  @override
  String get mpv_redownload => 'Unduh ulang file konfigurasi mpv';

  @override
  String get mpv_redownload_info =>
      'Mengganti file konfigurasi lama dengan yang baru!';

  @override
  String get mpv_download =>
      'File konfigurasi MPV diperlukan!\nUnduh sekarang?';

  @override
  String get custom_buttons => 'Tombol kustom';

  @override
  String get custom_buttons_info => 'Jalankan kode lua dengan tombol kustom';

  @override
  String get custom_buttons_edit => 'Edit tombol kustom';

  @override
  String get custom_buttons_add => 'Tambah tombol kustom';

  @override
  String get custom_buttons_added => 'Tombol kustom ditambahkan!';

  @override
  String get custom_buttons_delete => 'Hapus tombol kustom';

  @override
  String get custom_buttons_text => 'Teks tombol';

  @override
  String get custom_buttons_text_req => 'Teks tombol diperlukan';

  @override
  String get custom_buttons_js_code => 'Kode lua';

  @override
  String get custom_buttons_js_code_req => 'Kode lua diperlukan';

  @override
  String get custom_buttons_js_code_long => 'Kode lua (pada tekan lama)';

  @override
  String get custom_buttons_startup => 'Kode lua (saat startup)';

  @override
  String n_days(Object n) {
    return '$n hari';
  }

  @override
  String get decoder => 'Dekoder';

  @override
  String get decoder_info =>
      'Dekoding perangkat keras, format piksel, debanding';

  @override
  String get enable_gpu_next => 'Aktifkan gpu-next (khusus Android)';

  @override
  String get enable_gpu_next_info => 'Mesin rendering video baru';

  @override
  String get debanding => 'Debanding';

  @override
  String get use_yuv420p => 'Gunakan format piksel YUV420P';

  @override
  String get use_yuv420p_info =>
      'Dapat memperbaiki layar hitam pada beberapa codec video, juga dapat meningkatkan kinerja dengan mengorbankan kualitas';

  @override
  String get audio_preferred_languages => 'Bahasa pilihan';

  @override
  String get audio_preferred_languages_info =>
      'Bahasa audio untuk dipilih secara default pada video dengan beberapa streaming audio, kode bahasa 2/3 huruf (mis: id, en, ja). Beberapa nilai dapat dipisahkan dengan koma.';

  @override
  String get enable_audio_pitch_correction => 'Aktifkan koreksi nada audio';

  @override
  String get enable_audio_pitch_correction_info =>
      'Mencegah audio menjadi bernada tinggi pada kecepatan lebih cepat dan bernada rendah pada kecepatan lebih lambat';

  @override
  String get audio_channels => 'Kanal audio';

  @override
  String get volume_boost_cap => 'Batas peningkatan volume';

  @override
  String get internal_player => 'Pemutar internal';

  @override
  String get internal_player_info => 'Kemajuan, kontrol, orientasi';

  @override
  String get subtitle_delay_text => 'Penundaan subtitle';

  @override
  String get subtitle_delay => 'Penundaan (ms)';

  @override
  String get subtitle_speed => 'Kecepatan';

  @override
  String get calendar => 'Kalender';

  @override
  String get schedule => 'Planning';

  @override
  String get calendar_no_data => 'Belum ada data.';

  @override
  String get calendar_info =>
      'Kalender hanya dapat memprediksi unggahan bab berikutnya berdasarkan unggahan yang lebih lama. Beberapa data mungkin tidak 100% akurat!';

  @override
  String in_n_day(Object days) {
    return 'dalam $days hari';
  }

  @override
  String in_n_days(Object days) {
    return 'dalam $days hari';
  }

  @override
  String get clear_library => 'Bersihkan perpustakaan';

  @override
  String get clear_library_desc =>
      'Pilih untuk menghapus semua entri manga, anime dan/atau novel';

  @override
  String get clear_library_input =>
      'Ketik \'manga\', \'anime\' dan/atau \'novel\' (dipisahkan dengan koma) untuk menghapus semua entri terkait';

  @override
  String get watch_order => 'Urutan menonton';

  @override
  String get sequels => 'Sekuel';

  @override
  String get recommendations_similarity => 'Kesamaan:';

  @override
  String get local_folder_structure => 'Struktur folder lokal';

  @override
  String get local_folder => 'Folder lokal';

  @override
  String get add_local_folder => 'Tambah folder lokal';

  @override
  String get rescan_local_folder => 'Pindai ulang semua folder lokal sekarang';

  @override
  String get export_metadata => 'Ekspor metadata';

  @override
  String get exported => 'Diekspor';

  @override
  String get text_size => 'Ukuran Teks:';

  @override
  String get text_align => 'Perataan Teks';

  @override
  String get line_height => 'Tinggi Baris';

  @override
  String get show_scroll_percentage => 'Tampilkan Persentase Scroll';

  @override
  String get remove_extra_paragraph_spacing => 'Hapus Spasi Ekstra Paragraf';

  @override
  String select_label_color(Object label) {
    return 'Pilih Warna $label';
  }

  @override
  String get default_user_agent => 'Agen Pengguna Bawaan';

  @override
  String get forceLandscapeMode => 'Paksa Mode Lanskap';

  @override
  String get forceLandscapeModeSubtitle =>
      'Paksa pemain untuk menggunakan orientasi lanskap.';

  @override
  String get dns_over_https => 'DNS-over-HTTPS (DoH)';

  @override
  String get dns_provider => 'Penyedia DNS';

  @override
  String get tracked => 'Dilacak';

  @override
  String get auth_unlock_msg => 'Autentikasi untuk membuka kunci Mangayomi';

  @override
  String get app_locked => 'Mangayomi terkunci';

  @override
  String get auth_to_continue => 'Autentikasi untuk melanjutkan';

  @override
  String get authenticating => 'Mengautentikasi...';

  @override
  String get unlock => 'Buka';

  @override
  String get security => 'Keamanan';

  @override
  String get auth_to_change_security_setting =>
      'Autentikasi untuk mengubah pengaturan keamanan';

  @override
  String get app_lock => 'Kunci Aplikasi';

  @override
  String get require_biometric_or_device_credential =>
      'Memerlukan autentikasi biometrik atau kredensial perangkat untuk membuka aplikasi';

  @override
  String get biometric_or_device_credential_not_available =>
      'Autentikasi biometrik tidak tersedia di perangkat ini';

  @override
  String get app_lock_description =>
      'Ketika kunci aplikasi diaktifkan, Anda akan diminta untuk mengautentikasi\\nsetiap kali Anda membuka aplikasi atau kembali dari latar belakang.';

  @override
  String get keep_screen_on => 'Jaga Layar Tetap Menyala';

  @override
  String get webtoon_side_padding => 'Padding Samping Webtoon';

  @override
  String get show_page_gaps => 'Tampilkan Celah Halaman';

  @override
  String get invert_colors => 'Balik Warna';

  @override
  String get grayscale => 'Skala Abu-abu';

  @override
  String get brightness => 'Kecerahan';

  @override
  String get contrast => 'Kontras';

  @override
  String get saturation => 'Saturasi';

  @override
  String get navigation_layout => 'Tata Letak Navigasi';

  @override
  String get nav_layout_default => 'Bawaan';

  @override
  String get nav_layout_l_shaped => 'Bentuk L';

  @override
  String get nav_layout_kindle => 'Kindle';

  @override
  String get nav_layout_edge => 'Tepi';

  @override
  String get nav_layout_right_and_left => 'Kanan dan Kiri';

  @override
  String get nav_layout_disabled => 'Dinonaktifkan';

  @override
  String get color_enhancements => 'Peningkatan Warna';

  @override
  String get total => 'Total';

  @override
  String get mean_per_title => 'Rerata per judul';

  @override
  String get completion_rate => 'Tingkat penyelesaian';

  @override
  String get watching_time => 'Waktu menonton';

  @override
  String get reading_time => 'Waktu membaca';

  @override
  String average_chapters_per_title(Object title) {
    return 'Rata-rata bab per judul';
  }

  @override
  String get read_percentage => 'Persentase baca';

  @override
  String get entries => 'Entri';

  @override
  String get android_proxy_server_mihon => 'Server Proxy Android (Mihon)';

  @override
  String get android_proxy_server_mihon_description =>
      'Unduh dan konfigurasikan server proxy yang diperlukan untuk menggunakan ekstensi Mihon.';

  @override
  String get mihon_proxy_server => 'Server proxy Mihon';

  @override
  String get extension_server_intro_with_jre =>
      'Unduh bundel server proxy sebelum menggunakan ekstensi Mihon. Bundel tersebut mencakup JRE dan JAR server ekstensi.';

  @override
  String get extension_server_intro_ios =>
      'Unduh JAR server proxy sebelum menggunakan ekstensi Mihon. iOS hanya memerlukan JAR server ekstensi.';

  @override
  String get checking_files => 'Memeriksa file';

  @override
  String get files_installed => 'File terpasang';

  @override
  String get files_missing => 'File hilang';

  @override
  String get update_files => 'Perbarui file';

  @override
  String get up_to_date => 'Sudah terbaru';

  @override
  String get choose_location => 'Pilih lokasi';

  @override
  String get import_existing_jar => 'Impor JAR yang ada';

  @override
  String get detect_files_in_selected_folder =>
      'Deteksi file di folder yang dipilih';

  @override
  String get preparing_download => 'Menyiapkan unduhan...';

  @override
  String get app_install_location => 'Lokasi pemasangan aplikasi';

  @override
  String get install_location => 'Lokasi pemasangan';

  @override
  String get jre_executable => 'Executable JRE';

  @override
  String get extension_server_jar => 'JAR server ekstensi';

  @override
  String get installed_version => 'Versi terpasang';

  @override
  String get latest_version => 'Versi terbaru';

  @override
  String get apkbridge_description =>
      'Gunakan ApkBridge saat Anda memerlukan proxy perangkat Android terpisah. Atur alamat proxy di sini dan unduh APK dari GitHub.';

  @override
  String get set_proxy_address => 'Atur alamat proxy';

  @override
  String get no_newer_proxy_server_release_available =>
      'Tidak ada versi server proxy baru yang tersedia.';

  @override
  String get could_not_check_proxy_server_updates =>
      'Tidak dapat memeriksa pembaruan server proxy.';

  @override
  String get no_extension_server_bundle_available_for_this_platform =>
      'Tidak ada bundel server ekstensi yang tersedia untuk platform ini.';

  @override
  String failed_to_download_bundle(Object statusCode) {
    return 'Gagal mengunduh bundel ($statusCode).';
  }

  @override
  String get downloaded_bundle_missing_expected_files =>
      'Bundel yang diunduh tidak berisi file yang diharapkan.';

  @override
  String get extension_server_files_ready => 'File server ekstensi sudah siap.';

  @override
  String get ios_extension_server_import_hint =>
      'Di iOS, server dipasang di dalam sandbox aplikasi. Gunakan \"Impor JAR yang ada\" untuk memasukkan file yang diunduh.';

  @override
  String get select_extension_server_folder => 'Pilih folder server ekstensi';

  @override
  String get selected_folder_does_not_exist => 'Folder yang dipilih tidak ada.';

  @override
  String get no_extension_server_files_found_in_selected_folder =>
      'Tidak ada file server ekstensi ditemukan di folder yang dipilih.';

  @override
  String get extension_server_files_linked =>
      'File server ekstensi telah ditautkan.';

  @override
  String get select_extension_server_jar => 'Pilih JAR server ekstensi';

  @override
  String get selected_file_could_not_be_accessed =>
      'File yang dipilih tidak dapat diakses.';

  @override
  String get extension_server_jar_imported =>
      'JAR server ekstensi berhasil diimpor.';

  @override
  String get could_not_launch_apk_bridge_page =>
      'Tidak dapat meluncurkan halaman ApkBridge.';

  @override
  String get proxy_server_ip_hint =>
      'IP Server (mis. 10.0.0.5 atau https://example.com)';

  @override
  String get not_configured => 'Belum dikonfigurasi';

  @override
  String get webview => 'Tampilan Web';

  @override
  String get tts => 'Teks ke Suara';

  @override
  String get tts_speed => 'Kecepatan';

  @override
  String get tts_pitch => 'Nada';

  @override
  String get tts_language => 'Bahasa';

  @override
  String get tts_voice => 'Suara';

  @override
  String get tts_stop => 'Berhenti';

  @override
  String get tts_play => 'Putar';

  @override
  String get tts_pause => 'Jeda';

  @override
  String get tts_previous => 'Paragraf sebelumnya';

  @override
  String get tts_next => 'Paragraf berikutnya';

  @override
  String tts_paragraph_progress(Object current, Object total) {
    return 'Paragraf $current dari $total';
  }

  @override
  String get tts_settings => 'Pengaturan TTS';

  @override
  String get tts_default => 'Default';

  @override
  String get view_all => 'View all';

  @override
  String get for_you => 'For you';

  @override
  String get following_tab => 'Following';

  @override
  String get explore_tab => 'Explore';

  @override
  String get browser_dock_tabs => 'Tab';

  @override
  String get browser_dock_new_tab => 'Tab baru';

  @override
  String get browser_dock_more => 'Opsi lainnya';

  @override
  String get browser_dock_collapse => 'Ciutkan bilah';

  @override
  String get browser_dock_expand => 'Tampilkan bilah';

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
  String get browse_custom_sections => 'Bagian saya';

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
  String get transfer_title => 'Ruang berbagi';

  @override
  String get transfer_subtitle =>
      'Bagikan unduhan Anda dengan perangkat lain di jaringan WiFi yang sama, tanpa internet.';

  @override
  String transfer_chapters_available(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters available to share',
      one: '1 chapter available to share',
    );
    return '$_temp0';
  }

  @override
  String get transfer_join_room => 'GABUNG RUANG';

  @override
  String get transfer_lan_only =>
      'Hanya LAN / hotspot · tanpa server eksternal';

  @override
  String get transfer_devices_in_room => 'Perangkat di ruang';

  @override
  String get transfer_active_downloads => 'Unduhan berlangsung';

  @override
  String get transfer_completed => 'Selesai';

  @override
  String transfer_started_download(num count) {
    return 'Unduhan $count berkas dimulai';
  }

  @override
  String get transfer_local_room => 'Ruang lokal';

  @override
  String get transfer_active => 'AKTIF';

  @override
  String get transfer_my_device => 'Perangkat saya';

  @override
  String get transfer_me => 'Saya';

  @override
  String transfer_shared_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount bab',
    );
    return '$_temp0 · $_temp1 dibagikan';
  }

  @override
  String get transfer_searching_devices => 'Mencari perangkat…';

  @override
  String get transfer_same_wifi_hint =>
      'Pastikan berada di WiFi atau hotspot yang sama dengan perangkat lain.';

  @override
  String get transfer_loading_catalog => 'Memuat katalog…';

  @override
  String get transfer_catalog_unavailable => 'Katalog tidak tersedia';

  @override
  String transfer_catalog_summary(num mangaCount, num chapterCount) {
    String _temp0 = intl.Intl.pluralLogic(
      mangaCount,
      locale: localeName,
      other: '$mangaCount manga',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chapterCount,
      locale: localeName,
      other: '$chapterCount bab',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transfer_browse => 'Jelajahi';

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
  String get transfer_status_done => 'Selesai';

  @override
  String get transfer_status_failed => 'Gagal';

  @override
  String get transfer_catalog_empty => 'Katalog kosong';

  @override
  String get transfer_no_files => 'Tidak ada berkas tersedia';

  @override
  String get transfer_select_chapters => 'Pilih bab';

  @override
  String transfer_download_count(Object count) {
    return 'Unduh ($count)';
  }

  @override
  String get transfer_type_anime => 'ANIME';

  @override
  String get transfer_type_novel => 'NOVEL';

  @override
  String get transfer_type_other => 'LAINNYA';

  @override
  String get transfer_type_manga => 'MANGA';

  @override
  String get transfer_howto_title => 'Cara mentransfer';

  @override
  String get transfer_howto_step1 =>
      'Hubungkan kedua perangkat ke jaringan WiFi atau hotspot yang sama.';

  @override
  String get transfer_howto_step2 =>
      'Di perangkat lain, buka Unduhan → Transfert dan gabung ke ruang.';

  @override
  String get transfer_howto_step3 =>
      'Ketuk perangkat untuk menjelajahi pustakanya, pilih bab, lalu unduh.';

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
  String get transfer_platform_unknown => 'Perangkat';

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
}
