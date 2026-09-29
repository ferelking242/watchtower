import 'package:watchtower/eval/model/m_manga.dart';

/// Carries a collection's extension list id through the existing MManga
/// contract so collection cards open a browse list instead of a video detail.
class ExtensionCollectionRoute {
  const ExtensionCollectionRoute({required this.listId});

  final String listId;

  static ExtensionCollectionRoute? fromItem(MManga item) {
    final collectionId = item.collectionId?.trim();
    if (collectionId != null && collectionId.isNotEmpty) {
      return ExtensionCollectionRoute(listId: collectionId);
    }

    // Older extension payloads only carried their collection URL. Keep those
    // navigable while new payloads use the explicit collectionId field.
    final link = item.link?.trim();
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    final path = uri.path.toLowerCase();
    final search = uri.queryParameters['search']?.trim();
    if (path.endsWith('/video/search') &&
        search != null &&
        search.isNotEmpty) {
      return ExtensionCollectionRoute(listId: 'category_$search');
    }
    if (path.endsWith('/video') &&
        uri.queryParameters['o']?.trim().isNotEmpty == true) {
      return ExtensionCollectionRoute(
        listId: 'playlist_${uri.queryParameters['o']!.trim()}',
      );
    }
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        segments[segments.length - 2].toLowerCase() == 'language') {
      return ExtensionCollectionRoute(
        listId: 'language_${segments.last}',
      );
    }
    return null;
  }
}