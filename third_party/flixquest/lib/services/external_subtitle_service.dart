import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:better_player_plus/better_player_plus.dart';
import 'package:retry/retry.dart';
import '../functions/function.dart';
import '../models/external_subtitles.dart';
import '../video_providers/scraper_api.dart';

/// Fetches external subtitles through the FlixQuest Scraper API.
///
/// Search and file download both go through the scraper: it holds the provider
/// credentials, normalizes every file to UTF-8 and strips aggregator ads, so
/// the app never talks to a subtitle source directly.
class ExternalSubtitleService {
  ExternalSubtitleService(this.scraperApiUrl);

  final String scraperApiUrl;

  /// Fetch external subtitles for a movie using TMDB ID
  Future<List<ExternalSubtitle>> fetchMovieSubtitles(int tmdbId) {
    return ScraperApi(scraperApiUrl).searchSubtitles(tmdbId: tmdbId);
  }

  /// Fetch external subtitles for a TV episode using TMDB ID, season, and episode
  Future<List<ExternalSubtitle>> fetchTVSubtitles(
    int tmdbId,
    int seasonNumber,
    int episodeNumber,
  ) {
    return ScraperApi(scraperApiUrl).searchSubtitles(
      tmdbId: tmdbId,
      season: seasonNumber,
      episode: episodeNumber,
    );
  }

  /// Download and convert ExternalSubtitle to BetterPlayerSubtitlesSource with parsed content
  static Future<BetterPlayerSubtitlesSource> convertToBetterPlayerSource(
    ExternalSubtitle subtitle, {
    int? subtitleNumber,
  }) async {
    final subtitleContent = await _downloadSubtitle(subtitle.url);

    // The API serves WebVTT and SubRip; only WebVTT timestamps need fixing.
    final processedContent =
        subtitleContent.isEmpty || subtitle.format.toLowerCase() == 'srt'
            ? subtitleContent
            : processVttFileTimestamps(subtitleContent);

    // Create a unique name for the subtitle
    String subtitleName = subtitle.display;
    if (subtitleNumber != null) {
      subtitleName = '${subtitle.display} #$subtitleNumber';
    }
    if (subtitle.isHearingImpaired) {
      subtitleName += ' (HI)';
    }

    return BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.memory,
      name: subtitleName,
      content: processedContent,
      selectedByDefault: false,
    );
  }

  /// Downloads a subtitle file from the API, which always answers in UTF-8, so
  /// malformed bytes are replaced instead of probed for a code page.
  static Future<String> _downloadSubtitle(String url) async {
    final retryOptions = RetryOptions(maxAttempts: 3);

    try {
      final response = await retryOptions.retry(
        () => http.get(Uri.parse(url)).timeout(const Duration(seconds: 20)),
        retryIf: (e) => e is SocketException,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
      // An error page is never a subtitle file.
      return decoded.trimLeft().startsWith('<') ? '' : decoded;
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }
}
