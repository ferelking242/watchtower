import 'package:flutter/material.dart';

import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';

/// Manga sources and watch extensions intentionally use the same home
/// composition. Keeping this class as a thin compatibility wrapper preserves
/// existing manga routes while ensuring both entry points render the exact
/// same home, search and "All >" pages.
class MangaHomeScreen extends StatelessWidget {
  final Source source;
  final bool isSearch;
  final bool isLatest;
  final String query;

  const MangaHomeScreen({
    required this.source,
    this.query = '',
    this.isSearch = false,
    this.isLatest = false,
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
    );
  }
}