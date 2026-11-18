import 'package:isar_community/isar.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/canonical_key.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';

/// Persists a user's manual correction to an indexed entry.
///
/// The Smart Library's automatic classification is conservative: a file it
/// cannot place lands in `unknown` with a low confidence. This service lets
/// the user fix that by hand — retitle a mislabelled movie, reclassify an
/// anime, or complete a music track's artist/album — and marks the entry
/// `userLocked` so the next scan does not overwrite the correction.
class LocalOverrideService {
  LocalOverrideService._();

  static final instance = LocalOverrideService._();

  /// Applies [changes] to [item], writes it back and refreshes the in-memory
  /// index. A corrected title regenerates the canonical key so the entry
  /// groups under the right work.
  Future<LocalIndexedItem> edit(
    LocalIndexedItem item, {
    required Isar isar,
    required LocalSearchEngine searchEngine,
    String? title,
    LocalMediaKind? kind,
    int? season,
    int? episode,
    String? artist,
    String? album,
    bool? clearSeason,
    bool? clearEpisode,
    bool? clearArtist,
    bool? clearAlbum,
  }) async {
    final newTitle = title?.trim();
    if (newTitle != null && newTitle.isNotEmpty) {
      item.title = newTitle;
      item.canonicalKey = CanonicalKey.generate(newTitle);
    }
    if (kind != null) item.kind = kind;
    if (clearSeason ?? false) {
      item.season = null;
    } else if (season != null) {
      item.season = season;
    }
    if (clearEpisode ?? false) {
      item.episode = null;
    } else if (episode != null) {
      item.episode = episode;
    }
    if (clearArtist ?? false) {
      item.artist = null;
    } else if (artist != null) {
      item.artist = artist.trim().isEmpty ? null : artist.trim();
    }
    if (clearAlbum ?? false) {
      item.album = null;
    } else if (album != null) {
      item.album = album.trim().isEmpty ? null : album.trim();
    }
    item.userLocked = true;
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;

    await isar.writeTxn(() => isar.localIndexedItems.put(item));
    searchEngine.upsert(item);
    return item;
  }
}
