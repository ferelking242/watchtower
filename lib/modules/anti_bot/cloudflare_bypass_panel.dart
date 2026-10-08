import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Whether this platform can host an inline challenge webview.
bool cloudflareWebviewSupported() =>
    !kIsWeb && !Platform.isLinux && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

/// Reusable inline anti-bot resolver.
///
/// The panel embeds the page in a WebView and *inspects what is actually
/// displayed* before claiming anything:
///
///  * [AntiBotPageType.challenge] → real interactive challenge, wait for the
///    user to solve it (then persist the session for the HTTP retry);
///  * [AntiBotPageType.blocked] → WAF block page, there is no challenge to
///    solve;
///  * [AntiBotPageType.normal] → the page loads normally: the UI says so and
///    never reports a “resolved challenge”.
class CloudflareBypassPanel extends StatefulWidget {
  final String url;
  final int? sourceId;

  /// Called once a challenge has actually been observed, solved, and the
  /// `cf_clearance` cookie persisted for the HTTP client.
  final VoidCallback? onResolved;

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
    this.sourceId,
    this.onResolved,
    this.onRetry,
    this.onClose,
    this.compact = false,
    this.fullScreen = false,
  });

  @override
  State<CloudflareBypassPanel> createState() => _CloudflareBypassPanelState();
}

enum _CfPhase {
  checking,
  loading,
  challenge,
  solved,
  noChallenge,
  blocked,
  clearedWithoutCookie,
  unsupported,
}

class _CloudflareBypassPanelState extends State<CloudflareBypassPanel> {
  _CfPhase _phase = _CfPhase.checking;
  double _progress = 0;
  bool _busy = false;
  bool _cookieStoreReady = false;
  bool _resolvedCallbackSent = false;
  String _host = '';
  String? _statusNote;

  /// True only when a challenge was actually displayed in the WebView. The UI
  /// never reports “challenge resolved” without this flag.
  bool _challengeSeen = false;
  Timer? _pollTimer;
  InAppWebViewController? _webView;
  AntiBotPageType? _lastLoggedPage;

  @override
  void initState() {
    super.initState();
    _host = _hostFrom(widget.url);
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (!cloudflareWebviewSupported()) {
      if (mounted) setState(() => _phase = _CfPhase.unsupported);
      return;
    }
    // The challenge WebView and the extension HTTP client have separate cookie
    // stores. Seed the browser store before its first navigation so an
    // existing cf_clearance cookie is reused.
    try {
      await MClient.restoreCookiesToWebView(
        widget.url,
        sourceId: widget.sourceId,
      );
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
      _phase = _CfPhase.loading;
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

  Future<AntiBotAssessment> _probe() async {
    final controller = _webView;
    if (controller == null) return const AntiBotAssessment();
    try {
      final raw = await controller.evaluateJavascript(source: kCfPageProbeJs);
      return parsePageProbe(raw);
    } catch (e) {
      AppLogger.log(
        'CloudflareBypassPanel page probe failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
      return const AntiBotAssessment();
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _inspectPage();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onPageLoaded() async {
    if (!mounted) return;
    setState(() => _progress = 1);
    await _inspectPage();
  }

  Future<void> _inspectPage() async {
    if (!_cookieStoreReady) return;
    final assessment = await _probe();
    if (!mounted) return;

    if (assessment.pageType != _lastLoggedPage) {
      _lastLoggedPage = assessment.pageType;
      AppLogger.log(
        '[CloudflareWebView] url=${redactUrl(widget.url)} '
        'pageType=${assessment.pageType.name} '
        'challengeDetected=${assessment.challenge} '
        'blocked=${assessment.blocked}',
        logLevel: LogLevel.debug,
        tag: kLogTagNet,
      );
    }

    switch (assessment.pageType) {
      case AntiBotPageType.challenge:
        _challengeSeen = true;
        setState(() {
          _phase = _CfPhase.challenge;
          _statusNote = null;
        });
        // Challenges can clear on their own (Turnstile) without a new load.
        _startPolling();
        return;
      case AntiBotPageType.blocked:
        _stopPolling();
        setState(() {
          _phase = _CfPhase.blocked;
          _statusNote = null;
        });
        return;
      case AntiBotPageType.normal:
        if (_challengeSeen) {
          await _finishResolution();
        } else {
          _stopPolling();
          setState(() {
            _phase = _CfPhase.noChallenge;
            _statusNote = null;
          });
        }
        return;
      case AntiBotPageType.unknown:
        // Page mid-load or probe unavailable: keep the current phase, the
        // polling loop / next onLoadStop will retry.
        return;
    }
  }

  /// Called when the page no longer shows a challenge after one was seen.
  Future<void> _finishResolution() async {
    _stopPolling();
    var persisted = false;
    final controller = _webView;
    if (controller != null) {
      try {
        final ua = await controller.evaluateJavascript(
              source: 'navigator.userAgent',
            ) ??
            '';
        if (ua.isNotEmpty) {
          await MClient.setCookie(
            widget.url,
            ua,
            controller,
            sourceId: widget.sourceId,
          );
        }
        // Verify the cookie really reached the HTTP client store (Isar).
        final stored = MClient.getCookiesPref(
          widget.url,
          sourceId: widget.sourceId,
        ).values.join('; ');
        persisted = stored
            .split(';')
            .any((cookie) => cookie.trim().startsWith('cf_clearance='));
      } catch (e) {
        AppLogger.log(
          'CloudflareBypassPanel cookie persistence failed: $e',
          logLevel: LogLevel.warning,
          tag: kLogTagNet,
        );
      }
      if (!persisted) {
        persisted = await MClient.hasCfClearanceCookie(
          widget.url,
          sourceId: widget.sourceId,
        );
      }
    }

    final resolved = canMarkChallengeResolved(
      challengeSeen: _challengeSeen,
      cfClearancePresent: persisted,
      currentPage: AntiBotPageType.normal,
    );
    if (!mounted) return;

    if (resolved) {
      setState(() {
        _phase = _CfPhase.solved;
        _statusNote = null;
      });
      if (!_resolvedCallbackSent) {
        _resolvedCallbackSent = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (mounted) widget.onResolved?.call();
      }
    } else {
      setState(() {
        _phase = _CfPhase.clearedWithoutCookie;
        _statusNote =
            'Le challenge a disparu mais le cookie cf_clearance n’a pas été '
            'enregistré pour les requêtes HTTP.';
      });
    }
  }

  /// User pressed “Vérifier la page”.
  Future<void> _verifyNow() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusNote = null;
      if (_phase == _CfPhase.noChallenge) _phase = _CfPhase.loading;
    });

    final assessment = await _probe();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (assessment.pageType) {
      case AntiBotPageType.challenge:
        _challengeSeen = true;
        setState(() {
          _phase = _CfPhase.challenge;
          _statusNote =
              'Le challenge est encore présent — terminez-le puis vérifiez à nouveau.';
        });
        return;
      case AntiBotPageType.blocked:
        _stopPolling();
        setState(() {
          _phase = _CfPhase.blocked;
          _statusNote = null;
        });
        return;
      case AntiBotPageType.normal:
        if (_challengeSeen) {
          await _finishResolution();
        } else {
          _stopPolling();
          setState(() {
            _phase = _CfPhase.noChallenge;
            _statusNote = null;
          });
        }
        return;
      case AntiBotPageType.unknown:
        setState(() {
          _statusNote = 'Vérification impossible pour le moment — réessayez.';
        });
        return;
    }
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
                  color: cs.outlineVariant.withValues(alpha: 0.7)),
            ),
      clipBehavior: widget.fullScreen ? Clip.none : Clip.antiAlias,
      child: Column(
        mainAxisSize: widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
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
                      _phaseTitle(_phase),
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
              _phase == _CfPhase.challenge ||
              _phase == _CfPhase.solved)
            SizedBox(
              height: 2,
              child: _phase == _CfPhase.solved
                  ? LinearProgressIndicator(
                      value: 1,
                      backgroundColor: Colors.transparent,
                      color: Colors.green.shade500,
                    )
                  : LinearProgressIndicator(
                      value: _phase == _CfPhase.challenge ? null : _progress,
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

          if (_statusNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                _statusNote!,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _phaseTitle(_CfPhase phase) => switch (phase) {
        _CfPhase.checking => 'Vérification du challenge…',
        _CfPhase.loading => 'Chargement de la page…',
        _CfPhase.challenge => 'Challenge Cloudflare',
        _CfPhase.solved => 'Challenge résolu',
        _CfPhase.noChallenge => 'Aucun challenge détecté',
        _CfPhase.blocked => 'Blocage anti-bot (sans challenge)',
        _CfPhase.clearedWithoutCookie => 'Challenge franchi — cookie manquant',
        _CfPhase.unsupported => 'WebView indisponible',
      };

  Widget _buildWebview(ColorScheme cs) {
    if (!_cookieStoreReady || _phase == _CfPhase.checking) {
      final loading = const Center(child: CircularProgressIndicator());
      return widget.fullScreen
          ? loading
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              child: SizedBox(
                height: 32,
                width: 32,
                child: loading,
              ),
            );
    }

    if (_phase == _CfPhase.solved) {
      final resolvedContent = Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Accès rétabli — le cookie cf_clearance a été détecté et enregistré.',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      );
      return widget.fullScreen
          ? Center(child: resolvedContent)
          : resolvedContent;
    }

    return Column(
      mainAxisSize: widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_phase == _CfPhase.blocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              'Cloudflare renvoie un refus d’accès, pas un challenge '
              'interactif : cette page ne peut pas le résoudre.',
              style: TextStyle(color: cs.error, fontSize: 12),
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
        if (_phase == _CfPhase.noChallenge)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Cette page se charge normalement : aucun challenge Cloudflare '
              'n’est affiché. L’erreur vient probablement d’ailleurs (403/API, '
              'en-têtes, autre anti-bot) — elle ne se résout pas ici.',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant, height: 1.35),
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
                onPressed: _busy ? null : _verifyNow,
                icon: const Icon(Icons.verified_rounded, size: 15),
                label: const Text('Vérifier la page'),
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
            // Same UA as the HTTP client so cf_clearance stays valid for both.
            userAgent: widget.sourceId == null
                ? MClient.userAgentForRequests()
                : MClient.extensionUserAgentForRequests(
                    sourceId: widget.sourceId,
                  ),
          ),
          onWebViewCreated: (controller) => _webView = controller,
          onLoadStart: (ctrl, url) {
            if (mounted) {
              setState(() {
                _webView = ctrl;
                _progress = 0;
                _phase = _CfPhase.loading;
              });
            }
          },
          onProgressChanged: (ctrl, progress) {
            if (mounted) setState(() => _progress = progress / 100.0);
          },
          onLoadStop: (ctrl, url) => _onPageLoaded(),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _verifyNow,
                icon: const Icon(Icons.verified_rounded, size: 15),
                label: const Text('Vérifier à nouveau'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
              ),
              if (widget.onRetry != null)
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
          ),
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
      _CfPhase.checking || _CfPhase.loading || _CfPhase.challenge => (
          Icons.shield_outlined,
          Colors.amber.shade700,
          true,
        ),
      _CfPhase.solved => (Icons.shield_rounded, Colors.green.shade600, false),
      _CfPhase.noChallenge => (
          Icons.verified_user_outlined,
          Colors.green.shade600,
          false,
        ),
      _CfPhase.blocked || _CfPhase.clearedWithoutCookie => (
          Icons.gpp_maybe_outlined,
          cs.error,
          false,
        ),
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
