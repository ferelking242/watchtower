
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'remote_server_url';
const _kApiKeyPrefKey = 'remote_server_api_key';

/// HTTP client for the web version to reach the native app's server.
/// Stores the configured server URL in SharedPreferences.
class RemoteClient {
  static final RemoteClient instance = RemoteClient._();
  RemoteClient._();

  String? _baseUrl;
  String? _apiKey;
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() { for (final cb in _listeners) cb(); }

  String? get baseUrl => _baseUrl;
  String? get apiKey => _apiKey;
  bool get isConfigured =>
      _baseUrl != null &&
      _baseUrl!.isNotEmpty &&
      _apiKey != null &&
      _apiKey!.isNotEmpty;
  Map<String, String> get authHeaders => {
        if (_apiKey != null && _apiKey!.isNotEmpty)
          'Authorization': 'Bearer $_apiKey',
      };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kPrefKey);
    _apiKey = prefs.getString(_kApiKeyPrefKey);
  }

  Future<void> setConnection(String url, String apiKey) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _apiKey = apiKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, _baseUrl!);
    await prefs.setString(_kApiKeyPrefKey, _apiKey!);
    _notify();
  }

  Future<void> clear() async {
    _baseUrl = null;
    _apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    await prefs.remove(_kApiKeyPrefKey);
    _notify();
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!isConfigured) throw Exception('Remote server URL or API key missing');
    return getAt(_baseUrl!, path, params: params, timeout: timeout);
  }

  Future<Map<String, dynamic>> getAt(
    String baseUrl,
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Remote server API key missing');
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await http.get(uri, headers: authHeaders).timeout(timeout);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> ping() async {
    try {
      final data = await get('/api/ping');
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
