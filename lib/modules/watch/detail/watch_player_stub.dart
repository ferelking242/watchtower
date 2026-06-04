// Web stub — no media_kit on web platform.
// Same public API as watch_player_io.dart.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/chapter.dart';

class WatchInlinePlayer {
  bool hasVideoUrl = false;
  int? loadedChapterId;
  String title = '';

  String? _videoUrl;
  String? _viewType;
  static final _registeredViews = <String>{};

  void dispose() {
    _videoUrl = null;
    _viewType = null;
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
