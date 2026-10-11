import 'package:flutter/material.dart';

import 'package:watchtower/models/gallery_component_palette.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';

/// Manga sources and watch extensions share the same home data boundary.
///
/// The section stack is owned by [GalleryComponentPalette.mangaHomeStack] and
/// rendered by the shared gallery renderer, so the manga home shows the exact
/// cards the developer gallery previews. There is no second renderer: add or
/// reorder a section by editing `mangaHomeStack`.
class MangaHomeScreen extends StatelessWidget {
  final Source source;
  final bool isSearch;
  final bool isLatest;
  final bool isLayoutEditing;
  final String query;

  const MangaHomeScreen({
    required this.source,
    this.query = '',
    this.isSearch = false,
    this.isLatest = false,
    this.isLayoutEditing = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final initialQuery = isSearch && query.trim().isNotEmpty
        ? query.trim()
        : null;

    return WatchExtensionHomeScreen(
      source: source,
      initialSearchQuery: initialQuery,
      initialSectionId: isLatest ? 'latest' : null,
      layoutEditorMode: isLayoutEditing,
      defaultSections: GalleryComponentPalette.buildSections(
        GalleryComponentPalette.mangaHomeStack,
      ),
    );
  }
}
