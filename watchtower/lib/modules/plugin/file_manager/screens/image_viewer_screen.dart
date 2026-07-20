// lib/modules/plugin/file_manager/screens/image_viewer_screen.dart
// Visionneuse d'images plein écran avec swipe entre images du dossier.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FmImageViewerScreen extends StatefulWidget {
  /// [initialPath] : chemin de l'image ouverte.
  /// [allPaths]   : liste ordonnée de toutes les images du même dossier.
  final String initialPath;
  final List<String> allPaths;

  const FmImageViewerScreen({
    super.key,
    required this.initialPath,
    required this.allPaths,
  });

  @override
  State<FmImageViewerScreen> createState() => _FmImageViewerScreenState();
}

class _FmImageViewerScreenState extends State<FmImageViewerScreen> {
  late PageController _pageCtrl;
  late int _currentIndex;
  bool _uiVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allPaths.indexOf(widget.initialPath);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageCtrl = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUi() => setState(() => _uiVisible = !_uiVisible);

  @override
  Widget build(BuildContext context) {
    final images = widget.allPaths;
    final name = p.basename(images[_currentIndex]);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _uiVisible
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              title: Text(name,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${_currentIndex + 1} / ${images.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleUi,
        child: PhotoViewGallery.builder(
          pageController: _pageCtrl,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          builder: (_, i) => PhotoViewGalleryPageOptions(
            imageProvider: FileImage(File(images[i])),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_rounded,
                  size: 64, color: Colors.white30),
            ),
          ),
          loadingBuilder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
