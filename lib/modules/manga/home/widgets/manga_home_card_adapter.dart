import 'package:flutter/widgets.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart';

/// Adapts extension home data to the Manga card components that can display it.
///
/// Manga list items currently expose title, cover, description, and status.
/// Cards requiring chapter history, progress, or ranking data are deliberately
/// not registered in this context.
class MangaHomeCardAdapter {
  const MangaHomeCardAdapter._();

  static Widget? build({
    required String component,
    required ContentItem item,
    required double width,
    required VoidCallback onTap,
  }) {
    final definition = LayoutComponentRegistry.resolve(component);
    if (definition == null ||
        !definition.supportedContexts.contains(
          LayoutComponentContext.homeMangaCard,
        )) {
      return null;
    }

    return switch (definition.renderer) {
      LayoutComponentRenderer.mangaFeaturedCard => MangaFeaturedCard(
        item: item,
        width: width,
        onTap: onTap,
      ),
      LayoutComponentRenderer.mangaChapterCard => MangaChapterCard(
        item: item,
        width: width,
        onTap: onTap,
      ),
      _ => null,
    };
  }
}
