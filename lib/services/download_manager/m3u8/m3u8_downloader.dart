import 'dart:developer';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/http/rhttp/src/model/settings.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/m3u8/models/ts_info.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart' as path;
import 'package:convert/convert.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

typedef TsMergeRunner =
    Future<void> Function(String outputFile, List<String> segmentPaths);

class M3u8Downloader {
  final String m3u8Url;
  final String downloadDir;
  final Map<String, String>? headers;
  final String fileName;
  final int concurrentDownloads;
  final Chapter chapter;
  final List<Track>? subtitles;
  @visibleForTesting
  final TsMergeRunner? mergeRunner;

  /// Source page URL — used as Referer header (anti-403 fix)
  final String? refererUrl;

  static var httpClient = MClient.httpClient(
    settings: const ClientSettings(
      throwOnStatusCode: false,
      tlsSettings: TlsSettings(verifyCertificates: true),
    ),
  );

  M3u8Downloader({
    required this.m3u8Url,
    required this.downloadDir,
    required this.fileName,
    this.headers,
    required this.chapter,
    this.concurrentDownloads = 1,
    required this.subtitles,
    this.refererUrl,
    this.mergeRunner,
  });

  void _log(String message) {
    if (kDebugMode) {
      log('[M3u8Downloader] $message');
    }
    AppLogger.log(message);
  }

  void close() {
    DownloadIsolatePool.instance.cancelTask('m3u8_${chapter.id}');
    isolateChapsSendPorts.remove('${chapter.id}');
  }

  /// Build effective headers, injecting Referer, User-Agent, and cookies.
  Map<String, String> _buildEffectiveHeaders({String? urlOverride}) {
    final uri = Uri.tryParse(urlOverride ?? m3u8Url);
    final origin = uri != null ? '${uri.scheme}://${uri.host}' : '';
    final effectiveReferer = refererUrl ?? origin;

    final merged = <String, String>{
      'User-Agent': _appUserAgent(),
      if (effectiveReferer.isNotEmpty) 'Referer': effectiveReferer,
      if (origin.isNotEmpty) 'Origin': origin,
      ...?headers,
    };

    // Inject cookies stored for this domain
    final cookies = MClient.getCookiesPref(urlOverride ?? m3u8Url);
    if (cookies.isNotEmpty) {
      merged.addAll(cookies);
      merged['User-Agent'] = _appUserAgent();
    }

    return merged;
  }

  String _appUserAgent() {
    return 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts) {
          throw M3u8DownloaderException(
            'Operation failed after $maxAttempts attempts',
            e,
          );
        }
        _log('Attempt $attempts failed, retrying in ${delay.inSeconds}s: $e');
        await Future.delayed(delay * attempts);
      }
    }
  }

  Future<(List<TsInfo>, Uint8List?, Uint8List?, int?)> _getTsList() async {
    try {
      var effectiveUrl = m3u8Url;
      // Fetch with full headers (anti-403)
      var m3u8Body = await _withRetry(() => _getM3u8Body(effectiveUrl));

      // If this is a master playlist (variant streams listed via
      // #EXT-X-STREAM-INF), follow the highest-bandwidth variant first,
      // otherwise we'd "download" the variant playlist URLs as if they were
      // TS segments (which produced a few-KB invalid mp4 file).
      if (m3u8Body.contains('#EXT-X-STREAM-INF')) {
        final variantUrl = _pickBestVariant(effectiveUrl, m3u8Body);
        if (variantUrl != null) {
          _log('Master playlist detected, switching to variant: $variantUrl');
          effectiveUrl = variantUrl;
          m3u8Body = await _withRetry(() => _getM3u8Body(effectiveUrl));
        }
      }

      final tsList = _parseTsList(effectiveUrl, m3u8Body);
      final mediaSequence = _extractMediaSequence(m3u8Body);

      _log("Total TS files to download: ${tsList.length}");

      final (key, iv) = await _getM3u8KeyAndIv(m3u8Body, effectiveUrl);
      if (key != null) _log("TS Key found");
      if (iv != null) _log("TS IV found");
      if (mediaSequence != null) _log("Media sequence: $mediaSequence");

      return (tsList, key, iv, mediaSequence);
    } catch (e) {
      // If we get a 403, attempt to re-fetch with refreshed headers
      _log('Failed to get TS list, attempting header refresh: $e');
      throw M3u8DownloaderException('Failed to get TS list', e);
    }
  }

  Future<void> download(void Function(DownloadProgress) onProgress) async {
    final tempDir = path.join(downloadDir, 'temp');
    await StorageProvider().createDirectorySafely(tempDir);

    try {
      final (tsList, key, iv, mediaSequence) = await _getTsList();

      final (tsListToDownload, completedSegments, downloadedBytes) =
          await _getResumeState(tsList, tempDir);
      _log('Downloading ${tsListToDownload.length} segments...');

      if (completedSegments > 0) {
        onProgress(
          DownloadProgress(
            completedSegments,
            tsList.length,
            chapter.manga.value!.itemType,
            downloadedBytes: downloadedBytes,
          ),
        );
      }

      await _downloadSegmentsWithProgress(
        tsListToDownload,
        tempDir,
        key,
        iv,
        mediaSequence,
        onProgress,
        totalSegments: tsList.length,
        initialCompletedSegments: completedSegments,
        initialDownloadedBytes: downloadedBytes,
      );

      for (var element in subtitles ?? <Track>[]) {
        final subtitleFile = File(
          path.join('${downloadDir}_subtitles', '${element.label}.srt'),
        );
        if (subtitleFile.existsSync()) {
          _log('Subtitle file already exists: ${element.label}');
          continue;
        }
        _log('Downloading subtitle file: ${element.label}');
        if (element.file == null || element.file!.trim().isEmpty) {
          _log('Warning: No subtitle file: ${element.label}');
          continue;
        }
        subtitleFile.createSync(recursive: true);
        if (element.file!.startsWith("http")) {
          final response = await _withRetry(
            () => httpClient.get(
              Uri.parse(element.file ?? ''),
              headers: _buildEffectiveHeaders(),
            ),
          );
          if (response.statusCode != 200) {
            _log('Warning: Failed to download subtitle file: ${element.label}');
            continue;
          }
          _log('Subtitle file downloaded: ${element.label}');
          await subtitleFile.writeAsBytes(response.bodyBytes);
        } else {
          _log('Subtitle file written: ${element.label}');
          await subtitleFile.writeAsString(element.file!);
        }
      }
    } catch (e) {
      AppLogger.log("Download failed", logLevel: LogLevel.error);
      AppLogger.log(e.toString(), logLevel: LogLevel.error);
      throw M3u8DownloaderException('Download failed', e);
    } finally {
      close();
    }
  }

  /// Returns the pending segments plus the durable progress already present
  /// on disk. A resumed HLS task must keep the original playlist denominator;
  /// otherwise the progress bar jumps backwards when only the remaining
  /// segments are submitted to the isolate. Empty files are deliberately not
  /// counted as complete: a zero-byte segment is never valid media and must
  /// be downloaded again.
  Future<(List<TsInfo>, int, int)> _getResumeState(
    List<TsInfo> tsList,
    String tempDir,
  ) async {
    final pending = <TsInfo>[];
    var completedSegments = 0;
    var downloadedBytes = 0;

    for (final segment in tsList) {
      final tsFile = File(path.join(tempDir, '${segment.name}.ts'));
      final doneFile = File('${tsFile.path}.done');
      if (tsFile.existsSync() && doneFile.existsSync()) {
        try {
          final size = await tsFile.length();
          if (size <= 0) {
            pending.add(segment);
            continue;
          }
          completedSegments++;
          downloadedBytes += size;
        } catch (_) {
          pending.add(segment);
        }
      } else {
        pending.add(segment);
      }
    }

    return (pending, completedSegments, downloadedBytes);
  }

  @visibleForTesting
  Future<(List<TsInfo>, int, int)> getResumeStateForTesting(
    List<TsInfo> tsList,
    String tempDir,
  ) => _getResumeState(tsList, tempDir);

  Future<void> _downloadSegmentsWithProgress(
    List<TsInfo> segments,
    String tempDir,
    Uint8List? key,
    Uint8List? iv,
    int? mediaSequence,
    void Function(DownloadProgress) onProgress, {
    required int totalSegments,
    required int initialCompletedSegments,
    required int initialDownloadedBytes,
  }) async {
    final completer = Completer<void>();
    final taskId = 'm3u8_${chapter.id}';

    isolateChapsSendPorts['${chapter.id}'] = true;

    await DownloadIsolatePool.instance.submitM3u8Download(
      taskId: taskId,
      segments: segments,
      tempDir: tempDir,
      key: key,
      iv: iv,
      mediaSequence: mediaSequence,
      totalSegments: totalSegments,
      initialCompletedSegments: initialCompletedSegments,
      initialDownloadedBytes: initialDownloadedBytes,
      concurrentDownloads: concurrentDownloads,
      headers: _buildEffectiveHeaders(),
      itemType: chapter.manga.value!.itemType,
      writeMode: DownloadSettingsService.instance.downloadWriteMode,
      speedLimitKBs: DownloadSettingsService.instance.speedLimitKBs,
      onProgress: (progress) {
        onProgress(progress);
      },
      onComplete: () async {
        try {
          await _mergeSegmentsAndCleanTemp(fileName, tempDir, onProgress);
          if (!completer.isCompleted) completer.complete();
        } catch (e, st) {
          _log('Merge failed: $e\n$st');
          if (!completer.isCompleted) completer.completeError(e, st);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onCancelled: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    return completer.future;
  }

  /// Merges the downloaded fragments and removes the resumable working
  /// directory only after a successful merge.
  Future<void> _mergeSegmentsAndCleanTemp(
    String outputFile,
    String tempDir,
    void Function(DownloadProgress) onProgress,
  ) async {
    await _mergeSegments(outputFile, tempDir, onProgress);

    // A failed merge must preserve valid fragments so a retry can resume.
    // Cleanup is deliberately after _mergeSegments succeeds, rather than in
    // a finally block, so a stale output file cannot hide a failed merge.
    if (await File(outputFile).exists() && await Directory(tempDir).exists()) {
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (e) {
        _log('Warning: failed to clean temporary directory: $e');
      }
    }
  }

  @visibleForTesting
  Future<void> mergeSegmentsAndCleanTempForTesting(
    String outputFile,
    String tempDir,
    void Function(DownloadProgress) onProgress,
  ) => _mergeSegmentsAndCleanTemp(outputFile, tempDir, onProgress);

  Future<void> _mergeSegments(
    String outputFile,
    String tempDir,
    void Function(DownloadProgress) onProgress,
  ) async {
    _log('Merging segments...');
    try {
      await _mergeTsToMp4(outputFile, tempDir);

      // Measure the actual merged file size so Isar stores the real value
      // instead of the segment-count estimate (which is always an under-estimate
      // because TS container overhead is not included in the per-segment average).
      int? actualBytes;
      try {
        actualBytes = await File(outputFile).length();
        _log(
          'Merge size: ${(actualBytes / 1024 / 1024).toStringAsFixed(1)} MB  path=$outputFile',
        );
      } catch (e) {
        _log('Warning: could not stat merged file: $e');
      }

      onProgress.call(
        DownloadProgress(
          1,
          1,
          chapter.manga.value!.itemType,
          isCompleted: true,
          downloadedBytes: actualBytes,
          totalBytes: actualBytes,
        ),
      );
      _log('Merge completed successfully');
    } catch (e) {
      throw M3u8DownloaderException('Failed to merge segments', e);
    }
  }

  Future<void> _mergeTsToMp4(String fileName, String directory) async {
    try {
      final dir = Directory(directory);
      final files =
          (await dir.list().where((entity) {
            if (!entity.path.endsWith('.ts')) return false;
            final file = File(entity.path);
            final marker = File('${entity.path}.done');
            return marker.existsSync() && file.lengthSync() > 0;
          }).toList())..sort((a, b) {
            final aIndex = int.parse(
              a.path.substringAfter("TS_").substringBefore("."),
            );
            final bIndex = int.parse(
              b.path.substringAfter("TS_").substringBefore("."),
            );
            return aIndex.compareTo(bIndex);
          });

      if (files.isEmpty) {
        throw M3u8DownloaderException(
          'No valid completed TS segments found in $directory',
        );
      }

      // Merge atomically: FFmpeg writes to <name>.mp4.part, then the result is
      // checked before it replaces the final file. A crash or a failed mux can
      // no longer leave a truncated file masquerading as a finished download.
      final partFile = File('$fileName.part');
      if (await partFile.exists()) await partFile.delete();

      final segmentPaths = files.map((file) => file.path).toList();
      final runner = mergeRunner ?? _runFfmpegMerge;
      await runner(partFile.path, segmentPaths);

      if (!await partFile.exists() || await partFile.length() <= 0) {
        throw M3u8DownloaderException('Merged output is empty ($fileName)');
      }

      final out = File(fileName);
      if (await out.exists()) await out.delete();
      await partFile.rename(out.path);
    } catch (e) {
      final partFile = File('$fileName.part');
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      if (e is M3u8DownloaderException) rethrow;
      throw M3u8DownloaderException('Failed to merge TS files', e);
    }
  }

  Future<void> _runFfmpegMerge(
    String outputFile,
    List<String> segmentPaths,
  ) async {
    final concatFile = File('$outputFile.concat.txt');
    await concatFile.writeAsString(
      segmentPaths
          .map((segmentPath) => "file '${_escapeConcatPath(segmentPath)}'")
          .join('\n'),
      flush: true,
    );

    try {
      final session = await FFmpegKit.executeWithArguments([
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatFile.path,
        '-map',
        '0',
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        '-y',
        outputFile,
      ]);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw M3u8DownloaderException(
          'FFmpeg merge failed (return code $returnCode)'
          '${output == null || output.trim().isEmpty ? '' : ': $output'}',
        );
      }
    } finally {
      if (await concatFile.exists()) {
        await concatFile.delete();
      }
    }
  }

  String _escapeConcatPath(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "'\\''");

  Future<String> _getM3u8Body(String url) async {
    final effectiveHeaders = _buildEffectiveHeaders(urlOverride: url);
    final response = await httpClient.get(
      Uri.parse(url),
      headers: effectiveHeaders,
    );

    if (response.statusCode == 403) {
      _log('403 Forbidden — retrying with refreshed headers...');
      // Wait briefly and retry with cookies refreshed
      await Future.delayed(const Duration(seconds: 1));
      final retryHeaders = _buildEffectiveHeaders(urlOverride: url);
      final retryResponse = await httpClient.get(
        Uri.parse(url),
        headers: retryHeaders,
      );
      if (retryResponse.statusCode != 200) {
        throw M3u8DownloaderException(
          'Failed to load m3u8 body (status ${retryResponse.statusCode} after retry)',
        );
      }
      return retryResponse.body;
    }

    if (response.statusCode != 200) {
      throw M3u8DownloaderException(
        'Failed to load m3u8 body (status ${response.statusCode})',
      );
    }
    return response.body;
  }

  /// Parse a master playlist and return the absolute URL of the variant
  /// stream with the highest BANDWIDTH (best quality available).
  @visibleForTesting
  static String? pickBestVariantForTesting(String baseUrl, String body) =>
      _pickBestVariant(baseUrl, body);

  static String? _pickBestVariant(String baseUrl, String body) {
    final lines = body.split('\n');
    int bestBw = -1;
    String? bestUrl;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      final bwMatch = RegExp(
        r'BANDWIDTH=(\d+)',
        caseSensitive: false,
      ).firstMatch(line);
      final bw = bwMatch != null
          ? int.tryParse(bwMatch.group(1) ?? '') ?? 0
          : 0;
      // The next non-comment, non-empty line is the variant URL.
      String? variant;
      for (var j = i + 1; j < lines.length; j++) {
        final cand = lines[j].trim();
        if (cand.isEmpty || cand.startsWith('#')) continue;
        variant = cand;
        break;
      }
      if (variant == null) continue;
      final absolute = Uri.parse(baseUrl).resolve(variant).toString();
      if (bw > bestBw) {
        bestBw = bw;
        bestUrl = absolute;
      }
    }
    return bestUrl;
  }

  @visibleForTesting
  static List<TsInfo> parseTsListForTesting(String baseUrl, String body) =>
      _parseTsList(baseUrl, body);

  static List<TsInfo> _parseTsList(String baseUrl, String body) {
    final lines = body.split('\n');
    final tsList = <TsInfo>[];
    var index = 1;

    // fMP4 playlists need their initialization fragment before all media
    // fragments. Dropping EXT-X-MAP produces files that may play briefly but
    // fail when seeking.
    String? initRef;
    for (final line in lines) {
      if (!line.trim().startsWith('#EXT-X-MAP')) continue;
      initRef = RegExp(
        r'URI="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(line)?.group(1);
      if (initRef != null && initRef!.isNotEmpty) break;
    }
    if (initRef != null && initRef!.isNotEmpty) {
      tsList.add(
        TsInfo(
          'TS_0',
          Uri.parse(baseUrl).resolve(initRef!).toString(),
          isInitialization: true,
        ),
      );
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final tsUrl = Uri.parse(baseUrl).resolve(trimmed).toString();
      tsList.add(TsInfo('TS_$index', tsUrl));
      index++;
    }
    return tsList;
  }

  Future<(Uint8List?, Uint8List?)> _getM3u8KeyAndIv(
    String m3u8Body,
    String playlistUrl,
  ) async {
    try {
      for (final line in m3u8Body.split('\n')) {
        if (!line.contains('#EXT-X-KEY')) continue;

        final (keyUrl, iv) = _extractKeyAttributes(line, playlistUrl);
        if (keyUrl == null) break;

        final response = await _withRetry(
          () => httpClient.get(
            Uri.parse(keyUrl),
            headers: _buildEffectiveHeaders(urlOverride: keyUrl),
          ),
        );
        if (response.statusCode == 200) {
          return (Uint8List.fromList(response.bodyBytes), iv);
        }
      }
      return (null, null);
    } catch (e) {
      throw M3u8DownloaderException('Failed to get m3u8 key and IV', e);
    }
  }

  @visibleForTesting
  static (String?, Uint8List?) extractKeyAttributesForTesting(
    String content,
    String baseUrl,
  ) => _extractKeyAttributes(content, baseUrl);

  static (String?, Uint8List?) _extractKeyAttributes(
    String content,
    String baseUrl,
  ) {
    final keyPattern = RegExp(
      r'#EXT-X-KEY:METHOD=AES-128(?:,URI="([^"]+)")?(?:,IV=0x([A-F0-9]+))?',
      caseSensitive: false,
    );
    final match = keyPattern.firstMatch(content);
    if (match == null) return (null, null);

    String? uri = match.group(1);
    if (uri != null) {
      uri = Uri.parse(baseUrl).resolve(uri).toString();
    }

    final ivStr = match.group(2);
    final iv = ivStr != null
        ? Uint8List.fromList(hex.decode(ivStr.replaceFirst('0x', '')))
        : null;

    return (uri, iv);
  }

  int? _extractMediaSequence(String content) {
    for (final line in content.split('\n')) {
      if (!line.startsWith('#EXT-X-MEDIA-SEQUENCE')) continue;
      return int.tryParse(line.substringAfter(':').trim());
    }
    return null;
  }
}

class M3u8DownloaderException implements Exception {
  final String message;
  final dynamic originalError;

  M3u8DownloaderException(this.message, [this.originalError]);

  @override
  String toString() =>
      'M3u8DownloaderException: $message${originalError != null ? ' ($originalError)' : ''}';
}
