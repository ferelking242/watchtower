
import 'dart:async';
class MusicDisplayUpdater {
  Future<void> updateDisplay(SMTCDisplayMetadata m) async {}
}
class SMTCDisplayMetadata {
  final String? title;
  final String? album;
  final String? artist;
  const SMTCDisplayMetadata({this.title, this.album, this.artist});
}
enum PlaybackStatus { playing, paused, stopped }
class SMTCWindows {
  final MusicDisplayUpdater musicPropertiesUpdater = MusicDisplayUpdater();
  SMTCWindows({bool enabled = false, bool shuffle = false, PlaybackStatus playbackStatus = PlaybackStatus.stopped, bool playpause = false, bool stop = false, bool next = false, bool prev = false, bool fastForward = false, bool rewind = false});
  Future<void> updateConfig(SMTCWindows cfg) async {}
  Future<void> setPlaybackStatus(PlaybackStatus s) async {}
  Stream<dynamic> get buttonPressStream => const Stream.empty();
  Future<void> enableSmtc() async {}
  Future<void> disableSmtc() async {}
  Future<void> dispose() async {}
}
