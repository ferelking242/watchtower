import 'package:flutter/material.dart';

import '../../provider/recently_watched_provider.dart';
import '../models/tv_media_item.dart';
import 'tv_dialog.dart';

/// The recently watched keys a Continue watching removal needs.
///
/// A movie row is keyed by its own id; an episode row needs the episode, season
/// and episode number together, because the store keeps one row per episode.
@immutable
class TvContinueWatchingRemoval {
  const TvContinueWatchingRemoval.movie(this.movieId)
      : episodeId = null,
        seasonNumber = null,
        episodeNumber = null;

  const TvContinueWatchingRemoval.episode({
    required this.episodeId,
    required this.seasonNumber,
    required this.episodeNumber,
  }) : movieId = null;

  final int? movieId;
  final int? episodeId;
  final int? seasonNumber;
  final int? episodeNumber;

  /// The removal [item] needs, or null when it did not come from the recently
  /// watched store and so carries no keys to remove it by.
  static TvContinueWatchingRemoval? forItem(TvMediaItem item) {
    final movie = item.recentMovie;
    if (movie != null) {
      final id = movie.id;
      return id == null ? null : TvContinueWatchingRemoval.movie(id);
    }
    final episode = item.recentEpisode;
    if (episode == null) return null;
    final id = episode.id;
    final seasonNumber = episode.seasonNum;
    final episodeNumber = episode.episodeNum;
    if (id == null || seasonNumber == null || episodeNumber == null) return null;
    return TvContinueWatchingRemoval.episode(
      episodeId: id,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Tombstones the row so the removal reaches the user's other devices instead
  /// of being undone by their next sync.
  Future<void> apply(RecentProvider recent) {
    final movieId = this.movieId;
    if (movieId != null) return recent.deleteMovie(movieId);
    return recent.deleteEpisode(episodeId!, episodeNumber!, seasonNumber!);
  }

  @override
  bool operator ==(Object other) =>
      other is TvContinueWatchingRemoval &&
      other.movieId == movieId &&
      other.episodeId == episodeId &&
      other.seasonNumber == seasonNumber &&
      other.episodeNumber == episodeNumber;

  @override
  int get hashCode =>
      Object.hash(movieId, episodeId, seasonNumber, episodeNumber);

  @override
  String toString() => movieId != null
      ? 'TvContinueWatchingRemoval.movie($movieId)'
      : 'TvContinueWatchingRemoval.episode($episodeId, '
          'S$seasonNumber E$episodeNumber)';
}

/// Asks before dropping [item] from the Continue watching row.
///
/// A remote's held OK is easier to hit by accident than a touch long press, and
/// the removal is not undoable, so this stands between the two.
Future<bool> confirmRemoveFromContinueWatching({
  required BuildContext context,
  required TvMediaItem item,
}) async {
  final confirmed = await showTvDialog<bool>(
    context: context,
    title: 'Remove from Continue watching?',
    content: Text(
      '"${item.title}" stops showing up in Continue watching, and its '
      'playback position is discarded.',
    ),
    actions: <TvDialogAction>[
      TvDialogAction(
        label: 'Remove',
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      // The safe action takes focus: someone who only meant to resume playback
      // and held OK a beat too long should not land on a destructive default.
      TvDialogAction(
        label: 'Cancel',
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
  return confirmed == true;
}
