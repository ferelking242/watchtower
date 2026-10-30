/// Normalises cover URLs that point at a sprite sheet rather than a picture.
///
/// XNXX publishes `mozaique_listing.jpg` (a 3×3 grid of nine frames) and
/// `mozaique_full.jpg` (a 10×10 grid of a hundred frames) next to the real
/// single-frame still (`xn_10_t.jpg`). Rendered as a cover, a mosaic shows the
/// "plusieurs images collées" grid. Extensions are expected to hand back the
/// single frame, but a source pinned to an older commit keeps emitting the
/// mosaic, and rows already persisted in Isar hold it too. Rewriting the name
/// here repairs both without touching stored data.
String? normalizeCoverUrl(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return url;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return url;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return url;
  final file = segments.last;
  final dot = file.lastIndexOf('.');
  final stem = dot > 0 ? file.substring(0, dot) : file;
  final ext = dot > 0 ? file.substring(dot) : '';
  if (stem != 'mozaique_listing' && stem != 'mozaique_full') return url;
  final replaced = [...segments.sublist(0, segments.length - 1), 'xn_10_t$ext'];
  return uri.replace(pathSegments: replaced).toString();
}

/// Grid geometry of a known sprite sheet, or null for a normal picture.
///
/// Used by the cover widgets as a second line of defence: even if a mosaic URL
/// slips through (older extension build, stored row), the widget crops the
/// first tile instead of showing the whole grid.
({int columns, int rows})? mosaicGrid(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.pathSegments.isEmpty) return null;
  final file = uri.pathSegments.last;
  final dot = file.lastIndexOf('.');
  final stem = (dot > 0 ? file.substring(0, dot) : file).toLowerCase();
  return switch (stem) {
    'mozaique_listing' => (columns: 3, rows: 3),
    'mozaique_full' => (columns: 10, rows: 10),
    _ => null,
  };
}
