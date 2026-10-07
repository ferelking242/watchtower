import 'package:isar_community/isar.dart';
import 'package:watchtower/models/chapter.dart';

part 'download.g.dart';

@collection
@Name("Download")
class Download {
  Id? id;

  int? succeeded;

  int? failed;

  int? total;

  bool? isDownload;

  bool? isStartDownload;

  /// Exact transfer counters. The legacy succeeded/total fields remain in KB
  /// for backwards-compatible queue rendering, while these fields preserve the
  /// server's real Content-Length and resume offset across process restarts.
  int? downloadedBytes;
  int? totalBytes;

  String? title;
  String? quality;
  String? posterUrl;
  String? filePath;
  String? status;

  final chapter = IsarLink<Chapter>();

  Download({
    this.id = 0,
    required this.succeeded,
    required this.failed,
    required this.total,
    required this.isDownload,
    required this.isStartDownload,
    this.downloadedBytes,
    this.totalBytes,
    this.title,
    this.quality,
    this.posterUrl,
    this.filePath,
    this.status,
  });
  Download.fromJson(Map<String, dynamic> json) {
    failed = json['failed'];
    id = json['id'];
    isDownload = json['isDownload'];
    isStartDownload = json['isStartDownload'];
    succeeded = json['succeeded'];
    total = json['total'];
    downloadedBytes = json['downloadedBytes'];
    totalBytes = json['totalBytes'];
    title = json['title'];
    quality = json['quality'];
    posterUrl = json['posterUrl'];
    filePath = json['filePath'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() => {
    'failed': failed,
    'id': id,
    'isDownload': isDownload,
    'isStartDownload': isStartDownload,
    'succeeded': succeeded,
    'total': total,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'title': title,
    'quality': quality,
    'posterUrl': posterUrl,
    'filePath': filePath,
    'status': status,
  };
}
