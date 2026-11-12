import 'package:flutter/foundation.dart';

/// A queued download that was refused by Cloudflare, and the URL the bypass
/// panel must open.
@immutable
class ChallengeTarget {
  const ChallengeTarget({
    required this.chapterId,
    required this.url,
    this.sourceId,
    this.sourceName,
  });

  /// `chapter.id` of the refused download — the row the queue focuses.
  final int chapterId;

  /// The exact URL the panel must load (the request that was refused).
  final String url;

  final int? sourceId;
  final String? sourceName;
}

/// Bridges a Cloudflare refusal on a *download* to the download manager UI.
///
/// The notification action that the user taps ("Battre le challenge") only
/// knows the blocked URL. The queue, in turn, only knows chapter ids. This
/// inbox keeps the mapping between the two so tapping the notification can open
/// the download manager on the *concerned* box and reveal the inline bypass
/// panel there — instead of dumping the user on the extension home.
///
/// A download touches several URLs (the chapter page the extension fetches and
/// the media playlist the downloader fetches), so every one of them is mapped
/// back to the same chapter.
///
/// Root isolate only (it is written by the download provider and read by the
/// queue widget); no persistence, since a refusal that is not acted on before
/// the next app launch is stale anyway.
class ChallengeInbox {
  ChallengeInbox._();
  static final ChallengeInbox instance = ChallengeInbox._();

  /// The download the queue should focus, or `null` when nothing is pending.
  final ValueNotifier<ChallengeTarget?> target = ValueNotifier(null);

  final Map<String, ChallengeTarget> _byUrl = {};
  final List<String> _order = [];
  static const int _maxEntries = 50;

  /// Maps [url] to [chapterId], so a later refusal on that URL routes the user
  /// to the right download.
  void watch({
    required int chapterId,
    required String url,
    int? sourceId,
    String? sourceName,
  }) {
    final key = url.trim();
    if (key.isEmpty) return;
    if (_byUrl.containsKey(key)) _order.remove(key);
    _byUrl[key] = ChallengeTarget(
      chapterId: chapterId,
      url: key,
      sourceId: sourceId,
      sourceName: sourceName,
    );
    _order.add(key);
    while (_order.length > _maxEntries) {
      _byUrl.remove(_order.removeAt(0));
    }
  }

  /// Marks [url] as refused, queuing the download manager to focus its row.
  void record({
    required int chapterId,
    required String url,
    int? sourceId,
    String? sourceName,
  }) {
    watch(
      chapterId: chapterId,
      url: url,
      sourceId: sourceId,
      sourceName: sourceName,
    );
    final key = url.trim();
    if (key.isEmpty) return;
    target.value = _byUrl[key];
  }

  /// Resolves the download that was refused for [url].
  ///
  /// Matches the exact URL first, then the same host + path so a URL that
  /// gained or dropped a query string still resolves. Returns `null` when the
  /// refusal belongs to an extension page rather than a download.
  ChallengeTarget? forUrl(String url) {
    final needle = url.trim();
    if (needle.isEmpty) return null;
    final exact = _byUrl[needle];
    if (exact != null) return exact;
    final needleUri = Uri.tryParse(needle);
    if (needleUri == null) return null;
    for (final key in _order.reversed) {
      final uri = Uri.tryParse(key);
      if (uri == null) continue;
      if (uri.host == needleUri.host && uri.path == needleUri.path) {
        return _byUrl[key];
      }
    }
    return null;
  }

  /// The most recent refusal recorded for [chapterId], if any.
  ChallengeTarget? forChapter(int chapterId) {
    for (final key in _order.reversed) {
      final entry = _byUrl[key];
      if (entry != null && entry.chapterId == chapterId) return entry;
    }
    return null;
  }

  /// Consumes the pending focus so the queue only reacts once per tap.
  ChallengeTarget? takeTarget() {
    final current = target.value;
    target.value = null;
    return current;
  }

  void clear() {
    target.value = null;
  }

  @visibleForTesting
  void reset() {
    _byUrl.clear();
    _order.clear();
    target.value = null;
  }
}
