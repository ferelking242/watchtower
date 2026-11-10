import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

/// The Music/Game download settings were added to `DownloadSettingsService`.
/// These tests pin the defaults and clamping so a typo in a key name (which
/// would silently fall back to the default) is caught.
void main() {
  group('Music/Game download settings', () {
    final settings = DownloadSettingsService.instance;

    test('defaults are sane for both types', () {
      expect(settings.musicConnections, inInclusiveRange(1, 10));
      expect(settings.gameConnections, inInclusiveRange(1, 10));
      expect(settings.musicSimultaneous, inInclusiveRange(1, 20));
      expect(settings.gameSimultaneous, inInclusiveRange(1, 20));
      expect(settings.musicSimultaneousPerSource, inInclusiveRange(1, 10));
      expect(settings.gameSimultaneousPerSource, inInclusiveRange(1, 10));
      expect(settings.musicOnlyOnWifi, isA<bool>());
      expect(settings.gameOnlyOnWifi, isA<bool>());
    });

    test('values round-trip through the in-memory store', () async {
      await settings.setMusicConnections(7);
      await settings.setGameConnections(5);
      expect(settings.musicConnections, 7);
      expect(settings.gameConnections, 5);

      await settings.setMusicSimultaneous(9);
      await settings.setGameSimultaneous(4);
      expect(settings.musicSimultaneous, 9);
      expect(settings.gameSimultaneous, 4);

      await settings.setMusicSimultaneousPerSource(6);
      await settings.setGameSimultaneousPerSource(2);
      expect(settings.musicSimultaneousPerSource, 6);
      expect(settings.gameSimultaneousPerSource, 2);

      await settings.setMusicOnlyOnWifi(true);
      await settings.setGameOnlyOnWifi(true);
      expect(settings.musicOnlyOnWifi, isTrue);
      expect(settings.gameOnlyOnWifi, isTrue);
    });

    test('out-of-range values are clamped', () async {
      await settings.setMusicConnections(999);
      expect(settings.musicConnections, 10);
      await settings.setGameConnections(0);
      expect(settings.gameConnections, 1);

      await settings.setMusicSimultaneous(999);
      expect(settings.musicSimultaneous, 20);
      await settings.setGameSimultaneous(0);
      expect(settings.gameSimultaneous, 1);

      await settings.setMusicSimultaneousPerSource(999);
      expect(settings.musicSimultaneousPerSource, 10);
      await settings.setGameSimultaneousPerSource(0);
      expect(settings.gameSimultaneousPerSource, 1);
    });
  });
}
