import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';

/// The published catalogues are split by origin, so they overlap: the genre
/// catalogue repeats most of the country catalogue's streams. Flattening them
/// without checking for that lists the same channel twice, which the user sees
/// as duplicates after installing both.
void main() {
  LiveChannel channel(String name, List<String> urls, {String? group}) =>
      LiveChannel(id: 'p:$name', name: name, urls: urls, group: group);

  test('a channel offered by two providers is listed once', () {
    final merged = mergeChannels([
      [
        channel('TF1', ['https://a/tf1.m3u8'], group: 'France'),
        channel('France 2', ['https://a/f2.m3u8'], group: 'France'),
      ],
      [
        channel('TF1', ['https://a/tf1.m3u8'], group: 'Général'),
        channel('Cinema', ['https://a/cinema.m3u8'], group: 'Cinéma'),
      ],
    ]);

    expect(merged.map((c) => c.name), ['TF1', 'France 2', 'Cinema']);
    expect(merged.first.group, 'France', reason: 'the first provider wins');
  });

  test('an entry that adds a mirror survives', () {
    // Same stream, but the second provider also knows a fallback the first one
    // does not: dropping the entry would lose that mirror.
    final merged = mergeChannels([
      [
        channel('TF1', ['https://a/tf1.m3u8']),
      ],
      [
        channel('TF1 HD', ['https://a/tf1.m3u8', 'https://b/tf1.m3u8']),
      ],
    ]);

    expect(merged.map((c) => c.name), ['TF1', 'TF1 HD']);
    expect(merged.last.urls, hasLength(2));
  });

  test('a repeated entry inside one provider is also collapsed', () {
    final merged = mergeChannels([
      [
        channel('TF1', ['https://a/tf1.m3u8']),
        channel('TF1', ['https://a/tf1.m3u8']),
      ],
    ]);

    expect(merged, hasLength(1));
  });

  test('a provider with no channels contributes nothing', () {
    expect(mergeChannels([[], [channel('TF1', ['https://a/tf1.m3u8'])]]),
        hasLength(1));
  });

  test('a channel with no URLs is kept rather than dropped silently', () {
    // Nothing to dedupe on, so it must not be swallowed by the every() check.
    final merged = mergeChannels([
      [channel('Sans URL', [])],
    ]);

    expect(merged, hasLength(1));
  });
}
