import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the current connection satisfies a Wi-Fi-only download setting.
bool hasWifiOrEthernet(Iterable<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
}