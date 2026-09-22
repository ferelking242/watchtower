import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_custom_list.g.dart';

@riverpod
Future<MPages?> getCustomList(
  Ref ref, {
  required Source source,
  required String listId,
  required int page,
}) async {
  final keepAlive = ref.keepAlive();
  final cacheTimer = Timer(const Duration(minutes: 2), keepAlive.close);
  ref.onDispose(cacheTimer.cancel);

  if (kIsWeb && RemoteClient.instance.isConfigured && source.id != null) {
    final data = await RemoteClient.instance.get(
      '/api/sources/${source.id}/custom',
      params: {'listId': listId, 'page': '$page'},
    );
    final results = (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
    if (results == null) {
      throw StateError('Remote custom list response did not contain mangas');
    }
    return MPages(
      list: results
          .map(
            (m) => MManga(
              name: m['name'] as String?,
              imageUrl: m['imageUrl'] as String?,
              link: m['link'] as String?,
              author: m['author'] as String?,
              description: m['description'] as String?,
            ),
          )
          .toList(),
      hasNextPage: data['hasNextPage'] as bool? ?? true,
    );
  }

  return getIsolateService.get<MPages?>(
    url: listId, // listId sent via the url field
    page: page,
    source: source,
    serviceType: 'getCustomList',
    proxyServer: ref.read(androidProxyServerStateProvider),
  );
}
