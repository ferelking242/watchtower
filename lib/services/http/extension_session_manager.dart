import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure, per-extension storage for browser cookies, local storage and UA.
///
/// The WebView remains responsible for website navigation and authentication.
/// This class only keeps the browser state available to the extension HTTP
/// client; secrets are stored in the platform secure-storage backend, never in
/// Isar or application logs.
class ExtensionSessionManager {
  ExtensionSessionManager._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final Map<int, Map<String, dynamic>> _sessions = {};
  static final Set<int> _loaded = {};
  static const Set<String> _authenticationStates = {
    'anonymous',
    'loggingIn',
    'authenticated',
    'loggedOut',
    'error',
  };

  static String _key(int extensionId) => 'extension_session_$extensionId';

  static Future<void> load(int? extensionId) async {
    if (extensionId == null || extensionId <= 0 || _loaded.contains(extensionId)) {
      return;
    }
    final raw = await _storage.read(key: _key(extensionId));
    if (raw == null || raw.isEmpty) {
      _sessions[extensionId] = _emptySession();
      _loaded.add(extensionId);
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid extension session data.');
    }
    _sessions[extensionId] = _normalizeSession(
      Map<String, dynamic>.from(decoded),
    );
    _loaded.add(extensionId);
  }

  static Map<String, dynamic> _emptySession() => {
    'cookies': <Map<String, dynamic>>[],
    'localStorage': <String, Map<String, String>>{},
    'authenticationState': 'anonymous',
    'webViewState': <String, dynamic>{},
    'httpSessionState': <String, dynamic>{},
  };

  static Map<String, dynamic> _normalizeSession(Map<String, dynamic> raw) {
    final cookies = raw['cookies'];
    final storage = raw['localStorage'];
    final normalizedStorage = <String, Map<String, String>>{};
    if (storage is Map) {
      for (final entry in storage.entries) {
        if (entry.value is Map) {
          normalizedStorage[entry.key.toString().toLowerCase()] =
              (entry.value as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              );
        }
      }
    }
    return {
      'cookies': cookies is List
          ? cookies.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[],
      'localStorage': normalizedStorage,
      'authenticationState':
          _authenticationStates.contains(raw['authenticationState'])
              ? raw['authenticationState']
              : 'anonymous',
      'webViewState': raw['webViewState'] is Map
          ? Map<String, dynamic>.from(raw['webViewState'] as Map)
          : <String, dynamic>{},
      'httpSessionState': raw['httpSessionState'] is Map
          ? Map<String, dynamic>.from(raw['httpSessionState'] as Map)
          : <String, dynamic>{},
      if (raw['lastSynchronizedAt'] is int)
        'lastSynchronizedAt': raw['lastSynchronizedAt'],
      if (raw['userAgent'] is String) 'userAgent': raw['userAgent'],
      if (raw['lastUpdated'] is int) 'lastUpdated': raw['lastUpdated'],
    };
  }

  /// Returns a copy of the extension's session and its derived domain list.
  static Future<Map<String, dynamic>> getSession(int extensionId) async {
    await load(extensionId);
    final session = _normalizeSession(
      Map<String, dynamic>.from(_sessions[extensionId] ?? _emptySession()),
    );
    return {
      'extensionId': extensionId,
      ...session,
      'domains': _domainsForSession(session),
    };
  }

  static List<String> _domainsForSession(Map<String, dynamic> session) {
    final domains = <String>{};
    final cookies = session['cookies'];
    if (cookies is List) {
      for (final cookie in cookies.whereType<Map>()) {
        final domain = _normalizeDomain(cookie['domain']?.toString() ?? '');
        if (domain.isNotEmpty) domains.add(domain);
      }
    }
    final storage = session['localStorage'];
    if (storage is Map) {
      for (final origin in storage.keys) {
        final uri = Uri.tryParse(origin.toString());
        if (uri != null && uri.host.isNotEmpty) {
          domains.add(uri.host.toLowerCase());
        }
      }
    }
    return domains.toList()..sort();
  }

  static Future<List<Map<String, dynamic>>> getCookies(
    int extensionId, {
    String? url,
  }) async {
    await load(extensionId);
    final stored = _sessions[extensionId]?['cookies'];
    if (url != null) return cookiesForUrl(extensionId, url);
    if (stored is! List) return const [];
    return stored
        .whereType<Map>()
        .map((cookie) => Map<String, dynamic>.from(cookie))
        .toList(growable: false);
  }

  /// Merges cookies by name/domain/path without replacing unrelated cookies.
  static Future<void> setCookies(
    int extensionId,
    Iterable<Map<String, dynamic>> values,
  ) async {
    await load(extensionId);
    final session = _sessions[extensionId]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cookies = (session['cookies'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((cookie) {
          final expiresAt = cookie['expiresAt'];
          return expiresAt is! int || expiresAt > now;
        })
        .toList();

    for (final raw in values) {
      final cookie = Map<String, dynamic>.from(raw);
      final name = cookie['name']?.toString().trim() ?? '';
      final domain = _normalizeDomain(cookie['domain']?.toString() ?? '');
      if (name.isEmpty || domain.isEmpty) continue;
      cookie['name'] = name;
      cookie['domain'] = domain;
      cookie['path'] = cookie['path']?.toString().startsWith('/') == true
          ? cookie['path'].toString()
          : '/';
      cookie['hostOnly'] = cookie['hostOnly'] == true;
      cookie['secure'] = cookie['secure'] == true;
      cookie['httpOnly'] = cookie['httpOnly'] == true;
      final sameIndex = cookies.indexWhere(
        (existing) => _sameCookie(existing, cookie),
      );
      final expiresAt = cookie['expiresAt'];
      if (expiresAt is int && expiresAt <= now) {
        if (sameIndex >= 0) cookies.removeAt(sameIndex);
      } else if (sameIndex >= 0) {
        cookies[sameIndex] = cookie;
      } else {
        cookies.add(cookie);
      }
    }
    session['cookies'] = cookies;
    await _persist(extensionId);
  }

  static Future<bool> isAuthenticated(int extensionId) async {
    await load(extensionId);
    return _sessions[extensionId]?['authenticationState'] == 'authenticated';
  }

  static Future<void> setAuthenticationState(
    int extensionId,
    String state,
  ) async {
    if (!_authenticationStates.contains(state)) {
      throw ArgumentError.value(state, 'state', 'Unknown authentication state.');
    }
    await load(extensionId);
    _sessions[extensionId]!['authenticationState'] = state;
    await _persist(extensionId);
  }

  static Future<void> clearSession(int extensionId) async {
    _sessions.remove(extensionId);
    _loaded.remove(extensionId);
    await _storage.delete(key: _key(extensionId));
  }

  /// Backwards-compatible alias used by existing session and account flows.
  static Future<void> clear(int extensionId) => clearSession(extensionId);

  static Future<void> syncFromWebView({
    required int extensionId,
    required String url,
    required Iterable<dynamic> cookies,
    String? cookieHeader,
    String? userAgent,
  }) async {
    await saveBrowserCookies(
      extensionId: extensionId,
      url: url,
      cookies: cookies,
      cookieHeader: cookieHeader,
      userAgent: userAgent,
    );
  }

  static Future<void> syncToWebView({
    required int extensionId,
    required String url,
    required Future<void> Function(Map<String, dynamic> cookie) setCookie,
  }) async {
    await restoreToWebView(
      extensionId: extensionId,
      url: url,
      setCookie: setCookie,
    );
    final session = _sessions[extensionId]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    session['webViewState'] = {
      'lastUrl': url,
      'lastSynchronizedAt': now,
      'direction': 'toWebView',
    };
    session['lastSynchronizedAt'] = now;
    await _persist(extensionId);
  }

  static Map<String, dynamic> snapshotForWorker(int? extensionId) {
    if (extensionId == null) return _emptySession();
    return _normalizeSession(
      Map<String, dynamic>.from(_sessions[extensionId] ?? _emptySession()),
    );
  }

  /// Installs the main-isolate snapshot in an extension worker.
  static void installWorkerSnapshot(int extensionId, Object? snapshot) {
    final raw = snapshot is Map
        ? Map<String, dynamic>.from(snapshot)
        : _emptySession();
    _sessions[extensionId] = _normalizeSession(raw);
    _loaded.add(extensionId);
  }

  static String? userAgentFor(int? extensionId) {
    if (extensionId == null) return null;
    final value = _sessions[extensionId]?['userAgent'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static String? cookieHeaderForUrl(int? extensionId, String rawUrl) {
    if (extensionId == null) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return null;
    final session = _sessions[extensionId];
    final rawCookies = session?['cookies'];
    if (rawCookies is! List) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final cookies = <Map<String, dynamic>>[];
    for (final raw in rawCookies.whereType<Map>()) {
      final cookie = Map<String, dynamic>.from(raw);
      if (_applies(cookie, uri, now)) cookies.add(cookie);
    }
    cookies.sort((a, b) {
      final aPath = (a['path'] as String? ?? '/').length;
      final bPath = (b['path'] as String? ?? '/').length;
      return bPath.compareTo(aPath);
    });
    final values = <String, String>{};
    for (final cookie in cookies) {
      final name = cookie['name']?.toString() ?? '';
      final value = cookie['value']?.toString() ?? '';
      if (name.isNotEmpty) values.putIfAbsent(name, () => value);
    }
    if (values.isEmpty) return null;
    return values.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  static bool _applies(
    Map<String, dynamic> cookie,
    Uri uri,
    int nowMillis,
  ) {
    final name = cookie['name']?.toString() ?? '';
    final domain = _normalizeDomain(cookie['domain']?.toString() ?? '');
    if (name.isEmpty || domain.isEmpty) return false;

    final host = uri.host.toLowerCase();
    final hostOnly = cookie['hostOnly'] == true;
    final domainMatches = hostOnly
        ? host == domain
        : host == domain || host.endsWith('.$domain');
    if (!domainMatches) return false;
    if (cookie['secure'] == true && uri.scheme != 'https') return false;

    final expiresAt = cookie['expiresAt'] as int?;
    if (expiresAt != null && expiresAt <= nowMillis) return false;

    final cookiePath = cookie['path']?.toString().isNotEmpty == true
        ? cookie['path']!.toString()
        : '/';
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    return requestPath == cookiePath ||
        requestPath.startsWith(cookiePath.endsWith('/')
            ? cookiePath
            : '$cookiePath/');
  }

  static String _normalizeDomain(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

  static String _storageOrigin(String value) {
    final candidate = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return _normalizeDomain(value);
    final defaultPort =
        (uri.scheme == 'https' && uri.port == 443) ||
        (uri.scheme == 'http' && uri.port == 80);
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: defaultPort ? null : uri.port,
    ).toString().replaceFirst(RegExp(r'/$'), '');
  }

  static bool _domainMatchesHost(String cookieDomain, String host) {
    final domain = _normalizeDomain(cookieDomain);
    final normalizedHost = _normalizeDomain(host);
    return domain.isNotEmpty &&
        (normalizedHost == domain || normalizedHost.endsWith('.$domain'));
  }

  static Map<String, dynamic> _cookieFromWebView(
    dynamic raw,
    String fallbackHost,
    bool defaultSecure,
  ) {
    dynamic property(String name) {
      if (raw is Map) return raw[name];
      try {
        return switch (name) {
          'name' => raw.name,
          'value' => raw.value,
          'domain' => raw.domain,
          'path' => raw.path,
          'expiresDate' => raw.expiresDate,
          'isHostOnly' => raw.isHostOnly,
          'isSecure' => raw.isSecure,
          'isHttpOnly' => raw.isHttpOnly,
          'sameSite' => raw.sameSite,
          _ => null,
        };
      } catch (_) {
        return null;
      }
    }

    final rawDomain = property('domain')?.toString().trim() ?? '';
    final domain = rawDomain.isEmpty ? fallbackHost : rawDomain;
    final rawExpiry = property('expiresDate');
    final expiry = rawExpiry is int
        ? rawExpiry
        : rawExpiry is DateTime
            ? rawExpiry.millisecondsSinceEpoch
            : DateTime.tryParse(rawExpiry?.toString() ?? '')
                ?.millisecondsSinceEpoch;
    final rawSameSite = property('sameSite');
    final hostOnlyValue = property('isHostOnly');
    final secureValue = property('isSecure');
    return {
      'name': property('name')?.toString() ?? '',
      'value': property('value')?.toString() ?? '',
      'domain': _normalizeDomain(domain),
      'hostOnly': hostOnlyValue is bool
          ? hostOnlyValue
          : !rawDomain.startsWith('.'),
      'path': (property('path')?.toString().isNotEmpty == true)
          ? property('path').toString()
          : '/',
      if (expiry != null) 'expiresAt': expiry,
      'secure': secureValue is bool ? secureValue : defaultSecure,
      'httpOnly': property('isHttpOnly') == true,
      if (rawSameSite != null)
        'sameSite': rawSameSite.toString().split('.').last.toLowerCase(),
    };
  }

  static Map<String, dynamic>? _cookieFromSetCookie(Uri uri, String raw) {
    final parts = raw.split(';');
    if (parts.isEmpty) return null;
    final firstSeparator = parts.first.indexOf('=');
    if (firstSeparator <= 0) return null;
    final name = parts.first.substring(0, firstSeparator).trim();
    final value = parts.first.substring(firstSeparator + 1).trim();
    if (name.isEmpty) return null;

    var domain = uri.host.toLowerCase();
    var hostOnly = true;
    var cookiePath = _defaultPath(uri.path);
    int? expiresAt;
    var secure = false;
    var httpOnly = false;
    String? sameSite;
    for (final attribute in parts.skip(1)) {
      final separator = attribute.indexOf('=');
      final key = (separator < 0 ? attribute : attribute.substring(0, separator))
          .trim()
          .toLowerCase();
      final attributeValue =
          separator < 0 ? '' : attribute.substring(separator + 1).trim();
      switch (key) {
        case 'domain':
          final candidate = _normalizeDomain(attributeValue);
          if (candidate.isNotEmpty &&
              _domainMatchesHost(candidate, uri.host)) {
            domain = candidate;
            hostOnly = false;
          }
          break;
        case 'path':
          if (attributeValue.startsWith('/')) cookiePath = attributeValue;
          break;
        case 'expires':
          expiresAt = DateTime.tryParse(attributeValue)?.millisecondsSinceEpoch ??
              _parseHttpDate(attributeValue);
          break;
        case 'max-age':
          final seconds = int.tryParse(attributeValue);
          if (seconds != null) {
            expiresAt = DateTime.now()
                .add(Duration(seconds: seconds))
                .millisecondsSinceEpoch;
          }
          break;
        case 'secure':
          secure = true;
          break;
        case 'httponly':
          httpOnly = true;
          break;
        case 'samesite':
          if (attributeValue.isNotEmpty) {
            sameSite = attributeValue.toLowerCase();
          }
          break;
      }
    }
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'hostOnly': hostOnly,
      'path': cookiePath,
      if (expiresAt != null) 'expiresAt': expiresAt,
      'secure': secure,
      'httpOnly': httpOnly,
      if (sameSite != null) 'sameSite': sameSite,
    };
  }

  static int? _parseHttpDate(String value) {
    final match = RegExp(
      r'^[A-Za-z]{3},\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    ).millisecondsSinceEpoch;
  }

  static String _defaultPath(String path) {
    if (!path.startsWith('/') || path == '/') return '/';
    final lastSlash = path.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : path.substring(0, lastSlash);
  }

  static bool _sameCookie(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['name'] == b['name'] &&
      a['domain'] == b['domain'] &&
      a['path'] == b['path'] &&
      a['hostOnly'] == b['hostOnly'];

  static Future<void> _persist(int extensionId) async {
    final session = _sessions[extensionId] ?? _emptySession();
    session['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _key(extensionId), value: jsonEncode(session));
  }

  static Future<void> saveBrowserCookies({
    required int extensionId,
    required String url,
    required Iterable<dynamic> cookies,
    String? cookieHeader,
    String? userAgent,
  }) async {
    await load(extensionId);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final session = _sessions[extensionId]!;
    final current = (session['cookies'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    final parsed = <Map<String, dynamic>>[];
    for (final cookie in cookies) {
      final converted = _cookieFromWebView(
        cookie,
        uri.host,
        uri.scheme == 'https',
      );
      if ((converted['name'] as String).isNotEmpty) parsed.add(converted);
    }
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      parsed.addAll(_parseCookieHeader(uri, cookieHeader));
    }

    // Replace only cookies visible to this URL. A WebView query may omit
    // valid cookies on other paths, so keep those entries in the jar.
    final now = DateTime.now().millisecondsSinceEpoch;
    final preserved = current
        .where((cookie) {
          final expiresAt = cookie['expiresAt'] as int?;
          return (expiresAt == null || expiresAt > now) &&
              !_applies(cookie, uri, now);
        })
        .toList();
    for (final cookie in parsed) {
      final existingIndex = preserved.indexWhere((entry) => _sameCookie(entry, cookie));
      if (existingIndex < 0) {
        preserved.add(cookie);
      } else {
        preserved[existingIndex] = cookie;
      }
    }
    session['cookies'] = preserved;
    if (userAgent?.trim().isNotEmpty == true) {
      session['userAgent'] = userAgent!.trim();
    }
    session['webViewState'] = {
      'lastUrl': uri.toString(),
      'lastSynchronizedAt': now,
      if (userAgent?.trim().isNotEmpty == true) 'userAgent': userAgent!.trim(),
      'direction': 'fromWebView',
    };
    session['lastSynchronizedAt'] = now;
    await _persist(extensionId);
  }

  static List<Map<String, dynamic>> _parseCookieHeader(Uri uri, String header) {
    final cookies = <Map<String, dynamic>>[];
    for (final raw in header.split(';')) {
      final separator = raw.indexOf('=');
      if (separator <= 0) continue;
      final name = raw.substring(0, separator).trim();
      if (name.isEmpty) continue;
      cookies.add({
        'name': name,
        'value': raw.substring(separator + 1).trim(),
        'domain': uri.host.toLowerCase(),
        'hostOnly': true,
        'path': '/',
        'secure': uri.scheme == 'https',
        'httpOnly': false,
      });
    }
    return cookies;
  }

  static Future<void> saveResponseCookies({
    required int extensionId,
    required String url,
    required String setCookieHeader,
  }) async {
    await load(extensionId);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final session = _sessions[extensionId]!;
    final cookies = (session['cookies'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final combinedHeaders = setCookieHeader.split(
      RegExp(r',\s*(?=[!#$%&*+\-.^_`|~0-9A-Za-z]+=)'),
    );
    var changed = false;
    for (final raw in combinedHeaders) {
      final cookie = _cookieFromSetCookie(uri, raw.trim());
      if (cookie == null) continue;
      final existingIndex = cookies.indexWhere((entry) => _sameCookie(entry, cookie));
      final expiry = cookie['expiresAt'] as int?;
      if (expiry != null && expiry <= DateTime.now().millisecondsSinceEpoch) {
        if (existingIndex >= 0) cookies.removeAt(existingIndex);
      } else if (existingIndex >= 0) {
        cookies[existingIndex] = cookie;
      } else {
        cookies.add(cookie);
      }
      changed = true;
    }
    if (changed) {
      session['cookies'] = cookies;
      final now = DateTime.now().millisecondsSinceEpoch;
      session['httpSessionState'] = {
        'lastResponseUrl': uri.toString(),
        'lastCookieUpdateAt': now,
      };
      session['lastSynchronizedAt'] = now;
      await _persist(extensionId);
    }
  }

  static Future<void> removeCookiesForHost(
    int extensionId,
    String host,
  ) async {
    await load(extensionId);
    final session = _sessions[extensionId]!;
    session['cookies'] = (session['cookies'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((cookie) => !_domainMatchesHost(
              cookie['domain']?.toString() ?? '',
              host,
            ))
        .toList();
    await _persist(extensionId);
  }

  static Future<String?> getLocalStorage(
    int extensionId,
    String domain,
    String key,
  ) async {
    await load(extensionId);
    final values = _sessions[extensionId]!['localStorage'] as Map;
    final storage = values[_storageOrigin(domain)];
    return storage is Map ? storage[key]?.toString() : null;
  }

  static Future<void> setLocalStorage(
    int extensionId,
    String domain,
    String key,
    String value,
  ) async {
    await load(extensionId);
    final values = _sessions[extensionId]!['localStorage'] as Map;
    final storage = values.putIfAbsent(
      _storageOrigin(domain),
      () => <String, String>{},
    ) as Map;
    storage[key] = value;
    await _persist(extensionId);
  }

  static Future<void> removeLocalStorage(
    int extensionId,
    String domain,
    String key,
  ) async {
    await load(extensionId);
    final values = _sessions[extensionId]!['localStorage'] as Map;
    final origin = _storageOrigin(domain);
    final storage = values[origin];
    if (storage is Map) {
      storage.remove(key);
      if (storage.isEmpty) values.remove(origin);
      await _persist(extensionId);
    }
  }

  static Future<void> saveBrowserLocalStorage({
    required int extensionId,
    required String url,
    required Map<String, String> values,
  }) async {
    await load(extensionId);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final storage =
        _sessions[extensionId]!['localStorage'] as Map<String, Map<String, String>>;
    storage[_storageOrigin(url)] = Map<String, String>.from(values);
    final now = DateTime.now().millisecondsSinceEpoch;
    _sessions[extensionId]!['webViewState'] = {
      'lastUrl': uri.toString(),
      'lastSynchronizedAt': now,
      'localStorageCaptured': true,
      'direction': 'fromWebView',
    };
    _sessions[extensionId]!['lastSynchronizedAt'] = now;
    await _persist(extensionId);
  }

  static Map<String, String> localStorageForUrl(
    int? extensionId,
    String url,
  ) {
    if (extensionId == null) return const {};
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return const {};
    final storage = _sessions[extensionId]?['localStorage'];
    if (storage is! Map) return const {};
    final values = storage[_storageOrigin(url)];
    if (values is! Map) return const {};
    return values.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static bool hasLocalStorageForUrl(int? extensionId, String url) {
    if (extensionId == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final storage = _sessions[extensionId]?['localStorage'];
    return storage is Map && storage.containsKey(_storageOrigin(url));
  }

  static bool hasSessionDataForUrl(int? extensionId, String url) =>
      cookieHeaderForUrl(extensionId, url) != null ||
      hasLocalStorageForUrl(extensionId, url);

  static String localStorageRestoreScript(int? extensionId, String url) {
    if (extensionId == null) return '';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    final origin = _storageOrigin(url);
    final storage = _sessions[extensionId]?['localStorage'];
    if (storage is! Map || !storage.containsKey(origin)) return '';
    final values = jsonEncode(localStorageForUrl(extensionId, url));
    final encodedOrigin = jsonEncode(origin);
    return '''
(() => {
  const expectedOrigin = $encodedOrigin;
  if (window.location.origin !== expectedOrigin) return;
  const values = $values;
  try {
    for (const [key, value] of Object.entries(values)) {
      localStorage.setItem(key, value);
    }
  } catch (_) {}
})();
''';
  }

  static Future<void> mergeCookie(int extensionId, String domain, String name, String value) async {
    await load(extensionId);
    final uri = Uri.tryParse(domain.contains('://') ? domain : 'https://$domain');
    if (uri == null || uri.host.isEmpty || name.trim().isEmpty) return;
    final session = _sessions[extensionId]!;
    final cookies = (session['cookies'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final cookie = {
      'name': name.trim(),
      'value': value,
      'domain': uri.host.toLowerCase(),
      'hostOnly': true,
      'path': '/',
      'secure': uri.scheme == 'https',
      'httpOnly': false,
    };
    final index = cookies.indexWhere((entry) => _sameCookie(entry, cookie));
    if (index < 0) {
      cookies.add(cookie);
    } else {
      cookies[index] = cookie;
    }
    session['cookies'] = cookies;
    await _persist(extensionId);
  }

  static List<Map<String, dynamic>> cookiesForUrl(
    int extensionId,
    String rawUrl,
  ) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return const [];
    final cookies = _sessions[extensionId]?['cookies'];
    if (cookies is! List) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    return cookies
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((cookie) => _applies(cookie, uri, now))
        .toList(growable: false);
  }

  static Future<void> restoreToWebView({
    required int extensionId,
    required String url,
    required Future<void> Function(Map<String, dynamic> cookie) setCookie,
  }) async {
    await load(extensionId);
    for (final cookie in cookiesForUrl(extensionId, url)) {
      await setCookie(cookie);
    }
  }
}
