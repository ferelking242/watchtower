import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Video-player options that have no field in the Isar settings model yet.
/// Persisted in the `player_prefs` Hive box.
const _kBox = 'player_prefs';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

T _read<T>(String key, T fallback) {
  final v = _box?.get(key);
  return v is T ? v : fallback;
}

void _write(String key, Object? value) => _box?.put(key, value);

class _BoolPref extends Notifier<bool> {
  _BoolPref(this._key, this._default);
  final String _key;
  final bool _default;

  @override
  bool build() => _read(_key, _default);

  void set(bool v) {
    _write(_key, v);
    state = v;
  }
}

class _IntPref extends Notifier<int> {
  _IntPref(this._key, this._default);
  final String _key;
  final int _default;

  @override
  int build() => _read(_key, _default);

  void set(int v) {
    _write(_key, v);
    state = v;
  }
}

class _StringPref extends Notifier<String> {
  _StringPref(this._key, this._default);
  final String _key;
  final String _default;

  @override
  String build() => _read(_key, _default);

  void set(String v) {
    _write(_key, v);
    state = v;
  }
}

NotifierProvider<_BoolPref, bool> _boolPref(String key, bool def) =>
    NotifierProvider<_BoolPref, bool>(() => _BoolPref(key, def));

NotifierProvider<_IntPref, int> _intPref(String key, int def) =>
    NotifierProvider<_IntPref, int>(() => _IntPref(key, def));

NotifierProvider<_StringPref, String> _stringPref(String key, String def) =>
    NotifierProvider<_StringPref, String>(() => _StringPref(key, def));

// ── Gestes ──────────────────────────────────────────────────────────────────

/// Double-tap side to seek.
final playerDoubleTapSeekProvider = _boolPref('double_tap_seek', true);

/// Seconds skipped by a double tap.
final playerDoubleTapSeekSecondsProvider = _intPref('double_tap_seek_seconds', 10);

/// Horizontal swipe seeks, vertical swipe changes volume/brightness.
final playerSwipeGesturesProvider = _boolPref('swipe_gestures', true);

/// Show the gesture overlay while a gesture is active.
final playerGestureOverlayProvider = _boolPref('gesture_overlay', true);

// ── Progression / contrôles / orientation ───────────────────────────────────

/// Resume playback where it stopped.
final playerResumeFromLastPositionProvider =
    _boolPref('resume_from_last_position', true);

/// Ask for the next episode when one finishes.
final playerAskNextEpisodeProvider = _boolPref('ask_next_episode', true);

/// Lock orientation to landscape while a video plays.
final playerOrientationLandscapeProvider =
    _boolPref('orientation_landscape', false);

/// Double tap the centre of the screen to play/pause.
final playerDoubleTapToPauseProvider = _boolPref('double_tap_to_pause', true);

// ── Décodeur ────────────────────────────────────────────────────────────────

/// Video decoder backend: auto | hw | sw.
final playerDecoderModeProvider = _stringPref('decoder_mode', 'auto');

/// Deinterlace interlaced video streams.
final playerDeinterlaceProvider = _boolPref('deinterlace', false);

// ── Sous-titres ─────────────────────────────────────────────────────────────

/// Preferred subtitle languages, comma-separated ISO codes.
final playerSubtitleLanguagesProvider = _stringPref('subtitle_languages', '');

/// Preferred audio languages, comma-separated ISO codes.
final playerAudioLanguagesProvider = _stringPref('audio_languages', '');

/// Whitelist of subtitle tracks to keep.
final playerSubtitleWhitelistProvider = _stringPref('subtitle_whitelist', '');

/// Blacklist of subtitle tracks to drop.
final playerSubtitleBlacklistProvider = _stringPref('subtitle_blacklist', '');

/// Subtitle text scale, in percent.
final playerSubtitleScaleProvider = _intPref('subtitle_scale', 100);

// ── Audio ───────────────────────────────────────────────────────────────────

/// Apply pitch correction when the playback speed changes.
final playerPitchCorrectionProvider = _boolPref('pitch_correction', true);

/// Keep the source audio channel layout instead of downmixing.
final playerKeepAudioChannelsProvider = _boolPref('keep_audio_channels', false);

// ── Torrent ─────────────────────────────────────────────────────────────────

/// TorrServer address used for torrent streaming.
final playerTorrServerUrlProvider = _stringPref('torrserver_url', '');

/// Start streaming as soon as enough pieces are available.
final playerTorrentStreamProvider = _boolPref('torrent_stream', false);

// ── Avancé ──────────────────────────────────────────────────────────────────

/// Load user-provided mpv configuration files.
final playerUserFilesProvider = _boolPref('user_files', false);

/// Directory holding user mpv scripts and shaders.
final playerUserFilesDirProvider = _stringPref('user_files_dir', '');

const kDecoderModeOptions = <(String, String)>[
  ('auto', 'Automatique'),
  ('hw', 'Décodage matériel'),
  ('sw', 'Décodage logiciel'),
];

String decoderModeLabel(String v) {
  for (final o in kDecoderModeOptions) {
    if (o.$1 == v) return o.$2;
  }
  return kDecoderModeOptions.first.$2;
}
