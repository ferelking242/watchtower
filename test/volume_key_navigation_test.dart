import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/manga/reader/services/volume_key_channel.dart';

void main() {
  group('VolumeKeyChannel.volumeKeyGoesToNextPage', () {
    test('par défaut, volume bas avance et volume haut recule', () {
      expect(
        VolumeKeyChannel.volumeKeyGoesToNextPage(direction: -1, invert: false),
        isTrue,
      );
      expect(
        VolumeKeyChannel.volumeKeyGoesToNextPage(direction: 1, invert: false),
        isFalse,
      );
    });

    test('inversé, volume haut avance et volume bas recule', () {
      expect(
        VolumeKeyChannel.volumeKeyGoesToNextPage(direction: 1, invert: true),
        isTrue,
      );
      expect(
        VolumeKeyChannel.volumeKeyGoesToNextPage(direction: -1, invert: true),
        isFalse,
      );
    });
  });
}
