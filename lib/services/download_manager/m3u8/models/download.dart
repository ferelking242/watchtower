import 'dart:isolate';
import 'dart:typed_data';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/download_manager/m3u8/models/ts_info.dart';

class DownloadParams {
  final List<TsInfo>? segments;
  final String? tempDir;
  final Uint8List? key;
  final Uint8List? iv;
  final int? mediaSequence;
  final int? concurrentDownloads;
  final Map<String, String>? headers;
  final SendPort? sendPort;
  final List<PageUrl>? pageUrls;
  final ItemType? itemType;

  DownloadParams({
    this.segments,
    this.tempDir,
    this.key,
    this.iv,
    this.mediaSequence,
    this.concurrentDownloads,
    this.headers,
    this.sendPort,
    this.pageUrls,
    this.itemType,
  });

  @override
  String toString() {
    return 'DownloadParams(segments: ${segments?.length}, tempDir: $tempDir, mediaSequence: $mediaSequence, concurrentDownloads: $concurrentDownloads, pageUrls: ${pageUrls?.length})';
  }
}

class DownloadComplete {}

class DownloadProgress {
  TsInfo? segment;
  PageUrl? pageUrl;
  final int completed;
  final int total;
  bool isCompleted;
  ItemType itemType;

  /// True when a direct transfer has no trustworthy final length.
  /// Its byte count is real, but it must not be presented as a percentage.
  final bool isIndeterminate;

  /// Bytes downloaded so far (used for video progress display, in bytes).
  /// When non-null and [totalBytes] > 0, the UI shows "14 MB / 58 MB"
  /// instead of a percentage.
  final int? downloadedBytes;

  /// Total size in bytes. Estimated from Content-Length or segment accumulation.
  final int? totalBytes;

  DownloadProgress(
    this.completed,
    this.total,
    this.itemType, {
    this.segment,
    this.pageUrl,
    this.isCompleted = false,
    this.isIndeterminate = false,
    this.downloadedBytes,
    this.totalBytes,
  });

  DownloadProgress.directFile({
    required int downloadedBytes,
    required int? totalBytes,
    required ItemType itemType,
    PageUrl? pageUrl,
  }) : this(
         downloadedBytes,
         totalBytes ?? 0,
         itemType,
         pageUrl: pageUrl,
         isIndeterminate: totalBytes == null || totalBytes <= 0,
         downloadedBytes: downloadedBytes,
         totalBytes: totalBytes,
       );

  /// Real progress when the transfer has a byte total or a known unit total.
  /// HLS uses completed/total segments until the merged file size is known;
  /// unknown-length direct files stay indeterminate instead of inventing a
  /// byte denominator.
  double? get progressFraction {
    if (isCompleted) return 1;
    final bytes = downloadedBytes;
    final byteTotal = totalBytes;
    if (bytes != null && byteTotal != null && byteTotal > 0) {
      return (bytes / byteTotal).clamp(0.0, 1.0).toDouble();
    }
    if (!isIndeterminate && total > 0) {
      return (completed / total).clamp(0.0, 1.0).toDouble();
    }
    return null;
  }

  @override
  String toString() {
    return 'DownloadProgress(segment: $segment, pageUrl: $pageUrl completed: $completed, total: $total, isCompleted: $isCompleted, bytes: $downloadedBytes/$totalBytes)';
  }
}
