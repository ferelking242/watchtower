import '../video_providers/scraper_api.dart';

/// Loads signed stream-size estimates in parallel without making an estimate a
/// prerequisite for selecting a resolution.
abstract final class StreamSizeEstimator {
  static const Duration timeout = Duration(seconds: 10);
  static final Map<String, Future<StreamSizeEstimate?>> _inFlightByRequest = {};

  static Future<Map<String, int?>> load({
    required String scraperApiUrl,
    required Map<String, String> tokens,
    required Map<String, int?> cacheByToken,
    void Function(String token, int? estimatedBytes)? onEstimate,
  }) async {
    final pendingByToken = <String, Future<StreamSizeEstimate?>>{};

    for (final token in tokens.values) {
      if (token.trim().isEmpty ||
          cacheByToken.containsKey(token) ||
          pendingByToken.containsKey(token)) {
        continue;
      }
      final requestKey = '$scraperApiUrl\u0000$token';
      final request = _inFlightByRequest.putIfAbsent(requestKey, () async {
        try {
          return await ScraperApi(scraperApiUrl).estimateStreamSize(token);
        } finally {
          _inFlightByRequest.remove(requestKey);
        }
      });
      pendingByToken[token] = request.then((estimate) {
        cacheByToken[token] = estimate?.estimatedBytes;
        onEstimate?.call(token, estimate?.estimatedBytes);
        return estimate;
      });
    }

    final completed = <String, StreamSizeEstimate?>{};
    final requests = <Future<StreamSizeEstimate?>>[
      for (final entry in pendingByToken.entries)
        entry.value.then((estimate) {
          completed[entry.key] = estimate;
          return estimate;
        }),
    ];

    if (requests.isNotEmpty) {
      await Future.wait(requests).timeout(
        timeout,
        onTimeout: () => <StreamSizeEstimate?>[],
      );
    }

    for (final entry in tokens.entries) {
      if (!cacheByToken.containsKey(entry.value)) {
        cacheByToken[entry.value] = completed[entry.value]?.estimatedBytes;
        onEstimate?.call(entry.value, cacheByToken[entry.value]);
      }
    }
    return {
      for (final entry in tokens.entries) entry.key: cacheByToken[entry.value],
    };
  }
}
