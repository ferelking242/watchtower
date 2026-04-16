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

  const ZeusRelease({
    required this.version,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isNightly,
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
  return ZeusRelease(
    version: tag,
    htmlUrl: first['html_url']?.toString() ?? '',
    publishedAt: first['published_at']?.toString() ?? '',
    isNightly: isNightly,
  );
}
