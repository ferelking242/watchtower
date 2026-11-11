import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path/path.dart' as p;

/// Durable description of an HLS episode's segment list, written next to the
/// fragments while they download.
///
/// The merged `.mp4` only exists once every fragment is in. Without this file a
/// partially-downloaded episode carries no information about what is missing or
/// where it sits on the real timeline, so it could only ever be played as a
/// truncated file. Persisting the playlist order and each fragment's `#EXTINF`
/// duration is what lets the player reconstruct the original timeline for the
/// fragments that *are* present.
class HlsSegmentManifest {
  /// Playlist order, one entry per media fragment (the fMP4 initialization
  /// fragment is excluded — it carries no duration and is always kept).
  final List<HlsSegmentEntry> segments;

  /// File name of the fMP4 initialization fragment in the working directory,
  /// or null for MPEG-TS playlists.
  final String? initSegmentName;

  const HlsSegmentManifest({
    required this.segments,
    this.initSegmentName,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'initSegmentName': initSegmentName,
    'segments': segments.map((segment) => segment.toJson()).toList(),
  };

  factory HlsSegmentManifest.fromJson(Map<String, dynamic> json) {
    final rawSegments = (json['segments'] as List?) ?? const [];
    return HlsSegmentManifest(
      initSegmentName: json['initSegmentName'] as String?,
      segments: [
        for (final raw in rawSegments)
          HlsSegmentEntry.fromJson((raw as Map).cast<String, dynamic>()),
      ],
    );
  }

  static HlsSegmentManifest? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return HlsSegmentManifest.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static const String fileName = 'segments.json';

  static File fileIn(String tempDir) => File(p.join(tempDir, fileName));

  /// Best-effort write; a failure must never abort a download that is otherwise
  /// making progress.
  static Future<void> write(
    String tempDir,
    HlsSegmentManifest manifest,
  ) async {
    try {
      await fileIn(tempDir).writeAsString(jsonEncode(manifest.toJson()));
    } catch (_) {}
  }

  static Future<HlsSegmentManifest?> read(String tempDir) async {
    try {
      final file = fileIn(tempDir);
      if (!await file.exists()) return null;
      return decode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }
}

class HlsSegmentEntry {
  /// Fragment name as written on disk, without the `.ts` extension (e.g.
  /// `TS_1`).
  final String name;

  /// Real duration from `#EXTINF`, in milliseconds. Zero when the playlist
  /// omitted it.
  final int durationMs;

  const HlsSegmentEntry({required this.name, required this.durationMs});

  Map<String, dynamic> toJson() => {'name': name, 'durationMs': durationMs};

  factory HlsSegmentEntry.fromJson(Map<String, dynamic> json) =>
      HlsSegmentEntry(
        name: (json['name'] ?? '').toString(),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      );
}
