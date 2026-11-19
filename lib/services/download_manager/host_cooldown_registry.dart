import 'package:flutter/foundation.dart';

/// Remembers hosts that asked us to back off, so the download queue stops
/// dispatching new chapters to a host that is currently refusing us.
///
/// Why this exists: the per-request retry only covers a few seconds. A batch
/// download of 173 manga chapters runs for a long time against one host, and
/// hosts start answering 429/503 once they see sustained traffic. Every page
/// then burned its retries inside that short window, the chapter failed, and
/// the queue immediately dispatched the next chapter to the same throttled
/// host — so chapter ~20 onward all failed while the first ones succeeded.
/// Twenty minutes later the host's window had expired and the same chapters
/// downloaded fine, which is exactly the "it works again later" symptom.
///
/// The registry is in-memory only: a cooldown is a property of the current
/// session and must not survive a restart.
class HostCooldownRegistry {
  HostCooldownRegistry._();

  static final HostCooldownRegistry instance = HostCooldownRegistry._();

  /// Hosts with an active cooldown, mapped to the moment it ends.
  final Map<String, DateTime> _until = <String, DateTime>{};

  /// How many consecutive rate-limit failures a host has produced, used to
  /// grow the cooldown instead of resetting to the server's short hint.
  final Map<String, int> _strikes = <String, int>{};

  static const Duration _baseCooldown = Duration(seconds: 30);
  static const Duration _maxCooldown = Duration(minutes: 15);

  /// Canonical cooldown key for an extension source.
  ///
  /// The scheduler gates dispatch on `manga.source` and the UI groups rows by
  /// the same name, so both must ask the registry about exactly this value.
  /// (Recording failures per URL host instead meant a host like
  /// "cdn.example.org" never matched the source name "MangaDex", and no
  /// cooldown ever fired.)
  static String keyForSource(String source) =>
      source.isEmpty ? '_unknown' : source;

  /// Cooldown currently in force for [host], or null when it may be used.
  DateTime? cooldownUntil(String host) {
    final until = _until[host];
    if (until == null || !until.isAfter(DateTime.now())) {
      _until.remove(host);
      return null;
    }
    return until;
  }

  /// True when [host] is cooling down and must not receive new work.
  bool isCoolingDown(String host) => cooldownUntil(host) != null;

  /// Remaining cooldown for [host], or null.
  Duration? remaining(String host) {
    final until = cooldownUntil(host);
    return until == null ? null : until.difference(DateTime.now());
  }

  /// Records a rate-limit / refusal for [host] and returns the cooldown that
  /// now applies.
  ///
  /// [retryAfter] is the server's own hint when it sent one; it is honoured
  /// but raised on repeated strikes, because a host that keeps refusing us
  /// needs a longer pause than the single hint it gave the first time.
  Duration registerFailure(String host, {Duration? retryAfter}) {
    if (host.isEmpty) return Duration.zero;
    final strikes = (_strikes[host] ?? 0) + 1;
    _strikes[host] = strikes;

    final escalated = _baseCooldown * (1 << (strikes - 1).clamp(0, 5));
    var cooldown = escalated > _maxCooldown ? _maxCooldown : escalated;
    if (retryAfter != null && retryAfter > cooldown) {
      cooldown = retryAfter > _maxCooldown ? _maxCooldown : retryAfter;
    }
    _until[host] = DateTime.now().add(cooldown);
    return cooldown;
  }

  /// Clears the cooldown and strike count for [host] after a success, so an
  /// occasional blip does not keep escalating forever.
  void registerSuccess(String host) {
    if (host.isEmpty) return;
    _until.remove(host);
    _strikes.remove(host);
  }

  /// Clears every cooldown (used when the user explicitly retries).
  void clear() {
    _until.clear();
    _strikes.clear();
  }

  @visibleForTesting
  void resetForTest() => clear();
}
