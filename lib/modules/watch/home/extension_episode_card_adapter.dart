import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/widgets/episode_card.dart'
    as home_episode;

/// Adapts the episode fields supplied by an extension to the existing Home
/// episode card. Playback/navigation stays with the owning screen.
class ExtensionEpisodeCardAdapter {
  static int? parseEpisodeNumber(String? episodeName) {
    final name = episodeName?.trim() ?? '';
    final seasonEpisode = RegExp(
      r'\bs\d+\s*e\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    final explicitEpisode = RegExp(
      r'(?:\bepisode\b|\bep\.?|(?:^|[\s._-])e)\s*[-:#]?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    final seasonPattern = RegExp(r'\d+\s*[x×]\s*(\d+)').firstMatch(name);
    final leadingNumber = RegExp(r'^\s*(\d+)\b').firstMatch(name);
    final match =
        seasonEpisode ?? explicitEpisode ?? seasonPattern ?? leadingNumber;
    return int.tryParse(match?.group(1) ?? '');
  }

  static Widget build({
    required MManga series,
    required MChapter episode,
    required int episodeNumber,
    required double width,
    required VoidCallback onTap,
  }) {
    final episodeName = episode.name!.trim();
    final seriesName = series.name!.trim();
    final episodeThumbnail = episode.thumbnailUrl?.trim();
    final seriesPreview = series.previewUrl?.trim();
    final seriesCover = series.imageUrl?.trim();

    return home_episode.EpisodeCard(
      width: width,
      data: home_episode.EpisodeCardData(
        thumbnailUrl: episodeThumbnail?.isNotEmpty == true
            ? episodeThumbnail
            : seriesPreview?.isNotEmpty == true
            ? seriesPreview
            : null,
        animeCoverUrl: seriesCover?.isNotEmpty == true ? seriesCover : null,
        animeTitle: seriesName,
        episodeNumber: episodeNumber,
        episodeTitle: episodeName,
      ),
      onTap: onTap,
    );
  }
}
