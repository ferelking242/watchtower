import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_web_sync.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_detail.g.dart';

@riverpod
Future<MManga> getDetail(
  Ref ref, {
  required String url,
  required Source source,
}) async {
  // ── Web: route through remote server ────────────────────────────────────
  if (kIsWeb && source.id != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('remote_server_url');
      if (baseUrl != null && baseUrl.isNotEmpty) {
        final data = await fetchRemoteDetail(baseUrl, source.id!, url);
        if (data != null) {
          final manga = data['manga'] as Map<String, dynamic>? ?? data;
          final rawChapters = data['chapters'] as List? ?? [];
          return MManga(
            name: manga['name'] as String?,
            imageUrl: manga['imageUrl'] as String?,
            link: manga['link'] as String? ?? url,
            author: manga['author'] as String?,
            description: manga['description'] as String?,
            status: Status.unknown,
            genre: (manga['genre'] as List?)?.cast<String>(),
            chapters: rawChapters.map<MChapter>((c) {
              final ch = c as Map<String, dynamic>;
              return MChapter(
                url: ch['url'] as String?,
                name: ch['name'] as String?,
                dateUpload: ch['dateUpload'] as String?,
                scanlator: ch['scanlator'] as String?,
              );
            }).toList(),
          );
        }
      }
    } catch (_) {}
    // Fallback: return a minimal MManga so the UI doesn't crash
    return MManga(link: url, name: '', description: '');
  }

  final proxyServer = ref.read(androidProxyServerStateProvider);
  return getIsolateService.get<MManga>(
    url: url,
    source: source,
    serviceType: 'getDetail',
    proxyServer: proxyServer,
  );
}
