
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'remote_server_url';

/// Provides the configured remote server base URL (or null if not set).
/// Used by web services to route requests through the remote server.
final remoteBaseUrlProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kPrefKey);
});

/// Notifier to update the URL and invalidate dependents.
class RemoteBaseUrlNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> setUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, url);
    state = url;
    ref.invalidate(remoteBaseUrlProvider);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    state = null;
    ref.invalidate(remoteBaseUrlProvider);
  }
}

final remoteBaseUrlNotifierProvider =
    NotifierProvider<RemoteBaseUrlNotifier, String?>(RemoteBaseUrlNotifier.new);
