import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/services/python/libpython_manager.dart';
import 'package:watchtower/utils/log/logger.dart';

class TelegramService {
  static TelegramService? _instance;
  static TelegramService get instance => _instance ??= TelegramService._();
  TelegramService._();

  static const _prefApiId    = 'tg_api_id';
  static const _prefApiHash  = 'tg_api_hash';
  static const _prefPhone    = 'tg_phone';
  static const _prefSession  = 'tg_session_string';
  static const _prefPcoh     = '_tmp_tg_pcoh';
  static const _prefTmpPhone = '_tmp_tg_phone';

  String? _scriptPath;

  static const telegramRequiredPackages = [
    'pyrogram',
    'tgcrypto',
  ];

  Future<String> get _scriptFile async {
    if (_scriptPath != null) {
      if (await File(_scriptPath!).exists()) return _scriptPath!;
    }
    final dir = await getApplicationSupportDirectory();
    final dest = File('${dir.path}/telegram_plugin/script.py');
    if (!await dest.exists()) {
      await dest.parent.create(recursive: true);
      final bytes = await rootBundle.load('assets/telegram/script.py');
      await dest.writeAsBytes(bytes.buffer.asUint8List());
    }
    _scriptPath = dest.path;
    return dest.path;
  }

  Future<Map<String, dynamic>> _invoke(List<String> args) async {
      final mgr = LibPythonManager.instance;

      // 1. Extraire la stdlib Python (libpython.zip.so -> PYTHONHOME)
      final pythonHome = await mgr.ensureStdlib();
      if (pythonHome == null) {
        return {
          'status': 'error',
          'error': 'stdlib Python introuvable. Verifiez libpython via Parametres > Avance > LibPython.'
        };
      }

      final exe = await mgr.pythonExe;
      if (exe == null) {
        return {'status': 'error', 'error': 'libpython.so introuvable. Installez libpython via Parametres > Avance > LibPython.'};
      }

      // 2. Installer les deps manquantes — await obligatoire pour éviter la race condition
      // pyrogram doit être dans site-packages AVANT que le script Python soit lancé.
      // resolvePluginDeps retourne immédiatement si le marker est déjà présent.
      await mgr.resolvePluginDeps(
        pluginId: 'telegram',
        pluginDeps: telegramRequiredPackages,
        markerKey: 'telegram_plugin',
      );

      final script = await _scriptFile;
      final env = await mgr.buildEnv();
      AppLogger.log('[Telegram] invoke: ${args.join(' ')}', tag: LogTag.zeus, logLevel: LogLevel.debug);
    try {
      final res = await Process.run(
        exe,
        [script, ...args],
        environment: env,
        stdoutEncoding: const Utf8Codec(allowMalformed: true),
        stderrEncoding: const Utf8Codec(allowMalformed: true),
      ).timeout(const Duration(seconds: 60));

      final stdout = (res.stdout as String).trim();
      final stderr = (res.stderr as String).trim();

      if (stderr.isNotEmpty) {
        AppLogger.log('[Telegram] stderr: $stderr', tag: LogTag.zeus, logLevel: LogLevel.debug);
      }

      if (stdout.isEmpty) {
        AppLogger.log('[Telegram] stdout vide. exit=${res.exitCode} stderr=$stderr', tag: LogTag.zeus, logLevel: LogLevel.warning);
        return {'status': 'error', 'error': 'Pas de réponse du script Python. Vérifiez que pyrogram est installé.'};
      }

      final lastLine = stdout.split('\n').where((l) => l.trim().startsWith('{')).lastOrNull ?? stdout;
      return jsonDecode(lastLine) as Map<String, dynamic>;
    } catch (e, st) {
      AppLogger.log('[Telegram] invoke erreur', tag: LogTag.zeus, logLevel: LogLevel.error, error: e, stackTrace: st);
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendCode({
    required String apiId,
    required String apiHash,
    required String phone,
  }) => _invoke([
    '--action', 'auth_send_code',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--phone', phone,
  ]);

  Future<Map<String, dynamic>> verifyCode({
    required String apiId,
    required String apiHash,
    required String phone,
    required String phoneCodeHash,
    required String code,
  }) => _invoke([
    '--action', 'auth_verify_code',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--phone', phone,
    '--phone_code_hash', phoneCodeHash,
    '--code', code,
  ]);

  Future<Map<String, dynamic>> checkPassword({
    required String apiId,
    required String apiHash,
    required String password,
  }) => _invoke([
    '--action', 'auth_check_password',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--password', password,
  ]);

  Future<Map<String, dynamic>> getMetadata({
    required String apiId,
    required String apiHash,
    required String session,
    required String channel,
  }) => _invoke([
    '--action', 'metadata',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--session', session,
    '--channel', channel,
  ]);

  Future<Map<String, dynamic>> listFiles({
    required String apiId,
    required String apiHash,
    required String session,
    required String channel,
    int offset = 0,
    int limit = 20,
  }) => _invoke([
    '--action', 'list',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--session', session,
    '--channel', channel,
    '--offset', '$offset',
    '--limit', '$limit',
  ]);

  Future<Map<String, dynamic>> search({
    required String apiId,
    required String apiHash,
    required String session,
    required String channel,
    required String query,
    int limit = 20,
  }) => _invoke([
    '--action', 'search',
    '--api_id', apiId,
    '--api_hash', apiHash,
    '--session', session,
    '--channel', channel,
    '--query', query,
    '--limit', '$limit',
  ]);

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefSession) ?? '';
    return s.isNotEmpty;
  }

  Future<Map<String, String>> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'api_id':   prefs.getString(_prefApiId)   ?? '',
      'api_hash': prefs.getString(_prefApiHash) ?? '',
      'phone':    prefs.getString(_prefPhone)   ?? '',
      'session':  prefs.getString(_prefSession) ?? '',
    };
  }

  Future<void> saveSession({
    required String session,
    required String apiId,
    required String apiHash,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSession, session);
    await prefs.setString(_prefApiId, apiId);
    await prefs.setString(_prefApiHash, apiHash);
    await prefs.setString(_prefPhone, phone);
    await prefs.remove(_prefPcoh);
    await prefs.remove(_prefTmpPhone);
  }

  Future<void> saveTmpAuth(String phone, String pcoh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTmpPhone, phone);
    await prefs.setString(_prefPcoh, pcoh);
  }

  Future<Map<String, String>> loadTmpAuth() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'phone': prefs.getString(_prefTmpPhone) ?? '',
      'pcoh':  prefs.getString(_prefPcoh)     ?? '',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSession);
    await prefs.remove(_prefApiId);
    await prefs.remove(_prefApiHash);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefPcoh);
    await prefs.remove(_prefTmpPhone);
  }

  Future<String> ensureDeps({void Function(String)? onProgress}) =>
      LibPythonManager.instance.resolvePluginDeps(
        pluginId: 'telegram',
        pluginDeps: telegramRequiredPackages,
        markerKey: 'telegram_plugin',
        onProgress: onProgress,
      );
}
