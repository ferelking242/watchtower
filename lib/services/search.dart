
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_web_sync.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'search.g.dart';

@riverpod
Future<MPages?> search(
  Ref ref, {
  required Source source,
  required String query,
  required int page,
  required List<dynamic> filterList,
}) async {
  // Web: route through remote server if configured
  if (kIsWeb) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('remote_server_url');
      if (baseUrl != null && baseUrl.isNotEmpty && source.id != null) {
        final results = await fetchRemoteSearch(baseUrl, source.id!, query, page);
        if (results != null) {
          return MPages(
            list: results.map((m) => MManga(
              name: m['name'] as String?,
              imageUrl: m['imageUrl'] as String?,
              link: m['link'] as String?,
              author: m['author'] as String?,
              description: m['description'] as String?,
            )).toList(),
            hasNextPage: true,
          );
        }
      }
    } catch (_) {}
    // Fallback: search in MockIsar demo data
    final result =
        (await isar.mangas
                .filter()
                .itemTypeEqualTo(source.itemType)
                .nameContains(query, caseSensitive: false)
                .offset(max(0, page - 1) * 50)
                .limit(50)
                .findAll())
            .map((e) => MManga(name: e.name, imageUrl: e.imageUrl, link: e.link))
            .toList();
    return MPages(list: result, hasNextPage: false);
  }

  if (source.name == "local" && source.lang == "") {
    final result =
        (await isar.mangas
                .filter()
                .itemTypeEqualTo(source.itemType)
                .group(
                  (q) => q
                      .sourceEqualTo("local")
                      .or()
                      .linkContains("Watchtower/local")
                      .or()
                      .linkContains("Watchtower\\local"),
                )
                .nameContains(query, caseSensitive: false)
                .offset(max(0, page - 1) * 50)
                .limit(50)
                .findAll())
            .map((e) => MManga(name: e.name))
            .toList();
    return MPages(list: result, hasNextPage: true);
  }
  return getIsolateService.get<MPages?>(
    query: query,
    filterList: filterList,
    source: source,
    page: page,
    serviceType: 'search',
    proxyServer: ref.read(androidProxyServerStateProvider),
  );
}
