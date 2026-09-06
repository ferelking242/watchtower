
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_popular.g.dart';

@riverpod
Future<MPages?> getPopular(
  Ref ref, {
  required Source source,
  required int page,
}) async {
  // Web: route through remote server if configured
  if (kIsWeb) {
    try {
      if (RemoteClient.instance.isConfigured && source.id != null) {
        final data = await RemoteClient.instance.get(
          '/api/sources/${source.id}/popular',
          params: {'page': '$page'},
        );
        final results = (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
        if (results != null) {
          return MPages(
            list: results.map((m) => MManga(
              name: m['name'] as String?,
              imageUrl: m['imageUrl'] as String?,
              link: m['link'] as String?,
              author: m['author'] as String?,
              description: m['description'] as String?,
            )).toList(),
            hasNextPage: data['hasNextPage'] as bool? ?? true,
          );
        }
      }
    } catch (_) {}
    // Fallback: return from MockIsar (static demo data)
    final result = (await isar.mangas
            .filter()
            .itemTypeEqualTo(source.itemType)
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
                .sortByName()
                .offset(max(0, page - 1) * 50)
                .limit(50)
                .findAll())
            .map((e) => MManga(name: e.name))
            .toList();
    return MPages(list: result, hasNextPage: true);
  }

  return getIsolateService.get<MPages?>(
    page: page,
    source: source,
    serviceType: 'getPopular',
    proxyServer: ref.read(androidProxyServerStateProvider),
  );
}
