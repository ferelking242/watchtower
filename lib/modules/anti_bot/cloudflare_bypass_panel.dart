import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Whether this platform can host an inline challenge webview.
///
/// The OS check alone is not enough: in a widget test (or any embedder without
/// the plugin registered) `InAppWebViewPlatform.instance` is null and building
/// an [InAppWebView] throws. Treating that as unsupported keeps the panel — and
/// the test suite — from crashing.
bool cloudflareWebviewSupported() {
  final osSupported =
      !kIsWeb &&
      !Platform.isLinux &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows);
  if (!osSupported) return false;
  return InAppWebViewPlatform.instance != null;
}

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
///
/// The WebView is mounted exactly once and never swapped out for a loading
/// surface. Replacing it on a transient navigation destroyed and recreated the
/// native view, which made the page reload endlessly before it ever settled.
class CloudflareBypassPanel extends StatefulWidget {
  final String url;
  final int? sourceId;

  /// Called once a challenge has actually been observed, solved, and the
  /// `cf_clearance` cookie persisted for the HTTP client.
  final VoidCallback? onResolved;

  /// Called when the user wants to retry the failing operation.
  final FutureOr<void> Function()? onRetry;

  /// Optional close action (panel embedded in a dismissible surface).
  final VoidCallback? onClose;

  /// Small heading style for embedded cards (no big hero layout).
  final bool compact;

  /// Fills a full-screen route (notification-triggered challenge screen).
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
  verifying,
  solved,
  requestFailed,
  blocked,
  clearedWithoutCookie,
  unsupported,
}

class _CloudflareBypassPanelState extends State<CloudflareBypassPanel> {
  _CfPhase _phase = _CfPhase.checking;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool _cookieStoreReady = false;
  bool _pageLoadedOnce = false;
  bool _resolvedCallbackSent = false;
  bool _inspectionInProgress = false;
  bool _retryLocked = false;
  bool _challengeNavigationPending = false;
  bool _expanded = false;
  String? _statusNote;
  int? _mainFrameHttpStatusCode;

  /// True only when a challenge was actually displayed in the WebView. The UI
  /// never reports “challenge resolved” without this flag.
  bool _challengeSeen = false;
  Timer? _pollTimer;
  InAppWebViewController? _webView;
  AntiBotPageType? _lastLoggedPage;
  int _pollTicks = 0;

  /// Polling is a safety net for challenges that clear without a new load, not
  /// a heartbeat. It stops after ~2.5 min so a stuck page cannot spin forever.
  static const int _maxPollTicks = 150;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progress.dispose();
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
      if (!mounted) return;
      if (_pollTicks++ >= _maxPollTicks) {
        _stopPolling();
        return;
      }
      _inspectPage();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onPageLoaded() async {
    if (!mounted) return;
    _progress.value = 1;
    if (!_pageLoadedOnce) setState(() => _pageLoadedOnce = true);
    await _inspectPage();
  }

  Future<void> _inspectPage() async {
    if (!_cookieStoreReady ||
        _inspectionInProgress ||
        _phase == _CfPhase.solved ||
        _phase == _CfPhase.requestFailed ||
        _phase == _CfPhase.blocked) {
      return;
    }
    _inspectionInProgress = true;
    try {
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
          _challengeNavigationPending = false;
          // The challenge document itself commonly returns HTTP 403/503.
          // Do not mistake that status for the page loaded after solving it.
          _mainFrameHttpStatusCode = null;
          _setPhase(_CfPhase.challenge);
          // Challenges can clear on their own (Turnstile) without a new load.
          _startPolling();
          return;
        case AntiBotPageType.blocked:
          _stopPolling();
          _setPhase(
            _CfPhase.blocked,
            statusNote: 'Accès refusé, sans challenge',
          );
          return;
        case AntiBotPageType.normal:
          // Always try to persist the browser session, even when no challenge
          // was observed: a managed challenge can auto-solve between probes.
          if (_challengeSeen) _setPhase(_CfPhase.verifying);
          await _finishResolution(currentPage: assessment.pageType);
          return;
        case AntiBotPageType.unknown:
          // The post-challenge page is often an API JSON payload or a redirect
          // the text probe cannot classify, so gating persistence on `normal`
          // alone dropped the `cf_clearance` cookie: the WebView kept its
          // session but the HTTP client never saw it, forcing the user to solve
          // the same challenge over and over. Persist here too — the cookie is
          // only trusted when it is actually present.
          if (_challengeSeen) _setPhase(_CfPhase.verifying);
          await _finishResolution(currentPage: assessment.pageType);
          return;
      }
    } finally {
      _inspectionInProgress = false;
      if (mounted &&
          _challengeNavigationPending &&
          _phase != _CfPhase.loading) {
        setState(() => _challengeNavigationPending = false);
      }
    }
  }

  void _setPhase(_CfPhase phase, {String? statusNote}) {
    if (!mounted || (_phase == phase && _statusNote == statusNote)) return;
    setState(() {
      _phase = phase;
      _statusNote = statusNote;
    });
  }

  Future<void> _triggerRetry() async {
    final reopenChallenge = _shouldReloadChallenge;
    if (_retryLocked || (!reopenChallenge && widget.onRetry == null)) return;
    setState(() => _retryLocked = true);
    try {
      if (reopenChallenge) {
        _mainFrameHttpStatusCode = null;
        await _webView?.reload();
      } else {
        await widget.onRetry!.call();
      }
    } catch (error) {
      AppLogger.log(
        'CloudflareBypassPanel retry failed: $error',
        logLevel: LogLevel.warning,
        tag: kLogTagNet,
      );
    } finally {
      if (mounted) setState(() => _retryLocked = false);
    }
  }

  bool get _shouldReloadChallenge {
    if (!_challengeSeen) return false;
    if (_phase == _CfPhase.clearedWithoutCookie ||
        _phase == _CfPhase.blocked ||
        _phase == _CfPhase.challenge) {
      return true;
    }
    return _phase == _CfPhase.requestFailed &&
        (_mainFrameHttpStatusCode == 403 ||
            _mainFrameHttpStatusCode == 503);
  }

  /// Called when the page no longer shows a challenge after one was seen.
  Future<void> _finishResolution({
    AntiBotPageType currentPage = AntiBotPageType.normal,
  }) async {
    _stopPolling();
    var persisted = false;
    final controller = _webView;
    if (controller != null) {
      try {
        final ua =
            await controller.evaluateJavascript(
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

    final statusCode = _mainFrameHttpStatusCode;
    final resolved =
        (statusCode == null || statusCode < 400) &&
        canMarkChallengeResolved(
          challengeSeen: _challengeSeen,
          cfClearancePresent: persisted,
          currentPage: currentPage,
        );
    if (!mounted) return;

    if (resolved) {
      _challengeNavigationPending = false;
      _setPhase(_CfPhase.solved);
      if (!_resolvedCallbackSent && widget.onResolved != null) {
        _resolvedCallbackSent = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (mounted) widget.onResolved?.call();
      }
    } else if (_challengeSeen && statusCode != null && statusCode >= 400) {
      _challengeNavigationPending = false;
      _setPhase(
        _CfPhase.requestFailed,
        statusNote: 'HTTP $statusCode',
      );
    } else {
      _challengeNavigationPending = false;
      // No auto-retry here: the user retries from the panel, so the screen is
      // never torn down and rebuilt while they are looking at it.
      _setPhase(
        _CfPhase.clearedWithoutCookie,
        statusNote: _challengeSeen
            ? 'Challenge franchi — cookie non enregistré'
            : 'Aucun challenge détecté',
      );
    }
  }

  void _toggleExpanded() {
    if (widget.fullScreen) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final supported = cloudflareWebviewSupported();

    if (widget.fullScreen) {
      return Stack(
        children: [
          Positioned.fill(child: _buildSurface(cs, supported)),
          Positioned(top: 0, left: 0, right: 0, child: _buildProgress(cs)),
          Positioned(
            top: 6,
            right: 6,
            child: _buildControls(cs, allowExpand: false),
          ),
        ],
      );
    }

    final maxHeight = MediaQuery.sizeOf(context).height;
    final collapsed = widget.compact ? 300.0 : 380.0;
    final expanded = (maxHeight * 0.72).clamp(collapsed, maxHeight);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: _expanded ? expanded : collapsed,
        child: Stack(
          children: [
            Positioned.fill(child: _buildSurface(cs, supported)),
            Positioned(top: 0, left: 0, right: 0, child: _buildProgress(cs)),
            Positioned(
              top: 6,
              right: 6,
              child: _buildControls(cs, allowExpand: supported),
            ),
            if (_statusNote != null)
              Positioned(
                left: 8,
                bottom: 8,
                right: 64,
                child: _StatusChip(text: _statusNote!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurface(ColorScheme cs, bool supported) {
    if (!supported) return _buildUnsupported(cs);
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          // Mounted once, kept alive across every phase.
          if (_cookieStoreReady) Positioned.fill(child: _buildBrowser()),
          if (!_pageLoadedOnce)
            Positioned.fill(child: _buildLoadingOverlay(cs)),
          if (_challengeNavigationPending || _phase == _CfPhase.verifying)
            Positioned.fill(child: _buildResolutionLoadingOverlay(cs))
          else if (_phase == _CfPhase.solved ||
              _phase == _CfPhase.requestFailed ||
              _phase == _CfPhase.blocked ||
              (_challengeSeen && _phase == _CfPhase.clearedWithoutCookie))
            Positioned.fill(child: _buildResolutionOverlay(cs)),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    final active =
        _phase == _CfPhase.loading ||
        _phase == _CfPhase.checking ||
        _phase == _CfPhase.challenge ||
        _phase == _CfPhase.verifying ||
        _phase == _CfPhase.solved;
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: SizedBox(
        height: 2,
        child: ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, _) => _phase == _CfPhase.solved
              ? LinearProgressIndicator(
                  value: 1,
                  backgroundColor: Colors.transparent,
                  color: Colors.green.shade500,
                )
              : LinearProgressIndicator(
                  value: _phase == _CfPhase.challenge ? null : progress,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
        ),
      ),
    );
  }

  Widget _buildControls(ColorScheme cs, {required bool allowExpand}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onRetry != null || _shouldReloadChallenge)
          _BoxIconButton(
            icon: Icons.refresh_rounded,
            tooltip: _shouldReloadChallenge
                ? 'Recharger le défi'
                : 'Réessayer la source',
            onPressed:
                _retryLocked ||
                    _challengeNavigationPending ||
                    _phase == _CfPhase.verifying
                ? null
                : _triggerRetry,
          ),
        if (allowExpand)
          _BoxIconButton(
            icon: _expanded
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            tooltip: _expanded ? 'Réduire' : 'Agrandir',
            onPressed: _toggleExpanded,
          ),
        if (widget.onClose != null)
          _BoxIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Fermer',
            onPressed: widget.onClose!,
          ),
      ],
    );
  }

  Widget _buildLoadingOverlay(ColorScheme cs) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
        ),
      ),
    );
  }

  Widget _buildResolutionLoadingOverlay(ColorScheme cs) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Vérification…',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOverlay(ColorScheme cs) {
    final statusCode = _mainFrameHttpStatusCode;
    final IconData icon;
    final Color iconColor;
    final String title;
    final String message;

    switch (_phase) {
      case _CfPhase.solved:
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green.shade600;
        title = 'Défi terminé';
        message = 'Réessaie la source avec l’icône de rafraîchissement.';
        break;
      case _CfPhase.requestFailed:
        icon = Icons.error_outline_rounded;
        iconColor = cs.error;
        title = statusCode == null ? 'Erreur HTTP' : 'HTTP $statusCode';
        message = 'Le défi est terminé, mais la source a refusé la requête.';
        break;
      case _CfPhase.blocked:
        icon = Icons.block_rounded;
        iconColor = cs.error;
        title = statusCode == null ? 'Accès refusé' : 'HTTP $statusCode';
        message = 'Cloudflare bloque cette requête sans défi interactif.';
        break;
      case _CfPhase.clearedWithoutCookie:
        icon = Icons.shield_outlined;
        iconColor = cs.error;
        title = statusCode == null ? 'Défi non confirmé' : 'HTTP $statusCode';
        message = 'Recharge le défi pour réessayer la vérification.';
        break;
      default:
        icon = Icons.info_outline_rounded;
        iconColor = cs.onSurfaceVariant;
        title = 'Vérification en attente';
        message = 'Réessaie la source.';
        break;
    }

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowser() {
    return ClipRect(
      child: InAppWebView(
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          useShouldOverrideUrlLoading: false,
          // Scroll, pinch-zoom and text selection must stay enabled: the
          // Turnstile widget and the “Verify you are human” button sit below
          // the fold, so the user has to be able to reach them.
          disableVerticalScroll: false,
          disableHorizontalScroll: false,
          verticalScrollBarEnabled: true,
          horizontalScrollBarEnabled: true,
          overScrollMode: OverScrollMode.ALWAYS,
          supportZoom: true,
          builtInZoomControls: true,
          displayZoomControls: false,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          // Without hybrid composition the Android surface view swallows
          // touch drags, so the embedded page cannot be scrolled and the
          // “Verify you are human” button below the fold is unreachable.
          useHybridComposition: true,
          isTextInteractionEnabled: true,
          // Same UA as the HTTP client so cf_clearance stays valid for both.
          userAgent: widget.sourceId == null
              ? MClient.userAgentForRequests()
              : MClient.extensionUserAgentForRequests(
                  sourceId: widget.sourceId,
                ),
        ),
        onWebViewCreated: (controller) => _webView = controller,
        onLoadStart: (ctrl, url) {
          if (!mounted) return;
          _webView = ctrl;
          _progress.value = 0;
          _mainFrameHttpStatusCode = null;
          if (_challengeSeen) {
            setState(() => _challengeNavigationPending = true);
            _setPhase(_CfPhase.verifying);
          } else if (!_pageLoadedOnce) {
            _setPhase(_CfPhase.loading);
          }
        },
        onReceivedHttpError: (ctrl, request, errorResponse) {
          if (request.isForMainFrame == true &&
              _phase != _CfPhase.challenge) {
            _mainFrameHttpStatusCode = errorResponse.statusCode;
          }
        },
        onProgressChanged: (ctrl, progress) {
          if (mounted) _progress.value = progress / 100.0;
        },
        onLoadStop: (ctrl, url) => _onPageLoaded(),
      ),
    );
  }

  Widget _buildUnsupported(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Le challenge ne peut pas être affiché ici. Ouvre la source '
                  'dans ton navigateur, résous le challenge, puis réessaye.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact icon button drawn over the WebView, on a translucent disc so it
/// stays legible on any page.
class _BoxIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _BoxIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: 17,
                color: onPressed == null ? Colors.white54 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line state note shown at the bottom of the box.
class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: Colors.white),
      ),
    );
  }
}
