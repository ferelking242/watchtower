import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_connectivity.dart';

void main() {
  group('Wi-Fi-only download gate', () {
    test('permits Wi-Fi and ethernet only', () {
      expect(hasWifiOrEthernet([ConnectivityResult.wifi]), isTrue);
      expect(hasWifiOrEthernet([ConnectivityResult.ethernet]), isTrue);
      expect(hasWifiOrEthernet([ConnectivityResult.mobile]), isFalse);
      expect(hasWifiOrEthernet([ConnectivityResult.none]), isFalse);
    });
  });

  group('download worker reservation', () {
    const downloadId = 91234567;

    tearDown(() => ActiveDownloadRegistry.unregister(downloadId));

    test('only one scheduler can claim a chapter', () {
      expect(
        ActiveDownloadRegistry.tryRegisterInternal(
          downloadId,
          '$downloadId',
          itemType: ItemType.manga,
          source: 'test',
        ),
        isTrue,
      );
      expect(
        ActiveDownloadRegistry.tryRegisterInternal(
          downloadId,
          '$downloadId',
          itemType: ItemType.manga,
          source: 'test',
        ),
        isFalse,
      );
      expect(ActiveDownloadRegistry.isActive(downloadId), isTrue);
    });
  });
}