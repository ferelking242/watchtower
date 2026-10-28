import 'package:flutter/widgets.dart';

/// Carries the HTTP headers an extension declares (browser User-Agent and
/// Referer) down to the artwork widgets.
///
/// Some image CDNs refuse a request whose `Referer` is absent or is not the
/// reader site: Harimanga's `img-r1.2xstorage.com` answers 403 to everything
/// except `Referer: https://www.harimanga.co.uk/`. Cards build a
/// [ContentImage] from a bare URL, so without this they would fetch every
/// cover headerless and show a placeholder for all of them.
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
