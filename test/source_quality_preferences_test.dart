import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_source_preference.dart';

void main() {
  test('quality defaults include Auto through 8K and select Auto', () {
    final source = Source(
      id: 1900000191,
      videoQualities: const ['360p', '480p'],
    );

    final preferences = withWatchtowerDefaults(source, []);
    final quality = preferences
        .firstWhere(
          (preference) => preference.key == extensionDefaultQualityKey,
        )
        .listPreference!;
    final fallback = preferences
        .firstWhere(
          (preference) => preference.key == extensionQualityFallbackKey,
        )
        .listPreference!;

    expect(quality.entries, [
      'Auto',
      '144p',
      '240p',
      '360p',
      '480p',
      '720p',
      '1080p',
      '1440p (2K)',
      '2160p (4K)',
      '4320p (8K)',
    ]);
    expect(quality.entryValues, quality.entries);
    expect(quality.valueIndex, 0);
    expect(fallback.entries, [
      'Qualité immédiatement supérieure',
      'Qualité immédiatement inférieure',
    ]);
    expect(fallback.entryValues, ['higher', 'lower']);
    expect(fallback.valueIndex, 1);
  });
}
