import 'dart:math' as math;

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
