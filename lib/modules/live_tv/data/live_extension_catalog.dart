import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// The extension catalogue Live TV installs from.
///
/// Live TV providers are published exactly like Watch and Manga extensions: one
/// index per content type in the extensions repository. The app ships no
/// provider list of its own — [liveIndexPath] is the only place a catalogue
/// location is named, so adding a provider means publishing it upstream, not
/// cutting a release.
///
/// Nothing here executes foreign code. A provider is a declarative record (a
/// playlist URL, or an asset path for a bundled catalogue), so the worst a
/// hostile index can do is offer bad channels.
class LiveExtensionCatalog {
  /// The official repository, shared with the Watch and Manga catalogues.
  static const baseUrl =
      'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';

  /// Live TV's index inside that repository.
  static const liveIndexPath = 'index/live.json';

  static String get liveIndexUrl => '$baseUrl/$liveIndexPath';

  /// Fetches and parses the Live TV index.
  ///
  /// A malformed entry is skipped rather than failing the whole catalogue: one
  /// bad provider upstream must not empty Live TV. A network failure is
  /// reported to the caller, which decides whether to keep the installed list.
  static Future<List<LiveProviderCatalogEntry>> fetch({
    http.Client? client,
    String? url,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(url ?? liveIndexUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw LiveCatalogException(
          'Catalogue indisponible (HTTP ${response.statusCode}).',
        );
      }
      return parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } on LiveCatalogException {
      rethrow;
    } on Exception catch (error) {
      throw LiveCatalogException('Catalogue injoignable : $error');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Parses an index body.
  ///
  /// Accepts the same shapes as the Watch index — a bare list, or an object
  /// wrapping it under `providers`/`entries`/`data` — so a repository can host
  /// Live TV beside the other catalogues without a bespoke format.
  @visibleForTesting
  static List<LiveProviderCatalogEntry> parse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const [];
    }

    final list = _entryList(decoded);
    if (list == null) return const [];

    final seen = <String>{};
    final entries = <LiveProviderCatalogEntry>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final entry = LiveProviderCatalogEntry.fromJson(
        raw.cast<String, dynamic>(),
      );
      if (entry == null) continue;
      // The catalogue guarantees unique ids; an upstream duplicate would
      // otherwise show twice and install over itself.
      if (!seen.add(entry.id)) continue;
      entries.add(entry);
    }
    return entries;
  }

  static List<dynamic>? _entryList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const ['providers', 'entries', 'data', 'items']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return null;
  }
}

/// A catalogue failure the UI can show verbatim.
class LiveCatalogException implements Exception {
  const LiveCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
