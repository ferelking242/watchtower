import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum IntroDbSegmentType { intro, recap, credits, preview }

class IntroDbSegment {
  const IntroDbSegment({required this.type, required this.startMs, this.endMs});

  final IntroDbSegmentType type;
  final int startMs;
  final int? endMs;
}

class IntroDbTimings {
  const IntroDbTimings(this.segments);

  final List<IntroDbSegment> segments;

  static const empty = IntroDbTimings(<IntroDbSegment>[]);
}

class IntroDbService {
  IntroDbService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static final Uri _mediaEndpoint = Uri.parse(
    'https://api.theintrodb.org/v3/media',
  );

  final http.Client _client;
  final bool _ownsClient;

  Future<IntroDbTimings> fetch({
    required int tmdbId,
    required bool isTv,
    int? season,
    int? episode,
    int? durationMs,
  }) async {
    if (tmdbId <= 0 || (isTv && (season == null || episode == null))) {
      debugPrint(
        '[IntroDB] lookup skipped: invalid metadata '
        'tmdbId=$tmdbId isTv=$isTv season=$season episode=$episode',
      );
      return IntroDbTimings.empty;
    }

    final query = <String, String>{'tmdb_id': '$tmdbId'};
    if (isTv) {
      query['season'] = '$season';
      query['episode'] = '$episode';
    }
    if (durationMs != null && durationMs > 0) {
      query['duration_ms'] = '$durationMs';
    }

    final requestUri = _mediaEndpoint.replace(queryParameters: query);
    debugPrint('[IntroDB] GET $requestUri');
    final response = await _getWithRetry(requestUri);
    debugPrint(
      '[IntroDB] response status=${response.statusCode} '
      'bytes=${response.bodyBytes.length}',
    );
    if (response.statusCode == 404) {
      debugPrint('[IntroDB] no accepted timings for this media');
      return IntroDbTimings.empty;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IntroDbException(
          'IntroDB request failed (HTTP ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const IntroDbException('Invalid IntroDB response');
    }

    final segments = <IntroDbSegment>[];
    for (final type in IntroDbSegmentType.values) {
      final raw = decoded[_keyFor(type)];
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is! Map) continue;
        final start = _intValue(item['start_ms']) ?? 0;
        final end = _intValue(item['end_ms']);
        if (start < 0 || (end != null && end <= start)) continue;
        segments.add(IntroDbSegment(type: type, startMs: start, endMs: end));
      }
    }
    final merged = _merge(segments);
    final normalized = durationMs != null && durationMs > 0
        ? _normalizeToDuration(merged, durationMs)
        : merged;
    debugPrint(
      '[IntroDB] parsed ${segments.length} ranges, '
      'merged=${merged.length} normalized=${normalized.length} '
      'ranges=${normalized.map((segment) => '${segment.type.name}:'
          '${segment.startMs}-${segment.endMs ?? 'end'}').join(',')}',
    );
    return IntroDbTimings(normalized);
  }

  String _keyFor(IntroDbSegmentType type) => switch (type) {
        IntroDbSegmentType.intro => 'intro',
        IntroDbSegmentType.recap => 'recap',
        IntroDbSegmentType.credits => 'credits',
        IntroDbSegmentType.preview => 'preview',
      };

  List<IntroDbSegment> _merge(List<IntroDbSegment> input) {
    final byType = <IntroDbSegmentType, List<IntroDbSegment>>{};
    for (final segment in input) {
      byType.putIfAbsent(segment.type, () => []).add(segment);
    }
    final merged = <IntroDbSegment>[];
    for (final entry in byType.entries) {
      final values = entry.value
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      var current = values.first;
      for (final next in values.skip(1)) {
        final currentEnd = current.endMs;
        if (currentEnd == null || next.startMs <= currentEnd) {
          final nextEnd = currentEnd == null || next.endMs == null
              ? null
              : (currentEnd > next.endMs! ? currentEnd : next.endMs);
          current = IntroDbSegment(
            type: current.type,
            startMs: current.startMs,
            endMs: nextEnd,
          );
        } else {
          merged.add(current);
          current = next;
        }
      }
      merged.add(current);
    }
    merged.sort((a, b) => a.startMs.compareTo(b.startMs));
    return List.unmodifiable(merged);
  }

  List<IntroDbSegment> _normalizeToDuration(
    List<IntroDbSegment> segments,
    int durationMs,
  ) {
    final normalized = <IntroDbSegment>[];
    for (final segment in segments) {
      var startMs = segment.startMs;
      var endMs = segment.endMs;
      if (startMs >= durationMs) {
        if (segment.type != IntroDbSegmentType.credits) {
          debugPrint(
            '[IntroDB] discarded out-of-range ${segment.type.name} '
            '${segment.startMs}-${segment.endMs ?? 'end'} '
            'durationMs=$durationMs',
          );
          continue;
        }
        // Some entries describe a longer cut than the selected provider. An
        // open-ended credits marker beyond this stream can never activate, so
        // fall back to the final 5% rather than losing both end controls.
        startMs = (durationMs * .95).floor();
        endMs = durationMs;
        debugPrint(
          '[IntroDB] adjusted out-of-range credits '
          '${segment.startMs}-${segment.endMs ?? 'end'} -> '
          '$startMs-$endMs durationMs=$durationMs',
        );
      } else if (endMs == null || endMs > durationMs) {
        endMs = durationMs;
      }
      if (endMs <= startMs) continue;
      normalized.add(
        IntroDbSegment(
          type: segment.type,
          startMs: startMs,
          endMs: endMs,
        ),
      );
    }
    return List<IntroDbSegment>.unmodifiable(normalized);
  }

  int? _intValue(dynamic value) =>
      value is int ? value : int.tryParse('$value');

  Future<http.Response> _getWithRetry(Uri uri) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _client.get(uri).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[IntroDB] request timed out attempt=$attempt/2');
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        debugPrint('[IntroDB] retrying request');
      }
    }
    throw StateError('Unreachable IntroDB retry state');
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class IntroDbException implements Exception {
  const IntroDbException(this.message);

  final String message;

  @override
  String toString() => message;
}
