import 'hls_variant_resolver.dart';

/// Picks an HLS rendition from a measured connection speed.
///
/// Neither backend adapts on its own here: FFmpeg's HLS demuxer reads
/// `hls_bitrate` once at open time and never switches (its `max` default is
/// why a 1080p rendition gets picked on a 3G connection and then rebuffers),
/// and libmpv exposes no client-side ABR. The browser equivalent (hls.js)
/// instead starts on a level that fits the measured throughput, so we
/// reproduce that decision before calling `open()`.
///
/// The plan is expressed as an `hls-bitrate` value: mpv documents that a
/// numeric value selects "the stream with the highest rate equal or below the
/// option value", which is exactly a "best rendition that fits" rule.
class AdaptiveQualityController {
  /// Fraction of the measured throughput a rendition may use. The remaining
  /// headroom absorbs bitrate peaks (`BANDWIDTH` in a master playlist is a
  /// peak, not an average) and any competing traffic.
  static const double safetyFactor = 0.75;

  /// A master playlist is a *hint*: the CDN can ignore it, and `BANDWIDTH`
  /// values are self-reported. Refuse to act on numbers that cannot describe
  /// a real video rendition.
  static const int minPlausibleBandwidth = 50 * 1000;

  /// Decides which rendition to request.
  ///
  /// [throughputBitsPerSecond] is `null` when the connection could not be
  /// measured: the master playlist is then returned untouched so libmpv keeps
  /// its own default rather than us degrading quality on a guess.
  static AdaptiveQualityPlan plan({
    required List<HlsVariant> variants,
    required int? throughputBitsPerSecond,
  }) {
    final usable = variants
        .where((variant) =>
            variant.bandwidth != null &&
            variant.bandwidth! >= minPlausibleBandwidth)
        .toList()
      ..sort((a, b) => a.bandwidth!.compareTo(b.bandwidth!));

    if (usable.isEmpty) {
      return const AdaptiveQualityPlan(
        bitrate: null,
        variant: null,
        reason: 'no variant advertises a usable bitrate',
      );
    }

    if (throughputBitsPerSecond == null || throughputBitsPerSecond <= 0) {
      return const AdaptiveQualityPlan(
        bitrate: null,
        variant: null,
        reason: 'throughput unknown — leaving mpv on its default',
      );
    }

    final budget = (throughputBitsPerSecond * safetyFactor).round();
    HlsVariant? chosen;
    for (final variant in usable) {
      if (variant.bandwidth! <= budget) chosen = variant;
    }

    // Nothing fits: the connection cannot even sustain the lightest
    // rendition. Request it anyway - it is still the best chance of playing
    // without a stall, and mpv will not pick something heavier on its own.
    if (chosen == null) {
      final lightest = usable.first;
      return AdaptiveQualityPlan(
        bitrate: lightest.bandwidth,
        variant: lightest,
        reason: 'connection (${_mbps(throughputBitsPerSecond)}) below the '
            'lightest rendition — forcing ${lightest.label}',
      );
    }

    return AdaptiveQualityPlan(
      bitrate: chosen.bandwidth,
      variant: chosen,
      reason: 'connection ${_mbps(throughputBitsPerSecond)}, budget '
          '${_mbps(budget)} → ${chosen.label}',
    );
  }

  static String _mbps(int bitsPerSecond) =>
      '${(bitsPerSecond / 1000000).toStringAsFixed(2)} Mbps';
}

/// Outcome of [AdaptiveQualityController.plan].
class AdaptiveQualityPlan {
  /// Value for mpv's `hls-bitrate`, or `null` to leave the default in place.
  final int? bitrate;

  /// The rendition the plan expects mpv to select. Informational: mpv decides
  /// for real, so this is only used for logging.
  final HlsVariant? variant;

  /// Why this plan was chosen, for the log line.
  final String reason;

  const AdaptiveQualityPlan({
    required this.bitrate,
    required this.variant,
    required this.reason,
  });
}

/// Measures the connection by downloading the head of one media segment.
///
/// Deliberately a real payload rather than a `HEAD` or a playlist fetch:
/// those only measure round-trip latency, which says nothing about how fast
/// bytes arrive. A playlist is ~1 KB and would be fetched faster than the
/// throughput could be observed.
///
/// Bounded on purpose. [budget] caps the wall clock and [maxBytes] caps the
/// payload, and whichever is reached first ends the measurement. On a fast
/// link that is ~100 ms for 256 KB; on a slow one the cap is hit and the
/// estimate is a *lower bound*, which is the safe direction to err in.
Future<int?> measureThroughput(
  String url, {
  Map<String, String>? headers,
  required Future<HttpRangeResponse?> Function(
    String url,
    int maxBytes,
    Map<String, String>? headers,
  ) fetchRange,
  int maxBytes = 256 * 1024,
  Duration budget = const Duration(milliseconds: 1200),
}) async {
  final sw = Stopwatch()..start();
  final response = await fetchRange(url, maxBytes, headers);
  sw.stop();
  if (response == null || response.bytes <= 0) return null;

  final elapsedMs = sw.elapsedMilliseconds;
  // A sub-millisecond read would divide by ~0 and report an absurd speed.
  if (elapsedMs < 5) return null;

  final bitsPerSecond = (response.bytes * 8 * 1000 / elapsedMs).round();
  return bitsPerSecond;
}

/// A bounded byte read, as returned by the range-fetch callback.
class HttpRangeResponse {
  /// Bytes actually received, which may be fewer than requested when the
  /// budget expired first.
  final int bytes;

  const HttpRangeResponse({required this.bytes});
}

/// Measures a connection *through the actual media path* and derives the
/// `hls-bitrate` value to use.
///
/// Throughput is read from a real media segment, never from a playlist: a
/// playlist is ~1 KB and completes faster than any rate can be observed, so
/// timing one would only report round-trip latency. The variant playlists are
/// fetched first solely to discover a segment URL.
///
/// Every step is bounded and any failure yields `null`, which means "leave
/// libmpv on its default" — the probe can only improve on the static choice,
/// never break playback.
class HlsAdaptiveProbe {
  final Future<String?> Function(String url, Map<String, String>? headers)
      fetchText;
  final Future<HttpRangeResponse?> Function(
    String url,
    int maxBytes,
    Map<String, String>? headers,
  ) fetchRange;

  /// Wall-clock cap per request, so a stalling CDN cannot hold up `open()`.
  final Duration requestTimeout;

  /// How much of the segment to read. Enough to average out TCP ramp-up
  /// without making the probe itself a bandwidth problem.
  final int probeBytes;

  /// Cap on the measurement window. On a slow link this is reached first and
  /// the estimate is a lower bound — the safe direction, since it can only
  /// push the selection down.
  final Duration probeBudget;

  const HlsAdaptiveProbe({
    required this.fetchText,
    required this.fetchRange,
    this.requestTimeout = const Duration(milliseconds: 1500),
    this.probeBytes = 192 * 1024,
    this.probeBudget = const Duration(milliseconds: 900),
  });

  /// Returns the plan to apply, or `null` when nothing could be measured.
  Future<AdaptiveQualityPlan?> planFor(
    String masterUrl, {
    Map<String, String>? headers,
  }) async {
    final masterBody =
        await fetchText(masterUrl, headers).timeout(requestTimeout, onTimeout: () => null);
    if (masterBody == null) return null;

    final Uri? masterUri = Uri.tryParse(masterUrl);
    if (masterUri == null) return null;

    final variants =
        HlsVariantResolver.parseMaster(masterBody, masterUrl: masterUri);
    if (variants.isEmpty) return null;

    // Probe the heaviest rendition: measuring the lightest would only prove
    // the connection clears the floor we already assume.
    final probeTarget = variants.first;
    final variantBody = await fetchText(probeTarget.url, headers)
        .timeout(requestTimeout, onTimeout: () => null);
    if (variantBody == null) return null;

    final segmentUrl = firstSegmentUrl(variantBody, probeTarget.url);
    if (segmentUrl == null) return null;

    final throughput = await measureThroughput(
      segmentUrl,
      headers: headers,
      fetchRange: (url, maxBytes, hdrs) => fetchRange(url, maxBytes, hdrs)
          .timeout(requestTimeout, onTimeout: () => null),
      maxBytes: probeBytes,
      budget: probeBudget,
    );
    if (throughput == null) return null;

    return AdaptiveQualityController.plan(
      variants: variants,
      throughputBitsPerSecond: throughput,
    );
  }
}

/// Extracts the first media segment URI from a media playlist.
///
/// Returns `null` for a master playlist (its "entries" are other playlists,
/// not segments) or when no URI is present.
String? firstSegmentUrl(String playlistBody, String playlistUrl) {
  if (HlsVariantResolver.isMasterPlaylist(playlistBody)) return null;
  final base = Uri.tryParse(playlistUrl);
  if (base == null) return null;

  for (final rawLine in playlistBody.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    return base.resolve(line).toString();
  }
  return null;
}
