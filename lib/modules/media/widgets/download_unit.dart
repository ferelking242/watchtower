import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';

/// Wording of a bulk-download count, derived from the source's [ItemType].
///
/// Two different counts appear in the download flow and they must not share
/// one word:
///
/// * the number of selected *catalogue entries* (a manga title, a novel, an
///   album, a film…), shown in the menu and the sheet header;
/// * the number of *queued items* (chapters, episodes, tracks), shown in the
///   sheet footer and per-row.
///
/// A manga extension therefore reads "Télécharger 5 mangas" in the header and
/// "120 chapitres" in the footer, instead of the previous, always-"vidéos"
/// wording that made no sense outside video extensions.
enum DownloadUnit {
  /// Manga / webtoon: entries are titles, queued items are chapters.
  manga,

  /// Anime / series / film: entries are titles, queued items are episodes.
  video,

  /// Novel: entries are titles, queued items are chapters.
  novel,

  /// Music: entries are albums/titles, queued items are tracks.
  music,

  /// Game: entries and queued items are both games.
  game,
}

DownloadUnit downloadUnitFor(ItemType? itemType) {
  return switch (itemType) {
    ItemType.manga => DownloadUnit.manga,
    ItemType.novel => DownloadUnit.novel,
    ItemType.music => DownloadUnit.music,
    ItemType.game => DownloadUnit.game,
    // anime (and plugin, which shares the video pipeline) queue episodes.
    _ => DownloadUnit.video,
  };
}

/// Word naming the content type of one catalogue entry ("mangas", "vidéos"…).
String catalogEntryUnitLabel(
  AppLocalizations l10n,
  ItemType? itemType,
  int count,
) {
  final plural = count != 1;
  return switch (downloadUnitFor(itemType)) {
    DownloadUnit.manga =>
      plural ? l10n.media_unit_mangas : l10n.media_unit_manga,
    DownloadUnit.video =>
      plural ? l10n.media_unit_videos : l10n.media_unit_video,
    DownloadUnit.novel =>
      plural ? l10n.media_unit_novels : l10n.media_unit_novel,
    DownloadUnit.music =>
      plural ? l10n.media_unit_musics : l10n.media_unit_music,
    DownloadUnit.game =>
      plural ? l10n.media_unit_games : l10n.media_unit_game,
  };
}

/// Plural form of [catalogEntryUnitLabel], for headings that name the content
/// type without a count ("Télécharger des mangas").
String catalogEntryUnitPluralLabel(AppLocalizations l10n, ItemType? itemType) =>
    catalogEntryUnitLabel(l10n, itemType, 2);

/// Word naming one queued item ("chapitres", "épisodes", "pistes"…).
String queuedUnitLabel(
  AppLocalizations l10n,
  ItemType? itemType,
  int count,
) {
  final plural = count != 1;
  return switch (downloadUnitFor(itemType)) {
    DownloadUnit.manga =>
      plural ? l10n.media_unit_chapters : l10n.media_unit_chapter,
    DownloadUnit.video =>
      plural ? l10n.media_unit_episodes : l10n.media_unit_episode,
    DownloadUnit.novel =>
      plural ? l10n.media_unit_chapters : l10n.media_unit_chapter,
    DownloadUnit.music =>
      plural ? l10n.media_unit_tracks : l10n.media_unit_track,
    DownloadUnit.game =>
      plural ? l10n.media_unit_games : l10n.media_unit_game,
  };
}
