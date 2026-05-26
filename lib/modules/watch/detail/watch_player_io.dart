// Native (Android / iOS / desktop) inline video player.
// Conditionally imported by watch_detail_view.dart via:
//   import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

class WatchInlinePlayer {
  static const _teal = Color(0xFF1DB954);

  final Player _player;
  late final VideoController _controller;

  bool hasVideoUrl = false;
  int? loadedChapterId;

  WatchInlinePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  void dispose() {
    _player.dispose();
  }

  /// Fetch the video URL for [chapter] and start playback.
  /// Idempotent: caller must set [loadedChapterId] before calling.
  Future<void> load({
    required WidgetRef ref,
    required Chapter chapter,
  }) async {
    try {
      final data =
          await ref.read(getVideoListProvider(episode: chapter).future);
      final (videos, _, __, ___) = data;
      if (videos.isNotEmpty) {
        final v = videos.first;
        await _player.open(
          Media(v.url, httpHeaders: v.headers),
          play: true,
        );
        hasVideoUrl = true;
      }
    } catch (_) {
      // Silently fall back to poster image
    }
  }

  /// Overlay shown on top of the poster image inside the SliverAppBar banner.
  /// Returns an empty widget when the video is not yet ready.
  Widget buildBannerOverlay({
    required BuildContext context,
    required List<Chapter> chapters,
  }) {
    if (!hasVideoUrl) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        ),
        // Fullscreen button — opens the dedicated player view
        Positioned(
          bottom: 10,
          right: 10,
          child: GestureDetector(
            onTap: chapters.isEmpty
                ? null
                : () => chapters.first
                    .pushToReaderView(context, ignoreIsRead: true),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Full-screen landscape player widget.
  Widget buildFullscreenPlayer() {
    return Video(
      controller: _controller,
      fit: BoxFit.contain,
      controls: MaterialVideoControls,
    );
  }
}
