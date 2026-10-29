import 'package:flutter/widgets.dart';

/// Carries the HTTP headers an extension declares (browser User-Agent and
/// Referer) down to the artwork widgets.
///
/// Some image CDNs are hotlink-protected and want the reader site's `Referer`.
/// Cards build a [ContentImage] from a bare URL, so without this scope they
/// would fetch covers headerless and risk a placeholder. Note that not every
/// reported placeholder bug is a hotlink one: the 2026-10-26 Harimanga case
/// (`img-r1.2xstorage.com`) served `200` even with no header at all, and the
/// real cause was the extension routing covers onto an incomplete mirror. This
/// scope is still the right place to pass extension headers to artwork.
///
/// Installed once per extension screen; [ContentImage] reads it back with
/// [of]. Callers that already pass explicit headers keep precedence.
class ExtensionImageHeaders extends InheritedWidget {
  const ExtensionImageHeaders({
    super.key,
    required this.headers,
    required super.child,
  });

  /// An empty map when the extension declares none: a screen with no headers
  /// simply behaves as before.
  final Map<String, String> headers;

  static Map<String, String>? of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ExtensionImageHeaders>();
    final headers = scope?.headers;
    if (headers == null || headers.isEmpty) return null;
    return headers;
  }

  @override
  bool updateShouldNotify(ExtensionImageHeaders oldWidget) =>
      !_sameHeaders(oldWidget.headers, headers);

  static bool _sameHeaders(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
