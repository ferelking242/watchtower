import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:watchtower/modules/watch/detail/watch_player_io.dart';

SubtitleTrack _track(String lang, [String? title]) =>
    SubtitleTrack('${lang}_${title ?? ''}', title, lang);

void main() {
  final tracks = [
    _track('fr', 'Français'),
    _track('en', 'English'),
    _track('es', 'Español'),
    _track('en', 'Forced'),
  ];

  group('filterSubtitleTracks', () {
    test('keeps every track when both lists are empty', () {
      final out = filterSubtitleTracks(tracks, whitelist: '', blacklist: '');
      expect(out, hasLength(4));
    });

    test('a whitelist keeps only the matching languages', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: 'fr, es',
        blacklist: '',
      );
      expect(out.map((t) => t.language), ['fr', 'es']);
    });

    test('a blacklist drops the matching languages', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: '',
        blacklist: 'es',
      );
      expect(out.map((t) => t.language), ['fr', 'en', 'en']);
    });

    test('blacklist wins over whitelist for the same language', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: 'fr, en',
        blacklist: 'en',
      );
      expect(out.map((t) => t.language), ['fr']);
    });

    test('matching ignores case and matches the track title too', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: 'FR',
        blacklist: '',
      );
      expect(out, hasLength(1));
      expect(out.single.language, 'fr');
    });

    test('blank entries in the lists are ignored, not treated as a match', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: ' fr , ',
        blacklist: ',',
      );
      expect(out.map((t) => t.language), ['fr']);
    });

    test('a whitelist that matches nothing yields an empty list', () {
      final out = filterSubtitleTracks(
        tracks,
        whitelist: 'ja',
        blacklist: '',
      );
      expect(out, isEmpty);
    });
  });
}
