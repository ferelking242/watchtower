import 'dart:math' as math;

/// One running download, as seen by the preemption pass.
class ActiveSlot {
  final int downloadId;
  final String source;

  /// True when the download was already preempted and is only draining; such a
  /// worker is never preempted twice.
  final bool preempted;

  const ActiveSlot({
    required this.downloadId,
    required this.source,
    this.preempted = false,
  });
}

/// Chooses which running downloads must stop so the workers fit [total] and
/// [perSourceCap].
///
/// [slots] must be in start order (oldest first): the downloads that started
/// first are kept and the newest over-budget ones are returned, so lowering a
/// limit stops the most recent work instead of the work closest to finishing.
/// Already-[ActiveSlot.preempted] workers are ignored.
///
/// Only the two limits the user actually sets are enforced. The proportional
/// share is *not* a cap here: it decides who gets a free slot first, so
/// preempting on it would stop downloads to reserve slots that nothing uses.
///
/// Returns the IDs to preempt, in the order they should be stopped.
List<int> selectPreemptions({
  required List<ActiveSlot> slots,
  required int total,
  required int perSourceCap,
}) {
  if (total <= 0 || perSourceCap <= 0) {
    return [
      for (final slot in slots)
        if (!slot.preempted) slot.downloadId,
    ];
  }
  final keptPerSource = <String, int>{};
  var keptTotal = 0;
  final toPreempt = <int>[];
  for (final slot in slots) {
    if (slot.preempted) continue;
    final kept = keptPerSource[slot.source] ?? 0;
    if (keptTotal >= total || kept >= perSourceCap) {
      toPreempt.add(slot.downloadId);
      continue;
    }
    keptPerSource[slot.source] = kept + 1;
    keptTotal++;
  }
  return toPreempt;
}

/// Whether a source other than [source] can still use a free slot of the type.
///
/// The proportional share reserves slots for short queues, but it must never
/// leave a slot idle: when no other source can start work, the current source
/// is allowed to run above its own share. Without this, one stalled source
/// (waiting for Wi-Fi, a dead extension) kept the whole queue below the total
/// the user asked for.
///
/// [startableBySource] counts the items that can be launched *now*, so a source
/// whose remaining items are all parked (Wi-Fi, network, retry backoff) does
/// not hold a slot it cannot fill.
bool hasCompetingSource({
  required String source,
  required Map<String, int> startableBySource,
  required Map<String, int> activeBySource,
  required Map<String, int> shareBySource,
  required int perSourceCap,
}) {
  for (final entry in startableBySource.entries) {
    if (entry.key == source || entry.value <= 0) continue;
    final active = activeBySource[entry.key] ?? 0;
    final share = shareBySource[entry.key] ?? 0;
    if (active < share && active < perSourceCap) return true;
  }
  return false;
}

/// Splits a type's simultaneous-download budget across the sources that still
/// have pending work.
///
/// The "Total" queue setting is a per-type budget, not a flat per-source cap:
/// the source with the *fewest* pending items receives the largest share, so a
/// short queue drains quickly instead of waiting behind a long one. Shares are
/// inverse-proportional to the pending counts and rounded with the largest-
/// remainder method, so their sum never exceeds [total]. Each source is also
/// capped by [perSourceCap] and by its own pending count (a source can never
/// use more slots than it has items). Budget that cannot be placed because a
/// source hit its cap is redistributed to the others on the next pass, so a
/// long queue is never starved by a short one.
///
/// Returns one entry per source that has pending work and a non-zero share.
///
/// Example: `total = 5`, `{srcA: 20, srcB: 10}` -> `{srcA: 2, srcB: 3}`: the
/// smaller queue gets the bigger share.
Map<String, int> allocateSourceSlots({
  required int total,
  required Map<String, int> pendingBySource,
  required int perSourceCap,
}) {
  final result = <String, int>{};
  if (total <= 0 || perSourceCap <= 0) return result;

  final pending = <String, int>{
    for (final entry in pendingBySource.entries)
      if (entry.value > 0) entry.key: entry.value,
  };
  if (pending.isEmpty) return result;

  // A source can never run more than its own queue length.
  final cap = <String, int>{
    for (final entry in pending.entries)
      entry.key: math.min(perSourceCap, entry.value),
  };
  for (final source in pending.keys) {
    result[source] = 0;
  }

  var remaining = total;
  while (remaining > 0) {
    final open = pending.keys.where((s) => result[s]! < cap[s]!).toList();
    if (open.isEmpty) break;

    var weightSum = 0.0;
    for (final s in open) {
      weightSum += 1 / pending[s]!;
    }

    var assigned = 0;
    final fractions = <(String, double)>[];
    for (final s in open) {
      final ideal = remaining * (1 / pending[s]!) / weightSum;
      final room = cap[s]! - result[s]!;
      final take = math.min(ideal.floor(), room);
      result[s] = result[s]! + take;
      assigned += take;
      fractions.add((s, ideal - ideal.floor()));
    }

    // Largest-remainder rounding: hand the whole slots out to the sources
    // with the biggest fractional part, still honouring each cap.
    var leftover = remaining - assigned;
    fractions.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (s, _) in fractions) {
      if (leftover == 0) break;
      if (result[s]! < cap[s]!) {
        result[s] = result[s]! + 1;
        leftover--;
      }
    }

    // Whatever could not be placed this pass (every remaining source is at its
    // cap) is retried against the still-open sources next pass. No progress
    // means the caps are saturated — stop instead of spinning.
    if (leftover >= remaining) break;
    remaining = leftover;
  }

  result.removeWhere((_, slots) => slots == 0);
  return result;
}
