
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages a Cloudflare Quick Tunnel (cloudflared tunnel --url).
/// No account or token required — Cloudflare provides free quick tunnels.
/// On Android, downloads the cloudflared binary on first use if not present.
class TunnelService {
  Process? _process;
  StreamSubscription? _sub;
  bool _running = false;

  /// Called whenever the public HTTPS URL is found.
  void Function(String url)? onUrlChanged;

  /// Called when the tunnel cannot be started (binary unavailable, etc.).
  void Function(String error)? onError;

  /// Called with download progress (0.0–1.0) while fetching the binary.
  void Function(double progress)? onDownloadProgress;

  static const _cloudflaredVersion = '2025.4.0';

  Future<String?> _resolveCloudflaredBin() async {
    if (!Platform.isAndroid) {
      // On desktop platforms, expect cloudflared in PATH
      return 'cloudflared';
    }

    // On Android, manage the binary ourselves in the app's files directory
    final dir = await getApplicationDocumentsDirectory();
    final bin = File('${dir.path}/cloudflared');

    if (bin.existsSync() && bin.lengthSync() > 1024 * 1024) {
      // Binary already downloaded
      return bin.path;
    }

    // Determine ABI
    final abi = await _getAndroidAbi();
    final downloadUrl = 'https://github.com/cloudflare/cloudflared/releases/'
        'download/$_cloudflaredVersion/cloudflared-linux-$abi';

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        onError?.call('Téléchargement cloudflared échoué (HTTP ${response.statusCode})');
        client.close();
        return null;
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = bin.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onDownloadProgress?.call(received / total);
        }
      }

      await sink.close();
      client.close();

      // Make executable
      await Process.run('chmod', ['+x', bin.path]);
      return bin.path;
    } catch (e) {
      onError?.call('Impossible de télécharger cloudflared : $e');
      if (bin.existsSync()) bin.deleteSync();
      return null;
    }
  }

  Future<String> _getAndroidAbi() async {
    try {
      final result = await Process.run('getprop', ['ro.product.cpu.abi']);
      final abi = result.stdout.toString().trim();
      if (abi.contains('arm64')) return 'arm64';
      if (abi.contains('x86_64')) return 'amd64';
      if (abi.contains('x86')) return '386';
      return 'arm64'; // default
    } catch (_) {
      return 'arm64';
    }
  }

  Future<void> start() async {
    if (kIsWeb) return;
    try {
      final binPath = await _resolveCloudflaredBin();
      if (binPath == null) return; // onError already called

      _process = await Process.start(binPath, [
        'tunnel', '--url', 'http://localhost:4567',
        '--no-autoupdate',
      ]);
      _running = true;

      // cloudflared prints the tunnel URL to stderr
      _sub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final match = RegExp(r'https://[a-z0-9\-]+\.trycloudflare\.com').firstMatch(line);
        if (match != null) {
          onUrlChanged?.call(match.group(0)!);
        }
      });

      // Also check if the process exited early with an error
      _process!.exitCode.then((code) {
        if (_running && code != 0) {
          onError?.call('cloudflared s\'est arrêté (code $code)');
        }
      });
    } catch (e) {
      // cloudflared not available — tunnel URL stays null, local URL works on LAN
      onError?.call('cloudflared indisponible : $e');
    }
  }

  void stop() {
    _running = false;
    _sub?.cancel();
    _process?.kill();
    _process = null;
  }
}
