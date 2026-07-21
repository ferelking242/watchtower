import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

enum TransferMode { idle, room, receiving, sending }

enum TransferStatus { pending, accepted, rejected, inProgress, done, failed }

enum TransferItemType { manga, anime, novel, other }

class PeerDevice {
  final String fingerprint;
  final String name;
  final String ip;
  final int port;
  DateTime seenAt;

  PeerDevice({
    required this.fingerprint,
    required this.name,
    required this.ip,
    required this.port,
    required this.seenAt,
  });

  bool get isStale => DateTime.now().difference(seenAt).inSeconds > 8;

  @override
  bool operator ==(Object other) =>
      other is PeerDevice && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;
}

class TransferFile {
  final String id;
  final String name;
  final int size;
  final TransferItemType type;
  final String? localPath;

  TransferFile({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'type': type.name,
      };

  factory TransferFile.fromJson(Map<String, dynamic> j) => TransferFile(
        id: j['id'] as String,
        name: j['name'] as String,
        size: (j['size'] as num).toInt(),
        type: TransferItemType.values.byName((j['type'] as String?) ?? 'other'),
      );

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static TransferItemType typeFromExtension(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    if (['cbz', 'cbr', 'zip', 'pdf'].contains(ext)) return TransferItemType.manga;
    if (['mp4', 'mkv', 'avi', 'webm', 'm4v'].contains(ext)) {
      return TransferItemType.anime;
    }
    if (['epub', 'fb2', 'mobi', 'txt'].contains(ext)) return TransferItemType.novel;
    return TransferItemType.other;
  }
}

class TransferOffer {
  final String sessionId;
  final PeerDevice from;
  final List<TransferFile> files;
  final DateTime receivedAt;

  TransferOffer({
    required this.sessionId,
    required this.from,
    required this.files,
    required this.receivedAt,
  });

  int get totalSize => files.fold(0, (s, f) => s + f.size);

  String get totalSizeLabel {
    final ts = totalSize;
    if (ts < 1024 * 1024) return '${(ts / 1024).toStringAsFixed(0)} KB';
    if (ts < 1024 * 1024 * 1024) {
      return '${(ts / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(ts / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class TransferSession {
  final String id;
  final PeerDevice peer;
  final List<TransferFile> files;
  final bool isSender;
  TransferStatus status;
  final Map<String, double> fileProgress;
  final DateTime startedAt;
  DateTime? completedAt;

  TransferSession({
    required this.id,
    required this.peer,
    required this.files,
    required this.isSender,
    this.status = TransferStatus.pending,
    DateTime? startedAt,
    Map<String, double>? fileProgress,
    this.completedAt,
  })  : fileProgress = fileProgress ?? {for (final f in files) f.id: 0.0},
        startedAt = startedAt ?? DateTime.now();

  double get totalProgress {
    if (files.isEmpty) return 0;
    final sum = fileProgress.values.fold(0.0, (s, v) => s + v);
    return sum / files.length;
  }

  int get totalSize => files.fold(0, (s, f) => s + f.size);

  TransferSession copyWith({TransferStatus? status, DateTime? completedAt}) =>
      TransferSession(
        id: id,
        peer: peer,
        files: files,
        isSender: isSender,
        status: status ?? this.status,
        startedAt: startedAt,
        fileProgress: fileProgress,
        completedAt: completedAt ?? this.completedAt,
      );
}

// ── Peer catalog (room mode) ──────────────────────────────────────────────────

class PeerCatalogEntry {
  final String mangaName;
  final String? imageUrl;
  final TransferItemType itemType;
  final List<PeerCatalogChapter> chapters;

  const PeerCatalogEntry({
    required this.mangaName,
    this.imageUrl,
    required this.itemType,
    required this.chapters,
  });

  factory PeerCatalogEntry.fromJson(Map<String, dynamic> j) => PeerCatalogEntry(
        mangaName: j['mangaName'] as String? ?? '—',
        imageUrl: j['imageUrl'] as String?,
        itemType: TransferItemType.values.byName(
            (j['itemType'] as String?) ?? 'manga'),
        chapters: ((j['chapters'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(PeerCatalogChapter.fromJson)
            .toList(),
      );

  int get totalSize => chapters.fold(0, (s, c) => s + c.size);
}

class PeerCatalogChapter {
  final String id;
  final String name;
  final int size;
  final TransferItemType type;

  const PeerCatalogChapter({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
  });

  factory PeerCatalogChapter.fromJson(Map<String, dynamic> j) =>
      PeerCatalogChapter(
        id: j['id'] as String,
        name: j['name'] as String? ?? '—',
        size: (j['size'] as num).toInt(),
        type: TransferItemType.values.byName(
            (j['type'] as String?) ?? 'manga'),
      );

  String get sizeLabel {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  TransferFile toTransferFile() =>
      TransferFile(id: id, name: name, size: size, type: type);
}
