import 'package:flutter/foundation.dart';

/// A live Cloudflare refusal and the URL the bypass panel must load.
@immutable
class CloudflareChallenge {
  const CloudflareChallenge({required this.url, this.sourceId});

  /// The exact refused URL (the extension's page, or the media playlist).
  final String url;

  /// `Source.id` of the extension whose request was refused, when known.
  final int? sourceId;

  /// True when [sourceId] identifies the same extension as [other].
  bool matchesSource(int? other) =>
      sourceId != null && other != null && sourceId == other;
}

/// App-wide "a Cloudflare challenge is blocking a request" signal.
///
/// The extension home already renders an inline bypass panel, but a refusal
/// that happens while the *player* is resolving a stream (the surrit playlist
/// behind MissAV, for instance) had nowhere to surface: the user only saw a
/// failed load. The player and the detail screen subscribe to this bus so the
/// panel appears exactly where the user is looking.
///
/// Root isolate only: a refusal first seen while replaying a worker request is
/// reported to the root isolate through `BrowserBridge.onBrowserUnavailable`,
/// which publishes here.
class CloudflareChallengeBus {
  CloudflareChallengeBus._();
  static final CloudflareChallengeBus instance = CloudflareChallengeBus._();

  /// The most recent refusal, or `null` once cleared.
  final ValueNotifier<CloudflareChallenge?> challenge = ValueNotifier(null);

  void publish(String url, {int? sourceId}) {
    final key = url.trim();
    if (key.isEmpty) return;
    challenge.value = CloudflareChallenge(url: key, sourceId: sourceId);
  }

  void clear() {
    challenge.value = null;
  }

  @visibleForTesting
  void reset() => challenge.value = null;
}
