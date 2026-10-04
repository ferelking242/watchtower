import 'dart:async';

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/services/anti_bot/cloudflare_page_detector.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Whether this platform can host an inline challenge webview.
bool cloudflareWebviewSupported() =>
    !kIsWeb &&
    !Platform.isLinux &&
    (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows);

/// Reusable inline Cloudflare challenge resolver.
///
/// Unlike the old “open a WebView route/sheet” flow, this widget embeds the
/// challenge directly in the calling screen (bottom sheet, error card, detail
/// pane…) and calls [onResolved] as soon as `cf_clearance` is observed — the
/// user never leaves the current page. On platforms without an embedded
/// webview it degrades to clear guidance + manual re-check.
class CloudflareBypassPanel extends StatefulWidget {
  final String url;

  /// Called once the challenge has been solved (cf_clearance cookie present).
  final VoidCallback? onResolved;

  /// Called when the user asks to re-test the source manually.
  final VoidCallback? onManualCheck;

  /// Called when the user wants to retry the failing operation.
  final VoidCallback? onRetry;

  /// Optional close action (panel embedded in a dismissible surface).
  final VoidCallback? onClose;

  /// Small heading style for embedded cards (no big hero layout).
  final bool compact;

  /// Expands the real browser surface to fill a full-screen route.
  final bool fullScreen;

  const CloudflareBypassPanel({
    super.key,
    required this.url,
    this.onResolved,
    this.onManualCheck,
    this.onRetry,
    this.onClose,
    this.compact = false,
    this.fullScreen = false,
  });

  @override
  State<CloudflareBypassPanel> createState() => _CloudflareBypassPanelState();
}

enum _CfPhase { checking, loading, waiting, resolved, unsupported }

class _CloudflareBypassPanelState extends State<CloudflareBypassPanel> {
  _CfPhase _phase = _CfPhase.loading;
  double _progress = 0;
  bool _checkingCookie = false;
  bool _cookieStoreReady = false;
  bool _resolvedCallbackSent = false;
  bool _pageLoaded = false;
  bool _hardBlocked = false;
  bool _cookiePersistenceFailed = false;
  String _host = '';
  InAppWebViewController? _webViewController;
  Timer? _challengePollTimer;

  @override
  void initState() {
    super.initState();
    _host = _hostFrom(widget.url);
    _initPhase();
  }

  Future<void> _initPhase() async {
    final supported = cloudflareWebviewSupported();
    if (!supported) {
      if (mounted) setState(() => _phase = _CfPhase.unsupported);
      return;
    }
    // The challenge WebView and extension HTTP client have separate cookie
    // stores. Seed the browser store before its first navigation.
    try {
      await MClient.restoreCookiesToWebView(widget.url);
    } catch (e) {
      AppLogger.log(
        'CloudflareBypassPanel cookie restore failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
    }
    if (!mounted) return;
    setState(() {
      _cookieStoreReady = true;
      _phase = _CfPhase.waiting;
    });
  }

  String _hostFrom(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.isEmpty ? url : host;
    } catch (_) {
      return url;
    }
  }

  Future<void> _probeCookie({
    bool showSpinner = true,
    InAppWebViewController? controller,
  }) async {
    if (_checkingCookie) return;
    final activeController = controller ?? _webViewController;
    if (!_cookieStoreReady || activeController == null) return;
    setState(() {
      _checkingCookie = true;
      if (showSpinner) _phase = _CfPhase.checking;
    });
    try {
      final pageUrl =
          (await activeController.getUrl())?.toString() ?? widget.url;
      final pageSnapshot =
          (await activeController.evaluateJavascript(
            source: '''
              (() => {
                const challenge = !!document.querySelector(
                  '#challenge-form, #challenge-running, #cf-challenge-running, ' +
                  '.cf-browser-verification, iframe[src*="challenges.cloudflare.com"], ' +
                  'iframe[src*="turnstile"], input[name="cf-turnstile-response"]'
                );
                const title = document.title || '';
                const body = (document.body?.innerText || '').slice(0, 10000);
                return 'WT_CF_CHALLENGE=' + (challenge ? '1' : '0') +
                  '\\n' + title + '\\n' + body;
              })()
            ''',
          ))?.toString() ??
          '';
      final stillChallenging =
          isCloudflareChallengeSnapshot(pageSnapshot);
      final blocked =
          isCloudflareBlockedSnapshot(pageSnapshot);
      _hardBlocked = blocked;
      final cookies = await CookieManager.instance()
          .getCookies(
            url: WebUri(pageUrl),
            webViewController: activeController,
          );
      final hasClearance = cookies.any((c) => c.name == 'cf_clearance');
      if (hasClearance && !stillChallenging && !blocked && mounted) {
        var persisted = false;
        try {
          await MClient.setCookie(
            pageUrl,
            MClient.userAgentForRequests(),
            activeController,
          );
          final storedCookies = MClient.getCookiesPref(pageUrl).values;
          persisted = storedCookies.any(
            (header) => header
                .split(';')
                .any((cookie) => cookie.trim().startsWith('cf_clearance=')),
          );
        } catch (e) {
          AppLogger.log(
            'CloudflareBypassPanel cookie persistence failed: $e',
            logLevel: LogLevel.warning,
            tag: kLogTagNet,
          );
        }
        if (!persisted) {
          _cookiePersistenceFailed = true;
        } else {
          _cookiePersistenceFailed = false;
        }
        if (!mounted) return;
        if (persisted) {
          _challengePollTimer?.cancel();
          setState(() {
            _phase = _CfPhase.resolved;
            _checkingCookie = false;
          });
          if (!_resolvedCallbackSent) {
            _resolvedCallbackSent = true;
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (mounted) widget.onResolved?.call();
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.log(
        'CloudflareBypassPanel cookie probe failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
    }
    if (mounted) {
      setState(() {
        _checkingCookie = false;
        _phase = _CfPhase.waiting;
      });
    }
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    Uri? _,
  ) async {
    if (!mounted) return;
    setState(() {
      _progress = 1;
      _pageLoaded = true;
    });
    _challengePollTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_pageLoaded && _phase != _CfPhase.resolved) {
          unawaited(_probeCookie(showSpinner: false));
        }
      },
    );
    await _probeCookie(showSpinner: false, controller: controller);
  }

  @override
  void dispose() {
    _challengePollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final supported = cloudflareWebviewSupported();

    return Container(
        decoration: widget.fullScreen
            ? null
            : BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          mainAxisSize:
              widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                widget.compact ? 10 : 14,
                widget.compact ? 8 : 10,
                widget.compact ? 6 : 8,
                widget.compact ? 8 : 10),
            child: Row(children: [
              _ShieldStatus(phase: _phase, cs: cs),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phase == _CfPhase.resolved
                          ? 'Challenge résolu'
                          : 'Challenge Cloudflare',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: widget.compact ? 12.5 : 13.5,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _host,
                      style: TextStyle(
                        fontSize: widget.compact ? 10.5 : 11,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Fermer',
                ),
            ]),
          ),

          // ── Thin progress ─────────────────────────────────────────────
          if (_phase == _CfPhase.loading ||
              _phase == _CfPhase.checking ||
              _phase == _CfPhase.resolved)
            SizedBox(
              height: 2,
              child: _phase == _CfPhase.resolved
                  ? LinearProgressIndicator(
                      value: 1,
                      backgroundColor: Colors.transparent,
                      color: Colors.green.shade500,
                    )
                  : LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: cs.primary,
                    ),
            ),

          // ── Body ──────────────────────────────────────────────────────
          if (supported)
            widget.fullScreen
                ? Expanded(child: _buildWebview(cs))
                : _buildWebview(cs)
          else
            widget.fullScreen
                ? Expanded(child: _buildUnsupported(cs))
                : _buildUnsupported(cs),
        ],
      ),
    );
  }

  Widget _buildWebview(ColorScheme cs) {
    if (_phase == _CfPhase.resolved) {
      final resolvedContent = Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Accès rétabli — le cookie cf_clearance a été détecté.',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      );
      return widget.fullScreen ? Center(child: resolvedContent) : resolvedContent;
    }

    if (!_cookieStoreReady) {
      final loading = const Center(child: CircularProgressIndicator());
      return widget.fullScreen
          ? loading
          : SizedBox(height: widget.compact ? 230 : 320, child: loading);
    }

    return Column(
      mainAxisSize:
          widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hardBlocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              'Le site renvoie un refus d’accès Cloudflare, pas un challenge '
              'interactif. Cette page ne peut pas le résoudre.',
              style: TextStyle(
                color: cs.error,
                fontSize: 12,
              ),
            ),
          )
        else if (_cookiePersistenceFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              'Le navigateur a obtenu le cookie, mais l’application n’a pas '
              'pu l’enregistrer pour les requêtes de la source.',
              style: TextStyle(
                color: cs.error,
                fontSize: 12,
              ),
            ),
          ),
        if (widget.fullScreen)
          Expanded(child: _buildBrowser())
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: SizedBox(
              height: widget.compact ? 230 : 320,
              child: _buildBrowser(),
            ),
          ),

        // ── Footer actions ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _checkingCookie ? null : _probeCookie,
                icon: const Icon(Icons.verified_rounded, size: 15),
                label: const Text('J’ai résolu — vérifier'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.onRetry != null)
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Réessayer la source'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrowser() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 10),
      child: ColoredBox(
        color: Colors.white,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
            useShouldOverrideUrlLoading: false,
            userAgent: MClient.userAgentForRequests(),
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStart: (controller, url) {
            if (mounted) {
              setState(() {
                _webViewController = controller;
                _progress = 0;
                _pageLoaded = false;
                _hardBlocked = false;
                _cookiePersistenceFailed = false;
                _phase = _CfPhase.loading;
              });
            }
          },
          onProgressChanged: (controller, progress) {
            if (mounted) setState(() => _progress = progress / 100.0);
          },
          onLoadStop: (controller, url) => _onLoadStop(controller, url),
        ),
      ),
    );
  }

  Widget _buildUnsupported(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Le challenge ne peut pas être affiché sur cette plateforme. '
                'Ouvrez la source dans votre navigateur, résolvez le challenge, '
                'puis revenez vérifier.',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            FilledButton.tonalIcon(
              onPressed: _checkingCookie ? null : _probeCookie,
              icon: const Icon(Icons.verified_rounded, size: 15),
              label: const Text('Vérifier à nouveau'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11.5),
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Réessayer le diagnostic'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _ShieldStatus extends StatelessWidget {
  final _CfPhase phase;
  final ColorScheme cs;

  const _ShieldStatus({required this.phase, required this.cs});

  @override
  Widget build(BuildContext context) {
    final (icon, color, animating) = switch (phase) {
      _CfPhase.checking || _CfPhase.loading => (
          Icons.shield_outlined,
          Colors.amber.shade700,
          true,
        ),
      _CfPhase.waiting => (
          Icons.shield_outlined,
          Colors.amber.shade700,
          false,
        ),
      _CfPhase.resolved => (Icons.shield_rounded, Colors.green.shade600, false),
      _CfPhase.unsupported => (Icons.shield_outlined, cs.outlineVariant, false),
    };

    Widget shield = Icon(icon, size: 20, color: color);
    if (animating) {
      shield = _PulsingIcon(color: color);
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(child: shield),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
        lowerBound: 0.5)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Icon(Icons.shield_outlined, size: 20, color: widget.color),
    );
  }
}
