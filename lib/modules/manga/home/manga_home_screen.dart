import 'package:flutter/material.dart';

import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/home/widgets/enum_manga_home_widget.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';

/// Manga sources and watch extensions intentionally use the same home
/// data boundary, but the manga home composes its own section stack from
/// the shared [EnumMangaHomeWidget] cards for visual diversity.
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
    );
  }
}

/// Static composition of the manga home sections used by previews and
/// the component gallery. Production data flows through
/// [WatchExtensionHomeScreen]; this widget documents and previews the
/// exact section stack with the shared [EnumMangaHomeWidget] cards.
class MangaHomeSectionsPreview extends StatelessWidget {
  const MangaHomeSectionsPreview({
    required this.items,
    required this.onOpen,
    super.key,
  });

  final List<ContentItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in EnumMangaHomeWidget.values) ...[
          EnumMangaHomeWidgetCard(
            type: type,
            items: items,
            onOpen: onOpen,
            subtitle: type == EnumMangaHomeWidget.continueReading
                ? 'Chapitre 148 · il y a 2 h'
                : null,
            onSeeAll: () {},
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}
