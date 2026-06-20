
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'remote_server_url';

/// HTTP client for the web version to reach the native app's server.
/// Stores the configured server URL in SharedPreferences.
class RemoteClient {
  static final RemoteClient instance = RemoteClient._();
  RemoteClient._();

  String? _baseUrl;
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() { for (final cb in _listeners) cb(); }

  String? get baseUrl => _baseUrl;
  bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kPrefKey);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, _baseUrl!);
    _notify();
  }

  Future<void> clear() async {
    _baseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    _notify();
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? params}) async {
    if (!isConfigured) throw Exception('Remote server not configured');
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: params);
    final res = await http.get(uri);
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
