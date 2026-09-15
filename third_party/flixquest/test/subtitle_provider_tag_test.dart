import 'package:flixquest/functions/subtitle_provider_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the provider from a scraper subtitle url', () {
    expect(
      subtitleProviderTagForUrl(
        'https://scraper.test/api/v2/subtitles/wyzie/1951613622.vtt?t=abc',
      ),
      'wyzie',
    );
    expect(
      subtitleProviderTagForUrl(
        'https://scraper.test/api/v2/subtitles/natsuki/3030682.vtt',
      ),
      'natsuki',
    );
  });

  test('falls back to the host when the url has no provider segment', () {
    expect(
      subtitleProviderTagForUrl('https://www.opensubs.test/download/1.srt'),
      'opensubs.test',
    );
    expect(
      subtitleProviderTagForUrl('https://cdn.test/download/subtitles/en.vtt'),
      'cdn.test',
    );
    expect(subtitleProviderTagForUrl('https://cdn.test/subtitles'), 'cdn.test');
  });

  test('has no tag for missing or blank urls', () {
    expect(subtitleProviderTagForUrl(null), '');
    expect(subtitleProviderTagForUrl('   '), '');
  });
}
