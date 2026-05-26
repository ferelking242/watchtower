// Web stub — no media_kit on web platform.
// Same public API as watch_player_io.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/chapter.dart';

class WatchInlinePlayer {
  bool hasVideoUrl = false;
  int? loadedChapterId;

  void dispose() {}

  Future<void> load({
    required WidgetRef ref,
    required Chapter chapter,
  }) async {}

  Widget buildBannerOverlay({
    required BuildContext context,
    required List<Chapter> chapters,
  }) =>
      const SizedBox.shrink();

  Widget buildFullscreenPlayer() => const SizedBox.shrink();
}
