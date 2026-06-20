
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';

/// Manages a Cloudflare Quick Tunnel (cloudflared tunnel --url).
/// No account or token required — Cloudflare provides free quick tunnels.
class TunnelService {
  Process? _process;
  StreamSubscription? _sub;
  bool _running = false;

  /// Called whenever the public HTTPS URL is found.
  void Function(String url)? onUrlChanged;

  Future<void> start() async {
    if (kIsWeb) return;
    try {
      // cloudflared must be available in PATH (pre-installed on Android via
      // the app's assets or downloaded on first use — handled by the UI).
      _process = await Process.start('cloudflared', [
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
    } catch (e) {
      // cloudflared not available — tunnel URL stays null, local URL works on LAN
    }
  }

  void stop() {
    _running = false;
    _sub?.cancel();
    _process?.kill();
    _process = null;
  }
}
