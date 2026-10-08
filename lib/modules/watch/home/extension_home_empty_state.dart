import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';

int? extensionHttpStatusCode(Object? error) {
  if (error == null) return null;
  final detail = error.toString();
  final patterns = [
    RegExp(
      r'\bHTTP(?:/\d+(?:\.\d+)?)?\s*[:=#-]?\s*([1-5]\d{2})\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bstatus(?:\s*code)?\s*(?:(?:is|of)\s+|[:=]\s*)?([1-5]\d{2})\b',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(detail);
    final code = int.tryParse(match?.group(1) ?? '');
    if (code != null) return code;
  }
  return null;
}

/// Extracts the exact failing URL embedded in an extension error so the bypass
/// WebView opens the request that was actually challenged. Opening the site
/// root instead shows a normal page with no challenge, which cannot be beaten.
String? extensionFailedUrl(Object? error) {
  if (error == null) return null;
  // Extensions put the URL as the last whitespace-delimited token, so a greedy
  // match to the next space keeps query strings (which contain (), %, &) intact.
  final match = RegExp(
    r'https?://\S+',
    caseSensitive: false,
  ).firstMatch(error.toString());
  var url = match?.group(0);
  if (url == null) return null;
  url = _trimTrailingPunctuation(url);
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  return url;
}

/// Drops sentence punctuation a URL may have picked up as its last token
/// (e.g. a closing bracket from `(https://…)`), without touching balanced
/// brackets that are genuinely part of the query.
String _trimTrailingPunctuation(String url) {
  const closers = {')': '(', ']': '[', '}': '{'};
  var result = url;
  var changed = true;
  while (changed && result.isNotEmpty) {
    changed = false;
    final last = result[result.length - 1];
    final opener = closers[last];
    if (opener != null) {
      if (_count(result, last) > _count(result, opener)) {
        result = result.substring(0, result.length - 1);
        changed = true;
      }
    } else if ('.,;:\'"'.contains(last)) {
      result = result.substring(0, result.length - 1);
      changed = true;
    }
  }
  return result;
}

int _count(String value, String char) => value.split(char).length - 1;

/// Raw, human-readable detail of an extension failure.
///
/// Strips the redundant `[Extension]` / `Exception:` wrappers and collapses
/// whitespace so an unrecognised failure still shows what actually happened
/// instead of falling back to a catch-all sentence.
String? extensionErrorDetail(Object? error) {
  if (error == null) return null;
  // Drop any leading `Exception:` / `[ExtensionName]` wrappers, possibly
  // stacked, then collapse whitespace.
  var detail = error
      .toString()
      .replaceFirst(RegExp(r'^(?:Exception:\s*|\[[^\]]{1,40}\]\s*)+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (detail.isEmpty || detail == 'null') return null;
  return detail;
}

String? extensionRequestFailureMessage(Object? error) {
  if (error == null) return null;
  final detail = error.toString().toLowerCase();
  final statusCode = extensionHttpStatusCode(error);
  if (extensionErrorIsCloudflareApiBlock(error)) {
    if (statusCode != null) {
      return 'Cloudflare bloque la requête API de l’extension '
          '(HTTP $statusCode).';
    }
    if (extensionErrorIsConnectionDropped(error)) {
      return 'Cloudflare a coupé la requête API de l’extension avant toute '
          'réponse. Vérifie l’accès à la source ci-dessous.';
    }
    return 'Cloudflare bloque l’API de l’extension, mais l’erreur ne fournit '
        'aucun code HTTP. Vérifie l’accès à la source ci-dessous.';
  }
  if (extensionErrorIsCloudflareChallenge(error)) {
    final statusSuffix = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'La source demande une vérification anti-bot$statusSuffix. '
        'Termine-la dans le panneau, puis réessaie.';
  }
  if (statusCode != null) {
    return switch (statusCode) {
      401 || 403 =>
        'La source a refusé la requête (HTTP $statusCode). Elle peut être temporairement inaccessible ou demander une vérification.',
      404 => 'La source a renvoyé une page introuvable (HTTP 404).',
      429 =>
        'La source limite temporairement les requêtes (HTTP 429). Réessaie dans quelques instants.',
      >= 500 =>
        'La source rencontre une erreur serveur (HTTP $statusCode). Réessaie dans quelques instants.',
      _ => 'La source a renvoyé une erreur HTTP $statusCode.',
    };
  }
  if (extensionErrorIsConnectionDropped(error)) {
    return 'La source a coupé la connexion (anti-bot). '
        'Termine la vérification ci-dessous, puis réessaie.';
  }
  if (detail.contains('socketexception') ||
      detail.contains('failed host lookup') ||
      detail.contains('timed out') ||
      detail.contains('timeout') ||
      detail.contains('network') ||
      detail.contains('connection')) {
    return 'Connexion à la source impossible. Vérifie le réseau ou réessaie dans quelques instants.';
  }
  if (detail.contains('http 401') || detail.contains('http 403')) {
    return 'La source a refusé la requête. Elle peut être temporairement inaccessible ou demander une vérification.';
  }
  // Never hide an unrecognised failure behind a catch-all sentence: show the
  // extension's own message so the real cause stays visible.
  return extensionErrorDetail(error) ??
      'La source est momentanément indisponible. Réessaie dans quelques instants.';
}

bool extensionErrorIsCloudflareApiBlock(Object? error) {
  if (error == null) return false;
  final detail = error.toString().toLowerCase();
  return detail.contains('cloudflare') &&
      detail.contains('api request') &&
      (detail.contains('blocked') || detail.contains('block'));
}

bool extensionErrorIsCloudflareChallenge(Object? error) {
  if (error == null) return false;
  final detail = error.toString().toLowerCase();
  final hasCloudflareMarker =
      detail.contains('cloudflare') ||
      detail.contains('cf-chl-') ||
      detail.contains('cf_chl_');
  return detail.contains('cf-chl-') ||
      detail.contains('cf_chl_') ||
      (hasCloudflareMarker &&
          (detail.contains('captcha') ||
              detail.contains('just a moment') ||
              detail.contains('attention required') ||
              detail.contains('verify you are human') ||
              detail.contains('challenge page') ||
              detail.contains('challenge detected') ||
              detail.contains('challenge required') ||
              detail.contains('browser verification')));
}

/// A Cloudflare-fronted host can close the TCP connection instead of answering
/// with the challenge page. The HTTP bridge then surfaces a thrown request as
/// `statusCode: 0` / “connection closed before full header was received”, which
/// the empty state must describe as an anti-bot cut, not as “HTTP 0”.
bool extensionErrorIsConnectionDropped(Object? error) {
  if (error == null) return false;
  final detail = error.toString().toLowerCase();
  final dropped = detail.contains('connection closed') ||
      detail.contains('connection reset') ||
      detail.contains('connection terminated') ||
      detail.contains('connection aborted') ||
      detail.contains('clientexception') ||
      detail.contains('connection attempt failed') ||
      detail.contains('connection refused');
  if (!dropped) return false;
  return detail.contains('cloudflare') ||
      detail.contains('allanime') ||
      detail.contains('anti-bot') ||
      detail.contains('cf-chl') ||
      detail.contains('http 0') ||
      RegExp(r'statuscode["\s:=]+0\b').hasMatch(detail);
}

/// Short, specific heading for a failed extension request. Replaces the former
/// catch-all “Impossible de charger le contenu” so the real failure (HTTP code,
/// Cloudflare block, connection error) is visible at a glance.
String extensionErrorTitle(Object? error) {
  if (error == null) return 'Aucun contenu disponible';
  if (extensionErrorIsCloudflareChallenge(error)) {
    return 'Vérification Cloudflare requise';
  }
  if (extensionErrorIsCloudflareApiBlock(error)) return 'Accès API bloqué';
  if (extensionErrorIsConnectionDropped(error)) {
    return 'Blocage anti-bot — connexion coupée';
  }
  final statusCode = extensionHttpStatusCode(error);
  if (statusCode != null) return 'Erreur HTTP $statusCode';
  final detail = error.toString().toLowerCase();
  if (detail.contains('socketexception') ||
      detail.contains('failed host lookup') ||
      detail.contains('timed out') ||
      detail.contains('timeout') ||
      detail.contains('network') ||
      detail.contains('connection')) {
    return 'Connexion impossible';
  }
  return 'Source indisponible';
}

/// True when the inline bypass WebView is worth showing: either a real
/// Cloudflare challenge or a Cloudflare block of the extension API. The panel
/// then opens the exact failing URL and reports what it actually displays.
bool extensionErrorNeedsBypass(Object? error) =>
    extensionErrorIsCloudflareChallenge(error) ||
    extensionErrorIsCloudflareApiBlock(error);

class ExtensionHomeEmptyState extends StatefulWidget {
  const ExtensionHomeEmptyState({
    required this.onRetry,
    required this.onRefresh,
    required this.header,
    this.sourceId,
    this.error,
    this.challengeUrl,
    super.key,
  });

  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final Widget header;
  final int? sourceId;
  final Object? error;
  final String? challengeUrl;

  @override
  State<ExtensionHomeEmptyState> createState() =>
      _ExtensionHomeEmptyStateState();
}

class _ExtensionHomeEmptyStateState extends State<ExtensionHomeEmptyState> {
  late bool _showChallenge = extensionErrorNeedsBypass(widget.error);
  bool _showDetails = false;

  @override
  void didUpdateWidget(covariant ExtensionHomeEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasChallenge = extensionErrorNeedsBypass(oldWidget.error);
    final isChallenge = extensionErrorNeedsBypass(widget.error);
    if (wasChallenge != isChallenge) {
      _showChallenge = isChallenge;
    }
  }

  void _retrySource() {
    unawaited(widget.onRetry());
  }

  /// Full, unsummarised error text for the “Détails” disclosure. Null when the
  /// empty state is the plain “no content” one, or when the summary already
  /// carries the whole message.
  String? get _errorDetail {
    final detail = extensionErrorDetail(widget.error);
    if (detail == null) return null;
    final summary = extensionRequestFailureMessage(widget.error);
    if (summary != null && summary.trim() == detail.trim()) return null;
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    final failureMessage = extensionRequestFailureMessage(widget.error);
    final httpStatusCode = extensionHttpStatusCode(widget.error);
    // Prefer the exact URL that failed: the bypass WebView must open the
    // challenged request, not the site root (which loads without a challenge).
    final failedUrl = extensionFailedUrl(widget.error);
    final challengeUrl = (failedUrl ?? widget.challengeUrl)?.trim();
    final hasChallengeUrl = challengeUrl?.isNotEmpty == true;
    final cloudflareApiBlocked = extensionErrorIsCloudflareApiBlock(
      widget.error,
    );
    final challengeDetected = extensionErrorIsCloudflareChallenge(
      widget.error,
    );
    final isPlainEmpty = widget.error == null && !challengeDetected;
    // A generic HTTP failure shows its real code in the title, so the separate
    // chip would only duplicate it. Challenge / API-block states keep the chip
    // because their title is a category, not a code.
    final titleShowsHttpCode =
        widget.error != null &&
        !challengeDetected &&
        !cloudflareApiBlocked &&
        httpStatusCode != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: Column(
        children: [
          widget.header,
          Expanded(
            child: SafeArea(
              top: false,
              child: ExtensionAppleRefreshable(
                onRefresh: widget.onRefresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final animationSize = isPlainEmpty
                        ? math.min(
                            220.0,
                            math.max(120.0, constraints.maxHeight * .32),
                          )
                        : 48.0;
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: challengeDetected ? 14 : 22,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // LottieFiles: “empty box3” by partho prothimdatta.
                                  // Free to use under the Lottie Simple License.
                                  // https://lottiefiles.com/free-animation/empty-box3-zu0ECVDz4n
                                  Center(
                                    child: Semantics(
                                      label: isPlainEmpty
                                          ? 'Boîte vide'
                                          : challengeDetected
                                              ? 'Vérification Cloudflare nécessaire'
                                              : cloudflareApiBlocked
                                                  ? 'Accès API bloqué'
                                                  : 'Échec de connexion à la source',
                                      child: isPlainEmpty
                                          ? Lottie.asset(
                                              'assets/animations/empty_box_partho.json',
                                              key: const ValueKey(
                                                'extension-empty-lottie',
                                              ),
                                              width: animationSize,
                                              height: animationSize,
                                              fit: BoxFit.contain,
                                              repeat: true,
                                            )
                                          : Container(
                                              width: animationSize,
                                              height: animationSize,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: .06,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withValues(
                                                    alpha: .10,
                                                  ),
                                                ),
                                              ),
                                              child: Icon(
                                                challengeDetected
                                                    ? Icons.shield_rounded
                                                    : Icons.warning_amber_rounded,
                                                size: 24,
                                                color: challengeDetected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.white70,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: challengeDetected ? 10 : 14),
                                  Text(
                                    extensionErrorTitle(widget.error),
                                    key: const ValueKey('extension-empty-title'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      height: 1.3,
                                      letterSpacing: -0.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  // `0` is the bridge's “request threw” sentinel,
                                  // not a status line: never show it as “HTTP 0”.
                                  if (httpStatusCode != null &&
                                      httpStatusCode > 0 &&
                                      !titleShowsHttpCode) ...[
                                    const SizedBox(height: 8),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .07,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: .12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'HTTP $httpStatusCode',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (failureMessage != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      failureMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ] else if (challengeDetected) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'La source demande une vérification. '
                                      'Termine-la dans le panneau, puis réessaie.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'La source a répondu mais n’a renvoyé '
                                      'aucun élément. Le site sert peut-être '
                                      'une protection anti-bot invisible, ou '
                                      'l’extension est obsolète : mets-la à '
                                      'jour, puis réessaie. Les LOGS donnent '
                                      'le détail.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                  if (_errorDetail != null) ...[
                                    const SizedBox(height: 10),
                                    _ErrorDetailsDisclosure(
                                      detail: _errorDetail!,
                                      expanded: _showDetails,
                                      onToggle: () => setState(
                                        () => _showDetails = !_showDetails,
                                      ),
                                    ),
                                  ],
                                  if (hasChallengeUrl && _showChallenge) ...[
                                    const SizedBox(height: 14),
                                    CloudflareBypassPanel(
                                      url: challengeUrl!,
                                      sourceId: widget.sourceId,
                                      compact: true,
                                      onResolved: _retrySource,
                                      onRetry: _retrySource,
                                      onClose: () => setState(
                                        () => _showChallenge = false,
                                      ),
                                    ),
                                  ],
                                  if (!(hasChallengeUrl && _showChallenge))
                                    ...[
                                      const SizedBox(height: 18),
                                      Center(
                                        child: SizedBox(
                                          width: 190,
                                          child: FilledButton.icon(
                                            onPressed: _retrySource,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Réessayer'),
                                            style: FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(48),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  if (hasChallengeUrl &&
                                      !_showChallenge) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => setState(
                                        () => _showChallenge = true,
                                      ),
                                      icon: const Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Vérifier l’accès à la source',
                                      ),
                                    ),
                                  ],
                                  if (isPlainEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Tirer vers le bas pour actualiser',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible “Détails” block that reveals the raw extension error (HTTP code,
/// Cloudflare marker, Dart stack) so the real cause is never hidden behind the
/// short summary above it.
class _ErrorDetailsDisclosure extends StatelessWidget {
  const _ErrorDetailsDisclosure({
    required this.detail,
    required this.expanded,
    required this.onToggle,
  });

  final String detail;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 15,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Détails de l’erreur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Built only when expanded: an always-present offstage copy would keep
          // the raw text (and its selection handlers) alive for nothing.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        detail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class ExtensionAppleRefreshable extends StatefulWidget {
  const ExtensionAppleRefreshable({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<ExtensionAppleRefreshable> createState() =>
      _ExtensionAppleRefreshableState();
}

class _ExtensionAppleRefreshableState extends State<ExtensionAppleRefreshable> {
  bool _isRefreshing = false;

  void _setStatus(RefreshIndicatorStatus? status) {
    final visible =
        status == RefreshIndicatorStatus.drag ||
        status == RefreshIndicatorStatus.armed ||
        status == RefreshIndicatorStatus.refresh;
    if (visible != _isRefreshing && mounted) {
      setState(() => _isRefreshing = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 18;
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: _setStatus,
          child: widget.child,
        ),
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isRefreshing ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: const Center(child: _ExtensionAppleRefreshDots()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small iPhone-style refresh affordance that does not take up a layout row.
class _ExtensionAppleRefreshDots extends StatefulWidget {
  const _ExtensionAppleRefreshDots();

  @override
  State<_ExtensionAppleRefreshDots> createState() =>
      _ExtensionAppleRefreshDotsState();
}

class _ExtensionAppleRefreshDotsState extends State<_ExtensionAppleRefreshDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final phase = _controller.value * math.pi * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 8; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos(i * math.pi / 4) * 11,
                    math.sin(i * math.pi / 4) * 11,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, -2.4 * _dotPulse(i, phase)),
                    child: Opacity(
                      opacity: .28 + .72 * _dotPulse(i, phase),
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _dotPulse(int index, double phase) {
    final distance = (phase - index * math.pi / 4) % (math.pi * 2);
    final shortest = math.min(distance, math.pi * 2 - distance);
    return (1 - shortest / (math.pi / 2)).clamp(0.0, 1.0).toDouble();
  }
}