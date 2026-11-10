import 'dart:math' as math;

import 'package:watchtower/services/download_manager/partial/hls_segment_manifest.dart';

/// A contiguous span of the episode's real timeline.
class PlayableRange {
  /// Real start, in milliseconds from the beginning of the episode.
  final int startMs;

  /// Real end, in milliseconds from the beginning of the episode.
  final int endMs;

  const PlayableRange(this.startMs, this.endMs);

  int get durationMs => endMs - startMs;

  bool get isEmpty => endMs <= startMs;

  @override
  String toString() => 'PlayableRange($startMs..$endMs)';

  @override
  bool operator ==(Object other) =>
      other is PlayableRange && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);
}

/// Where a seek should actually land.
class PartialSeekTarget {
  /// Position on the real timeline the player will display.
  final int realMs;

  /// Position within the partial (available-only) media the player must seek to.
  final int compressedMs;

  /// True when the requested position fell inside a gap and was moved to the
  /// next available fragment.
  final bool jumped;

  const PartialSeekTarget({
    required this.realMs,
    required this.compressedMs,
    required this.jumped,
  });
}

/// Pure, side-effect-free description of how a partially-downloaded HLS episode
/// maps onto its original timeline.
///
/// The fragments that are present are played as one continuous stream (a local
/// playlist built from [availableIndices]), which is what a demuxer can play
/// without any filler. That stream has a *compressed* timeline — the gaps are
/// simply absent. This plan carries the mapping between that compressed
/// timeline and the episode's real timeline so the UI can show the real
/// position, paint the missing spans, and jump a seek that lands in a gap to the
/// next fragment that is actually there.
class PartialPlaybackPlan {
  /// Full playlist order (every fragment, present or not).
  final List<HlsSegmentEntry> segments;

  /// Aligned with [segments]: whether each fragment is present and non-empty.
  final List<bool> available;

  /// Real start of each fragment, aligned with [segments].
  final List<int> realStartMs;

  /// Real end of each fragment, aligned with [segments].
  final List<int> realEndMs;

  /// Indices of the available fragments, in playlist order.
  final List<int> availableIndices;

  /// Cumulative compressed start of each available fragment, aligned with
  /// [availableIndices].
  final List<int> compressedStartMs;

  /// Contiguous available spans of the real timeline.
  final List<PlayableRange> playableRanges;

  /// Contiguous missing spans of the real timeline.
  final List<PlayableRange> gapRanges;

  /// Real duration of the whole episode.
  final int totalDurationMs;

  /// Sum of the durations of the available fragments.
  final int availableDurationMs;

  /// True when every fragment is present.
  final bool isComplete;

  /// False when the playlist carried no `#EXTINF` durations, in which case the
  /// real timeline is unknown and every mapping degrades to the compressed one.
  final bool hasDurationInfo;

  const PartialPlaybackPlan({
    required this.segments,
    required this.available,
    required this.realStartMs,
    required this.realEndMs,
    required this.availableIndices,
    required this.compressedStartMs,
    required this.playableRanges,
    required this.gapRanges,
    required this.totalDurationMs,
    required this.availableDurationMs,
    required this.isComplete,
    required this.hasDurationInfo,
  });

  bool get hasPlayableContent => availableIndices.isNotEmpty;

  /// True when nothing is missing; the caller should just play the merged file.
  bool get isFullyAvailable => isComplete;

  /// Longest fragment duration in whole seconds, for `#EXT-X-TARGETDURATION`.
  int get targetDurationSeconds {
    var maxMs = 0;
    for (final segment in segments) {
      maxMs = math.max(maxMs, segment.durationMs);
    }
    // HLS requires a positive integer; a one-second floor keeps playlists
    // valid when every fragment is shorter than a second.
    return math.max(1, (maxMs / 1000).ceil());
  }

  /// Real position of the start of the next available fragment at or after
  /// [realMs], or null when nothing playable remains.
  PlayableRange? nextPlayableRange(int realMs) {
    for (final range in playableRanges) {
      if (range.endMs > realMs) return range;
    }
    return null;
  }

  /// Resolves a requested real position to a concrete seek.
  ///
  /// A position inside a gap is redirected to the start of the next available
  /// fragment; a position past the end is clamped to the end of the last
  /// available fragment. This is the "ne saute pas, va à la prochaine partie
  /// disponible" behaviour — never an error, never a crash.
  PartialSeekTarget resolveSeek(int realMs) {
    final clamped = realMs.clamp(0, math.max(0, totalDurationMs)).toInt();
    for (final range in playableRanges) {
      if (clamped >= range.startMs && clamped < range.endMs) {
        return PartialSeekTarget(
          realMs: clamped,
          compressedMs: realToCompressedMs(clamped),
          jumped: false,
        );
      }
    }
    final next = nextPlayableRange(clamped);
    if (next != null) {
      return PartialSeekTarget(
        realMs: next.startMs,
        compressedMs: realToCompressedMs(next.startMs),
        jumped: true,
      );
    }
    // Nothing after: land on the end of the last available fragment.
    final last = playableRanges.isEmpty ? null : playableRanges.last;
    final endMs = last?.endMs ?? 0;
    return PartialSeekTarget(
      realMs: endMs,
      compressedMs: availableDurationMs,
      jumped: clamped != endMs,
    );
  }

  /// Real timeline position for a position within the partial (compressed)
  /// media. A compressed position that lands at the start of a fragment which
  /// follows a gap maps to that fragment's real start, so the displayed clock
  /// jumps forward over the missing span instead of drifting.
  int compressedToRealMs(int compressedMs) {
    if (availableIndices.isEmpty) return 0;
    final clamped = compressedMs.clamp(0, math.max(0, availableDurationMs)).toInt();
    for (var i = availableIndices.length - 1; i >= 0; i--) {
      final start = compressedStartMs[i];
      if (clamped >= start) {
        final segIndex = availableIndices[i];
        final withinMs = clamped - start;
        final segDuration = segments[segIndex].durationMs;
        return realStartMs[segIndex] + math.min(withinMs, segDuration);
      }
    }
    return realStartMs[availableIndices.first];
  }

  /// Position within the partial media for a real timeline position. A real
  /// position inside a gap maps to the compressed position where the next
  /// available fragment begins.
  int realToCompressedMs(int realMs) {
    if (availableIndices.isEmpty) return 0;
    final clamped = realMs.clamp(0, math.max(0, totalDurationMs)).toInt();
    for (var i = 0; i < availableIndices.length; i++) {
      final segIndex = availableIndices[i];
      if (clamped < realEndMs[segIndex]) {
        final withinMs = math.max(0, clamped - realStartMs[segIndex]);
        return compressedStartMs[i] + withinMs;
      }
    }
    return availableDurationMs;
  }

  /// The gap crossed when playback moves from [fromRealMs] to [toRealMs], or
  /// null when the move stays inside a playable span.
  PlayableRange? gapCrossedBetween(int fromRealMs, int toRealMs) {
    if (toRealMs <= fromRealMs) return null;
    for (final gap in gapRanges) {
      if (gap.startMs < toRealMs && gap.endMs > fromRealMs) return gap;
    }
    return null;
  }
}

/// Builds a plan from the playlist order and a per-fragment availability flag.
PartialPlaybackPlan buildPartialPlaybackPlan({
  required List<HlsSegmentEntry> segments,
  required List<bool> available,
}) {
  final count = segments.length;
  final realStart = List<int>.filled(count, 0);
  final realEnd = List<int>.filled(count, 0);
  var cursor = 0;
  for (var i = 0; i < count; i++) {
    realStart[i] = cursor;
    cursor += segments[i].durationMs;
    realEnd[i] = cursor;
  }
  final totalDurationMs = cursor;

  final availableIndices = <int>[];
  final compressedStart = <int>[];
  var compressedCursor = 0;
  for (var i = 0; i < count; i++) {
    final isAvailable = i < available.length && available[i];
    if (!isAvailable || segments[i].durationMs <= 0) continue;
    availableIndices.add(i);
    compressedStart.add(compressedCursor);
    compressedCursor += segments[i].durationMs;
  }
  final availableDurationMs = compressedCursor;

  final playableRanges = <PlayableRange>[];
  final gapRanges = <PlayableRange>[];
  var runStart = -1;
  for (var i = 0; i < count; i++) {
    final isAvailable =
        i < available.length && available[i] && segments[i].durationMs > 0;
    if (isAvailable && runStart < 0) {
      runStart = realStart[i];
    } else if (!isAvailable && runStart >= 0) {
      playableRanges.add(PlayableRange(runStart, realStart[i]));
      gapRanges.add(PlayableRange(realStart[i], realEnd[i]));
      runStart = -1;
    }
  }
  if (runStart >= 0) {
    playableRanges.add(PlayableRange(runStart, totalDurationMs));
  }

  // Build the gaps as the clean complement of the playable ranges so the UI
  // never draws overlapping spans.
  final mergedGaps = <PlayableRange>[];
  var cursorMs = 0;
  for (final range in playableRanges) {
    if (range.startMs > cursorMs) {
      mergedGaps.add(PlayableRange(cursorMs, range.startMs));
    }
    cursorMs = range.endMs;
  }
  if (cursorMs < totalDurationMs) {
    mergedGaps.add(PlayableRange(cursorMs, totalDurationMs));
  }

  return PartialPlaybackPlan(
    segments: segments,
    available: [
      for (var i = 0; i < count; i++) i < available.length && available[i],
    ],
    realStartMs: realStart,
    realEndMs: realEnd,
    availableIndices: availableIndices,
    compressedStartMs: compressedStart,
    playableRanges: playableRanges,
    gapRanges: mergedGaps,
    totalDurationMs: totalDurationMs,
    availableDurationMs: availableDurationMs,
    isComplete: count > 0 && availableIndices.length == count,
    hasDurationInfo: totalDurationMs > 0,
  );
}

/// Builds the local `#EXTM3U` playlist that plays only the available fragments.
///
/// No `#EXT-X-KEY` is emitted: the fragments on disk are already decrypted. The
/// fMP4 initialization fragment, when present, is emitted through `#EXT-X-MAP`
/// so a CMAF stream keeps its `moov`. Gaps are simply absent, which is why a
/// linear playback flows straight from one available fragment to the next.
String buildPartialPlaylistText({
  required PartialPlaybackPlan plan,
  String? initSegmentFileName,
}) {
  final buffer = StringBuffer()
    ..writeln('#EXTM3U')
    ..writeln('#EXT-X-VERSION:3')
    ..writeln('#EXT-X-PLAYLIST-TYPE:VOD')
    ..writeln('#EXT-X-TARGETDURATION:${plan.targetDurationSeconds}')
    ..writeln('#EXT-X-MEDIA-SEQUENCE:0');
  if (initSegmentFileName != null && initSegmentFileName.isNotEmpty) {
    buffer.writeln('#EXT-X-MAP:URI="$initSegmentFileName"');
  }
  for (final index in plan.availableIndices) {
    final seconds = plan.segments[index].durationMs / 1000;
    buffer
      ..writeln('#EXTINF:${seconds.toStringAsFixed(3)},')
      ..writeln('${plan.segments[index].name}.ts');
  }
  buffer.writeln('#EXT-X-ENDLIST');
  return buffer.toString();
}
