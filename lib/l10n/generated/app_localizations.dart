import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_as.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('as'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('es', '419'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @open_random_entry.
  ///
  /// In en, this message translates to:
  /// **'Open random entry'**
  String get open_random_entry;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @ignore_filters.
  ///
  /// In en, this message translates to:
  /// **'Ignore Filters'**
  String get ignore_filters;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @unwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get unwatched;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get bookmarked;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @alphabetically.
  ///
  /// In en, this message translates to:
  /// **'Alphabetically'**
  String get alphabetically;

  /// No description provided for @last_read.
  ///
  /// In en, this message translates to:
  /// **'Last read'**
  String get last_read;

  /// No description provided for @last_watched.
  ///
  /// In en, this message translates to:
  /// **'Last watched'**
  String get last_watched;

  /// No description provided for @last_update_check.
  ///
  /// In en, this message translates to:
  /// **'Last update check'**
  String get last_update_check;

  /// Warning when deleting all entries (chapters/episodes) of a manga/anime.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are deleting the only {entryType} of this {mediaType} from the library.} other{You are deleting all {count} {entryTypePlural} of this {mediaType} from the library.}}\nThis will also remove the whole {mediaType} from your library.\n\nNote: The files themselves will not be deleted.'**
  String last_entry_delete_warning(
    num count,
    Object entryType,
    Object entryTypePlural,
    Object mediaType,
  );

  /// No description provided for @chapter.
  ///
  /// In en, this message translates to:
  /// **'chapter'**
  String get chapter;

  /// No description provided for @episode.
  ///
  /// In en, this message translates to:
  /// **'episode'**
  String get episode;

  /// No description provided for @unread_count.
  ///
  /// In en, this message translates to:
  /// **'Unread count'**
  String get unread_count;

  /// No description provided for @unwatched_count.
  ///
  /// In en, this message translates to:
  /// **'Unwatched count'**
  String get unwatched_count;

  /// No description provided for @latest_chapter.
  ///
  /// In en, this message translates to:
  /// **'Latest chapter'**
  String get latest_chapter;

  /// No description provided for @latest_episode.
  ///
  /// In en, this message translates to:
  /// **'Latest episode'**
  String get latest_episode;

  /// No description provided for @date_added.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get date_added;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// No description provided for @display_mode.
  ///
  /// In en, this message translates to:
  /// **'Display mode'**
  String get display_mode;

  /// No description provided for @compact_grid.
  ///
  /// In en, this message translates to:
  /// **'Compact grid'**
  String get compact_grid;

  /// No description provided for @compression_level.
  ///
  /// In en, this message translates to:
  /// **'Compression level'**
  String get compression_level;

  /// No description provided for @compression_info.
  ///
  /// In en, this message translates to:
  /// **'The higher the compression, the less space the backup file takes, but it uses more CPU. Default: {level}'**
  String compression_info(Object level);

  /// No description provided for @comfortable_grid.
  ///
  /// In en, this message translates to:
  /// **'Comfortable grid'**
  String get comfortable_grid;

  /// No description provided for @cover_only_grid.
  ///
  /// In en, this message translates to:
  /// **'Cover-only grid'**
  String get cover_only_grid;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @downloaded_chapters.
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapters'**
  String get downloaded_chapters;

  /// No description provided for @downloaded_episodes.
  ///
  /// In en, this message translates to:
  /// **'Downloaded episodes'**
  String get downloaded_episodes;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @local_source.
  ///
  /// In en, this message translates to:
  /// **'Local source'**
  String get local_source;

  /// No description provided for @overlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get overlay;

  /// No description provided for @show_unread_chapters.
  ///
  /// In en, this message translates to:
  /// **'Unread chapters'**
  String get show_unread_chapters;

  /// No description provided for @random.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get random;

  /// No description provided for @release_date.
  ///
  /// In en, this message translates to:
  /// **'Release date'**
  String get release_date;

  /// No description provided for @folder_name.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folder_name;

  /// No description provided for @chapter_fetch_date.
  ///
  /// In en, this message translates to:
  /// **'Chapter fetch date'**
  String get chapter_fetch_date;

  /// No description provided for @nsfw_only.
  ///
  /// In en, this message translates to:
  /// **'R18'**
  String get nsfw_only;

  /// No description provided for @tabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get tabs;

  /// No description provided for @show_category_tabs.
  ///
  /// In en, this message translates to:
  /// **'Show category tabs'**
  String get show_category_tabs;

  /// No description provided for @show_numbers_of_items.
  ///
  /// In en, this message translates to:
  /// **'Show numbers of items'**
  String get show_numbers_of_items;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @show_continue_reading_buttons.
  ///
  /// In en, this message translates to:
  /// **'Show continue reading buttons'**
  String get show_continue_reading_buttons;

  /// No description provided for @show_continue_watching_buttons.
  ///
  /// In en, this message translates to:
  /// **'Show continue watching buttons'**
  String get show_continue_watching_buttons;

  /// No description provided for @empty_library.
  ///
  /// In en, this message translates to:
  /// **'Empty library'**
  String get empty_library;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @no_recent_updates.
  ///
  /// In en, this message translates to:
  /// **'No recent updates'**
  String get no_recent_updates;

  /// No description provided for @remove_everything.
  ///
  /// In en, this message translates to:
  /// **'Remove everything'**
  String get remove_everything;

  /// No description provided for @remove_everything_msg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? All history will be lost'**
  String get remove_everything_msg;

  /// No description provided for @remove_all_update_msg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? The whole update will be cleared'**
  String get remove_all_update_msg;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @remove_history_msg.
  ///
  /// In en, this message translates to:
  /// **'This will remove the read date of this chapter. Are you sure?'**
  String get remove_history_msg;

  /// No description provided for @last_used.
  ///
  /// In en, this message translates to:
  /// **'Last Used'**
  String get last_used;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @extensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get extensions;

  /// No description provided for @migrate.
  ///
  /// In en, this message translates to:
  /// **'Migrate'**
  String get migrate;

  /// No description provided for @mass_migration_title.
  ///
  /// In en, this message translates to:
  /// **'Mass migration'**
  String get mass_migration_title;

  /// No description provided for @mass_migration_preview_items.
  ///
  /// In en, this message translates to:
  /// **'Preview items'**
  String get mass_migration_preview_items;

  /// No description provided for @mass_migration_destination_source.
  ///
  /// In en, this message translates to:
  /// **'Destination source'**
  String get mass_migration_destination_source;

  /// No description provided for @mass_migration_no_library_items.
  ///
  /// In en, this message translates to:
  /// **'No library items are available for mass migration.'**
  String get mass_migration_no_library_items;

  /// No description provided for @mass_migration_no_destination_sources.
  ///
  /// In en, this message translates to:
  /// **'No installed destination sources are available.'**
  String get mass_migration_no_destination_sources;

  /// No description provided for @mass_migration_installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get mass_migration_installed;

  /// No description provided for @mass_migration_items_ready_for_review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item ready for review} other{{count} items ready for review}}'**
  String mass_migration_items_ready_for_review(int count);

  /// No description provided for @mass_migration_item_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String mass_migration_item_count(int count);

  /// No description provided for @mass_migration_select_destination_source.
  ///
  /// In en, this message translates to:
  /// **'Select destination source'**
  String get mass_migration_select_destination_source;

  /// No description provided for @mass_migration_finding_matches.
  ///
  /// In en, this message translates to:
  /// **'Finding matches in {source} • {language}'**
  String mass_migration_finding_matches(Object source, Object language);

  /// No description provided for @mass_migration_processing_item.
  ///
  /// In en, this message translates to:
  /// **'Processing item {current} of {total}'**
  String mass_migration_processing_item(int current, int total);

  /// No description provided for @mass_migration_waiting_next_item.
  ///
  /// In en, this message translates to:
  /// **'Waiting 2 seconds before the next item...'**
  String get mass_migration_waiting_next_item;

  /// No description provided for @mass_migration_waiting_next_migration.
  ///
  /// In en, this message translates to:
  /// **'Waiting 2 seconds before the next migration...'**
  String get mass_migration_waiting_next_migration;

  /// No description provided for @mass_migration_matched_so_far.
  ///
  /// In en, this message translates to:
  /// **'Matched so far: {count}'**
  String mass_migration_matched_so_far(int count);

  /// No description provided for @mass_migration_no_match_count.
  ///
  /// In en, this message translates to:
  /// **'No match: {count}'**
  String mass_migration_no_match_count(int count);

  /// No description provided for @mass_migration_review_matches.
  ///
  /// In en, this message translates to:
  /// **'Review matches for {source}'**
  String mass_migration_review_matches(Object source);

  /// No description provided for @mass_migration_found_matches.
  ///
  /// In en, this message translates to:
  /// **'Found matches: {count}'**
  String mass_migration_found_matches(int count);

  /// No description provided for @mass_migration_no_matches.
  ///
  /// In en, this message translates to:
  /// **'No matches: {count}'**
  String mass_migration_no_matches(int count);

  /// No description provided for @mass_migration_selected_to_migrate.
  ///
  /// In en, this message translates to:
  /// **'Selected to migrate: {count}'**
  String mass_migration_selected_to_migrate(int count);

  /// No description provided for @mass_migration_finish_review.
  ///
  /// In en, this message translates to:
  /// **'Finish review'**
  String get mass_migration_finish_review;

  /// No description provided for @mass_migration_migrate_selected.
  ///
  /// In en, this message translates to:
  /// **'Migrate selected items ({count})'**
  String mass_migration_migrate_selected(int count);

  /// No description provided for @mass_migration_migrating_selected.
  ///
  /// In en, this message translates to:
  /// **'Migrating selected items to {source}'**
  String mass_migration_migrating_selected(Object source);

  /// No description provided for @mass_migration_no_items_selected.
  ///
  /// In en, this message translates to:
  /// **'No items selected for migration.'**
  String get mass_migration_no_items_selected;

  /// No description provided for @mass_migration_migrating_item.
  ///
  /// In en, this message translates to:
  /// **'Migrating item {current} of {total}'**
  String mass_migration_migrating_item(int current, int total);

  /// No description provided for @mass_migration_complete.
  ///
  /// In en, this message translates to:
  /// **'Mass migration complete'**
  String get mass_migration_complete;

  /// No description provided for @mass_migration_complete_success_message.
  ///
  /// In en, this message translates to:
  /// **'All selected items were processed successfully.'**
  String get mass_migration_complete_success_message;

  /// No description provided for @mass_migration_complete_partial_message.
  ///
  /// In en, this message translates to:
  /// **'Migration finished with a few items that still need manual attention.'**
  String get mass_migration_complete_partial_message;

  /// No description provided for @mass_migration_route_summary.
  ///
  /// In en, this message translates to:
  /// **'{source} → {destination}'**
  String mass_migration_route_summary(Object source, Object destination);

  /// No description provided for @mass_migration_processed.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get mass_migration_processed;

  /// No description provided for @mass_migration_matched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get mass_migration_matched;

  /// No description provided for @mass_migration_migrated.
  ///
  /// In en, this message translates to:
  /// **'Migrated'**
  String get mass_migration_migrated;

  /// No description provided for @mass_migration_skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get mass_migration_skipped;

  /// No description provided for @mass_migration_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mass_migration_failed;

  /// No description provided for @mass_migration_failed_items.
  ///
  /// In en, this message translates to:
  /// **'Failed Items'**
  String get mass_migration_failed_items;

  /// No description provided for @mass_migration_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit Mass Migration'**
  String get mass_migration_exit;

  /// No description provided for @mass_migration_no_destination_match.
  ///
  /// In en, this message translates to:
  /// **'No destination match found'**
  String get mass_migration_no_destination_match;

  /// No description provided for @mass_migration_query.
  ///
  /// In en, this message translates to:
  /// **'Query: {query}'**
  String mass_migration_query(Object query);

  /// No description provided for @mass_migration_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get mass_migration_skip;

  /// No description provided for @mass_migration_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get mass_migration_loading;

  /// No description provided for @mass_migration_choose_another_result.
  ///
  /// In en, this message translates to:
  /// **'Choose another result'**
  String get mass_migration_choose_another_result;

  /// No description provided for @mass_migration_source_chapters.
  ///
  /// In en, this message translates to:
  /// **'Source chapters'**
  String get mass_migration_source_chapters;

  /// No description provided for @mass_migration_destination_chapters.
  ///
  /// In en, this message translates to:
  /// **'Destination chapters'**
  String get mass_migration_destination_chapters;

  /// No description provided for @mass_migration_chapter_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter} other{{count} chapters}}'**
  String mass_migration_chapter_count(int count);

  /// No description provided for @mass_migration_source_chapter_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source chapter} other{{count} source chapters}}'**
  String mass_migration_source_chapter_count(int count);

  /// No description provided for @mass_migration_destination_chapter_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 destination chapter} other{{count} destination chapters}}'**
  String mass_migration_destination_chapter_count(int count);

  /// No description provided for @mass_migration_no_chapters_found.
  ///
  /// In en, this message translates to:
  /// **'No chapters found.'**
  String get mass_migration_no_chapters_found;

  /// No description provided for @mass_migration_and_more_chapters.
  ///
  /// In en, this message translates to:
  /// **'And {count} more...'**
  String mass_migration_and_more_chapters(int count);

  /// No description provided for @mass_migration_unknown_title.
  ///
  /// In en, this message translates to:
  /// **'Unknown title'**
  String get mass_migration_unknown_title;

  /// No description provided for @mass_migration_unknown_match.
  ///
  /// In en, this message translates to:
  /// **'Unknown match'**
  String get mass_migration_unknown_match;

  /// No description provided for @mass_migration_unknown_source.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get mass_migration_unknown_source;

  /// No description provided for @mass_migration_unknown_chapter.
  ///
  /// In en, this message translates to:
  /// **'Unknown chapter'**
  String get mass_migration_unknown_chapter;

  /// No description provided for @migrate_confirm.
  ///
  /// In en, this message translates to:
  /// **'Migrate to another source'**
  String get migrate_confirm;

  /// No description provided for @clean_database.
  ///
  /// In en, this message translates to:
  /// **'Clean database'**
  String get clean_database;

  /// No description provided for @cleaned_database.
  ///
  /// In en, this message translates to:
  /// **'Database cleaned! {x} entries removed'**
  String cleaned_database(Object x);

  /// No description provided for @clean_database_desc.
  ///
  /// In en, this message translates to:
  /// **'This will remove all items that are not added to the library!'**
  String get clean_database_desc;

  /// No description provided for @incognito_mode.
  ///
  /// In en, this message translates to:
  /// **'Incognito Mode'**
  String get incognito_mode;

  /// No description provided for @incognito_mode_description.
  ///
  /// In en, this message translates to:
  /// **'Pauses reading history'**
  String get incognito_mode_description;

  /// No description provided for @downloaded_only.
  ///
  /// In en, this message translates to:
  /// **'Downloaded only'**
  String get downloaded_only;

  /// No description provided for @downloaded_only_description.
  ///
  /// In en, this message translates to:
  /// **'Only show downloaded entries in your library'**
  String get downloaded_only_description;

  /// No description provided for @download_queue.
  ///
  /// In en, this message translates to:
  /// **'Download Manager'**
  String get download_queue;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @no_downloads.
  ///
  /// In en, this message translates to:
  /// **'No Downloads'**
  String get no_downloads;

  /// No description provided for @edit_categories.
  ///
  /// In en, this message translates to:
  /// **'Edit Categories'**
  String get edit_categories;

  /// No description provided for @edit_categories_description.
  ///
  /// In en, this message translates to:
  /// **'You have no categories. Tap the plus button to create one for organizing your library'**
  String get edit_categories_description;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @add_category.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get add_category;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @category_name_required.
  ///
  /// In en, this message translates to:
  /// **'*Required'**
  String get category_name_required;

  /// No description provided for @add_category_error_exist.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exist!'**
  String get add_category_error_exist;

  /// No description provided for @delete_category.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get delete_category;

  /// No description provided for @delete_category_msg.
  ///
  /// In en, this message translates to:
  /// **'Do you wish to delete the category {name}?'**
  String delete_category_msg(Object name);

  /// No description provided for @rename_category.
  ///
  /// In en, this message translates to:
  /// **'Rename Category'**
  String get rename_category;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @general_subtitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get general_subtitle;

  /// No description provided for @app_language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get app_language;

  /// No description provided for @default_subtitle_language.
  ///
  /// In en, this message translates to:
  /// **'Default subtitle language'**
  String get default_subtitle_language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearance_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, date & time format'**
  String get appearance_subtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get dark_mode;

  /// No description provided for @follow_system_theme.
  ///
  /// In en, this message translates to:
  /// **'Follow system theme'**
  String get follow_system_theme;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @pure_black_dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Pure black dark mode'**
  String get pure_black_dark_mode;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @relative_timestamp.
  ///
  /// In en, this message translates to:
  /// **'Relative timestamp'**
  String get relative_timestamp;

  /// No description provided for @relative_timestamp_short.
  ///
  /// In en, this message translates to:
  /// **'Short (Today, Yesterday)'**
  String get relative_timestamp_short;

  /// No description provided for @relative_timestamp_long.
  ///
  /// In en, this message translates to:
  /// **'Long (Short+, n days ago)'**
  String get relative_timestamp_long;

  /// No description provided for @date_format.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get date_format;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @reader_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga reader'**
  String get reader_manga;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reader_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading mode, display, navigation'**
  String get reader_subtitle;

  /// No description provided for @default_reading_mode.
  ///
  /// In en, this message translates to:
  /// **'Default reading mode'**
  String get default_reading_mode;

  /// No description provided for @reading_mode_vertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get reading_mode_vertical;

  /// No description provided for @reading_mode_horizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get reading_mode_horizontal;

  /// No description provided for @reading_mode_left_to_right.
  ///
  /// In en, this message translates to:
  /// **'Left to Right'**
  String get reading_mode_left_to_right;

  /// No description provided for @reading_mode_right_to_left.
  ///
  /// In en, this message translates to:
  /// **'Right to Left'**
  String get reading_mode_right_to_left;

  /// No description provided for @reading_mode_vertical_continuous.
  ///
  /// In en, this message translates to:
  /// **'Vertical continuous'**
  String get reading_mode_vertical_continuous;

  /// No description provided for @reading_mode_webtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get reading_mode_webtoon;

  /// No description provided for @double_tap_animation_speed.
  ///
  /// In en, this message translates to:
  /// **'Double tap animation speed'**
  String get double_tap_animation_speed;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get fast;

  /// No description provided for @no_animation.
  ///
  /// In en, this message translates to:
  /// **'No animation'**
  String get no_animation;

  /// No description provided for @animate_page_transitions.
  ///
  /// In en, this message translates to:
  /// **'Animate page transitions'**
  String get animate_page_transitions;

  /// No description provided for @crop_borders.
  ///
  /// In en, this message translates to:
  /// **'Crop borders'**
  String get crop_borders;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloads_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads settings'**
  String get downloads_subtitle;

  /// No description provided for @download_location.
  ///
  /// In en, this message translates to:
  /// **'Download location'**
  String get download_location;

  /// No description provided for @custom_location.
  ///
  /// In en, this message translates to:
  /// **'Custom location'**
  String get custom_location;

  /// No description provided for @only_on_wifi.
  ///
  /// In en, this message translates to:
  /// **'Only on wifi'**
  String get only_on_wifi;

  /// No description provided for @save_as_cbz_archive.
  ///
  /// In en, this message translates to:
  /// **'Save as CBZ archive'**
  String get save_as_cbz_archive;

  /// No description provided for @delete_download_after_reading.
  ///
  /// In en, this message translates to:
  /// **'Delete download after reading'**
  String get delete_download_after_reading;

  /// No description provided for @concurrent_downloads.
  ///
  /// In en, this message translates to:
  /// **'Concurrent downloads'**
  String get concurrent_downloads;

  /// No description provided for @browse_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sources, global search'**
  String get browse_subtitle;

  /// No description provided for @only_include_pinned_sources.
  ///
  /// In en, this message translates to:
  /// **'Only include pinned sources'**
  String get only_include_pinned_sources;

  /// No description provided for @nsfw_sources.
  ///
  /// In en, this message translates to:
  /// **'NSFW (+18) sources'**
  String get nsfw_sources;

  /// No description provided for @nsfw_sources_show.
  ///
  /// In en, this message translates to:
  /// **'Show in sources and extensions lists'**
  String get nsfw_sources_show;

  /// No description provided for @nsfw_sources_info.
  ///
  /// In en, this message translates to:
  /// **'This does not prevent unofficial or potentially incorrectly flagged extensions from surfacing NSFW (18+) content within the app'**
  String get nsfw_sources_info;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @check_for_update.
  ///
  /// In en, this message translates to:
  /// **'Check for update'**
  String get check_for_update;

  /// No description provided for @logs_on.
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get logs_on;

  /// No description provided for @share_app_logs.
  ///
  /// In en, this message translates to:
  /// **'Share app logs'**
  String get share_app_logs;

  /// No description provided for @no_app_logs.
  ///
  /// In en, this message translates to:
  /// **'No log.txt available!'**
  String get no_app_logs;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed!'**
  String get failed;

  /// No description provided for @n_days_ago.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String n_days_ago(Object days);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @a_week_ago.
  ///
  /// In en, this message translates to:
  /// **'A week ago'**
  String get a_week_ago;

  /// No description provided for @next_week.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get next_week;

  /// No description provided for @add_to_library.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get add_to_library;

  /// No description provided for @added_to_library.
  ///
  /// In en, this message translates to:
  /// **'Added to library'**
  String get added_to_library;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @on_hiatus.
  ///
  /// In en, this message translates to:
  /// **'On Hiatus'**
  String get on_hiatus;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// No description provided for @publishing_finished.
  ///
  /// In en, this message translates to:
  /// **'Publishing finished'**
  String get publishing_finished;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @designer.
  ///
  /// In en, this message translates to:
  /// **'Designer'**
  String get designer;

  /// No description provided for @set_categories.
  ///
  /// In en, this message translates to:
  /// **'Set categories'**
  String get set_categories;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @in_library.
  ///
  /// In en, this message translates to:
  /// **'In library'**
  String get in_library;

  /// No description provided for @filter_scanlator_groups.
  ///
  /// In en, this message translates to:
  /// **'Filter scanlator groups'**
  String get filter_scanlator_groups;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @by_source.
  ///
  /// In en, this message translates to:
  /// **'By source'**
  String get by_source;

  /// No description provided for @by_chapter_number.
  ///
  /// In en, this message translates to:
  /// **'By chapter number'**
  String get by_chapter_number;

  /// No description provided for @by_episode_number.
  ///
  /// In en, this message translates to:
  /// **'By episode number'**
  String get by_episode_number;

  /// No description provided for @by_upload_date.
  ///
  /// In en, this message translates to:
  /// **'By upload date'**
  String get by_upload_date;

  /// No description provided for @source_title.
  ///
  /// In en, this message translates to:
  /// **'Source title'**
  String get source_title;

  /// No description provided for @chapter_number.
  ///
  /// In en, this message translates to:
  /// **'Chapter number'**
  String get chapter_number;

  /// No description provided for @episode_number.
  ///
  /// In en, this message translates to:
  /// **'Episode number'**
  String get episode_number;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @search_in_extension.
  ///
  /// In en, this message translates to:
  /// **'Search in extension'**
  String get search_in_extension;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @n_chapters.
  ///
  /// In en, this message translates to:
  /// **'{n} chapters'**
  String n_chapters(Object n);

  /// No description provided for @no_description.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get no_description;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @open_in_browser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get open_in_browser;

  /// No description provided for @clear_cookie.
  ///
  /// In en, this message translates to:
  /// **'Clear cookie'**
  String get clear_cookie;

  /// No description provided for @show_page_number.
  ///
  /// In en, this message translates to:
  /// **'Show page number'**
  String get show_page_number;

  /// No description provided for @from_library.
  ///
  /// In en, this message translates to:
  /// **'From library'**
  String get from_library;

  /// No description provided for @downloaded_chapter.
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapter'**
  String get downloaded_chapter;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String page(Object page);

  /// No description provided for @global_search.
  ///
  /// In en, this message translates to:
  /// **'Global search'**
  String get global_search;

  /// No description provided for @color_blend_level.
  ///
  /// In en, this message translates to:
  /// **'Color blend level'**
  String get color_blend_level;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current {char}'**
  String current(Object char);

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished {char}'**
  String finished(Object char);

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next {char}'**
  String next(Object char);

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous {char}'**
  String previous(Object char);

  /// No description provided for @no_more_chapter.
  ///
  /// In en, this message translates to:
  /// **'There\'s no more chapter'**
  String get no_more_chapter;

  /// No description provided for @no_result.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get no_result;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @start_downloading.
  ///
  /// In en, this message translates to:
  /// **'Start downloading now'**
  String get start_downloading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @add_chapters.
  ///
  /// In en, this message translates to:
  /// **'Add Chapters'**
  String get add_chapters;

  /// No description provided for @delete_chapters.
  ///
  /// In en, this message translates to:
  /// **'Delete Chapter?'**
  String get delete_chapters;

  /// No description provided for @default0.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default0;

  /// No description provided for @total_chapters.
  ///
  /// In en, this message translates to:
  /// **'Total Chapters'**
  String get total_chapters;

  /// No description provided for @total_episodes.
  ///
  /// In en, this message translates to:
  /// **'Total episodes'**
  String get total_episodes;

  /// No description provided for @import_local_file.
  ///
  /// In en, this message translates to:
  /// **'Import Local file'**
  String get import_local_file;

  /// No description provided for @import_files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get import_files;

  /// No description provided for @split_epub_chapters.
  ///
  /// In en, this message translates to:
  /// **'Split into chapters'**
  String get split_epub_chapters;

  /// No description provided for @split_epub_chapters_description.
  ///
  /// In en, this message translates to:
  /// **'Import each EPUB chapter as a separate entry'**
  String get split_epub_chapters_description;

  /// No description provided for @nothing_read_recently.
  ///
  /// In en, this message translates to:
  /// **'Nothing read recently'**
  String get nothing_read_recently;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @not_started.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get not_started;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @start_date.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get start_date;

  /// No description provided for @finish_date.
  ///
  /// In en, this message translates to:
  /// **'Finish date'**
  String get finish_date;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @on_hold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get on_hold;

  /// No description provided for @dropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get dropped;

  /// No description provided for @plan_to_read.
  ///
  /// In en, this message translates to:
  /// **'Plan to read'**
  String get plan_to_read;

  /// No description provided for @re_reading.
  ///
  /// In en, this message translates to:
  /// **'Rereading'**
  String get re_reading;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @add_tracker.
  ///
  /// In en, this message translates to:
  /// **'Add tracking'**
  String get add_tracker;

  /// No description provided for @one_tracker.
  ///
  /// In en, this message translates to:
  /// **'1 tracker'**
  String get one_tracker;

  /// No description provided for @n_tracker.
  ///
  /// In en, this message translates to:
  /// **'{n} trackers'**
  String n_tracker(Object n);

  /// No description provided for @tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncing;

  /// No description provided for @sync_password.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 8 characters)'**
  String get sync_password;

  /// No description provided for @sync_logged.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get sync_logged;

  /// No description provided for @syncing_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your progress across multiple devices via a self-hosted \nserver. Check out our discord server for more info!'**
  String get syncing_subtitle;

  /// No description provided for @last_sync_manga.
  ///
  /// In en, this message translates to:
  /// **'Last manga sync at: '**
  String get last_sync_manga;

  /// No description provided for @last_sync_history.
  ///
  /// In en, this message translates to:
  /// **'Last history sync at: '**
  String get last_sync_history;

  /// No description provided for @last_sync_update.
  ///
  /// In en, this message translates to:
  /// **'Last update sync at: '**
  String get last_sync_update;

  /// No description provided for @sync_server.
  ///
  /// In en, this message translates to:
  /// **'Sync Server Address'**
  String get sync_server;

  /// No description provided for @sync_login_invalid_creds.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get sync_login_invalid_creds;

  /// No description provided for @sync_starting.
  ///
  /// In en, this message translates to:
  /// **'Starting sync...'**
  String get sync_starting;

  /// No description provided for @sync_finished.
  ///
  /// In en, this message translates to:
  /// **'Sync finished'**
  String get sync_finished;

  /// No description provided for @sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get sync_failed;

  /// No description provided for @sync_button_sync.
  ///
  /// In en, this message translates to:
  /// **'Sync progress'**
  String get sync_button_sync;

  /// No description provided for @sync_button_upload.
  ///
  /// In en, this message translates to:
  /// **'Upload only'**
  String get sync_button_upload;

  /// No description provided for @sync_button_upload_info.
  ///
  /// In en, this message translates to:
  /// **'This operation will fully replace the remote data with local data!'**
  String get sync_button_upload_info;

  /// No description provided for @sync_button_download.
  ///
  /// In en, this message translates to:
  /// **'Download only'**
  String get sync_button_download;

  /// No description provided for @sync_button_download_info.
  ///
  /// In en, this message translates to:
  /// **'This operation will fully replace the local data with remote data!'**
  String get sync_button_download_info;

  /// No description provided for @sync_on.
  ///
  /// In en, this message translates to:
  /// **'Enable sync'**
  String get sync_on;

  /// No description provided for @sync_auto.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get sync_auto;

  /// No description provided for @sync_auto_warning.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync is currently an experimental feature!'**
  String get sync_auto_warning;

  /// No description provided for @sync_auto_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sync_auto_off;

  /// No description provided for @sync_auto_5_minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 5 minutes'**
  String get sync_auto_5_minutes;

  /// No description provided for @sync_auto_10_minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 10 minutes'**
  String get sync_auto_10_minutes;

  /// No description provided for @sync_auto_30_minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 30 minutes'**
  String get sync_auto_30_minutes;

  /// No description provided for @sync_auto_1_hour.
  ///
  /// In en, this message translates to:
  /// **'Every 1 hour'**
  String get sync_auto_1_hour;

  /// No description provided for @sync_auto_3_hours.
  ///
  /// In en, this message translates to:
  /// **'Every 3 hours'**
  String get sync_auto_3_hours;

  /// No description provided for @sync_auto_6_hours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get sync_auto_6_hours;

  /// No description provided for @sync_auto_12_hours.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get sync_auto_12_hours;

  /// No description provided for @server_error.
  ///
  /// In en, this message translates to:
  /// **'Server error!'**
  String get server_error;

  /// No description provided for @dialog_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialog_confirm;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @reorder_navigation.
  ///
  /// In en, this message translates to:
  /// **'Customize navigation'**
  String get reorder_navigation;

  /// No description provided for @reorder_navigation_description.
  ///
  /// In en, this message translates to:
  /// **'Reorder and toggle each navigation to your needs.'**
  String get reorder_navigation_description;

  /// No description provided for @full_screen_player.
  ///
  /// In en, this message translates to:
  /// **'Use Fullscreen'**
  String get full_screen_player;

  /// No description provided for @full_screen_player_info.
  ///
  /// In en, this message translates to:
  /// **'Automatically use fullscreen when playing a video.'**
  String get full_screen_player_info;

  /// No description provided for @episode_progress.
  ///
  /// In en, this message translates to:
  /// **'Progress: {n}'**
  String episode_progress(Object n);

  /// No description provided for @n_episodes.
  ///
  /// In en, this message translates to:
  /// **'{n} episodes'**
  String n_episodes(Object n);

  /// No description provided for @manga_sources.
  ///
  /// In en, this message translates to:
  /// **'Manga Sources'**
  String get manga_sources;

  /// No description provided for @anime_sources.
  ///
  /// In en, this message translates to:
  /// **'Watch Sources'**
  String get anime_sources;

  /// No description provided for @novel_sources.
  ///
  /// In en, this message translates to:
  /// **'Novel Sources'**
  String get novel_sources;

  /// No description provided for @anime_extensions.
  ///
  /// In en, this message translates to:
  /// **'Watch Extensions'**
  String get anime_extensions;

  /// No description provided for @manga_extensions.
  ///
  /// In en, this message translates to:
  /// **'Manga Extensions'**
  String get manga_extensions;

  /// No description provided for @novel_extensions.
  ///
  /// In en, this message translates to:
  /// **'Novel Extensions'**
  String get novel_extensions;

  /// No description provided for @extension_settings.
  ///
  /// In en, this message translates to:
  /// **'Extension settings'**
  String get extension_settings;

  /// No description provided for @anime.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get anime;

  /// No description provided for @manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get manga;

  /// No description provided for @novel.
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get novel;

  /// No description provided for @library_no_category_exist.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any categories yet'**
  String get library_no_category_exist;

  /// No description provided for @watching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get watching;

  /// No description provided for @plan_to_watch.
  ///
  /// In en, this message translates to:
  /// **'Plan to watch'**
  String get plan_to_watch;

  /// No description provided for @re_watching.
  ///
  /// In en, this message translates to:
  /// **'Rewatching'**
  String get re_watching;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @new_update_available.
  ///
  /// In en, this message translates to:
  /// **'New update available'**
  String get new_update_available;

  /// No description provided for @app_version.
  ///
  /// In en, this message translates to:
  /// **'App Version : v{v}'**
  String app_version(Object v);

  /// No description provided for @searching_for_updates.
  ///
  /// In en, this message translates to:
  /// **'Searching for updates...'**
  String get searching_for_updates;

  /// No description provided for @no_new_updates_available.
  ///
  /// In en, this message translates to:
  /// **'No new updates available'**
  String get no_new_updates_available;

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @uninstall_extension.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {ext} extension?'**
  String uninstall_extension(Object ext);

  /// No description provided for @langauage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langauage;

  /// No description provided for @extension_detail.
  ///
  /// In en, this message translates to:
  /// **'Extension detail'**
  String get extension_detail;

  /// No description provided for @scale_type.
  ///
  /// In en, this message translates to:
  /// **'Scale type'**
  String get scale_type;

  /// No description provided for @scale_type_fit_screen.
  ///
  /// In en, this message translates to:
  /// **'Fit screen'**
  String get scale_type_fit_screen;

  /// No description provided for @scale_type_stretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get scale_type_stretch;

  /// No description provided for @scale_type_fit_width.
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get scale_type_fit_width;

  /// No description provided for @scale_type_fit_height.
  ///
  /// In en, this message translates to:
  /// **'Fit height'**
  String get scale_type_fit_height;

  /// No description provided for @scale_type_original_size.
  ///
  /// In en, this message translates to:
  /// **'Original size'**
  String get scale_type_original_size;

  /// No description provided for @scale_type_smart_fit.
  ///
  /// In en, this message translates to:
  /// **'Smart fit'**
  String get scale_type_smart_fit;

  /// No description provided for @page_preload_amount.
  ///
  /// In en, this message translates to:
  /// **'Page preload amount'**
  String get page_preload_amount;

  /// No description provided for @page_preload_amount_subtitle.
  ///
  /// In en, this message translates to:
  /// **'The amount of pages to preload when reading. Higher values will result in a smoother reading experience, at the cost of higher cache and network usage.'**
  String get page_preload_amount_subtitle;

  /// No description provided for @image_loading_error.
  ///
  /// In en, this message translates to:
  /// **'This image couldn\'t be loaded'**
  String get image_loading_error;

  /// No description provided for @add_episodes.
  ///
  /// In en, this message translates to:
  /// **'Add Episodes'**
  String get add_episodes;

  /// No description provided for @video_quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get video_quality;

  /// No description provided for @video_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get video_subtitle;

  /// No description provided for @check_for_extension_updates.
  ///
  /// In en, this message translates to:
  /// **'Check for extension updates'**
  String get check_for_extension_updates;

  /// No description provided for @auto_extensions_updates.
  ///
  /// In en, this message translates to:
  /// **'Auto extension updates'**
  String get auto_extensions_updates;

  /// No description provided for @auto_extensions_updates_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Will automatically update the extension when a new version is available.'**
  String get auto_extensions_updates_subtitle;

  /// No description provided for @check_for_app_updates.
  ///
  /// In en, this message translates to:
  /// **'Check for app updates on startup'**
  String get check_for_app_updates;

  /// No description provided for @reading_mode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get reading_mode;

  /// No description provided for @custom_filter.
  ///
  /// In en, this message translates to:
  /// **'Custom filter'**
  String get custom_filter;

  /// No description provided for @background_color.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get background_color;

  /// No description provided for @white.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;

  /// No description provided for @grey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get grey;

  /// No description provided for @automaic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automaic;

  /// No description provided for @preferred_domain.
  ///
  /// In en, this message translates to:
  /// **'Preferred Domain'**
  String get preferred_domain;

  /// No description provided for @load_more.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get load_more;

  /// No description provided for @cancel_all_for_this_series.
  ///
  /// In en, this message translates to:
  /// **'Cancel all for this series'**
  String get cancel_all_for_this_series;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @login_into.
  ///
  /// In en, this message translates to:
  /// **'Login into {tracker}'**
  String login_into(Object tracker);

  /// No description provided for @email_adress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email_adress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @log_out_from.
  ///
  /// In en, this message translates to:
  /// **'Log out from {tracker}?'**
  String log_out_from(Object tracker);

  /// No description provided for @log_out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get log_out;

  /// No description provided for @update_pending.
  ///
  /// In en, this message translates to:
  /// **'Update pending'**
  String get update_pending;

  /// No description provided for @update_all.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get update_all;

  /// No description provided for @backup_and_restore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backup_and_restore;

  /// No description provided for @create_backup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get create_backup;

  /// No description provided for @create_backup_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'What do you want to backup?'**
  String get create_backup_dialog_title;

  /// No description provided for @create_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be used to restore current library'**
  String get create_backup_subtitle;

  /// No description provided for @restore_backup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restore_backup;

  /// No description provided for @restore_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore library from backup file'**
  String get restore_backup_subtitle;

  /// No description provided for @automatic_backups.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get automatic_backups;

  /// No description provided for @backup_frequency.
  ///
  /// In en, this message translates to:
  /// **'Backup frequency'**
  String get backup_frequency;

  /// No description provided for @backup_location.
  ///
  /// In en, this message translates to:
  /// **'Backup location'**
  String get backup_location;

  /// No description provided for @backup_options.
  ///
  /// In en, this message translates to:
  /// **'Backup options'**
  String get backup_options;

  /// No description provided for @backup_options_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'What do you want to backup?'**
  String get backup_options_dialog_title;

  /// No description provided for @backup_options_subtitle.
  ///
  /// In en, this message translates to:
  /// **'What information to include in the backup file?'**
  String get backup_options_subtitle;

  /// No description provided for @backup_and_restore_warning_info.
  ///
  /// In en, this message translates to:
  /// **'You should keep copies of backups in other places as well'**
  String get backup_and_restore_warning_info;

  /// No description provided for @library_entries.
  ///
  /// In en, this message translates to:
  /// **'Library entries'**
  String get library_entries;

  /// No description provided for @chapters_and_episode.
  ///
  /// In en, this message translates to:
  /// **'Chapters and episode'**
  String get chapters_and_episode;

  /// No description provided for @every_6_hours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get every_6_hours;

  /// No description provided for @every_12_hours.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get every_12_hours;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @every_2_days.
  ///
  /// In en, this message translates to:
  /// **'Every 2 days'**
  String get every_2_days;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @restore_backup_warning_title.
  ///
  /// In en, this message translates to:
  /// **'Restoring a backup will overwrite all existing data.\n\nContinue restoring?'**
  String get restore_backup_warning_title;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @tracking_warning_info.
  ///
  /// In en, this message translates to:
  /// **'One-way sync to update the chapter progress in tracking services. Set up tracking for individual entries from their tracking button.'**
  String get tracking_warning_info;

  /// No description provided for @use_page_tap_zones.
  ///
  /// In en, this message translates to:
  /// **'Use page tap zones'**
  String get use_page_tap_zones;

  /// No description provided for @manage_trackers.
  ///
  /// In en, this message translates to:
  /// **'Manage trackers'**
  String get manage_trackers;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups;

  /// No description provided for @by_scanlator.
  ///
  /// In en, this message translates to:
  /// **'By scanlator'**
  String get by_scanlator;

  /// No description provided for @by_name.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get by_name;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @auto_scroll.
  ///
  /// In en, this message translates to:
  /// **'Auto scroll'**
  String get auto_scroll;

  /// No description provided for @video_audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get video_audio;

  /// No description provided for @video_audio_info.
  ///
  /// In en, this message translates to:
  /// **'Preferred languages, pitch correction, audio channels'**
  String get video_audio_info;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @player_video.
  ///
  /// In en, this message translates to:
  /// **'Video player'**
  String get player_video;

  /// No description provided for @markEpisodeAsSeenSetting.
  ///
  /// In en, this message translates to:
  /// **'At what point to mark the episode as seen'**
  String get markEpisodeAsSeenSetting;

  /// No description provided for @default_skip_intro_length.
  ///
  /// In en, this message translates to:
  /// **'Default Skip intro length'**
  String get default_skip_intro_length;

  /// No description provided for @default_playback_speed_length.
  ///
  /// In en, this message translates to:
  /// **'Default Playback speed length'**
  String get default_playback_speed_length;

  /// No description provided for @updateProgressAfterReading.
  ///
  /// In en, this message translates to:
  /// **'Update progress after reading'**
  String get updateProgressAfterReading;

  /// No description provided for @no_sources_installed.
  ///
  /// In en, this message translates to:
  /// **'No sources installed!'**
  String get no_sources_installed;

  /// No description provided for @show_extensions.
  ///
  /// In en, this message translates to:
  /// **'Show extensions'**
  String get show_extensions;

  /// No description provided for @default_skip_forward_skip_length.
  ///
  /// In en, this message translates to:
  /// **'Default skip forward skip length'**
  String get default_skip_forward_skip_length;

  /// No description provided for @aniskip_requires_info.
  ///
  /// In en, this message translates to:
  /// **'AniSkip requires the anime to be tracked with MAL or Anilist to work.'**
  String get aniskip_requires_info;

  /// No description provided for @enable_aniskip.
  ///
  /// In en, this message translates to:
  /// **'Enable AniSkip'**
  String get enable_aniskip;

  /// No description provided for @enable_auto_skip.
  ///
  /// In en, this message translates to:
  /// **'Enable auto skip'**
  String get enable_auto_skip;

  /// No description provided for @aniskip_button_timeout.
  ///
  /// In en, this message translates to:
  /// **'Button timeout'**
  String get aniskip_button_timeout;

  /// No description provided for @skip_opening.
  ///
  /// In en, this message translates to:
  /// **'Skip opening'**
  String get skip_opening;

  /// No description provided for @skip_ending.
  ///
  /// In en, this message translates to:
  /// **'Skip ending'**
  String get skip_ending;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @update_library.
  ///
  /// In en, this message translates to:
  /// **'Update library'**
  String get update_library;

  /// No description provided for @updating_library.
  ///
  /// In en, this message translates to:
  /// **'Updating library ({cur} / {max}) - Failed: {failed}'**
  String updating_library(Object cur, Object failed, Object max);

  /// No description provided for @next_chapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get next_chapter;

  /// No description provided for @next_5_chapters.
  ///
  /// In en, this message translates to:
  /// **'Next 5 chapters'**
  String get next_5_chapters;

  /// No description provided for @next_10_chapters.
  ///
  /// In en, this message translates to:
  /// **'Next 10 chapters'**
  String get next_10_chapters;

  /// No description provided for @next_25_chapters.
  ///
  /// In en, this message translates to:
  /// **'Next 25 chapters'**
  String get next_25_chapters;

  /// No description provided for @all_chapters.
  ///
  /// In en, this message translates to:
  /// **'All chapters'**
  String get all_chapters;

  /// No description provided for @next_episode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get next_episode;

  /// No description provided for @next_5_episodes.
  ///
  /// In en, this message translates to:
  /// **'Next 5 episodes'**
  String get next_5_episodes;

  /// No description provided for @next_10_episodes.
  ///
  /// In en, this message translates to:
  /// **'Next 10 episodes'**
  String get next_10_episodes;

  /// No description provided for @next_25_episodes.
  ///
  /// In en, this message translates to:
  /// **'Next 25 episodes'**
  String get next_25_episodes;

  /// No description provided for @all_episodes.
  ///
  /// In en, this message translates to:
  /// **'All episodes'**
  String get all_episodes;

  /// No description provided for @cover_saved.
  ///
  /// In en, this message translates to:
  /// **'Cover saved'**
  String get cover_saved;

  /// No description provided for @set_as_cover.
  ///
  /// In en, this message translates to:
  /// **'Set as cover'**
  String get set_as_cover;

  /// No description provided for @use_this_as_cover_art.
  ///
  /// In en, this message translates to:
  /// **'Use this as cover art?'**
  String get use_this_as_cover_art;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @picture_saved.
  ///
  /// In en, this message translates to:
  /// **'Picture saved'**
  String get picture_saved;

  /// No description provided for @cover_updated.
  ///
  /// In en, this message translates to:
  /// **'Cover updated'**
  String get cover_updated;

  /// No description provided for @include_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Include subtitles'**
  String get include_subtitles;

  /// No description provided for @blend_mode_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get blend_mode_default;

  /// No description provided for @blend_mode_multiply.
  ///
  /// In en, this message translates to:
  /// **'Multiply'**
  String get blend_mode_multiply;

  /// No description provided for @blend_mode_screen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get blend_mode_screen;

  /// No description provided for @blend_mode_overlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get blend_mode_overlay;

  /// No description provided for @blend_mode_colorDodge.
  ///
  /// In en, this message translates to:
  /// **'ColorDodge'**
  String get blend_mode_colorDodge;

  /// No description provided for @blend_mode_lighten.
  ///
  /// In en, this message translates to:
  /// **'Lighten'**
  String get blend_mode_lighten;

  /// No description provided for @blend_mode_colorBurn.
  ///
  /// In en, this message translates to:
  /// **'ColorBurn'**
  String get blend_mode_colorBurn;

  /// No description provided for @blend_mode_darken.
  ///
  /// In en, this message translates to:
  /// **'Darken'**
  String get blend_mode_darken;

  /// No description provided for @blend_mode_difference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get blend_mode_difference;

  /// No description provided for @blend_mode_saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get blend_mode_saturation;

  /// No description provided for @blend_mode_softLight.
  ///
  /// In en, this message translates to:
  /// **'SoftLight'**
  String get blend_mode_softLight;

  /// No description provided for @blend_mode_plus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get blend_mode_plus;

  /// No description provided for @blend_mode_exclusion.
  ///
  /// In en, this message translates to:
  /// **'Exclusion'**
  String get blend_mode_exclusion;

  /// No description provided for @custom_color_filter.
  ///
  /// In en, this message translates to:
  /// **'Custom color filter'**
  String get custom_color_filter;

  /// No description provided for @color_filter_blend_mode.
  ///
  /// In en, this message translates to:
  /// **'Color filter blend mode'**
  String get color_filter_blend_mode;

  /// No description provided for @enable_all.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get enable_all;

  /// No description provided for @disable_all.
  ///
  /// In en, this message translates to:
  /// **'Disable all'**
  String get disable_all;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @font_size.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get font_size;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @border.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get border;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @no_subtite_warning_message.
  ///
  /// In en, this message translates to:
  /// **'Has no effect because there aren\'t any subtitle tracks in this video'**
  String get no_subtite_warning_message;

  /// No description provided for @grid_size.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get grid_size;

  /// No description provided for @n_per_row.
  ///
  /// In en, this message translates to:
  /// **'{n} per row'**
  String n_per_row(Object n);

  /// No description provided for @horizontal_continious.
  ///
  /// In en, this message translates to:
  /// **'Horizontal continuous'**
  String get horizontal_continious;

  /// No description provided for @edit_code.
  ///
  /// In en, this message translates to:
  /// **'Edit code'**
  String get edit_code;

  /// No description provided for @use_libass.
  ///
  /// In en, this message translates to:
  /// **'Enable libass'**
  String get use_libass;

  /// No description provided for @use_libass_info.
  ///
  /// In en, this message translates to:
  /// **'Use libass based subtitle rendering for native backend.'**
  String get use_libass_info;

  /// No description provided for @libass_not_disable_message.
  ///
  /// In en, this message translates to:
  /// **'Disable `use libass` in player settings to be able to customize the subtitles.'**
  String get libass_not_disable_message;

  /// No description provided for @torrent_stream.
  ///
  /// In en, this message translates to:
  /// **'Torrent Stream'**
  String get torrent_stream;

  /// No description provided for @add_torrent.
  ///
  /// In en, this message translates to:
  /// **'Add torrent'**
  String get add_torrent;

  /// No description provided for @enter_torrent_hint_text.
  ///
  /// In en, this message translates to:
  /// **'Enter magnet or torrent file url'**
  String get enter_torrent_hint_text;

  /// No description provided for @torrent_url.
  ///
  /// In en, this message translates to:
  /// **'Torrent url'**
  String get torrent_url;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advanced_info.
  ///
  /// In en, this message translates to:
  /// **'mpv config'**
  String get advanced_info;

  /// No description provided for @use_native_http_client.
  ///
  /// In en, this message translates to:
  /// **'Use native http client'**
  String get use_native_http_client;

  /// No description provided for @use_native_http_client_info.
  ///
  /// In en, this message translates to:
  /// **'it automatically supports platform features such VPNs, support more HTTP features such as HTTP/3 and custom redirect handling'**
  String get use_native_http_client_info;

  /// No description provided for @n_hour_ago.
  ///
  /// In en, this message translates to:
  /// **'{hour} hour ago'**
  String n_hour_ago(Object hour);

  /// No description provided for @n_hours_ago.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String n_hours_ago(Object hours);

  /// No description provided for @n_minute_ago.
  ///
  /// In en, this message translates to:
  /// **'{minute} minute ago'**
  String n_minute_ago(Object minute);

  /// No description provided for @n_minutes_ago.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes ago'**
  String n_minutes_ago(Object minutes);

  /// No description provided for @n_day_ago.
  ///
  /// In en, this message translates to:
  /// **'{day} day ago'**
  String n_day_ago(Object day);

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get now;

  /// No description provided for @library_last_updated.
  ///
  /// In en, this message translates to:
  /// **'Library last updated: {lastUpdated}'**
  String library_last_updated(Object lastUpdated);

  /// No description provided for @data_and_storage.
  ///
  /// In en, this message translates to:
  /// **'Data and storage'**
  String get data_and_storage;

  /// No description provided for @download_location_info.
  ///
  /// In en, this message translates to:
  /// **'Used for chapter downloads'**
  String get download_location_info;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @clear_chapter_and_episode_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear chapter and episode cache'**
  String get clear_chapter_and_episode_cache;

  /// No description provided for @cache_cleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cache_cleared;

  /// No description provided for @clear_chapter_or_episode_cache_on_app_launch.
  ///
  /// In en, this message translates to:
  /// **'Clear chapter/episode cache on app launch'**
  String get clear_chapter_or_episode_cache_on_app_launch;

  /// No description provided for @app_settings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get app_settings;

  /// No description provided for @sources_settings.
  ///
  /// In en, this message translates to:
  /// **'Sources settings'**
  String get sources_settings;

  /// No description provided for @include_sensitive_settings.
  ///
  /// In en, this message translates to:
  /// **'Include sensitive settings (e.g., tracker login tokens)'**
  String get include_sensitive_settings;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @downloads_are_limited_to_wifi.
  ///
  /// In en, this message translates to:
  /// **'Downloads are limited to Wi-Fi only'**
  String get downloads_are_limited_to_wifi;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @recommendations_similar.
  ///
  /// In en, this message translates to:
  /// **'similar'**
  String get recommendations_similar;

  /// No description provided for @recommendations_weights.
  ///
  /// In en, this message translates to:
  /// **'Recommendation Weights'**
  String get recommendations_weights;

  /// No description provided for @recommendations_weights_genre.
  ///
  /// In en, this message translates to:
  /// **'Genre Similarity'**
  String get recommendations_weights_genre;

  /// No description provided for @recommendations_weights_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting Similarity'**
  String get recommendations_weights_setting;

  /// No description provided for @recommendations_weights_synopsis.
  ///
  /// In en, this message translates to:
  /// **'Story Similarity'**
  String get recommendations_weights_synopsis;

  /// No description provided for @recommendations_weights_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme Similarity'**
  String get recommendations_weights_theme;

  /// No description provided for @manga_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'Manga extensions repo'**
  String get manga_extensions_repo;

  /// No description provided for @anime_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'Watch extensions repo'**
  String get anime_extensions_repo;

  /// No description provided for @novel_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'Novel extensions repo'**
  String get novel_extensions_repo;

  /// No description provided for @custom_dns.
  ///
  /// In en, this message translates to:
  /// **'Custom DNS (leave blank to use system DNS)'**
  String get custom_dns;

  /// No description provided for @android_proxy_server.
  ///
  /// In en, this message translates to:
  /// **'Android Proxy Server (ApkBridge)'**
  String get android_proxy_server;

  /// No description provided for @get_apk_bridge.
  ///
  /// In en, this message translates to:
  /// **'Get ApkBridge'**
  String get get_apk_bridge;

  /// No description provided for @get_sync_server.
  ///
  /// In en, this message translates to:
  /// **'Get Sync Server here'**
  String get get_sync_server;

  /// No description provided for @undefined.
  ///
  /// In en, this message translates to:
  /// **'undefined'**
  String get undefined;

  /// No description provided for @empty_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any repository urls here. Click on the plus button to add one!'**
  String get empty_extensions_repo;

  /// No description provided for @add_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'Add repo URL'**
  String get add_extensions_repo;

  /// No description provided for @remove_extensions_repo.
  ///
  /// In en, this message translates to:
  /// **'Remove repo URL'**
  String get remove_extensions_repo;

  /// No description provided for @manage_manga_repo_urls.
  ///
  /// In en, this message translates to:
  /// **'Manage Manga Repo URLs'**
  String get manage_manga_repo_urls;

  /// No description provided for @manage_anime_repo_urls.
  ///
  /// In en, this message translates to:
  /// **'Manage Watch Repo URLs'**
  String get manage_anime_repo_urls;

  /// No description provided for @manage_novel_repo_urls.
  ///
  /// In en, this message translates to:
  /// **'Manage Novel Repo URLs'**
  String get manage_novel_repo_urls;

  /// No description provided for @url_cannot_be_empty.
  ///
  /// In en, this message translates to:
  /// **'URL cannot be empty'**
  String get url_cannot_be_empty;

  /// No description provided for @url_must_end_with_dot_json.
  ///
  /// In en, this message translates to:
  /// **'URL must end with .json'**
  String get url_must_end_with_dot_json;

  /// No description provided for @repo_url.
  ///
  /// In en, this message translates to:
  /// **'Repo URL'**
  String get repo_url;

  /// No description provided for @invalid_url_format.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format'**
  String get invalid_url_format;

  /// No description provided for @clear_all_sources.
  ///
  /// In en, this message translates to:
  /// **'Clear all sources'**
  String get clear_all_sources;

  /// No description provided for @clear_all_sources_msg.
  ///
  /// In en, this message translates to:
  /// **'This will completely erase all sources of the application. Are you sure you want to continue?'**
  String get clear_all_sources_msg;

  /// No description provided for @sources_cleared.
  ///
  /// In en, this message translates to:
  /// **'Sources cleared!!!'**
  String get sources_cleared;

  /// No description provided for @repo_added.
  ///
  /// In en, this message translates to:
  /// **'Source repository added!'**
  String get repo_added;

  /// No description provided for @add_repo.
  ///
  /// In en, this message translates to:
  /// **'Add Repository?'**
  String get add_repo;

  /// No description provided for @genre_search_library.
  ///
  /// In en, this message translates to:
  /// **'Search genre in library'**
  String get genre_search_library;

  /// No description provided for @genre_search_source.
  ///
  /// In en, this message translates to:
  /// **'Browse in source'**
  String get genre_search_source;

  /// No description provided for @source_not_added.
  ///
  /// In en, this message translates to:
  /// **'Source is not installed!'**
  String get source_not_added;

  /// No description provided for @load_own_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Load your own subtitles...'**
  String get load_own_subtitles;

  /// No description provided for @search_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Search subtitles online...'**
  String get search_subtitles;

  /// No description provided for @extension_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String extension_notes(Object notes);

  /// No description provided for @unsupported_repo.
  ///
  /// In en, this message translates to:
  /// **'You\'ve tried to add an unsupported repository. Please check the discord server for support!'**
  String get unsupported_repo;

  /// No description provided for @end_of_chapter.
  ///
  /// In en, this message translates to:
  /// **'End of chapter'**
  String get end_of_chapter;

  /// No description provided for @chapter_completed.
  ///
  /// In en, this message translates to:
  /// **'Chapter completed'**
  String get chapter_completed;

  /// No description provided for @continue_to_next_chapter.
  ///
  /// In en, this message translates to:
  /// **'Continue scrolling to read the next chapter'**
  String get continue_to_next_chapter;

  /// No description provided for @no_next_chapter.
  ///
  /// In en, this message translates to:
  /// **'No next chapter'**
  String get no_next_chapter;

  /// No description provided for @you_have_finished_reading.
  ///
  /// In en, this message translates to:
  /// **'You have finished reading'**
  String get you_have_finished_reading;

  /// No description provided for @return_to_the_list_of_chapters.
  ///
  /// In en, this message translates to:
  /// **'Return to the list of chapters'**
  String get return_to_the_list_of_chapters;

  /// No description provided for @hwdec.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoder'**
  String get hwdec;

  /// No description provided for @enable_hardware_accel.
  ///
  /// In en, this message translates to:
  /// **'Hardware Acceleration'**
  String get enable_hardware_accel;

  /// No description provided for @enable_hardware_accel_info.
  ///
  /// In en, this message translates to:
  /// **'Turn it on/off if you are experiencing bugs or crashes'**
  String get enable_hardware_accel_info;

  /// No description provided for @track_library_navigate.
  ///
  /// In en, this message translates to:
  /// **'Go to existing local entry'**
  String get track_library_navigate;

  /// No description provided for @track_library_add.
  ///
  /// In en, this message translates to:
  /// **'Add to local library'**
  String get track_library_add;

  /// No description provided for @track_library_add_confirm.
  ///
  /// In en, this message translates to:
  /// **'Add tracked item to local library'**
  String get track_library_add_confirm;

  /// No description provided for @track_library_not_logged.
  ///
  /// In en, this message translates to:
  /// **'Login to the corresponding tracker to use this feature!'**
  String get track_library_not_logged;

  /// No description provided for @track_library_switch.
  ///
  /// In en, this message translates to:
  /// **'Switch to another tracker'**
  String get track_library_switch;

  /// No description provided for @go_back.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get go_back;

  /// No description provided for @merge_library_nav_mobile.
  ///
  /// In en, this message translates to:
  /// **'Merge library navigation on mobile'**
  String get merge_library_nav_mobile;

  /// No description provided for @enable_discord_rpc.
  ///
  /// In en, this message translates to:
  /// **'Enable Discord RPC'**
  String get enable_discord_rpc;

  /// No description provided for @hide_discord_rpc_incognito.
  ///
  /// In en, this message translates to:
  /// **'Hide Discord RPC while in Incognito'**
  String get hide_discord_rpc_incognito;

  /// No description provided for @rpc_show_reading_watching_progress.
  ///
  /// In en, this message translates to:
  /// **'Show current chapter in Discord (requires a restart)'**
  String get rpc_show_reading_watching_progress;

  /// No description provided for @rpc_show_title.
  ///
  /// In en, this message translates to:
  /// **'Show current title in Discord'**
  String get rpc_show_title;

  /// No description provided for @rpc_show_cover_image.
  ///
  /// In en, this message translates to:
  /// **'Show current cover image in Discord'**
  String get rpc_show_cover_image;

  /// No description provided for @sync_enable_histories.
  ///
  /// In en, this message translates to:
  /// **'Sync history data'**
  String get sync_enable_histories;

  /// No description provided for @sync_enable_updates.
  ///
  /// In en, this message translates to:
  /// **'Sync update data'**
  String get sync_enable_updates;

  /// No description provided for @sync_enable_settings.
  ///
  /// In en, this message translates to:
  /// **'Sync settings'**
  String get sync_enable_settings;

  /// No description provided for @enable_mpv.
  ///
  /// In en, this message translates to:
  /// **'Enable mpv shaders / scripts'**
  String get enable_mpv;

  /// No description provided for @mpv_info.
  ///
  /// In en, this message translates to:
  /// **'Supports .js scripts under mpv/scripts/'**
  String get mpv_info;

  /// No description provided for @mpv_redownload.
  ///
  /// In en, this message translates to:
  /// **'Redownload mpv config files'**
  String get mpv_redownload;

  /// No description provided for @mpv_redownload_info.
  ///
  /// In en, this message translates to:
  /// **'Replaces old config files with new one!'**
  String get mpv_redownload_info;

  /// No description provided for @mpv_download.
  ///
  /// In en, this message translates to:
  /// **'MPV config files are required!\nDownload now?'**
  String get mpv_download;

  /// No description provided for @custom_buttons.
  ///
  /// In en, this message translates to:
  /// **'Custom buttons'**
  String get custom_buttons;

  /// No description provided for @custom_buttons_info.
  ///
  /// In en, this message translates to:
  /// **'Execute lua code with custom buttons'**
  String get custom_buttons_info;

  /// No description provided for @custom_buttons_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit custom buttons'**
  String get custom_buttons_edit;

  /// No description provided for @custom_buttons_add.
  ///
  /// In en, this message translates to:
  /// **'Add custom button'**
  String get custom_buttons_add;

  /// No description provided for @custom_buttons_added.
  ///
  /// In en, this message translates to:
  /// **'Custom button added!'**
  String get custom_buttons_added;

  /// No description provided for @custom_buttons_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete custom button'**
  String get custom_buttons_delete;

  /// No description provided for @custom_buttons_text.
  ///
  /// In en, this message translates to:
  /// **'Button text'**
  String get custom_buttons_text;

  /// No description provided for @custom_buttons_text_req.
  ///
  /// In en, this message translates to:
  /// **'Button text required'**
  String get custom_buttons_text_req;

  /// No description provided for @custom_buttons_js_code.
  ///
  /// In en, this message translates to:
  /// **'lua code'**
  String get custom_buttons_js_code;

  /// No description provided for @custom_buttons_js_code_req.
  ///
  /// In en, this message translates to:
  /// **'lua code required'**
  String get custom_buttons_js_code_req;

  /// No description provided for @custom_buttons_js_code_long.
  ///
  /// In en, this message translates to:
  /// **'lua code (on long press)'**
  String get custom_buttons_js_code_long;

  /// No description provided for @custom_buttons_startup.
  ///
  /// In en, this message translates to:
  /// **'lua code (on startup)'**
  String get custom_buttons_startup;

  /// No description provided for @n_days.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String n_days(Object n);

  /// No description provided for @decoder.
  ///
  /// In en, this message translates to:
  /// **'Decoder'**
  String get decoder;

  /// No description provided for @decoder_info.
  ///
  /// In en, this message translates to:
  /// **'Hardware decoding, pixel format, debanding'**
  String get decoder_info;

  /// No description provided for @enable_gpu_next.
  ///
  /// In en, this message translates to:
  /// **'Enable gpu-next (Android only)'**
  String get enable_gpu_next;

  /// No description provided for @enable_gpu_next_info.
  ///
  /// In en, this message translates to:
  /// **'A new video rendering backend'**
  String get enable_gpu_next_info;

  /// No description provided for @debanding.
  ///
  /// In en, this message translates to:
  /// **'Debanding'**
  String get debanding;

  /// No description provided for @use_yuv420p.
  ///
  /// In en, this message translates to:
  /// **'Use YUV420P pixel format'**
  String get use_yuv420p;

  /// No description provided for @use_yuv420p_info.
  ///
  /// In en, this message translates to:
  /// **'May fix black screens on some video codecs, can also improve performance at the cost of quality'**
  String get use_yuv420p_info;

  /// No description provided for @audio_preferred_languages.
  ///
  /// In en, this message translates to:
  /// **'Preferred langauages'**
  String get audio_preferred_languages;

  /// No description provided for @audio_preferred_languages_info.
  ///
  /// In en, this message translates to:
  /// **'Audio langauage(s) to be selected by default on a video with multiple audio streams, 2/3-letter languages codes (e.g.: en, de, fr) work. Multiple values can be delimited by a comma.'**
  String get audio_preferred_languages_info;

  /// No description provided for @enable_audio_pitch_correction.
  ///
  /// In en, this message translates to:
  /// **'Enable audio pitch correction'**
  String get enable_audio_pitch_correction;

  /// No description provided for @enable_audio_pitch_correction_info.
  ///
  /// In en, this message translates to:
  /// **'Prevents the audio from becoming high-pitched at faster speeds and low-pitched at slower speeds'**
  String get enable_audio_pitch_correction_info;

  /// No description provided for @audio_channels.
  ///
  /// In en, this message translates to:
  /// **'Audio channels'**
  String get audio_channels;

  /// No description provided for @volume_boost_cap.
  ///
  /// In en, this message translates to:
  /// **'Volume boost cap'**
  String get volume_boost_cap;

  /// No description provided for @internal_player.
  ///
  /// In en, this message translates to:
  /// **'Internal player'**
  String get internal_player;

  /// No description provided for @internal_player_info.
  ///
  /// In en, this message translates to:
  /// **'Progress, controls, orientation'**
  String get internal_player_info;

  /// No description provided for @subtitle_delay_text.
  ///
  /// In en, this message translates to:
  /// **'Subtitle delay'**
  String get subtitle_delay_text;

  /// No description provided for @subtitle_delay.
  ///
  /// In en, this message translates to:
  /// **'Delay (ms)'**
  String get subtitle_delay;

  /// No description provided for @subtitle_speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get subtitle_speed;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get schedule;

  /// No description provided for @calendar_no_data.
  ///
  /// In en, this message translates to:
  /// **'No data yet.'**
  String get calendar_no_data;

  /// No description provided for @calendar_info.
  ///
  /// In en, this message translates to:
  /// **'The calendar is only able to predict the next chapter upload based on the older uploads. Some data might not be 100% accurate!'**
  String get calendar_info;

  /// No description provided for @in_n_day.
  ///
  /// In en, this message translates to:
  /// **'in {days} day'**
  String in_n_day(Object days);

  /// No description provided for @in_n_days.
  ///
  /// In en, this message translates to:
  /// **'in {days} days'**
  String in_n_days(Object days);

  /// No description provided for @clear_library.
  ///
  /// In en, this message translates to:
  /// **'Clear library'**
  String get clear_library;

  /// No description provided for @clear_library_desc.
  ///
  /// In en, this message translates to:
  /// **'Choose to clear all manga, anime and/or novel entries'**
  String get clear_library_desc;

  /// No description provided for @clear_library_input.
  ///
  /// In en, this message translates to:
  /// **'Type \'manga\', \'anime\' and/or \'novel\' (separated by a comma) to remove all related entries'**
  String get clear_library_input;

  /// No description provided for @watch_order.
  ///
  /// In en, this message translates to:
  /// **'Watch order'**
  String get watch_order;

  /// No description provided for @sequels.
  ///
  /// In en, this message translates to:
  /// **'Sequels'**
  String get sequels;

  /// No description provided for @recommendations_similarity.
  ///
  /// In en, this message translates to:
  /// **'Similarity:'**
  String get recommendations_similarity;

  /// No description provided for @local_folder_structure.
  ///
  /// In en, this message translates to:
  /// **'Structure of a local folder'**
  String get local_folder_structure;

  /// No description provided for @local_folder.
  ///
  /// In en, this message translates to:
  /// **'Local folders'**
  String get local_folder;

  /// No description provided for @add_local_folder.
  ///
  /// In en, this message translates to:
  /// **'Add local folder'**
  String get add_local_folder;

  /// No description provided for @rescan_local_folder.
  ///
  /// In en, this message translates to:
  /// **'Rescan all local folders now'**
  String get rescan_local_folder;

  /// No description provided for @export_metadata.
  ///
  /// In en, this message translates to:
  /// **'Export metadata'**
  String get export_metadata;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exported;

  /// No description provided for @text_size.
  ///
  /// In en, this message translates to:
  /// **'Text Size :'**
  String get text_size;

  /// No description provided for @text_align.
  ///
  /// In en, this message translates to:
  /// **'Text Align'**
  String get text_align;

  /// No description provided for @line_height.
  ///
  /// In en, this message translates to:
  /// **'Line Height'**
  String get line_height;

  /// No description provided for @show_scroll_percentage.
  ///
  /// In en, this message translates to:
  /// **'Show Scroll Percentage'**
  String get show_scroll_percentage;

  /// No description provided for @remove_extra_paragraph_spacing.
  ///
  /// In en, this message translates to:
  /// **'Remove Extra Paragraph Spacing'**
  String get remove_extra_paragraph_spacing;

  /// No description provided for @select_label_color.
  ///
  /// In en, this message translates to:
  /// **'Select {label} Color'**
  String select_label_color(Object label);

  /// No description provided for @default_user_agent.
  ///
  /// In en, this message translates to:
  /// **'Default user agent'**
  String get default_user_agent;

  /// No description provided for @forceLandscapeMode.
  ///
  /// In en, this message translates to:
  /// **'Force landscape mode'**
  String get forceLandscapeMode;

  /// No description provided for @forceLandscapeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Force the player to use landscape orientation.'**
  String get forceLandscapeModeSubtitle;

  /// No description provided for @dns_over_https.
  ///
  /// In en, this message translates to:
  /// **'DNS-over-HTTPS (DoH)'**
  String get dns_over_https;

  /// No description provided for @dns_provider.
  ///
  /// In en, this message translates to:
  /// **'DNS Provider'**
  String get dns_provider;

  /// No description provided for @tracked.
  ///
  /// In en, this message translates to:
  /// **'Tracked'**
  String get tracked;

  /// No description provided for @auth_unlock_msg.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock Watchtower'**
  String get auth_unlock_msg;

  /// No description provided for @app_locked.
  ///
  /// In en, this message translates to:
  /// **'Watchtower is locked'**
  String get app_locked;

  /// No description provided for @auth_to_continue.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to continue'**
  String get auth_to_continue;

  /// No description provided for @authenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating...'**
  String get authenticating;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @auth_to_change_security_setting.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to change security settings'**
  String get auth_to_change_security_setting;

  /// No description provided for @app_lock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get app_lock;

  /// No description provided for @require_biometric_or_device_credential.
  ///
  /// In en, this message translates to:
  /// **'Require biometric or device credential to open the app'**
  String get require_biometric_or_device_credential;

  /// No description provided for @biometric_or_device_credential_not_available.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication not available on this device'**
  String get biometric_or_device_credential_not_available;

  /// No description provided for @app_lock_description.
  ///
  /// In en, this message translates to:
  /// **'When app lock is enabled, you will be asked to authenticate \nevery time you open the app or switch back to it from the background.'**
  String get app_lock_description;

  /// No description provided for @keep_screen_on.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get keep_screen_on;

  /// No description provided for @webtoon_side_padding.
  ///
  /// In en, this message translates to:
  /// **'Webtoon side padding'**
  String get webtoon_side_padding;

  /// No description provided for @show_page_gaps.
  ///
  /// In en, this message translates to:
  /// **'Show page gaps'**
  String get show_page_gaps;

  /// No description provided for @invert_colors.
  ///
  /// In en, this message translates to:
  /// **'Invert colors'**
  String get invert_colors;

  /// No description provided for @grayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get grayscale;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @navigation_layout.
  ///
  /// In en, this message translates to:
  /// **'Navigation layout'**
  String get navigation_layout;

  /// No description provided for @nav_layout_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get nav_layout_default;

  /// No description provided for @nav_layout_l_shaped.
  ///
  /// In en, this message translates to:
  /// **'L-shaped'**
  String get nav_layout_l_shaped;

  /// No description provided for @nav_layout_kindle.
  ///
  /// In en, this message translates to:
  /// **'Kindle-ish'**
  String get nav_layout_kindle;

  /// No description provided for @nav_layout_edge.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get nav_layout_edge;

  /// No description provided for @nav_layout_right_and_left.
  ///
  /// In en, this message translates to:
  /// **'Right and left'**
  String get nav_layout_right_and_left;

  /// No description provided for @nav_layout_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get nav_layout_disabled;

  /// No description provided for @color_enhancements.
  ///
  /// In en, this message translates to:
  /// **'Color enhancements'**
  String get color_enhancements;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @mean_per_title.
  ///
  /// In en, this message translates to:
  /// **'Mean per Title'**
  String get mean_per_title;

  /// No description provided for @completion_rate.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get completion_rate;

  /// No description provided for @watching_time.
  ///
  /// In en, this message translates to:
  /// **'Watch Time'**
  String get watching_time;

  /// No description provided for @reading_time.
  ///
  /// In en, this message translates to:
  /// **'Reading Time'**
  String get reading_time;

  /// No description provided for @average_chapters_per_title.
  ///
  /// In en, this message translates to:
  /// **'Average Chapters per {title}'**
  String average_chapters_per_title(Object title);

  /// No description provided for @read_percentage.
  ///
  /// In en, this message translates to:
  /// **'Read Percentage'**
  String get read_percentage;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entries;

  /// No description provided for @android_proxy_server_mihon.
  ///
  /// In en, this message translates to:
  /// **'Android Proxy Server (Mihon)'**
  String get android_proxy_server_mihon;

  /// No description provided for @android_proxy_server_mihon_description.
  ///
  /// In en, this message translates to:
  /// **'Download and configure the proxy server required to use Mihon extensions.'**
  String get android_proxy_server_mihon_description;

  /// No description provided for @mihon_proxy_server.
  ///
  /// In en, this message translates to:
  /// **'Mihon proxy server'**
  String get mihon_proxy_server;

  /// No description provided for @extension_server_intro_with_jre.
  ///
  /// In en, this message translates to:
  /// **'Download the proxy server bundle before using Mihon extensions. The bundle includes the JRE and extension server JAR.'**
  String get extension_server_intro_with_jre;

  /// No description provided for @extension_server_intro_ios.
  ///
  /// In en, this message translates to:
  /// **'Download the proxy server JAR before using Mihon extensions. iOS only needs the extension server JAR.'**
  String get extension_server_intro_ios;

  /// No description provided for @checking_files.
  ///
  /// In en, this message translates to:
  /// **'Checking files'**
  String get checking_files;

  /// No description provided for @files_installed.
  ///
  /// In en, this message translates to:
  /// **'Files installed'**
  String get files_installed;

  /// No description provided for @files_missing.
  ///
  /// In en, this message translates to:
  /// **'Files missing'**
  String get files_missing;

  /// No description provided for @update_files.
  ///
  /// In en, this message translates to:
  /// **'Update files'**
  String get update_files;

  /// No description provided for @up_to_date.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get up_to_date;

  /// No description provided for @choose_location.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get choose_location;

  /// No description provided for @import_existing_jar.
  ///
  /// In en, this message translates to:
  /// **'Import existing JAR'**
  String get import_existing_jar;

  /// No description provided for @detect_files_in_selected_folder.
  ///
  /// In en, this message translates to:
  /// **'Detect files in selected folder'**
  String get detect_files_in_selected_folder;

  /// No description provided for @preparing_download.
  ///
  /// In en, this message translates to:
  /// **'Preparing download...'**
  String get preparing_download;

  /// No description provided for @app_install_location.
  ///
  /// In en, this message translates to:
  /// **'App install location'**
  String get app_install_location;

  /// No description provided for @install_location.
  ///
  /// In en, this message translates to:
  /// **'Install location'**
  String get install_location;

  /// No description provided for @jre_executable.
  ///
  /// In en, this message translates to:
  /// **'JRE executable'**
  String get jre_executable;

  /// No description provided for @extension_server_jar.
  ///
  /// In en, this message translates to:
  /// **'Extension server JAR'**
  String get extension_server_jar;

  /// No description provided for @installed_version.
  ///
  /// In en, this message translates to:
  /// **'Installed version'**
  String get installed_version;

  /// No description provided for @latest_version.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get latest_version;

  /// No description provided for @apkbridge_description.
  ///
  /// In en, this message translates to:
  /// **'Use ApkBridge when you need a separate Android device proxy. Set the proxy address here and download the APK from GitHub.'**
  String get apkbridge_description;

  /// No description provided for @set_proxy_address.
  ///
  /// In en, this message translates to:
  /// **'Set proxy address'**
  String get set_proxy_address;

  /// No description provided for @no_newer_proxy_server_release_available.
  ///
  /// In en, this message translates to:
  /// **'No newer proxy server release is available.'**
  String get no_newer_proxy_server_release_available;

  /// No description provided for @could_not_check_proxy_server_updates.
  ///
  /// In en, this message translates to:
  /// **'Could not check for proxy server updates.'**
  String get could_not_check_proxy_server_updates;

  /// No description provided for @no_extension_server_bundle_available_for_this_platform.
  ///
  /// In en, this message translates to:
  /// **'No extension server bundle is available for this platform.'**
  String get no_extension_server_bundle_available_for_this_platform;

  /// No description provided for @failed_to_download_bundle.
  ///
  /// In en, this message translates to:
  /// **'Failed to download bundle ({statusCode}).'**
  String failed_to_download_bundle(Object statusCode);

  /// No description provided for @downloaded_bundle_missing_expected_files.
  ///
  /// In en, this message translates to:
  /// **'The downloaded bundle does not contain the expected files.'**
  String get downloaded_bundle_missing_expected_files;

  /// No description provided for @extension_server_files_ready.
  ///
  /// In en, this message translates to:
  /// **'Extension server files are ready.'**
  String get extension_server_files_ready;

  /// No description provided for @ios_extension_server_import_hint.
  ///
  /// In en, this message translates to:
  /// **'On iOS the server is installed inside the app sandbox. Use \"Import existing JAR\" to bring in a downloaded file.'**
  String get ios_extension_server_import_hint;

  /// No description provided for @select_extension_server_folder.
  ///
  /// In en, this message translates to:
  /// **'Select extension server folder'**
  String get select_extension_server_folder;

  /// No description provided for @selected_folder_does_not_exist.
  ///
  /// In en, this message translates to:
  /// **'The selected folder does not exist.'**
  String get selected_folder_does_not_exist;

  /// No description provided for @no_extension_server_files_found_in_selected_folder.
  ///
  /// In en, this message translates to:
  /// **'No extension server files were found in the selected folder.'**
  String get no_extension_server_files_found_in_selected_folder;

  /// No description provided for @extension_server_files_linked.
  ///
  /// In en, this message translates to:
  /// **'Extension server files were linked.'**
  String get extension_server_files_linked;

  /// No description provided for @select_extension_server_jar.
  ///
  /// In en, this message translates to:
  /// **'Select extension server JAR'**
  String get select_extension_server_jar;

  /// No description provided for @selected_file_could_not_be_accessed.
  ///
  /// In en, this message translates to:
  /// **'The selected file could not be accessed.'**
  String get selected_file_could_not_be_accessed;

  /// No description provided for @extension_server_jar_imported.
  ///
  /// In en, this message translates to:
  /// **'Extension server JAR was imported.'**
  String get extension_server_jar_imported;

  /// No description provided for @could_not_launch_apk_bridge_page.
  ///
  /// In en, this message translates to:
  /// **'Could not launch the ApkBridge page.'**
  String get could_not_launch_apk_bridge_page;

  /// No description provided for @proxy_server_ip_hint.
  ///
  /// In en, this message translates to:
  /// **'Server IP (e.g., 10.0.0.5 or https://example.com)'**
  String get proxy_server_ip_hint;

  /// No description provided for @not_configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get not_configured;

  /// No description provided for @webview.
  ///
  /// In en, this message translates to:
  /// **'Webview'**
  String get webview;

  /// No description provided for @tts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get tts;

  /// No description provided for @tts_speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get tts_speed;

  /// No description provided for @tts_pitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get tts_pitch;

  /// No description provided for @tts_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get tts_language;

  /// No description provided for @tts_voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get tts_voice;

  /// No description provided for @tts_stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tts_stop;

  /// No description provided for @tts_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get tts_play;

  /// No description provided for @tts_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tts_pause;

  /// No description provided for @tts_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous paragraph'**
  String get tts_previous;

  /// No description provided for @tts_next.
  ///
  /// In en, this message translates to:
  /// **'Next paragraph'**
  String get tts_next;

  /// No description provided for @tts_paragraph_progress.
  ///
  /// In en, this message translates to:
  /// **'Paragraph {current} of {total}'**
  String tts_paragraph_progress(Object current, Object total);

  /// No description provided for @tts_settings.
  ///
  /// In en, this message translates to:
  /// **'TTS Settings'**
  String get tts_settings;

  /// No description provided for @tts_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get tts_default;

  /// No description provided for @view_all.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get view_all;

  /// No description provided for @for_you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get for_you;

  /// No description provided for @following_tab.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following_tab;

  /// No description provided for @explore_tab.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore_tab;

  /// No description provided for @browser_dock_tabs.
  ///
  /// In en, this message translates to:
  /// **'Browser tabs'**
  String get browser_dock_tabs;

  /// No description provided for @browser_dock_new_tab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get browser_dock_new_tab;

  /// No description provided for @browser_dock_more.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get browser_dock_more;

  /// No description provided for @browser_dock_collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse dock'**
  String get browser_dock_collapse;

  /// No description provided for @browser_dock_expand.
  ///
  /// In en, this message translates to:
  /// **'Show dock'**
  String get browser_dock_expand;

  /// No description provided for @catalog_tag_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get catalog_tag_watch;

  /// No description provided for @catalog_tag_read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get catalog_tag_read;

  /// No description provided for @catalog_tag_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get catalog_tag_manga;

  /// No description provided for @catalog_tag_manhwa.
  ///
  /// In en, this message translates to:
  /// **'Manhwa'**
  String get catalog_tag_manhwa;

  /// No description provided for @catalog_tag_manhua.
  ///
  /// In en, this message translates to:
  /// **'Manhua'**
  String get catalog_tag_manhua;

  /// No description provided for @catalog_tag_webtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get catalog_tag_webtoon;

  /// No description provided for @catalog_tag_comics.
  ///
  /// In en, this message translates to:
  /// **'Comics'**
  String get catalog_tag_comics;

  /// No description provided for @catalog_tag_novel.
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get catalog_tag_novel;

  /// No description provided for @catalog_tag_anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get catalog_tag_anime;

  /// No description provided for @catalog_tag_animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get catalog_tag_animation;

  /// No description provided for @catalog_tag_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get catalog_tag_movies;

  /// No description provided for @catalog_tag_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get catalog_tag_series;

  /// No description provided for @catalog_tag_documentary.
  ///
  /// In en, this message translates to:
  /// **'Documentaries'**
  String get catalog_tag_documentary;

  /// No description provided for @catalog_tag_jav.
  ///
  /// In en, this message translates to:
  /// **'JAV'**
  String get catalog_tag_jav;

  /// No description provided for @catalog_tag_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get catalog_tag_music;

  /// No description provided for @catalog_tag_game.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get catalog_tag_game;

  /// No description provided for @catalog_tag_action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get catalog_tag_action;

  /// No description provided for @catalog_tag_adventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get catalog_tag_adventure;

  /// No description provided for @catalog_tag_fantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get catalog_tag_fantasy;

  /// No description provided for @catalog_tag_science_fiction.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get catalog_tag_science_fiction;

  /// No description provided for @catalog_tag_romance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get catalog_tag_romance;

  /// No description provided for @catalog_tag_mystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get catalog_tag_mystery;

  /// No description provided for @catalog_tag_drama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get catalog_tag_drama;

  /// No description provided for @catalog_tag_comedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get catalog_tag_comedy;

  /// No description provided for @catalog_tag_horror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get catalog_tag_horror;

  /// No description provided for @catalog_tag_thriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get catalog_tag_thriller;

  /// No description provided for @catalog_tag_historical.
  ///
  /// In en, this message translates to:
  /// **'Historical'**
  String get catalog_tag_historical;

  /// No description provided for @catalog_tag_slice_of_life.
  ///
  /// In en, this message translates to:
  /// **'Slice of Life'**
  String get catalog_tag_slice_of_life;

  /// No description provided for @catalog_tag_mecha.
  ///
  /// In en, this message translates to:
  /// **'Mecha'**
  String get catalog_tag_mecha;

  /// No description provided for @catalog_tag_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get catalog_tag_sports;

  /// No description provided for @catalog_tag_multilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual'**
  String get catalog_tag_multilingual;

  /// No description provided for @catalog_tag_french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get catalog_tag_french;

  /// No description provided for @catalog_tag_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get catalog_tag_english;

  /// No description provided for @catalog_tag_spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get catalog_tag_spanish;

  /// No description provided for @catalog_tag_german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get catalog_tag_german;

  /// No description provided for @catalog_tag_italian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get catalog_tag_italian;

  /// No description provided for @catalog_tag_portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get catalog_tag_portuguese;

  /// No description provided for @catalog_tag_japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get catalog_tag_japanese;

  /// No description provided for @catalog_tag_korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get catalog_tag_korean;

  /// No description provided for @catalog_tag_chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get catalog_tag_chinese;

  /// No description provided for @catalog_tag_arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get catalog_tag_arabic;

  /// No description provided for @catalog_tag_russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get catalog_tag_russian;

  /// No description provided for @catalog_tag_turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get catalog_tag_turkish;

  /// No description provided for @catalog_tag_thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get catalog_tag_thai;

  /// No description provided for @catalog_tag_indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get catalog_tag_indonesian;

  /// No description provided for @catalog_tag_hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get catalog_tag_hindi;

  /// No description provided for @catalog_tag_vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get catalog_tag_vietnamese;

  /// No description provided for @catalog_tag_polish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get catalog_tag_polish;

  /// No description provided for @catalog_tag_dutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get catalog_tag_dutch;

  /// No description provided for @catalog_tag_featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get catalog_tag_featured;

  /// No description provided for @catalog_tag_new.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get catalog_tag_new;

  /// No description provided for @catalog_tag_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get catalog_tag_popular;

  /// No description provided for @catalog_tag_trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get catalog_tag_trending;

  /// No description provided for @catalog_shelf_watch_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular to watch'**
  String get catalog_shelf_watch_popular;

  /// No description provided for @catalog_shelf_read_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular to read'**
  String get catalog_shelf_read_popular;

  /// No description provided for @catalog_shelf_new_watch.
  ///
  /// In en, this message translates to:
  /// **'New watch sources'**
  String get catalog_shelf_new_watch;

  /// No description provided for @catalog_shelf_new_read.
  ///
  /// In en, this message translates to:
  /// **'New reading sources'**
  String get catalog_shelf_new_read;

  /// No description provided for @catalog_shelf_new.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get catalog_shelf_new;

  /// No description provided for @catalog_shelf_recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get catalog_shelf_recommended;

  /// No description provided for @catalog_shelf_featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get catalog_shelf_featured;

  /// No description provided for @catalog_shelf_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get catalog_shelf_movies;

  /// No description provided for @catalog_shelf_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get catalog_shelf_series;

  /// No description provided for @catalog_shelf_anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get catalog_shelf_anime;

  /// No description provided for @catalog_shelf_animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get catalog_shelf_animation;

  /// No description provided for @catalog_shelf_documentaries.
  ///
  /// In en, this message translates to:
  /// **'Documentaries'**
  String get catalog_shelf_documentaries;

  /// No description provided for @catalog_shelf_science_fiction.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get catalog_shelf_science_fiction;

  /// No description provided for @catalog_shelf_fantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get catalog_shelf_fantasy;

  /// No description provided for @catalog_shelf_action_adventure.
  ///
  /// In en, this message translates to:
  /// **'Action and adventure'**
  String get catalog_shelf_action_adventure;

  /// No description provided for @catalog_shelf_romance_mystery.
  ///
  /// In en, this message translates to:
  /// **'Romance and mystery'**
  String get catalog_shelf_romance_mystery;

  /// No description provided for @catalog_shelf_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get catalog_shelf_manga;

  /// No description provided for @catalog_shelf_manga_manhwa.
  ///
  /// In en, this message translates to:
  /// **'Manga and manhwa'**
  String get catalog_shelf_manga_manhwa;

  /// No description provided for @catalog_shelf_manhwa.
  ///
  /// In en, this message translates to:
  /// **'Manhwa'**
  String get catalog_shelf_manhwa;

  /// No description provided for @catalog_shelf_manhua.
  ///
  /// In en, this message translates to:
  /// **'Manhua'**
  String get catalog_shelf_manhua;

  /// No description provided for @catalog_shelf_webtoons.
  ///
  /// In en, this message translates to:
  /// **'Webtoons'**
  String get catalog_shelf_webtoons;

  /// No description provided for @catalog_shelf_comics.
  ///
  /// In en, this message translates to:
  /// **'Comics and graphic novels'**
  String get catalog_shelf_comics;

  /// No description provided for @catalog_shelf_novels.
  ///
  /// In en, this message translates to:
  /// **'Novels and light novels'**
  String get catalog_shelf_novels;

  /// No description provided for @catalog_shelf_french.
  ///
  /// In en, this message translates to:
  /// **'French sources'**
  String get catalog_shelf_french;

  /// No description provided for @catalog_shelf_english.
  ///
  /// In en, this message translates to:
  /// **'English sources'**
  String get catalog_shelf_english;

  /// No description provided for @catalog_shelf_multilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual sources'**
  String get catalog_shelf_multilingual;

  /// No description provided for @catalog_shelf_scifi_fantasy.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi and fantasy'**
  String get catalog_shelf_scifi_fantasy;

  /// No description provided for @catalog_shelf_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get catalog_shelf_music;

  /// No description provided for @catalog_shelf_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get catalog_shelf_games;

  /// No description provided for @catalog_shelf_order_curated.
  ///
  /// In en, this message translates to:
  /// **'Featured first, then most recently added'**
  String get catalog_shelf_order_curated;

  /// No description provided for @catalog_shelf_empty.
  ///
  /// In en, this message translates to:
  /// **'No extension matches this selection yet.'**
  String get catalog_shelf_empty;

  /// No description provided for @catalog_see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get catalog_see_all;

  /// No description provided for @catalog_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get catalog_back;

  /// No description provided for @catalog_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load the catalogue.'**
  String get catalog_error;

  /// No description provided for @marketplace_all_extensions.
  ///
  /// In en, this message translates to:
  /// **'All {type} extensions'**
  String marketplace_all_extensions(Object type);

  /// No description provided for @catalog_shelf_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension} other{{count} extensions}}'**
  String catalog_shelf_count(num count);

  /// No description provided for @marketplace_explore_by_language.
  ///
  /// In en, this message translates to:
  /// **'Explore by language'**
  String get marketplace_explore_by_language;

  /// No description provided for @marketplace_whole_catalogue.
  ///
  /// In en, this message translates to:
  /// **'The whole catalogue'**
  String get marketplace_whole_catalogue;

  /// No description provided for @catalog_shelf_adult_watch.
  ///
  /// In en, this message translates to:
  /// **'Midnight World'**
  String get catalog_shelf_adult_watch;

  /// No description provided for @catalog_shelf_adult_read.
  ///
  /// In en, this message translates to:
  /// **'Midnight Library'**
  String get catalog_shelf_adult_read;

  /// No description provided for @catalog_shelf_for_you_watch.
  ///
  /// In en, this message translates to:
  /// **'For you · to watch'**
  String get catalog_shelf_for_you_watch;

  /// No description provided for @catalog_shelf_for_you_read.
  ///
  /// In en, this message translates to:
  /// **'For you · to read'**
  String get catalog_shelf_for_you_read;

  /// No description provided for @catalog_card_see_more.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get catalog_card_see_more;

  /// No description provided for @catalog_card_see_less.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get catalog_card_see_less;

  /// No description provided for @catalog_card_open_site.
  ///
  /// In en, this message translates to:
  /// **'Open the website'**
  String get catalog_card_open_site;

  /// No description provided for @catalog_card_open_site_unavailable.
  ///
  /// In en, this message translates to:
  /// **'No website for this extension'**
  String get catalog_card_open_site_unavailable;

  /// No description provided for @plugins_section_builtin.
  ///
  /// In en, this message translates to:
  /// **'Built-in plugins'**
  String get plugins_section_builtin;

  /// No description provided for @plugins_section_engines.
  ///
  /// In en, this message translates to:
  /// **'Components and engines'**
  String get plugins_section_engines;

  /// No description provided for @plugins_section_empty.
  ///
  /// In en, this message translates to:
  /// **'No plugin available.'**
  String get plugins_section_empty;

  /// No description provided for @plugins_nfile_title.
  ///
  /// In en, this message translates to:
  /// **'NFile — file manager'**
  String get plugins_nfile_title;

  /// No description provided for @plugins_nfile_description.
  ///
  /// In en, this message translates to:
  /// **'Built-in file explorer with players and management tools.'**
  String get plugins_nfile_description;

  /// No description provided for @plugins_smart_library_description.
  ///
  /// In en, this message translates to:
  /// **'Scans and organises the videos, mangas and music already on the device.'**
  String get plugins_smart_library_description;

  /// No description provided for @plugins_ffmpeg_bundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled with the app — no installation required.'**
  String get plugins_ffmpeg_bundled;

  /// No description provided for @plugins_mpv_description.
  ///
  /// In en, this message translates to:
  /// **'Downloads only mpv.conf, input.conf and the scripts.'**
  String get plugins_mpv_description;

  /// No description provided for @plugins_action_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get plugins_action_open;

  /// No description provided for @plugins_action_info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get plugins_action_info;

  /// No description provided for @plugins_action_install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get plugins_action_install;

  /// No description provided for @plugins_action_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get plugins_action_close;

  /// No description provided for @plugins_mpv_config_exception.
  ///
  /// In en, this message translates to:
  /// **'The MPV configuration folder is unavailable.'**
  String get plugins_mpv_config_exception;

  /// No description provided for @plugins_ffmpeg_title.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg'**
  String get plugins_ffmpeg_title;

  /// No description provided for @plugins_ffmpeg_info.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg is bundled with Watchtower. It performs a single stream-copy mux of the downloaded HLS fragments (MPEG-TS or fMP4) into the final MP4.\n\nNo download, no separate runtime: assembly works offline and does not depend on an external executable.'**
  String get plugins_ffmpeg_info;

  /// No description provided for @plugins_smart_library_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Library'**
  String get plugins_smart_library_title;

  /// No description provided for @plugins_mpv_title.
  ///
  /// In en, this message translates to:
  /// **'MPV configuration'**
  String get plugins_mpv_title;

  /// No description provided for @plugins_music_title.
  ///
  /// In en, this message translates to:
  /// **'Music plugins'**
  String get plugins_music_title;

  /// No description provided for @catalog_tab_for_you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get catalog_tab_for_you;

  /// No description provided for @catalog_tab_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get catalog_tab_watch;

  /// No description provided for @catalog_tab_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get catalog_tab_manga;

  /// No description provided for @catalog_tab_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get catalog_tab_music;

  /// No description provided for @catalog_tab_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get catalog_tab_games;

  /// No description provided for @catalog_tab_novels.
  ///
  /// In en, this message translates to:
  /// **'Novels'**
  String get catalog_tab_novels;

  /// No description provided for @marketplace_search_results.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get marketplace_search_results;

  /// No description provided for @marketplace_empty_search_title.
  ///
  /// In en, this message translates to:
  /// **'No extension found'**
  String get marketplace_empty_search_title;

  /// No description provided for @marketplace_empty_catalog_title.
  ///
  /// In en, this message translates to:
  /// **'No extension available'**
  String get marketplace_empty_catalog_title;

  /// No description provided for @marketplace_empty_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Try another name or refresh the catalogue.'**
  String get marketplace_empty_search_hint;

  /// No description provided for @marketplace_empty_catalog_hint.
  ///
  /// In en, this message translates to:
  /// **'The catalogue is empty right now. Try again later.'**
  String get marketplace_empty_catalog_hint;

  /// No description provided for @marketplace_empty_semantics.
  ///
  /// In en, this message translates to:
  /// **'Empty catalogue'**
  String get marketplace_empty_semantics;

  /// No description provided for @marketplace_settings_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Marketplace settings'**
  String get marketplace_settings_tooltip;

  /// No description provided for @marketplace_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search extensions'**
  String get marketplace_search_hint;

  /// No description provided for @marketplace_recent_searches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get marketplace_recent_searches;

  /// No description provided for @marketplace_popular_searches.
  ///
  /// In en, this message translates to:
  /// **'Popular searches'**
  String get marketplace_popular_searches;

  /// No description provided for @marketplace_browse_by_category.
  ///
  /// In en, this message translates to:
  /// **'Browse by category'**
  String get marketplace_browse_by_category;

  /// No description provided for @marketplace_nsfw_gate_title.
  ///
  /// In en, this message translates to:
  /// **'Adult content hidden'**
  String get marketplace_nsfw_gate_title;

  /// No description provided for @marketplace_nsfw_gate_body.
  ///
  /// In en, this message translates to:
  /// **'Enable adult content in the preferences to show these extensions.'**
  String get marketplace_nsfw_gate_body;

  /// No description provided for @marketplace_nsfw_gate_show.
  ///
  /// In en, this message translates to:
  /// **'Show adult content'**
  String get marketplace_nsfw_gate_show;

  /// No description provided for @marketplace_account_title.
  ///
  /// In en, this message translates to:
  /// **'Watchtower account'**
  String get marketplace_account_title;

  /// No description provided for @marketplace_manage_installed.
  ///
  /// In en, this message translates to:
  /// **'Manage installed extensions'**
  String get marketplace_manage_installed;

  /// No description provided for @marketplace_preferences.
  ///
  /// In en, this message translates to:
  /// **'Marketplace preferences'**
  String get marketplace_preferences;

  /// No description provided for @marketplace_help_feedback.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get marketplace_help_feedback;

  /// No description provided for @marketplace_details_title.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get marketplace_details_title;

  /// No description provided for @marketplace_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'{label} is coming soon.'**
  String marketplace_coming_soon(Object label);

  /// No description provided for @marketplace_source_blurb.
  ///
  /// In en, this message translates to:
  /// **'{language} source to discover {kind} in Watchtower.'**
  String marketplace_source_blurb(Object language, Object kind);

  /// No description provided for @marketplace_kind_anime.
  ///
  /// In en, this message translates to:
  /// **'anime and series'**
  String get marketplace_kind_anime;

  /// No description provided for @marketplace_kind_manga.
  ///
  /// In en, this message translates to:
  /// **'mangas and comics'**
  String get marketplace_kind_manga;

  /// No description provided for @marketplace_kind_novel.
  ///
  /// In en, this message translates to:
  /// **'novels and light novels'**
  String get marketplace_kind_novel;

  /// No description provided for @marketplace_kind_music.
  ///
  /// In en, this message translates to:
  /// **'music and audio'**
  String get marketplace_kind_music;

  /// No description provided for @marketplace_kind_default.
  ///
  /// In en, this message translates to:
  /// **'content'**
  String get marketplace_kind_default;

  /// No description provided for @marketplace_lang_french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get marketplace_lang_french;

  /// No description provided for @marketplace_lang_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get marketplace_lang_english;

  /// No description provided for @marketplace_lang_multilingual.
  ///
  /// In en, this message translates to:
  /// **'multilingual'**
  String get marketplace_lang_multilingual;

  /// No description provided for @marketplace_unknown_size.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get marketplace_unknown_size;

  /// No description provided for @marketplace_reviews_count.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String marketplace_reviews_count(Object count);

  /// No description provided for @marketplace_reviews_unavailable.
  ///
  /// In en, this message translates to:
  /// **'No reviews available'**
  String get marketplace_reviews_unavailable;

  /// No description provided for @marketplace_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get marketplace_update;

  /// No description provided for @marketplace_extension_installed.
  ///
  /// In en, this message translates to:
  /// **'Extension installed'**
  String get marketplace_extension_installed;

  /// No description provided for @marketplace_about_extension.
  ///
  /// In en, this message translates to:
  /// **'About this extension'**
  String get marketplace_about_extension;

  /// No description provided for @marketplace_info_access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get marketplace_info_access;

  /// No description provided for @marketplace_info_community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get marketplace_info_community;

  /// No description provided for @marketplace_info_repo.
  ///
  /// In en, this message translates to:
  /// **'Repository and provenance'**
  String get marketplace_info_repo;

  /// No description provided for @marketplace_official_repo_note.
  ///
  /// In en, this message translates to:
  /// **'Updated through the official Watchtower Extensions repository.'**
  String get marketplace_official_repo_note;

  /// No description provided for @marketplace_ntfy_signals.
  ///
  /// In en, this message translates to:
  /// **'ntfy signals'**
  String get marketplace_ntfy_signals;

  /// No description provided for @marketplace_source_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} source} other{{count} sources}}'**
  String marketplace_source_count(num count);

  /// No description provided for @marketplace_installed_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension installed} other{{count} extensions installed}}'**
  String marketplace_installed_count(num count);

  /// No description provided for @marketplace_info_information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get marketplace_info_information;

  /// No description provided for @marketplace_info_technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get marketplace_info_technology;

  /// No description provided for @marketplace_info_reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get marketplace_info_reading;

  /// No description provided for @marketplace_info_catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get marketplace_info_catalog;

  /// No description provided for @marketplace_info_content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get marketplace_info_content;

  /// No description provided for @marketplace_access_required.
  ///
  /// In en, this message translates to:
  /// **'Account required'**
  String get marketplace_access_required;

  /// No description provided for @marketplace_aggregator.
  ///
  /// In en, this message translates to:
  /// **'Aggregator'**
  String get marketplace_aggregator;

  /// No description provided for @marketplace_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get marketplace_comments;

  /// No description provided for @marketplace_available_version.
  ///
  /// In en, this message translates to:
  /// **'available v{version}'**
  String marketplace_available_version(Object version);

  /// No description provided for @marketplace_catalog_unavailable.
  ///
  /// In en, this message translates to:
  /// **'The catalogue is unavailable'**
  String get marketplace_catalog_unavailable;

  /// No description provided for @marketplace_check_connection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get marketplace_check_connection;

  /// No description provided for @marketplace_update_available.
  ///
  /// In en, this message translates to:
  /// **'Update available · v{version}'**
  String marketplace_update_available(String version);

  /// No description provided for @marketplace_installed_version_label.
  ///
  /// In en, this message translates to:
  /// **'Installed v{version}'**
  String marketplace_installed_version_label(String version);

  /// No description provided for @marketplace_info_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get marketplace_info_size;

  /// No description provided for @marketplace_load_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load the marketplace'**
  String get marketplace_load_error;

  /// No description provided for @marketplace_search_extension_hint.
  ///
  /// In en, this message translates to:
  /// **'Search an extension…'**
  String get marketplace_search_extension_hint;

  /// No description provided for @marketplace_search_apps_hint.
  ///
  /// In en, this message translates to:
  /// **'Search apps and games…'**
  String get marketplace_search_apps_hint;

  /// No description provided for @marketplace_filter_extensions.
  ///
  /// In en, this message translates to:
  /// **'Filter extensions'**
  String get marketplace_filter_extensions;

  /// No description provided for @marketplace_search_language_hint.
  ///
  /// In en, this message translates to:
  /// **'Search a language…'**
  String get marketplace_search_language_hint;

  /// No description provided for @marketplace_browse_extensions.
  ///
  /// In en, this message translates to:
  /// **'Browse extensions'**
  String get marketplace_browse_extensions;

  /// No description provided for @marketplace_clear_all_filters.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get marketplace_clear_all_filters;

  /// No description provided for @marketplace_installed_only.
  ///
  /// In en, this message translates to:
  /// **'Installed only'**
  String get marketplace_installed_only;

  /// No description provided for @marketplace_installed_only_sub.
  ///
  /// In en, this message translates to:
  /// **'Hide extensions that are not installed'**
  String get marketplace_installed_only_sub;

  /// No description provided for @marketplace_updates_available.
  ///
  /// In en, this message translates to:
  /// **'Updates available'**
  String get marketplace_updates_available;

  /// No description provided for @marketplace_updates_available_sub.
  ///
  /// In en, this message translates to:
  /// **'Extensions with a new version'**
  String get marketplace_updates_available_sub;

  /// No description provided for @marketplace_all_option.
  ///
  /// In en, this message translates to:
  /// **'(all)'**
  String get marketplace_all_option;

  /// No description provided for @marketplace_nothing_to_install.
  ///
  /// In en, this message translates to:
  /// **'Nothing to install'**
  String get marketplace_nothing_to_install;

  /// No description provided for @marketplace_check_updates_subtitle.
  ///
  /// In en, this message translates to:
  /// **'When the app starts'**
  String get marketplace_check_updates_subtitle;

  /// No description provided for @marketplace_auto_update_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Without confirmation'**
  String get marketplace_auto_update_subtitle;

  /// No description provided for @marketplace_adult_content_title.
  ///
  /// In en, this message translates to:
  /// **'18+ content'**
  String get marketplace_adult_content_title;

  /// No description provided for @marketplace_adult_content_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show NSFW extensions'**
  String get marketplace_adult_content_subtitle;

  /// No description provided for @marketplace_manage_repositories.
  ///
  /// In en, this message translates to:
  /// **'Manage repositories'**
  String get marketplace_manage_repositories;

  /// No description provided for @marketplace_reload_catalogue.
  ///
  /// In en, this message translates to:
  /// **'Reload the catalogue'**
  String get marketplace_reload_catalogue;

  /// No description provided for @marketplace_bulk_install.
  ///
  /// In en, this message translates to:
  /// **'Bulk install'**
  String get marketplace_bulk_install;

  /// No description provided for @marketplace_ntfy_error_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Push an alert on error'**
  String get marketplace_ntfy_error_subtitle;

  /// No description provided for @plugins_third_party_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Install this plugin?'**
  String get plugins_third_party_confirm_title;

  /// No description provided for @plugins_third_party_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Third-party plugin from {owner}.\n\nIt will access the APIs declared in its manifest.\n\nLong-press the card to uninstall.'**
  String plugins_third_party_confirm_body(Object owner);

  /// No description provided for @plugins_auth_required_body.
  ///
  /// In en, this message translates to:
  /// **'This plugin requires authentication.\nOpen Music Hub → Settings → Sources, select this plugin as the default source, then tap “Sign in”.'**
  String get plugins_auth_required_body;

  /// No description provided for @marketplace_error_load_failed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Failed to load {count} repository} other{Failed to load {count} repositories}}'**
  String marketplace_error_load_failed(num count);

  /// No description provided for @marketplace_error_http.
  ///
  /// In en, this message translates to:
  /// **'HTTP {status} for {url}'**
  String marketplace_error_http(Object status, Object url);

  /// No description provided for @marketplace_error_empty_response.
  ///
  /// In en, this message translates to:
  /// **'Empty response for {url}'**
  String marketplace_error_empty_response(Object url);

  /// No description provided for @marketplace_error_plugin_not_registered.
  ///
  /// In en, this message translates to:
  /// **'Plugin {name} was not registered after the download.'**
  String marketplace_error_plugin_not_registered(Object name);

  /// No description provided for @marketplace_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String marketplace_error_generic(Object error);

  /// No description provided for @marketplace_error_uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall error: {error}'**
  String marketplace_error_uninstall(Object error);

  /// No description provided for @marketplace_error_not_installed.
  ///
  /// In en, this message translates to:
  /// **'Extension {name} could not be installed. No active source was recorded.'**
  String marketplace_error_not_installed(Object name);

  /// No description provided for @marketplace_error_layout_not_saved.
  ///
  /// In en, this message translates to:
  /// **'The UI layout of {name} was not saved.'**
  String marketplace_error_layout_not_saved(Object name);

  /// No description provided for @marketplace_error_layout_unreadable.
  ///
  /// In en, this message translates to:
  /// **'The UI layout of {name} is unreadable.'**
  String marketplace_error_layout_unreadable(Object name);

  /// No description provided for @marketplace_error_categories_not_saved.
  ///
  /// In en, this message translates to:
  /// **'The categories of {name} were not saved.'**
  String marketplace_error_categories_not_saved(Object name);

  /// No description provided for @marketplace_error_content_types_not_saved.
  ///
  /// In en, this message translates to:
  /// **'The content types of {name} were not saved.'**
  String marketplace_error_content_types_not_saved(Object name);

  /// No description provided for @marketplace_error_audio_plugin_missing.
  ///
  /// In en, this message translates to:
  /// **'Audio plugin not found in local storage.'**
  String get marketplace_error_audio_plugin_missing;

  /// No description provided for @marketplace_error_extension_missing.
  ///
  /// In en, this message translates to:
  /// **'Extension not found in local storage.'**
  String get marketplace_error_extension_missing;

  /// No description provided for @marketplace_uninstall_title.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {name}'**
  String marketplace_uninstall_title(Object name);

  /// No description provided for @marketplace_uninstall_body.
  ///
  /// In en, this message translates to:
  /// **'The extension will be uninstalled. It can be reinstalled at any time.'**
  String get marketplace_uninstall_body;

  /// No description provided for @marketplace_uninstalled_toast.
  ///
  /// In en, this message translates to:
  /// **'{name} uninstalled'**
  String marketplace_uninstalled_toast(Object name);

  /// No description provided for @marketplace_bulk_install_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Install {count} extension} other{Install {count} extensions}}'**
  String marketplace_bulk_install_count(num count);

  /// No description provided for @marketplace_bulk_install_confirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension to install} other{{count} extensions to install}}'**
  String marketplace_bulk_install_confirm(num count);

  /// No description provided for @marketplace_settings_section_behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get marketplace_settings_section_behavior;

  /// No description provided for @marketplace_settings_section_repositories.
  ///
  /// In en, this message translates to:
  /// **'Repositories'**
  String get marketplace_settings_section_repositories;

  /// No description provided for @marketplace_settings_section_cache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get marketplace_settings_section_cache;

  /// No description provided for @marketplace_settings_section_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get marketplace_settings_section_actions;

  /// No description provided for @marketplace_force_reload.
  ///
  /// In en, this message translates to:
  /// **'Force reload (bypass cache)'**
  String get marketplace_force_reload;

  /// No description provided for @marketplace_installed_toast.
  ///
  /// In en, this message translates to:
  /// **'{name} installed'**
  String marketplace_installed_toast(Object name);

  /// No description provided for @marketplace_repository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get marketplace_repository;

  /// No description provided for @marketplace_default_metadata_provider.
  ///
  /// In en, this message translates to:
  /// **'Default metadata provider'**
  String get marketplace_default_metadata_provider;

  /// No description provided for @marketplace_currently_default.
  ///
  /// In en, this message translates to:
  /// **'Currently the default'**
  String get marketplace_currently_default;

  /// No description provided for @marketplace_set_default_provider.
  ///
  /// In en, this message translates to:
  /// **'Set as default provider'**
  String get marketplace_set_default_provider;

  /// No description provided for @marketplace_default_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Default audio source'**
  String get marketplace_default_audio_source;

  /// No description provided for @marketplace_set_default_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Set as default audio source'**
  String get marketplace_set_default_audio_source;

  /// No description provided for @marketplace_update_available_short.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get marketplace_update_available_short;

  /// No description provided for @marketplace_with_updates_short.
  ///
  /// In en, this message translates to:
  /// **'With updates'**
  String get marketplace_with_updates_short;

  /// No description provided for @marketplace_section_show.
  ///
  /// In en, this message translates to:
  /// **'SHOW'**
  String get marketplace_section_show;

  /// No description provided for @marketplace_section_active_filters.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE FILTERS'**
  String get marketplace_section_active_filters;

  /// No description provided for @marketplace_advanced_filters.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get marketplace_advanced_filters;

  /// No description provided for @marketplace_sort_installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get marketplace_sort_installed;

  /// No description provided for @marketplace_selected_count.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String marketplace_selected_count(Object count);

  /// No description provided for @marketplace_progress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} processed'**
  String marketplace_progress(Object done, Object total);

  /// No description provided for @marketplace_failed_count.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String marketplace_failed_count(Object count);

  /// No description provided for @marketplace_size_kb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String marketplace_size_kb(Object value);

  /// No description provided for @marketplace_size_mb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String marketplace_size_mb(Object value);

  /// No description provided for @marketplace_kind_subtitles.
  ///
  /// In en, this message translates to:
  /// **'subtitles and caption tracks'**
  String get marketplace_kind_subtitles;

  /// No description provided for @marketplace_type_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get marketplace_type_subtitles;

  /// No description provided for @marketplace_got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get marketplace_got_it;

  /// No description provided for @marketplace_installing_progress.
  ///
  /// In en, this message translates to:
  /// **'Installing… {done}/{total}'**
  String marketplace_installing_progress(Object done, Object total);

  /// No description provided for @browse_installing_all.
  ///
  /// In en, this message translates to:
  /// **'Installing all extensions…'**
  String get browse_installing_all;

  /// No description provided for @browse_installed_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension installed} other{{count} extensions installed}}'**
  String browse_installed_count(num count);

  /// No description provided for @browse_uninstall_all_title.
  ///
  /// In en, this message translates to:
  /// **'Uninstall all'**
  String get browse_uninstall_all_title;

  /// No description provided for @browse_uninstall_all_body.
  ///
  /// In en, this message translates to:
  /// **'Really uninstall every installed extension?'**
  String get browse_uninstall_all_body;

  /// No description provided for @browse_uninstalled_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension uninstalled} other{{count} extensions uninstalled}}'**
  String browse_uninstalled_count(num count);

  /// No description provided for @browse_updating_all.
  ///
  /// In en, this message translates to:
  /// **'Updating all extensions…'**
  String get browse_updating_all;

  /// No description provided for @browse_updated_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension updated} other{{count} extensions updated}}'**
  String browse_updated_count(num count);

  /// No description provided for @browse_no_active_source.
  ///
  /// In en, this message translates to:
  /// **'No active source installed.'**
  String get browse_no_active_source;

  /// No description provided for @browse_opening_source.
  ///
  /// In en, this message translates to:
  /// **'Opening \"{name}\"…'**
  String browse_opening_source(Object name);

  /// No description provided for @browse_global_search_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Global search · long-press = diagnostic'**
  String get browse_global_search_tooltip;

  /// No description provided for @browse_more_options.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get browse_more_options;

  /// No description provided for @browse_custom_sections.
  ///
  /// In en, this message translates to:
  /// **'My sections'**
  String get browse_custom_sections;

  /// No description provided for @browse_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get browse_marketplace;

  /// No description provided for @browse_how_to_local_source.
  ///
  /// In en, this message translates to:
  /// **'How To — Local Source'**
  String get browse_how_to_local_source;

  /// No description provided for @browse_random_source.
  ///
  /// In en, this message translates to:
  /// **'Random source'**
  String get browse_random_source;

  /// No description provided for @browse_diagnostic.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic'**
  String get browse_diagnostic;

  /// No description provided for @browse_plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get browse_plugins;

  /// No description provided for @browse_sources_limited.
  ///
  /// In en, this message translates to:
  /// **'Sources limited to {lang} + EN'**
  String browse_sources_limited(Object lang);

  /// No description provided for @browse_all_languages_restored.
  ///
  /// In en, this message translates to:
  /// **'All languages re-enabled'**
  String get browse_all_languages_restored;

  /// No description provided for @marketplace_tag_adult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get marketplace_tag_adult;

  /// No description provided for @marketplace_sort_alpha.
  ///
  /// In en, this message translates to:
  /// **'A → Z'**
  String get marketplace_sort_alpha;

  /// No description provided for @notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications_title;

  /// No description provided for @notifications_refresh_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get notifications_refresh_tooltip;

  /// No description provided for @notifications_load_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load the notifications.'**
  String get notifications_load_error;

  /// No description provided for @notifications_checking_updates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get notifications_checking_updates;

  /// No description provided for @notifications_updates_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your installed extensions have a new version.'**
  String get notifications_updates_subtitle;

  /// No description provided for @notifications_update_single.
  ///
  /// In en, this message translates to:
  /// **'{name} extension update'**
  String notifications_update_single(Object name);

  /// No description provided for @notifications_update_message.
  ///
  /// In en, this message translates to:
  /// **'{name} extension update'**
  String notifications_update_message(Object name);

  /// No description provided for @notifications_updates_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension update} other{{count} extension updates}}'**
  String notifications_updates_count(num count);

  /// No description provided for @notifications_install_all.
  ///
  /// In en, this message translates to:
  /// **'Install all'**
  String get notifications_install_all;

  /// No description provided for @notifications_install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get notifications_install;

  /// No description provided for @notifications_dismiss_update.
  ///
  /// In en, this message translates to:
  /// **'Hide this update'**
  String get notifications_dismiss_update;

  /// No description provided for @notifications_updated_toast.
  ///
  /// In en, this message translates to:
  /// **'{name} updated'**
  String notifications_updated_toast(Object name);

  /// No description provided for @notifications_install_failed.
  ///
  /// In en, this message translates to:
  /// **'Install failed: {error}'**
  String notifications_install_failed(Object error);

  /// No description provided for @notifications_new_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} new extension published} other{{count} new extensions published}}'**
  String notifications_new_count(num count);

  /// No description provided for @notifications_new_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover the latest extensions in the catalogue.'**
  String get notifications_new_subtitle;

  /// No description provided for @notifications_browse_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Browse the Marketplace'**
  String get notifications_browse_marketplace;

  /// No description provided for @notifications_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide this notification'**
  String get notifications_hide;

  /// No description provided for @notifications_library_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} library update} other{{count} library updates}}'**
  String notifications_library_count(num count);

  /// No description provided for @notifications_library_subtitle.
  ///
  /// In en, this message translates to:
  /// **'New chapters are available.'**
  String get notifications_library_subtitle;

  /// No description provided for @notifications_view_updates.
  ///
  /// In en, this message translates to:
  /// **'View updates'**
  String get notifications_view_updates;

  /// No description provided for @notifications_none.
  ///
  /// In en, this message translates to:
  /// **'No new notification'**
  String get notifications_none;

  /// No description provided for @marketplace_search_categories_title.
  ///
  /// In en, this message translates to:
  /// **'Browse by category'**
  String get marketplace_search_categories_title;

  /// No description provided for @marketplace_search_recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get marketplace_search_recommended;

  /// No description provided for @marketplace_search_all_results.
  ///
  /// In en, this message translates to:
  /// **'All results'**
  String get marketplace_search_all_results;

  /// No description provided for @marketplace_search_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get marketplace_search_sort;

  /// No description provided for @marketplace_search_filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get marketplace_search_filters;

  /// No description provided for @marketplace_search_no_results_title.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get marketplace_search_no_results_title;

  /// No description provided for @marketplace_search_no_results_body.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search.'**
  String get marketplace_search_no_results_body;

  /// No description provided for @marketplace_sort_recent.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get marketplace_sort_recent;

  /// No description provided for @marketplace_search_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get marketplace_search_sort_title;

  /// No description provided for @marketplace_search_suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get marketplace_search_suggestions;

  /// No description provided for @marketplace_search_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get marketplace_search_clear;

  /// No description provided for @marketplace_search_results_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} result} other{{count} results}}'**
  String marketplace_search_results_count(num count);

  /// No description provided for @obNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get obNext;

  /// No description provided for @obStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get obStart;

  /// No description provided for @obBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get obBack;

  /// No description provided for @obContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get obContinue;

  /// No description provided for @obSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get obSkipForNow;

  /// No description provided for @obEnterWatchtower.
  ///
  /// In en, this message translates to:
  /// **'Enter Watchtower'**
  String get obEnterWatchtower;

  /// No description provided for @obPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get obPermissionsTitle;

  /// No description provided for @obPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watchtower needs a few permissions to run properly.'**
  String get obPermissionsSubtitle;

  /// No description provided for @obOptionalSection.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL'**
  String get obOptionalSection;

  /// No description provided for @obPermStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get obPermStorageTitle;

  /// No description provided for @obPermStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow full file access for downloads and Smart Library.'**
  String get obPermStorageSubtitle;

  /// No description provided for @obPermStorageIosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'iOS sandbox access — no action required.'**
  String get obPermStorageIosSubtitle;

  /// No description provided for @obPermNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get obPermNotifTitle;

  /// No description provided for @obPermNotifSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads and library update alerts.'**
  String get obPermNotifSubtitle;

  /// No description provided for @obPermInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'App installation'**
  String get obPermInstallTitle;

  /// No description provided for @obPermInstallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Install APK updates directly from the app.'**
  String get obPermInstallSubtitle;

  /// No description provided for @obPermOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay / PiP'**
  String get obPermOverlayTitle;

  /// No description provided for @obPermOverlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the video floating over other apps.'**
  String get obPermOverlaySubtitle;

  /// No description provided for @obPermBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'No battery restriction'**
  String get obPermBatteryTitle;

  /// No description provided for @obPermBatterySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stops Android from killing background downloads (Doze, standby).'**
  String get obPermBatterySubtitle;

  /// No description provided for @obGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get obGrant;

  /// No description provided for @obGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get obGranted;

  /// No description provided for @obShowcaseHeadline.
  ///
  /// In en, this message translates to:
  /// **'Anime, manga, novels, music, films, series and games — all in one place.'**
  String get obShowcaseHeadline;

  /// No description provided for @obSloganWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch.'**
  String get obSloganWatch;

  /// No description provided for @obSloganRead.
  ///
  /// In en, this message translates to:
  /// **'Read.'**
  String get obSloganRead;

  /// No description provided for @obSloganListen.
  ///
  /// In en, this message translates to:
  /// **'Listen.'**
  String get obSloganListen;

  /// No description provided for @obSloganAll.
  ///
  /// In en, this message translates to:
  /// **'All.'**
  String get obSloganAll;

  /// No description provided for @obSloganSub.
  ///
  /// In en, this message translates to:
  /// **'One place for everything you love.'**
  String get obSloganSub;

  /// No description provided for @migTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration'**
  String get migTitle;

  /// No description provided for @migHeadline.
  ///
  /// In en, this message translates to:
  /// **'Bring your library with you.'**
  String get migHeadline;

  /// No description provided for @migSpeech.
  ///
  /// In en, this message translates to:
  /// **'Coming from Mihon, Aniyomi, Mangayomi or another app? Watchtower reads their backups and folders, then rebuilds your library, categories, reading progress and downloads here.'**
  String get migSpeech;

  /// No description provided for @migTabManga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get migTabManga;

  /// No description provided for @migTabAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get migTabAnime;

  /// No description provided for @migTabUniversal.
  ///
  /// In en, this message translates to:
  /// **'Universal'**
  String get migTabUniversal;

  /// No description provided for @migSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search an app…'**
  String get migSearchHint;

  /// No description provided for @migFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get migFilterTitle;

  /// No description provided for @migFilterPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get migFilterPlatform;

  /// No description provided for @migFilterOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source only'**
  String get migFilterOpenSource;

  /// No description provided for @migFilterWithBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup import supported'**
  String get migFilterWithBackup;

  /// No description provided for @migFilterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get migFilterReset;

  /// No description provided for @migSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get migSortTitle;

  /// No description provided for @migSortName.
  ///
  /// In en, this message translates to:
  /// **'Alphabetically'**
  String get migSortName;

  /// No description provided for @migSortPlatform.
  ///
  /// In en, this message translates to:
  /// **'By platform'**
  String get migSortPlatform;

  /// No description provided for @migMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get migMoreTitle;

  /// No description provided for @migMoreSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all apps'**
  String get migMoreSelectAll;

  /// No description provided for @migMoreClear.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get migMoreClear;

  /// No description provided for @migMoreGuide.
  ///
  /// In en, this message translates to:
  /// **'Migration guide'**
  String get migMoreGuide;

  /// No description provided for @migMoreRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get migMoreRefresh;

  /// No description provided for @migAppsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app} other{{count} apps}}'**
  String migAppsCount(int count);

  /// No description provided for @migEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No app matches your search.'**
  String get migEmptySearch;

  /// No description provided for @migPros.
  ///
  /// In en, this message translates to:
  /// **'Pros'**
  String get migPros;

  /// No description provided for @migCons.
  ///
  /// In en, this message translates to:
  /// **'Cons'**
  String get migCons;

  /// No description provided for @migOfficialSite.
  ///
  /// In en, this message translates to:
  /// **'Official site'**
  String get migOfficialSite;

  /// No description provided for @migBackupFormat.
  ///
  /// In en, this message translates to:
  /// **'Backup format'**
  String get migBackupFormat;

  /// No description provided for @migPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get migPlatforms;

  /// No description provided for @migSupported.
  ///
  /// In en, this message translates to:
  /// **'Import supported'**
  String get migSupported;

  /// No description provided for @migSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get migSelect;

  /// No description provided for @migSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get migSelected;

  /// No description provided for @migWhatToImport.
  ///
  /// In en, this message translates to:
  /// **'What to import'**
  String get migWhatToImport;

  /// No description provided for @migImportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library and categories'**
  String get migImportLibrary;

  /// No description provided for @migImportLibrarySub.
  ///
  /// In en, this message translates to:
  /// **'Titles, covers, categories and read state.'**
  String get migImportLibrarySub;

  /// No description provided for @migImportDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapters'**
  String get migImportDownloads;

  /// No description provided for @migImportDownloadsSub.
  ///
  /// In en, this message translates to:
  /// **'Copy or move the files Mihon already downloaded.'**
  String get migImportDownloadsSub;

  /// No description provided for @migImportHistory.
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get migImportHistory;

  /// No description provided for @migImportHistorySub.
  ///
  /// In en, this message translates to:
  /// **'Resume each series where you stopped.'**
  String get migImportHistorySub;

  /// No description provided for @migImportSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get migImportSettings;

  /// No description provided for @migImportSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Theme, reader and download preferences.'**
  String get migImportSettingsSub;

  /// No description provided for @migBackupSource.
  ///
  /// In en, this message translates to:
  /// **'Backup file'**
  String get migBackupSource;

  /// No description provided for @migBackupSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the .tachibk backup exported by the app.'**
  String get migBackupSourceHint;

  /// No description provided for @migPickBackup.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get migPickBackup;

  /// No description provided for @migDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Downloads folder'**
  String get migDownloadFolder;

  /// No description provided for @migDownloadFolderHint.
  ///
  /// In en, this message translates to:
  /// **'The folder where the other app stored its downloads.'**
  String get migDownloadFolderHint;

  /// No description provided for @migPickFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get migPickFolder;

  /// No description provided for @migNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get migNoFile;

  /// No description provided for @migFileMode.
  ///
  /// In en, this message translates to:
  /// **'File handling'**
  String get migFileMode;

  /// No description provided for @migCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get migCopy;

  /// No description provided for @migCopySub.
  ///
  /// In en, this message translates to:
  /// **'Keeps the original files in place.'**
  String get migCopySub;

  /// No description provided for @migMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get migMove;

  /// No description provided for @migMoveSub.
  ///
  /// In en, this message translates to:
  /// **'Frees the space the other app used.'**
  String get migMoveSub;

  /// No description provided for @migScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get migScan;

  /// No description provided for @migScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get migScanning;

  /// No description provided for @migScanResultLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry in the backup} other{{count} entries in the backup}}'**
  String migScanResultLibrary(int count);

  /// No description provided for @migScanResultDownloads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 downloaded chapter found} other{{count} downloaded chapters found}}'**
  String migScanResultDownloads(int count);

  /// No description provided for @migScanResultNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing detected yet.'**
  String get migScanResultNone;

  /// No description provided for @migStartImport.
  ///
  /// In en, this message translates to:
  /// **'Start import'**
  String get migStartImport;

  /// No description provided for @migImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get migImporting;

  /// No description provided for @migImportDone.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get migImportDone;

  /// No description provided for @migImportLibraryDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry imported} other{{count} entries imported}}'**
  String migImportLibraryDone(int count);

  /// No description provided for @migImportDownloadsDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download imported} other{{count} downloads imported}}'**
  String migImportDownloadsDone(int count);

  /// No description provided for @migImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The import could not finish.'**
  String get migImportFailed;

  /// No description provided for @migNeedSelection.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one thing to import.'**
  String get migNeedSelection;

  /// No description provided for @migDetectedApps.
  ///
  /// In en, this message translates to:
  /// **'Apps detected on this device'**
  String get migDetectedApps;

  /// No description provided for @migNoDetectedApps.
  ///
  /// In en, this message translates to:
  /// **'No other app data found. You can still pick a backup manually.'**
  String get migNoDetectedApps;

  /// No description provided for @migFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'More than a library'**
  String get migFeatureTitle;

  /// No description provided for @migFeatureTrackers.
  ///
  /// In en, this message translates to:
  /// **'Trackers and AniList/MAL progress follow your titles.'**
  String get migFeatureTrackers;

  /// No description provided for @migFeatureSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync keeps every device aligned.'**
  String get migFeatureSync;

  /// No description provided for @migFeatureExtensions.
  ///
  /// In en, this message translates to:
  /// **'Install extensions to add new sources.'**
  String get migFeatureExtensions;

  /// No description provided for @migFeatureSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart Library rebuilds shelves from your files.'**
  String get migFeatureSmart;

  /// No description provided for @migFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Everything is processed on your device. Nothing is uploaded.'**
  String get migFooterHint;

  /// No description provided for @migProMangaReader.
  ///
  /// In en, this message translates to:
  /// **'Manga reading app'**
  String get migProMangaReader;

  /// No description provided for @migProAnimeWatcher.
  ///
  /// In en, this message translates to:
  /// **'Anime watching app'**
  String get migProAnimeWatcher;

  /// No description provided for @migProLightNovelReader.
  ///
  /// In en, this message translates to:
  /// **'Light novel reading app'**
  String get migProLightNovelReader;

  /// No description provided for @migProBothAnimeManga.
  ///
  /// In en, this message translates to:
  /// **'Supports both anime and manga'**
  String get migProBothAnimeManga;

  /// No description provided for @migProAnimeLnManga.
  ///
  /// In en, this message translates to:
  /// **'Supports anime, light novels and manga'**
  String get migProAnimeLnManga;

  /// No description provided for @migProManySources.
  ///
  /// In en, this message translates to:
  /// **'Many extension sources available'**
  String get migProManySources;

  /// No description provided for @migProManySourcesShort.
  ///
  /// In en, this message translates to:
  /// **'Many sources available'**
  String get migProManySourcesShort;

  /// No description provided for @migProOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get migProOpenSource;

  /// No description provided for @migProActivelyDeveloped.
  ///
  /// In en, this message translates to:
  /// **'Actively developed'**
  String get migProActivelyDeveloped;

  /// No description provided for @migProLongTrackRecord.
  ///
  /// In en, this message translates to:
  /// **'Long track record'**
  String get migProLongTrackRecord;

  /// No description provided for @migProCrossPlatform.
  ///
  /// In en, this message translates to:
  /// **'Cross platform (Android, iOS, Mac, Windows, Linux)'**
  String get migProCrossPlatform;

  /// No description provided for @migProDesktopPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Supports Windows, Linux and Mac'**
  String get migProDesktopPlatforms;

  /// No description provided for @migProOpenExtensionSystem.
  ///
  /// In en, this message translates to:
  /// **'Open extension system'**
  String get migProOpenExtensionSystem;

  /// No description provided for @migProNiceUi.
  ///
  /// In en, this message translates to:
  /// **'Nice user interface'**
  String get migProNiceUi;

  /// No description provided for @migProIntegration.
  ///
  /// In en, this message translates to:
  /// **'Integrates with many other apps (backups and extensions)'**
  String get migProIntegration;

  /// No description provided for @migProTracker.
  ///
  /// In en, this message translates to:
  /// **'Manga tracker'**
  String get migProTracker;

  /// No description provided for @migProTrackReleases.
  ///
  /// In en, this message translates to:
  /// **'Tracks new chapter releases across sites'**
  String get migProTrackReleases;

  /// No description provided for @migProEbookOutput.
  ///
  /// In en, this message translates to:
  /// **'Generates e-book output'**
  String get migProEbookOutput;

  /// No description provided for @migProBatchZip.
  ///
  /// In en, this message translates to:
  /// **'Batch .zip download'**
  String get migProBatchZip;

  /// No description provided for @migProLargeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Very large library'**
  String get migProLargeLibrary;

  /// No description provided for @migProMangadexClient.
  ///
  /// In en, this message translates to:
  /// **'Focused MangaDex client'**
  String get migProMangadexClient;

  /// No description provided for @migProSameAsMihon.
  ///
  /// In en, this message translates to:
  /// **'Everything Mihon does, plus more'**
  String get migProSameAsMihon;

  /// No description provided for @migProCombinesForks.
  ///
  /// In en, this message translates to:
  /// **'Combines features from several Mihon forks'**
  String get migProCombinesForks;

  /// No description provided for @migProEh.
  ///
  /// In en, this message translates to:
  /// **'E-Hentai and ExHentai integration'**
  String get migProEh;

  /// No description provided for @migConAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Android only'**
  String get migConAndroidOnly;

  /// No description provided for @migConDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'Desktop only'**
  String get migConDesktopOnly;

  /// No description provided for @migConNeedExtension.
  ///
  /// In en, this message translates to:
  /// **'Need to install an extension to use'**
  String get migConNeedExtension;

  /// No description provided for @migConExtensionSeparate.
  ///
  /// In en, this message translates to:
  /// **'Extensions installed separately'**
  String get migConExtensionSeparate;

  /// No description provided for @migConOriginalUnmaintained.
  ///
  /// In en, this message translates to:
  /// **'Original repository no longer maintained'**
  String get migConOriginalUnmaintained;

  /// No description provided for @migConNotIosStore.
  ///
  /// In en, this message translates to:
  /// **'Not in the iOS App Store'**
  String get migConNotIosStore;

  /// No description provided for @migConNeedPlugins.
  ///
  /// In en, this message translates to:
  /// **'Need to install plugins to use'**
  String get migConNeedPlugins;

  /// No description provided for @migConLessPopular.
  ///
  /// In en, this message translates to:
  /// **'Less popular'**
  String get migConLessPopular;

  /// No description provided for @migConNewApp.
  ///
  /// In en, this message translates to:
  /// **'New app, less popular'**
  String get migConNewApp;

  /// No description provided for @migConOnlyMangadex.
  ///
  /// In en, this message translates to:
  /// **'Only MangaDex content'**
  String get migConOnlyMangadex;

  /// No description provided for @migConCannotReadOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot read offline'**
  String get migConCannotReadOffline;

  /// No description provided for @migConArchived.
  ///
  /// In en, this message translates to:
  /// **'Original repository archived'**
  String get migConArchived;

  /// No description provided for @migConTorrent.
  ///
  /// In en, this message translates to:
  /// **'Depends on a torrent connection'**
  String get migConTorrent;

  /// No description provided for @migConIosDonors.
  ///
  /// In en, this message translates to:
  /// **'iOS build only for donors'**
  String get migConIosDonors;

  /// No description provided for @migConRaw.
  ///
  /// In en, this message translates to:
  /// **'Manga are untranslated (raw)'**
  String get migConRaw;

  /// No description provided for @migConBareboneSearch.
  ///
  /// In en, this message translates to:
  /// **'Bare-bones search and filter'**
  String get migConBareboneSearch;

  /// No description provided for @migConNotDifferent.
  ///
  /// In en, this message translates to:
  /// **'Not drastically different'**
  String get migConNotDifferent;

  /// No description provided for @migConRelativelyNew.
  ///
  /// In en, this message translates to:
  /// **'Relatively new'**
  String get migConRelativelyNew;

  /// No description provided for @migConMissingNewFeatures.
  ///
  /// In en, this message translates to:
  /// **'Missing features added in the parent app'**
  String get migConMissingNewFeatures;

  /// No description provided for @migDetectedBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup found'**
  String get migDetectedBackup;

  /// No description provided for @migDetectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads found'**
  String get migDetectedDownloads;

  /// Title of the local transfer / share room screen.
  ///
  /// In en, this message translates to:
  /// **'Share room'**
  String get transfer_title;

  /// Lobby subtitle explaining local sharing.
  ///
  /// In en, this message translates to:
  /// **'Share your downloads with other devices on the same WiFi network, without internet.'**
  String get transfer_subtitle;

  /// Count of chapters available to share.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter available to share} other{{count} chapters available to share}}'**
  String transfer_chapters_available(num count);

  /// Button that joins the local share room.
  ///
  /// In en, this message translates to:
  /// **'JOIN THE ROOM'**
  String get transfer_join_room;

  /// Reassurance that transfer stays on the local network.
  ///
  /// In en, this message translates to:
  /// **'LAN / Hotspot only · no external server'**
  String get transfer_lan_only;

  /// Section header listing discovered devices.
  ///
  /// In en, this message translates to:
  /// **'Devices in the room'**
  String get transfer_devices_in_room;

  /// Section header for in-progress transfers.
  ///
  /// In en, this message translates to:
  /// **'Downloads in progress'**
  String get transfer_active_downloads;

  /// Section header for finished transfers.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transfer_completed;

  /// Snackbar confirming a transfer started.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Download of 1 file started} other{Download of {count} files started}}'**
  String transfer_started_download(num count);

  /// Title of the local room top bar.
  ///
  /// In en, this message translates to:
  /// **'Local room'**
  String get transfer_local_room;

  /// Badge showing the room is live.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get transfer_active;

  /// Label of the current device card.
  ///
  /// In en, this message translates to:
  /// **'My device'**
  String get transfer_my_device;

  /// Small badge marking the current device.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get transfer_me;

  /// Summary of what this device shares.
  ///
  /// In en, this message translates to:
  /// **'{mangaCount, plural, =1{1 manga} other{{mangaCount} mangas}} · {chapterCount, plural, =1{1 chapter} other{{chapterCount} chapters}} shared'**
  String transfer_shared_summary(num mangaCount, num chapterCount);

  /// Empty-state title while discovering peers.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get transfer_searching_devices;

  /// Empty-state hint about the network.
  ///
  /// In en, this message translates to:
  /// **'Make sure you are on the same WiFi or hotspot as the other devices.'**
  String get transfer_same_wifi_hint;

  /// Loading indicator for a peer catalogue.
  ///
  /// In en, this message translates to:
  /// **'Loading catalogue…'**
  String get transfer_loading_catalog;

  /// Shown when a peer catalogue cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Catalogue unavailable'**
  String get transfer_catalog_unavailable;

  /// Peer catalogue counts.
  ///
  /// In en, this message translates to:
  /// **'{mangaCount, plural, =1{1 manga} other{{mangaCount} mangas}} · {chapterCount, plural, =1{1 chapter} other{{chapterCount} chapters}}'**
  String transfer_catalog_summary(num mangaCount, num chapterCount);

  /// Button opening a peer catalogue.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get transfer_browse;

  /// Number of files in a transfer session.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String transfer_file_count(num count);

  /// Transfer finished successfully.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transfer_status_done;

  /// Transfer failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transfer_status_failed;

  /// Peer catalogue header when empty.
  ///
  /// In en, this message translates to:
  /// **'Empty catalogue'**
  String get transfer_catalog_empty;

  /// Empty-state when a peer has nothing to share.
  ///
  /// In en, this message translates to:
  /// **'No files available'**
  String get transfer_no_files;

  /// Hint prompting chapter selection.
  ///
  /// In en, this message translates to:
  /// **'Select chapters'**
  String get transfer_select_chapters;

  /// Download button with a selection count.
  ///
  /// In en, this message translates to:
  /// **'Download ({count})'**
  String transfer_download_count(Object count);

  /// Badge for anime items.
  ///
  /// In en, this message translates to:
  /// **'ANIME'**
  String get transfer_type_anime;

  /// Badge for novel items.
  ///
  /// In en, this message translates to:
  /// **'NOVEL'**
  String get transfer_type_novel;

  /// Badge for other items.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get transfer_type_other;

  /// Badge for manga items.
  ///
  /// In en, this message translates to:
  /// **'MANGA'**
  String get transfer_type_manga;

  /// Title of the cross-device transfer instructions.
  ///
  /// In en, this message translates to:
  /// **'How to transfer'**
  String get transfer_howto_title;

  /// Instruction step 1.
  ///
  /// In en, this message translates to:
  /// **'Connect both devices to the same WiFi network or hotspot.'**
  String get transfer_howto_step1;

  /// Instruction step 2.
  ///
  /// In en, this message translates to:
  /// **'On the other device, open Downloads → Transfert and join the room.'**
  String get transfer_howto_step2;

  /// Instruction step 3.
  ///
  /// In en, this message translates to:
  /// **'Tap a device to browse its library, pick chapters, then download.'**
  String get transfer_howto_step3;

  /// Android device label.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get transfer_platform_android;

  /// iOS device label.
  ///
  /// In en, this message translates to:
  /// **'iPhone / iPad'**
  String get transfer_platform_ios;

  /// Windows device label.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get transfer_platform_windows;

  /// macOS device label.
  ///
  /// In en, this message translates to:
  /// **'macOS'**
  String get transfer_platform_macos;

  /// Linux device label.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get transfer_platform_linux;

  /// Web device label.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get transfer_platform_web;

  /// Fallback device label.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get transfer_platform_unknown;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copied_to_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied_to_clipboard;

  /// No description provided for @author_works.
  ///
  /// In en, this message translates to:
  /// **'Works by this author'**
  String get author_works;

  /// No description provided for @select_range.
  ///
  /// In en, this message translates to:
  /// **'Select range'**
  String get select_range;

  /// No description provided for @select_all.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get select_all;

  /// No description provided for @select_invert.
  ///
  /// In en, this message translates to:
  /// **'Invert selection'**
  String get select_invert;

  /// No description provided for @select_none.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get select_none;

  /// No description provided for @download_range.
  ///
  /// In en, this message translates to:
  /// **'Download a range'**
  String get download_range;

  /// No description provided for @range_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get range_start;

  /// No description provided for @range_end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get range_end;

  /// No description provided for @download_range_hint.
  ///
  /// In en, this message translates to:
  /// **'Chapters between the two numbers are downloaded, in reading order.'**
  String get download_range_hint;

  /// No description provided for @invalid_range.
  ///
  /// In en, this message translates to:
  /// **'Invalid range'**
  String get invalid_range;

  /// No description provided for @no_comments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get no_comments;

  /// No description provided for @plugins_ffmpeg_ready.
  ///
  /// In en, this message translates to:
  /// **'Verified binary available for HLS files.'**
  String get plugins_ffmpeg_ready;

  /// No description provided for @plugins_ffmpeg_optional.
  ///
  /// In en, this message translates to:
  /// **'Optional: direct concatenation is used automatically.'**
  String get plugins_ffmpeg_optional;

  /// No description provided for @browse_global_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search extensions…'**
  String get browse_global_search_hint;

  /// No description provided for @browse_intelligent_search.
  ///
  /// In en, this message translates to:
  /// **'Intelligent search'**
  String get browse_intelligent_search;

  /// No description provided for @browse_intelligent_search_tooltip.
  ///
  /// In en, this message translates to:
  /// **'What is intelligent search?'**
  String get browse_intelligent_search_tooltip;

  /// No description provided for @browse_intelligent_search_help.
  ///
  /// In en, this message translates to:
  /// **'An extension has its own search: when it does not have the exact title, it often returns near results that are not relevant.\n\nIntelligent search keeps what the extension found, but only shows the results whose name really matches your search. The algorithm is tolerant: “Narufo” finds “Naruto”, and searching by another title works too (for example “Attack on Titan” for “Shingeki no Kyojin”).'**
  String get browse_intelligent_search_help;

  /// No description provided for @browse_pinned_sources.
  ///
  /// In en, this message translates to:
  /// **'Pinned sources'**
  String get browse_pinned_sources;

  /// No description provided for @browse_clear_filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get browse_clear_filters;

  /// No description provided for @browse_filters.
  ///
  /// In en, this message translates to:
  /// **'FILTERS'**
  String get browse_filters;

  /// No description provided for @browse_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get browse_clear;

  /// No description provided for @browse_content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get browse_content;

  /// No description provided for @browse_all_content.
  ///
  /// In en, this message translates to:
  /// **'All content'**
  String get browse_all_content;

  /// No description provided for @browse_sfw_only.
  ///
  /// In en, this message translates to:
  /// **'SFW only'**
  String get browse_sfw_only;

  /// No description provided for @browse_nsfw_only.
  ///
  /// In en, this message translates to:
  /// **'NSFW only'**
  String get browse_nsfw_only;

  /// No description provided for @browse_source_type.
  ///
  /// In en, this message translates to:
  /// **'Source type'**
  String get browse_source_type;

  /// No description provided for @browse_no_source_found.
  ///
  /// In en, this message translates to:
  /// **'No source found'**
  String get browse_no_source_found;

  /// No description provided for @browse_no_source_matches_filters.
  ///
  /// In en, this message translates to:
  /// **'No source matches\nthe active filters'**
  String get browse_no_source_matches_filters;

  /// No description provided for @browse_try_another_term.
  ///
  /// In en, this message translates to:
  /// **'Try another search term'**
  String get browse_try_another_term;

  /// No description provided for @browse_reset_filters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get browse_reset_filters;

  /// No description provided for @browse_retry_intelligently.
  ///
  /// In en, this message translates to:
  /// **'Retry intelligently'**
  String get browse_retry_intelligently;

  /// No description provided for @browse_got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get browse_got_it;

  /// No description provided for @browse_understood.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get browse_understood;

  /// No description provided for @browse_download_what.
  ///
  /// In en, this message translates to:
  /// **'What to download?'**
  String get browse_download_what;

  /// No description provided for @browse_download_options.
  ///
  /// In en, this message translates to:
  /// **'Download options'**
  String get browse_download_options;

  /// No description provided for @browse_download_prompt_search.
  ///
  /// In en, this message translates to:
  /// **'Run a search to see the titles you can download.'**
  String get browse_download_prompt_search;

  /// No description provided for @browse_from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get browse_from;

  /// No description provided for @browse_to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get browse_to;

  /// No description provided for @browse_wifi_only.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get browse_wifi_only;

  /// No description provided for @browse_cbz_archive.
  ///
  /// In en, this message translates to:
  /// **'CBZ archive'**
  String get browse_cbz_archive;

  /// No description provided for @browse_cbz_archive_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Package each chapter in a .cbz'**
  String get browse_cbz_archive_subtitle;

  /// No description provided for @browse_connections_count.
  ///
  /// In en, this message translates to:
  /// **'{count} connection(s)'**
  String browse_connections_count(Object count);

  /// No description provided for @browse_download_queued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} chapter queued for download} other{{count} chapters queued for download}}'**
  String browse_download_queued(num count);

  /// No description provided for @browse_download_failed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String browse_download_failed(Object error);

  /// No description provided for @browse_chapter_label.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get browse_chapter_label;

  /// No description provided for @browse_download_no_link.
  ///
  /// In en, this message translates to:
  /// **'This entry has no usable link.'**
  String get browse_download_no_link;

  /// No description provided for @browse_download_no_chapters.
  ///
  /// In en, this message translates to:
  /// **'No chapter available for this title.'**
  String get browse_download_no_chapters;

  /// No description provided for @browse_download_no_valid_chapter.
  ///
  /// In en, this message translates to:
  /// **'No valid chapter to download.'**
  String get browse_download_no_valid_chapter;

  /// No description provided for @browse_section_new.
  ///
  /// In en, this message translates to:
  /// **'New section'**
  String get browse_section_new;

  /// No description provided for @browse_section_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename section'**
  String get browse_section_rename;

  /// No description provided for @browse_section_rename_short.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get browse_section_rename_short;

  /// No description provided for @browse_section_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String browse_section_delete_title(Object name);

  /// No description provided for @browse_section_delete_body.
  ///
  /// In en, this message translates to:
  /// **'The section is deleted. The extensions stay installed.'**
  String get browse_section_delete_body;

  /// No description provided for @browse_section_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get browse_section_name_hint;

  /// No description provided for @browse_section_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No section'**
  String get browse_section_empty_title;

  /// No description provided for @browse_section_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Create a section (e.g. “Hentai”) then add the extensions you want to group in it.'**
  String get browse_section_empty_body;

  /// No description provided for @browse_section_extension_count.
  ///
  /// In en, this message translates to:
  /// **'{count} extension(s)'**
  String browse_section_extension_count(Object count);

  /// No description provided for @browse_section_add_extensions.
  ///
  /// In en, this message translates to:
  /// **'Add extensions'**
  String get browse_section_add_extensions;

  /// No description provided for @browse_section_detail_empty.
  ///
  /// In en, this message translates to:
  /// **'This section is empty. Add extensions to find them here.'**
  String get browse_section_detail_empty;

  /// No description provided for @browse_section_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Section extensions'**
  String get browse_section_picker_title;

  /// No description provided for @browse_section_no_extensions.
  ///
  /// In en, this message translates to:
  /// **'No extension installed for this type.'**
  String get browse_section_no_extensions;

  /// No description provided for @browse_section_add_to.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}” to a section'**
  String browse_section_add_to(Object name);

  /// No description provided for @browse_section_create_first.
  ///
  /// In en, this message translates to:
  /// **'First create a section from the ⋮ menu of the Explorer.'**
  String get browse_section_create_first;

  /// No description provided for @browse_section_default_name.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get browse_section_default_name;

  /// No description provided for @browse_validate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get browse_validate;

  /// No description provided for @browse_remove_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get browse_remove_tooltip;

  /// No description provided for @browse_section_options.
  ///
  /// In en, this message translates to:
  /// **'Section options'**
  String get browse_section_options;

  /// No description provided for @browse_section_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable section'**
  String get browse_section_enable;

  /// No description provided for @browse_section_disable.
  ///
  /// In en, this message translates to:
  /// **'Disable section'**
  String get browse_section_disable;

  /// No description provided for @browse_section_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin section'**
  String get browse_section_pin;

  /// No description provided for @browse_section_unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin section'**
  String get browse_section_unpin;

  /// No description provided for @browse_load_extensions_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load extensions'**
  String get browse_load_extensions_failed;

  /// No description provided for @browse_check_connection.
  ///
  /// In en, this message translates to:
  /// **'Retry after checking your connection.'**
  String get browse_check_connection;

  /// No description provided for @browse_install_from_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Install an extension from the Marketplace'**
  String get browse_install_from_marketplace;

  /// No description provided for @browse_go_to_market.
  ///
  /// In en, this message translates to:
  /// **'Go to Marketplace'**
  String get browse_go_to_market;

  /// No description provided for @browse_no_matching_extension.
  ///
  /// In en, this message translates to:
  /// **'No extension matches the search or the filters.'**
  String get browse_no_matching_extension;

  /// No description provided for @browse_scanning_extensions.
  ///
  /// In en, this message translates to:
  /// **'Scanning extensions…'**
  String get browse_scanning_extensions;

  /// No description provided for @browse_extension_settings.
  ///
  /// In en, this message translates to:
  /// **'Extension settings'**
  String get browse_extension_settings;

  /// No description provided for @browse_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get browse_pin;

  /// No description provided for @browse_unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get browse_unpin;

  /// No description provided for @browse_filter_installed.
  ///
  /// In en, this message translates to:
  /// **'Installed extensions'**
  String get browse_filter_installed;

  /// No description provided for @browse_filter_active_only.
  ///
  /// In en, this message translates to:
  /// **'Active sources only'**
  String get browse_filter_active_only;

  /// No description provided for @browse_filter_content_nsfw.
  ///
  /// In en, this message translates to:
  /// **'Content and NSFW'**
  String get browse_filter_content_nsfw;

  /// No description provided for @browse_filter_all_languages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get browse_filter_all_languages;

  /// No description provided for @browse_filter_language_prefix.
  ///
  /// In en, this message translates to:
  /// **'Language: {code}'**
  String browse_filter_language_prefix(Object code);

  /// No description provided for @browse_filter_tags.
  ///
  /// In en, this message translates to:
  /// **'Extension tags'**
  String get browse_filter_tags;

  /// No description provided for @browse_filter_tags_count.
  ///
  /// In en, this message translates to:
  /// **'{count} tag(s) selected'**
  String browse_filter_tags_count(Object count);

  /// No description provided for @browse_filter_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get browse_filter_done;

  /// No description provided for @browse_filter_clear_search.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get browse_filter_clear_search;

  /// No description provided for @browse_filter_search_installed.
  ///
  /// In en, this message translates to:
  /// **'Search an installed extension'**
  String get browse_filter_search_installed;

  /// No description provided for @browse_tag_cloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get browse_tag_cloudflare;

  /// No description provided for @browse_tag_account.
  ///
  /// In en, this message translates to:
  /// **'Account required'**
  String get browse_tag_account;

  /// No description provided for @browse_tag_drm.
  ///
  /// In en, this message translates to:
  /// **'DRM'**
  String get browse_tag_drm;

  /// No description provided for @browse_tag_aggregator.
  ///
  /// In en, this message translates to:
  /// **'Aggregator'**
  String get browse_tag_aggregator;

  /// No description provided for @browse_tag_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get browse_tag_comments;

  /// No description provided for @browse_tag_torrent.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get browse_tag_torrent;

  /// No description provided for @browse_tag_update.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get browse_tag_update;

  /// No description provided for @browse_tag_javascript.
  ///
  /// In en, this message translates to:
  /// **'JavaScript'**
  String get browse_tag_javascript;

  /// No description provided for @browse_tag_dart.
  ///
  /// In en, this message translates to:
  /// **'Dart'**
  String get browse_tag_dart;

  /// No description provided for @browse_url_copied.
  ///
  /// In en, this message translates to:
  /// **'URL copied!'**
  String get browse_url_copied;

  /// No description provided for @browse_launch_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String browse_launch_failed(Object url);

  /// No description provided for @browse_no_local_layout.
  ///
  /// In en, this message translates to:
  /// **'No local layout available for this extension.'**
  String get browse_no_local_layout;

  /// No description provided for @browse_layout_root_object.
  ///
  /// In en, this message translates to:
  /// **'The layout root must be an object.'**
  String get browse_layout_root_object;

  /// No description provided for @browse_save_card_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the search card.'**
  String get browse_save_card_failed;

  /// No description provided for @browse_search_card_saved.
  ///
  /// In en, this message translates to:
  /// **'Search card saved.'**
  String get browse_search_card_saved;

  /// No description provided for @browse_search_layout_invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid search layout: {error}'**
  String browse_search_layout_invalid(Object error);

  /// No description provided for @browse_invalid_site_url.
  ///
  /// In en, this message translates to:
  /// **'Invalid site URL.'**
  String get browse_invalid_site_url;

  /// No description provided for @browse_login_open_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the login page.'**
  String get browse_login_open_failed;

  /// No description provided for @browse_session_cleared.
  ///
  /// In en, this message translates to:
  /// **'Session cleared for this extension.'**
  String get browse_session_cleared;

  /// No description provided for @browse_session_clear_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear this extension’s session.'**
  String get browse_session_clear_failed;

  /// No description provided for @browse_session_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking connection…'**
  String get browse_session_checking;

  /// No description provided for @browse_session_logging_in.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get browse_session_logging_in;

  /// No description provided for @browse_session_logging_out.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get browse_session_logging_out;

  /// No description provided for @browse_session_saved.
  ///
  /// In en, this message translates to:
  /// **'Site session saved'**
  String get browse_session_saved;

  /// No description provided for @browse_session_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected: {identity}'**
  String browse_session_connected(Object identity);

  /// No description provided for @browse_session_not_connected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get browse_session_not_connected;

  /// No description provided for @browse_session_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Connection status unavailable'**
  String get browse_session_unavailable;

  /// No description provided for @browse_check_connection_short.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get browse_check_connection_short;

  /// No description provided for @browse_account_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected account'**
  String get browse_account_connected;

  /// No description provided for @browse_account_fallback.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get browse_account_fallback;

  /// No description provided for @browse_no_favorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite available.'**
  String get browse_no_favorites;

  /// No description provided for @browse_untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get browse_untitled;

  /// No description provided for @browse_more_favorites.
  ///
  /// In en, this message translates to:
  /// **'+{count} more favorites'**
  String browse_more_favorites(Object count);

  /// No description provided for @browse_expires_on.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String browse_expires_on(Object date);

  /// No description provided for @browse_details_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Details unavailable'**
  String get browse_details_unavailable;

  /// No description provided for @browse_premium_status.
  ///
  /// In en, this message translates to:
  /// **'Premium status'**
  String get browse_premium_status;

  /// No description provided for @browse_status_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get browse_status_unavailable;

  /// No description provided for @browse_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get browse_status_active;

  /// No description provided for @browse_status_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get browse_status_inactive;

  /// No description provided for @browse_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get browse_favorites;

  /// No description provided for @browse_edit_base_url.
  ///
  /// In en, this message translates to:
  /// **'Edit base URL'**
  String get browse_edit_base_url;

  /// No description provided for @browse_base_url.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get browse_base_url;

  /// No description provided for @browse_base_url_updated.
  ///
  /// In en, this message translates to:
  /// **'URL updated!'**
  String get browse_base_url_updated;

  /// No description provided for @browse_base_url_undefined.
  ///
  /// In en, this message translates to:
  /// **'Base URL not set.'**
  String get browse_base_url_undefined;

  /// No description provided for @browse_import_cookies.
  ///
  /// In en, this message translates to:
  /// **'Import cookies'**
  String get browse_import_cookies;

  /// No description provided for @browse_cookies_format.
  ///
  /// In en, this message translates to:
  /// **'Paste cookies as: key=value; key2=value2'**
  String get browse_cookies_format;

  /// No description provided for @browse_cookies_hint.
  ///
  /// In en, this message translates to:
  /// **'session=abc123; token=xyz789'**
  String get browse_cookies_hint;

  /// No description provided for @browse_cookies_imported.
  ///
  /// In en, this message translates to:
  /// **'Cookies imported!'**
  String get browse_cookies_imported;

  /// No description provided for @browse_cookies_import_failed.
  ///
  /// In en, this message translates to:
  /// **'Error importing cookies.'**
  String get browse_cookies_import_failed;

  /// No description provided for @browse_cookies_none_available.
  ///
  /// In en, this message translates to:
  /// **'No cookie available for this extension.'**
  String get browse_cookies_none_available;

  /// No description provided for @browse_cookies_copied.
  ///
  /// In en, this message translates to:
  /// **'Cookies copied!'**
  String get browse_cookies_copied;

  /// No description provided for @browse_cookies_none_stored.
  ///
  /// In en, this message translates to:
  /// **'No stored cookie for this extension.'**
  String get browse_cookies_none_stored;

  /// No description provided for @browse_export_cookies.
  ///
  /// In en, this message translates to:
  /// **'Export cookies'**
  String get browse_export_cookies;

  /// No description provided for @browse_stored_cookies.
  ///
  /// In en, this message translates to:
  /// **'Stored cookies'**
  String get browse_stored_cookies;

  /// No description provided for @browse_user_agent.
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get browse_user_agent;

  /// No description provided for @browse_user_agent_help.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default User-Agent.'**
  String get browse_user_agent_help;

  /// No description provided for @browse_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get browse_reset;

  /// No description provided for @browse_user_agent_reset.
  ///
  /// In en, this message translates to:
  /// **'User-Agent reset.'**
  String get browse_user_agent_reset;

  /// No description provided for @browse_user_agent_updated.
  ///
  /// In en, this message translates to:
  /// **'User-Agent updated!'**
  String get browse_user_agent_updated;

  /// No description provided for @browse_clear_data_title.
  ///
  /// In en, this message translates to:
  /// **'Clear data?'**
  String get browse_clear_data_title;

  /// No description provided for @browse_clear_data_body.
  ///
  /// In en, this message translates to:
  /// **'This will delete all preferences, cookies and data associated with this extension.'**
  String get browse_clear_data_body;

  /// No description provided for @browse_clear_data_confirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get browse_clear_data_confirm;

  /// No description provided for @browse_data_cleared.
  ///
  /// In en, this message translates to:
  /// **'Data cleared!'**
  String get browse_data_cleared;

  /// No description provided for @browse_clear_cache_title.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get browse_clear_cache_title;

  /// No description provided for @browse_clear_cache_body.
  ///
  /// In en, this message translates to:
  /// **'This reloads the extension preferences from the local database and tries to invalidate this source’s HTTP cache. Cookies are not affected.'**
  String get browse_clear_cache_body;

  /// No description provided for @browse_cache_emptied.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get browse_cache_emptied;

  /// No description provided for @browse_prefs_reloaded.
  ///
  /// In en, this message translates to:
  /// **'Preferences reloaded. Reopen the source to refresh the cache.'**
  String get browse_prefs_reloaded;

  /// No description provided for @browse_http_headers.
  ///
  /// In en, this message translates to:
  /// **'HTTP headers'**
  String get browse_http_headers;

  /// No description provided for @browse_no_headers.
  ///
  /// In en, this message translates to:
  /// **'No header defined.'**
  String get browse_no_headers;

  /// No description provided for @browse_headers_copied.
  ///
  /// In en, this message translates to:
  /// **'Headers copied!'**
  String get browse_headers_copied;

  /// No description provided for @browse_extension_missing.
  ///
  /// In en, this message translates to:
  /// **'This extension no longer exists in local storage.'**
  String get browse_extension_missing;

  /// No description provided for @browse_extension_uninstalled.
  ///
  /// In en, this message translates to:
  /// **'Extension uninstalled.'**
  String get browse_extension_uninstalled;

  /// No description provided for @browse_uninstall_failed.
  ///
  /// In en, this message translates to:
  /// **'Error while uninstalling: {error}'**
  String browse_uninstall_failed(Object error);

  /// No description provided for @browse_uninstall_extension.
  ///
  /// In en, this message translates to:
  /// **'Uninstall extension'**
  String get browse_uninstall_extension;

  /// No description provided for @browse_cookies_deleted.
  ///
  /// In en, this message translates to:
  /// **'Cookies deleted!'**
  String get browse_cookies_deleted;

  /// No description provided for @browse_import_cookie.
  ///
  /// In en, this message translates to:
  /// **'Import cookie'**
  String get browse_import_cookie;

  /// No description provided for @browse_view_cookies.
  ///
  /// In en, this message translates to:
  /// **'View cookies'**
  String get browse_view_cookies;

  /// No description provided for @browse_clear_cookies.
  ///
  /// In en, this message translates to:
  /// **'Clear cookies'**
  String get browse_clear_cookies;

  /// No description provided for @browse_clear_cache_short.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get browse_clear_cache_short;

  /// No description provided for @browse_clear_data_short.
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get browse_clear_data_short;

  /// No description provided for @browse_edit_url.
  ///
  /// In en, this message translates to:
  /// **'Edit URL'**
  String get browse_edit_url;

  /// No description provided for @browse_view_headers.
  ///
  /// In en, this message translates to:
  /// **'View headers'**
  String get browse_view_headers;

  /// No description provided for @browse_edit_user_agent.
  ///
  /// In en, this message translates to:
  /// **'Edit User-Agent'**
  String get browse_edit_user_agent;

  /// No description provided for @browse_obsolete.
  ///
  /// In en, this message translates to:
  /// **'Outdated'**
  String get browse_obsolete;

  /// No description provided for @browse_not_installed.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get browse_not_installed;

  /// No description provided for @browse_account_required.
  ///
  /// In en, this message translates to:
  /// **'Account required'**
  String get browse_account_required;

  /// No description provided for @browse_repository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get browse_repository;

  /// No description provided for @browse_available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get browse_available;

  /// No description provided for @browse_account_and_features.
  ///
  /// In en, this message translates to:
  /// **'Account and features'**
  String get browse_account_and_features;

  /// No description provided for @browse_account_desc.
  ///
  /// In en, this message translates to:
  /// **'The connection and displayed information are specific to this extension. The session data used by its requests stays separate.'**
  String get browse_account_desc;

  /// No description provided for @browse_account_desc_generic.
  ///
  /// In en, this message translates to:
  /// **'The displayed information is provided by the methods declared by this extension.'**
  String get browse_account_desc_generic;

  /// No description provided for @browse_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get browse_sign_in;

  /// No description provided for @browse_clear_session.
  ///
  /// In en, this message translates to:
  /// **'Clear session'**
  String get browse_clear_session;

  /// No description provided for @browse_home_layout.
  ///
  /// In en, this message translates to:
  /// **'Home layout'**
  String get browse_home_layout;

  /// No description provided for @browse_edit_visually.
  ///
  /// In en, this message translates to:
  /// **'Edit visually'**
  String get browse_edit_visually;

  /// No description provided for @browse_search_results.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get browse_search_results;

  /// No description provided for @browse_choose_result_card.
  ///
  /// In en, this message translates to:
  /// **'Choose a result card'**
  String get browse_choose_result_card;

  /// No description provided for @browse_extension_word.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get browse_extension_word;

  /// No description provided for @browse_open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get browse_open_settings;

  /// No description provided for @browse_diag_export_report.
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get browse_diag_export_report;

  /// No description provided for @browse_diag_files_count.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String browse_diag_files_count(Object count);

  /// No description provided for @browse_diag_summary_view.
  ///
  /// In en, this message translates to:
  /// **'Summary view'**
  String get browse_diag_summary_view;

  /// No description provided for @browse_diag_view_raw.
  ///
  /// In en, this message translates to:
  /// **'View raw report'**
  String get browse_diag_view_raw;

  /// No description provided for @browse_diag_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get browse_diag_copy;

  /// No description provided for @browse_diag_raw_report.
  ///
  /// In en, this message translates to:
  /// **'Raw report — {format}'**
  String browse_diag_raw_report(Object format);

  /// No description provided for @browse_diag_chars_count.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String browse_diag_chars_count(Object count);

  /// No description provided for @browse_diag_tab_extension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get browse_diag_tab_extension;

  /// No description provided for @browse_diag_tab_detail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get browse_diag_tab_detail;

  /// No description provided for @browse_diag_in_progress.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic in progress…'**
  String get browse_diag_in_progress;

  /// No description provided for @browse_diag_waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for diagnostic'**
  String get browse_diag_waiting;

  /// No description provided for @browse_diag_test_extension.
  ///
  /// In en, this message translates to:
  /// **'Test this extension'**
  String get browse_diag_test_extension;

  /// No description provided for @browse_diag_interrupted.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic interrupted — some steps could not run.'**
  String get browse_diag_interrupted;

  /// No description provided for @browse_diag_retest.
  ///
  /// In en, this message translates to:
  /// **'Retest this extension'**
  String get browse_diag_retest;

  /// No description provided for @browse_diag_results_count.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String browse_diag_results_count(Object count);

  /// No description provided for @browse_diag_logs.
  ///
  /// In en, this message translates to:
  /// **'LOGS — {label}'**
  String browse_diag_logs(Object label);

  /// No description provided for @browse_diag_no_trace.
  ///
  /// In en, this message translates to:
  /// **'No trace for this step.'**
  String get browse_diag_no_trace;

  /// No description provided for @browse_diag_sources_count.
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String browse_diag_sources_count(Object count);

  /// No description provided for @browse_diag_page_of.
  ///
  /// In en, this message translates to:
  /// **'Page {page} / {total}'**
  String browse_diag_page_of(Object page, Object total);

  /// No description provided for @browse_diag_image_unreachable.
  ///
  /// In en, this message translates to:
  /// **'Image unreachable'**
  String get browse_diag_image_unreachable;

  /// No description provided for @browse_diag_open_detail.
  ///
  /// In en, this message translates to:
  /// **'Open detail'**
  String get browse_diag_open_detail;

  /// No description provided for @browse_diag_no_errors.
  ///
  /// In en, this message translates to:
  /// **'No error detected on the steps.'**
  String get browse_diag_no_errors;

  /// No description provided for @browse_diag_running.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic {label} in progress…'**
  String browse_diag_running(Object label);

  /// No description provided for @browse_diag_title.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic {label}'**
  String browse_diag_title(Object label);

  /// No description provided for @browse_diag_no_extension_installed.
  ///
  /// In en, this message translates to:
  /// **'No extension installed'**
  String get browse_diag_no_extension_installed;

  /// No description provided for @browse_diag_change_filters.
  ///
  /// In en, this message translates to:
  /// **'Change the search or the filters from the Panel.'**
  String get browse_diag_change_filters;

  /// No description provided for @browse_diag_no_extension_selected.
  ///
  /// In en, this message translates to:
  /// **'No extension selected'**
  String get browse_diag_no_extension_selected;

  /// No description provided for @browse_diag_no_results_yet.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get browse_diag_no_results_yet;

  /// No description provided for @browse_diag_no_report.
  ///
  /// In en, this message translates to:
  /// **'No report'**
  String get browse_diag_no_report;

  /// No description provided for @browse_diag_control_panel.
  ///
  /// In en, this message translates to:
  /// **'Control panel'**
  String get browse_diag_control_panel;

  /// No description provided for @browse_diag_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get browse_diag_all;

  /// No description provided for @browse_diag_everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get browse_diag_everything;

  /// No description provided for @browse_diag_sfw.
  ///
  /// In en, this message translates to:
  /// **'SFW'**
  String get browse_diag_sfw;

  /// No description provided for @browse_diag_only_errors.
  ///
  /// In en, this message translates to:
  /// **'Show only errors'**
  String get browse_diag_only_errors;

  /// No description provided for @browse_diag_only_tested.
  ///
  /// In en, this message translates to:
  /// **'Show only tested extensions'**
  String get browse_diag_only_tested;

  /// No description provided for @browse_diag_canceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling…'**
  String get browse_diag_canceling;

  /// No description provided for @browse_diag_panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get browse_diag_panel;

  /// No description provided for @browse_diag_results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get browse_diag_results;

  /// No description provided for @browse_diag_all_respond.
  ///
  /// In en, this message translates to:
  /// **'All sources respond ✓'**
  String get browse_diag_all_respond;

  /// No description provided for @browse_diag_unanalyzed.
  ///
  /// In en, this message translates to:
  /// **'{count} not analyzed'**
  String browse_diag_unanalyzed(Object count);

  /// No description provided for @browse_diag_remaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String browse_diag_remaining(Object count);

  /// No description provided for @browse_diag_restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get browse_diag_restart;

  /// No description provided for @browse_diag_err_short.
  ///
  /// In en, this message translates to:
  /// **'Err.'**
  String get browse_diag_err_short;

  /// No description provided for @browse_diag_tested.
  ///
  /// In en, this message translates to:
  /// **'Tested'**
  String get browse_diag_tested;

  /// No description provided for @browse_create_title.
  ///
  /// In en, this message translates to:
  /// **'Create an extension'**
  String get browse_create_title;

  /// No description provided for @browse_create_language.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get browse_create_language;

  /// No description provided for @browse_create_information.
  ///
  /// In en, this message translates to:
  /// **'INFORMATION'**
  String get browse_create_information;

  /// No description provided for @browse_create_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get browse_create_name;

  /// No description provided for @browse_create_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. myAnime'**
  String get browse_create_name_hint;

  /// No description provided for @browse_create_api_url.
  ///
  /// In en, this message translates to:
  /// **'API URL (optional)'**
  String get browse_create_api_url;

  /// No description provided for @browse_create_icon_url.
  ///
  /// In en, this message translates to:
  /// **'Icon URL'**
  String get browse_create_icon_url;

  /// No description provided for @browse_create_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get browse_create_notes;

  /// No description provided for @browse_create_notes_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. requires a connection'**
  String get browse_create_notes_hint;

  /// No description provided for @browse_create_type.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get browse_create_type;

  /// No description provided for @browse_create_source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get browse_create_source;

  /// No description provided for @browse_create_lang_iso.
  ///
  /// In en, this message translates to:
  /// **'Language (ISO code)'**
  String get browse_create_lang_iso;

  /// No description provided for @browse_create_lang_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. fr, en, ja'**
  String get browse_create_lang_hint;

  /// No description provided for @browse_create_exists.
  ///
  /// In en, this message translates to:
  /// **'This extension name already exists.'**
  String get browse_create_exists;

  /// No description provided for @browse_create_native_recommended.
  ///
  /// In en, this message translates to:
  /// **'Native · Recommended'**
  String get browse_create_native_recommended;

  /// No description provided for @browse_create_js_universal.
  ///
  /// In en, this message translates to:
  /// **'Universal JS'**
  String get browse_create_js_universal;

  /// No description provided for @browse_layout_format.
  ///
  /// In en, this message translates to:
  /// **'Format (indented)'**
  String get browse_layout_format;

  /// No description provided for @browse_layout_minify.
  ///
  /// In en, this message translates to:
  /// **'Minify'**
  String get browse_layout_minify;

  /// No description provided for @browse_layout_save.
  ///
  /// In en, this message translates to:
  /// **'Save layout'**
  String get browse_layout_save;

  /// No description provided for @browse_layout_placeholder.
  ///
  /// In en, this message translates to:
  /// **'The layout JSON will appear here'**
  String get browse_layout_placeholder;

  /// No description provided for @browse_layout_saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get browse_layout_saving;

  /// No description provided for @browse_layout_wrap.
  ///
  /// In en, this message translates to:
  /// **'Word wrap'**
  String get browse_layout_wrap;

  /// No description provided for @browse_layout_numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get browse_layout_numbers;

  /// No description provided for @browse_layout_left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get browse_layout_left;

  /// No description provided for @browse_layout_center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get browse_layout_center;

  /// No description provided for @browse_code_import_file.
  ///
  /// In en, this message translates to:
  /// **'Import a file'**
  String get browse_code_import_file;

  /// No description provided for @browse_code_file_imported.
  ///
  /// In en, this message translates to:
  /// **'File imported: {name}'**
  String browse_code_file_imported(Object name);

  /// No description provided for @browse_code_import_error.
  ///
  /// In en, this message translates to:
  /// **'Import error: {error}'**
  String browse_code_import_error(Object error);

  /// No description provided for @browse_code_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get browse_code_save;

  /// No description provided for @browse_code_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get browse_code_saved;

  /// No description provided for @browse_code_clear_logs.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get browse_code_clear_logs;

  /// No description provided for @browse_pref_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get browse_pref_setting;

  /// No description provided for @browse_pref_choice.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get browse_pref_choice;

  /// No description provided for @browse_pref_multi_choice.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get browse_pref_multi_choice;

  /// No description provided for @browse_anime_episode.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String browse_anime_episode(Object number);

  /// No description provided for @browse_anime_play_failed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String browse_anime_play_failed(Object error);

  /// No description provided for @browse_anime_episode_sources.
  ///
  /// In en, this message translates to:
  /// **'Episode sources'**
  String get browse_anime_episode_sources;

  /// No description provided for @browse_anime_play_episode.
  ///
  /// In en, this message translates to:
  /// **'Play this episode'**
  String get browse_anime_play_episode;

  /// No description provided for @browse_local_how_to_title.
  ///
  /// In en, this message translates to:
  /// **'Local {type} — How to use'**
  String browse_local_how_to_title(Object type);

  /// No description provided for @browse_alternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get browse_alternative;

  /// No description provided for @browse_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get browse_close;

  /// No description provided for @browse_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get browse_copy;

  /// No description provided for @browse_diag_steps_header.
  ///
  /// In en, this message translates to:
  /// **'Steps — Popular · Latest · Detail · {media}'**
  String browse_diag_steps_header(Object media);

  /// No description provided for @browse_diag_videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get browse_diag_videos;

  /// No description provided for @browse_diag_pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get browse_diag_pages;

  /// No description provided for @browse_diag_not_tested.
  ///
  /// In en, this message translates to:
  /// **'not tested'**
  String get browse_diag_not_tested;

  /// No description provided for @browse_diag_lang_filter.
  ///
  /// In en, this message translates to:
  /// **'Language: {name}'**
  String browse_diag_lang_filter(Object name);

  /// No description provided for @browse_diag_type_filter.
  ///
  /// In en, this message translates to:
  /// **'Type: {name}'**
  String browse_diag_type_filter(Object name);

  /// No description provided for @browse_diag_nsfw_only.
  ///
  /// In en, this message translates to:
  /// **'NSFW only'**
  String get browse_diag_nsfw_only;

  /// No description provided for @browse_diag_sfw_only.
  ///
  /// In en, this message translates to:
  /// **'SFW only'**
  String get browse_diag_sfw_only;

  /// No description provided for @browse_diag_all_extensions.
  ///
  /// In en, this message translates to:
  /// **'All extensions'**
  String get browse_diag_all_extensions;

  /// No description provided for @browse_diag_notify_running.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic {label} in progress…'**
  String browse_diag_notify_running(Object label);

  /// No description provided for @browse_diag_notify_title.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic {label}'**
  String browse_diag_notify_title(Object label);

  /// No description provided for @browse_diag_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic cancelled — {done} / {total} analyzed.'**
  String browse_diag_cancelled(Object done, Object total);

  /// No description provided for @browse_diag_finished.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic finished — {ok} OK · {failed} failed.'**
  String browse_diag_finished(Object failed, Object ok);

  /// No description provided for @browse_diag_cancelling_snack.
  ///
  /// In en, this message translates to:
  /// **'Canceling the diagnostic…'**
  String get browse_diag_cancelling_snack;

  /// No description provided for @browse_diag_retest_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Retest cancelled for {name}.'**
  String browse_diag_retest_cancelled(Object name);

  /// No description provided for @browse_diag_retest_ok.
  ///
  /// In en, this message translates to:
  /// **'✅ {name} now responds correctly.'**
  String browse_diag_retest_ok(Object name);

  /// No description provided for @browse_diag_retest_fail.
  ///
  /// In en, this message translates to:
  /// **'❌ {name} still fails — see the step logs.'**
  String browse_diag_retest_fail(Object name);

  /// No description provided for @browse_diag_no_report_available.
  ///
  /// In en, this message translates to:
  /// **'No report available — run a diagnostic.'**
  String get browse_diag_no_report_available;

  /// No description provided for @browse_diag_report_copied.
  ///
  /// In en, this message translates to:
  /// **'{format} report copied ✓'**
  String browse_diag_report_copied(Object format);

  /// No description provided for @browse_diag_no_extension_selected_snack.
  ///
  /// In en, this message translates to:
  /// **'No extension selected — enable at least one.'**
  String get browse_diag_no_extension_selected_snack;

  /// No description provided for @browse_diag_no_extension_filter.
  ///
  /// In en, this message translates to:
  /// **'No extension for this filter.'**
  String get browse_diag_no_extension_filter;

  /// No description provided for @browse_diag_ready.
  ///
  /// In en, this message translates to:
  /// **'Ready to diagnose'**
  String get browse_diag_ready;

  /// No description provided for @browse_diag_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get browse_diag_paused;

  /// No description provided for @browse_diag_running_state.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic in progress'**
  String get browse_diag_running_state;

  /// No description provided for @browse_diag_interrupted_state.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get browse_diag_interrupted_state;

  /// No description provided for @browse_diag_complete.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic finished'**
  String get browse_diag_complete;

  /// No description provided for @browse_diag_complete_errors.
  ///
  /// In en, this message translates to:
  /// **'Finished with errors'**
  String get browse_diag_complete_errors;

  /// No description provided for @browse_diag_ready_short.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get browse_diag_ready_short;

  /// No description provided for @browse_diag_extensions_analyzed.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} extensions analyzed · {elapsed}'**
  String browse_diag_extensions_analyzed(
    Object done,
    Object elapsed,
    Object total,
  );

  /// No description provided for @browse_diag_select_hint.
  ///
  /// In en, this message translates to:
  /// **'Check the extensions to test · {count} selected'**
  String browse_diag_select_hint(Object count);

  /// No description provided for @browse_diag_panel_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get browse_diag_panel_type;

  /// No description provided for @browse_diag_panel_content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get browse_diag_panel_content;

  /// No description provided for @browse_diag_panel_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get browse_diag_panel_options;

  /// No description provided for @browse_diag_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get browse_diag_resume;

  /// No description provided for @browse_diag_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get browse_diag_pause;

  /// No description provided for @browse_diag_start.
  ///
  /// In en, this message translates to:
  /// **'Start the diagnostic'**
  String get browse_diag_start;

  /// No description provided for @browse_diag_view_extensions.
  ///
  /// In en, this message translates to:
  /// **'View extensions'**
  String get browse_diag_view_extensions;

  /// No description provided for @browse_diag_open_panel.
  ///
  /// In en, this message translates to:
  /// **'Open the Panel'**
  String get browse_diag_open_panel;

  /// No description provided for @browse_diag_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get browse_diag_back;

  /// No description provided for @browse_diag_add_extensions.
  ///
  /// In en, this message translates to:
  /// **'Add extensions from the Marketplace before running a diagnostic.'**
  String get browse_diag_add_extensions;

  /// No description provided for @browse_diag_no_extension_filters.
  ///
  /// In en, this message translates to:
  /// **'No extension for these filters'**
  String get browse_diag_no_extension_filters;

  /// No description provided for @browse_diag_touch_extension.
  ///
  /// In en, this message translates to:
  /// **'Tap an extension in the list to show its steps, logs and detailed errors.'**
  String get browse_diag_touch_extension;

  /// No description provided for @browse_diag_results_appear.
  ///
  /// In en, this message translates to:
  /// **'Analyzed extensions will appear here with their steps and logs.'**
  String get browse_diag_results_appear;

  /// No description provided for @browse_diag_run_for_report.
  ///
  /// In en, this message translates to:
  /// **'Run a diagnostic to get a detailed, exportable report (Markdown, JSON, TXT, CSV).'**
  String get browse_diag_run_for_report;

  /// No description provided for @browse_diag_step_failed.
  ///
  /// In en, this message translates to:
  /// **'{count} step(s) failed — open each step for the logs.'**
  String browse_diag_step_failed(Object count);

  /// No description provided for @browse_diag_extension_word.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get browse_diag_extension_word;

  /// No description provided for @browse_diag_analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get browse_diag_analyzing;

  /// No description provided for @browse_diag_waiting_short.
  ///
  /// In en, this message translates to:
  /// **'Waiting…'**
  String get browse_diag_waiting_short;

  /// No description provided for @browse_local_folder.
  ///
  /// In en, this message translates to:
  /// **'📁 Local folder'**
  String get browse_local_folder;

  /// No description provided for @browse_local_formats.
  ///
  /// In en, this message translates to:
  /// **'🗂️ Supported formats'**
  String get browse_local_formats;

  /// No description provided for @browse_local_organization.
  ///
  /// In en, this message translates to:
  /// **'🗃️ Folder organization'**
  String get browse_local_organization;

  /// No description provided for @browse_local_recommended_structure.
  ///
  /// In en, this message translates to:
  /// **'Recommended structure:'**
  String get browse_local_recommended_structure;

  /// No description provided for @browse_local_tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get browse_local_tips;

  /// No description provided for @browse_local_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get browse_local_default;

  /// No description provided for @browse_local_alt.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get browse_local_alt;

  /// No description provided for @browse_local_default_path.
  ///
  /// In en, this message translates to:
  /// **'On my iPhone → Watchtower → Local/{type}'**
  String browse_local_default_path(Object type);

  /// No description provided for @browse_local_alt_path.
  ///
  /// In en, this message translates to:
  /// **'On my iPhone → Watchtower → {type}'**
  String browse_local_alt_path(Object type);

  /// No description provided for @browse_local_scan_note.
  ///
  /// In en, this message translates to:
  /// **'Watchtower will scan this folder automatically when the local source opens.'**
  String get browse_local_scan_note;

  /// No description provided for @browse_local_hero_title.
  ///
  /// In en, this message translates to:
  /// **'Local source {type}'**
  String browse_local_hero_title(Object type);

  /// No description provided for @browse_local_hero_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Read your local files directly from your device, without an internet connection.'**
  String get browse_local_hero_subtitle;

  /// No description provided for @browse_local_tip_source.
  ///
  /// In en, this message translates to:
  /// **'Open the \"{type} Local\" source in Browse → Sources to see your files.'**
  String browse_local_tip_source(Object type);

  /// No description provided for @browse_local_tip_subfolder.
  ///
  /// In en, this message translates to:
  /// **'Create a subfolder per title for better organization.'**
  String get browse_local_tip_subfolder;

  /// No description provided for @browse_local_tip_cover.
  ///
  /// In en, this message translates to:
  /// **'A cover.jpg file in the title folder will be used as the cover.'**
  String get browse_local_tip_cover;

  /// No description provided for @browse_local_tip_pull.
  ///
  /// In en, this message translates to:
  /// **'Pull down on the local library to rescan the files.'**
  String get browse_local_tip_pull;

  /// No description provided for @browse_local_type_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get browse_local_type_music;

  /// No description provided for @browse_local_type_game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get browse_local_type_game;

  /// No description provided for @browse_local_type_plugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get browse_local_type_plugin;

  /// No description provided for @browse_create_base_url.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get browse_create_base_url;

  /// No description provided for @browse_account_required_chip.
  ///
  /// In en, this message translates to:
  /// **'🔐 Account required'**
  String get browse_account_required_chip;

  /// No description provided for @browse_drm_chip.
  ///
  /// In en, this message translates to:
  /// **'🔒 DRM'**
  String get browse_drm_chip;

  /// No description provided for @browse_version_up.
  ///
  /// In en, this message translates to:
  /// **'↑ v{version}'**
  String browse_version_up(Object version);

  /// No description provided for @browse_version_short.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String browse_version_short(Object version);

  /// No description provided for @browse_cookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get browse_cookies;

  /// No description provided for @browse_user_agent_hint.
  ///
  /// In en, this message translates to:
  /// **'Mozilla/5.0 ...'**
  String get browse_user_agent_hint;

  /// No description provided for @browse_cloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get browse_cloudflare;

  /// No description provided for @settings_remote_bypass_title.
  ///
  /// In en, this message translates to:
  /// **'Remote bypass server'**
  String get settings_remote_bypass_title;

  /// No description provided for @settings_remote_bypass_help.
  ///
  /// In en, this message translates to:
  /// **'Enter the URL of your FlareSolverr instance (e.g. http://192.168.1.10:8191)'**
  String get settings_remote_bypass_help;

  /// No description provided for @settings_remote_server_url.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settings_remote_server_url;

  /// No description provided for @settings_remote_api_key.
  ///
  /// In en, this message translates to:
  /// **'API key (optional)'**
  String get settings_remote_api_key;

  /// No description provided for @settings_remote_timeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout (ms)'**
  String get settings_remote_timeout;

  /// No description provided for @settings_remote_trigger_mode.
  ///
  /// In en, this message translates to:
  /// **'Trigger mode'**
  String get settings_remote_trigger_mode;

  /// No description provided for @settings_remote_mode_auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settings_remote_mode_auto;

  /// No description provided for @settings_remote_mode_auto_desc.
  ///
  /// In en, this message translates to:
  /// **'Uses the remote server as soon as the 2 local attempts fail'**
  String get settings_remote_mode_auto_desc;

  /// No description provided for @settings_remote_mode_on_demand.
  ///
  /// In en, this message translates to:
  /// **'On demand'**
  String get settings_remote_mode_on_demand;

  /// No description provided for @settings_remote_mode_on_demand_desc.
  ///
  /// In en, this message translates to:
  /// **'Uses the remote server only when you tap \"Bypass via remote server\"'**
  String get settings_remote_mode_on_demand_desc;

  /// No description provided for @settings_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settings_save;

  /// No description provided for @settings_clear_database.
  ///
  /// In en, this message translates to:
  /// **'Clear the database'**
  String get settings_clear_database;

  /// No description provided for @settings_clear_database_body.
  ///
  /// In en, this message translates to:
  /// **'{count} series not saved in your library will be deleted.\n\nThis action cannot be undone.'**
  String settings_clear_database_body(Object count);

  /// No description provided for @settings_clear_image_caches_title.
  ///
  /// In en, this message translates to:
  /// **'Clear all image caches?'**
  String get settings_clear_image_caches_title;

  /// No description provided for @settings_clear_image_caches_body.
  ///
  /// In en, this message translates to:
  /// **'Covers and extension icons will be downloaded again the next time they are shown. Your downloads are not affected.'**
  String get settings_clear_image_caches_body;

  /// No description provided for @settings_share_crash_reports.
  ///
  /// In en, this message translates to:
  /// **'Share crash reports'**
  String get settings_share_crash_reports;

  /// No description provided for @settings_share_crash_reports_desc.
  ///
  /// In en, this message translates to:
  /// **'Writes crash reports to a file so you can share them with the developers'**
  String get settings_share_crash_reports_desc;

  /// No description provided for @settings_detailed_reports.
  ///
  /// In en, this message translates to:
  /// **'Detailed reports'**
  String get settings_detailed_reports;

  /// No description provided for @settings_detailed_reports_desc.
  ///
  /// In en, this message translates to:
  /// **'Adds detailed reports to the system traces (reduces app performance)'**
  String get settings_detailed_reports_desc;

  /// No description provided for @settings_onboarding_guide.
  ///
  /// In en, this message translates to:
  /// **'First-launch guide'**
  String get settings_onboarding_guide;

  /// No description provided for @settings_onboarding_guide_desc.
  ///
  /// In en, this message translates to:
  /// **'Restart the startup tutorial'**
  String get settings_onboarding_guide_desc;

  /// No description provided for @settings_manage_notifications.
  ///
  /// In en, this message translates to:
  /// **'Manage the app alerts'**
  String get settings_manage_notifications;

  /// No description provided for @settings_disable_battery_optimisation.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimisation'**
  String get settings_disable_battery_optimisation;

  /// No description provided for @settings_disable_battery_optimisation_desc.
  ///
  /// In en, this message translates to:
  /// **'Makes background library updates and backups easier'**
  String get settings_disable_battery_optimisation_desc;

  /// No description provided for @settings_dont_kill_my_app_desc.
  ///
  /// In en, this message translates to:
  /// **'Some manufacturers add extra restrictions on apps that kill background services. This website has more information on how to fix it.'**
  String get settings_dont_kill_my_app_desc;

  /// No description provided for @settings_remote_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable the remote server'**
  String get settings_remote_enable;

  /// No description provided for @settings_remote_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {url}'**
  String settings_remote_connected(Object url);

  /// No description provided for @settings_remote_none_configured.
  ///
  /// In en, this message translates to:
  /// **'No server configured — Tap Configure'**
  String get settings_remote_none_configured;

  /// No description provided for @settings_remote_configure.
  ///
  /// In en, this message translates to:
  /// **'Configure the remote server'**
  String get settings_remote_configure;

  /// No description provided for @settings_remote_configure_desc.
  ///
  /// In en, this message translates to:
  /// **'URL, API key, timeout, trigger mode'**
  String get settings_remote_configure_desc;

  /// No description provided for @settings_flaresolverr_help.
  ///
  /// In en, this message translates to:
  /// **'FlareSolverr is a proxy server that uses a headless browser to solve Cloudflare challenges. Install it on your machine or a local server and enter its URL here.'**
  String get settings_flaresolverr_help;

  /// No description provided for @settings_reindex_downloads.
  ///
  /// In en, this message translates to:
  /// **'Reindex the downloads'**
  String get settings_reindex_downloads;

  /// No description provided for @settings_reindex_downloads_desc.
  ///
  /// In en, this message translates to:
  /// **'Scans the files already on disk and fixes the missing entries'**
  String get settings_reindex_downloads_desc;

  /// No description provided for @settings_downloads_not_in_library.
  ///
  /// In en, this message translates to:
  /// **'Downloads not in the library'**
  String get settings_downloads_not_in_library;

  /// No description provided for @settings_downloads_not_in_library_desc.
  ///
  /// In en, this message translates to:
  /// **'Automatically adds to the library every series with a downloaded chapter'**
  String get settings_downloads_not_in_library_desc;

  /// No description provided for @settings_clear_database_desc.
  ///
  /// In en, this message translates to:
  /// **'Delete the history of the series that are not saved in your library'**
  String get settings_clear_database_desc;

  /// No description provided for @settings_clear_cookies.
  ///
  /// In en, this message translates to:
  /// **'Clear cookies'**
  String get settings_clear_cookies;

  /// No description provided for @settings_clear_webview_data.
  ///
  /// In en, this message translates to:
  /// **'Clear the WebView data'**
  String get settings_clear_webview_data;

  /// No description provided for @settings_doh.
  ///
  /// In en, this message translates to:
  /// **'DNS over HTTPS (DoH)'**
  String get settings_doh;

  /// No description provided for @settings_default_user_agent_list.
  ///
  /// In en, this message translates to:
  /// **'Default user-agent list'**
  String get settings_default_user_agent_list;

  /// No description provided for @settings_reset_user_agent.
  ///
  /// In en, this message translates to:
  /// **'Reset the user-agent list'**
  String get settings_reset_user_agent;

  /// No description provided for @settings_icon_cover_cache.
  ///
  /// In en, this message translates to:
  /// **'Icon and cover cache'**
  String get settings_icon_cover_cache;

  /// No description provided for @settings_max_cache_size.
  ///
  /// In en, this message translates to:
  /// **'Maximum cache size'**
  String get settings_max_cache_size;

  /// No description provided for @settings_max_cache_size_desc.
  ///
  /// In en, this message translates to:
  /// **'Total ceiling for every image cache. The oldest entry is removed first when the limit is reached.'**
  String get settings_max_cache_size_desc;

  /// No description provided for @settings_clear_icon_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear the extension icon cache'**
  String get settings_clear_icon_cache;

  /// No description provided for @settings_clear_cover_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear the library cover cache'**
  String get settings_clear_cover_cache;

  /// No description provided for @settings_clear_all_image_caches.
  ///
  /// In en, this message translates to:
  /// **'Clear all image caches'**
  String get settings_clear_all_image_caches;

  /// No description provided for @settings_refresh_cache_sizes.
  ///
  /// In en, this message translates to:
  /// **'Refresh the cache sizes'**
  String get settings_refresh_cache_sizes;

  /// No description provided for @settings_refresh_cache_sizes_desc.
  ///
  /// In en, this message translates to:
  /// **'Recalculates the disk cache sizes'**
  String get settings_refresh_cache_sizes_desc;

  /// No description provided for @settings_current_size.
  ///
  /// In en, this message translates to:
  /// **'Current size: {size}'**
  String settings_current_size(Object size);

  /// No description provided for @settings_current_total_size.
  ///
  /// In en, this message translates to:
  /// **'Current total size: {size}'**
  String settings_current_total_size(Object size);

  /// No description provided for @settings_refresh_library_covers.
  ///
  /// In en, this message translates to:
  /// **'Refresh the library covers'**
  String get settings_refresh_library_covers;

  /// No description provided for @settings_refreshing_covers.
  ///
  /// In en, this message translates to:
  /// **'Refreshing covers…'**
  String get settings_refreshing_covers;

  /// No description provided for @settings_reset_reader_per_series.
  ///
  /// In en, this message translates to:
  /// **'Reset the reader settings per series'**
  String get settings_reset_reader_per_series;

  /// No description provided for @settings_reset_reader_per_series_desc.
  ///
  /// In en, this message translates to:
  /// **'Resets the reading mode and orientation of every series'**
  String get settings_reset_reader_per_series_desc;

  /// No description provided for @settings_reset_reader_title.
  ///
  /// In en, this message translates to:
  /// **'Reset the reader settings'**
  String get settings_reset_reader_title;

  /// No description provided for @settings_reader_reset_done.
  ///
  /// In en, this message translates to:
  /// **'Reader settings reset'**
  String get settings_reader_reset_done;

  /// No description provided for @settings_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get settings_error;

  /// No description provided for @settings_update_library_titles.
  ///
  /// In en, this message translates to:
  /// **'Update the library series titles'**
  String get settings_update_library_titles;

  /// No description provided for @settings_update_library_titles_desc.
  ///
  /// In en, this message translates to:
  /// **'Warning: if a series is renamed, it will be removed from the download queue.'**
  String get settings_update_library_titles_desc;

  /// No description provided for @settings_updating_titles.
  ///
  /// In en, this message translates to:
  /// **'Updating titles…'**
  String get settings_updating_titles;

  /// No description provided for @settings_no_non_ascii.
  ///
  /// In en, this message translates to:
  /// **'Forbid non-ASCII file names'**
  String get settings_no_non_ascii;

  /// No description provided for @settings_no_non_ascii_desc.
  ///
  /// In en, this message translates to:
  /// **'Keeps compatibility with some storage media that do not support Unicode'**
  String get settings_no_non_ascii_desc;

  /// No description provided for @settings_bitmap_threshold.
  ///
  /// In en, this message translates to:
  /// **'Custom hardware bitmap threshold'**
  String get settings_bitmap_threshold;

  /// No description provided for @settings_bitmap_threshold_desc.
  ///
  /// In en, this message translates to:
  /// **'If the reader shows a blank image, lower the threshold gradually.'**
  String get settings_bitmap_threshold_desc;

  /// No description provided for @settings_old_decoder.
  ///
  /// In en, this message translates to:
  /// **'Use the old decoder for the long-strip reader'**
  String get settings_old_decoder;

  /// No description provided for @settings_old_decoder_desc.
  ///
  /// In en, this message translates to:
  /// **'Affects performance. Only enable it if lowering the bitmap threshold does not fix the blank image issues'**
  String get settings_old_decoder_desc;

  /// No description provided for @settings_custom_display_profile.
  ///
  /// In en, this message translates to:
  /// **'Custom display profile'**
  String get settings_custom_display_profile;

  /// No description provided for @settings_installer.
  ///
  /// In en, this message translates to:
  /// **'Installer'**
  String get settings_installer;

  /// No description provided for @settings_revoke_extra_repo_extensions.
  ///
  /// In en, this message translates to:
  /// **'Revoke extensions from an additional repository'**
  String get settings_revoke_extra_repo_extensions;

  /// No description provided for @settings_revoke_extensions_title.
  ///
  /// In en, this message translates to:
  /// **'Revoke the extensions'**
  String get settings_revoke_extensions_title;

  /// No description provided for @settings_revoke_extensions_body.
  ///
  /// In en, this message translates to:
  /// **'Every extension coming from additional repositories will be revoked.'**
  String get settings_revoke_extensions_body;

  /// No description provided for @settings_revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get settings_revoke;

  /// No description provided for @settings_extensions_revoked.
  ///
  /// In en, this message translates to:
  /// **'Extensions revoked'**
  String get settings_extensions_revoked;

  /// No description provided for @settings_interface_scale.
  ///
  /// In en, this message translates to:
  /// **'Interface scale'**
  String get settings_interface_scale;

  /// No description provided for @settings_interface_scale_desc.
  ///
  /// In en, this message translates to:
  /// **'Adapts the interface size (text + spacing). Useful for small screens like the iPhone 7.'**
  String get settings_interface_scale_desc;

  /// No description provided for @settings_default_suffix.
  ///
  /// In en, this message translates to:
  /// **'{value} (default)'**
  String settings_default_suffix(Object value);

  /// No description provided for @settings_logs_enable_hint.
  ///
  /// In en, this message translates to:
  /// **'Enable logs in About > Developer to configure these options.'**
  String get settings_logs_enable_hint;

  /// No description provided for @settings_log_mode.
  ///
  /// In en, this message translates to:
  /// **'Logging mode'**
  String get settings_log_mode;

  /// No description provided for @settings_log_suppress_images.
  ///
  /// In en, this message translates to:
  /// **'Suppress image errors'**
  String get settings_log_suppress_images;

  /// No description provided for @settings_log_suppress_images_desc.
  ///
  /// In en, this message translates to:
  /// **'Do not record 404 logo errors'**
  String get settings_log_suppress_images_desc;

  /// No description provided for @settings_log_active_categories.
  ///
  /// In en, this message translates to:
  /// **'Active categories'**
  String get settings_log_active_categories;

  /// No description provided for @settings_log_customisable.
  ///
  /// In en, this message translates to:
  /// **'customisable'**
  String get settings_log_customisable;

  /// No description provided for @settings_log_tag_ext.
  ///
  /// In en, this message translates to:
  /// **'Extensions [EXT]'**
  String get settings_log_tag_ext;

  /// No description provided for @settings_log_tag_ext_desc.
  ///
  /// In en, this message translates to:
  /// **'Extension installation, update and errors'**
  String get settings_log_tag_ext_desc;

  /// No description provided for @settings_log_tag_install.
  ///
  /// In en, this message translates to:
  /// **'Detailed install [INSTALL]'**
  String get settings_log_tag_install;

  /// No description provided for @settings_log_tag_install_desc.
  ///
  /// In en, this message translates to:
  /// **'Every install/uninstall step'**
  String get settings_log_tag_install_desc;

  /// No description provided for @settings_log_tag_dl.
  ///
  /// In en, this message translates to:
  /// **'Downloads [DL]'**
  String get settings_log_tag_dl;

  /// No description provided for @settings_log_tag_dl_desc.
  ///
  /// In en, this message translates to:
  /// **'Download progress, resume and errors'**
  String get settings_log_tag_dl_desc;

  /// No description provided for @settings_log_tag_hls.
  ///
  /// In en, this message translates to:
  /// **'HLS streaming [HLS]'**
  String get settings_log_tag_hls;

  /// No description provided for @settings_log_tag_hls_desc.
  ///
  /// In en, this message translates to:
  /// **'HLS segments, manifest and stream errors'**
  String get settings_log_tag_hls_desc;

  /// No description provided for @settings_log_tag_net.
  ///
  /// In en, this message translates to:
  /// **'Network [NET]'**
  String get settings_log_tag_net;

  /// No description provided for @settings_log_tag_net_desc.
  ///
  /// In en, this message translates to:
  /// **'HTTP requests, redirects and network errors'**
  String get settings_log_tag_net_desc;

  /// No description provided for @settings_log_tag_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga [MANGA]'**
  String get settings_log_tag_manga;

  /// No description provided for @settings_log_tag_manga_desc.
  ///
  /// In en, this message translates to:
  /// **'Series, chapters and metadata loading'**
  String get settings_log_tag_manga_desc;

  /// No description provided for @settings_log_tag_reader.
  ///
  /// In en, this message translates to:
  /// **'Reader [READER]'**
  String get settings_log_tag_reader;

  /// No description provided for @settings_log_tag_reader_desc.
  ///
  /// In en, this message translates to:
  /// **'Reader navigation, zoom and orientation'**
  String get settings_log_tag_reader_desc;

  /// No description provided for @settings_log_tag_page.
  ///
  /// In en, this message translates to:
  /// **'Manga pages [PAGE]'**
  String get settings_log_tag_page;

  /// No description provided for @settings_log_tag_page_desc.
  ///
  /// In en, this message translates to:
  /// **'⚡ Every loaded page (very verbose)'**
  String get settings_log_tag_page_desc;

  /// No description provided for @settings_log_tag_watch.
  ///
  /// In en, this message translates to:
  /// **'Video playback [WATCH]'**
  String get settings_log_tag_watch;

  /// No description provided for @settings_log_tag_watch_desc.
  ///
  /// In en, this message translates to:
  /// **'Episode opening, buffering, 60 s watchdog'**
  String get settings_log_tag_watch_desc;

  /// No description provided for @settings_log_tag_maint.
  ///
  /// In en, this message translates to:
  /// **'Maintenance [MAINT]'**
  String get settings_log_tag_maint;

  /// No description provided for @settings_log_tag_maint_desc.
  ///
  /// In en, this message translates to:
  /// **'Cookie cleanup, database, reindexing and background tasks'**
  String get settings_log_tag_maint_desc;

  /// No description provided for @settings_log_tag_ui.
  ///
  /// In en, this message translates to:
  /// **'Interface [UI]'**
  String get settings_log_tag_ui;

  /// No description provided for @settings_log_tag_ui_desc.
  ///
  /// In en, this message translates to:
  /// **'Interface events and errors'**
  String get settings_log_tag_ui_desc;

  /// No description provided for @settings_log_tag_img.
  ///
  /// In en, this message translates to:
  /// **'Images [IMG]'**
  String get settings_log_tag_img;

  /// No description provided for @settings_log_tag_img_desc.
  ///
  /// In en, this message translates to:
  /// **'Cover downloads: cache, network and failures'**
  String get settings_log_tag_img_desc;

  /// No description provided for @settings_silent_updates.
  ///
  /// In en, this message translates to:
  /// **'Silent updates'**
  String get settings_silent_updates;

  /// No description provided for @settings_silent_active.
  ///
  /// In en, this message translates to:
  /// **'Active — updates install automatically without confirmation.'**
  String get settings_silent_active;

  /// No description provided for @settings_silent_shizuku_required.
  ///
  /// In en, this message translates to:
  /// **'Shizuku is required for a one-time setup. Tap to configure.'**
  String get settings_silent_shizuku_required;

  /// No description provided for @settings_silent_shizuku_not_running.
  ///
  /// In en, this message translates to:
  /// **'Shizuku is not running. Open Shizuku and come back here.'**
  String get settings_silent_shizuku_not_running;

  /// No description provided for @settings_silent_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settings_silent_checking;

  /// No description provided for @settings_auto_install.
  ///
  /// In en, this message translates to:
  /// **'Automatic install'**
  String get settings_auto_install;

  /// No description provided for @settings_data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settings_data;

  /// No description provided for @settings_network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settings_network;

  /// No description provided for @settings_reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get settings_reader;

  /// No description provided for @settings_display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settings_display;

  /// No description provided for @settings_advanced_logs.
  ///
  /// In en, this message translates to:
  /// **'Advanced logs'**
  String get settings_advanced_logs;

  /// No description provided for @settings_background_activity.
  ///
  /// In en, this message translates to:
  /// **'Background activity'**
  String get settings_background_activity;

  /// No description provided for @settings_advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settings_advanced;

  /// No description provided for @settings_remote_section.
  ///
  /// In en, this message translates to:
  /// **'Remote Cloudflare bypass'**
  String get settings_remote_section;

  /// No description provided for @settings_library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settings_library;

  /// No description provided for @settings_cookies_cleared.
  ///
  /// In en, this message translates to:
  /// **'Cookies cleared'**
  String get settings_cookies_cleared;

  /// No description provided for @settings_webview_data_cleared.
  ///
  /// In en, this message translates to:
  /// **'WebView data cleared'**
  String get settings_webview_data_cleared;

  /// No description provided for @settings_cookies_clear_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the cookies'**
  String get settings_cookies_clear_failed;

  /// No description provided for @settings_webview_clear_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the WebView data'**
  String get settings_webview_clear_failed;

  /// No description provided for @settings_db_cleared.
  ///
  /// In en, this message translates to:
  /// **'Database cleaned ({count} deleted)'**
  String settings_db_cleared(Object count);

  /// No description provided for @settings_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settings_clear;

  /// No description provided for @settings_empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get settings_empty;

  /// No description provided for @settings_reindexing.
  ///
  /// In en, this message translates to:
  /// **'Reindexing…'**
  String get settings_reindexing;

  /// No description provided for @settings_reindex_done.
  ///
  /// In en, this message translates to:
  /// **'{fixed} of {total} chapter(s) reindexed'**
  String settings_reindex_done(Object fixed, Object total);

  /// No description provided for @settings_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settings_checking;

  /// No description provided for @settings_added_to_library.
  ///
  /// In en, this message translates to:
  /// **'{count} series added to the library'**
  String settings_added_to_library(Object count);

  /// No description provided for @settings_bytes_o.
  ///
  /// In en, this message translates to:
  /// **'{bytes} B'**
  String settings_bytes_o(Object bytes);

  /// No description provided for @settings_bytes_ko.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String settings_bytes_ko(Object value);

  /// No description provided for @settings_bytes_mo.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String settings_bytes_mo(Object value);

  /// No description provided for @settings_bytes_go.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String settings_bytes_go(Object value);

  /// No description provided for @settings_icon_cache_cleared.
  ///
  /// In en, this message translates to:
  /// **'Icon cache cleared'**
  String get settings_icon_cache_cleared;

  /// No description provided for @settings_cover_cache_cleared.
  ///
  /// In en, this message translates to:
  /// **'Cover cache cleared'**
  String get settings_cover_cache_cleared;

  /// No description provided for @settings_all_caches_cleared.
  ///
  /// In en, this message translates to:
  /// **'All image caches cleared'**
  String get settings_all_caches_cleared;

  /// No description provided for @settings_user_agent_reset.
  ///
  /// In en, this message translates to:
  /// **'User agent reset'**
  String get settings_user_agent_reset;

  /// No description provided for @settings_user_agent_reset_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset'**
  String get settings_user_agent_reset_failed;

  /// No description provided for @settings_battery_settings_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the battery optimisation settings.\nGo to Settings > Battery > Battery optimisation.'**
  String get settings_battery_settings_failed;

  /// No description provided for @settings_notifications_hint_android.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Notifications to manage the alerts.'**
  String get settings_notifications_hint_android;

  /// No description provided for @settings_notifications_hint_ios.
  ///
  /// In en, this message translates to:
  /// **'Open the system Settings to manage the notifications.'**
  String get settings_notifications_hint_ios;

  /// No description provided for @settings_extreme_warning.
  ///
  /// In en, this message translates to:
  /// **'⚡ Extreme – everything is logged. RAM +++. Use with caution.'**
  String get settings_extreme_warning;

  /// No description provided for @settings_debug_warning.
  ///
  /// In en, this message translates to:
  /// **'⚠ Debug mode active – high RAM usage'**
  String get settings_debug_warning;

  /// No description provided for @settings_log_mode_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settings_log_mode_normal;

  /// No description provided for @settings_log_mode_normal_desc.
  ///
  /// In en, this message translates to:
  /// **'INFO+ · extensions and installs only'**
  String get settings_log_mode_normal_desc;

  /// No description provided for @settings_log_mode_verbose.
  ///
  /// In en, this message translates to:
  /// **'Verbose'**
  String get settings_log_mode_verbose;

  /// No description provided for @settings_log_mode_verbose_desc.
  ///
  /// In en, this message translates to:
  /// **'DEBUG+ · network, downloads, manga, HLS'**
  String get settings_log_mode_verbose_desc;

  /// No description provided for @settings_log_mode_debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get settings_log_mode_debug;

  /// No description provided for @settings_log_mode_debug_desc.
  ///
  /// In en, this message translates to:
  /// **'DEBUG+ · everything except page-by-page reads'**
  String get settings_log_mode_debug_desc;

  /// No description provided for @settings_log_mode_extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get settings_log_mode_extreme;

  /// No description provided for @settings_log_mode_extreme_desc.
  ///
  /// In en, this message translates to:
  /// **'⚡ Log EVERYTHING – every page, HLS segment, reader event'**
  String get settings_log_mode_extreme_desc;

  /// No description provided for @settings_scale_default.
  ///
  /// In en, this message translates to:
  /// **'100% (default)'**
  String get settings_scale_default;

  /// No description provided for @settings_percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String settings_percent(Object value);

  /// No description provided for @reader_show_reading_mode.
  ///
  /// In en, this message translates to:
  /// **'Show the reading mode'**
  String get reader_show_reading_mode;

  /// No description provided for @reader_show_reading_mode_desc.
  ///
  /// In en, this message translates to:
  /// **'Lists the reading modes when the reader opens'**
  String get reader_show_reading_mode_desc;

  /// No description provided for @reader_show_tap_zones.
  ///
  /// In en, this message translates to:
  /// **'Show the tap zones (overlay)'**
  String get reader_show_tap_zones;

  /// No description provided for @reader_show_tap_zones_desc.
  ///
  /// In en, this message translates to:
  /// **'Briefly shown when the reader opens'**
  String get reader_show_tap_zones_desc;

  /// No description provided for @reader_load_ahead_wifi.
  ///
  /// In en, this message translates to:
  /// **'Only preload on Wi-Fi'**
  String get reader_load_ahead_wifi;

  /// No description provided for @reader_load_ahead_wifi_desc.
  ///
  /// In en, this message translates to:
  /// **'Saves mobile data by loading only the pages close to the one you are reading'**
  String get reader_load_ahead_wifi_desc;

  /// No description provided for @reader_pages_preload.
  ///
  /// In en, this message translates to:
  /// **'Number of pages to preload'**
  String get reader_pages_preload;

  /// No description provided for @reader_pages_preload_desc.
  ///
  /// In en, this message translates to:
  /// **'How many pages to preload while reading. A higher value makes reading smoother, at the cost of a larger cache and higher data usage.'**
  String get reader_pages_preload_desc;

  /// No description provided for @reader_section_display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get reader_section_display;

  /// No description provided for @reader_default_rotation.
  ///
  /// In en, this message translates to:
  /// **'Default rotation'**
  String get reader_default_rotation;

  /// No description provided for @reader_cutout.
  ///
  /// In en, this message translates to:
  /// **'Use the notch area'**
  String get reader_cutout;

  /// No description provided for @reader_show_page_number.
  ///
  /// In en, this message translates to:
  /// **'Show the page number'**
  String get reader_show_page_number;

  /// No description provided for @reader_section_eink.
  ///
  /// In en, this message translates to:
  /// **'E-Ink'**
  String get reader_section_eink;

  /// No description provided for @reader_eink_flash.
  ///
  /// In en, this message translates to:
  /// **'Flash on page change'**
  String get reader_eink_flash;

  /// No description provided for @reader_eink_flash_desc.
  ///
  /// In en, this message translates to:
  /// **'Reduces ghosting on e-ink screens'**
  String get reader_eink_flash_desc;

  /// No description provided for @reader_section_reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reader_section_reading;

  /// No description provided for @reader_skip_read.
  ///
  /// In en, this message translates to:
  /// **'Skip chapters marked as read'**
  String get reader_skip_read;

  /// No description provided for @reader_skip_filtered.
  ///
  /// In en, this message translates to:
  /// **'Skip filtered chapters'**
  String get reader_skip_filtered;

  /// No description provided for @reader_skip_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Ignore duplicate chapters'**
  String get reader_skip_duplicate;

  /// No description provided for @reader_always_transition.
  ///
  /// In en, this message translates to:
  /// **'Always show the transition between chapters'**
  String get reader_always_transition;

  /// No description provided for @reader_section_pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get reader_section_pages;

  /// No description provided for @reader_invert_tap_zones.
  ///
  /// In en, this message translates to:
  /// **'Invert the tap zones'**
  String get reader_invert_tap_zones;

  /// No description provided for @reader_zoom_start.
  ///
  /// In en, this message translates to:
  /// **'Initial zoom position'**
  String get reader_zoom_start;

  /// No description provided for @reader_panorama.
  ///
  /// In en, this message translates to:
  /// **'Pan wide images'**
  String get reader_panorama;

  /// No description provided for @reader_split_wide.
  ///
  /// In en, this message translates to:
  /// **'Split wide pages'**
  String get reader_split_wide;

  /// No description provided for @reader_rotate_wide.
  ///
  /// In en, this message translates to:
  /// **'Rotate wide pages to fit'**
  String get reader_rotate_wide;

  /// No description provided for @reader_disable_zoom_out.
  ///
  /// In en, this message translates to:
  /// **'Disable zooming out'**
  String get reader_disable_zoom_out;

  /// No description provided for @reader_disable_zoom_out_desc.
  ///
  /// In en, this message translates to:
  /// **'A double tap now only zooms in'**
  String get reader_disable_zoom_out_desc;

  /// No description provided for @reader_section_continuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous strip'**
  String get reader_section_continuous;

  /// No description provided for @reader_side_padding.
  ///
  /// In en, this message translates to:
  /// **'Side padding'**
  String get reader_side_padding;

  /// No description provided for @reader_menu_hide_sensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity for hiding the menu while scrolling'**
  String get reader_menu_hide_sensitivity;

  /// No description provided for @reader_section_navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get reader_section_navigation;

  /// No description provided for @reader_volume_buttons.
  ///
  /// In en, this message translates to:
  /// **'Use the volume buttons'**
  String get reader_volume_buttons;

  /// No description provided for @reader_volume_buttons_desc.
  ///
  /// In en, this message translates to:
  /// **'Use ▲/▼ to turn the pages'**
  String get reader_volume_buttons_desc;

  /// No description provided for @reader_invert_volume.
  ///
  /// In en, this message translates to:
  /// **'Invert the volume buttons'**
  String get reader_invert_volume;

  /// No description provided for @reader_volume_forward.
  ///
  /// In en, this message translates to:
  /// **'▲ → next page  •  ▼ → previous page'**
  String get reader_volume_forward;

  /// No description provided for @reader_volume_backward.
  ///
  /// In en, this message translates to:
  /// **'▲ → previous page  •  ▼ → next page'**
  String get reader_volume_backward;

  /// No description provided for @reader_vertical_navigator.
  ///
  /// In en, this message translates to:
  /// **'Vertical chapter navigator'**
  String get reader_vertical_navigator;

  /// No description provided for @reader_section_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get reader_section_actions;

  /// No description provided for @reader_long_press_actions.
  ///
  /// In en, this message translates to:
  /// **'Show actions on long press'**
  String get reader_long_press_actions;

  /// No description provided for @reader_save_pages_separate.
  ///
  /// In en, this message translates to:
  /// **'Save pages in separate folders'**
  String get reader_save_pages_separate;

  /// No description provided for @reader_option_free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get reader_option_free;

  /// No description provided for @reader_option_portrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get reader_option_portrait;

  /// No description provided for @reader_option_landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get reader_option_landscape;

  /// No description provided for @reader_option_auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get reader_option_auto;

  /// No description provided for @reader_option_left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get reader_option_left;

  /// No description provided for @reader_option_right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get reader_option_right;

  /// No description provided for @reader_option_center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get reader_option_center;

  /// No description provided for @reader_option_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reader_option_none;

  /// No description provided for @reader_option_both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get reader_option_both;

  /// No description provided for @reader_option_low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get reader_option_low;

  /// No description provided for @reader_option_medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get reader_option_medium;

  /// No description provided for @reader_option_high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get reader_option_high;

  /// No description provided for @settings_general_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, DNS, recommendations, Discord'**
  String get settings_general_subtitle;

  /// No description provided for @settings_display_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, colors, fonts, dark mode'**
  String get settings_display_subtitle;

  /// No description provided for @settings_library_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Categories, sorting, automatic updates'**
  String get settings_library_subtitle;

  /// No description provided for @settings_reader_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manga reader: pages, zoom, reading direction'**
  String get settings_reader_subtitle;

  /// No description provided for @settings_player_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Video player: quality, gestures, subtitles'**
  String get settings_player_subtitle;

  /// No description provided for @settings_downloads_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Folder, queue, Wi-Fi only'**
  String get settings_downloads_subtitle;

  /// No description provided for @settings_auto_backup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get settings_auto_backup;

  /// No description provided for @settings_auto_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Library, settings and cache — survives a reinstall'**
  String get settings_auto_backup_subtitle;

  /// No description provided for @settings_tracking_subtitle.
  ///
  /// In en, this message translates to:
  /// **'AniList, MyAnimeList, progress sync'**
  String get settings_tracking_subtitle;

  /// No description provided for @settings_sync_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup and synchronization'**
  String get settings_sync_subtitle;

  /// No description provided for @settings_browse_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Extension repositories, installed sources'**
  String get settings_browse_subtitle;

  /// No description provided for @settings_security_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock, password, biometrics'**
  String get settings_security_subtitle;

  /// No description provided for @settings_local_sources.
  ///
  /// In en, this message translates to:
  /// **'Local Sources'**
  String get settings_local_sources;

  /// No description provided for @settings_local_sources_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Import files from a local folder'**
  String get settings_local_sources_subtitle;

  /// No description provided for @settings_advanced_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Logging, cache, technical options'**
  String get settings_advanced_subtitle;

  /// No description provided for @settings_music_hub.
  ///
  /// In en, this message translates to:
  /// **'Music Hub'**
  String get settings_music_hub;

  /// No description provided for @settings_music_hub_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio player and music library'**
  String get settings_music_hub_subtitle;

  /// No description provided for @settings_remote_connection.
  ///
  /// In en, this message translates to:
  /// **'Remote Connection'**
  String get settings_remote_connection;

  /// No description provided for @settings_remote_connection_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Access the library from a browser'**
  String get settings_remote_connection_subtitle;

  /// No description provided for @settings_remote_mode.
  ///
  /// In en, this message translates to:
  /// **'Remote Mode'**
  String get settings_remote_mode;

  /// No description provided for @settings_remote_mode_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the library on the local network'**
  String get settings_remote_mode_subtitle;

  /// No description provided for @settings_about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, credits, license'**
  String get settings_about_subtitle;

  /// No description provided for @settings_search_no_results.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String settings_search_no_results(Object query);

  /// No description provided for @settings_search_results.
  ///
  /// In en, this message translates to:
  /// **'Results in the settings'**
  String get settings_search_results;

  /// No description provided for @downloads_section_per_media.
  ///
  /// In en, this message translates to:
  /// **'Per media'**
  String get downloads_section_per_media;

  /// No description provided for @downloads_watch_engine_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Engine, connections, episodes, fillers'**
  String get downloads_watch_engine_subtitle;

  /// No description provided for @downloads_manga_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Archive format, compression, chapters'**
  String get downloads_manga_subtitle;

  /// No description provided for @downloads_wifi_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connections, Wi-Fi downloads'**
  String get downloads_wifi_subtitle;

  /// No description provided for @downloads_simultaneous.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous downloads (max)'**
  String get downloads_simultaneous;

  /// No description provided for @downloads_speed_limit.
  ///
  /// In en, this message translates to:
  /// **'Speed limit'**
  String get downloads_speed_limit;

  /// No description provided for @downloads_disk_write_mode.
  ///
  /// In en, this message translates to:
  /// **'Disk write mode'**
  String get downloads_disk_write_mode;

  /// No description provided for @downloads_cards_gestures.
  ///
  /// In en, this message translates to:
  /// **'Cards & Gestures'**
  String get downloads_cards_gestures;

  /// No description provided for @downloads_cards.
  ///
  /// In en, this message translates to:
  /// **'Download cards'**
  String get downloads_cards;

  /// No description provided for @downloads_cards_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Buttons shown and swipe actions'**
  String get downloads_cards_subtitle;

  /// No description provided for @downloads_auto_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete automatically after reading'**
  String get downloads_auto_delete;

  /// No description provided for @downloads_quick_nav.
  ///
  /// In en, this message translates to:
  /// **'Quick navigation (dock)'**
  String get downloads_quick_nav;

  /// No description provided for @downloads_dock_history.
  ///
  /// In en, this message translates to:
  /// **'History in the dock'**
  String get downloads_dock_history;

  /// No description provided for @downloads_dock_updates.
  ///
  /// In en, this message translates to:
  /// **'Updates in the dock'**
  String get downloads_dock_updates;

  /// No description provided for @downloads_folder_structure.
  ///
  /// In en, this message translates to:
  /// **'Folder Structure'**
  String get downloads_folder_structure;

  /// No description provided for @downloads_delete_folder.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder'**
  String get downloads_delete_folder;

  /// No description provided for @downloads_watchtower_folders.
  ///
  /// In en, this message translates to:
  /// **'Watchtower folders'**
  String get downloads_watchtower_folders;

  /// No description provided for @downloads_allow_access.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get downloads_allow_access;

  /// No description provided for @settings_idx_title_dns_over_https.
  ///
  /// In en, this message translates to:
  /// **'DNS over HTTPS'**
  String get settings_idx_title_dns_over_https;

  /// No description provided for @settings_idx_title_dns_personnalise.
  ///
  /// In en, this message translates to:
  /// **'DNS personnalisé'**
  String get settings_idx_title_dns_personnalise;

  /// No description provided for @settings_idx_title_user_agent_par_defaut.
  ///
  /// In en, this message translates to:
  /// **'User-Agent par défaut'**
  String get settings_idx_title_user_agent_par_defaut;

  /// No description provided for @settings_idx_title_discord_rich_presence.
  ///
  /// In en, this message translates to:
  /// **'Discord Rich Presence'**
  String get settings_idx_title_discord_rich_presence;

  /// No description provided for @settings_idx_title_afficher_la_progression_discord.
  ///
  /// In en, this message translates to:
  /// **'Afficher la progression Discord'**
  String get settings_idx_title_afficher_la_progression_discord;

  /// No description provided for @settings_idx_title_mode_tablette.
  ///
  /// In en, this message translates to:
  /// **'Mode tablette'**
  String get settings_idx_title_mode_tablette;

  /// No description provided for @settings_idx_title_durees_relatives.
  ///
  /// In en, this message translates to:
  /// **'Durées relatives'**
  String get settings_idx_title_durees_relatives;

  /// No description provided for @settings_idx_title_rendre_les_images_dans_les_descriptions_de_mangas.
  ///
  /// In en, this message translates to:
  /// **'Rendre les images dans les descriptions de mangas'**
  String
  get settings_idx_title_rendre_les_images_dans_les_descriptions_de_mangas;

  /// No description provided for @settings_idx_title_mode_sombre_pur.
  ///
  /// In en, this message translates to:
  /// **'Mode sombre pur'**
  String get settings_idx_title_mode_sombre_pur;

  /// No description provided for @settings_idx_title_niveau_de_melange_des_couleurs.
  ///
  /// In en, this message translates to:
  /// **'Niveau de mélange des couleurs'**
  String get settings_idx_title_niveau_de_melange_des_couleurs;

  /// No description provided for @settings_idx_title_reorganiser_la_navigation.
  ///
  /// In en, this message translates to:
  /// **'Réorganiser la navigation'**
  String get settings_idx_title_reorganiser_la_navigation;

  /// No description provided for @settings_idx_title_interface_effets.
  ///
  /// In en, this message translates to:
  /// **'Interface & Effets'**
  String get settings_idx_title_interface_effets;

  /// No description provided for @settings_idx_title_categorie_par_defaut.
  ///
  /// In en, this message translates to:
  /// **'Catégorie par défaut'**
  String get settings_idx_title_categorie_par_defaut;

  /// No description provided for @settings_idx_title_reglages_de_tri_par_categorie.
  ///
  /// In en, this message translates to:
  /// **'Réglages de tri par catégorie'**
  String get settings_idx_title_reglages_de_tri_par_categorie;

  /// No description provided for @settings_idx_title_mises_a_jour_automatiques.
  ///
  /// In en, this message translates to:
  /// **'Mises à jour automatiques'**
  String get settings_idx_title_mises_a_jour_automatiques;

  /// No description provided for @settings_idx_title_restrictions_materielles_pour_les_mises_a_jour.
  ///
  /// In en, this message translates to:
  /// **'Restrictions matérielles pour les mises à jour'**
  String get settings_idx_title_restrictions_materielles_pour_les_mises_a_jour;

  /// No description provided for @settings_idx_title_categories_des_mises_a_jour_inclure_exclure.
  ///
  /// In en, this message translates to:
  /// **'Catégories des mises à jour (inclure / exclure)'**
  String get settings_idx_title_categories_des_mises_a_jour_inclure_exclure;

  /// No description provided for @settings_idx_title_actualiser_automatiquement_les_metadonnees.
  ///
  /// In en, this message translates to:
  /// **'Actualiser automatiquement les métadonnées'**
  String get settings_idx_title_actualiser_automatiquement_les_metadonnees;

  /// No description provided for @settings_idx_title_verifier_sil_y_a_une_nouvelle_couverture_ou_synopsis.
  ///
  /// In en, this message translates to:
  /// **'Vérifier s’il y a une nouvelle couverture ou synopsis'**
  String
  get settings_idx_title_verifier_sil_y_a_une_nouvelle_couverture_ou_synopsis;

  /// No description provided for @settings_idx_title_mise_a_jour_intelligente.
  ///
  /// In en, this message translates to:
  /// **'Mise à jour intelligente'**
  String get settings_idx_title_mise_a_jour_intelligente;

  /// No description provided for @settings_idx_title_afficher_le_nombre_de_chapitres_non_lus.
  ///
  /// In en, this message translates to:
  /// **'Afficher le nombre de chapitres non lus'**
  String get settings_idx_title_afficher_le_nombre_de_chapitres_non_lus;

  /// No description provided for @settings_idx_title_action_de_glisser_a_gauche.
  ///
  /// In en, this message translates to:
  /// **'Action de glisser à gauche'**
  String get settings_idx_title_action_de_glisser_a_gauche;

  /// No description provided for @settings_idx_title_action_de_glisser_a_droite.
  ///
  /// In en, this message translates to:
  /// **'Action de glisser à droite'**
  String get settings_idx_title_action_de_glisser_a_droite;

  /// No description provided for @settings_idx_title_marquer_un_chapitre_duplique_comme_lu.
  ///
  /// In en, this message translates to:
  /// **'Marquer un chapitre dupliqué comme lu'**
  String get settings_idx_title_marquer_un_chapitre_duplique_comme_lu;

  /// No description provided for @settings_idx_title_masquer_les_indicateurs_de_chapitre_manquants.
  ///
  /// In en, this message translates to:
  /// **'Masquer les indicateurs de chapitre manquants'**
  String get settings_idx_title_masquer_les_indicateurs_de_chapitre_manquants;

  /// No description provided for @settings_idx_title_type_de_mise_a_lechelle.
  ///
  /// In en, this message translates to:
  /// **'Type de mise à l’échelle'**
  String get settings_idx_title_type_de_mise_a_lechelle;

  /// No description provided for @settings_idx_title_garder_lecran_allume.
  ///
  /// In en, this message translates to:
  /// **'Garder l’écran allumé'**
  String get settings_idx_title_garder_lecran_allume;

  /// No description provided for @settings_idx_title_navigation_par_boutons_de_volume.
  ///
  /// In en, this message translates to:
  /// **'Navigation par boutons de volume'**
  String get settings_idx_title_navigation_par_boutons_de_volume;

  /// No description provided for @settings_idx_page_lecteur_video.
  ///
  /// In en, this message translates to:
  /// **'Lecteur Vidéo'**
  String get settings_idx_page_lecteur_video;

  /// No description provided for @settings_idx_title_gestes.
  ///
  /// In en, this message translates to:
  /// **'Gestes'**
  String get settings_idx_title_gestes;

  /// No description provided for @settings_idx_title_sous_titres.
  ///
  /// In en, this message translates to:
  /// **'Sous-titres'**
  String get settings_idx_title_sous_titres;

  /// No description provided for @settings_idx_title_editeur_de_scripts.
  ///
  /// In en, this message translates to:
  /// **'Éditeur de scripts'**
  String get settings_idx_title_editeur_de_scripts;

  /// No description provided for @settings_idx_title_torrent.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get settings_idx_title_torrent;

  /// No description provided for @settings_idx_title_fichiers_utilisateur.
  ///
  /// In en, this message translates to:
  /// **'Fichiers utilisateur'**
  String get settings_idx_title_fichiers_utilisateur;

  /// No description provided for @settings_idx_page_sources_locales.
  ///
  /// In en, this message translates to:
  /// **'Sources locales'**
  String get settings_idx_page_sources_locales;

  /// No description provided for @settings_idx_title_sources_locales.
  ///
  /// In en, this message translates to:
  /// **'Sources locales'**
  String get settings_idx_title_sources_locales;

  /// No description provided for @settings_idx_title_dont_kill_my_app.
  ///
  /// In en, this message translates to:
  /// **'Don\'t kill my app!'**
  String get settings_idx_title_dont_kill_my_app;

  /// No description provided for @settings_idx_page_mode_distant.
  ///
  /// In en, this message translates to:
  /// **'Mode distant'**
  String get settings_idx_page_mode_distant;

  /// No description provided for @settings_idx_title_mode_distant.
  ///
  /// In en, this message translates to:
  /// **'Mode distant'**
  String get settings_idx_title_mode_distant;

  /// No description provided for @settings_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search in the settings…'**
  String get settings_search_hint;

  /// No description provided for @downloads_simultaneous_title.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous downloads'**
  String get downloads_simultaneous_title;

  /// No description provided for @downloads_simultaneous_subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} download at a time} other{{count} downloads at a time}}'**
  String downloads_simultaneous_subtitle(num count);

  /// No description provided for @downloads_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get downloads_disabled;

  /// No description provided for @downloads_write_part.
  ///
  /// In en, this message translates to:
  /// **'.part + resume'**
  String get downloads_write_part;

  /// No description provided for @downloads_write_part_desc.
  ///
  /// In en, this message translates to:
  /// **'Writes to a .part file then renames it at the end. Resumes automatically after an interruption; the partial file stays readable.'**
  String get downloads_write_part_desc;

  /// No description provided for @downloads_write_prealloc.
  ///
  /// In en, this message translates to:
  /// **'Pre-allocation'**
  String get downloads_write_prealloc;

  /// No description provided for @downloads_write_prealloc_desc.
  ///
  /// In en, this message translates to:
  /// **'Reserves the final file size before downloading. Avoids fragmentation on large files.'**
  String get downloads_write_prealloc_desc;

  /// No description provided for @downloads_write_direct.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get downloads_write_direct;

  /// No description provided for @downloads_write_direct_desc.
  ///
  /// In en, this message translates to:
  /// **'Writes straight to the final path (legacy behaviour). The file may be corrupted if the download is interrupted.'**
  String get downloads_write_direct_desc;

  /// No description provided for @downloads_section_deletion.
  ///
  /// In en, this message translates to:
  /// **'Deletion'**
  String get downloads_section_deletion;

  /// No description provided for @downloads_auto_delete_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes the file once the content has been read or watched'**
  String get downloads_auto_delete_subtitle;

  /// No description provided for @downloads_allow_bookmarked_delete.
  ///
  /// In en, this message translates to:
  /// **'Allow deleting bookmarked chapters'**
  String get downloads_allow_bookmarked_delete;

  /// No description provided for @downloads_allow_bookmarked_delete_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Lets a chapter with a bookmark be deleted'**
  String get downloads_allow_bookmarked_delete_subtitle;

  /// No description provided for @downloads_dock_history_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows the History tab in the navigation bar'**
  String get downloads_dock_history_subtitle;

  /// No description provided for @downloads_dock_updates_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows the Updates tab in the navigation bar'**
  String get downloads_dock_updates_subtitle;

  /// No description provided for @downloads_default_folder.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get downloads_default_folder;

  /// No description provided for @downloads_storage_unavailable_snack.
  ///
  /// In en, this message translates to:
  /// **'The download folder is not accessible. Check the storage space and try again.'**
  String get downloads_storage_unavailable_snack;

  /// No description provided for @downloads_no_folder.
  ///
  /// In en, this message translates to:
  /// **'No download folder is available.'**
  String get downloads_no_folder;

  /// No description provided for @downloads_folder_prepare_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the download folder.'**
  String get downloads_folder_prepare_failed;

  /// No description provided for @downloads_file_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} file} other{{count} files}}'**
  String downloads_file_count(num count);

  /// No description provided for @downloads_folder_not_created.
  ///
  /// In en, this message translates to:
  /// **'Folder not created yet'**
  String get downloads_folder_not_created;

  /// No description provided for @library_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library_settings_title;

  /// No description provided for @library_settings_section_updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get library_settings_section_updates;

  /// No description provided for @library_settings_section_behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get library_settings_section_behavior;

  /// No description provided for @library_settings_categories_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, rename and delete your categories'**
  String get library_settings_categories_subtitle;

  /// No description provided for @library_settings_edit_categories_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder and assign titles'**
  String get library_settings_edit_categories_subtitle;

  /// No description provided for @library_settings_default_category.
  ///
  /// In en, this message translates to:
  /// **'Default category'**
  String get library_settings_default_category;

  /// No description provided for @library_settings_per_category_sort.
  ///
  /// In en, this message translates to:
  /// **'Keep sort settings per category'**
  String get library_settings_per_category_sort;

  /// No description provided for @library_settings_update_restrictions.
  ///
  /// In en, this message translates to:
  /// **'Hardware restrictions for automatic updates'**
  String get library_settings_update_restrictions;

  /// No description provided for @library_settings_restrictions.
  ///
  /// In en, this message translates to:
  /// **'Restrictions'**
  String get library_settings_restrictions;

  /// No description provided for @library_settings_restrictions_summary.
  ///
  /// In en, this message translates to:
  /// **'Restrictions: {list}'**
  String library_settings_restrictions_summary(Object list);

  /// No description provided for @library_settings_categories_summary.
  ///
  /// In en, this message translates to:
  /// **'Include: {include}\nExclude: {exclude}'**
  String library_settings_categories_summary(Object exclude, Object include);

  /// No description provided for @library_settings_auto_refresh_metadata.
  ///
  /// In en, this message translates to:
  /// **'Automatically refresh metadata'**
  String get library_settings_auto_refresh_metadata;

  /// No description provided for @library_settings_check_new_cover.
  ///
  /// In en, this message translates to:
  /// **'Check for a new cover or synopsis on library updates'**
  String get library_settings_check_new_cover;

  /// No description provided for @library_settings_unread_badge.
  ///
  /// In en, this message translates to:
  /// **'Show the unread chapter count on the updates icon'**
  String get library_settings_unread_badge;

  /// No description provided for @library_settings_swipe_left.
  ///
  /// In en, this message translates to:
  /// **'Left swipe action'**
  String get library_settings_swipe_left;

  /// No description provided for @library_settings_swipe_right.
  ///
  /// In en, this message translates to:
  /// **'Right swipe action'**
  String get library_settings_swipe_right;

  /// No description provided for @library_settings_mark_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Mark a duplicate chapter as read'**
  String get library_settings_mark_duplicate;

  /// No description provided for @library_settings_hide_missing.
  ///
  /// In en, this message translates to:
  /// **'Hide missing chapter indicators'**
  String get library_settings_hide_missing;

  /// No description provided for @library_settings_include.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get library_settings_include;

  /// No description provided for @library_settings_exclude.
  ///
  /// In en, this message translates to:
  /// **'Exclude'**
  String get library_settings_exclude;

  /// No description provided for @library_settings_no_category.
  ///
  /// In en, this message translates to:
  /// **'No category.'**
  String get library_settings_no_category;

  /// No description provided for @library_settings_everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get library_settings_everything;

  /// No description provided for @library_settings_charging_only.
  ///
  /// In en, this message translates to:
  /// **'Only while charging'**
  String get library_settings_charging_only;

  /// No description provided for @library_settings_manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get library_settings_manual;

  /// No description provided for @library_settings_every_2_days.
  ///
  /// In en, this message translates to:
  /// **'Every 2 days'**
  String get library_settings_every_2_days;

  /// No description provided for @library_settings_every_2_weeks.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get library_settings_every_2_weeks;

  /// No description provided for @library_settings_every_month.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get library_settings_every_month;

  /// No description provided for @library_settings_smart_new_chapters.
  ///
  /// In en, this message translates to:
  /// **'New chapters only'**
  String get library_settings_smart_new_chapters;

  /// No description provided for @library_settings_always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get library_settings_always;

  /// No description provided for @library_settings_mark_chapter.
  ///
  /// In en, this message translates to:
  /// **'Mark chapter'**
  String get library_settings_mark_chapter;

  /// No description provided for @library_settings_mark_as_read.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get library_settings_mark_as_read;

  /// No description provided for @library_settings_swipe_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get library_settings_swipe_none;

  /// No description provided for @downloads_watch_title.
  ///
  /// In en, this message translates to:
  /// **'Downloads — Watch'**
  String get downloads_watch_title;

  /// No description provided for @downloads_novel_title.
  ///
  /// In en, this message translates to:
  /// **'Downloads — Novel'**
  String get downloads_novel_title;

  /// No description provided for @downloads_music_title.
  ///
  /// In en, this message translates to:
  /// **'Downloads — Music'**
  String get downloads_music_title;

  /// No description provided for @downloads_game_title.
  ///
  /// In en, this message translates to:
  /// **'Downloads — Game'**
  String get downloads_game_title;

  /// No description provided for @downloads_engine_section.
  ///
  /// In en, this message translates to:
  /// **'Download engine'**
  String get downloads_engine_section;

  /// No description provided for @downloads_connections_section.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get downloads_connections_section;

  /// No description provided for @downloads_behavior_section.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get downloads_behavior_section;

  /// No description provided for @downloads_hls_connections.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous HLS connections'**
  String get downloads_hls_connections;

  /// No description provided for @downloads_hls_connections_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Segments downloaded in parallel per episode'**
  String get downloads_hls_connections_subtitle;

  /// No description provided for @downloads_episodes_queue.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous episodes (queue)'**
  String get downloads_episodes_queue;

  /// No description provided for @downloads_episodes_queue_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Number of episodes downloaded at the same time'**
  String get downloads_episodes_queue_subtitle;

  /// No description provided for @downloads_wifi_only.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get downloads_wifi_only;

  /// No description provided for @downloads_wifi_only_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Download over Wi-Fi only'**
  String get downloads_wifi_only_subtitle;

  /// No description provided for @downloads_new_episodes.
  ///
  /// In en, this message translates to:
  /// **'Download new episodes'**
  String get downloads_new_episodes;

  /// No description provided for @downloads_new_episodes_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically downloads new available episodes'**
  String get downloads_new_episodes_subtitle;

  /// No description provided for @downloads_filler.
  ///
  /// In en, this message translates to:
  /// **'Allow filler episodes'**
  String get downloads_filler;

  /// No description provided for @downloads_filler_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Include filler episodes in automatic downloads'**
  String get downloads_filler_subtitle;

  /// No description provided for @downloads_anticipatory.
  ///
  /// In en, this message translates to:
  /// **'Anticipatory download'**
  String get downloads_anticipatory;

  /// No description provided for @downloads_anticipatory_watch_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-downloads while watching when the next 2 episodes are available'**
  String get downloads_anticipatory_watch_subtitle;

  /// No description provided for @downloads_external_section.
  ///
  /// In en, this message translates to:
  /// **'External downloader'**
  String get downloads_external_section;

  /// No description provided for @downloads_always_external.
  ///
  /// In en, this message translates to:
  /// **'Always use an external downloader'**
  String get downloads_always_external;

  /// No description provided for @downloads_always_external_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Hands every download to the external app chosen below'**
  String get downloads_always_external_subtitle;

  /// No description provided for @downloads_no_app.
  ///
  /// In en, this message translates to:
  /// **'No app selected'**
  String get downloads_no_app;

  /// No description provided for @downloads_no_app_subtitle.
  ///
  /// In en, this message translates to:
  /// **'The app will ask on every download.'**
  String get downloads_no_app_subtitle;

  /// No description provided for @downloads_preferred_app.
  ///
  /// In en, this message translates to:
  /// **'Preferred download app'**
  String get downloads_preferred_app;

  /// No description provided for @downloads_none_app.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get downloads_none_app;

  /// No description provided for @downloads_test_launch.
  ///
  /// In en, this message translates to:
  /// **'Test (launches {name})'**
  String downloads_test_launch(Object name);

  /// No description provided for @downloads_launched.
  ///
  /// In en, this message translates to:
  /// **'{name} launched via intent'**
  String downloads_launched(Object name);

  /// No description provided for @downloads_launch_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not launch {name} (is the app installed?)'**
  String downloads_launch_failed(Object name);

  /// No description provided for @downloads_official_site.
  ///
  /// In en, this message translates to:
  /// **'Official site'**
  String get downloads_official_site;

  /// No description provided for @downloads_ext_adm_desc.
  ///
  /// In en, this message translates to:
  /// **'Multi-threaded download manager for Android.'**
  String get downloads_ext_adm_desc;

  /// No description provided for @downloads_ext_1dm_desc.
  ///
  /// In en, this message translates to:
  /// **'Fast downloader with HLS and DASH support for Android.'**
  String get downloads_ext_1dm_desc;

  /// No description provided for @downloads_ext_fdm_desc.
  ///
  /// In en, this message translates to:
  /// **'Free and open-source cross-platform downloader.'**
  String get downloads_ext_fdm_desc;

  /// No description provided for @downloads_ext_idm_desc.
  ///
  /// In en, this message translates to:
  /// **'High-speed downloader with resume (Windows).'**
  String get downloads_ext_idm_desc;

  /// No description provided for @downloads_ext_jdownloader_desc.
  ///
  /// In en, this message translates to:
  /// **'Very popular open-source cross-platform downloader.'**
  String get downloads_ext_jdownloader_desc;

  /// No description provided for @downloads_ext_motrix_desc.
  ///
  /// In en, this message translates to:
  /// **'Open-source Aria2 downloader with a modern interface.'**
  String get downloads_ext_motrix_desc;

  /// No description provided for @downloads_mode_internal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get downloads_mode_internal;

  /// No description provided for @downloads_mode_external.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get downloads_mode_external;

  /// No description provided for @downloads_mode_internal_desc.
  ///
  /// In en, this message translates to:
  /// **'HLS downloader built into the app. Ideal for most streams.'**
  String get downloads_mode_internal_desc;

  /// No description provided for @downloads_mode_aria2_desc.
  ///
  /// In en, this message translates to:
  /// **'High-performance aria2c engine. Multiple connections and download resume.'**
  String get downloads_mode_aria2_desc;

  /// No description provided for @downloads_mode_external_desc.
  ///
  /// In en, this message translates to:
  /// **'Hands off to an external app (ADM, 1DM, FDM, IDM…). The download leaves the app.'**
  String get downloads_mode_external_desc;

  /// No description provided for @downloads_mode_zeus_desc.
  ///
  /// In en, this message translates to:
  /// **'Python extractor (ZeusDL) for web pages: TikTok, Facebook, Instagram… without watermark.'**
  String get downloads_mode_zeus_desc;

  /// No description provided for @downloads_manga_engine_note.
  ///
  /// In en, this message translates to:
  /// **'Manga always uses the internal downloader: a chapter’s pages are fetched in parallel automatically.'**
  String get downloads_manga_engine_note;

  /// No description provided for @downloads_archive_section.
  ///
  /// In en, this message translates to:
  /// **'Archive format'**
  String get downloads_archive_section;

  /// No description provided for @downloads_compression_section.
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get downloads_compression_section;

  /// No description provided for @downloads_compression_disabled.
  ///
  /// In en, this message translates to:
  /// **'Choose an archive format to enable compression.'**
  String get downloads_compression_disabled;

  /// No description provided for @downloads_compression_none.
  ///
  /// In en, this message translates to:
  /// **'No recompression: original pages are kept, only ZIP packing is applied (fastest).'**
  String get downloads_compression_none;

  /// No description provided for @downloads_compression_level.
  ///
  /// In en, this message translates to:
  /// **'Level {level}/9 · pages are re-encoded to lighter JPEG then packed into the archive: smaller file, a little quality lost.'**
  String downloads_compression_level(Object level);

  /// No description provided for @downloads_less_compressed.
  ///
  /// In en, this message translates to:
  /// **'Less compressed'**
  String get downloads_less_compressed;

  /// No description provided for @downloads_more_compressed.
  ///
  /// In en, this message translates to:
  /// **'More compressed'**
  String get downloads_more_compressed;

  /// No description provided for @downloads_compression_fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get downloads_compression_fast;

  /// No description provided for @downloads_compression_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get downloads_compression_light;

  /// No description provided for @downloads_compression_light_plus.
  ///
  /// In en, this message translates to:
  /// **'Light +'**
  String get downloads_compression_light_plus;

  /// No description provided for @downloads_compression_standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get downloads_compression_standard;

  /// No description provided for @downloads_compression_standard_plus.
  ///
  /// In en, this message translates to:
  /// **'Standard +'**
  String get downloads_compression_standard_plus;

  /// No description provided for @downloads_compression_strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get downloads_compression_strong;

  /// No description provided for @downloads_compression_strong_plus.
  ///
  /// In en, this message translates to:
  /// **'Strong +'**
  String get downloads_compression_strong_plus;

  /// No description provided for @downloads_compression_intense.
  ///
  /// In en, this message translates to:
  /// **'Intense'**
  String get downloads_compression_intense;

  /// No description provided for @downloads_compression_intense_plus.
  ///
  /// In en, this message translates to:
  /// **'Intense +'**
  String get downloads_compression_intense_plus;

  /// No description provided for @downloads_compression_maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get downloads_compression_maximum;

  /// No description provided for @downloads_archive_cbz_title.
  ///
  /// In en, this message translates to:
  /// **'Comic Book ZIP'**
  String get downloads_archive_cbz_title;

  /// No description provided for @downloads_archive_cbz_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Most compatible · ZIP images'**
  String get downloads_archive_cbz_subtitle;

  /// No description provided for @downloads_archive_cbr_title.
  ///
  /// In en, this message translates to:
  /// **'Comic Book RAR'**
  String get downloads_archive_cbr_title;

  /// No description provided for @downloads_archive_cbr_subtitle.
  ///
  /// In en, this message translates to:
  /// **'CBR container · readable everywhere'**
  String get downloads_archive_cbr_subtitle;

  /// No description provided for @downloads_archive_cb7_title.
  ///
  /// In en, this message translates to:
  /// **'Comic Book 7-Zip'**
  String get downloads_archive_cb7_title;

  /// No description provided for @downloads_archive_cb7_subtitle.
  ///
  /// In en, this message translates to:
  /// **'CB7 container · highly compressed'**
  String get downloads_archive_cb7_subtitle;

  /// No description provided for @downloads_archive_zip_title.
  ///
  /// In en, this message translates to:
  /// **'Standard ZIP'**
  String get downloads_archive_zip_title;

  /// No description provided for @downloads_archive_zip_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Raw ZIP archive'**
  String get downloads_archive_zip_subtitle;

  /// No description provided for @downloads_archive_folder_title.
  ///
  /// In en, this message translates to:
  /// **'Image folder'**
  String get downloads_archive_folder_title;

  /// No description provided for @downloads_archive_folder_subtitle.
  ///
  /// In en, this message translates to:
  /// **'No archive · direct access'**
  String get downloads_archive_folder_subtitle;

  /// No description provided for @downloads_manga_new_chapters.
  ///
  /// In en, this message translates to:
  /// **'Download new chapters'**
  String get downloads_manga_new_chapters;

  /// No description provided for @downloads_manga_new_chapters_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically downloads new available chapters'**
  String get downloads_manga_new_chapters_subtitle;

  /// No description provided for @downloads_anticipatory_read.
  ///
  /// In en, this message translates to:
  /// **'Anticipatory download (reading)'**
  String get downloads_anticipatory_read;

  /// No description provided for @downloads_anticipatory_read_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-downloads when the current and next chapter are already present'**
  String get downloads_anticipatory_read_subtitle;

  /// No description provided for @downloads_delete_after_read.
  ///
  /// In en, this message translates to:
  /// **'Delete after reading'**
  String get downloads_delete_after_read;

  /// No description provided for @downloads_delete_after_read_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes the chapter as soon as it is marked read'**
  String get downloads_delete_after_read_subtitle;

  /// No description provided for @downloads_delete_marked.
  ///
  /// In en, this message translates to:
  /// **'Delete even bookmarked chapters'**
  String get downloads_delete_marked;

  /// No description provided for @downloads_delete_marked_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic deletion also applies to bookmarked chapters'**
  String get downloads_delete_marked_subtitle;

  /// No description provided for @downloads_novel_note.
  ///
  /// In en, this message translates to:
  /// **'Novel uses the internal downloader through the source extension. Chapters are saved as HTML and grouped by title.'**
  String get downloads_novel_note;

  /// No description provided for @downloads_music_note.
  ///
  /// In en, this message translates to:
  /// **'Music uses the internal downloader through the source extension.'**
  String get downloads_music_note;

  /// No description provided for @downloads_game_note.
  ///
  /// In en, this message translates to:
  /// **'Game uses the internal downloader through the source extension.'**
  String get downloads_game_note;

  /// No description provided for @downloads_connections_simultaneous.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous connections'**
  String get downloads_connections_simultaneous;

  /// No description provided for @downloads_connections_per_chapter.
  ///
  /// In en, this message translates to:
  /// **'Parallel connections per chapter'**
  String get downloads_connections_per_chapter;

  /// No description provided for @downloads_connections_per_download.
  ///
  /// In en, this message translates to:
  /// **'Parallel connections per download'**
  String get downloads_connections_per_download;

  /// No description provided for @downloads_chapters_queue.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous chapters (queue)'**
  String get downloads_chapters_queue;

  /// No description provided for @downloads_chapters_queue_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Number of chapters downloaded at the same time'**
  String get downloads_chapters_queue_subtitle;

  /// No description provided for @downloads_items_queue.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous items (queue)'**
  String get downloads_items_queue;

  /// No description provided for @downloads_items_queue_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Number of items downloaded at the same time'**
  String get downloads_items_queue_subtitle;

  /// No description provided for @downloads_cards_buttons_section.
  ///
  /// In en, this message translates to:
  /// **'Download card buttons'**
  String get downloads_cards_buttons_section;

  /// No description provided for @downloads_cards_buttons_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the buttons shown on each download card.'**
  String get downloads_cards_buttons_subtitle;

  /// No description provided for @downloads_card_preview.
  ///
  /// In en, this message translates to:
  /// **'Card preview'**
  String get downloads_card_preview;

  /// No description provided for @downloads_swipe_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Action triggered by swiping a card left or right.'**
  String get downloads_swipe_subtitle;

  /// No description provided for @downloads_swipe_left.
  ///
  /// In en, this message translates to:
  /// **'Swipe left'**
  String get downloads_swipe_left;

  /// No description provided for @downloads_swipe_right.
  ///
  /// In en, this message translates to:
  /// **'Swipe right'**
  String get downloads_swipe_right;

  /// No description provided for @downloads_no_buttons.
  ///
  /// In en, this message translates to:
  /// **'No button shown — swipe to act.'**
  String get downloads_no_buttons;

  /// No description provided for @downloads_storage_format.
  ///
  /// In en, this message translates to:
  /// **'Storage format'**
  String get downloads_storage_format;

  /// No description provided for @downloads_archive_folder_desc.
  ///
  /// In en, this message translates to:
  /// **'Pages verified, kept in a folder.'**
  String get downloads_archive_folder_desc;

  /// No description provided for @downloads_archive_cbz_desc.
  ///
  /// In en, this message translates to:
  /// **'Archive created after all pages are verified.'**
  String get downloads_archive_cbz_desc;

  /// No description provided for @downloads_archive_zip_desc.
  ///
  /// In en, this message translates to:
  /// **'ZIP archive created after pages are verified.'**
  String get downloads_archive_zip_desc;

  /// No description provided for @downloads_archive_unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format: a CBZ will be produced.'**
  String get downloads_archive_unsupported;

  /// No description provided for @downloads_archive_label_folder.
  ///
  /// In en, this message translates to:
  /// **'Folder (images)'**
  String get downloads_archive_label_folder;

  /// No description provided for @downloads_swipe_pause_resume.
  ///
  /// In en, this message translates to:
  /// **'Pause / Resume'**
  String get downloads_swipe_pause_resume;

  /// No description provided for @downloads_swipe_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloads_swipe_cancel;

  /// No description provided for @downloads_swipe_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloads_swipe_delete;

  /// No description provided for @downloads_swipe_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloads_swipe_retry;

  /// No description provided for @downloads_swipe_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get downloads_swipe_disabled;

  /// No description provided for @downloads_open_folder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get downloads_open_folder;

  /// No description provided for @downloads_swipe_section.
  ///
  /// In en, this message translates to:
  /// **'Swipe actions'**
  String get downloads_swipe_section;

  /// No description provided for @queue_title.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get queue_title;

  /// No description provided for @queue_load_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load the download queue.'**
  String get queue_load_error;

  /// No description provided for @queue_unfinished.
  ///
  /// In en, this message translates to:
  /// **'Unfinished ({count})'**
  String queue_unfinished(Object count);

  /// No description provided for @queue_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get queue_manage;

  /// No description provided for @queue_empty_watch.
  ///
  /// In en, this message translates to:
  /// **'No Watch download'**
  String get queue_empty_watch;

  /// No description provided for @queue_empty_manga.
  ///
  /// In en, this message translates to:
  /// **'No Manga download'**
  String get queue_empty_manga;

  /// No description provided for @queue_empty_novel.
  ///
  /// In en, this message translates to:
  /// **'No Novel download'**
  String get queue_empty_novel;

  /// No description provided for @queue_empty_music.
  ///
  /// In en, this message translates to:
  /// **'No Music download'**
  String get queue_empty_music;

  /// No description provided for @queue_empty_game.
  ///
  /// In en, this message translates to:
  /// **'No Game download'**
  String get queue_empty_game;

  /// No description provided for @queue_download_canceled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get queue_download_canceled;

  /// No description provided for @queue_chapter_not_found.
  ///
  /// In en, this message translates to:
  /// **'Chapter not found.'**
  String get queue_chapter_not_found;

  /// No description provided for @queue_manage_downloads.
  ///
  /// In en, this message translates to:
  /// **'Manage downloads'**
  String get queue_manage_downloads;

  /// No description provided for @queue_settings_for.
  ///
  /// In en, this message translates to:
  /// **'{name} settings'**
  String queue_settings_for(Object name);

  /// No description provided for @queue_act_on_all.
  ///
  /// In en, this message translates to:
  /// **'Act on the whole queue'**
  String get queue_act_on_all;

  /// No description provided for @queue_stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get queue_stop;

  /// No description provided for @queue_simultaneous.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous'**
  String get queue_simultaneous;

  /// No description provided for @queue_simultaneous_help.
  ///
  /// In en, this message translates to:
  /// **'Number of parallel downloads per type and per source'**
  String get queue_simultaneous_help;

  /// No description provided for @queue_density_help.
  ///
  /// In en, this message translates to:
  /// **'Display density of the queue items'**
  String get queue_density_help;

  /// No description provided for @queue_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get queue_background;

  /// No description provided for @queue_continue_closed.
  ///
  /// In en, this message translates to:
  /// **'Keep going when the app is closed'**
  String get queue_continue_closed;

  /// No description provided for @queue_background_enabled.
  ///
  /// In en, this message translates to:
  /// **'Background downloading enabled'**
  String get queue_background_enabled;

  /// No description provided for @queue_clear_completed.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get queue_clear_completed;

  /// No description provided for @queue_clear_completed_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove finished items from the queue'**
  String get queue_clear_completed_subtitle;

  /// No description provided for @queue_completed_removed.
  ///
  /// In en, this message translates to:
  /// **'Completed items removed from the queue'**
  String get queue_completed_removed;

  /// No description provided for @queue_simultaneous_for.
  ///
  /// In en, this message translates to:
  /// **'Parallel downloads for {name}'**
  String queue_simultaneous_for(Object name);

  /// No description provided for @queue_connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get queue_connections;

  /// No description provided for @queue_connections_help.
  ///
  /// In en, this message translates to:
  /// **'Parallel connections per downloaded unit'**
  String get queue_connections_help;

  /// No description provided for @queue_segments_per_episode.
  ///
  /// In en, this message translates to:
  /// **'HLS segments per episode'**
  String get queue_segments_per_episode;

  /// No description provided for @queue_connections_per_chapter.
  ///
  /// In en, this message translates to:
  /// **'Connections per chapter'**
  String get queue_connections_per_chapter;

  /// No description provided for @queue_params_for.
  ///
  /// In en, this message translates to:
  /// **'{name} settings'**
  String queue_params_for(Object name);

  /// No description provided for @queue_delete_series.
  ///
  /// In en, this message translates to:
  /// **'Delete the series'**
  String get queue_delete_series;

  /// No description provided for @queue_resume_series.
  ///
  /// In en, this message translates to:
  /// **'Resume the series'**
  String get queue_resume_series;

  /// No description provided for @queue_pause_series.
  ///
  /// In en, this message translates to:
  /// **'Pause the series'**
  String get queue_pause_series;

  /// No description provided for @queue_pause_series_full.
  ///
  /// In en, this message translates to:
  /// **'Pause the series'**
  String get queue_pause_series_full;

  /// No description provided for @queue_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get queue_hide;

  /// No description provided for @queue_challenge_resolved.
  ///
  /// In en, this message translates to:
  /// **'Challenge solved — download resumed'**
  String get queue_challenge_resolved;

  /// No description provided for @queue_priority_high.
  ///
  /// In en, this message translates to:
  /// **'High priority enabled'**
  String get queue_priority_high;

  /// No description provided for @queue_priority_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal priority'**
  String get queue_priority_normal;

  /// No description provided for @queue_status_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queue_status_completed;

  /// No description provided for @queue_status_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get queue_status_failed;

  /// No description provided for @queue_status_canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get queue_status_canceled;

  /// No description provided for @queue_unit_chapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get queue_unit_chapter;

  /// No description provided for @queue_unit_episodes.
  ///
  /// In en, this message translates to:
  /// **'episodes'**
  String get queue_unit_episodes;

  /// No description provided for @queue_unit_chapters.
  ///
  /// In en, this message translates to:
  /// **'chapters'**
  String get queue_unit_chapters;

  /// No description provided for @queue_download_finished.
  ///
  /// In en, this message translates to:
  /// **'Download finished'**
  String get queue_download_finished;

  /// No description provided for @queue_received.
  ///
  /// In en, this message translates to:
  /// **'{size} received'**
  String queue_received(Object size);

  /// No description provided for @queue_transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get queue_transfer;

  /// No description provided for @queue_quick_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get queue_quick_actions;

  /// No description provided for @queue_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get queue_start;

  /// No description provided for @queue_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get queue_retry;

  /// No description provided for @queue_layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get queue_layout;

  /// No description provided for @queue_status_muxing.
  ///
  /// In en, this message translates to:
  /// **'Muxing'**
  String get queue_status_muxing;

  /// No description provided for @queue_status_compressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing'**
  String get queue_status_compressing;

  /// No description provided for @queue_status_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get queue_status_paused;

  /// No description provided for @queue_status_waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get queue_status_waiting;

  /// No description provided for @queue_cloudflare_challenge.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare challenge — {source}'**
  String queue_cloudflare_challenge(Object source);

  /// No description provided for @queue_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get queue_resume;

  /// No description provided for @queue_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get queue_pause;

  /// No description provided for @appearance_ui_title.
  ///
  /// In en, this message translates to:
  /// **'Interface & Effects'**
  String get appearance_ui_title;

  /// No description provided for @appearance_ui_section_ui.
  ///
  /// In en, this message translates to:
  /// **'UI & DISCOVERY'**
  String get appearance_ui_section_ui;

  /// No description provided for @appearance_ui_carousel_style.
  ///
  /// In en, this message translates to:
  /// **'Carousel style'**
  String get appearance_ui_carousel_style;

  /// No description provided for @appearance_ui_carousel_synopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis in the carousel'**
  String get appearance_ui_carousel_synopsis;

  /// No description provided for @appearance_ui_carousel_synopsis_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the description under the banner'**
  String get appearance_ui_carousel_synopsis_subtitle;

  /// No description provided for @appearance_ui_glow.
  ///
  /// In en, this message translates to:
  /// **'Glow effects'**
  String get appearance_ui_glow;

  /// No description provided for @appearance_ui_glow_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Bright shadows on the covers'**
  String get appearance_ui_glow_subtitle;

  /// No description provided for @appearance_ui_animated_bg.
  ///
  /// In en, this message translates to:
  /// **'Animated background (detail)'**
  String get appearance_ui_animated_bg;

  /// No description provided for @appearance_ui_animated_bg_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ken Burns effect on the detail banners'**
  String get appearance_ui_animated_bg_subtitle;

  /// No description provided for @appearance_ui_petals.
  ///
  /// In en, this message translates to:
  /// **'Falling petals'**
  String get appearance_ui_petals;

  /// No description provided for @appearance_ui_petals_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Discreet floral animation on the screens'**
  String get appearance_ui_petals_subtitle;

  /// No description provided for @appearance_ui_section_blur.
  ///
  /// In en, this message translates to:
  /// **'BLUR & GLASS'**
  String get appearance_ui_section_blur;

  /// No description provided for @appearance_ui_frosted_header.
  ///
  /// In en, this message translates to:
  /// **'Frosted header'**
  String get appearance_ui_frosted_header;

  /// No description provided for @appearance_ui_frosted_header_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Header blur while scrolling'**
  String get appearance_ui_frosted_header_subtitle;

  /// No description provided for @appearance_ui_frosted_sheets.
  ///
  /// In en, this message translates to:
  /// **'Frosted sheets'**
  String get appearance_ui_frosted_sheets;

  /// No description provided for @appearance_ui_frosted_sheets_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Background blur behind bottom sheets'**
  String get appearance_ui_frosted_sheets_subtitle;

  /// No description provided for @appearance_ui_blur_intensity.
  ///
  /// In en, this message translates to:
  /// **'Blur intensity'**
  String get appearance_ui_blur_intensity;

  /// No description provided for @appearance_ui_section_transitions.
  ///
  /// In en, this message translates to:
  /// **'TRANSITIONS & ANIMATIONS'**
  String get appearance_ui_section_transitions;

  /// No description provided for @appearance_ui_transition_style.
  ///
  /// In en, this message translates to:
  /// **'Transition style'**
  String get appearance_ui_transition_style;

  /// No description provided for @appearance_ui_carousel_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get appearance_ui_carousel_classic;

  /// No description provided for @appearance_ui_carousel_cinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get appearance_ui_carousel_cinematic;

  /// No description provided for @appearance_ui_carousel_compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get appearance_ui_carousel_compact;

  /// No description provided for @appearance_ui_transition_fade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get appearance_ui_transition_fade;

  /// No description provided for @appearance_ui_transition_slide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get appearance_ui_transition_slide;

  /// No description provided for @appearance_ui_transition_scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get appearance_ui_transition_scale;

  /// No description provided for @appearance_ui_transition_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get appearance_ui_transition_none;

  /// No description provided for @appearance_display_title.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get appearance_display_title;

  /// No description provided for @appearance_display_system_default.
  ///
  /// In en, this message translates to:
  /// **'System (default)'**
  String get appearance_display_system_default;

  /// No description provided for @appearance_display_date_format.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get appearance_display_date_format;

  /// No description provided for @appearance_display_relative_times.
  ///
  /// In en, this message translates to:
  /// **'Relative times'**
  String get appearance_display_relative_times;

  /// No description provided for @appearance_display_render_images.
  ///
  /// In en, this message translates to:
  /// **'Render images in manga descriptions'**
  String get appearance_display_render_images;

  /// No description provided for @appearance_font_picker.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get appearance_font_picker;

  /// No description provided for @appearance_font_search.
  ///
  /// In en, this message translates to:
  /// **'Search for a font…'**
  String get appearance_font_search;

  /// No description provided for @app_language_title.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get app_language_title;

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @general_section_network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get general_section_network;

  /// No description provided for @general_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get general_disabled;

  /// No description provided for @general_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get general_close;

  /// No description provided for @general_section_recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get general_section_recommendations;

  /// No description provided for @general_recommendations_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Algorithm, similarity and relevance weights'**
  String get general_recommendations_subtitle;

  /// No description provided for @general_section_activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get general_section_activity;

  /// No description provided for @general_system_default.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get general_system_default;

  /// No description provided for @general_doh_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypts your DNS requests so your carrier or network cannot see the sites you visit.'**
  String get general_doh_subtitle;

  /// No description provided for @general_user_agent_hint.
  ///
  /// In en, this message translates to:
  /// **'Open the site, copy your User-Agent, then paste it above.'**
  String get general_user_agent_hint;

  /// No description provided for @player_gestures_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Seek, double tap, controls'**
  String get player_gestures_subtitle;

  /// No description provided for @player_subtitles_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred languages, whitelist, blacklist'**
  String get player_subtitles_subtitle;

  /// No description provided for @player_script_editor_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit and create new scripts and script options'**
  String get player_script_editor_subtitle;

  /// No description provided for @player_torrent_subtitle.
  ///
  /// In en, this message translates to:
  /// **'TorrServer options'**
  String get player_torrent_subtitle;

  /// No description provided for @player_user_files_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom scripts, shaders and fonts'**
  String get player_user_files_subtitle;

  /// No description provided for @player_script_editor_title.
  ///
  /// In en, this message translates to:
  /// **'Script editor'**
  String get player_script_editor_title;

  /// No description provided for @player_gestures_title.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get player_gestures_title;

  /// No description provided for @player_double_tap_seek.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to seek'**
  String get player_double_tap_seek;

  /// No description provided for @player_double_tap_seek_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast-forward or rewind the video by double-tapping the sides'**
  String get player_double_tap_seek_subtitle;

  /// No description provided for @player_double_tap_duration.
  ///
  /// In en, this message translates to:
  /// **'Double-tap duration'**
  String get player_double_tap_duration;

  /// No description provided for @player_seconds.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String player_seconds(Object count);

  /// No description provided for @player_swipe_gestures.
  ///
  /// In en, this message translates to:
  /// **'Swipe gestures'**
  String get player_swipe_gestures;

  /// No description provided for @player_swipe_gestures_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Horizontal swipe to seek, vertical for volume and brightness'**
  String get player_swipe_gestures_subtitle;

  /// No description provided for @player_gesture_overlay.
  ///
  /// In en, this message translates to:
  /// **'Gesture overlay'**
  String get player_gesture_overlay;

  /// No description provided for @player_gesture_overlay_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows a preview during a gesture'**
  String get player_gesture_overlay_subtitle;

  /// No description provided for @player_center_double_tap.
  ///
  /// In en, this message translates to:
  /// **'Double-tap centre for play/pause'**
  String get player_center_double_tap;

  /// No description provided for @player_subtitles_title.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get player_subtitles_title;

  /// No description provided for @player_preferred_languages.
  ///
  /// In en, this message translates to:
  /// **'Preferred languages'**
  String get player_preferred_languages;

  /// No description provided for @player_whitelist.
  ///
  /// In en, this message translates to:
  /// **'Whitelist'**
  String get player_whitelist;

  /// No description provided for @player_whitelist_hint.
  ///
  /// In en, this message translates to:
  /// **'Filters to keep'**
  String get player_whitelist_hint;

  /// No description provided for @player_blacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get player_blacklist;

  /// No description provided for @player_blacklist_hint.
  ///
  /// In en, this message translates to:
  /// **'Filters to hide'**
  String get player_blacklist_hint;

  /// No description provided for @player_subtitle_text_size.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get player_subtitle_text_size;

  /// No description provided for @player_custom_buttons.
  ///
  /// In en, this message translates to:
  /// **'Custom buttons'**
  String get player_custom_buttons;

  /// No description provided for @player_custom_buttons_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and edit buttons that run lua code'**
  String get player_custom_buttons_subtitle;

  /// No description provided for @player_load_user_files.
  ///
  /// In en, this message translates to:
  /// **'Load user files'**
  String get player_load_user_files;

  /// No description provided for @player_load_user_files_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Runs the mpv scripts placed in the user folder'**
  String get player_load_user_files_subtitle;

  /// No description provided for @player_scripts_folder.
  ///
  /// In en, this message translates to:
  /// **'Scripts folder'**
  String get player_scripts_folder;

  /// No description provided for @player_not_defined.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get player_not_defined;

  /// No description provided for @player_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get player_not_configured;

  /// No description provided for @player_resume_last_position.
  ///
  /// In en, this message translates to:
  /// **'Resume at the last position'**
  String get player_resume_last_position;

  /// No description provided for @player_resume_last_position_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Resumes playback where it stopped'**
  String get player_resume_last_position_subtitle;

  /// No description provided for @player_ask_next_episode.
  ///
  /// In en, this message translates to:
  /// **'Ask for the next episode'**
  String get player_ask_next_episode;

  /// No description provided for @player_ask_next_episode_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows a prompt at the end of an episode'**
  String get player_ask_next_episode_subtitle;

  /// No description provided for @player_lock_landscape.
  ///
  /// In en, this message translates to:
  /// **'Lock landscape orientation while playing'**
  String get player_lock_landscape;

  /// No description provided for @player_decoder_mode.
  ///
  /// In en, this message translates to:
  /// **'Decoding mode'**
  String get player_decoder_mode;

  /// No description provided for @player_debanding.
  ///
  /// In en, this message translates to:
  /// **'Debanding'**
  String get player_debanding;

  /// No description provided for @player_debanding_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Improves interlaced videos'**
  String get player_debanding_subtitle;

  /// No description provided for @player_torrent_prebuffer.
  ///
  /// In en, this message translates to:
  /// **'Starts playback as soon as enough pieces are available'**
  String get player_torrent_prebuffer;

  /// No description provided for @player_keep_audio_channels.
  ///
  /// In en, this message translates to:
  /// **'Keep audio channels'**
  String get player_keep_audio_channels;

  /// No description provided for @player_keep_audio_channels_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Do not downmix to stereo'**
  String get player_keep_audio_channels_subtitle;

  /// No description provided for @player_load_user_assets.
  ///
  /// In en, this message translates to:
  /// **'Load scripts, shaders and fonts from the user folder'**
  String get player_load_user_assets;

  /// No description provided for @player_orientation_landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape orientation'**
  String get player_orientation_landscape;

  /// No description provided for @player_decoder_auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get player_decoder_auto;

  /// No description provided for @player_decoder_hw.
  ///
  /// In en, this message translates to:
  /// **'Hardware decoding'**
  String get player_decoder_hw;

  /// No description provided for @player_decoder_sw.
  ///
  /// In en, this message translates to:
  /// **'Software decoding'**
  String get player_decoder_sw;

  /// No description provided for @settings_search_in_settings.
  ///
  /// In en, this message translates to:
  /// **'Search in settings…'**
  String get settings_search_in_settings;

  /// No description provided for @settings_search_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settings_search_tooltip;

  /// No description provided for @settings_close_search.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get settings_close_search;

  /// No description provided for @settings_extensions_display.
  ///
  /// In en, this message translates to:
  /// **'Extensions display'**
  String get settings_extensions_display;

  /// No description provided for @settings_layout_list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get settings_layout_list;

  /// No description provided for @settings_layout_grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get settings_layout_grid;

  /// No description provided for @settings_layout_extended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get settings_layout_extended;

  /// No description provided for @settings_remote_server.
  ///
  /// In en, this message translates to:
  /// **'Remote server'**
  String get settings_remote_server;

  /// No description provided for @settings_remote_server_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your device to sync the library'**
  String get settings_remote_server_subtitle;

  /// No description provided for @media_filters_title.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get media_filters_title;

  /// No description provided for @media_filters_active.
  ///
  /// In en, this message translates to:
  /// **'Filters · {count} active'**
  String media_filters_active(Object count);

  /// No description provided for @media_clear_filters.
  ///
  /// In en, this message translates to:
  /// **'Remove filters'**
  String get media_clear_filters;

  /// No description provided for @media_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get media_apply;

  /// No description provided for @media_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get media_done;

  /// No description provided for @media_display_mode.
  ///
  /// In en, this message translates to:
  /// **'Display mode'**
  String get media_display_mode;

  /// No description provided for @media_items_per_row.
  ///
  /// In en, this message translates to:
  /// **'Items per row'**
  String get media_items_per_row;

  /// No description provided for @media_columns_count.
  ///
  /// In en, this message translates to:
  /// **'Number of columns'**
  String get media_columns_count;

  /// No description provided for @media_columns_n.
  ///
  /// In en, this message translates to:
  /// **'{count} columns'**
  String media_columns_n(Object count);

  /// No description provided for @media_columns_one.
  ///
  /// In en, this message translates to:
  /// **'1 column'**
  String get media_columns_one;

  /// No description provided for @media_automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get media_automatic;

  /// No description provided for @media_years.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get media_years;

  /// No description provided for @media_all_years.
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get media_all_years;

  /// No description provided for @media_genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get media_genres;

  /// No description provided for @media_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get media_rating;

  /// No description provided for @media_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get media_sort;

  /// No description provided for @media_search_option.
  ///
  /// In en, this message translates to:
  /// **'Search an option…'**
  String get media_search_option;

  /// No description provided for @media_search_page.
  ///
  /// In en, this message translates to:
  /// **'Search in this page…'**
  String get media_search_page;

  /// No description provided for @media_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get media_all;

  /// No description provided for @media_all_durations.
  ///
  /// In en, this message translates to:
  /// **'All durations'**
  String get media_all_durations;

  /// No description provided for @media_all_languages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get media_all_languages;

  /// No description provided for @media_all_qualities.
  ///
  /// In en, this message translates to:
  /// **'All qualities'**
  String get media_all_qualities;

  /// No description provided for @media_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get media_language;

  /// No description provided for @media_upper.
  ///
  /// In en, this message translates to:
  /// **'Upper'**
  String get media_upper;

  /// No description provided for @media_lower.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get media_lower;

  /// No description provided for @media_deselect_all.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get media_deselect_all;

  /// No description provided for @media_download_all.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get media_download_all;

  /// No description provided for @media_download_count.
  ///
  /// In en, this message translates to:
  /// **'Download {count} item(s)'**
  String media_download_count(Object count);

  /// No description provided for @media_download_selection.
  ///
  /// In en, this message translates to:
  /// **'Download selection ({count})'**
  String media_download_selection(Object count);

  /// No description provided for @media_custom_download.
  ///
  /// In en, this message translates to:
  /// **'Custom download'**
  String get media_custom_download;

  /// No description provided for @media_item_count.
  ///
  /// In en, this message translates to:
  /// **'Number of items'**
  String get media_item_count;

  /// No description provided for @media_enter_positive.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than zero.'**
  String get media_enter_positive;

  /// No description provided for @media_nothing_downloadable.
  ///
  /// In en, this message translates to:
  /// **'No downloadable item.'**
  String get media_nothing_downloadable;

  /// No description provided for @media_no_selection.
  ///
  /// In en, this message translates to:
  /// **'No video selected.'**
  String get media_no_selection;

  /// No description provided for @media_episodes_count.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String media_episodes_count(Object count);

  /// No description provided for @media_episode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get media_episode;

  /// No description provided for @media_episode_n.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String media_episode_n(Object number);

  /// No description provided for @media_ep_short.
  ///
  /// In en, this message translates to:
  /// **'Ep. {number}'**
  String media_ep_short(Object number);

  /// No description provided for @media_season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get media_season;

  /// No description provided for @media_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get media_series;

  /// No description provided for @media_tv_movie.
  ///
  /// In en, this message translates to:
  /// **'TV movie'**
  String get media_tv_movie;

  /// No description provided for @media_reality.
  ///
  /// In en, this message translates to:
  /// **'Reality TV'**
  String get media_reality;

  /// No description provided for @media_top_rated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get media_top_rated;

  /// No description provided for @media_new_releases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get media_new_releases;

  /// No description provided for @media_most_popular.
  ///
  /// In en, this message translates to:
  /// **'Most popular'**
  String get media_most_popular;

  /// No description provided for @media_top_10_week.
  ///
  /// In en, this message translates to:
  /// **'Top 10 this week'**
  String get media_top_10_week;

  /// No description provided for @media_discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get media_discover;

  /// No description provided for @media_watch_this_week.
  ///
  /// In en, this message translates to:
  /// **'Watch this week'**
  String get media_watch_this_week;

  /// No description provided for @media_watch_tonight.
  ///
  /// In en, this message translates to:
  /// **'Watch tonight'**
  String get media_watch_tonight;

  /// No description provided for @media_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get media_categories;

  /// No description provided for @media_no_result.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get media_no_result;

  /// No description provided for @media_no_result_filters.
  ///
  /// In en, this message translates to:
  /// **'No result for these filters'**
  String get media_no_result_filters;

  /// No description provided for @media_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load \$title right now.'**
  String get media_load_failed;

  /// No description provided for @media_no_summary.
  ///
  /// In en, this message translates to:
  /// **'No summary available.'**
  String get media_no_summary;

  /// No description provided for @media_no_synopsis.
  ///
  /// In en, this message translates to:
  /// **'No synopsis available.'**
  String get media_no_synopsis;

  /// No description provided for @media_no_similar.
  ///
  /// In en, this message translates to:
  /// **'No similar title available.'**
  String get media_no_similar;

  /// No description provided for @media_no_wallpaper.
  ///
  /// In en, this message translates to:
  /// **'No wallpaper available.'**
  String get media_no_wallpaper;

  /// No description provided for @media_no_episode.
  ///
  /// In en, this message translates to:
  /// **'No episode available.'**
  String get media_no_episode;

  /// No description provided for @media_no_comments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get media_no_comments;

  /// No description provided for @media_comments_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the comments.'**
  String get media_comments_load_failed;

  /// No description provided for @media_episodes_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the episodes.'**
  String get media_episodes_load_failed;

  /// No description provided for @media_people_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the cast.'**
  String get media_people_load_failed;

  /// No description provided for @media_details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get media_details;

  /// No description provided for @media_details_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Details unavailable.'**
  String get media_details_unavailable;

  /// No description provided for @media_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get media_duration;

  /// No description provided for @media_episode_duration.
  ///
  /// In en, this message translates to:
  /// **'Episode duration'**
  String get media_episode_duration;

  /// No description provided for @media_release_date.
  ///
  /// In en, this message translates to:
  /// **'Release date'**
  String get media_release_date;

  /// No description provided for @media_first_air_date.
  ///
  /// In en, this message translates to:
  /// **'First air date'**
  String get media_first_air_date;

  /// No description provided for @media_last_episode.
  ///
  /// In en, this message translates to:
  /// **'Last episode'**
  String get media_last_episode;

  /// No description provided for @media_original_language.
  ///
  /// In en, this message translates to:
  /// **'Original language'**
  String get media_original_language;

  /// No description provided for @media_spoken_languages.
  ///
  /// In en, this message translates to:
  /// **'Spoken languages'**
  String get media_spoken_languages;

  /// No description provided for @media_networks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get media_networks;

  /// No description provided for @media_created_by.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get media_created_by;

  /// No description provided for @media_where_to_watch.
  ///
  /// In en, this message translates to:
  /// **'Where to watch'**
  String get media_where_to_watch;

  /// No description provided for @media_popularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get media_popularity;

  /// No description provided for @media_add_to_list.
  ///
  /// In en, this message translates to:
  /// **'Add to my list'**
  String get media_add_to_list;

  /// No description provided for @media_watch_series.
  ///
  /// In en, this message translates to:
  /// **'Watch the series'**
  String get media_watch_series;

  /// No description provided for @media_watch_episodes.
  ///
  /// In en, this message translates to:
  /// **'Watch the episodes'**
  String get media_watch_episodes;

  /// No description provided for @media_watch_season.
  ///
  /// In en, this message translates to:
  /// **'Watch the season'**
  String get media_watch_season;

  /// No description provided for @media_view_all_languages.
  ///
  /// In en, this message translates to:
  /// **'View all languages'**
  String get media_view_all_languages;

  /// No description provided for @media_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get media_retry;

  /// No description provided for @media_loading_failed_retry.
  ///
  /// In en, this message translates to:
  /// **'Loading failed · Retry'**
  String get media_loading_failed_retry;

  /// No description provided for @media_prev_chapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get media_prev_chapter;

  /// No description provided for @media_next_chapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get media_next_chapter;

  /// No description provided for @media_next_episode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get media_next_episode;

  /// No description provided for @media_new_chapter.
  ///
  /// In en, this message translates to:
  /// **'New chapter'**
  String get media_new_chapter;

  /// No description provided for @media_next_chapter_soon.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get media_next_chapter_soon;

  /// No description provided for @media_latest_releases.
  ///
  /// In en, this message translates to:
  /// **'Latest releases'**
  String get media_latest_releases;

  /// No description provided for @media_release_calendar.
  ///
  /// In en, this message translates to:
  /// **'Release calendar'**
  String get media_release_calendar;

  /// No description provided for @media_recent_results.
  ///
  /// In en, this message translates to:
  /// **'Recent results'**
  String get media_recent_results;

  /// No description provided for @media_resume_reading.
  ///
  /// In en, this message translates to:
  /// **'Resume reading'**
  String get media_resume_reading;

  /// No description provided for @media_quick_access.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get media_quick_access;

  /// No description provided for @media_reader_settings.
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get media_reader_settings;

  /// No description provided for @media_brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get media_brightness;

  /// No description provided for @media_volumes_preview.
  ///
  /// In en, this message translates to:
  /// **'Volumes preview'**
  String get media_volumes_preview;

  /// No description provided for @media_upcoming_volumes.
  ///
  /// In en, this message translates to:
  /// **'Upcoming volumes'**
  String get media_upcoming_volumes;

  /// No description provided for @media_other_works.
  ///
  /// In en, this message translates to:
  /// **'Other works in the universe'**
  String get media_other_works;

  /// No description provided for @media_editions_by_language.
  ///
  /// In en, this message translates to:
  /// **'Editions by language'**
  String get media_editions_by_language;

  /// No description provided for @media_universe_by_country.
  ///
  /// In en, this message translates to:
  /// **'Universe by country / language'**
  String get media_universe_by_country;

  /// No description provided for @media_trailers.
  ///
  /// In en, this message translates to:
  /// **'Trailers and videos'**
  String get media_trailers;

  /// No description provided for @media_video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get media_video;

  /// No description provided for @media_soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get media_soon;

  /// No description provided for @media_tv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get media_tv;

  /// No description provided for @media_announced.
  ///
  /// In en, this message translates to:
  /// **'Announced'**
  String get media_announced;

  /// No description provided for @media_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get media_cancelled;

  /// No description provided for @media_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get media_completed;

  /// No description provided for @media_dropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get media_dropped;

  /// No description provided for @media_status_ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get media_status_ongoing;

  /// No description provided for @media_available_channels.
  ///
  /// In en, this message translates to:
  /// **'Available channels'**
  String get media_available_channels;

  /// No description provided for @media_open_channel_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the channel'**
  String get media_open_channel_failed;

  /// No description provided for @media_world_channels.
  ///
  /// In en, this message translates to:
  /// **'Access the official channel pages from Watchtower.'**
  String get media_world_channels;

  /// No description provided for @media_world_content.
  ///
  /// In en, this message translates to:
  /// **'Explore content from around the world.'**
  String get media_world_content;

  /// No description provided for @media_european_news.
  ///
  /// In en, this message translates to:
  /// **'European news'**
  String get media_european_news;

  /// No description provided for @media_international_news.
  ///
  /// In en, this message translates to:
  /// **'International news'**
  String get media_international_news;

  /// No description provided for @media_no_network.
  ///
  /// In en, this message translates to:
  /// **'No network connection'**
  String get media_no_network;

  /// No description provided for @media_connect_internet.
  ///
  /// In en, this message translates to:
  /// **'Connect to the Internet to load \$title.'**
  String get media_connect_internet;

  /// No description provided for @media_check_connection.
  ///
  /// In en, this message translates to:
  /// **'Check your Wi-Fi or mobile data.'**
  String get media_check_connection;

  /// No description provided for @media_catalog_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the catalogue. Try again later.'**
  String get media_catalog_load_failed;

  /// No description provided for @media_hub_unavailable.
  ///
  /// In en, this message translates to:
  /// **'\$title is temporarily unavailable'**
  String get media_hub_unavailable;

  /// No description provided for @media_refine_with_tags.
  ///
  /// In en, this message translates to:
  /// **'Refine your search with the tags.'**
  String get media_refine_with_tags;

  /// No description provided for @media_find_favourite_genres.
  ///
  /// In en, this message translates to:
  /// **'Find your favourite genres.'**
  String get media_find_favourite_genres;

  /// No description provided for @media_personalise_reading.
  ///
  /// In en, this message translates to:
  /// **'Personalise your reading experience.'**
  String get media_personalise_reading;

  /// No description provided for @media_resume_where_left.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off.'**
  String get media_resume_where_left;

  /// No description provided for @media_official_manga.
  ///
  /// In en, this message translates to:
  /// **'Official manga available on legal platforms.'**
  String get media_official_manga;

  /// No description provided for @media_no_badge.
  ///
  /// In en, this message translates to:
  /// **'No badge published by this source.'**
  String get media_no_badge;

  /// No description provided for @media_remind_me.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get media_remind_me;

  /// No description provided for @media_computing_size.
  ///
  /// In en, this message translates to:
  /// **'Computing size…'**
  String get media_computing_size;

  /// No description provided for @media_fetching_formats.
  ///
  /// In en, this message translates to:
  /// **'Fetching formats…'**
  String get media_fetching_formats;

  /// No description provided for @media_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get media_background;

  /// No description provided for @media_collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get media_collapse;

  /// No description provided for @media_expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get media_expand;

  /// No description provided for @media_videos_processed.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} videos processed'**
  String media_videos_processed(Object done, Object total);

  /// No description provided for @media_videos_selected.
  ///
  /// In en, this message translates to:
  /// **'{total} videos · {size}'**
  String media_videos_selected(Object size, Object total);

  /// No description provided for @media_selection_mode.
  ///
  /// In en, this message translates to:
  /// **'Multiple selection'**
  String get media_selection_mode;

  /// No description provided for @media_finish_selection.
  ///
  /// In en, this message translates to:
  /// **'Finish selection'**
  String get media_finish_selection;

  /// No description provided for @media_quality_all.
  ///
  /// In en, this message translates to:
  /// **'Quality (all)'**
  String get media_quality_all;

  /// No description provided for @media_language_all.
  ///
  /// In en, this message translates to:
  /// **'Language (all)'**
  String get media_language_all;

  /// No description provided for @media_in_5_min.
  ///
  /// In en, this message translates to:
  /// **'In 5 min'**
  String get media_in_5_min;

  /// No description provided for @media_quick_summary.
  ///
  /// In en, this message translates to:
  /// **'Quick summary'**
  String get media_quick_summary;

  /// No description provided for @media_summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get media_summary;

  /// No description provided for @media_creator.
  ///
  /// In en, this message translates to:
  /// **'Creator:'**
  String get media_creator;

  /// No description provided for @media_read_direction.
  ///
  /// In en, this message translates to:
  /// **'Panel reading direction.'**
  String get media_read_direction;

  /// No description provided for @media_official_badge.
  ///
  /// In en, this message translates to:
  /// **'SERIES'**
  String get media_official_badge;

  /// No description provided for @media_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get media_recent;

  /// No description provided for @media_bulk_download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get media_bulk_download;

  /// No description provided for @media_show_more.
  ///
  /// In en, this message translates to:
  /// **'Show more ({count} left)'**
  String media_show_more(Object count);

  /// No description provided for @media_comment_video.
  ///
  /// In en, this message translates to:
  /// **'Comment video'**
  String get media_comment_video;

  /// No description provided for @media_replies.
  ///
  /// In en, this message translates to:
  /// **'{count} replies'**
  String media_replies(Object count);

  /// No description provided for @media_videos_count.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String media_videos_count(Object count);

  /// No description provided for @media_elements_count.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String media_elements_count(Object count);

  /// No description provided for @media_element_n.
  ///
  /// In en, this message translates to:
  /// **'Item {number}'**
  String media_element_n(Object number);

  /// No description provided for @media_queue_added.
  ///
  /// In en, this message translates to:
  /// **'Downloads added to the queue: '**
  String get media_queue_added;

  /// No description provided for @media_queue_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled · {queued} added, '**
  String media_queue_cancelled(Object queued);

  /// No description provided for @media_queue_failed.
  ///
  /// In en, this message translates to:
  /// **'{failed} failed, {remaining} remaining.'**
  String media_queue_failed(Object failed, Object remaining);

  /// No description provided for @media_series_suffix.
  ///
  /// In en, this message translates to:
  /// **'series'**
  String get media_series_suffix;

  /// No description provided for @media_february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get media_february;

  /// No description provided for @media_august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get media_august;

  /// No description provided for @media_december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get media_december;

  /// No description provided for @media_comedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get media_comedy;

  /// No description provided for @media_already_downloaded_hidden.
  ///
  /// In en, this message translates to:
  /// **'already downloaded hidden'**
  String get media_already_downloaded_hidden;

  /// No description provided for @media_first_card.
  ///
  /// In en, this message translates to:
  /// **'first card'**
  String get media_first_card;

  /// No description provided for @media_censored_hint.
  ///
  /// In en, this message translates to:
  /// **'Whether the video is censored, uncensored or leaked.'**
  String get media_censored_hint;

  /// No description provided for @media_audio_language_hint.
  ///
  /// In en, this message translates to:
  /// **'Video language'**
  String get media_audio_language_hint;

  /// No description provided for @media_country_flag_hint.
  ///
  /// In en, this message translates to:
  /// **'Flag of the country associated with the published language.'**
  String get media_country_flag_hint;

  /// No description provided for @media_subtitle_flag_hint.
  ///
  /// In en, this message translates to:
  /// **'Flag of the available subtitle language.'**
  String get media_subtitle_flag_hint;

  /// No description provided for @media_dub_flag_hint.
  ///
  /// In en, this message translates to:
  /// **'Flag of the available dub language.'**
  String get media_dub_flag_hint;

  /// No description provided for @media_platforms.
  ///
  /// In en, this message translates to:
  /// **'See platforms'**
  String get media_platforms;

  /// No description provided for @media_stats.
  ///
  /// In en, this message translates to:
  /// **'See statistics'**
  String get media_stats;

  /// No description provided for @media_teams.
  ///
  /// In en, this message translates to:
  /// **'See all teams'**
  String get media_teams;

  /// No description provided for @media_collection.
  ///
  /// In en, this message translates to:
  /// **'See the collection'**
  String get media_collection;

  /// No description provided for @media_list.
  ///
  /// In en, this message translates to:
  /// **'See the list'**
  String get media_list;

  /// No description provided for @media_more_like.
  ///
  /// In en, this message translates to:
  /// **'Top 20 series like Superman…'**
  String get media_more_like;

  /// No description provided for @media_all_chapters.
  ///
  /// In en, this message translates to:
  /// **'All chapters'**
  String get media_all_chapters;

  /// No description provided for @media_episode_count.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String media_episode_count(Object count);

  /// No description provided for @media_episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get media_episodes;

  /// No description provided for @media_grid_comfortable.
  ///
  /// In en, this message translates to:
  /// **'Spaced grid'**
  String get media_grid_comfortable;

  /// No description provided for @media_grid_compact.
  ///
  /// In en, this message translates to:
  /// **'Compact grid'**
  String get media_grid_compact;

  /// No description provided for @media_grid_cover_only.
  ///
  /// In en, this message translates to:
  /// **'Cover-only grid'**
  String get media_grid_cover_only;

  /// No description provided for @media_download_nb.
  ///
  /// In en, this message translates to:
  /// **'Download nb'**
  String get media_download_nb;

  /// No description provided for @media_badge_language.
  ///
  /// In en, this message translates to:
  /// **'Video language'**
  String get media_badge_language;

  /// No description provided for @media_download_failed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get media_download_failed;

  /// No description provided for @media_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get media_classic;

  /// No description provided for @media_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get media_type;

  /// No description provided for @media_text_filter_hint.
  ///
  /// In en, this message translates to:
  /// **'Type…'**
  String get media_text_filter_hint;

  /// No description provided for @media_love_shows.
  ///
  /// In en, this message translates to:
  /// **'Love shows'**
  String get media_love_shows;

  /// No description provided for @media_talk_shows.
  ///
  /// In en, this message translates to:
  /// **'Talk shows'**
  String get media_talk_shows;

  /// No description provided for @media_extension_only.
  ///
  /// In en, this message translates to:
  /// **'Download only available for extension catalogues.'**
  String get media_extension_only;

  /// No description provided for @media_status_paused.
  ///
  /// In en, this message translates to:
  /// **'On hiatus'**
  String get media_status_paused;

  /// No description provided for @media_queue_queued.
  ///
  /// In en, this message translates to:
  /// **'{count} download(s) queued, '**
  String media_queue_queued(Object count);

  /// No description provided for @media_queue_failed_short.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String media_queue_failed_short(Object count);

  /// No description provided for @media_anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get media_anime;

  /// No description provided for @media_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get media_manga;

  /// No description provided for @media_movie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get media_movie;

  /// No description provided for @media_animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get media_animation;

  /// No description provided for @media_documentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get media_documentary;

  /// No description provided for @media_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get media_popular;

  /// No description provided for @media_trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get media_trending;

  /// No description provided for @media_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get media_favorites;

  /// No description provided for @media_a_z.
  ///
  /// In en, this message translates to:
  /// **'A — Z'**
  String get media_a_z;

  /// No description provided for @media_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get media_options;

  /// No description provided for @media_selection.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get media_selection;

  /// No description provided for @media_remove_from_list.
  ///
  /// In en, this message translates to:
  /// **'Remove from my list'**
  String get media_remove_from_list;

  /// No description provided for @media_similar.
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get media_similar;

  /// No description provided for @media_media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media_media;

  /// No description provided for @media_read_more.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get media_read_more;

  /// No description provided for @media_see_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get media_see_all;

  /// No description provided for @media_wallpapers_count.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers ({count})'**
  String media_wallpapers_count(Object count);

  /// No description provided for @media_no_trailer.
  ///
  /// In en, this message translates to:
  /// **'No trailer available.'**
  String get media_no_trailer;

  /// No description provided for @media_information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get media_information;

  /// No description provided for @media_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get media_title;

  /// No description provided for @media_original_title.
  ///
  /// In en, this message translates to:
  /// **'Original title'**
  String get media_original_title;

  /// No description provided for @media_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get media_format;

  /// No description provided for @media_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get media_status;

  /// No description provided for @media_seasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get media_seasons;

  /// No description provided for @media_origin_countries.
  ///
  /// In en, this message translates to:
  /// **'Origin countries'**
  String get media_origin_countries;

  /// No description provided for @media_votes_tmdb.
  ///
  /// In en, this message translates to:
  /// **'TMDB votes'**
  String get media_votes_tmdb;

  /// No description provided for @media_rating_tmdb.
  ///
  /// In en, this message translates to:
  /// **'TMDB rating'**
  String get media_rating_tmdb;

  /// No description provided for @media_budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get media_budget;

  /// No description provided for @media_revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get media_revenue;

  /// No description provided for @media_in_production.
  ///
  /// In en, this message translates to:
  /// **'In production'**
  String get media_in_production;

  /// No description provided for @media_official_site.
  ///
  /// In en, this message translates to:
  /// **'Official site'**
  String get media_official_site;

  /// No description provided for @media_countries.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get media_countries;

  /// No description provided for @media_production.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get media_production;

  /// No description provided for @media_released.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get media_released;

  /// No description provided for @media_status_ongoing2.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get media_status_ongoing2;

  /// No description provided for @media_load_title_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this page'**
  String get media_load_title_failed;

  /// No description provided for @media_retry_when_online.
  ///
  /// In en, this message translates to:
  /// **'Try again when the connection is available.'**
  String get media_retry_when_online;

  /// No description provided for @media_cast_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the cast.'**
  String get media_cast_load_failed;

  /// No description provided for @media_load_page_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this page.'**
  String get media_load_page_failed;

  /// No description provided for @media_series_lower.
  ///
  /// In en, this message translates to:
  /// **'series'**
  String get media_series_lower;

  /// No description provided for @media_no_video_filter.
  ///
  /// In en, this message translates to:
  /// **'No video matches the filter.'**
  String get media_no_video_filter;

  /// No description provided for @media_load_failed_retry.
  ///
  /// In en, this message translates to:
  /// **'Load failed · Retry'**
  String get media_load_failed_retry;

  /// No description provided for @media_job.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get media_job;

  /// No description provided for @media_as.
  ///
  /// In en, this message translates to:
  /// **'As'**
  String get media_as;

  /// No description provided for @media_born_on.
  ///
  /// In en, this message translates to:
  /// **'Born on'**
  String get media_born_on;

  /// No description provided for @media_age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get media_age;

  /// No description provided for @media_from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get media_from;

  /// No description provided for @media_films.
  ///
  /// In en, this message translates to:
  /// **'movies'**
  String get media_films;

  /// No description provided for @media_videos_loaded.
  ///
  /// In en, this message translates to:
  /// **'{loaded} / {total} videos{more}'**
  String media_videos_loaded(Object loaded, Object more, Object total);

  /// No description provided for @media_see_all_arrow.
  ///
  /// In en, this message translates to:
  /// **'All >'**
  String get media_see_all_arrow;

  /// No description provided for @media_weight_calculating.
  ///
  /// In en, this message translates to:
  /// **'Computing size…'**
  String get media_weight_calculating;

  /// No description provided for @media_weight_known.
  ///
  /// In en, this message translates to:
  /// **'Computing · {size} known'**
  String media_weight_known(Object size);

  /// No description provided for @media_weight_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Size unavailable'**
  String get media_weight_unavailable;

  /// No description provided for @media_weight_partial.
  ///
  /// In en, this message translates to:
  /// **'{size} known · partial estimate'**
  String media_weight_partial(Object size);

  /// No description provided for @media_weight_total.
  ///
  /// In en, this message translates to:
  /// **'≈ {size} total'**
  String media_weight_total(Object size);

  /// No description provided for @media_no_video_selected.
  ///
  /// In en, this message translates to:
  /// **'No video selected.'**
  String get media_no_video_selected;

  /// No description provided for @media_download_n_videos.
  ///
  /// In en, this message translates to:
  /// **'Download {count} video(s)'**
  String media_download_n_videos(Object count);

  /// No description provided for @media_auto_best.
  ///
  /// In en, this message translates to:
  /// **'Auto (best)'**
  String get media_auto_best;

  /// No description provided for @media_if_missing.
  ///
  /// In en, this message translates to:
  /// **'If missing'**
  String get media_if_missing;

  /// No description provided for @media_higher.
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get media_higher;

  /// No description provided for @media_exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get media_exact;

  /// No description provided for @media_formats_loading.
  ///
  /// In en, this message translates to:
  /// **'Fetching formats…'**
  String get media_formats_loading;

  /// No description provided for @media_format_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Format unavailable'**
  String get media_format_unavailable;

  /// No description provided for @media_all_fem.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get media_all_fem;

  /// No description provided for @media_uncheck_all.
  ///
  /// In en, this message translates to:
  /// **'Uncheck all'**
  String get media_uncheck_all;

  /// No description provided for @media_check_all.
  ///
  /// In en, this message translates to:
  /// **'Check all'**
  String get media_check_all;

  /// No description provided for @media_episodes_ratio.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} episodes'**
  String media_episodes_ratio(Object selected, Object total);

  /// No description provided for @media_one_video.
  ///
  /// In en, this message translates to:
  /// **'1 video'**
  String get media_one_video;

  /// No description provided for @media_fetching_parallel.
  ///
  /// In en, this message translates to:
  /// **'Fetching in parallel · {count} items'**
  String media_fetching_parallel(Object count);

  /// No description provided for @media_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching · {count} items'**
  String media_fetching(Object count);

  /// No description provided for @media_n_videos_size.
  ///
  /// In en, this message translates to:
  /// **'{count} videos · {size}'**
  String media_n_videos_size(Object count, Object size);

  /// No description provided for @media_comments_count.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String media_comments_count(Object count);

  /// No description provided for @media_best.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get media_best;

  /// No description provided for @media_no_comment.
  ///
  /// In en, this message translates to:
  /// **'No comment yet.'**
  String get media_no_comment;

  /// No description provided for @media_replies_count.
  ///
  /// In en, this message translates to:
  /// **'{count} reply(ies)'**
  String media_replies_count(Object count);

  /// No description provided for @media_replies_hidden.
  ///
  /// In en, this message translates to:
  /// **'{count} hidden reply(ies)'**
  String media_replies_hidden(Object count);

  /// No description provided for @media_chapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get media_chapter;

  /// No description provided for @media_see_list.
  ///
  /// In en, this message translates to:
  /// **'See the list'**
  String get media_see_list;

  /// No description provided for @media_reading_direction.
  ///
  /// In en, this message translates to:
  /// **'Page reading direction.'**
  String get media_reading_direction;

  /// No description provided for @media_reader_settings_sub.
  ///
  /// In en, this message translates to:
  /// **'Customise your reading experience.'**
  String get media_reader_settings_sub;

  /// No description provided for @media_previous_chapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get media_previous_chapter;

  /// No description provided for @media_next_chapter_alt.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get media_next_chapter_alt;

  /// No description provided for @media_reading_direction_label.
  ///
  /// In en, this message translates to:
  /// **'Reading direction'**
  String get media_reading_direction_label;

  /// No description provided for @media_see_episodes.
  ///
  /// In en, this message translates to:
  /// **'See the episodes'**
  String get media_see_episodes;

  /// No description provided for @media_see_series.
  ///
  /// In en, this message translates to:
  /// **'See the series'**
  String get media_see_series;

  /// No description provided for @media_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get media_share;

  /// No description provided for @media_director_colon.
  ///
  /// In en, this message translates to:
  /// **'Director: '**
  String get media_director_colon;

  /// No description provided for @marketplace_official.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get marketplace_official;

  /// No description provided for @marketplace_third_party.
  ///
  /// In en, this message translates to:
  /// **'Third-party'**
  String get marketplace_third_party;

  /// No description provided for @marketplace_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get marketplace_sign_in;

  /// No description provided for @marketplace_connect_title.
  ///
  /// In en, this message translates to:
  /// **'Connection — {name}'**
  String marketplace_connect_title(Object name);

  /// No description provided for @marketplace_plugin_kind_music.
  ///
  /// In en, this message translates to:
  /// **'Music plugin'**
  String get marketplace_plugin_kind_music;

  /// No description provided for @marketplace_topic_metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get marketplace_topic_metadata;

  /// No description provided for @marketplace_topic_audio_source.
  ///
  /// In en, this message translates to:
  /// **'Audio Source'**
  String get marketplace_topic_audio_source;

  /// No description provided for @watch_home_layout_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This extension\'s layout is unavailable.'**
  String get watch_home_layout_unavailable;

  /// No description provided for @watch_home_layout_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the layout: {error}'**
  String watch_home_layout_save_failed(Object error);

  /// No description provided for @watch_home_layout_not_saved.
  ///
  /// In en, this message translates to:
  /// **'The layout could not be saved.'**
  String get watch_home_layout_not_saved;

  /// No description provided for @watch_home_hold_section_first.
  ///
  /// In en, this message translates to:
  /// **'Hold a section first, then pick “Replace”.'**
  String get watch_home_hold_section_first;

  /// No description provided for @watch_home_section_gone.
  ///
  /// In en, this message translates to:
  /// **'This section no longer exists in the layout.'**
  String get watch_home_section_gone;

  /// No description provided for @watch_home_episode_card_incompatible.
  ///
  /// In en, this message translates to:
  /// **'This episode card is not compatible with this selection.'**
  String get watch_home_episode_card_incompatible;

  /// No description provided for @watch_home_episode_card_grid_only.
  ///
  /// In en, this message translates to:
  /// **'Custom episode cards are available on grid sections.'**
  String get watch_home_episode_card_grid_only;

  /// No description provided for @watch_home_chapter_card_incompatible.
  ///
  /// In en, this message translates to:
  /// **'This chapter card is not compatible with this selection.'**
  String get watch_home_chapter_card_incompatible;

  /// No description provided for @watch_home_chapter_card_grid_only.
  ///
  /// In en, this message translates to:
  /// **'Custom chapter cards are available on grid sections.'**
  String get watch_home_chapter_card_grid_only;

  /// No description provided for @watch_home_manga_card_incompatible.
  ///
  /// In en, this message translates to:
  /// **'This Manga card is not compatible with this selection.'**
  String get watch_home_manga_card_incompatible;

  /// No description provided for @watch_home_manga_card_grid_only.
  ///
  /// In en, this message translates to:
  /// **'Custom Manga cards are available on grid sections.'**
  String get watch_home_manga_card_grid_only;

  /// No description provided for @watch_home_preview_refresh_failed.
  ///
  /// In en, this message translates to:
  /// **'Layout saved, but the preview could not be refreshed: {error}'**
  String watch_home_preview_refresh_failed(Object error);

  /// No description provided for @watch_home_no_video_in_playlist.
  ///
  /// In en, this message translates to:
  /// **'No video available in this playlist.'**
  String get watch_home_no_video_in_playlist;

  /// No description provided for @watch_home_playlist_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the playlist: {error}'**
  String watch_home_playlist_load_failed(Object error);

  /// No description provided for @watch_home_default_poster.
  ///
  /// In en, this message translates to:
  /// **'Standard poster'**
  String get watch_home_default_poster;

  /// No description provided for @watch_home_default_card.
  ///
  /// In en, this message translates to:
  /// **'Default card'**
  String get watch_home_default_card;

  /// No description provided for @watch_home_section_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions on this section'**
  String get watch_home_section_actions;

  /// No description provided for @watch_home_move_up.
  ///
  /// In en, this message translates to:
  /// **'Move one level up'**
  String get watch_home_move_up;

  /// No description provided for @watch_home_move_down.
  ///
  /// In en, this message translates to:
  /// **'Move one level down'**
  String get watch_home_move_down;

  /// No description provided for @watch_home_replace_component.
  ///
  /// In en, this message translates to:
  /// **'Replace the component'**
  String get watch_home_replace_component;

  /// No description provided for @watch_home_manga_card_style.
  ///
  /// In en, this message translates to:
  /// **'Manga card style'**
  String get watch_home_manga_card_style;

  /// No description provided for @watch_home_episode_card_style.
  ///
  /// In en, this message translates to:
  /// **'Episode card style'**
  String get watch_home_episode_card_style;

  /// No description provided for @watch_home_chapter_card_style.
  ///
  /// In en, this message translates to:
  /// **'Chapter card style'**
  String get watch_home_chapter_card_style;

  /// No description provided for @watch_home_current_value.
  ///
  /// In en, this message translates to:
  /// **'Current: {value}'**
  String watch_home_current_value(Object value);

  /// No description provided for @watch_home_delete_section.
  ///
  /// In en, this message translates to:
  /// **'Delete the section'**
  String get watch_home_delete_section;

  /// No description provided for @watch_home_delete_section_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this section?'**
  String get watch_home_delete_section_title;

  /// No description provided for @watch_home_delete_section_body.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from this home.'**
  String watch_home_delete_section_body(Object title);

  /// No description provided for @watch_home_no_section.
  ///
  /// In en, this message translates to:
  /// **'No section. Use the JSON editor to create one.'**
  String get watch_home_no_section;

  /// No description provided for @watch_home_hold_to_edit.
  ///
  /// In en, this message translates to:
  /// **'Hold to edit'**
  String get watch_home_hold_to_edit;

  /// No description provided for @watch_home_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get watch_home_home;

  /// No description provided for @watch_home_component_gallery.
  ///
  /// In en, this message translates to:
  /// **'Component gallery'**
  String get watch_home_component_gallery;

  /// No description provided for @watch_home_json_editor.
  ///
  /// In en, this message translates to:
  /// **'JSON editor'**
  String get watch_home_json_editor;

  /// No description provided for @watch_home_close_edit_dock.
  ///
  /// In en, this message translates to:
  /// **'Close the edit dock'**
  String get watch_home_close_edit_dock;

  /// No description provided for @watch_home_open_edit_dock.
  ///
  /// In en, this message translates to:
  /// **'Open the edit dock'**
  String get watch_home_open_edit_dock;

  /// No description provided for @watch_home_choose_month.
  ///
  /// In en, this message translates to:
  /// **'Choose a month'**
  String get watch_home_choose_month;

  /// No description provided for @watch_home_source_unavailable.
  ///
  /// In en, this message translates to:
  /// **'The source is temporarily unavailable.'**
  String get watch_home_source_unavailable;

  /// No description provided for @watch_home_no_content.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get watch_home_no_content;

  /// No description provided for @watch_home_extension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get watch_home_extension;

  /// No description provided for @watch_home_search_in_source.
  ///
  /// In en, this message translates to:
  /// **'Search in {source}'**
  String watch_home_search_in_source(Object source);

  /// No description provided for @watch_home_search_in_extension.
  ///
  /// In en, this message translates to:
  /// **'Search in the extension'**
  String get watch_home_search_in_extension;

  /// No description provided for @watch_home_search_video_hint.
  ///
  /// In en, this message translates to:
  /// **'Search for a video in this extension'**
  String get watch_home_search_video_hint;

  /// No description provided for @watch_home_search_failed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get watch_home_search_failed;

  /// No description provided for @watch_home_reel_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get watch_home_reel_follow;

  /// No description provided for @watch_home_reel_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get watch_home_reel_following;

  /// No description provided for @watch_home_reel_like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get watch_home_reel_like;

  /// No description provided for @watch_home_reel_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get watch_home_reel_comments;

  /// No description provided for @watch_home_reel_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get watch_home_reel_share;

  /// No description provided for @watch_home_reel_no_comment.
  ///
  /// In en, this message translates to:
  /// **'No comment yet.'**
  String get watch_home_reel_no_comment;

  /// No description provided for @watch_home_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get watch_home_search;

  /// No description provided for @watch_home_collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get watch_home_collection;

  /// No description provided for @watch_home_no_episode_from_source.
  ///
  /// In en, this message translates to:
  /// **'No numbered episode with a valid URL was provided by this source.'**
  String get watch_home_no_episode_from_source;

  /// No description provided for @watch_home_preview_search_unavailable.
  ///
  /// In en, this message translates to:
  /// **'The preview search is temporarily unavailable.'**
  String get watch_home_preview_search_unavailable;

  /// No description provided for @watch_home_search_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Search unavailable'**
  String get watch_home_search_unavailable;

  /// No description provided for @watch_home_search_source_unavailable.
  ///
  /// In en, this message translates to:
  /// **'The source is temporarily unavailable. Retry in a moment.'**
  String get watch_home_search_source_unavailable;

  /// No description provided for @watch_home_nothing_matches_query.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String watch_home_nothing_matches_query(Object query);

  /// No description provided for @watch_home_no_chapter_from_source.
  ///
  /// In en, this message translates to:
  /// **'No chapter with a valid title and URL was provided by this source.'**
  String get watch_home_no_chapter_from_source;

  /// No description provided for @source_err_access_denied_http.
  ///
  /// In en, this message translates to:
  /// **'Access denied (HTTP {code})'**
  String source_err_access_denied_http(Object code);

  /// No description provided for @source_err_not_found_http.
  ///
  /// In en, this message translates to:
  /// **'Not found (HTTP {code})'**
  String source_err_not_found_http(Object code);

  /// No description provided for @source_err_rate_limited_http.
  ///
  /// In en, this message translates to:
  /// **'Too many requests (HTTP {code})'**
  String source_err_rate_limited_http(Object code);

  /// No description provided for @source_err_server_http.
  ///
  /// In en, this message translates to:
  /// **'Server error (HTTP {code})'**
  String source_err_server_http(Object code);

  /// No description provided for @source_err_http.
  ///
  /// In en, this message translates to:
  /// **'HTTP error {code}'**
  String source_err_http(Object code);

  /// No description provided for @source_err_access_blocked.
  ///
  /// In en, this message translates to:
  /// **'Access blocked'**
  String get source_err_access_blocked;

  /// No description provided for @source_err_access_blocked_http.
  ///
  /// In en, this message translates to:
  /// **'Access blocked (HTTP {code})'**
  String source_err_access_blocked_http(Object code);

  /// No description provided for @source_err_verification_required.
  ///
  /// In en, this message translates to:
  /// **'Verification required'**
  String get source_err_verification_required;

  /// No description provided for @source_err_verification_required_http.
  ///
  /// In en, this message translates to:
  /// **'Verification required (HTTP {code})'**
  String source_err_verification_required_http(Object code);

  /// No description provided for @source_err_connection_dropped.
  ///
  /// In en, this message translates to:
  /// **'Connection dropped'**
  String get source_err_connection_dropped;

  /// No description provided for @source_err_check_network.
  ///
  /// In en, this message translates to:
  /// **'Check your network'**
  String get source_err_check_network;

  /// No description provided for @source_err_access_denied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get source_err_access_denied;

  /// No description provided for @source_err_no_content.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get source_err_no_content;

  /// No description provided for @source_err_cloudflare_required.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare verification required'**
  String get source_err_cloudflare_required;

  /// No description provided for @source_err_api_blocked.
  ///
  /// In en, this message translates to:
  /// **'API access blocked'**
  String get source_err_api_blocked;

  /// No description provided for @source_err_antibot_dropped.
  ///
  /// In en, this message translates to:
  /// **'Anti-bot block — connection dropped'**
  String get source_err_antibot_dropped;

  /// No description provided for @source_err_connection_failed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get source_err_connection_failed;

  /// No description provided for @source_err_source_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable'**
  String get source_err_source_unavailable;

  /// No description provided for @source_err_empty_box.
  ///
  /// In en, this message translates to:
  /// **'Empty box'**
  String get source_err_empty_box;

  /// No description provided for @source_err_cloudflare_needed.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare verification needed'**
  String get source_err_cloudflare_needed;

  /// No description provided for @source_err_source_connection_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to the source'**
  String get source_err_source_connection_failed;

  /// No description provided for @source_err_finish_verification.
  ///
  /// In en, this message translates to:
  /// **'Finish the verification in the panel, then retry.'**
  String get source_err_finish_verification;

  /// No description provided for @source_err_nothing_returned.
  ///
  /// In en, this message translates to:
  /// **'The source returned nothing. Retry, or update the extension.'**
  String get source_err_nothing_returned;

  /// No description provided for @source_err_pull_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get source_err_pull_to_refresh;

  /// No description provided for @source_err_details.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get source_err_details;

  /// No description provided for @source_err_hide_details.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get source_err_hide_details;

  /// No description provided for @source_err_copy_details.
  ///
  /// In en, this message translates to:
  /// **'Copy the error details'**
  String get source_err_copy_details;

  /// No description provided for @source_err_copied.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get source_err_copied;

  /// No description provided for @media_trending_week.
  ///
  /// In en, this message translates to:
  /// **'Trending this week'**
  String get media_trending_week;

  /// No description provided for @media_airing_today.
  ///
  /// In en, this message translates to:
  /// **'Airing today'**
  String get media_airing_today;

  /// No description provided for @media_on_the_air.
  ///
  /// In en, this message translates to:
  /// **'On the air'**
  String get media_on_the_air;

  /// No description provided for @media_now_playing.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get media_now_playing;

  /// No description provided for @media_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get media_upcoming;

  /// No description provided for @media_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get media_movies;

  /// No description provided for @media_live_tv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get media_live_tv;

  /// No description provided for @media_library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get media_library;

  /// No description provided for @media_tv_genres.
  ///
  /// In en, this message translates to:
  /// **'TV genres'**
  String get media_tv_genres;

  /// No description provided for @media_streaming_services.
  ///
  /// In en, this message translates to:
  /// **'Streaming services'**
  String get media_streaming_services;

  /// No description provided for @media_stories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get media_stories;

  /// No description provided for @media_documentaries.
  ///
  /// In en, this message translates to:
  /// **'Documentaries'**
  String get media_documentaries;

  /// No description provided for @media_docu_prefix.
  ///
  /// In en, this message translates to:
  /// **'Docu · {name}'**
  String media_docu_prefix(Object name);

  /// No description provided for @media_max_available.
  ///
  /// In en, this message translates to:
  /// **'Maximum available: {count}'**
  String media_max_available(Object count);

  /// No description provided for @media_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get media_continue;

  /// No description provided for @media_customize_ellipsis.
  ///
  /// In en, this message translates to:
  /// **'Customise…'**
  String get media_customize_ellipsis;

  /// No description provided for @media_untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get media_untitled;

  /// No description provided for @media_catalogue_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Catalogue unavailable'**
  String get media_catalogue_unavailable;

  /// No description provided for @media_catalogue_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load {title} for now.'**
  String media_catalogue_load_failed(Object title);

  /// No description provided for @media_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get media_back;

  /// No description provided for @media_all_episodes_queued.
  ///
  /// In en, this message translates to:
  /// **'All episodes queued'**
  String get media_all_episodes_queued;

  /// No description provided for @media_start_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start: {error}'**
  String media_start_failed(Object error);

  /// No description provided for @media_reel_mode.
  ///
  /// In en, this message translates to:
  /// **'Reel mode'**
  String get media_reel_mode;

  /// No description provided for @media_season_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} season} other{{count} seasons}}'**
  String media_season_count(num count);

  /// No description provided for @media_season_n.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String media_season_n(Object number);

  /// No description provided for @media_synopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get media_synopsis;

  /// No description provided for @media_crew_info.
  ///
  /// In en, this message translates to:
  /// **'Crew & info'**
  String get media_crew_info;

  /// No description provided for @media_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get media_country;

  /// No description provided for @media_director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get media_director;

  /// No description provided for @media_cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get media_cast;

  /// No description provided for @media_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get media_unknown;

  /// No description provided for @media_licenced.
  ///
  /// In en, this message translates to:
  /// **'Licensed'**
  String get media_licenced;

  /// No description provided for @media_add_to_library.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get media_add_to_library;

  /// No description provided for @media_resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get media_resources;

  /// No description provided for @media_provided_by.
  ///
  /// In en, this message translates to:
  /// **'Provided by'**
  String get media_provided_by;

  /// No description provided for @media_source_options.
  ///
  /// In en, this message translates to:
  /// **'Source options'**
  String get media_source_options;

  /// No description provided for @media_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get media_refresh;

  /// No description provided for @media_choose_season.
  ///
  /// In en, this message translates to:
  /// **'Choose the season'**
  String get media_choose_season;

  /// No description provided for @media_choose_language.
  ///
  /// In en, this message translates to:
  /// **'Choose the language'**
  String get media_choose_language;

  /// No description provided for @media_choose_resolution.
  ///
  /// In en, this message translates to:
  /// **'Choose the resolution'**
  String get media_choose_resolution;

  /// No description provided for @media_no_episode_available.
  ///
  /// In en, this message translates to:
  /// **'No episode available'**
  String get media_no_episode_available;

  /// No description provided for @media_watch_now.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get media_watch_now;

  /// No description provided for @media_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get media_year;

  /// No description provided for @media_no_details.
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get media_no_details;

  /// No description provided for @media_previews.
  ///
  /// In en, this message translates to:
  /// **'Previews'**
  String get media_previews;

  /// No description provided for @media_episodes_label.
  ///
  /// In en, this message translates to:
  /// **'Episodes ({count})'**
  String media_episodes_label(Object count);

  /// No description provided for @media_status_ongoing_label.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get media_status_ongoing_label;

  /// No description provided for @media_status_completed_label.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get media_status_completed_label;

  /// No description provided for @media_status_cancelled_label.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get media_status_cancelled_label;

  /// No description provided for @media_status_on_hold_label.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get media_status_on_hold_label;

  /// No description provided for @media_film.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get media_film;

  /// No description provided for @media_casting.
  ///
  /// In en, this message translates to:
  /// **'Casting'**
  String get media_casting;

  /// No description provided for @media_no_recommendation.
  ///
  /// In en, this message translates to:
  /// **'No recommendation'**
  String get media_no_recommendation;

  /// No description provided for @media_suggestions_here.
  ///
  /// In en, this message translates to:
  /// **'Suggestions will appear here.'**
  String get media_suggestions_here;

  /// No description provided for @media_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get media_anonymous;

  /// No description provided for @media_loading_comments.
  ///
  /// In en, this message translates to:
  /// **'Loading comments…'**
  String get media_loading_comments;

  /// No description provided for @media_reply_to.
  ///
  /// In en, this message translates to:
  /// **'Reply to {author}…'**
  String media_reply_to(Object author);

  /// No description provided for @media_your_comment.
  ///
  /// In en, this message translates to:
  /// **'Your comment…'**
  String get media_your_comment;

  /// No description provided for @media_add_comment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get media_add_comment;

  /// No description provided for @media_me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get media_me;

  /// No description provided for @media_just_now.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get media_just_now;

  /// No description provided for @media_reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get media_reply;

  /// No description provided for @media_time_ago_hours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String media_time_ago_hours(Object count);

  /// No description provided for @media_time_ago_days.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String media_time_ago_days(Object count);

  /// No description provided for @media_sample_comment_1.
  ///
  /// In en, this message translates to:
  /// **'Great film! The opening parkour scene genuinely took my breath away.'**
  String get media_sample_comment_1;

  /// No description provided for @media_sample_comment_2.
  ///
  /// In en, this message translates to:
  /// **'Agreed, and the choreography is clearly real, not CGI.'**
  String get media_sample_comment_2;

  /// No description provided for @media_sample_comment_3.
  ///
  /// In en, this message translates to:
  /// **'Exactly! You can feel every landing.'**
  String get media_sample_comment_3;

  /// No description provided for @media_sample_comment_4.
  ///
  /// In en, this message translates to:
  /// **'A performance that is still missed today.'**
  String get media_sample_comment_4;

  /// No description provided for @media_sample_comment_5.
  ///
  /// In en, this message translates to:
  /// **'The original with the other lead is even better!'**
  String get media_sample_comment_5;

  /// No description provided for @media_sample_comment_6.
  ///
  /// In en, this message translates to:
  /// **'French action cinema at its best.'**
  String get media_sample_comment_6;

  /// No description provided for @media_sample_comment_7.
  ///
  /// In en, this message translates to:
  /// **'The action is good but the plot is fairly predictable. 3.5/5 for me.'**
  String get media_sample_comment_7;

  /// No description provided for @media_sample_comment_8.
  ///
  /// In en, this message translates to:
  /// **'Just finished it. The ending is satisfying even if you see it coming.'**
  String get media_sample_comment_8;

  /// No description provided for @media_sample_comment_9.
  ///
  /// In en, this message translates to:
  /// **'Same, perfect for a relaxed evening.'**
  String get media_sample_comment_9;

  /// No description provided for @media_not_available.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get media_not_available;

  /// No description provided for @media_webview.
  ///
  /// In en, this message translates to:
  /// **'WebView'**
  String get media_webview;

  /// No description provided for @player_fit_contain.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get player_fit_contain;

  /// No description provided for @player_fit_cover.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get player_fit_cover;

  /// No description provided for @player_fit_fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get player_fit_fill;

  /// No description provided for @player_fit_height.
  ///
  /// In en, this message translates to:
  /// **'↕ Height'**
  String get player_fit_height;

  /// No description provided for @player_speed_title.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get player_speed_title;

  /// No description provided for @player_speed_short.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get player_speed_short;

  /// No description provided for @player_unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get player_unlock;

  /// No description provided for @player_capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get player_capture;

  /// No description provided for @player_capture_saved.
  ///
  /// In en, this message translates to:
  /// **'Capture saved'**
  String get player_capture_saved;

  /// No description provided for @player_capture_failed.
  ///
  /// In en, this message translates to:
  /// **'Capture failed'**
  String get player_capture_failed;

  /// No description provided for @player_auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get player_auto;

  /// No description provided for @player_portrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get player_portrait;

  /// No description provided for @player_landscape_left.
  ///
  /// In en, this message translates to:
  /// **'Landscape ←'**
  String get player_landscape_left;

  /// No description provided for @player_landscape_right.
  ///
  /// In en, this message translates to:
  /// **'Landscape →'**
  String get player_landscape_right;

  /// No description provided for @player_orientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get player_orientation;

  /// No description provided for @player_rotation_toast.
  ///
  /// In en, this message translates to:
  /// **'Rotation: {mode}'**
  String player_rotation_toast(Object mode);

  /// No description provided for @player_resume_at.
  ///
  /// In en, this message translates to:
  /// **'Resuming at {time}'**
  String player_resume_at(Object time);

  /// No description provided for @player_no_source_to_download.
  ///
  /// In en, this message translates to:
  /// **'No source to download'**
  String get player_no_source_to_download;

  /// No description provided for @player_already_downloaded.
  ///
  /// In en, this message translates to:
  /// **'This resolution is already downloaded'**
  String get player_already_downloaded;

  /// No description provided for @player_episode_not_in_library.
  ///
  /// In en, this message translates to:
  /// **'Episode not found in the library'**
  String get player_episode_not_in_library;

  /// No description provided for @player_download_added.
  ///
  /// In en, this message translates to:
  /// **'Download {quality} added'**
  String player_download_added(Object quality);

  /// No description provided for @player_download_duplicate.
  ///
  /// In en, this message translates to:
  /// **'This resolution is already downloaded or in progress'**
  String get player_download_duplicate;

  /// No description provided for @player_queue_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to queue'**
  String get player_queue_failed;

  /// No description provided for @player_quality_label.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get player_quality_label;

  /// No description provided for @player_download_quality.
  ///
  /// In en, this message translates to:
  /// **'Download · quality'**
  String get player_download_quality;

  /// No description provided for @player_no_quality.
  ///
  /// In en, this message translates to:
  /// **'No quality'**
  String get player_no_quality;

  /// No description provided for @player_quality_toast.
  ///
  /// In en, this message translates to:
  /// **'Quality: {quality}'**
  String player_quality_toast(Object quality);

  /// No description provided for @player_track_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get player_track_none;

  /// No description provided for @player_track_n.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String player_track_n(Object number);

  /// No description provided for @player_subtitle_n.
  ///
  /// In en, this message translates to:
  /// **'Subtitle {number}'**
  String player_subtitle_n(Object number);

  /// No description provided for @player_sub_n.
  ///
  /// In en, this message translates to:
  /// **'Sub {number}'**
  String player_sub_n(Object number);

  /// No description provided for @player_tab_playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get player_tab_playback;

  /// No description provided for @player_tab_audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get player_tab_audio;

  /// No description provided for @player_tab_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get player_tab_subtitles;

  /// No description provided for @player_seek_interval.
  ///
  /// In en, this message translates to:
  /// **'SEEK INTERVAL'**
  String get player_seek_interval;

  /// No description provided for @player_video_adjust.
  ///
  /// In en, this message translates to:
  /// **'VIDEO ADJUSTMENT'**
  String get player_video_adjust;

  /// No description provided for @player_no_audio_track.
  ///
  /// In en, this message translates to:
  /// **'No audio track'**
  String get player_no_audio_track;

  /// No description provided for @player_no_subtitle.
  ///
  /// In en, this message translates to:
  /// **'No subtitle'**
  String get player_no_subtitle;

  /// No description provided for @player_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get player_disabled;

  /// No description provided for @player_disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get player_disable;

  /// No description provided for @player_bilingual.
  ///
  /// In en, this message translates to:
  /// **'Bilingual'**
  String get player_bilingual;

  /// No description provided for @player_subtitle_offset.
  ///
  /// In en, this message translates to:
  /// **'Subtitle offset'**
  String get player_subtitle_offset;

  /// No description provided for @player_subtitle_style.
  ///
  /// In en, this message translates to:
  /// **'Subtitle style'**
  String get player_subtitle_style;

  /// No description provided for @player_style_outline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get player_style_outline;

  /// No description provided for @player_style_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get player_style_background;

  /// No description provided for @player_player_settings.
  ///
  /// In en, this message translates to:
  /// **'Player settings'**
  String get player_player_settings;

  /// No description provided for @player_loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get player_loop;

  /// No description provided for @player_loop_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get player_loop_none;

  /// No description provided for @player_loop_one.
  ///
  /// In en, this message translates to:
  /// **'One'**
  String get player_loop_one;

  /// No description provided for @player_loop_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get player_loop_all;

  /// No description provided for @player_brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get player_brightness;

  /// No description provided for @player_more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get player_more;

  /// No description provided for @player_audio_only.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get player_audio_only;

  /// No description provided for @player_mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get player_mirror;

  /// No description provided for @player_night_mode.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get player_night_mode;

  /// No description provided for @player_loop_episode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get player_loop_episode;

  /// No description provided for @player_ab_repeat.
  ///
  /// In en, this message translates to:
  /// **'A–B repeat'**
  String get player_ab_repeat;

  /// No description provided for @player_ab_set_a.
  ///
  /// In en, this message translates to:
  /// **'Set A'**
  String get player_ab_set_a;

  /// No description provided for @player_ab_set_b.
  ///
  /// In en, this message translates to:
  /// **'Set B'**
  String get player_ab_set_b;

  /// No description provided for @player_audio_track.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get player_audio_track;

  /// No description provided for @player_no_track.
  ///
  /// In en, this message translates to:
  /// **'No track'**
  String get player_no_track;

  /// No description provided for @player_episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get player_episodes;

  /// No description provided for @player_no_episode.
  ///
  /// In en, this message translates to:
  /// **'No episode'**
  String get player_no_episode;

  /// No description provided for @player_episode_n.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String player_episode_n(Object number);

  /// No description provided for @player_ep_short.
  ///
  /// In en, this message translates to:
  /// **'EP {number}'**
  String player_ep_short(Object number);

  /// No description provided for @player_next_episode_in.
  ///
  /// In en, this message translates to:
  /// **'Next episode in'**
  String get player_next_episode_in;

  /// No description provided for @player_play_now.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get player_play_now;

  /// No description provided for @player_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get player_language;

  /// No description provided for @player_webview_error.
  ///
  /// In en, this message translates to:
  /// **'Watch player queue request failed'**
  String get player_webview_error;

  /// No description provided for @discover_title.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get discover_title;

  /// No description provided for @discover_mode_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get discover_mode_watch;

  /// No description provided for @discover_mode_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get discover_mode_manga;

  /// No description provided for @discover_mode_novel.
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get discover_mode_novel;

  /// No description provided for @discover_mode_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get discover_mode_music;

  /// No description provided for @discover_mode_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get discover_mode_custom;

  /// No description provided for @discover_type_all.
  ///
  /// In en, this message translates to:
  /// **'All anime'**
  String get discover_type_all;

  /// No description provided for @discover_type_film.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get discover_type_film;

  /// No description provided for @discover_type_series.
  ///
  /// In en, this message translates to:
  /// **'TV series'**
  String get discover_type_series;

  /// No description provided for @discover_type_ova.
  ///
  /// In en, this message translates to:
  /// **'OVA / ONA'**
  String get discover_type_ova;

  /// No description provided for @discover_type_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get discover_type_manga;

  /// No description provided for @discover_type_webtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get discover_type_webtoon;

  /// No description provided for @discover_type_novel.
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get discover_type_novel;

  /// No description provided for @discover_type_one_shot.
  ///
  /// In en, this message translates to:
  /// **'One shot'**
  String get discover_type_one_shot;

  /// No description provided for @discover_sort_trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get discover_sort_trending;

  /// No description provided for @discover_sort_popularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get discover_sort_popularity;

  /// No description provided for @discover_sort_score.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get discover_sort_score;

  /// No description provided for @discover_sort_newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get discover_sort_newest;

  /// No description provided for @discover_sort_az.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get discover_sort_az;

  /// No description provided for @discover_season_any.
  ///
  /// In en, this message translates to:
  /// **'All seasons'**
  String get discover_season_any;

  /// No description provided for @discover_season_winter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get discover_season_winter;

  /// No description provided for @discover_season_spring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get discover_season_spring;

  /// No description provided for @discover_season_summer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get discover_season_summer;

  /// No description provided for @discover_season_fall.
  ///
  /// In en, this message translates to:
  /// **'Fall'**
  String get discover_season_fall;

  /// No description provided for @discover_status_any.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get discover_status_any;

  /// No description provided for @discover_status_finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get discover_status_finished;

  /// No description provided for @discover_status_releasing.
  ///
  /// In en, this message translates to:
  /// **'Airing'**
  String get discover_status_releasing;

  /// No description provided for @discover_status_not_yet_released.
  ///
  /// In en, this message translates to:
  /// **'Not yet released'**
  String get discover_status_not_yet_released;

  /// No description provided for @discover_status_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get discover_status_cancelled;

  /// No description provided for @discover_status_hiatus.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get discover_status_hiatus;

  /// No description provided for @discover_score_any.
  ///
  /// In en, this message translates to:
  /// **'All scores'**
  String get discover_score_any;

  /// No description provided for @discover_clear_filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get discover_clear_filters;

  /// No description provided for @discover_section_sort.
  ///
  /// In en, this message translates to:
  /// **'SORT BY'**
  String get discover_section_sort;

  /// No description provided for @discover_section_display.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY MODE'**
  String get discover_section_display;

  /// No description provided for @discover_section_grid_size.
  ///
  /// In en, this message translates to:
  /// **'GRID SIZE'**
  String get discover_section_grid_size;

  /// No description provided for @discover_display_compact.
  ///
  /// In en, this message translates to:
  /// **'Compact grid'**
  String get discover_display_compact;

  /// No description provided for @discover_display_comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable grid'**
  String get discover_display_comfortable;

  /// No description provided for @discover_display_cinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get discover_display_cinema;

  /// No description provided for @discover_display_list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get discover_display_list;

  /// No description provided for @discover_adult_on.
  ///
  /// In en, this message translates to:
  /// **'Adult on'**
  String get discover_adult_on;

  /// No description provided for @discover_adult.
  ///
  /// In en, this message translates to:
  /// **'Adult content'**
  String get discover_adult;

  /// No description provided for @discover_filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get discover_filters;

  /// No description provided for @discover_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get discover_clear;

  /// No description provided for @discover_content_type.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get discover_content_type;

  /// No description provided for @discover_sort_by.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get discover_sort_by;

  /// No description provided for @discover_genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get discover_genre;

  /// No description provided for @discover_genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get discover_genres;

  /// No description provided for @discover_all_genres.
  ///
  /// In en, this message translates to:
  /// **'All genres'**
  String get discover_all_genres;

  /// No description provided for @discover_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get discover_format;

  /// No description provided for @discover_formats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get discover_formats;

  /// No description provided for @discover_all_formats.
  ///
  /// In en, this message translates to:
  /// **'All formats'**
  String get discover_all_formats;

  /// No description provided for @discover_season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get discover_season;

  /// No description provided for @discover_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get discover_year;

  /// No description provided for @discover_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get discover_status;

  /// No description provided for @discover_score_min.
  ///
  /// In en, this message translates to:
  /// **'Min score'**
  String get discover_score_min;

  /// No description provided for @discover_score_minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum score'**
  String get discover_score_minimum;

  /// No description provided for @discover_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load'**
  String get discover_load_failed;

  /// No description provided for @discover_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discover_retry;

  /// No description provided for @discover_no_results_for.
  ///
  /// In en, this message translates to:
  /// **'No results found for {query}'**
  String discover_no_results_for(Object query);

  /// No description provided for @discover_no_results_hint.
  ///
  /// In en, this message translates to:
  /// **'Try another term or change the filters.'**
  String get discover_no_results_hint;

  /// No description provided for @discover_timeless.
  ///
  /// In en, this message translates to:
  /// **'Timeless'**
  String get discover_timeless;

  /// No description provided for @discover_choose_extension.
  ///
  /// In en, this message translates to:
  /// **'Choose an extension'**
  String get discover_choose_extension;

  /// No description provided for @discover_choose_extension_body.
  ///
  /// In en, this message translates to:
  /// **'Select an installed extension to explore its content.'**
  String get discover_choose_extension_body;

  /// No description provided for @discover_select_extension.
  ///
  /// In en, this message translates to:
  /// **'Select an extension'**
  String get discover_select_extension;

  /// No description provided for @discover_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get discover_reset;

  /// No description provided for @discover_change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get discover_change;

  /// No description provided for @discover_load_error.
  ///
  /// In en, this message translates to:
  /// **'Loading error'**
  String get discover_load_error;

  /// No description provided for @discover_no_result.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get discover_no_result;

  /// No description provided for @discover_no_extension_installed.
  ///
  /// In en, this message translates to:
  /// **'No extension installed'**
  String get discover_no_extension_installed;

  /// No description provided for @discover_install_hint.
  ///
  /// In en, this message translates to:
  /// **'Install extensions from Browse → Extensions.'**
  String get discover_install_hint;

  /// No description provided for @discover_search.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get discover_search;

  /// No description provided for @discover_search_in.
  ///
  /// In en, this message translates to:
  /// **'Search in {name}…'**
  String discover_search_in(Object name);

  /// No description provided for @discover_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discover_all;

  /// No description provided for @discover_sources_label.
  ///
  /// In en, this message translates to:
  /// **'SOURCE'**
  String get discover_sources_label;

  /// No description provided for @discover_extension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get discover_extension;

  /// No description provided for @discover_unknown_title.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get discover_unknown_title;

  /// No description provided for @discover_this_search.
  ///
  /// In en, this message translates to:
  /// **'this search'**
  String get discover_this_search;

  /// No description provided for @discover_search_start_hint.
  ///
  /// In en, this message translates to:
  /// **'Type your search to start.'**
  String get discover_search_start_hint;

  /// No description provided for @discover_what_to_read.
  ///
  /// In en, this message translates to:
  /// **'What do you want to read?'**
  String get discover_what_to_read;

  /// No description provided for @discover_what_to_watch.
  ///
  /// In en, this message translates to:
  /// **'What do you want to watch?'**
  String get discover_what_to_watch;

  /// No description provided for @discover_preview_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get discover_preview_unavailable;

  /// No description provided for @discover_channels.
  ///
  /// In en, this message translates to:
  /// **'CHANNELS'**
  String get discover_channels;

  /// No description provided for @discover_actresses.
  ///
  /// In en, this message translates to:
  /// **'ACTRESSES'**
  String get discover_actresses;

  /// No description provided for @discover_videos.
  ///
  /// In en, this message translates to:
  /// **'VIDEOS'**
  String get discover_videos;

  /// No description provided for @discover_tmdb_tab_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discover_tmdb_tab_all;

  /// No description provided for @discover_tmdb_tab_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get discover_tmdb_tab_movies;

  /// No description provided for @discover_tmdb_tab_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get discover_tmdb_tab_series;

  /// No description provided for @discover_tmdb_tab_people.
  ///
  /// In en, this message translates to:
  /// **'Celebrities'**
  String get discover_tmdb_tab_people;

  /// No description provided for @discover_tmdb_tab_collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get discover_tmdb_tab_collections;

  /// No description provided for @discover_tmdb_hint_movie.
  ///
  /// In en, this message translates to:
  /// **'Search a movie…'**
  String get discover_tmdb_hint_movie;

  /// No description provided for @discover_tmdb_hint_series.
  ///
  /// In en, this message translates to:
  /// **'Search a series…'**
  String get discover_tmdb_hint_series;

  /// No description provided for @discover_tmdb_hint_all.
  ///
  /// In en, this message translates to:
  /// **'Movie, series or celebrity…'**
  String get discover_tmdb_hint_all;

  /// No description provided for @discover_tmdb_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Search unavailable'**
  String get discover_tmdb_unavailable;

  /// No description provided for @discover_tmdb_no_celebrity.
  ///
  /// In en, this message translates to:
  /// **'No celebrity'**
  String get discover_tmdb_no_celebrity;

  /// No description provided for @discover_tmdb_try_another_name.
  ///
  /// In en, this message translates to:
  /// **'Try another name.'**
  String get discover_tmdb_try_another_name;

  /// No description provided for @discover_tmdb_no_collection.
  ///
  /// In en, this message translates to:
  /// **'No collection'**
  String get discover_tmdb_no_collection;

  /// No description provided for @discover_tmdb_no_collection_match.
  ///
  /// In en, this message translates to:
  /// **'No saga or collection matches.'**
  String get discover_tmdb_no_collection_match;

  /// No description provided for @discover_tmdb_try_another_title.
  ///
  /// In en, this message translates to:
  /// **'Try another title.'**
  String get discover_tmdb_try_another_title;

  /// No description provided for @home_tab_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get home_tab_all;

  /// No description provided for @home_tab_movie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get home_tab_movie;

  /// No description provided for @home_tab_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get home_tab_series;

  /// No description provided for @home_tab_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get home_tab_music;

  /// No description provided for @home_tab_anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get home_tab_anime;

  /// No description provided for @home_tab_asia.
  ///
  /// In en, this message translates to:
  /// **'Asia'**
  String get home_tab_asia;

  /// No description provided for @home_tab_kids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get home_tab_kids;

  /// No description provided for @home_tab_western.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get home_tab_western;

  /// No description provided for @home_tab_africa.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get home_tab_africa;

  /// No description provided for @home_tab_tv_short.
  ///
  /// In en, this message translates to:
  /// **'TV Short'**
  String get home_tab_tv_short;

  /// No description provided for @home_tab_football.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get home_tab_football;

  /// No description provided for @home_tab_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get home_tab_games;

  /// No description provided for @home_for_you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get home_for_you;

  /// No description provided for @home_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search a title…'**
  String get home_search_hint;

  /// No description provided for @home_search_action.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get home_search_action;

  /// No description provided for @home_offline_banner.
  ///
  /// In en, this message translates to:
  /// **'Connection unavailable — showing cached data'**
  String get home_offline_banner;

  /// No description provided for @home_spotlight.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get home_spotlight;

  /// No description provided for @home_animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get home_animation;

  /// No description provided for @home_popular_movies.
  ///
  /// In en, this message translates to:
  /// **'Popular movies'**
  String get home_popular_movies;

  /// No description provided for @home_trending_week.
  ///
  /// In en, this message translates to:
  /// **'Trending this week'**
  String get home_trending_week;

  /// No description provided for @home_top_rated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get home_top_rated;

  /// No description provided for @home_now_playing.
  ///
  /// In en, this message translates to:
  /// **'Now in theaters'**
  String get home_now_playing;

  /// No description provided for @home_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get home_upcoming;

  /// No description provided for @home_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get home_movies;

  /// No description provided for @home_movies_studio.
  ///
  /// In en, this message translates to:
  /// **'Movies · Studio'**
  String get home_movies_studio;

  /// No description provided for @home_popular_series.
  ///
  /// In en, this message translates to:
  /// **'Popular series'**
  String get home_popular_series;

  /// No description provided for @home_tv_trending_week.
  ///
  /// In en, this message translates to:
  /// **'TV trending this week'**
  String get home_tv_trending_week;

  /// No description provided for @home_top_rated_series.
  ///
  /// In en, this message translates to:
  /// **'Top rated series'**
  String get home_top_rated_series;

  /// No description provided for @home_watch_tonight.
  ///
  /// In en, this message translates to:
  /// **'Watch tonight'**
  String get home_watch_tonight;

  /// No description provided for @home_airing_today.
  ///
  /// In en, this message translates to:
  /// **'Airing today'**
  String get home_airing_today;

  /// No description provided for @home_airing_now.
  ///
  /// In en, this message translates to:
  /// **'Currently airing'**
  String get home_airing_now;

  /// No description provided for @home_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get home_series;

  /// No description provided for @home_series_studio.
  ///
  /// In en, this message translates to:
  /// **'Series · Studio'**
  String get home_series_studio;

  /// No description provided for @home_country_fr.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get home_country_fr;

  /// No description provided for @home_country_us_uk.
  ///
  /// In en, this message translates to:
  /// **'United States / United Kingdom'**
  String get home_country_us_uk;

  /// No description provided for @home_country_kr.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get home_country_kr;

  /// No description provided for @home_country_jp.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get home_country_jp;

  /// No description provided for @home_kids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get home_kids;

  /// No description provided for @home_kids_sub.
  ///
  /// In en, this message translates to:
  /// **'Cartoons & kids content'**
  String get home_kids_sub;

  /// No description provided for @home_western.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get home_western;

  /// No description provided for @home_western_sub.
  ///
  /// In en, this message translates to:
  /// **'US/EU series & movies'**
  String get home_western_sub;

  /// No description provided for @home_africa.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get home_africa;

  /// No description provided for @home_africa_sub.
  ///
  /// In en, this message translates to:
  /// **'African content'**
  String get home_africa_sub;

  /// No description provided for @home_football.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get home_football;

  /// No description provided for @home_football_sub.
  ///
  /// In en, this message translates to:
  /// **'Matches & highlights'**
  String get home_football_sub;

  /// No description provided for @home_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get home_games;

  /// No description provided for @home_games_sub.
  ///
  /// In en, this message translates to:
  /// **'ROM library'**
  String get home_games_sub;

  /// No description provided for @home_tv_short.
  ///
  /// In en, this message translates to:
  /// **'TV Short'**
  String get home_tv_short;

  /// No description provided for @home_tv_short_sub.
  ///
  /// In en, this message translates to:
  /// **'Mini-series, shorts & short dramas'**
  String get home_tv_short_sub;

  /// No description provided for @home_mini_dramas.
  ///
  /// In en, this message translates to:
  /// **'Mini-dramas & shorts'**
  String get home_mini_dramas;

  /// No description provided for @home_top_rated_short.
  ///
  /// In en, this message translates to:
  /// **'Top rated (short)'**
  String get home_top_rated_short;

  /// No description provided for @home_no_movie.
  ///
  /// In en, this message translates to:
  /// **'No movie available'**
  String get home_no_movie;

  /// No description provided for @home_best_rated.
  ///
  /// In en, this message translates to:
  /// **'Best rated'**
  String get home_best_rated;

  /// No description provided for @home_explore_genre.
  ///
  /// In en, this message translates to:
  /// **'Explore by genre'**
  String get home_explore_genre;

  /// No description provided for @home_trending_series.
  ///
  /// In en, this message translates to:
  /// **'Trending series'**
  String get home_trending_series;

  /// No description provided for @home_sagas_long.
  ///
  /// In en, this message translates to:
  /// **'Sagas & long series'**
  String get home_sagas_long;

  /// No description provided for @home_top_popular.
  ///
  /// In en, this message translates to:
  /// **'Top popular'**
  String get home_top_popular;

  /// No description provided for @home_best_rated_fem.
  ///
  /// In en, this message translates to:
  /// **'Best rated'**
  String get home_best_rated_fem;

  /// No description provided for @home_kdrama_trending.
  ///
  /// In en, this message translates to:
  /// **'Trending K-Drama'**
  String get home_kdrama_trending;

  /// No description provided for @home_cdrama_manhua.
  ///
  /// In en, this message translates to:
  /// **'C-Drama / Manhua'**
  String get home_cdrama_manhua;

  /// No description provided for @home_top_asia.
  ///
  /// In en, this message translates to:
  /// **'Top Asia'**
  String get home_top_asia;

  /// No description provided for @home_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get home_open;

  /// No description provided for @home_see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get home_see_all;

  /// No description provided for @home_view_all.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get home_view_all;

  /// No description provided for @home_favorite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get home_favorite;

  /// No description provided for @home_origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get home_origin;

  /// No description provided for @home_continue_watching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get home_continue_watching;

  /// No description provided for @home_tonight_pick.
  ///
  /// In en, this message translates to:
  /// **'TONIGHT’S PICK'**
  String get home_tonight_pick;

  /// No description provided for @home_recent_releases.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get home_recent_releases;

  /// No description provided for @home_trending_now.
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get home_trending_now;

  /// No description provided for @home_top_now.
  ///
  /// In en, this message translates to:
  /// **'Top this week'**
  String get home_top_now;

  /// No description provided for @home_drama_k.
  ///
  /// In en, this message translates to:
  /// **'K-Drama'**
  String get home_drama_k;

  /// No description provided for @home_drama_c.
  ///
  /// In en, this message translates to:
  /// **'C-Drama'**
  String get home_drama_c;

  /// No description provided for @home_drama_j.
  ///
  /// In en, this message translates to:
  /// **'J-Drama'**
  String get home_drama_j;

  /// No description provided for @account_guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get account_guest;

  /// No description provided for @account_connect_tracker.
  ///
  /// In en, this message translates to:
  /// **'Connect a tracker to sync'**
  String get account_connect_tracker;

  /// No description provided for @account_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get account_settings;

  /// No description provided for @account_tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get account_tracking;

  /// No description provided for @account_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get account_history;

  /// No description provided for @account_downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get account_downloads;

  /// No description provided for @account_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get account_about;

  /// No description provided for @tmdb_cat_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get tmdb_cat_movies;

  /// No description provided for @tmdb_cat_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get tmdb_cat_series;

  /// No description provided for @tmdb_cat_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tmdb_cat_refresh;

  /// No description provided for @tmdb_cat_now_playing.
  ///
  /// In en, this message translates to:
  /// **'Now in theaters'**
  String get tmdb_cat_now_playing;

  /// No description provided for @tmdb_cat_airing_now.
  ///
  /// In en, this message translates to:
  /// **'Currently airing'**
  String get tmdb_cat_airing_now;

  /// No description provided for @tmdb_cat_airing_today.
  ///
  /// In en, this message translates to:
  /// **'Airing today'**
  String get tmdb_cat_airing_today;

  /// No description provided for @tmdb_cat_movies_sub.
  ///
  /// In en, this message translates to:
  /// **'The movies of the moment, with their TMDB posters and information.'**
  String get tmdb_cat_movies_sub;

  /// No description provided for @tmdb_cat_series_sub.
  ///
  /// In en, this message translates to:
  /// **'The series of the moment, with their TMDB posters and information.'**
  String get tmdb_cat_series_sub;

  /// No description provided for @tmdb_cat_empty.
  ///
  /// In en, this message translates to:
  /// **'No content available.'**
  String get tmdb_cat_empty;

  /// No description provided for @tmdb_cat_rating.
  ///
  /// In en, this message translates to:
  /// **'TMDB rating: {rating}/10'**
  String tmdb_cat_rating(Object rating);

  /// No description provided for @tmdb_cat_date.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String tmdb_cat_date(Object date);

  /// No description provided for @tmdb_cat_catalogue.
  ///
  /// In en, this message translates to:
  /// **'the TMDB catalogue'**
  String get tmdb_cat_catalogue;

  /// No description provided for @tmdb_cat_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load TMDB content.'**
  String get tmdb_cat_load_failed;

  /// No description provided for @home_search_hint_all.
  ///
  /// In en, this message translates to:
  /// **'Movie, series, anime, music…'**
  String get home_search_hint_all;

  /// No description provided for @home_search_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get home_search_recent;

  /// No description provided for @home_search_everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone is searching'**
  String get home_search_everyone;

  /// No description provided for @home_search_error.
  ///
  /// In en, this message translates to:
  /// **'Search error'**
  String get home_search_error;

  /// No description provided for @home_search_no_anilist.
  ///
  /// In en, this message translates to:
  /// **'No AniList results for “{query}”'**
  String home_search_no_anilist(Object query);

  /// No description provided for @home_search_no_data.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get home_search_no_data;

  /// No description provided for @home_search_in_watch.
  ///
  /// In en, this message translates to:
  /// **'Search in Watch'**
  String get home_search_in_watch;

  /// No description provided for @home_search_in_watch_body.
  ///
  /// In en, this message translates to:
  /// **'Search “{query}” across all your installed Watch extensions, with filters for language, source and more.'**
  String home_search_in_watch_body(Object query);

  /// No description provided for @home_search_open_watch.
  ///
  /// In en, this message translates to:
  /// **'Open Watch search'**
  String get home_search_open_watch;

  /// No description provided for @episode_sources_tracks_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the tracks.'**
  String get episode_sources_tracks_failed;

  /// No description provided for @episode_sources_title.
  ///
  /// In en, this message translates to:
  /// **'Episode sources'**
  String get episode_sources_title;

  /// No description provided for @episode_sources_label.
  ///
  /// In en, this message translates to:
  /// **'Episode {number} · {title}'**
  String episode_sources_label(Object number, Object title);

  /// No description provided for @episode_sources_searching.
  ///
  /// In en, this message translates to:
  /// **'Searching {checked} / {total} sources'**
  String episode_sources_searching(Object checked, Object total);

  /// No description provided for @episode_sources_no_extension.
  ///
  /// In en, this message translates to:
  /// **'No active anime extension is installed.'**
  String get episode_sources_no_extension;

  /// No description provided for @episode_sources_searching_hint.
  ///
  /// In en, this message translates to:
  /// **'Searching for the episode on the installed extensions…'**
  String get episode_sources_searching_hint;

  /// No description provided for @episode_sources_none.
  ///
  /// In en, this message translates to:
  /// **'No extension offers this episode.'**
  String get episode_sources_none;

  /// No description provided for @episode_sources_unanswered.
  ///
  /// In en, this message translates to:
  /// **'{count} source(s) did not respond.'**
  String episode_sources_unanswered(Object count);

  /// No description provided for @episode_sources_extension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get episode_sources_extension;

  /// No description provided for @episode_sources_episode_n.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String episode_sources_episode_n(Object number);

  /// No description provided for @episode_sources_view_tracks.
  ///
  /// In en, this message translates to:
  /// **'View quality and subtitles'**
  String get episode_sources_view_tracks;

  /// No description provided for @episode_sources_retry_tracks.
  ///
  /// In en, this message translates to:
  /// **'Retry the tracks'**
  String get episode_sources_retry_tracks;

  /// No description provided for @episode_sources_no_track.
  ///
  /// In en, this message translates to:
  /// **'No video track detected.'**
  String get episode_sources_no_track;

  /// No description provided for @episode_sources_quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get episode_sources_quality;

  /// No description provided for @episode_sources_audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get episode_sources_audio;

  /// No description provided for @episode_sources_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get episode_sources_subtitles;

  /// No description provided for @episode_sources_subtitles_none.
  ///
  /// In en, this message translates to:
  /// **'Not indicated'**
  String get episode_sources_subtitles_none;

  /// No description provided for @episode_sources_play.
  ///
  /// In en, this message translates to:
  /// **'Play this episode'**
  String get episode_sources_play;

  /// No description provided for @download_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download_sheet_title;

  /// No description provided for @download_sheet_resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get download_sheet_resources;

  /// No description provided for @download_sheet_added_by.
  ///
  /// In en, this message translates to:
  /// **'Added by'**
  String get download_sheet_added_by;

  /// No description provided for @download_sheet_audio_original.
  ///
  /// In en, this message translates to:
  /// **'Original audio'**
  String get download_sheet_audio_original;

  /// No description provided for @download_sheet_select_all.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get download_sheet_select_all;

  /// No description provided for @download_sheet_website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get download_sheet_website;

  /// No description provided for @download_sheet_source_code.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get download_sheet_source_code;

  /// No description provided for @download_sheet_no_resource.
  ///
  /// In en, this message translates to:
  /// **'No resource available'**
  String get download_sheet_no_resource;

  /// No description provided for @download_sheet_all_downloaded.
  ///
  /// In en, this message translates to:
  /// **'All the qualities are already downloaded.'**
  String get download_sheet_all_downloaded;

  /// No description provided for @download_sheet_no_link.
  ///
  /// In en, this message translates to:
  /// **'No link available.'**
  String get download_sheet_no_link;

  /// No description provided for @download_sheet_no_episode.
  ///
  /// In en, this message translates to:
  /// **'No episode available.'**
  String get download_sheet_no_episode;

  /// No description provided for @download_sheet_no_link_for.
  ///
  /// In en, this message translates to:
  /// **'No link for {name}'**
  String download_sheet_no_link_for(Object name);

  /// No description provided for @download_sheet_open_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {app} — check that it is installed.'**
  String download_sheet_open_failed(Object app);

  /// No description provided for @download_sheet_season.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String download_sheet_season(Object number);

  /// No description provided for @download_sheet_season_word.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get download_sheet_season_word;

  /// No description provided for @remote_server_title.
  ///
  /// In en, this message translates to:
  /// **'Remote server'**
  String get remote_server_title;

  /// No description provided for @remote_public_link.
  ///
  /// In en, this message translates to:
  /// **'Public link (SSH tunnel)'**
  String get remote_public_link;

  /// No description provided for @remote_paste_in_web.
  ///
  /// In en, this message translates to:
  /// **'Paste this link into the web version'**
  String get remote_paste_in_web;

  /// No description provided for @remote_tunnel_starting.
  ///
  /// In en, this message translates to:
  /// **'Tunnel is starting…'**
  String get remote_tunnel_starting;

  /// No description provided for @remote_tunnel_ssh_hint.
  ///
  /// In en, this message translates to:
  /// **'SSH connection — about 5 seconds'**
  String get remote_tunnel_ssh_hint;

  /// No description provided for @remote_local_link.
  ///
  /// In en, this message translates to:
  /// **'Local link (same Wi-Fi network)'**
  String get remote_local_link;

  /// No description provided for @remote_use_same_network.
  ///
  /// In en, this message translates to:
  /// **'Use this if you are on the same network'**
  String get remote_use_same_network;

  /// No description provided for @remote_api_key.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get remote_api_key;

  /// No description provided for @remote_api_key_hint.
  ///
  /// In en, this message translates to:
  /// **'Add it as ?key=... or as an Authorization: Bearer header on every /api call'**
  String get remote_api_key_hint;

  /// No description provided for @remote_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get remote_copy;

  /// No description provided for @remote_key_copied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get remote_key_copied;

  /// No description provided for @remote_regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate (invalidates the old key)'**
  String get remote_regenerate;

  /// No description provided for @remote_new_key.
  ///
  /// In en, this message translates to:
  /// **'New key generated'**
  String get remote_new_key;

  /// No description provided for @remote_how_to_use.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get remote_how_to_use;

  /// No description provided for @remote_how_to_use_body.
  ///
  /// In en, this message translates to:
  /// **'1. Copy the public link above\n2. Open Watchtower on the web\n3. Go to Settings → Remote connection\n4. Paste the link and sign in\n5. Every extension and source becomes available'**
  String get remote_how_to_use_body;

  /// No description provided for @remote_how_it_works.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get remote_how_it_works;

  /// No description provided for @remote_how_it_works_body.
  ///
  /// In en, this message translates to:
  /// **'When Remote Mode is on, your device becomes a server. A public link is created automatically through an SSH tunnel (localhost.run) — reachable from anywhere, with no download and no network setup.\n\nThe web version of Watchtower can then connect to this link to use all your installed extensions and sources.'**
  String get remote_how_it_works_body;

  /// No description provided for @remote_tunnel_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Tunnel unavailable'**
  String get remote_tunnel_unavailable;

  /// No description provided for @remote_copy_error.
  ///
  /// In en, this message translates to:
  /// **'Copy the error'**
  String get remote_copy_error;

  /// No description provided for @remote_check_connection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get remote_check_connection;

  /// No description provided for @remote_error_copied.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get remote_error_copied;

  /// No description provided for @remote_link_copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get remote_link_copied;

  /// No description provided for @remote_connect_title.
  ///
  /// In en, this message translates to:
  /// **'Connect to the Watchtower server'**
  String get remote_connect_title;

  /// No description provided for @remote_connect_steps.
  ///
  /// In en, this message translates to:
  /// **'1. Open Watchtower on your phone or PC\n2. Go to Settings → Remote Mode\n3. Turn the server on, then copy the public link and the API key\n4. Paste them here — the next visit will be automatic'**
  String get remote_connect_steps;

  /// No description provided for @remote_server_url_label.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get remote_server_url_label;

  /// No description provided for @remote_api_key_label.
  ///
  /// In en, this message translates to:
  /// **'Server API key'**
  String get remote_api_key_label;

  /// No description provided for @remote_show_key.
  ///
  /// In en, this message translates to:
  /// **'Show the key'**
  String get remote_show_key;

  /// No description provided for @remote_hide_key.
  ///
  /// In en, this message translates to:
  /// **'Hide the key'**
  String get remote_hide_key;

  /// No description provided for @remote_enter_url.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL.'**
  String get remote_enter_url;

  /// No description provided for @remote_enter_api_key.
  ///
  /// In en, this message translates to:
  /// **'Enter the API key shown in Remote Mode.'**
  String get remote_enter_api_key;

  /// No description provided for @remote_http_blocked.
  ///
  /// In en, this message translates to:
  /// **'HTTP URL blocked by the browser (this page is HTTPS).\nUse the HTTPS public link of the SSH tunnel:\ne.g. https://xxxx.lhr.life'**
  String get remote_http_blocked;

  /// No description provided for @remote_timeout_10.
  ///
  /// In en, this message translates to:
  /// **'Timed out (10s) — server unreachable or wrong URL'**
  String get remote_timeout_10;

  /// No description provided for @remote_wrong_api_key.
  ///
  /// In en, this message translates to:
  /// **'Wrong API key. Copy the key shown in Remote Mode.'**
  String get remote_wrong_api_key;

  /// No description provided for @remote_api_unreachable.
  ///
  /// In en, this message translates to:
  /// **'The server responds, but its API is unreachable (HTTP {code}).'**
  String remote_api_unreachable(Object code);

  /// No description provided for @remote_connected_sync.
  ///
  /// In en, this message translates to:
  /// **'Server connected — syncing…'**
  String get remote_connected_sync;

  /// No description provided for @remote_not_found.
  ///
  /// In en, this message translates to:
  /// **'Server not found (HTTP {code}).\nCheck that Remote Mode is active on your device.'**
  String remote_not_found(Object code);

  /// No description provided for @remote_timeout_short.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get remote_timeout_short;

  /// No description provided for @remote_connect_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: {error}'**
  String remote_connect_failed(Object error);

  /// No description provided for @remote_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get remote_connecting;

  /// No description provided for @remote_connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get remote_connect;

  /// No description provided for @about_developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get about_developer;

  /// No description provided for @about_check_now.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get about_check_now;

  /// No description provided for @about_check_hint.
  ///
  /// In en, this message translates to:
  /// **'Look for the latest available version'**
  String get about_check_hint;

  /// No description provided for @about_up_to_date.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version: {version}'**
  String about_up_to_date(Object version);

  /// No description provided for @about_read_logs.
  ///
  /// In en, this message translates to:
  /// **'Read the logs'**
  String get about_read_logs;

  /// No description provided for @about_logs_hint.
  ///
  /// In en, this message translates to:
  /// **'Full, coloured and filterable view'**
  String get about_logs_hint;

  /// No description provided for @about_binary_engines.
  ///
  /// In en, this message translates to:
  /// **'BINARY ENGINES'**
  String get about_binary_engines;

  /// No description provided for @about_choose_engines.
  ///
  /// In en, this message translates to:
  /// **'Pick the engines to install for your needs.'**
  String get about_choose_engines;

  /// No description provided for @about_engine_download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get about_engine_download;

  /// No description provided for @about_aria2_desc.
  ///
  /// In en, this message translates to:
  /// **'Multi-connection engine for HTTP, FTP, BitTorrent and Magnet.'**
  String get about_aria2_desc;

  /// No description provided for @about_more_engines.
  ///
  /// In en, this message translates to:
  /// **'More engines are coming soon.'**
  String get about_more_engines;

  /// No description provided for @about_installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get about_installed;

  /// No description provided for @about_available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get about_available;

  /// No description provided for @about_stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get about_stable;

  /// No description provided for @about_aria2_tagline.
  ///
  /// In en, this message translates to:
  /// **'High-performance multi-connection download engine'**
  String get about_aria2_tagline;

  /// No description provided for @about_feature_multi.
  ///
  /// In en, this message translates to:
  /// **'Multi-connections'**
  String get about_feature_multi;

  /// No description provided for @about_feature_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get about_feature_resume;

  /// No description provided for @about_feature_open_source.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get about_feature_open_source;

  /// No description provided for @about_import_binary.
  ///
  /// In en, this message translates to:
  /// **'Import a local binary'**
  String get about_import_binary;

  /// No description provided for @about_aria2_fetch_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the aria2 release ({code})'**
  String about_aria2_fetch_failed(Object code);

  /// No description provided for @about_aria2_none.
  ///
  /// In en, this message translates to:
  /// **'No aria2 binary available'**
  String get about_aria2_none;

  /// No description provided for @about_aria2_error.
  ///
  /// In en, this message translates to:
  /// **'aria2 fetch error: {error}'**
  String about_aria2_error(Object error);

  /// No description provided for @about_download_aria2c.
  ///
  /// In en, this message translates to:
  /// **'Download aria2c'**
  String get about_download_aria2c;

  /// No description provided for @about_choose_aria2c.
  ///
  /// In en, this message translates to:
  /// **'Choose an aria2c binary'**
  String get about_choose_aria2c;

  /// No description provided for @about_file_unreachable.
  ///
  /// In en, this message translates to:
  /// **'File unreachable'**
  String get about_file_unreachable;

  /// No description provided for @about_binary_imported.
  ///
  /// In en, this message translates to:
  /// **'aria2c binary imported: {name}'**
  String about_binary_imported(Object name);

  /// No description provided for @about_import_failed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String about_import_failed(Object error);

  /// No description provided for @about_choose_binary.
  ///
  /// In en, this message translates to:
  /// **'Choose the binary'**
  String get about_choose_binary;

  /// No description provided for @about_compatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible'**
  String get about_compatible;

  /// No description provided for @about_all_platforms.
  ///
  /// In en, this message translates to:
  /// **'All platforms'**
  String get about_all_platforms;

  /// No description provided for @about_download_complete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get about_download_complete;

  /// No description provided for @about_download_failed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get about_download_failed;

  /// No description provided for @log_viewer_title.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get log_viewer_title;

  /// No description provided for @log_viewer_copy_all.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get log_viewer_copy_all;

  /// No description provided for @log_viewer_download_share.
  ///
  /// In en, this message translates to:
  /// **'Download / Share'**
  String get log_viewer_download_share;

  /// No description provided for @log_viewer_download_txt.
  ///
  /// In en, this message translates to:
  /// **'Download .txt'**
  String get log_viewer_download_txt;

  /// No description provided for @log_viewer_download_md.
  ///
  /// In en, this message translates to:
  /// **'Download .md'**
  String get log_viewer_download_md;

  /// No description provided for @log_viewer_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get log_viewer_share;

  /// No description provided for @log_viewer_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get log_viewer_refresh;

  /// No description provided for @log_viewer_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get log_viewer_options;

  /// No description provided for @log_viewer_overlay_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide overlay'**
  String get log_viewer_overlay_hide;

  /// No description provided for @log_viewer_overlay_live.
  ///
  /// In en, this message translates to:
  /// **'Live overlay'**
  String get log_viewer_overlay_live;

  /// No description provided for @log_viewer_autoscroll_on.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll ON'**
  String get log_viewer_autoscroll_on;

  /// No description provided for @log_viewer_autoscroll_off.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll OFF'**
  String get log_viewer_autoscroll_off;

  /// No description provided for @log_viewer_clear_logs.
  ///
  /// In en, this message translates to:
  /// **'Clear the logs'**
  String get log_viewer_clear_logs;

  /// No description provided for @log_viewer_filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get log_viewer_filters;

  /// No description provided for @log_viewer_no_log.
  ///
  /// In en, this message translates to:
  /// **'No log recorded'**
  String get log_viewer_no_log;

  /// No description provided for @log_viewer_no_result.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get log_viewer_no_result;

  /// No description provided for @log_viewer_clear_filters.
  ///
  /// In en, this message translates to:
  /// **'Clear the filters'**
  String get log_viewer_clear_filters;

  /// No description provided for @log_viewer_scroll_bottom.
  ///
  /// In en, this message translates to:
  /// **'Go to the bottom'**
  String get log_viewer_scroll_bottom;

  /// No description provided for @log_viewer_line.
  ///
  /// In en, this message translates to:
  /// **'{count} line'**
  String log_viewer_line(Object count);

  /// No description provided for @log_viewer_lines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String log_viewer_lines(Object count);

  /// No description provided for @log_viewer_filter.
  ///
  /// In en, this message translates to:
  /// **' · filter: \"{query}\"'**
  String log_viewer_filter(Object query);

  /// No description provided for @log_viewer_error.
  ///
  /// In en, this message translates to:
  /// **'{count} error'**
  String log_viewer_error(Object count);

  /// No description provided for @log_viewer_errors.
  ///
  /// In en, this message translates to:
  /// **'{count} errors'**
  String log_viewer_errors(Object count);

  /// No description provided for @log_viewer_warning.
  ///
  /// In en, this message translates to:
  /// **'{count} warning'**
  String log_viewer_warning(Object count);

  /// No description provided for @log_viewer_warnings.
  ///
  /// In en, this message translates to:
  /// **'{count} warnings'**
  String log_viewer_warnings(Object count);

  /// No description provided for @log_viewer_filter_hint.
  ///
  /// In en, this message translates to:
  /// **'Filter the logs…'**
  String get log_viewer_filter_hint;

  /// No description provided for @log_viewer_content_type.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get log_viewer_content_type;

  /// No description provided for @log_viewer_show_all.
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get log_viewer_show_all;

  /// No description provided for @log_viewer_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get log_viewer_level;

  /// No description provided for @log_viewer_error_level.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get log_viewer_error_level;

  /// No description provided for @log_viewer_warning_level.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get log_viewer_warning_level;

  /// No description provided for @log_viewer_success_level.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get log_viewer_success_level;

  /// No description provided for @log_viewer_info_level.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get log_viewer_info_level;

  /// No description provided for @log_viewer_debug_level.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get log_viewer_debug_level;

  /// No description provided for @log_viewer_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get log_viewer_tags;

  /// No description provided for @log_viewer_reset_filters.
  ///
  /// In en, this message translates to:
  /// **'Reset all the filters'**
  String get log_viewer_reset_filters;

  /// No description provided for @log_viewer_open_browser.
  ///
  /// In en, this message translates to:
  /// **'Open in the browser'**
  String get log_viewer_open_browser;

  /// No description provided for @log_viewer_cat_extensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get log_viewer_cat_extensions;

  /// No description provided for @log_viewer_cat_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get log_viewer_cat_watch;

  /// No description provided for @log_viewer_cat_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get log_viewer_cat_manga;

  /// No description provided for @log_viewer_cat_images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get log_viewer_cat_images;

  /// No description provided for @log_viewer_no_file.
  ///
  /// In en, this message translates to:
  /// **'No log file found'**
  String get log_viewer_no_file;

  /// No description provided for @log_viewer_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String log_viewer_saved(Object path);

  /// No description provided for @log_viewer_download_error.
  ///
  /// In en, this message translates to:
  /// **'Download error: {error}'**
  String log_viewer_download_error(Object error);

  /// No description provided for @log_viewer_copied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to the clipboard'**
  String get log_viewer_copied;

  /// No description provided for @log_viewer_mode_extreme.
  ///
  /// In en, this message translates to:
  /// **'⚡ Extreme – everything is logged. RAM +++. Use with care.'**
  String get log_viewer_mode_extreme;

  /// No description provided for @log_viewer_mode_debug_warn.
  ///
  /// In en, this message translates to:
  /// **'⚠ Debug mode active – high RAM usage'**
  String get log_viewer_mode_debug_warn;

  /// No description provided for @browse_diag2_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get browse_diag2_actions;

  /// No description provided for @browse_diag2_status_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get browse_diag2_status_ok;

  /// No description provided for @browse_diag2_status_errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get browse_diag2_status_errors;

  /// No description provided for @browse_diag2_status_running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get browse_diag2_status_running;

  /// No description provided for @browse_diag2_status_idle.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get browse_diag2_status_idle;

  /// No description provided for @browse_diag2_paused_progress.
  ///
  /// In en, this message translates to:
  /// **'Paused — {done} / {total}'**
  String browse_diag2_paused_progress(Object done, Object total);

  /// No description provided for @browse_diag2_running_progress.
  ///
  /// In en, this message translates to:
  /// **'Running — {done} / {total}'**
  String browse_diag2_running_progress(Object done, Object total);

  /// No description provided for @browse_diag2_interrupted_progress.
  ///
  /// In en, this message translates to:
  /// **'Interrupted — {done} / {total}'**
  String browse_diag2_interrupted_progress(Object done, Object total);

  /// No description provided for @browse_diag2_complete_progress.
  ///
  /// In en, this message translates to:
  /// **'Done · {ok} OK · {fail} error(s)'**
  String browse_diag2_complete_progress(Object fail, Object ok);

  /// No description provided for @browse_diag2_sources_selected.
  ///
  /// In en, this message translates to:
  /// **'{count} extensions · {selected} selected'**
  String browse_diag2_sources_selected(Object count, Object selected);

  /// No description provided for @browse_diag2_cancel_interrupt.
  ///
  /// In en, this message translates to:
  /// **'Cancel / interrupt'**
  String get browse_diag2_cancel_interrupt;

  /// No description provided for @browse_diag2_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get browse_diag2_reset;

  /// No description provided for @browse_diag2_copy_report.
  ///
  /// In en, this message translates to:
  /// **'Copy the report {format}'**
  String browse_diag2_copy_report(Object format);

  /// No description provided for @browse_diag2_interrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get browse_diag2_interrupted;

  /// No description provided for @browse_diag2_steps_ok.
  ///
  /// In en, this message translates to:
  /// **'{ok}/{total} steps OK'**
  String browse_diag2_steps_ok(Object ok, Object total);

  /// No description provided for @browse_diag2_step_errors.
  ///
  /// In en, this message translates to:
  /// **' · {count} error(s)'**
  String browse_diag2_step_errors(Object count);

  /// No description provided for @browse_diag2_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get browse_diag2_search;

  /// No description provided for @browse_diag2_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search an extension…'**
  String get browse_diag2_search_hint;

  /// No description provided for @browse_diag2_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get browse_diag2_status;

  /// No description provided for @browse_diag2_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get browse_diag2_sort;

  /// No description provided for @browse_diag2_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get browse_diag2_language;

  /// No description provided for @browse_diag2_selected_for_diag.
  ///
  /// In en, this message translates to:
  /// **'{selected} / {total} extensions selected for the diagnostic'**
  String browse_diag2_selected_for_diag(Object selected, Object total);

  /// No description provided for @browse_diag2_select_all.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get browse_diag2_select_all;

  /// No description provided for @browse_diag2_deselect_all.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get browse_diag2_deselect_all;

  /// No description provided for @browse_diag2_reset_filters.
  ///
  /// In en, this message translates to:
  /// **'Reset the filters'**
  String get browse_diag2_reset_filters;

  /// No description provided for @browse_diag2_sort_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get browse_diag2_sort_name;

  /// No description provided for @browse_diag2_sort_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get browse_diag2_sort_status;

  /// No description provided for @browse_diag2_sort_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get browse_diag2_sort_duration;

  /// No description provided for @browse_diag2_hint_run.
  ///
  /// In en, this message translates to:
  /// **'Run the analysis to test each step (Popular · Latest · Detail · Media).'**
  String get browse_diag2_hint_run;

  /// No description provided for @browse_diag2_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get browse_diag2_unknown;

  /// No description provided for @browse_diag2_video_preview.
  ///
  /// In en, this message translates to:
  /// **'Video preview'**
  String get browse_diag2_video_preview;

  /// No description provided for @browse_diag2_page_preview.
  ///
  /// In en, this message translates to:
  /// **'Page preview'**
  String get browse_diag2_page_preview;

  /// No description provided for @browse_diag2_all_ok.
  ///
  /// In en, this message translates to:
  /// **'All OK'**
  String get browse_diag2_all_ok;

  /// No description provided for @browse_diag2_log_lines_hint.
  ///
  /// In en, this message translates to:
  /// **'{count} log lines — open the detail to read them'**
  String browse_diag2_log_lines_hint(Object count);

  /// No description provided for @browse_diag2_progress_body.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} — {name}'**
  String browse_diag2_progress_body(Object done, Object name, Object total);

  /// No description provided for @browse_diag2_restart_diag.
  ///
  /// In en, this message translates to:
  /// **'Relaunch the diagnostic'**
  String get browse_diag2_restart_diag;

  /// No description provided for @browse_source_pref_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get browse_source_pref_setting;

  /// No description provided for @browse_source_pref_saved_value.
  ///
  /// In en, this message translates to:
  /// **'Saved value'**
  String get browse_source_pref_saved_value;

  /// No description provided for @browse_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get browse_save;

  /// No description provided for @browse_layout_none.
  ///
  /// In en, this message translates to:
  /// **'No layout JSON is available for this extension.'**
  String get browse_layout_none;

  /// No description provided for @browse_layout_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the layout: {error}'**
  String browse_layout_load_failed(Object error);

  /// No description provided for @browse_layout_saved.
  ///
  /// In en, this message translates to:
  /// **'Layout saved on this device.'**
  String get browse_layout_saved;

  /// No description provided for @browse_layout_line_numbers.
  ///
  /// In en, this message translates to:
  /// **'Line numbers'**
  String get browse_layout_line_numbers;

  /// No description provided for @browse_edit_code_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get browse_edit_code_saved;

  /// No description provided for @browse_layout_invalid_json.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String browse_layout_invalid_json(Object error);

  /// No description provided for @browse_layout_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String browse_layout_save_failed(Object error);

  /// No description provided for @browse_layout_view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get browse_layout_view;

  /// No description provided for @browse_layout_alignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get browse_layout_alignment;

  /// No description provided for @browse_layout_schema.
  ///
  /// In en, this message translates to:
  /// **'The layout does not match the expected schema.'**
  String get browse_layout_schema;

  /// No description provided for @browse_layout_title.
  ///
  /// In en, this message translates to:
  /// **'Layout JSON · {name}'**
  String browse_layout_title(Object name);

  /// No description provided for @browse_layout_align_left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get browse_layout_align_left;

  /// No description provided for @browse_layout_align_center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get browse_layout_align_center;

  /// No description provided for @browse_create_extension.
  ///
  /// In en, this message translates to:
  /// **'Create an extension'**
  String get browse_create_extension;

  /// No description provided for @webview_offline_title.
  ///
  /// In en, this message translates to:
  /// **'WebView is not available in the web version'**
  String get webview_offline_title;

  /// No description provided for @webview_offline_desc.
  ///
  /// In en, this message translates to:
  /// **'Sites cannot be displayed in the browser iframe because of X-Frame-Options policies. Open the link directly.'**
  String get webview_offline_desc;

  /// No description provided for @webview_text_size_label.
  ///
  /// In en, this message translates to:
  /// **'Text size: {size}'**
  String webview_text_size_label(Object size);

  /// No description provided for @webview_text_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get webview_text_normal;

  /// No description provided for @webview_text_large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get webview_text_large;

  /// No description provided for @webview_text_xlarge.
  ///
  /// In en, this message translates to:
  /// **'Very large'**
  String get webview_text_xlarge;

  /// No description provided for @webview_text_normal_full.
  ///
  /// In en, this message translates to:
  /// **'Normal text'**
  String get webview_text_normal_full;

  /// No description provided for @webview_text_large_full.
  ///
  /// In en, this message translates to:
  /// **'Large text'**
  String get webview_text_large_full;

  /// No description provided for @webview_text_xlarge_full.
  ///
  /// In en, this message translates to:
  /// **'Very large text'**
  String get webview_text_xlarge_full;

  /// No description provided for @webview_incognito_on.
  ///
  /// In en, this message translates to:
  /// **'Incognito mode enabled — cookies cleared'**
  String get webview_incognito_on;

  /// No description provided for @webview_incognito_off.
  ///
  /// In en, this message translates to:
  /// **'Incognito mode disabled'**
  String get webview_incognito_off;

  /// No description provided for @webview_url_copied_clipboard.
  ///
  /// In en, this message translates to:
  /// **'URL copied to the clipboard'**
  String get webview_url_copied_clipboard;

  /// No description provided for @webview_qr_hint.
  ///
  /// In en, this message translates to:
  /// **'Open the URL in an external QR generator'**
  String get webview_qr_hint;

  /// No description provided for @webview_copy_url.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get webview_copy_url;

  /// No description provided for @webview_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get webview_close;

  /// No description provided for @webview_no_hidden_elements.
  ///
  /// In en, this message translates to:
  /// **'No hidden element to restore'**
  String get webview_no_hidden_elements;

  /// No description provided for @webview_hidden_elements.
  ///
  /// In en, this message translates to:
  /// **'Hidden elements'**
  String get webview_hidden_elements;

  /// No description provided for @webview_restore_all.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get webview_restore_all;

  /// No description provided for @webview_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get webview_restore;

  /// No description provided for @webview_element_selected.
  ///
  /// In en, this message translates to:
  /// **'Element selected'**
  String get webview_element_selected;

  /// No description provided for @webview_what_to_do.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get webview_what_to_do;

  /// No description provided for @webview_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide {selector}'**
  String webview_hide(Object selector);

  /// No description provided for @webview_block_domain.
  ///
  /// In en, this message translates to:
  /// **'Block {domain}'**
  String webview_block_domain(Object domain);

  /// No description provided for @webview_mpv_open_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open in MPV: {error}'**
  String webview_mpv_open_failed(Object error);

  /// No description provided for @webview_address_or_search.
  ///
  /// In en, this message translates to:
  /// **'Address or search'**
  String get webview_address_or_search;

  /// No description provided for @webview_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get webview_clear;

  /// No description provided for @webview_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get webview_open;

  /// No description provided for @webview_no_results_found.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get webview_no_results_found;

  /// No description provided for @webview_find_in_page.
  ///
  /// In en, this message translates to:
  /// **'Find in page'**
  String get webview_find_in_page;

  /// No description provided for @webview_word_or_phrase.
  ///
  /// In en, this message translates to:
  /// **'Word or phrase'**
  String get webview_word_or_phrase;

  /// No description provided for @webview_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get webview_previous;

  /// No description provided for @webview_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get webview_next;

  /// No description provided for @webview_page_source.
  ///
  /// In en, this message translates to:
  /// **'Page source code'**
  String get webview_page_source;

  /// No description provided for @webview_no_source.
  ///
  /// In en, this message translates to:
  /// **'No source code available.'**
  String get webview_no_source;

  /// No description provided for @webview_source_read_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the source code'**
  String get webview_source_read_failed;

  /// No description provided for @webview_url_copied.
  ///
  /// In en, this message translates to:
  /// **'URL copied'**
  String get webview_url_copied;

  /// No description provided for @webview_tap_to_block.
  ///
  /// In en, this message translates to:
  /// **'Tap an element to block it'**
  String get webview_tap_to_block;

  /// No description provided for @webview_cookies_cleared.
  ///
  /// In en, this message translates to:
  /// **'Cookies cleared'**
  String get webview_cookies_cleared;

  /// No description provided for @webview_site_info.
  ///
  /// In en, this message translates to:
  /// **'Site information'**
  String get webview_site_info;

  /// No description provided for @webview_page_actions.
  ///
  /// In en, this message translates to:
  /// **'Page actions'**
  String get webview_page_actions;

  /// No description provided for @webview_controls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get webview_controls;

  /// No description provided for @webview_copy_link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get webview_copy_link;

  /// No description provided for @webview_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get webview_share;

  /// No description provided for @webview_view_source.
  ///
  /// In en, this message translates to:
  /// **'View the source code'**
  String get webview_view_source;

  /// No description provided for @webview_clear_cookies.
  ///
  /// In en, this message translates to:
  /// **'Clear cookies'**
  String get webview_clear_cookies;

  /// No description provided for @webview_translate_page.
  ///
  /// In en, this message translates to:
  /// **'Translate the page'**
  String get webview_translate_page;

  /// No description provided for @webview_download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get webview_download;

  /// No description provided for @webview_create_qr.
  ///
  /// In en, this message translates to:
  /// **'Create a QR code'**
  String get webview_create_qr;

  /// No description provided for @webview_change_orientation.
  ///
  /// In en, this message translates to:
  /// **'Change the orientation'**
  String get webview_change_orientation;

  /// No description provided for @webview_fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get webview_fullscreen;

  /// No description provided for @webview_minimize_window.
  ///
  /// In en, this message translates to:
  /// **'Minimize the window'**
  String get webview_minimize_window;

  /// No description provided for @webview_close_webview.
  ///
  /// In en, this message translates to:
  /// **'Close the WebView'**
  String get webview_close_webview;

  /// No description provided for @webview_adblock.
  ///
  /// In en, this message translates to:
  /// **'Ad blocker'**
  String get webview_adblock;

  /// No description provided for @webview_blocked_count.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String webview_blocked_count(Object count);

  /// No description provided for @webview_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get webview_disabled;

  /// No description provided for @webview_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get webview_enabled;

  /// No description provided for @webview_night_mode.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get webview_night_mode;

  /// No description provided for @webview_desktop_version.
  ///
  /// In en, this message translates to:
  /// **'Desktop version'**
  String get webview_desktop_version;

  /// No description provided for @webview_incognito.
  ///
  /// In en, this message translates to:
  /// **'Private browsing'**
  String get webview_incognito;

  /// No description provided for @webview_tap_to_change.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get webview_tap_to_change;

  /// No description provided for @webview_select_element.
  ///
  /// In en, this message translates to:
  /// **'Select an element'**
  String get webview_select_element;

  /// No description provided for @webview_tap_page_element.
  ///
  /// In en, this message translates to:
  /// **'Tap an element on the page'**
  String get webview_tap_page_element;

  /// No description provided for @webview_reset_rules.
  ///
  /// In en, this message translates to:
  /// **'Reset the rules'**
  String get webview_reset_rules;

  /// No description provided for @webview_blocked_elements_count.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked element(s)'**
  String webview_blocked_elements_count(Object count);

  /// No description provided for @webview_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get webview_refresh;

  /// No description provided for @webview_protection_active.
  ///
  /// In en, this message translates to:
  /// **'Protection on'**
  String get webview_protection_active;

  /// No description provided for @webview_protection_off.
  ///
  /// In en, this message translates to:
  /// **'Protection off'**
  String get webview_protection_off;

  /// No description provided for @webview_pause_site.
  ///
  /// In en, this message translates to:
  /// **'Pause\nthis site'**
  String get webview_pause_site;

  /// No description provided for @webview_pause_30min.
  ///
  /// In en, this message translates to:
  /// **'Pause\n30 min'**
  String get webview_pause_30min;

  /// No description provided for @webview_pick_element_short.
  ///
  /// In en, this message translates to:
  /// **'Sel.\nelem.'**
  String get webview_pick_element_short;

  /// No description provided for @webview_restore_short.
  ///
  /// In en, this message translates to:
  /// **'Restore\n{detail}'**
  String webview_restore_short(Object detail);

  /// No description provided for @webview_elem_short.
  ///
  /// In en, this message translates to:
  /// **'elem.'**
  String get webview_elem_short;

  /// No description provided for @webview_reset_short.
  ///
  /// In en, this message translates to:
  /// **'Reset\nto zero'**
  String get webview_reset_short;

  /// No description provided for @webview_blocked_requests.
  ///
  /// In en, this message translates to:
  /// **'Requests\nblocked'**
  String get webview_blocked_requests;

  /// No description provided for @webview_hidden_elements_short.
  ///
  /// In en, this message translates to:
  /// **'Hidden\nelements'**
  String get webview_hidden_elements_short;

  /// No description provided for @webview_active_rules.
  ///
  /// In en, this message translates to:
  /// **'Active\nrules'**
  String get webview_active_rules;

  /// No description provided for @webview_adblock_settings.
  ///
  /// In en, this message translates to:
  /// **'AdBlock – Settings'**
  String get webview_adblock_settings;

  /// No description provided for @webview_enable_adblock.
  ///
  /// In en, this message translates to:
  /// **'Enable AdBlock'**
  String get webview_enable_adblock;

  /// No description provided for @webview_adblock_desc.
  ///
  /// In en, this message translates to:
  /// **'Blocks ad domains and injects a CSS/DOM filter'**
  String get webview_adblock_desc;

  /// No description provided for @webview_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get webview_statistics;

  /// No description provided for @webview_tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get webview_tools;

  /// No description provided for @webview_select_elements.
  ///
  /// In en, this message translates to:
  /// **'Select elements'**
  String get webview_select_elements;

  /// No description provided for @webview_floating_toolbar.
  ///
  /// In en, this message translates to:
  /// **'Floating toolbar · touch picker'**
  String get webview_floating_toolbar;

  /// No description provided for @webview_reset_rules_desc.
  ///
  /// In en, this message translates to:
  /// **'Resets the counter to 0 and clears custom rules'**
  String get webview_reset_rules_desc;

  /// No description provided for @webview_manually_blocked.
  ///
  /// In en, this message translates to:
  /// **'Manually blocked elements ({count})'**
  String webview_manually_blocked(Object count);

  /// No description provided for @webview_more_elements.
  ///
  /// In en, this message translates to:
  /// **'+{count} elements…'**
  String webview_more_elements(Object count);

  /// No description provided for @webview_play_in_watchtower.
  ///
  /// In en, this message translates to:
  /// **'Play in Watchtower'**
  String get webview_play_in_watchtower;

  /// No description provided for @webview_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get webview_back;

  /// No description provided for @webview_qr_code.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get webview_qr_code;

  /// No description provided for @more_appearance_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, colours, dark mode'**
  String get more_appearance_subtitle;

  /// No description provided for @more_navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get more_navigation;

  /// No description provided for @more_navigation_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tabs, dock, side rail'**
  String get more_navigation_subtitle;

  /// No description provided for @more_reading_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Player, quality, subtitles'**
  String get more_reading_subtitle;

  /// No description provided for @more_customizations.
  ///
  /// In en, this message translates to:
  /// **'Customizations'**
  String get more_customizations;

  /// No description provided for @more_customizations_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Interface, fonts, icons'**
  String get more_customizations_subtitle;

  /// No description provided for @more_backup_restore.
  ///
  /// In en, this message translates to:
  /// **'Backup and Restore'**
  String get more_backup_restore;

  /// No description provided for @more_backup_restore_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Export / import your data'**
  String get more_backup_restore_subtitle;

  /// No description provided for @more_advanced_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced technical options'**
  String get more_advanced_subtitle;

  /// No description provided for @more_about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, credits, licence'**
  String get more_about_subtitle;

  /// No description provided for @more_my_list.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get more_my_list;

  /// No description provided for @more_web_view.
  ///
  /// In en, this message translates to:
  /// **'Web View'**
  String get more_web_view;

  /// No description provided for @nav_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get nav_movies;

  /// No description provided for @nav_series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get nav_series;

  /// No description provided for @nav_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get nav_music;

  /// No description provided for @nav_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get nav_games;

  /// No description provided for @nav_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get nav_search;

  /// No description provided for @nav_plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get nav_plugins;

  /// No description provided for @nav_plugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get nav_plugin;

  /// No description provided for @nav_hub.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get nav_hub;

  /// No description provided for @nav_menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get nav_menu;

  /// No description provided for @nav_discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get nav_discover;

  /// No description provided for @nav_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get nav_marketplace;

  /// No description provided for @nav_schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get nav_schedule;

  /// No description provided for @nav_expand_menu.
  ///
  /// In en, this message translates to:
  /// **'Expand the menu'**
  String get nav_expand_menu;

  /// No description provided for @nav_collapse_menu.
  ///
  /// In en, this message translates to:
  /// **'Collapse the menu'**
  String get nav_collapse_menu;

  /// No description provided for @nav_desc_hub.
  ///
  /// In en, this message translates to:
  /// **'Hub — tap to expand Manga, Watch & Novel tabs'**
  String get nav_desc_hub;

  /// No description provided for @nav_desc_hub_back.
  ///
  /// In en, this message translates to:
  /// **'Tap to go back to Hub view'**
  String get nav_desc_hub_back;

  /// No description provided for @nav_desc_library.
  ///
  /// In en, this message translates to:
  /// **'Library — all your content unified in one page'**
  String get nav_desc_library;

  /// No description provided for @nav_desc_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch — your anime & video library'**
  String get nav_desc_watch;

  /// No description provided for @nav_desc_movies.
  ///
  /// In en, this message translates to:
  /// **'Movies — movie catalogue'**
  String get nav_desc_movies;

  /// No description provided for @nav_desc_series.
  ///
  /// In en, this message translates to:
  /// **'Series — series catalogue'**
  String get nav_desc_series;

  /// No description provided for @nav_desc_manga.
  ///
  /// In en, this message translates to:
  /// **'Manga — your manga & comic library'**
  String get nav_desc_manga;

  /// No description provided for @nav_desc_novel.
  ///
  /// In en, this message translates to:
  /// **'Novel — your light novel library'**
  String get nav_desc_novel;

  /// No description provided for @nav_desc_music.
  ///
  /// In en, this message translates to:
  /// **'Music — stream & download music'**
  String get nav_desc_music;

  /// No description provided for @nav_desc_games.
  ///
  /// In en, this message translates to:
  /// **'Games — browse & download ROMs'**
  String get nav_desc_games;

  /// No description provided for @nav_desc_home.
  ///
  /// In en, this message translates to:
  /// **'Home — discover trending content'**
  String get nav_desc_home;

  /// No description provided for @nav_desc_browse.
  ///
  /// In en, this message translates to:
  /// **'Browse — explore & install sources and extensions'**
  String get nav_desc_browse;

  /// No description provided for @nav_desc_history.
  ///
  /// In en, this message translates to:
  /// **'History — recently read or watched items'**
  String get nav_desc_history;

  /// No description provided for @nav_desc_settings.
  ///
  /// In en, this message translates to:
  /// **'More — settings, about & advanced options'**
  String get nav_desc_settings;

  /// No description provided for @nav_desc_updates.
  ///
  /// In en, this message translates to:
  /// **'Updates — new chapters & episodes available'**
  String get nav_desc_updates;

  /// No description provided for @nav_desc_tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking — sync progress with external trackers'**
  String get nav_desc_tracking;

  /// No description provided for @nav_desc_menu.
  ///
  /// In en, this message translates to:
  /// **'Menu — History, Updates, Schedule & more'**
  String get nav_desc_menu;

  /// No description provided for @history_layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get history_layout;

  /// No description provided for @history_list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get history_list;

  /// No description provided for @history_grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get history_grid;

  /// No description provided for @history_sort_by.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get history_sort_by;

  /// No description provided for @history_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get history_sort_title;

  /// No description provided for @history_period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get history_period;

  /// No description provided for @history_period_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get history_period_all;

  /// No description provided for @history_period_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get history_period_today;

  /// No description provided for @history_period_week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get history_period_week;

  /// No description provided for @history_period_month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get history_period_month;

  /// No description provided for @history_remove_entry.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get history_remove_entry;

  /// No description provided for @download_finished.
  ///
  /// In en, this message translates to:
  /// **'Download finished'**
  String get download_finished;

  /// No description provided for @download_failed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get download_failed;

  /// No description provided for @download_platform_detected.
  ///
  /// In en, this message translates to:
  /// **'Detected platform: {platform}'**
  String download_platform_detected(Object platform);

  /// No description provided for @download_paste_link.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get download_paste_link;

  /// No description provided for @download_resume_all.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get download_resume_all;

  /// No description provided for @download_pause_all.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get download_pause_all;

  /// No description provided for @binary_info_title.
  ///
  /// In en, this message translates to:
  /// **'{name} — Information'**
  String binary_info_title(Object name);

  /// No description provided for @binary_settings_title.
  ///
  /// In en, this message translates to:
  /// **'{name} — Settings'**
  String binary_settings_title(Object name);

  /// No description provided for @binary_source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get binary_source;

  /// No description provided for @binary_source_bundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled (shipped in the APK)'**
  String get binary_source_bundled;

  /// No description provided for @binary_source_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Downloaded from the marketplace'**
  String get binary_source_marketplace;

  /// No description provided for @binary_native_path.
  ///
  /// In en, this message translates to:
  /// **'Native path (jniLibs)'**
  String get binary_native_path;

  /// No description provided for @binary_native_path_bundled.
  ///
  /// In en, this message translates to:
  /// **'Native path (bundled)'**
  String get binary_native_path_bundled;

  /// No description provided for @binary_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get binary_size;

  /// No description provided for @binary_size_unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get binary_size_unknown;

  /// No description provided for @binary_unavailable.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get binary_unavailable;

  /// No description provided for @binary_bundled_note.
  ///
  /// In en, this message translates to:
  /// **'This binary is bundled with the app. No download is required.\nIt will be updated with future app versions.'**
  String get binary_bundled_note;

  /// No description provided for @binary_override_marketplace.
  ///
  /// In en, this message translates to:
  /// **'Override (marketplace)'**
  String get binary_override_marketplace;

  /// No description provided for @binary_override_manual.
  ///
  /// In en, this message translates to:
  /// **'Manual override'**
  String get binary_override_manual;

  /// No description provided for @binary_override_note.
  ///
  /// In en, this message translates to:
  /// **'Drop your own binary into \"Manual override\" — it will be used first.'**
  String get binary_override_note;

  /// No description provided for @binary_uninstall_title.
  ///
  /// In en, this message translates to:
  /// **'Uninstall?'**
  String get binary_uninstall_title;

  /// No description provided for @binary_uninstall_body.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the device?'**
  String binary_uninstall_body(Object name);

  /// No description provided for @binary_uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get binary_uninstall;

  /// No description provided for @binary_badge_bundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled'**
  String get binary_badge_bundled;

  /// No description provided for @binary_badge_installed.
  ///
  /// In en, this message translates to:
  /// **'installed'**
  String get binary_badge_installed;

  /// No description provided for @binary_bundled_short.
  ///
  /// In en, this message translates to:
  /// **'Bundled · {size}'**
  String binary_bundled_short(Object size);

  /// No description provided for @binary_not_installed.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get binary_not_installed;

  /// No description provided for @binary_reinstall.
  ///
  /// In en, this message translates to:
  /// **'Reinstall'**
  String get binary_reinstall;

  /// No description provided for @binary_reinstall_update.
  ///
  /// In en, this message translates to:
  /// **'Reinstall / update'**
  String get binary_reinstall_update;

  /// No description provided for @binary_install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get binary_install;

  /// No description provided for @binary_installed_ok.
  ///
  /// In en, this message translates to:
  /// **'Installed ✓'**
  String get binary_installed_ok;

  /// No description provided for @binary_uninstalled_ok.
  ///
  /// In en, this message translates to:
  /// **'Uninstalled'**
  String get binary_uninstalled_ok;

  /// No description provided for @binary_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get binary_connecting;

  /// No description provided for @binary_extracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get binary_extracting;

  /// No description provided for @binary_empty_download.
  ///
  /// In en, this message translates to:
  /// **'Downloaded file is empty'**
  String get binary_empty_download;

  /// No description provided for @binary_empty_zip.
  ///
  /// In en, this message translates to:
  /// **'Empty ZIP'**
  String get binary_empty_zip;

  /// No description provided for @binary_invalid_install.
  ///
  /// In en, this message translates to:
  /// **'Invalid installation'**
  String get binary_invalid_install;

  /// No description provided for @binary_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String binary_error(Object error);

  /// No description provided for @binary_redirect_no_location.
  ///
  /// In en, this message translates to:
  /// **'Redirect without Location'**
  String get binary_redirect_no_location;

  /// No description provided for @binary_http_status.
  ///
  /// In en, this message translates to:
  /// **'HTTP {status}'**
  String binary_http_status(Object status);

  /// No description provided for @binary_architecture.
  ///
  /// In en, this message translates to:
  /// **'CPU architecture'**
  String get binary_architecture;

  /// No description provided for @binary_detected.
  ///
  /// In en, this message translates to:
  /// **'Detected: {arch}'**
  String binary_detected(Object arch);

  /// No description provided for @binary_detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get binary_detecting;

  /// No description provided for @binary_recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for this device'**
  String get binary_recommended;

  /// No description provided for @binary_reset_auto.
  ///
  /// In en, this message translates to:
  /// **'Reset (auto)'**
  String get binary_reset_auto;

  /// No description provided for @download_resolving_link.
  ///
  /// In en, this message translates to:
  /// **'Resolving the link…'**
  String get download_resolving_link;

  /// No description provided for @download_done_path.
  ///
  /// In en, this message translates to:
  /// **'Done → {path}'**
  String download_done_path(Object path);

  /// No description provided for @error_generic.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error_generic(Object error);

  /// No description provided for @download_paste_link_hint.
  ///
  /// In en, this message translates to:
  /// **'Direct file (.mp4, .m3u8) or a TikTok / Facebook / Instagram page. Pages are resolved automatically.'**
  String get download_paste_link_hint;

  /// No description provided for @download_paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get download_paste;

  /// No description provided for @download_downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get download_downloading;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @music_word.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music_word;

  /// No description provided for @binaries_aria2c_desc.
  ///
  /// In en, this message translates to:
  /// **'High-performance multi-segment HTTP/FTP/Magnet downloader.'**
  String get binaries_aria2c_desc;

  /// No description provided for @binaries_zeus_desc.
  ///
  /// In en, this message translates to:
  /// **'Python runtime that extracts TikTok, Facebook, Instagram… without a watermark.'**
  String get binaries_zeus_desc;

  /// No description provided for @anime_word.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get anime_word;

  /// No description provided for @novels_word.
  ///
  /// In en, this message translates to:
  /// **'Novels'**
  String get novels_word;

  /// No description provided for @onboarding_tagline.
  ///
  /// In en, this message translates to:
  /// **'Anime, manga, novels, music,\nfilms, series and games — all in one place.'**
  String get onboarding_tagline;

  /// No description provided for @onboarding_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboarding_next;

  /// No description provided for @onboarding_start.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboarding_start;

  /// No description provided for @onboarding_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboarding_continue;

  /// No description provided for @onboarding_allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboarding_allow;

  /// No description provided for @onboarding_optional.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL'**
  String get onboarding_optional;

  /// No description provided for @onboarding_watch_verb.
  ///
  /// In en, this message translates to:
  /// **'Watch.'**
  String get onboarding_watch_verb;

  /// No description provided for @onboarding_read_verb.
  ///
  /// In en, this message translates to:
  /// **'Read.'**
  String get onboarding_read_verb;

  /// No description provided for @onboarding_listen_verb.
  ///
  /// In en, this message translates to:
  /// **'Listen.'**
  String get onboarding_listen_verb;

  /// No description provided for @onboarding_all_verb.
  ///
  /// In en, this message translates to:
  /// **'Everything.'**
  String get onboarding_all_verb;

  /// No description provided for @onboarding_slogan_body.
  ///
  /// In en, this message translates to:
  /// **'One place for everything\nyou love.'**
  String get onboarding_slogan_body;

  /// No description provided for @onboarding_storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get onboarding_storage;

  /// No description provided for @onboarding_storage_ios.
  ///
  /// In en, this message translates to:
  /// **'iOS sandbox access — nothing to do.'**
  String get onboarding_storage_ios;

  /// No description provided for @onboarding_storage_android.
  ///
  /// In en, this message translates to:
  /// **'Grant \"access to all files\" for downloads and Smart Library.'**
  String get onboarding_storage_android;

  /// No description provided for @onboarding_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboarding_notifications;

  /// No description provided for @onboarding_notifications_sub.
  ///
  /// In en, this message translates to:
  /// **'Downloads and library updates.'**
  String get onboarding_notifications_sub;

  /// No description provided for @onboarding_install_apps.
  ///
  /// In en, this message translates to:
  /// **'App installs'**
  String get onboarding_install_apps;

  /// No description provided for @onboarding_install_apps_sub.
  ///
  /// In en, this message translates to:
  /// **'Install APK updates straight from the app.'**
  String get onboarding_install_apps_sub;

  /// No description provided for @onboarding_overlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay / PiP'**
  String get onboarding_overlay;

  /// No description provided for @onboarding_overlay_sub.
  ///
  /// In en, this message translates to:
  /// **'Show the video floating over other apps.'**
  String get onboarding_overlay_sub;

  /// No description provided for @onboarding_battery.
  ///
  /// In en, this message translates to:
  /// **'No battery restriction'**
  String get onboarding_battery;

  /// No description provided for @onboarding_battery_sub.
  ///
  /// In en, this message translates to:
  /// **'Stops Android from killing background downloads (Doze, idle).'**
  String get onboarding_battery_sub;

  /// No description provided for @onboarding_device_language.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get onboarding_device_language;

  /// No description provided for @onboarding_device_language_sub.
  ///
  /// In en, this message translates to:
  /// **'No manual choice. The language stays in sync with the system.'**
  String get onboarding_device_language_sub;

  /// No description provided for @onboarding_dubbing.
  ///
  /// In en, this message translates to:
  /// **'Dubbing and subtitles'**
  String get onboarding_dubbing;

  /// No description provided for @onboarding_dubbing_body.
  ///
  /// In en, this message translates to:
  /// **'The audio language and subtitles follow the detected language automatically. You can switch the track during playback.'**
  String get onboarding_dubbing_body;

  /// No description provided for @onboarding_audio_pref.
  ///
  /// In en, this message translates to:
  /// **'Audio preference'**
  String get onboarding_audio_pref;

  /// No description provided for @onboarding_audio_auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get onboarding_audio_auto;

  /// No description provided for @onboarding_audio_pref_sub.
  ///
  /// In en, this message translates to:
  /// **'Dub if available, otherwise the original with subtitles.'**
  String get onboarding_audio_pref_sub;

  /// No description provided for @onboarding_permissions_title.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get onboarding_permissions_title;

  /// No description provided for @onboarding_permissions_body.
  ///
  /// In en, this message translates to:
  /// **'Watchtower needs a few permissions\nto work properly.'**
  String get onboarding_permissions_body;

  /// No description provided for @onboarding_auto_detect.
  ///
  /// In en, this message translates to:
  /// **'Automatic detection'**
  String get onboarding_auto_detect;

  /// No description provided for @onboarding_auto_detect_body.
  ///
  /// In en, this message translates to:
  /// **'Watchtower follows your device language and picks the best-fitting dub automatically.'**
  String get onboarding_auto_detect_body;

  /// No description provided for @reel_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reel_all;

  /// No description provided for @reel_empty.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get reel_empty;

  /// No description provided for @reel_popular_creators.
  ///
  /// In en, this message translates to:
  /// **'Popular creators'**
  String get reel_popular_creators;

  /// No description provided for @reel_followers.
  ///
  /// In en, this message translates to:
  /// **'{count} followers'**
  String reel_followers(Object count);

  /// No description provided for @reel_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get reel_follow;

  /// No description provided for @reel_more_suffix.
  ///
  /// In en, this message translates to:
  /// **'…more'**
  String get reel_more_suffix;

  /// No description provided for @reel_niche_for_you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get reel_niche_for_you;

  /// No description provided for @reel_niche_just_boobs.
  ///
  /// In en, this message translates to:
  /// **'Just Boobs'**
  String get reel_niche_just_boobs;

  /// No description provided for @reel_niche_blowjobs.
  ///
  /// In en, this message translates to:
  /// **'Blowjobs'**
  String get reel_niche_blowjobs;

  /// No description provided for @reel_niche_thick_booty.
  ///
  /// In en, this message translates to:
  /// **'Thick Booty'**
  String get reel_niche_thick_booty;

  /// No description provided for @reel_niche_amateur_girls.
  ///
  /// In en, this message translates to:
  /// **'Amateur Girls'**
  String get reel_niche_amateur_girls;

  /// No description provided for @reel_niche_real_couples.
  ///
  /// In en, this message translates to:
  /// **'Real Couples'**
  String get reel_niche_real_couples;

  /// No description provided for @reel_niche_real_orgasms.
  ///
  /// In en, this message translates to:
  /// **'Real Orgasms'**
  String get reel_niche_real_orgasms;

  /// No description provided for @reel_niche_curvy_chicks.
  ///
  /// In en, this message translates to:
  /// **'Curvy Chicks'**
  String get reel_niche_curvy_chicks;

  /// No description provided for @reel_niche_rough_sex.
  ///
  /// In en, this message translates to:
  /// **'Rough Sex'**
  String get reel_niche_rough_sex;

  /// No description provided for @reel_niche_legal_teens.
  ///
  /// In en, this message translates to:
  /// **'Legal Teens'**
  String get reel_niche_legal_teens;

  /// No description provided for @reel_niche_busty_asians.
  ///
  /// In en, this message translates to:
  /// **'Busty Asians'**
  String get reel_niche_busty_asians;

  /// No description provided for @reel_niche_goth_girls.
  ///
  /// In en, this message translates to:
  /// **'Goth Girls'**
  String get reel_niche_goth_girls;

  /// No description provided for @reel_niche_latinas.
  ///
  /// In en, this message translates to:
  /// **'Latinas'**
  String get reel_niche_latinas;

  /// No description provided for @creator_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get creator_following;

  /// No description provided for @creator_followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get creator_followers;

  /// No description provided for @creator_likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get creator_likes;

  /// No description provided for @creator_no_video.
  ///
  /// In en, this message translates to:
  /// **'No video available'**
  String get creator_no_video;

  /// No description provided for @streaming_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get streaming_resume;

  /// No description provided for @streaming_replay.
  ///
  /// In en, this message translates to:
  /// **'Watch again'**
  String get streaming_replay;

  /// No description provided for @streaming_watch_now.
  ///
  /// In en, this message translates to:
  /// **'Watch now'**
  String get streaming_watch_now;

  /// No description provided for @streaming_view_season.
  ///
  /// In en, this message translates to:
  /// **'View season'**
  String get streaming_view_season;

  /// No description provided for @watch_home_load_failed_retry.
  ///
  /// In en, this message translates to:
  /// **'Load failed · Retry'**
  String get watch_home_load_failed_retry;

  /// No description provided for @nav_hub_tooltip.
  ///
  /// In en, this message translates to:
  /// **'When ON: Manga/Watch/Novel are hidden behind a single Hub button on the dock.'**
  String get nav_hub_tooltip;

  /// No description provided for @nav_hub_title.
  ///
  /// In en, this message translates to:
  /// **'Hub navigation on mobile'**
  String get nav_hub_title;

  /// No description provided for @nav_hub_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Groups Manga · Watch · Novel under one Hub button'**
  String get nav_hub_subtitle;

  /// No description provided for @nav_hub_enabled.
  ///
  /// In en, this message translates to:
  /// **'Hub enabled → Manga, Watch & Novel are now behind the Hub button'**
  String get nav_hub_enabled;

  /// No description provided for @nav_hub_disabled.
  ///
  /// In en, this message translates to:
  /// **'Hub disabled → Manga, Watch & Novel appear separately on the dock'**
  String get nav_hub_disabled;

  /// No description provided for @nav_merge_library_tooltip.
  ///
  /// In en, this message translates to:
  /// **'When ON: a unified Library tab appears on the dock (all types in one page).'**
  String get nav_merge_library_tooltip;

  /// No description provided for @nav_merge_library_title.
  ///
  /// In en, this message translates to:
  /// **'Merge library'**
  String get nav_merge_library_title;

  /// No description provided for @nav_merge_library_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Groups every library into a single tab'**
  String get nav_merge_library_subtitle;

  /// No description provided for @nav_dock_items.
  ///
  /// In en, this message translates to:
  /// **'Dock items'**
  String get nav_dock_items;

  /// No description provided for @nav_item_hidden.
  ///
  /// In en, this message translates to:
  /// **'{name} hidden from the dock'**
  String nav_item_hidden(Object name);

  /// No description provided for @nav_item_shown.
  ///
  /// In en, this message translates to:
  /// **'{name} visible on the dock'**
  String nav_item_shown(Object name);

  /// No description provided for @nav_dock_style.
  ///
  /// In en, this message translates to:
  /// **'Dock style'**
  String get nav_dock_style;

  /// No description provided for @nav_dock_mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get nav_dock_mobile;

  /// No description provided for @nav_dock_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get nav_dock_classic;

  /// No description provided for @nav_dock_classic_desc.
  ///
  /// In en, this message translates to:
  /// **'Full-width bar'**
  String get nav_dock_classic_desc;

  /// No description provided for @nav_dock_classic_set.
  ///
  /// In en, this message translates to:
  /// **'Dock style: Classic full-width bar'**
  String get nav_dock_classic_set;

  /// No description provided for @nav_dock_immersive.
  ///
  /// In en, this message translates to:
  /// **'Immersive'**
  String get nav_dock_immersive;

  /// No description provided for @nav_dock_immersive_desc.
  ///
  /// In en, this message translates to:
  /// **'Glass overlay'**
  String get nav_dock_immersive_desc;

  /// No description provided for @nav_dock_immersive_set.
  ///
  /// In en, this message translates to:
  /// **'Dock style: Immersive glass dock'**
  String get nav_dock_immersive_set;

  /// No description provided for @nav_dock_pc_tablet.
  ///
  /// In en, this message translates to:
  /// **'PC / Tablet'**
  String get nav_dock_pc_tablet;

  /// No description provided for @nav_dock_pc_sidebar.
  ///
  /// In en, this message translates to:
  /// **'PC Sidebar'**
  String get nav_dock_pc_sidebar;

  /// No description provided for @nav_dock_pc_sidebar_desc.
  ///
  /// In en, this message translates to:
  /// **'Side bar'**
  String get nav_dock_pc_sidebar_desc;

  /// No description provided for @nav_dock_pc_sidebar_set.
  ///
  /// In en, this message translates to:
  /// **'PC Sidebar — navigation in a side bar'**
  String get nav_dock_pc_sidebar_set;

  /// No description provided for @nav_sidebar_side_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Which side the PC / TV navigation bar sits on.'**
  String get nav_sidebar_side_tooltip;

  /// No description provided for @nav_sidebar_side.
  ///
  /// In en, this message translates to:
  /// **'Sidebar side'**
  String get nav_sidebar_side;

  /// No description provided for @nav_left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get nav_left;

  /// No description provided for @nav_right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get nav_right;

  /// No description provided for @nav_sidebar_left.
  ///
  /// In en, this message translates to:
  /// **'Sidebar on the left'**
  String get nav_sidebar_left;

  /// No description provided for @nav_sidebar_right.
  ///
  /// In en, this message translates to:
  /// **'Sidebar on the right'**
  String get nav_sidebar_right;

  /// No description provided for @nav_advanced_customisation.
  ///
  /// In en, this message translates to:
  /// **'Advanced customisation'**
  String get nav_advanced_customisation;

  /// No description provided for @nav_icon_size.
  ///
  /// In en, this message translates to:
  /// **'Icon size'**
  String get nav_icon_size;

  /// No description provided for @nav_icon_size_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Changes the size of dock icons. Affects all dock items.'**
  String get nav_icon_size_tooltip;

  /// No description provided for @nav_item_spacing.
  ///
  /// In en, this message translates to:
  /// **'Item spacing'**
  String get nav_item_spacing;

  /// No description provided for @nav_item_spacing_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Controls horizontal gap between each dock item. 0 = no gap, 16 = wide gap.'**
  String get nav_item_spacing_tooltip;

  /// No description provided for @nav_anim_speed.
  ///
  /// In en, this message translates to:
  /// **'Animation speed'**
  String get nav_anim_speed;

  /// No description provided for @nav_anim_speed_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Controls the speed of dock transitions and selection animations.'**
  String get nav_anim_speed_tooltip;

  /// No description provided for @nav_anim_speed_set.
  ///
  /// In en, this message translates to:
  /// **'Animation speed set to {name}'**
  String nav_anim_speed_set(Object name);

  /// No description provided for @nav_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get nav_normal;

  /// No description provided for @nav_show_labels.
  ///
  /// In en, this message translates to:
  /// **'Show labels'**
  String get nav_show_labels;

  /// No description provided for @nav_show_labels_tooltip.
  ///
  /// In en, this message translates to:
  /// **'When ON, text labels appear below each dock icon. When OFF, icons only.'**
  String get nav_show_labels_tooltip;

  /// No description provided for @nav_labels_visible.
  ///
  /// In en, this message translates to:
  /// **'Labels visible → text shown below each dock icon'**
  String get nav_labels_visible;

  /// No description provided for @nav_labels_hidden.
  ///
  /// In en, this message translates to:
  /// **'Labels hidden → icon only mode'**
  String get nav_labels_hidden;

  /// No description provided for @nav_haptic.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get nav_haptic;

  /// No description provided for @nav_haptic_tooltip.
  ///
  /// In en, this message translates to:
  /// **'When ON, the phone vibrates slightly when you switch dock tabs.'**
  String get nav_haptic_tooltip;

  /// No description provided for @nav_haptic_enabled.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback enabled → subtle vibration on tab change'**
  String get nav_haptic_enabled;

  /// No description provided for @nav_haptic_disabled.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback disabled'**
  String get nav_haptic_disabled;

  /// No description provided for @anilist_open_webview.
  ///
  /// In en, this message translates to:
  /// **'Open in WebView'**
  String get anilist_open_webview;

  /// No description provided for @anilist_find_extensions.
  ///
  /// In en, this message translates to:
  /// **'Find on Extensions'**
  String get anilist_find_extensions;

  /// No description provided for @anilist_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get anilist_share;

  /// No description provided for @anilist_report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get anilist_report;

  /// No description provided for @anilist_add_to_library.
  ///
  /// In en, this message translates to:
  /// **'Add to Library'**
  String get anilist_add_to_library;

  /// No description provided for @anilist_no_related.
  ///
  /// In en, this message translates to:
  /// **'No related media'**
  String get anilist_no_related;

  /// No description provided for @anilist_no_characters.
  ///
  /// In en, this message translates to:
  /// **'No characters'**
  String get anilist_no_characters;

  /// No description provided for @anilist_no_staff.
  ///
  /// In en, this message translates to:
  /// **'No staff information'**
  String get anilist_no_staff;

  /// No description provided for @anilist_connect_reviews.
  ///
  /// In en, this message translates to:
  /// **'Connect to read reviews'**
  String get anilist_connect_reviews;

  /// No description provided for @anilist_reviews_hint.
  ///
  /// In en, this message translates to:
  /// **'AniList reviews are available after you connect your AniList account.'**
  String get anilist_reviews_hint;

  /// No description provided for @anilist_connect_threads.
  ///
  /// In en, this message translates to:
  /// **'Connect to view threads'**
  String get anilist_connect_threads;

  /// No description provided for @anilist_threads_hint.
  ///
  /// In en, this message translates to:
  /// **'Join the AniList discussion after connecting your AniList account.'**
  String get anilist_threads_hint;

  /// No description provided for @anilist_no_recommendations.
  ///
  /// In en, this message translates to:
  /// **'No recommendations'**
  String get anilist_no_recommendations;

  /// No description provided for @anilist_no_watch_order.
  ///
  /// In en, this message translates to:
  /// **'No watch order available'**
  String get anilist_no_watch_order;

  /// No description provided for @anilist_view_full_profile.
  ///
  /// In en, this message translates to:
  /// **'View full profile on AniList'**
  String get anilist_view_full_profile;

  /// No description provided for @anilist_connect.
  ///
  /// In en, this message translates to:
  /// **'Connect to AniList'**
  String get anilist_connect;

  /// No description provided for @anilist_no_statistics.
  ///
  /// In en, this message translates to:
  /// **'No statistics available'**
  String get anilist_no_statistics;

  /// No description provided for @anilist_no_activities.
  ///
  /// In en, this message translates to:
  /// **'No recent activities'**
  String get anilist_no_activities;

  /// No description provided for @anilist_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get anilist_total;

  /// No description provided for @anilist_watched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get anilist_watched;

  /// No description provided for @anilist_remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get anilist_remaining;

  /// No description provided for @anilist_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get anilist_type;

  /// No description provided for @anilist_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get anilist_rating;

  /// No description provided for @anilist_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get anilist_format;

  /// No description provided for @anilist_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get anilist_status;

  /// No description provided for @anilist_popularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get anilist_popularity;

  /// No description provided for @anilist_episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get anilist_episodes;

  /// No description provided for @anilist_chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get anilist_chapters;

  /// No description provided for @anilist_season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get anilist_season;

  /// No description provided for @anilist_source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get anilist_source;

  /// No description provided for @anilist_mean_score.
  ///
  /// In en, this message translates to:
  /// **'Mean Score'**
  String get anilist_mean_score;

  /// No description provided for @anilist_favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get anilist_favourites;

  /// No description provided for @anilist_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get anilist_duration;

  /// No description provided for @anilist_start_date.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get anilist_start_date;

  /// No description provided for @anilist_end_date.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get anilist_end_date;

  /// No description provided for @anilist_studio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get anilist_studio;

  /// No description provided for @anilist_genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get anilist_genres;

  /// No description provided for @anilist_relations.
  ///
  /// In en, this message translates to:
  /// **'Relations'**
  String get anilist_relations;

  /// No description provided for @anilist_recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get anilist_recommendations;

  /// No description provided for @anilist_global.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get anilist_global;

  /// No description provided for @anilist_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get anilist_following;

  /// No description provided for @anilist_self.
  ///
  /// In en, this message translates to:
  /// **'Self'**
  String get anilist_self;

  /// No description provided for @anilist_score_distribution.
  ///
  /// In en, this message translates to:
  /// **'Score Distribution'**
  String get anilist_score_distribution;

  /// No description provided for @anilist_status_distribution.
  ///
  /// In en, this message translates to:
  /// **'Status Distribution'**
  String get anilist_status_distribution;

  /// No description provided for @anilist_episodes_anime_only.
  ///
  /// In en, this message translates to:
  /// **'Episode data is only available for anime'**
  String get anilist_episodes_anime_only;

  /// No description provided for @anilist_episodes_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load episodes: {error}'**
  String anilist_episodes_load_failed(Object error);

  /// No description provided for @anilist_no_episodes.
  ///
  /// In en, this message translates to:
  /// **'No episode data available yet'**
  String get anilist_no_episodes;

  /// No description provided for @anilist_episode_filters.
  ///
  /// In en, this message translates to:
  /// **'Episode filters'**
  String get anilist_episode_filters;

  /// No description provided for @anilist_regular_episodes.
  ///
  /// In en, this message translates to:
  /// **'Regular episodes'**
  String get anilist_regular_episodes;

  /// No description provided for @anilist_include_specials.
  ///
  /// In en, this message translates to:
  /// **'Include specials'**
  String get anilist_include_specials;

  /// No description provided for @anilist_episodes_with_synopsis.
  ///
  /// In en, this message translates to:
  /// **'Episodes with synopsis'**
  String get anilist_episodes_with_synopsis;

  /// No description provided for @anilist_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get anilist_watch;

  /// No description provided for @anilist_local_library.
  ///
  /// In en, this message translates to:
  /// **'Local Library'**
  String get anilist_local_library;

  /// No description provided for @anilist_local_library_hint.
  ///
  /// In en, this message translates to:
  /// **'Play from files already in your library'**
  String get anilist_local_library_hint;

  /// No description provided for @anilist_extensions_online.
  ///
  /// In en, this message translates to:
  /// **'Extensions — Online'**
  String get anilist_extensions_online;

  /// No description provided for @anilist_extensions_online_hint.
  ///
  /// In en, this message translates to:
  /// **'Smart search via your installed anime sources'**
  String get anilist_extensions_online_hint;

  /// No description provided for @anilist_manual_url.
  ///
  /// In en, this message translates to:
  /// **'Manual URL'**
  String get anilist_manual_url;

  /// No description provided for @anilist_manual_url_hint.
  ///
  /// In en, this message translates to:
  /// **'Paste a direct stream link to watch'**
  String get anilist_manual_url_hint;

  /// No description provided for @anilist_tab_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get anilist_tab_overview;

  /// No description provided for @anilist_tab_episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get anilist_tab_episodes;

  /// No description provided for @anilist_tab_related.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get anilist_tab_related;

  /// No description provided for @anilist_tab_characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get anilist_tab_characters;

  /// No description provided for @anilist_tab_staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get anilist_tab_staff;

  /// No description provided for @anilist_tab_reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get anilist_tab_reviews;

  /// No description provided for @anilist_tab_threads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get anilist_tab_threads;

  /// No description provided for @anilist_tab_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get anilist_tab_following;

  /// No description provided for @anilist_tab_activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get anilist_tab_activities;

  /// No description provided for @anilist_tab_recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get anilist_tab_recommendations;

  /// No description provided for @anilist_tab_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get anilist_tab_statistics;

  /// No description provided for @anilist_tab_watch_order.
  ///
  /// In en, this message translates to:
  /// **'Watch Order'**
  String get anilist_tab_watch_order;

  /// No description provided for @common_see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get common_see_all;

  /// No description provided for @anime_feed_featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get anime_feed_featured;

  /// No description provided for @anime_feed_explore_world.
  ///
  /// In en, this message translates to:
  /// **'Explore the world'**
  String get anime_feed_explore_world;

  /// No description provided for @anime_feed_top10.
  ///
  /// In en, this message translates to:
  /// **'Top 10 Anime'**
  String get anime_feed_top10;

  /// No description provided for @anime_feed_top10_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Highest rated on AniList'**
  String get anime_feed_top10_subtitle;

  /// No description provided for @anime_feed_top_anime.
  ///
  /// In en, this message translates to:
  /// **'Top Anime'**
  String get anime_feed_top_anime;

  /// No description provided for @anime_feed_explore_tags.
  ///
  /// In en, this message translates to:
  /// **'Explore by tags'**
  String get anime_feed_explore_tags;

  /// No description provided for @anime_feed_discover.
  ///
  /// In en, this message translates to:
  /// **'To discover'**
  String get anime_feed_discover;

  /// No description provided for @anime_feed_anime_movies.
  ///
  /// In en, this message translates to:
  /// **'Anime movies'**
  String get anime_feed_anime_movies;

  /// No description provided for @anime_feed_trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get anime_feed_trending;

  /// No description provided for @anime_feed_collections.
  ///
  /// In en, this message translates to:
  /// **'Collections to discover'**
  String get anime_feed_collections;

  /// No description provided for @anime_feed_anime_collections.
  ///
  /// In en, this message translates to:
  /// **'Anime collections'**
  String get anime_feed_anime_collections;

  /// No description provided for @anime_feed_franchises.
  ///
  /// In en, this message translates to:
  /// **'Cult franchises'**
  String get anime_feed_franchises;

  /// No description provided for @anime_feed_anime_franchises.
  ///
  /// In en, this message translates to:
  /// **'Anime franchises'**
  String get anime_feed_anime_franchises;

  /// No description provided for @anime_feed_featured_studio.
  ///
  /// In en, this message translates to:
  /// **'Featured studio'**
  String get anime_feed_featured_studio;

  /// No description provided for @anime_feed_popular_studios.
  ///
  /// In en, this message translates to:
  /// **'Popular studios'**
  String get anime_feed_popular_studios;

  /// No description provided for @anime_feed_featured_genres.
  ///
  /// In en, this message translates to:
  /// **'Featured genres'**
  String get anime_feed_featured_genres;

  /// No description provided for @anime_feed_genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get anime_feed_genres;

  /// No description provided for @anime_feed_catalogue.
  ///
  /// In en, this message translates to:
  /// **'Anime catalogue'**
  String get anime_feed_catalogue;

  /// No description provided for @anime_feed_popular_anime.
  ///
  /// In en, this message translates to:
  /// **'Popular anime'**
  String get anime_feed_popular_anime;

  /// No description provided for @discover_row_trending_manga.
  ///
  /// In en, this message translates to:
  /// **'Trending Manga'**
  String get discover_row_trending_manga;

  /// No description provided for @discover_row_popular_manga.
  ///
  /// In en, this message translates to:
  /// **'Popular Manga'**
  String get discover_row_popular_manga;

  /// No description provided for @discover_row_origins.
  ///
  /// In en, this message translates to:
  /// **'Origins'**
  String get discover_row_origins;

  /// No description provided for @discover_row_genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get discover_row_genres;

  /// No description provided for @discover_row_trending_manhwa.
  ///
  /// In en, this message translates to:
  /// **'Trending Manhwa'**
  String get discover_row_trending_manhwa;

  /// No description provided for @discover_row_trending_manhua.
  ///
  /// In en, this message translates to:
  /// **'Trending Manhua'**
  String get discover_row_trending_manhua;

  /// No description provided for @discover_row_highly_rated.
  ///
  /// In en, this message translates to:
  /// **'Highly Rated Completed'**
  String get discover_row_highly_rated;

  /// No description provided for @discover_row_top_rated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get discover_row_top_rated;

  /// No description provided for @discover_row_action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get discover_row_action;

  /// No description provided for @discover_row_romance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get discover_row_romance;

  /// No description provided for @discover_row_fantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get discover_row_fantasy;

  /// No description provided for @discover_row_slice_of_life.
  ///
  /// In en, this message translates to:
  /// **'Slice of Life'**
  String get discover_row_slice_of_life;

  /// No description provided for @discover_row_trending_novels.
  ///
  /// In en, this message translates to:
  /// **'Trending Light Novels'**
  String get discover_row_trending_novels;

  /// No description provided for @discover_row_popular_novels.
  ///
  /// In en, this message translates to:
  /// **'Popular Novels'**
  String get discover_row_popular_novels;

  /// No description provided for @game_install_hint.
  ///
  /// In en, this message translates to:
  /// **'Install game extensions to browse and download ROMs from sites like RomsFun, Vimm\'s Lair, and more.'**
  String get game_install_hint;

  /// No description provided for @game_feature_download_title.
  ///
  /// In en, this message translates to:
  /// **'Download ROMs'**
  String get game_feature_download_title;

  /// No description provided for @game_feature_download_subtitle.
  ///
  /// In en, this message translates to:
  /// **'PSP · PS2 · GBA · SNES · N64 and more'**
  String get game_feature_download_subtitle;

  /// No description provided for @game_feature_emulators_title.
  ///
  /// In en, this message translates to:
  /// **'Launch Emulators'**
  String get game_feature_emulators_title;

  /// No description provided for @game_feature_emulators_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Integrates with installed emulators'**
  String get game_feature_emulators_subtitle;

  /// No description provided for @game_feature_track_title.
  ///
  /// In en, this message translates to:
  /// **'Track your games'**
  String get game_feature_track_title;

  /// No description provided for @game_feature_track_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as played, playing, or wish list'**
  String get game_feature_track_subtitle;

  /// No description provided for @game_browse_extensions.
  ///
  /// In en, this message translates to:
  /// **'Browse Game Extensions'**
  String get game_browse_extensions;

  /// No description provided for @game_platform_games.
  ///
  /// In en, this message translates to:
  /// **'{name} Games'**
  String game_platform_games(Object name);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @common_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get common_select;

  /// No description provided for @common_ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get common_ascending;

  /// No description provided for @common_descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get common_descending;

  /// No description provided for @auto_backup_title.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get auto_backup_title;

  /// No description provided for @auto_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Regularly saves the library, the settings, the extensions and the cache in a folder that survives uninstalling.'**
  String get auto_backup_subtitle;

  /// No description provided for @auto_backup_location.
  ///
  /// In en, this message translates to:
  /// **'Backup location'**
  String get auto_backup_location;

  /// No description provided for @auto_backup_copy_path.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get auto_backup_copy_path;

  /// No description provided for @auto_backup_path_copied.
  ///
  /// In en, this message translates to:
  /// **'Path copied.'**
  String get auto_backup_path_copied;

  /// No description provided for @auto_backup_last.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get auto_backup_last;

  /// No description provided for @auto_backup_on_disk.
  ///
  /// In en, this message translates to:
  /// **'Backup present on disk'**
  String get auto_backup_on_disk;

  /// No description provided for @auto_backup_now.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get auto_backup_now;

  /// No description provided for @auto_backup_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get auto_backup_restore;

  /// No description provided for @auto_backup_done.
  ///
  /// In en, this message translates to:
  /// **'Backup complete.'**
  String get auto_backup_done;

  /// No description provided for @auto_backup_restored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Restart the app to reload the database.'**
  String get auto_backup_restored;

  /// No description provided for @auto_backup_none.
  ///
  /// In en, this message translates to:
  /// **'No backup to restore.'**
  String get auto_backup_none;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @queue_src.
  ///
  /// In en, this message translates to:
  /// **'Src'**
  String get queue_src;

  /// No description provided for @recommendations_title.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations_title;

  /// No description provided for @recommendations_algorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get recommendations_algorithm;

  /// No description provided for @recommendations_algo_content_title.
  ///
  /// In en, this message translates to:
  /// **'Content-Based Filtering'**
  String get recommendations_algo_content_title;

  /// No description provided for @recommendations_algo_content_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Compares genre, themes and synopsis directly. Fast and offline.'**
  String get recommendations_algo_content_subtitle;

  /// No description provided for @recommendations_algo_collaborative_title.
  ///
  /// In en, this message translates to:
  /// **'Collaborative Filtering'**
  String get recommendations_algo_collaborative_title;

  /// No description provided for @recommendations_algo_collaborative_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommends based on what similar users enjoyed. Requires network.'**
  String get recommendations_algo_collaborative_subtitle;

  /// No description provided for @recommendations_algo_hybrid_title.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get recommendations_algo_hybrid_title;

  /// No description provided for @recommendations_algo_hybrid_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Combines content-based and collaborative for best accuracy.'**
  String get recommendations_algo_hybrid_subtitle;

  /// No description provided for @recommendations_weights_hint.
  ///
  /// In en, this message translates to:
  /// **'Adjust how much each factor influences recommendations.'**
  String get recommendations_weights_hint;

  /// No description provided for @extension_cookies_title.
  ///
  /// In en, this message translates to:
  /// **'Extension cookies'**
  String get extension_cookies_title;

  /// No description provided for @extension_cookies_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get extension_cookies_refresh;

  /// No description provided for @extension_cookies_paste.
  ///
  /// In en, this message translates to:
  /// **'Paste from the clipboard'**
  String get extension_cookies_paste;

  /// No description provided for @extension_cookies_deleted.
  ///
  /// In en, this message translates to:
  /// **'Cookie deleted for {host}'**
  String extension_cookies_deleted(Object host);

  /// No description provided for @common_classification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get common_classification;

  /// No description provided for @log_viewer_date_on.
  ///
  /// In en, this message translates to:
  /// **'Date · ON'**
  String get log_viewer_date_on;

  /// No description provided for @log_viewer_date_off.
  ///
  /// In en, this message translates to:
  /// **'Date · OFF'**
  String get log_viewer_date_off;

  /// No description provided for @log_viewer_collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get log_viewer_collapse;

  /// No description provided for @log_viewer_errors_only.
  ///
  /// In en, this message translates to:
  /// **'Errors / warnings only'**
  String get log_viewer_errors_only;

  /// No description provided for @novel_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get novel_theme_dark;

  /// No description provided for @novel_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get novel_theme_light;

  /// No description provided for @novel_theme_sepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get novel_theme_sepia;

  /// No description provided for @novel_padding.
  ///
  /// In en, this message translates to:
  /// **'Padding'**
  String get novel_padding;

  /// No description provided for @novel_search_in_source.
  ///
  /// In en, this message translates to:
  /// **'Search in {name}…'**
  String novel_search_in_source(Object name);

  /// No description provided for @novel_the_source.
  ///
  /// In en, this message translates to:
  /// **'the source'**
  String get novel_the_source;

  /// No description provided for @novel_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get novel_popular;

  /// No description provided for @novel_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get novel_recent;

  /// No description provided for @novel_latest_chapters.
  ///
  /// In en, this message translates to:
  /// **'Latest chapters'**
  String get novel_latest_chapters;

  /// No description provided for @novel_explore_catalogue.
  ///
  /// In en, this message translates to:
  /// **'Explore the catalogue'**
  String get novel_explore_catalogue;

  /// No description provided for @novel_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search a novel…'**
  String get novel_search_hint;

  /// No description provided for @tmdb_vote_count.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String tmdb_vote_count(Object count);

  /// No description provided for @tmdb_watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get tmdb_watch;

  /// No description provided for @tmdb_wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers'**
  String get tmdb_wallpapers;

  /// No description provided for @tmdb_cast_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Cast unavailable.'**
  String get tmdb_cast_unavailable;

  /// No description provided for @schedule_anime_hidden.
  ///
  /// In en, this message translates to:
  /// **'Anime library hidden'**
  String get schedule_anime_hidden;

  /// No description provided for @schedule_week_start.
  ///
  /// In en, this message translates to:
  /// **'Week start'**
  String get schedule_week_start;

  /// No description provided for @schedule_monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get schedule_monday;

  /// No description provided for @schedule_sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get schedule_sunday;

  /// No description provided for @schedule_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get schedule_status;

  /// No description provided for @schedule_paused.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get schedule_paused;

  /// No description provided for @schedule_mark_watched.
  ///
  /// In en, this message translates to:
  /// **'Mark the watched episodes'**
  String get schedule_mark_watched;

  /// No description provided for @schedule_disable_transitions.
  ///
  /// In en, this message translates to:
  /// **'Disable the image transitions'**
  String get schedule_disable_transitions;

  /// No description provided for @schedule_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String schedule_error(Object error);

  /// No description provided for @schedule_empty.
  ///
  /// In en, this message translates to:
  /// **'No release this month'**
  String get schedule_empty;

  /// No description provided for @nav_merge_library_enabled.
  ///
  /// In en, this message translates to:
  /// **'Merge library enabled → libraries grouped together'**
  String get nav_merge_library_enabled;

  /// No description provided for @nav_merge_library_disabled.
  ///
  /// In en, this message translates to:
  /// **'Merge library disabled → libraries separated'**
  String get nav_merge_library_disabled;

  /// No description provided for @nav_fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get nav_fast;

  /// No description provided for @tmdb_cast_and_crew.
  ///
  /// In en, this message translates to:
  /// **'Cast and crew'**
  String get tmdb_cast_and_crew;

  /// No description provided for @tmdb_crew.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get tmdb_crew;

  /// No description provided for @tmdb_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get tmdb_about;

  /// No description provided for @tmdb_no_description.
  ///
  /// In en, this message translates to:
  /// **'No description available.'**
  String get tmdb_no_description;

  /// No description provided for @tmdb_author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get tmdb_author;

  /// No description provided for @tmdb_artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get tmdb_artist;

  /// No description provided for @tmdb_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tmdb_tags;

  /// No description provided for @tmdb_biography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get tmdb_biography;

  /// No description provided for @tmdb_images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get tmdb_images;

  /// No description provided for @tmdb_social_links.
  ///
  /// In en, this message translates to:
  /// **'Social media links'**
  String get tmdb_social_links;

  /// No description provided for @tmdb_x.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get tmdb_x;

  /// No description provided for @tmdb_website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get tmdb_website;

  /// No description provided for @tmdb_no_link.
  ///
  /// In en, this message translates to:
  /// **'No link available.'**
  String get tmdb_no_link;

  /// No description provided for @tmdb_no_info.
  ///
  /// In en, this message translates to:
  /// **'No information available.'**
  String get tmdb_no_info;

  /// No description provided for @similar_best_matches.
  ///
  /// In en, this message translates to:
  /// **'Best matches'**
  String get similar_best_matches;

  /// No description provided for @similar_sort_title.
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get similar_sort_title;

  /// No description provided for @similar_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load similar titles.'**
  String get similar_load_failed;

  /// No description provided for @manage_categories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manage_categories;

  /// No description provided for @library_entries_count.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String library_entries_count(Object count);

  /// No description provided for @library_reading_count.
  ///
  /// In en, this message translates to:
  /// **'{count} reading'**
  String library_reading_count(Object count);

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get theme_system;

  /// No description provided for @torrent_address.
  ///
  /// In en, this message translates to:
  /// **'TorrServer address'**
  String get torrent_address;

  /// No description provided for @torrent_streaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get torrent_streaming;

  /// No description provided for @smart_scan_failed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String smart_scan_failed(Object error);

  /// No description provided for @smart_index_unreadable.
  ///
  /// In en, this message translates to:
  /// **'Unreadable index: {error}'**
  String smart_index_unreadable(Object error);

  /// No description provided for @smart_search_changes.
  ///
  /// In en, this message translates to:
  /// **'Search for changes'**
  String get smart_search_changes;

  /// No description provided for @smart_verify_storage.
  ///
  /// In en, this message translates to:
  /// **'Check all storage'**
  String get smart_verify_storage;

  /// No description provided for @update_install_now.
  ///
  /// In en, this message translates to:
  /// **'Install now'**
  String get update_install_now;

  /// No description provided for @update_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get update_close;

  /// No description provided for @update_continue_background.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get update_continue_background;

  /// No description provided for @update_cancel_download.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get update_cancel_download;

  /// No description provided for @update_not_now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get update_not_now;

  /// No description provided for @discover_change_extension.
  ///
  /// In en, this message translates to:
  /// **'Change extension'**
  String get discover_change_extension;

  /// No description provided for @about_link_github.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get about_link_github;

  /// No description provided for @about_link_discord.
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get about_link_discord;

  /// No description provided for @about_link_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get about_link_email;

  /// No description provided for @about_feature_http_ftp.
  ///
  /// In en, this message translates to:
  /// **'HTTP / FTP'**
  String get about_feature_http_ftp;

  /// No description provided for @about_feature_bittorrent.
  ///
  /// In en, this message translates to:
  /// **'BitTorrent'**
  String get about_feature_bittorrent;

  /// No description provided for @about_feature_magnet.
  ///
  /// In en, this message translates to:
  /// **'Magnet'**
  String get about_feature_magnet;

  /// No description provided for @silent_install_active_title.
  ///
  /// In en, this message translates to:
  /// **'Automatic install active'**
  String get silent_install_active_title;

  /// No description provided for @silent_install_active_body.
  ///
  /// In en, this message translates to:
  /// **'Setup is already complete.\n\nWatchtower updates install automatically in the background.'**
  String get silent_install_active_body;

  /// No description provided for @silent_install_shizuku_title.
  ///
  /// In en, this message translates to:
  /// **'Shizuku required'**
  String get silent_install_shizuku_title;

  /// No description provided for @silent_install_shizuku_body.
  ///
  /// In en, this message translates to:
  /// **'Shizuku is not running.\n\n1. Install Shizuku from the Play Store.\n2. Enable it via wireless debugging (ADB).\n3. Come back here and tap again.'**
  String get silent_install_shizuku_body;

  /// No description provided for @silent_install_setup_title.
  ///
  /// In en, this message translates to:
  /// **'One-time setup'**
  String get silent_install_setup_title;

  /// No description provided for @silent_install_setup_body.
  ///
  /// In en, this message translates to:
  /// **'Watchtower will ask Shizuku for permission to install packages.\n\nThis step is only needed once.'**
  String get silent_install_setup_body;

  /// No description provided for @silent_install_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get silent_install_continue;

  /// No description provided for @silent_install_enabled_title.
  ///
  /// In en, this message translates to:
  /// **'Automatic install enabled'**
  String get silent_install_enabled_title;

  /// No description provided for @silent_install_enabled_body.
  ///
  /// In en, this message translates to:
  /// **'Done! Future Watchtower updates will install automatically in the background.\n\nShizuku is no longer needed.'**
  String get silent_install_enabled_body;

  /// No description provided for @silent_install_understood.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get silent_install_understood;

  /// No description provided for @tmdb_facebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get tmdb_facebook;

  /// No description provided for @tmdb_instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get tmdb_instagram;

  /// No description provided for @tmdb_imdb.
  ///
  /// In en, this message translates to:
  /// **'IMDb'**
  String get tmdb_imdb;

  /// No description provided for @media_badge_video_language.
  ///
  /// In en, this message translates to:
  /// **'Video language'**
  String get media_badge_video_language;

  /// No description provided for @media_badge_video_language_desc.
  ///
  /// In en, this message translates to:
  /// **'Flag of the country linked to the published language.'**
  String get media_badge_video_language_desc;

  /// No description provided for @media_badge_censorship.
  ///
  /// In en, this message translates to:
  /// **'Censorship'**
  String get media_badge_censorship;

  /// No description provided for @media_badge_censorship_desc.
  ///
  /// In en, this message translates to:
  /// **'Shows whether the video is censored, uncensored or leaked.'**
  String get media_badge_censorship_desc;

  /// No description provided for @media_badge_subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get media_badge_subtitles;

  /// No description provided for @media_badge_subtitles_desc.
  ///
  /// In en, this message translates to:
  /// **'Flag of the language of the available subtitles.'**
  String get media_badge_subtitles_desc;

  /// No description provided for @media_badge_dubbing.
  ///
  /// In en, this message translates to:
  /// **'Dubbing'**
  String get media_badge_dubbing;

  /// No description provided for @media_badge_dubbing_desc.
  ///
  /// In en, this message translates to:
  /// **'Flag of the language of the available dubbing.'**
  String get media_badge_dubbing_desc;

  /// No description provided for @media_top10_week.
  ///
  /// In en, this message translates to:
  /// **'Top 10 this week'**
  String get media_top10_week;

  /// No description provided for @browse_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get browse_all;

  /// No description provided for @browse_diag_nsfw.
  ///
  /// In en, this message translates to:
  /// **'NSFW'**
  String get browse_diag_nsfw;

  /// No description provided for @browse_diag_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get browse_diag_ok;

  /// No description provided for @queue_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get queue_total;

  /// No description provided for @manga_stat_followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get manga_stat_followers;

  /// No description provided for @manga_stat_titles.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get manga_stat_titles;

  /// No description provided for @manga_stat_staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get manga_stat_staff;

  /// No description provided for @download_link_empty.
  ///
  /// In en, this message translates to:
  /// **'Empty link'**
  String get download_link_empty;

  /// No description provided for @download_link_empty_file.
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get download_link_empty_file;

  /// No description provided for @download_link_http_error.
  ///
  /// In en, this message translates to:
  /// **'HTTP {code}'**
  String download_link_http_error(Object code);

  /// No description provided for @download_link_failed_detail.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {detail}'**
  String download_link_failed_detail(Object detail);

  /// No description provided for @browse_source_pref_default_quality.
  ///
  /// In en, this message translates to:
  /// **'Default video quality'**
  String get browse_source_pref_default_quality;

  /// No description provided for @browse_source_pref_default_quality_summary.
  ///
  /// In en, this message translates to:
  /// **'Priority used when several qualities are available.'**
  String get browse_source_pref_default_quality_summary;

  /// No description provided for @browse_source_pref_fallback_quality.
  ///
  /// In en, this message translates to:
  /// **'Fallback quality'**
  String get browse_source_pref_fallback_quality;

  /// No description provided for @browse_source_pref_fallback_quality_summary.
  ///
  /// In en, this message translates to:
  /// **'Choice applied when the requested quality is unavailable.'**
  String get browse_source_pref_fallback_quality_summary;

  /// No description provided for @browse_source_pref_languages.
  ///
  /// In en, this message translates to:
  /// **'Preferred languages'**
  String get browse_source_pref_languages;

  /// No description provided for @browse_source_pref_languages_summary.
  ///
  /// In en, this message translates to:
  /// **'Select one or more languages offered by the source.'**
  String get browse_source_pref_languages_summary;

  /// No description provided for @browse_source_pref_keep_session.
  ///
  /// In en, this message translates to:
  /// **'Keep the session'**
  String get browse_source_pref_keep_session;

  /// No description provided for @browse_source_pref_keep_session_summary.
  ///
  /// In en, this message translates to:
  /// **'Keep the session and cookies for requests and the WebView.'**
  String get browse_source_pref_keep_session_summary;

  /// No description provided for @browse_source_pref_quality_higher.
  ///
  /// In en, this message translates to:
  /// **'Immediately higher quality'**
  String get browse_source_pref_quality_higher;

  /// No description provided for @browse_source_pref_quality_lower.
  ///
  /// In en, this message translates to:
  /// **'Immediately lower quality'**
  String get browse_source_pref_quality_lower;

  /// No description provided for @browse_source_pref_all_languages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get browse_source_pref_all_languages;

  /// No description provided for @discover_origin_japan.
  ///
  /// In en, this message translates to:
  /// **'Manga (JP)'**
  String get discover_origin_japan;

  /// No description provided for @discover_origin_korea.
  ///
  /// In en, this message translates to:
  /// **'Manhwa (KR)'**
  String get discover_origin_korea;

  /// No description provided for @discover_origin_china.
  ///
  /// In en, this message translates to:
  /// **'Manhua (CN)'**
  String get discover_origin_china;

  /// No description provided for @discover_origin_webtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get discover_origin_webtoon;

  /// No description provided for @gallery_pick_component.
  ///
  /// In en, this message translates to:
  /// **'Choose a component'**
  String get gallery_pick_component;

  /// No description provided for @gallery_reset_filters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get gallery_reset_filters;

  /// No description provided for @gallery_close.
  ///
  /// In en, this message translates to:
  /// **'Close the gallery'**
  String get gallery_close;

  /// No description provided for @gallery_tab_cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get gallery_tab_cards;

  /// No description provided for @gallery_tab_sections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get gallery_tab_sections;

  /// No description provided for @gallery_clear_search.
  ///
  /// In en, this message translates to:
  /// **'Clear the search'**
  String get gallery_clear_search;

  /// No description provided for @gallery_filter_by_section.
  ///
  /// In en, this message translates to:
  /// **'Filter by section'**
  String get gallery_filter_by_section;

  /// No description provided for @gallery_all_sections.
  ///
  /// In en, this message translates to:
  /// **'All sections'**
  String get gallery_all_sections;

  /// No description provided for @gallery_result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get gallery_result;

  /// No description provided for @gallery_skeleton.
  ///
  /// In en, this message translates to:
  /// **'Skeleton'**
  String get gallery_skeleton;

  /// No description provided for @gallery_use_component.
  ///
  /// In en, this message translates to:
  /// **'Use this component'**
  String get gallery_use_component;

  /// No description provided for @gallery_click_to_copy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy {name}'**
  String gallery_click_to_copy(Object name);

  /// No description provided for @gallery_component_detail.
  ///
  /// In en, this message translates to:
  /// **'Component detail and its parameters'**
  String get gallery_component_detail;

  /// No description provided for @offline_no_connection.
  ///
  /// In en, this message translates to:
  /// **'No Internet connection'**
  String get offline_no_connection;

  /// No description provided for @offline_chapter_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s pages are not available offline. Reconnect to load them.'**
  String get offline_chapter_unavailable;

  /// No description provided for @offline_connect_for.
  ///
  /// In en, this message translates to:
  /// **'Connect to the Internet to load {title}.'**
  String offline_connect_for(Object title);

  /// No description provided for @media_hub_temporarily_unavailable.
  ///
  /// In en, this message translates to:
  /// **'{title} is temporarily unavailable'**
  String media_hub_temporarily_unavailable(Object title);

  /// No description provided for @media_watch_live.
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get media_watch_live;

  /// No description provided for @media_live_news.
  ///
  /// In en, this message translates to:
  /// **'Live news'**
  String get media_live_news;

  /// No description provided for @media_science_space.
  ///
  /// In en, this message translates to:
  /// **'Science and space'**
  String get media_science_space;

  /// No description provided for @media_queue_canceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling…'**
  String get media_queue_canceling;

  /// No description provided for @media_queue_paused.
  ///
  /// In en, this message translates to:
  /// **'Queue paused'**
  String get media_queue_paused;

  /// No description provided for @media_queue_queuing.
  ///
  /// In en, this message translates to:
  /// **'Queuing'**
  String get media_queue_queuing;

  /// No description provided for @media_queue_added_count.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String media_queue_added_count(Object count);

  /// No description provided for @media_format_tv_short.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get media_format_tv_short;

  /// No description provided for @media_format_special.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get media_format_special;

  /// No description provided for @media_format_one_shot.
  ///
  /// In en, this message translates to:
  /// **'1-shot'**
  String get media_format_one_shot;

  /// No description provided for @schedule_episode_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String schedule_episode_count(num count);

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get profile_title;

  /// No description provided for @profile_anonymous_title.
  ///
  /// In en, this message translates to:
  /// **'Anonymous account'**
  String get profile_anonymous_title;

  /// No description provided for @profile_anonymous_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Watchtower without an account. Your preferences stay on this device.'**
  String get profile_anonymous_subtitle;

  /// No description provided for @profile_insights.
  ///
  /// In en, this message translates to:
  /// **'Viewing insights'**
  String get profile_insights;

  /// No description provided for @profile_insights_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your reading and watching habits'**
  String get profile_insights_subtitle;

  /// No description provided for @profile_server.
  ///
  /// In en, this message translates to:
  /// **'Server status'**
  String get profile_server;

  /// No description provided for @profile_server_message.
  ///
  /// In en, this message translates to:
  /// **'TMDB and source services are checked on demand.'**
  String get profile_server_message;

  /// No description provided for @profile_share_message.
  ///
  /// In en, this message translates to:
  /// **'Discover Watchtower, your personal content library.'**
  String get profile_share_message;

  /// No description provided for @profile_account_message.
  ///
  /// In en, this message translates to:
  /// **'Online account management is not enabled in this Watchtower build. You can continue with the local profile and app settings.'**
  String get profile_account_message;

  /// No description provided for @library_classification_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Coming soon — no classification metadata is attached to the library entries yet.'**
  String get library_classification_unavailable;

  /// No description provided for @library_rating_safe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get library_rating_safe;

  /// No description provided for @library_rating_suggestive.
  ///
  /// In en, this message translates to:
  /// **'Suggestive'**
  String get library_rating_suggestive;

  /// No description provided for @library_no_source_detected.
  ///
  /// In en, this message translates to:
  /// **'No source detected in this library.'**
  String get library_no_source_detected;

  /// No description provided for @library_no_category_created.
  ///
  /// In en, this message translates to:
  /// **'No category created.'**
  String get library_no_category_created;

  /// No description provided for @common_grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get common_grid;

  /// No description provided for @notifications_partially_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Some notifications are temporarily unavailable.'**
  String get notifications_partially_unavailable;

  /// No description provided for @notifications_source_missing_after_install.
  ///
  /// In en, this message translates to:
  /// **'The installed source could not be found after the download.'**
  String get notifications_source_missing_after_install;

  /// No description provided for @notifications_layout_not_installed.
  ///
  /// In en, this message translates to:
  /// **'The UI layout was not installed.'**
  String get notifications_layout_not_installed;

  /// No description provided for @onboarding_dependencies_title.
  ///
  /// In en, this message translates to:
  /// **'Dependencies'**
  String get onboarding_dependencies_title;

  /// No description provided for @onboarding_dependencies_body.
  ///
  /// In en, this message translates to:
  /// **'The app keeps its APK light. Optional components install after the setup and can be postponed.'**
  String get onboarding_dependencies_body;

  /// No description provided for @smart_tmdb_unavailable.
  ///
  /// In en, this message translates to:
  /// **'TMDB metadata is unavailable; AniList is used instead.'**
  String get smart_tmdb_unavailable;

  /// No description provided for @smart_scanning_storage.
  ///
  /// In en, this message translates to:
  /// **'Scanning storage…'**
  String get smart_scanning_storage;

  /// No description provided for @smart_no_media_indexed.
  ///
  /// In en, this message translates to:
  /// **'No media indexed yet'**
  String get smart_no_media_indexed;

  /// No description provided for @smart_to_review.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get smart_to_review;

  /// No description provided for @smart_work_episodes.
  ///
  /// In en, this message translates to:
  /// **'{title} · {count} episodes'**
  String smart_work_episodes(Object count, Object title);

  /// No description provided for @anime_country_jp.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get anime_country_jp;

  /// No description provided for @anime_country_cn.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get anime_country_cn;

  /// No description provided for @anime_country_kr.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get anime_country_kr;

  /// No description provided for @anime_country_tw.
  ///
  /// In en, this message translates to:
  /// **'Taiwan'**
  String get anime_country_tw;

  /// No description provided for @anime_country_us.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get anime_country_us;

  /// No description provided for @anime_country_fr.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get anime_country_fr;

  /// No description provided for @anime_country_gb.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get anime_country_gb;

  /// No description provided for @anime_country_de.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get anime_country_de;

  /// No description provided for @anime_country_ca.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get anime_country_ca;

  /// No description provided for @anime_country_ru.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get anime_country_ru;

  /// No description provided for @anime_country_it.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get anime_country_it;

  /// No description provided for @anime_country_es.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get anime_country_es;

  /// No description provided for @anime_country_sg.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get anime_country_sg;

  /// No description provided for @anime_country_hk.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get anime_country_hk;

  /// No description provided for @anime_country_th.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get anime_country_th;

  /// No description provided for @anime_country_au.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get anime_country_au;

  /// No description provided for @anime_country_in.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get anime_country_in;

  /// No description provided for @anime_country_ph.
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get anime_country_ph;

  /// No description provided for @anime_country_br.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get anime_country_br;

  /// No description provided for @anime_country_mx.
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get anime_country_mx;

  /// No description provided for @anime_country_id.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get anime_country_id;

  /// No description provided for @anime_country_vn.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get anime_country_vn;

  /// No description provided for @anime_country_my.
  ///
  /// In en, this message translates to:
  /// **'Malaysia'**
  String get anime_country_my;

  /// No description provided for @anime_country_nz.
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get anime_country_nz;

  /// No description provided for @anime_country_be.
  ///
  /// In en, this message translates to:
  /// **'Belgium'**
  String get anime_country_be;

  /// No description provided for @anime_country_nl.
  ///
  /// In en, this message translates to:
  /// **'Netherlands'**
  String get anime_country_nl;

  /// No description provided for @anime_country_pl.
  ///
  /// In en, this message translates to:
  /// **'Poland'**
  String get anime_country_pl;

  /// No description provided for @anime_country_se.
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get anime_country_se;

  /// No description provided for @anime_country_no.
  ///
  /// In en, this message translates to:
  /// **'Norway'**
  String get anime_country_no;

  /// No description provided for @anime_country_fi.
  ///
  /// In en, this message translates to:
  /// **'Finland'**
  String get anime_country_fi;

  /// No description provided for @anime_country_ie.
  ///
  /// In en, this message translates to:
  /// **'Ireland'**
  String get anime_country_ie;

  /// No description provided for @anime_country_za.
  ///
  /// In en, this message translates to:
  /// **'South Africa'**
  String get anime_country_za;

  /// No description provided for @anime_country_eg.
  ///
  /// In en, this message translates to:
  /// **'Egypt'**
  String get anime_country_eg;

  /// No description provided for @anime_country_ar.
  ///
  /// In en, this message translates to:
  /// **'Argentina'**
  String get anime_country_ar;

  /// No description provided for @anime_directory_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this catalogue: {error}'**
  String anime_directory_load_failed(Object error);

  /// No description provided for @anime_directory_empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing available.'**
  String get anime_directory_empty;

  /// No description provided for @smart_scanning_storage_count.
  ///
  /// In en, this message translates to:
  /// **'Scanning storage · {count} files'**
  String smart_scanning_storage_count(Object count);

  /// No description provided for @smart_library_watch_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Library Watch'**
  String get smart_library_watch_title;

  /// No description provided for @smart_library_manga_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Library Manga'**
  String get smart_library_manga_title;

  /// No description provided for @smart_library_music_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Library Music'**
  String get smart_library_music_title;

  /// No description provided for @smart_filter_albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get smart_filter_albums;

  /// No description provided for @smart_filter_singles.
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get smart_filter_singles;

  /// No description provided for @smart_edit_entry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get smart_edit_entry;

  /// No description provided for @smart_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get smart_edit_title;

  /// No description provided for @smart_edit_kind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get smart_edit_kind;

  /// No description provided for @smart_edit_season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get smart_edit_season;

  /// No description provided for @smart_edit_episode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get smart_edit_episode;

  /// No description provided for @smart_edit_artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get smart_edit_artist;

  /// No description provided for @smart_edit_album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get smart_edit_album;

  /// No description provided for @smart_edit_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get smart_edit_save;

  /// No description provided for @smart_edit_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get smart_edit_cancel;

  /// No description provided for @smart_edit_saved.
  ///
  /// In en, this message translates to:
  /// **'Entry updated'**
  String get smart_edit_saved;

  /// No description provided for @smart_requery.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get smart_requery;

  /// No description provided for @smart_requery_running.
  ///
  /// In en, this message translates to:
  /// **'Searching the catalogue…'**
  String get smart_requery_running;

  /// No description provided for @smart_requery_found.
  ///
  /// In en, this message translates to:
  /// **'Match found: {title}'**
  String smart_requery_found(Object title);

  /// No description provided for @smart_requery_none.
  ///
  /// In en, this message translates to:
  /// **'No match found. You can fill the fields by hand.'**
  String get smart_requery_none;

  /// No description provided for @smart_requery_failed.
  ///
  /// In en, this message translates to:
  /// **'Lookup failed: {error}'**
  String smart_requery_failed(Object error);

  /// No description provided for @smart_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get smart_rename;

  /// No description provided for @smart_rename_preview.
  ///
  /// In en, this message translates to:
  /// **'Rename to'**
  String get smart_rename_preview;

  /// No description provided for @smart_rename_apply.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get smart_rename_apply;

  /// No description provided for @smart_rename_done.
  ///
  /// In en, this message translates to:
  /// **'File renamed'**
  String get smart_rename_done;

  /// No description provided for @smart_rename_failed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {reason}'**
  String smart_rename_failed(Object reason);

  /// No description provided for @smart_rename_not_needed.
  ///
  /// In en, this message translates to:
  /// **'Already correctly named'**
  String get smart_rename_not_needed;

  /// No description provided for @smart_track_count.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String smart_track_count(Object count);

  /// No description provided for @smart_unknown_help.
  ///
  /// In en, this message translates to:
  /// **'This entry could not be classified. Edit it or search the catalogue again.'**
  String get smart_unknown_help;

  /// No description provided for @appearance_ui_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Carousel, blur, animations and visual effects'**
  String get appearance_ui_subtitle;

  /// No description provided for @extension_repositories_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Watch, Manga & Novel repo URLs'**
  String get extension_repositories_subtitle;

  /// No description provided for @data_storage_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Library, settings and cache — managed from the Settings'**
  String get data_storage_subtitle;

  /// No description provided for @manage_categories_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove tabs you no longer need.\nTitles stay in your library.'**
  String get manage_categories_subtitle;

  /// No description provided for @media_info_pending.
  ///
  /// In en, this message translates to:
  /// **'The information will appear\nwhen it becomes available.'**
  String get media_info_pending;

  /// No description provided for @common_preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get common_preview;

  /// No description provided for @video_preview_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Video preview is not available on this platform.'**
  String get video_preview_unavailable;

  /// No description provided for @manga_chapter_input_hint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 142, 100-110…'**
  String get manga_chapter_input_hint;

  /// No description provided for @catalog_bulk_enqueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get catalog_bulk_enqueue;

  /// No description provided for @diag_video_preview_web_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Video preview is not available on web.'**
  String get diag_video_preview_web_unavailable;

  /// No description provided for @extension_repositories.
  ///
  /// In en, this message translates to:
  /// **'Extension repositories'**
  String get extension_repositories;

  /// No description provided for @reader_volume_buttons_title.
  ///
  /// In en, this message translates to:
  /// **'Volume-button navigation'**
  String get reader_volume_buttons_title;

  /// No description provided for @anime_resolve_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the search…'**
  String get anime_resolve_preparing;

  /// No description provided for @anime_resolve_reading.
  ///
  /// In en, this message translates to:
  /// **'Reading the titles and the reference date…'**
  String get anime_resolve_reading;

  /// No description provided for @anime_resolve_searching.
  ///
  /// In en, this message translates to:
  /// **'Silent search across {count} extension(s)…'**
  String anime_resolve_searching(Object count);

  /// No description provided for @anime_resolve_no_active_extension.
  ///
  /// In en, this message translates to:
  /// **'No active anime extension to query'**
  String get anime_resolve_no_active_extension;

  /// No description provided for @anime_resolve_checking_streams.
  ///
  /// In en, this message translates to:
  /// **'Episode confirmed · checking the available streams…'**
  String get anime_resolve_checking_streams;

  /// No description provided for @anime_resolve_no_reliable_source.
  ///
  /// In en, this message translates to:
  /// **'No reliable source found for this episode'**
  String get anime_resolve_no_reliable_source;

  /// No description provided for @anime_resolve_sources_verified.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} source verified} other{{count} sources verified}}'**
  String anime_resolve_sources_verified(num count);

  /// No description provided for @anime_resolve_hint.
  ///
  /// In en, this message translates to:
  /// **'The raw extension results stay hidden. The page checks the title, the format and the episode number before showing a source.'**
  String get anime_resolve_hint;

  /// No description provided for @anime_resolve_none_active.
  ///
  /// In en, this message translates to:
  /// **'No active anime extension'**
  String get anime_resolve_none_active;

  /// No description provided for @anime_resolve_none_reliable.
  ///
  /// In en, this message translates to:
  /// **'No reliable source for this episode'**
  String get anime_resolve_none_reliable;

  /// No description provided for @anime_resolve_install_hint.
  ///
  /// In en, this message translates to:
  /// **'Install or enable an anime extension, then run the search again.'**
  String get anime_resolve_install_hint;

  /// No description provided for @anime_resolve_failed_sources.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} extension did not answer.} other{{count} extensions did not answer.}} Also check the title variants and the episode number.'**
  String anime_resolve_failed_sources(num count);

  /// No description provided for @anime_resolve_no_match.
  ///
  /// In en, this message translates to:
  /// **'No result matches the selected title and episode closely enough. Try another anime extension.'**
  String get anime_resolve_no_match;

  /// No description provided for @anime_resolve_no_stream.
  ///
  /// In en, this message translates to:
  /// **'Episode found, but no video stream was returned.'**
  String get anime_resolve_no_stream;

  /// No description provided for @anime_resolve_episode_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed episode'**
  String get anime_resolve_episode_confirmed;

  /// No description provided for @anime_resolve_exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get anime_resolve_exact;

  /// No description provided for @anime_resolve_probable.
  ///
  /// In en, this message translates to:
  /// **'Probable'**
  String get anime_resolve_probable;

  /// No description provided for @anime_resolve_year_detected.
  ///
  /// In en, this message translates to:
  /// **'Year detected in the source title: {year}'**
  String anime_resolve_year_detected(Object year);

  /// No description provided for @anime_resolve_confirmed_progress.
  ///
  /// In en, this message translates to:
  /// **'{scanned} / {total} extensions · {count} confirmed episode(s)'**
  String anime_resolve_confirmed_progress(
    Object count,
    Object scanned,
    Object total,
  );

  /// No description provided for @app_version_beta.
  ///
  /// In en, this message translates to:
  /// **'v{version} · Beta'**
  String app_version_beta(Object version);

  /// No description provided for @library_items_percent.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {percent}%'**
  String library_items_percent(Object count, Object percent);

  /// No description provided for @browse_create_next_code_editor.
  ///
  /// In en, this message translates to:
  /// **'Next — Code editor'**
  String get browse_create_next_code_editor;

  /// No description provided for @browse_create_fill_required.
  ///
  /// In en, this message translates to:
  /// **'Fill in the name, the language, the base URL and the icon to continue.'**
  String get browse_create_fill_required;

  /// No description provided for @browse_create_info_banner.
  ///
  /// In en, this message translates to:
  /// **'Configure the metadata, then move on to the code editor to implement the logic.'**
  String get browse_create_info_banner;

  /// No description provided for @common_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get common_search_hint;

  /// No description provided for @watch_trailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer · {name}'**
  String watch_trailer(Object name);

  /// No description provided for @log_live_title.
  ///
  /// In en, this message translates to:
  /// **'Live logs · {count}'**
  String log_live_title(Object count);

  /// No description provided for @log_none.
  ///
  /// In en, this message translates to:
  /// **'No log for the moment.\nStart a reading or a download.'**
  String get log_none;

  /// No description provided for @download_in_app.
  ///
  /// In en, this message translates to:
  /// **'Download in the app'**
  String get download_in_app;

  /// No description provided for @download_open_external.
  ///
  /// In en, this message translates to:
  /// **'Open in an external download manager'**
  String get download_open_external;

  /// No description provided for @download_connection_lost_resume.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — it resumes automatically when the network returns'**
  String get download_connection_lost_resume;

  /// No description provided for @download_install_permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Install permission denied. Enable it in the system settings.'**
  String get download_install_permission_denied;

  /// No description provided for @browse_diag_source_default.
  ///
  /// In en, this message translates to:
  /// **'Source 1'**
  String get browse_diag_source_default;

  /// No description provided for @diag_tap_to_play.
  ///
  /// In en, this message translates to:
  /// **'{quality} — Tap to play'**
  String diag_tap_to_play(Object quality);

  /// No description provided for @watch_order_meta.
  ///
  /// In en, this message translates to:
  /// **'{period} | {type} | {episodes} episodes | ★{score} ({voters})'**
  String watch_order_meta(
    Object episodes,
    Object period,
    Object score,
    Object type,
    Object voters,
  );

  /// No description provided for @manga_rank_trending.
  ///
  /// In en, this message translates to:
  /// **'#{rank} · Trending'**
  String manga_rank_trending(Object rank);

  /// No description provided for @anime_episode_label.
  ///
  /// In en, this message translates to:
  /// **'EP {number} · {title}'**
  String anime_episode_label(Object number, Object title);

  /// No description provided for @categories_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No category yet'**
  String get categories_empty_title;

  /// No description provided for @categories_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a category to organise your library.'**
  String get categories_empty_subtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'as',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'pt',
    'ru',
    'th',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case '419':
            return AppLocalizationsEs419();
        }
        break;
      }
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'as':
      return AppLocalizationsAs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
