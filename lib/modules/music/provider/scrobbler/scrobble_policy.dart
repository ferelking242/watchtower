/// Pure decision helpers for the playback scrobble trigger.
///
/// ListenBrainz and Last.fm both accept a scrobble once the listener has
/// played either half of the track or four minutes, whichever comes first.
/// Keeping the arithmetic here (instead of inside a stream listener) makes the
/// rule unit-testable without a live audio player.
library;

/// Minimum listen time, in seconds, before a scrobble may be submitted.
int minimumScrobbleSeconds(Duration trackDuration) {
  final half = trackDuration.inSeconds ~/ 2;
  return half < 240 ? half : 240;
}

/// Stable identity of the currently playing track.
///
/// Local files are identified by their path because their ids are derived from
/// the path anyway, while catalogue tracks use the provider id.
String? scrobbleTrackKey({
  required String? id,
  required bool isLocal,
  required String? path,
}) {
  if (isLocal) return path;
  return id;
}

/// Whether [trackKey] should be scrobbled now.
///
/// [lastScrobbledKey] prevents re-submitting the same track while it keeps
/// playing, and every degenerate case (no track, unknown duration, zero
/// position, track too short to have reached half) returns false so nothing is
/// ever submitted on the first position tick.
bool shouldScrobble({
  required String? trackKey,
  required String? lastScrobbledKey,
  required Duration position,
  required Duration duration,
}) {
  if (trackKey == null || trackKey == lastScrobbledKey) return false;
  if (position == Duration.zero || duration == Duration.zero) return false;
  return position.inSeconds >= minimumScrobbleSeconds(duration);
}
