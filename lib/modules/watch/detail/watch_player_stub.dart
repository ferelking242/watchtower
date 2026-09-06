// Web stub — no media_kit on web platform.
// Same public API as watch_player_io.dart.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/video.dart';

class WatchInlinePlayer {
  bool hasVideoUrl = false;
  bool loadFailed = false;
  int? loadedChapterId;
  String title = '';
  List<Video> loadedVideos = [];
  String? selectedQuality;

  // Navigation callbacks — no-op on web
  // ignore: avoid_setters_without_getters
  set onPrevEpisode(VoidCallback? _) {}
  // ignore: avoid_setters_without_getters
  set onNextEpisode(VoidCallback? _) {}

  // Chapter list + tap — no-op on web
  // ignore: avoid_setters_without_getters
  set chapters(List<Chapter> _) {}
  // ignore: avoid_setters_without_getters
  set onEpisodeTap(void Function(Chapter)? _) {}

  // Controls visibility notifier — stub returns a constant false notifier
  final ValueNotifier<bool> controlsVisible = ValueNotifier(false);

  // Portrait/reel format notifier — always false on web (no reel mode)
  final ValueNotifier<bool> isPortraitFormat = ValueNotifier(false);

  // Callback fired when the active quality changes.
  // No-op setter on web — quality switching is not supported in the HTML5 stub.
  // ignore: avoid_setters_without_getters
  set onQualityChanged(VoidCallback? _) {}

  String? _videoUrl;
  String? _viewType;
  static final _registeredViews = <String>{};

  void dispose() {
    _videoUrl = null;
    _viewType = null;
    controlsVisible.dispose();
    isPortraitFormat.dispose();
  }

  /// No-op on web — reel mode is not supported in the HTML5 stub.
  void launchReelPage({
    required BuildContext context,
    required List<Chapter> chapters,
    required Chapter currentChapter,
  }) {
    // No reel page on web
  }

  /// No-op on web — quality switching is not supported in the HTML5 stub.
  Future<void> switchQuality(Video targetVideo) async {
    selectedQuality = targetVideo.quality;
  }

  void reset() {
    hasVideoUrl = false;
    loadFailed = false;
  }

  Future<void> load({
    required WidgetRef ref,
    required Chapter chapter,
  }) async {
    final url = chapter.url ?? '';
    _videoUrl = url;
    hasVideoUrl = url.isNotEmpty;
    loadedChapterId = chapter.id;

    if (hasVideoUrl) {
      final vt = 'wt_video_${chapter.id}';
      _viewType = vt;
      if (!_registeredViews.contains(vt)) {
        _registeredViews.add(vt);
        final src = url;
        ui_web.platformViewRegistry.registerViewFactory(
          vt,
          (int viewId) => html.VideoElement()
            ..src = src
            ..controls = true
            ..autoplay = false
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain'
            ..style.background = '#000000',
        );
      }
    }
  }

  Widget buildBannerOverlay({required BuildContext context}) {
    if (!hasVideoUrl || _viewType == null) return const SizedBox.shrink();
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType!),
    );
  }

  Widget buildFullscreenPlayer() {
    if (!hasVideoUrl || _viewType == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Lecteur non disponible sur web',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox.expand(
          child: HtmlElementView(viewType: _viewType!),
        ),
      ),
    );
  }
}
