import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'check_zeus_update.g.dart';

class ZeusRelease {
  final String version;
  final String htmlUrl;
  final String publishedAt;
  final bool isNightly;
  final List<ZeusReleaseAsset> assets;

  const ZeusRelease({
    required this.version,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isNightly,
    this.assets = const [],
  });
}

class ZeusReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  const ZeusReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

@riverpod
Future<ZeusRelease?> zeusLatestRelease(Ref ref) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final res = await http.get(
    Uri.parse(
      'https://api.github.com/repos/ferelking242/zeusdl/releases?page=1&per_page=5',
    ),
  );
  final List data = jsonDecode(res.body) as List;
  if (data.isEmpty) return null;
  final first = data.first as Map<String, dynamic>;
  final tag = (first['tag_name'] ?? first['name'] ?? 'unknown').toString();
  final isNightly = tag.contains('nightly');
  final List rawAssets = (first['assets'] as List?) ?? const [];
  final assets = rawAssets
      .whereType<Map<String, dynamic>>()
      .map((a) => ZeusReleaseAsset(
            name: (a['name'] ?? '').toString(),
            downloadUrl: (a['browser_download_url'] ?? '').toString(),
            size: (a['size'] is int) ? a['size'] as int : 0,
          ))
      .where((a) => a.downloadUrl.isNotEmpty)
      .toList();
  return ZeusRelease(
    version: tag,
    htmlUrl: first['html_url']?.toString() ?? '',
    publishedAt: first['published_at']?.toString() ?? '',
    isNightly: isNightly,
    assets: assets,
  );
}
