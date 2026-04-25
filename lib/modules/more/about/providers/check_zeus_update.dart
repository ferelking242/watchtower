import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';
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

// ── Caching ──────────────────────────────────────────────────────────────────
//
// The previous implementation hit api.github.com on every UI rebuild,
// which produced log spam (4-6 requests/minute while the About screen
// was visible) and risked GitHub rate-limiting (60 anonymous requests
// per hour). We now memoize the answer for [_cacheTtl] and only make a
// network call when the cache is stale or [forceRefresh] is true.
const Duration _cacheTtl = Duration(minutes: 5);
ZeusRelease? _cachedRelease;
DateTime? _cachedAt;
Future<ZeusRelease?>? _inflight;

/// Manually clear the cache so the next read of [zeusLatestReleaseProvider]
/// hits the network. Pair with `ref.invalidate(zeusLatestReleaseProvider)`
/// when the user explicitly taps "Check for updates".
void invalidateZeusReleaseCache() {
  _cachedRelease = null;
  _cachedAt = null;
}

@riverpod
Future<ZeusRelease?> zeusLatestRelease(Ref ref) async {
  final now = DateTime.now();
  if (_cachedRelease != null &&
      _cachedAt != null &&
      now.difference(_cachedAt!) < _cacheTtl) {
    return _cachedRelease;
  }

  // Coalesce concurrent fetches into one network call.
  if (_inflight != null) return _inflight;

  _inflight = _fetchZeusRelease();
  try {
    final result = await _inflight!;
    _cachedRelease = result;
    _cachedAt = DateTime.now();
    return result;
  } finally {
    _inflight = null;
  }
}

Future<ZeusRelease?> _fetchZeusRelease() async {
  try {
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
  } catch (e, st) {
    AppLogger.log(
      'zeusLatestRelease fetch failed: $e\n$st',
      logLevel: LogLevel.warning,
      tag: LogTag.network,
    );
    // Return whatever we have cached (even if stale) on transient errors,
    // so the UI keeps showing the last known state instead of nothing.
    return _cachedRelease;
  }
}
