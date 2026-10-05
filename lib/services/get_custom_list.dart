import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/extension_page_cache.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/saved_watch_progress.dart';
import 'package:watchtower/services/watch_progress_storage.dart';
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

  Future<MPages?> load() async {
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
                previewUrl: m['previewUrl'] as String?,
                link: m['link'] as String?,
                collectionId: m['collectionId'] as String?,
                author: m['author'] as String?,
                description: m['description'] as String?,
                genre: (m['genre'] as List?)?.map((e) => e.toString()).toList(),
              ),
            )
            .toList(),
        hasNextPage: data['hasNextPage'] as bool? ?? true,
      );
    }

    final pages = await getIsolateService.get<MPages?>(
      url: listId, // listId sent via the url field
      page: page,
      source: source,
      serviceType: 'getCustomList',
      proxyServer: ref.read(androidProxyServerStateProvider),
    );
    if (pages == null || listId != 'history' || !source.touchToPreview) {
      return pages;
    }
    final titles = pages.list
        .map((item) => item.name?.trim())
        .whereType<String>()
        .where((title) => title.isNotEmpty);
    final positions = await loadSavedWatchPositions(titles);
    for (final item in pages.list) {
      final progress = positions[item.name?.trim()];
      if (progress == null) continue;
      final position = progress.position;
      final hours = position.inHours;
      final minutes = position.inMinutes.remainder(60);
      final seconds = position.inSeconds.remainder(60);
      final timestamp = hours > 0
          ? '${hours.toString().padLeft(2, '0')}:'
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}'
          : '${position.inMinutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}';
      final savedAt = progress.savedAt;
      final updatedAt = savedAt == null
          ? null
          : _formatProgressTime(savedAt.toLocal());
      item.description = updatedAt == null
          ? 'Reprise à $timestamp'
          : 'Reprise à $timestamp · $updatedAt';
    }
    return pages;
  }

  // Resume-history descriptions are derived from live progress and should not
  // be cached. Other extension lists are stable for the short cache window.
  if (listId == 'history' && source.touchToPreview) return load();
  return extensionPageCache.getOrLoad(
    ExtensionPageCacheKey.forSource(
      source: source,
      service: 'custom',
      listId: listId,
      page: page,
    ),
    load,
  );
}

String _formatProgressTime(DateTime dateTime) {
  const monthNames = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final year = dateTime.year == DateTime.now().year ? '' : ' ${dateTime.year}';
  final date = '${dateTime.day.toString().padLeft(2, '0')} '
      '${monthNames[dateTime.month - 1]}$year';
  final time =
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
