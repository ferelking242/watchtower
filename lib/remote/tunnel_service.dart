import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

void _tlog(String msg) => AppLogger.log('[TUNNEL] $msg', tag: 'REMOTE');
void _tlogErr(String msg) =>
    AppLogger.log('[TUNNEL] $msg', tag: 'REMOTE', logLevel: LogLevel.error);

/// Public exposure of the local API server.
///
/// Strategies are tried in order, the first one that yields a URL is kept
/// alive for as long as the server runs:
///
/// 1. **cloudflared** — Cloudflare quick tunnel: HTTPS, no account, works
///    behind NAT. The binary is downloaded once into the app support
///    directory (progress reported through [onDownloadProgress]).
/// 2. **ssh / localhost.run** — `ssh -R 80:localhost:4567
///    nokey@localhost.run`; nothing to download where OpenSSH exists.
/// 3. **ssh / serveo.net** — same idea, different free relay.
///
/// A user-provided [customUrl] (own domain behind a reverse proxy, a
/// `cloudflared tunnel run` on a VPS…) short-circuits the whole chain.
class TunnelService {
  TunnelService({this.customUrl, this.cloudflaredPath});

  static const int localPort = 4567;

  /// `https://<random>.trycloudflare.com`
  static final RegExp cloudflarePattern =
      RegExp(r'https://[a-z0-9-]+\.trycloudflare\.com');

  /// `https://<random>.lhr.life` (localhost.run) and `*.serveo.net`
  static final RegExp sshRelayPattern = RegExp(
    r'https://[a-z0-9][a-z0-9-]*\.(?:lhr\.life|localhost\.run|serveo\.net)',
  );

  /// Called once a public URL answers.
  void Function(String url, String provider)? onUrlChanged;
  void Function(String error)? onError;
  void Function(double progress)? onDownloadProgress;

  /// User-supplied public URL; disables the automatic tunnels when set.
  String? customUrl;

  /// Explicit cloudflared binary (otherwise searched then downloaded).
  String? cloudflaredPath;

  Process? _process;
  bool _running = false;
  Timer? _retryTimer;
  int _attempt = 0;
  final List<String> _failures = [];
  String? _activeProvider;
  String? _cloudflaredBin;

  String? get activeProvider => _activeProvider;

  /// Android/iOS cannot exec the cloudflared/ssh binaries: the app falls back
  /// to the LAN link or to a public URL the user supplies.
  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> start() async {
    if (kIsWeb || _running) return;
    _running = true;
    _attempt = 0;
    await _runChain();
  }

  Future<void> stop() async {
    _running = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _killProcess();
    _tlog('Arrêté');
  }

  /// Drops the current tunnel and opens a new one (new public URL).
  Future<void> restart() async {
    await _killProcess();
    _failures.clear();
    _attempt++;
    if (!_running) return;
    await _runChain();
  }

  // ── Provider chain ──────────────────────────────────────────────────────────

  Future<void> _runChain() async {
    final custom = customUrl?.trim();
    if (custom != null && custom.isNotEmpty) {
      _activeProvider = 'custom';
      _tlog('URL personnalisée : $custom');
      onUrlChanged?.call(custom, 'custom');
      return;
    }

    _failures.clear();
    if (await _tryCloudflared()) return;
    if (!_running) return;
    if (await _trySsh('localhost.run')) return;
    if (!_running) return;
    if (await _trySsh('serveo.net')) return;
    if (!_running) return;

    onError?.call(_errorSummary());
  }

  String _errorSummary() {
    if (_isMobile) {
      return 'Tunnel automatique indisponible sur mobile.\n'
          'Utilise le lien local (même Wi-Fi) ou renseigne une URL publique '
          'personnalisée : lance « cloudflared tunnel --url '
          'http://<ip-du-téléphone>:$localPort » sur un PC, ou pointe un '
          'domaine vers ce serveur.';
    }
    final details = _failures.isEmpty
        ? 'aucun tunnel n’a pu démarrer'
        : _failures.map((f) => '• $f').join('\n');
    return 'Impossible d’ouvrir un lien public.\n$details\n\n'
        'Le lien local reste utilisable sur le même réseau Wi-Fi. '
        'Installe cloudflared ou OpenSSH, puis réessaie — ou renseigne ta '
        'propre URL publique.';
  }

  Future<bool> _tryCloudflared() async {
    if (_isMobile) {
      _failures.add('cloudflared : indisponible sur mobile');
      return false;
    }
    final bin = await _resolveCloudflared();
    if (bin == null || !_running) return false;
    _tlog('cloudflared → $bin');
    return _spawnTunnel(
      provider: 'cloudflared',
      executable: bin,
      arguments: [
        'tunnel',
        '--no-autoupdate',
        '--url',
        'http://127.0.0.1:$localPort',
      ],
      urlPattern: cloudflarePattern,
    );
  }

  Future<bool> _trySsh(String host) async {
    _tlog('ssh → $host');
    return _spawnTunnel(
      provider: host == 'serveo.net' ? 'serveo' : 'ssh',
      executable: 'ssh',
      arguments: [
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'ServerAliveInterval=30',
        '-o', 'ServerAliveCountMax=3',
        '-o', 'ExitOnForwardFailure=yes',
        '-R', '80:127.0.0.1:$localPort',
        'nokey@$host',
      ],
      urlPattern: sshRelayPattern,
      readyTimeout: const Duration(seconds: 25),
    );
  }

  /// Starts [executable], waits for the first URL printed on stdout/stderr,
  /// then keeps the process alive. Returns false and records the reason in
  /// [_failures] when no URL shows up.
  Future<bool> _spawnTunnel({
    required String provider,
    required String executable,
    required List<String> arguments,
    required RegExp urlPattern,
    Duration readyTimeout = const Duration(seconds: 60),
  }) async {
    await _killProcess();

    final completer = Completer<String?>();
    final buffer = StringBuffer();

    Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        environment: {'TERM': 'dumb'},
      );
    } catch (e) {
      _failures.add('$provider : ${_describe(e)}');
      return false;
    }
    _process = process;

    void feed(String chunk) {
      buffer.write(chunk);
      final match = urlPattern.firstMatch(buffer.toString());
      if (match != null && !completer.isCompleted) {
        completer.complete(match.group(0));
      }
      if (buffer.length > 16384) buffer.clear();
    }

    process.stdout.listen(
      (data) => feed(utf8.decode(data, allowMalformed: true)),
      onError: (Object e) => _tlogErr('$provider stdout : $e'),
    );
    process.stderr.listen(
      (data) => feed(utf8.decode(data, allowMalformed: true)),
      onError: (Object e) => _tlogErr('$provider stderr : $e'),
    );

    process.exitCode.then((code) {
      if (!completer.isCompleted) {
        completer.complete(null);
        return;
      }
      if (_running && identical(_process, process)) {
        _tlogErr('$provider arrêté (code $code) — redémarrage');
        _attempt++;
        _scheduleRetry();
      }
    });

    final url = await completer.future.timeout(readyTimeout, onTimeout: () => null);

    if (url == null) {
      final tail = _lastLine(buffer.toString());
      final reason = _explain(tail);
      _tlogErr('$provider échec : $reason');
      _failures.add('$provider : $reason');
      await _killProcess();
      return false;
    }

    _activeProvider = provider;
    _tlog('$provider prêt : $url');
    onUrlChanged?.call(url, provider);
    return true;
  }

  /// Turns the raw process output into something actionable.
  String _explain(String? tail) {
    final text = tail ?? 'pas de réponse';
    if (text.contains('429') || text.contains('Too Many Requests')) {
      return 'quota temporaire atteint (HTTP 429) — réessaie dans quelques '
          'minutes ou utilise un autre fournisseur';
    }
    if (text.contains('Permission denied')) {
      return 'le relais a refusé la connexion SSH';
    }
    if (text.contains('Could not resolve hostname') ||
        text.contains('no such host')) {
      return 'hôte injoignable (pas de DNS)';
    }
    if (text.contains('No such file or directory')) {
      return 'binaire introuvable';
    }
    return text;
  }

  String _describe(Object e) =>
      e is ProcessException ? e.message : e.toString();

  String? _lastLine(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final line = lines.last;
    return line.length > 180 ? '${line.substring(0, 180)}…' : line;
  }

  void _scheduleRetry() {
    if (!_running) return;
    _retryTimer?.cancel();
    final delay =
        _attempt < 3 ? const Duration(seconds: 5) : const Duration(seconds: 20);
    _tlog('Nouvelle tentative dans ${delay.inSeconds}s');
    _retryTimer = Timer(delay, () async {
      if (!_running) return;
      await _killProcess();
      await _runChain();
    });
  }

  Future<void> _killProcess() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  // ── cloudflared binary ──────────────────────────────────────────────────────

  Future<String?> _resolveCloudflared() async {
    final cached = _cloudflaredBin;
    if (cached != null) return cached;

    final explicit = cloudflaredPath;
    if (explicit != null && explicit.isNotEmpty) {
      if (File(explicit).existsSync()) return _cloudflaredBin = explicit;
    }

    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final exeName = isWindows ? 'cloudflared.exe' : 'cloudflared';

    final candidates = <String>[];
    try {
      final support = await getApplicationSupportDirectory();
      candidates.add('${support.path}/bin/$exeName');
    } catch (_) {}
    if (isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      candidates.addAll([
        r'C:\Program Files\cloudflared\cloudflared.exe',
        r'C:\Program Files (x86)\cloudflared\cloudflared.exe',
        if (localAppData.isNotEmpty)
          '$localAppData\\Microsoft\\WinGet\\Links\\cloudflared.exe',
      ]);
    } else {
      candidates.addAll([
        '/usr/local/bin/cloudflared',
        '/opt/homebrew/bin/cloudflared',
        '/usr/bin/cloudflared',
        '/data/data/com.termux/files/usr/bin/cloudflared',
      ]);
    }

    for (final candidate in candidates) {
      try {
        if (File(candidate).existsSync()) {
          _cloudflaredBin = candidate;
          return candidate;
        }
      } catch (_) {}
    }

    // Honour a system install that is not in the well-known directories.
    final fromPath = await _which(exeName);
    if (fromPath != null) return _cloudflaredBin = fromPath;

    try {
      final support = await getApplicationSupportDirectory();
      final target = '${support.path}/bin/$exeName';
      final downloaded = await _downloadCloudflared(target, isWindows);
      if (downloaded != null) {
        _cloudflaredBin = downloaded;
        return downloaded;
      }
    } catch (e) {
      _failures.add('cloudflared : téléchargement impossible (${_describe(e)})');
    }
    return null;
  }

  Future<String?> _which(String exeName) async {
    try {
      final finder =
          defaultTargetPlatform == TargetPlatform.windows ? 'where' : 'which';
      final result = await Process.run(finder, [exeName]);
      if (result.exitCode != 0) return null;
      final first = (result.stdout as String)
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => '');
      if (first.isEmpty) return null;
      return File(first).existsSync() ? first : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _downloadCloudflared(String target, bool isWindows) async {
    final arch = await _machineArch();
    final String asset;
    final bool compressed;

    if (isWindows) {
      asset = 'cloudflared-windows-amd64.exe';
      compressed = false;
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      asset = arch == 'arm64'
          ? 'cloudflared-darwin-arm64.tgz'
          : 'cloudflared-darwin-amd64.tgz';
      compressed = true;
    } else {
      asset = (arch == 'aarch64' || arch == 'arm64')
          ? 'cloudflared-linux-arm64'
          : 'cloudflared-linux-amd64';
      compressed = false;
    }

    final url = 'https://github.com/cloudflare/cloudflared/releases/latest/'
        'download/$asset';
    _tlog('Téléchargement cloudflared : $url');

    final client = http.Client();
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(url))).timeout(
                const Duration(seconds: 30),
              );
      if (response.statusCode != 200) {
        _failures.add(
          'cloudflared : téléchargement HTTP ${response.statusCode}',
        );
        return null;
      }
      final total = response.contentLength ?? 0;
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (total > 0) onDownloadProgress?.call(bytes.length / total);
      }
      onDownloadProgress?.call(1);

      final dir = Directory(target).parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);

      if (compressed) {
        final archive = '${dir.path}/cloudflared.tgz';
        File(archive).writeAsBytesSync(bytes);
        final result =
            await Process.run('tar', ['-xzf', archive, '-C', dir.path]);
        File(archive).deleteSync();
        if (result.exitCode != 0) {
          _failures.add('cloudflared : extraction impossible');
          return null;
        }
      } else {
        File(target).writeAsBytesSync(bytes);
      }

      if (!isWindows) await Process.run('chmod', ['+x', target]);
      if (!File(target).existsSync()) return null;
      _tlog('cloudflared installé : $target');
      return target;
    } catch (e) {
      _failures.add('cloudflared : ${_describe(e)}');
      return null;
    } finally {
      client.close();
    }
  }

  Future<String> _machineArch() async {
    try {
      final result = await Process.run('uname', ['-m']);
      final arch = (result.stdout as String).trim();
      if (arch.isNotEmpty) return arch;
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.android ? 'arm64' : 'x86_64';
  }
}
