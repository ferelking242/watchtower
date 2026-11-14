import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/engines/zeus_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/zeus_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_runtime.dart';
import 'package:watchtower/services/download_manager/social_media_extractor.dart';
import 'package:watchtower/services/download_manager/social_url_detector.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/watchtower_folder_service.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Outcome of a "paste a link" download.
enum LinkDownloadStatus { completed, delegatedToZeus, failed }

class LinkDownloadResult {
  final LinkDownloadStatus status;
  final String? filePath;
  final String? message;

  const LinkDownloadResult(this.status, {this.filePath, this.message});
}

/// Downloads a single media file from a URL pasted by the user — no extension,
/// no Isar record. Three paths, chosen automatically:
///
/// * a **social page** (TikTok/Facebook/…) is resolved to a direct URL with
///   [SocialMediaExtractor] and fetched by the internal engine;
/// * a **direct file** URL (`.mp4`, `.m3u8`, any HTTP resource) is fetched
///   directly;
/// * when the page cannot be resolved and the **ZeusDL runtime** is installed,
///   the link is handed to [ZeusEngine] for extractor-grade support.
///
/// Progress is streamed to [onProgress] as `(receivedBytes, totalBytes)`.
class LinkDownloadService {
  const LinkDownloadService();

  Future<LinkDownloadResult> download({
    required String url,
    required String outputPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const LinkDownloadResult(
        LinkDownloadStatus.failed,
        message: 'Lien vide',
      );
    }

    final platform = SocialUrlDetector.detect(trimmed);
    var effectiveUrl = trimmed;

    if (platform != null) {
      // Try the light extractor first; fall back to ZeusDL when the page shape
      // is not recognised (private post, JS-only player, …).
      try {
        effectiveUrl = await SocialMediaExtractor.resolve(trimmed);
        AppLogger.log(
          'LinkDownload: resolved ${platform.name} page → direct media',
          tag: LogTag.download,
        );
      } catch (e) {
        final zeusResult = await _tryZeus(
          url: trimmed,
          platform: platform,
          outputPath: outputPath,
          onProgress: onProgress,
        );
        if (zeusResult != null) return zeusResult;
        return LinkDownloadResult(
          LinkDownloadStatus.failed,
          message: '$e',
        );
      }
    }

    return _downloadDirect(
      url: effectiveUrl,
      outputPath: outputPath,
      onProgress: onProgress,
    );
  }

  /// Runs [ZeusEngine] when the runtime is installed. Returns null when the
  /// runtime is absent so the caller can report the extraction error instead.
  Future<LinkDownloadResult?> _tryZeus({
    required String url,
    required SocialPlatform platform,
    required String outputPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final installed = await ZeusBinaryManager.instance.isInstalled();
    if (!installed) return null;
    try {
      final engine = ZeusEngine(
        url: url,
        outputPath: outputPath,
        headers: const {},
        itemType: ItemType.anime,
        chapterId: 'link',
        pluginId: platform.pluginId,
        params: ZeusParams(url: url, noWatermark: platform.hasWatermark),
      );
      await engine.start((progress) {
        onProgress?.call(
          progress.downloadedBytes ?? progress.completed,
          progress.totalBytes ?? progress.total,
        );
      });
      return LinkDownloadResult(
        LinkDownloadStatus.completed,
        filePath: outputPath,
      );
    } catch (e) {
      AppLogger.log(
        'LinkDownload: ZeusDL failed — $e',
        logLevel: LogLevel.error,
        tag: LogTag.download,
      );
      return null;
    }
  }

  Future<LinkDownloadResult> _downloadDirect({
    required String url,
    required String outputPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final client = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = SocialMediaExtractor.userAgent
        ..followRedirects = true;
      final response = await client.send(request);
      if (response.statusCode != 200) {
        return LinkDownloadResult(
          LinkDownloadStatus.failed,
          message: 'HTTP ${response.statusCode}',
        );
      }
      final file = File(outputPath);
      await file.parent.create(recursive: true);
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      if (received == 0) {
        return const LinkDownloadResult(
          LinkDownloadStatus.failed,
          message: 'Fichier vide',
        );
      }
      AppLogger.log(
        'LinkDownload: saved $received bytes → $outputPath',
        tag: LogTag.download,
      );
      return LinkDownloadResult(
        LinkDownloadStatus.completed,
        filePath: outputPath,
      );
    } catch (e) {
      AppLogger.log(
        'LinkDownload error',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: e,
      );
      return LinkDownloadResult(
        LinkDownloadStatus.failed,
        message: '$e',
      );
    }
  }

  /// Builds a safe output path inside the app's Watch download folder.
  Future<String> buildOutputPath({required String url}) async {
    final dir = await WatchtowerFolderService.instance.getDownloadDir('anime') ??
        (await getApplicationSupportDirectory()).path;
    return p.join(dir, fileNameFor(url));
  }

  /// Derives a safe file name from [url]. Falls back to a timestamped `.mp4`
  /// when the URL carries no usable name, and strips characters that are
  /// illegal on the target filesystems.
  static String fileNameFor(String url) {
    final uri = Uri.tryParse(url.trim());
    var name = p.basename(uri?.path ?? '');
    if (name.isEmpty || !name.contains('.')) {
      name = 'watchtower_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
