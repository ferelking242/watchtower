import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/utils/log/logger.dart';

const _kBoxName = 'anti_bot_settings';
const _kEnabledKey = 'remote_enabled';
const _kUrlKey = 'remote_url';
const _kTimeoutKey = 'remote_timeout_ms';
const _kApiKeyKey = 'remote_api_key';
const _kModeKey = 'remote_mode';

enum RemoteBypassMode {
  auto,
  onDemand;

  String get label => switch (this) {
        RemoteBypassMode.auto => 'Automatique',
        RemoteBypassMode.onDemand => 'Sur demande',
      };

  String get description => switch (this) {
        RemoteBypassMode.auto =>
          'Utilise le serveur distant dès que les 2 tentatives locales échouent',
        RemoteBypassMode.onDemand =>
          'Utilise le serveur distant uniquement quand vous appuyez sur "Contourner via serveur distant"',
      };
}

class RemoteBypassSettings {
  final bool enabled;
  final String serverUrl;
  final int timeoutMs;
  final String apiKey;
  final RemoteBypassMode mode;

  const RemoteBypassSettings({
    this.enabled = false,
    this.serverUrl = '',
    this.timeoutMs = 60000,
    this.apiKey = '',
    this.mode = RemoteBypassMode.onDemand,
  });

  String get url => serverUrl;
  bool get isConfigured => enabled && serverUrl.trim().isNotEmpty;
  bool get isHttpOnly => serverUrl.trim().toLowerCase().startsWith('http://');

  RemoteBypassSettings copyWith({
    bool? enabled,
    String? url,
    int? timeoutMs,
    String? apiKey,
    RemoteBypassMode? mode,
  }) {
    return RemoteBypassSettings(
      enabled: enabled ?? this.enabled,
      serverUrl: url ?? serverUrl,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      apiKey: apiKey ?? this.apiKey,
      mode: mode ?? this.mode,
    );
  }
}

class RemoteBypassResult {
  final bool success;
  final String cookies;
  final String userAgent;
  final String error;

  const RemoteBypassResult({
    required this.success,
    this.cookies = '',
    this.userAgent = '',
    this.error = '',
  });
}

class RemoteBypassService {
  RemoteBypassService._();
  static final RemoteBypassService instance = RemoteBypassService._();

  Box? _box;

  Future<Box> _openBox() async {
    _box ??= await Hive.openBox(_kBoxName);
    return _box!;
  }

  Future<RemoteBypassSettings> loadSettings() async {
    final box = await _openBox();
    return RemoteBypassSettings(
      enabled: box.get(_kEnabledKey, defaultValue: false) as bool,
      serverUrl: box.get(_kUrlKey, defaultValue: '') as String,
      timeoutMs: box.get(_kTimeoutKey, defaultValue: 60000) as int,
      apiKey: box.get(_kApiKeyKey, defaultValue: '') as String,
      mode: RemoteBypassMode.values[
        (box.get(_kModeKey, defaultValue: 1) as int)
            .clamp(0, RemoteBypassMode.values.length - 1)
      ],
    );
  }

  Future<void> saveSettings(RemoteBypassSettings s) async {
    final box = await _openBox();
    await box.put(_kEnabledKey, s.enabled);
    await box.put(_kUrlKey, s.serverUrl.trim());
    await box.put(_kTimeoutKey, s.timeoutMs.clamp(5000, 300000));
    await box.put(_kApiKeyKey, s.apiKey.trim());
    await box.put(_kModeKey, s.mode.index);
  }

  Future<RemoteBypassResult> solve(String url) async {
    final settings = await loadSettings();
    if (!settings.isConfigured) {
      return const RemoteBypassResult(
        success: false,
        error: 'Remote bypass non configuré',
      );
    }
    final baseUrl = settings.serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    final endpoint = '$baseUrl/v1';
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (settings.apiKey.isNotEmpty) 'X-Api-Key': settings.apiKey,
      };
      final body = jsonEncode({
        'cmd': 'request.get',
        'url': url,
        'maxTimeout': settings.timeoutMs,
      });
      final response = await http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(
            Duration(milliseconds: settings.timeoutMs + 5000),
          );
      if (response.statusCode != 200) {
        return RemoteBypassResult(
          success: false,
          error: 'Serveur distant: HTTP ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'ok') {
        final msg = data['message'] as String? ?? 'Erreur inconnue';
        return RemoteBypassResult(success: false, error: msg);
      }
      final solution = data['solution'] as Map<String, dynamic>? ?? {};
      final rawCookies = solution['cookies'] as List? ?? [];
      final cookieStr = rawCookies
          .map((c) {
            final m = c as Map<String, dynamic>;
            return '${m['name']}=${m['value']}';
          })
          .join('; ');
      final ua = solution['userAgent'] as String? ?? '';
      AppLogger.log(
        'RemoteBypass: succès pour $url — ${rawCookies.length} cookies',
        logLevel: LogLevel.info,
        tag: LogTag.network,
      );
      return RemoteBypassResult(
        success: true,
        cookies: cookieStr,
        userAgent: ua,
      );
    } catch (e) {
      AppLogger.log(
        'RemoteBypass: erreur pour $url — $e',
        logLevel: LogLevel.error,
        tag: LogTag.network,
      );
      return RemoteBypassResult(success: false, error: e.toString());
    }
  }
}
