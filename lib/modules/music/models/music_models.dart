import 'package:flutter/foundation.dart';

// ─── Image ───────────────────────────────────────────────────────────────────

class MusicImage {
  final String url;
  final int? width;
  final int? height;
  const MusicImage({required this.url, this.width, this.height});

  factory MusicImage.fromJson(Map<String, dynamic> j) => MusicImage(
        url: j['url'] ?? '',
        width: j['width'],
        height: j['height'],
      );
  Map<String, dynamic> toJson() => {'url': url, 'width': width, 'height': height};

  String get bestUrl => url;
}

// ─── Artist ──────────────────────────────────────────────────────────────────

class MusicArtist {
  final String id;
  final String name;
  final List<MusicImage> images;
  final String? externalUrl;

  const MusicArtist({
    required this.id,
    required this.name,
    this.images = const [],
    this.externalUrl,
  });

  factory MusicArtist.fromJson(Map<String, dynamic> j) => MusicArtist(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        images: (j['images'] as List?)
                ?.map((e) => MusicImage.fromJson(e))
                .toList() ??
            [],
        externalUrl: j['external_url'],
      );

  String get imageUrl =>
      images.isNotEmpty ? images.first.url : '';
}

// ─── Album ───────────────────────────────────────────────────────────────────

class MusicAlbum {
  final String id;
  final String name;
  final List<MusicImage> images;
  final List<MusicArtist> artists;
  final String? releaseDate;
  final int? totalTracks;

  const MusicAlbum({
    required this.id,
    required this.name,
    this.images = const [],
    this.artists = const [],
    this.releaseDate,
    this.totalTracks,
  });

  factory MusicAlbum.fromJson(Map<String, dynamic> j) => MusicAlbum(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        images: (j['images'] as List?)
                ?.map((e) => MusicImage.fromJson(e))
                .toList() ??
            [],
        artists: (j['artists'] as List?)
                ?.map((e) => MusicArtist.fromJson(e))
                .toList() ??
            [],
        releaseDate: j['release_date'],
        totalTracks: j['total_tracks'],
      );

  String get imageUrl => images.isNotEmpty ? images.first.url : '';
  String get artistNames => artists.map((a) => a.name).join(', ');
}

// ─── Track ───────────────────────────────────────────────────────────────────

class MusicTrack {
  final String id;
  final String name;
  final MusicAlbum album;
  final List<MusicArtist> artists;
  final int durationMs;
  final bool explicit;
  final String? previewUrl;
  final String? sourceUrl;   // resolved audio URL (YouTube, etc.)
  bool isLiked;

  MusicTrack({
    required this.id,
    required this.name,
    required this.album,
    required this.artists,
    required this.durationMs,
    this.explicit = false,
    this.previewUrl,
    this.sourceUrl,
    this.isLiked = false,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> j) => MusicTrack(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        album: MusicAlbum.fromJson(j['album'] ?? {}),
        artists: (j['artists'] as List?)
                ?.map((e) => MusicArtist.fromJson(e))
                .toList() ??
            [],
        durationMs: j['duration_ms'] ?? 0,
        explicit: j['explicit'] ?? false,
        previewUrl: j['preview_url'],
        sourceUrl: j['source_url'],
        isLiked: j['is_liked'] ?? false,
      );

  Duration get duration => Duration(milliseconds: durationMs);
  String get imageUrl => album.imageUrl;
  String get artistNames => artists.map((a) => a.name).join(', ');

  MusicTrack copyWith({String? sourceUrl, bool? isLiked}) => MusicTrack(
        id: id,
        name: name,
        album: album,
        artists: artists,
        durationMs: durationMs,
        explicit: explicit,
        previewUrl: previewUrl,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        isLiked: isLiked ?? this.isLiked,
      );

  @override
  bool operator ==(Object other) =>
      other is MusicTrack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─── Playlist ────────────────────────────────────────────────────────────────

class MusicPlaylist {
  final String id;
  final String name;
  final String? description;
  final List<MusicImage> images;
  final String? ownerName;
  final int? trackCount;
  final bool isPublic;
  final List<MusicTrack> tracks;

  const MusicPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.images = const [],
    this.ownerName,
    this.trackCount,
    this.isPublic = true,
    this.tracks = const [],
  });

  factory MusicPlaylist.fromJson(Map<String, dynamic> j) => MusicPlaylist(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        description: j['description'],
        images: (j['images'] as List?)
                ?.map((e) => MusicImage.fromJson(e))
                .toList() ??
            [],
        ownerName: j['owner']?['display_name'],
        trackCount: j['tracks']?['total'],
        isPublic: j['public'] ?? true,
      );

  String get imageUrl => images.isNotEmpty ? images.first.url : '';
}

// ─── Audio Player State ───────────────────────────────────────────────────────

enum MusicRepeatMode { none, track, playlist }

@immutable
class MusicPlayerState {
  final List<MusicTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffled;
  final MusicRepeatMode repeatMode;
  final Duration position;
  final Duration buffered;

  const MusicPlayerState({
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isShuffled = false,
    this.repeatMode = MusicRepeatMode.none,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
  });

  MusicTrack? get activeTrack =>
      queue.isNotEmpty && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  Duration get duration => activeTrack?.duration ?? Duration.zero;

  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  double get bufferProgress => duration.inMilliseconds > 0
      ? buffered.inMilliseconds / duration.inMilliseconds
      : 0.0;

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < queue.length - 1;

  MusicPlayerState copyWith({
    List<MusicTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    bool? isShuffled,
    MusicRepeatMode? repeatMode,
    Duration? position,
    Duration? buffered,
  }) =>
      MusicPlayerState(
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        isBuffering: isBuffering ?? this.isBuffering,
        isShuffled: isShuffled ?? this.isShuffled,
        repeatMode: repeatMode ?? this.repeatMode,
        position: position ?? this.position,
        buffered: buffered ?? this.buffered,
      );
}
