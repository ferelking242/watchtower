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

String? extensionRequestFailureMessage(Object? error) {
  if (error == null) return null;
  final detail = error.toString().toLowerCase();
  if (extensionErrorIsCloudflareChallenge(error)) {
    return 'La source demande une vérification anti-bot. Termine-la dans le panneau, puis réessaie.';
  }
  final statusCode = extensionHttpStatusCode(error);
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
  return 'La source n’a pas pu répondre correctement. Réessaie; si le problème persiste, consulte les journaux.';
}

bool extensionErrorIsCloudflareChallenge(Object? error) {
  if (error == null) return false;
  final detail = error.toString().toLowerCase();
  return detail.contains('cloudflare') ||
      detail.contains('cf-chl-') ||
      detail.contains('cf_clearance') ||
      detail.contains('cf-ray') ||
      detail.contains('captcha') ||
      detail.contains('challenge') ||
      detail.contains('just a moment') ||
      detail.contains('attention required') ||
      (detail.contains('403') && detail.contains('cloud')) ||
      (detail.contains('503') && detail.contains('cloud'));
}

class ExtensionHomeEmptyState extends StatefulWidget {
  const ExtensionHomeEmptyState({
    required this.onRetry,
    required this.onRefresh,
    required this.header,
    this.error,
    this.challengeUrl,
    super.key,
  });

  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final Widget header;
  final Object? error;
  final String? challengeUrl;

  @override
  State<ExtensionHomeEmptyState> createState() =>
      _ExtensionHomeEmptyStateState();
}

class _ExtensionHomeEmptyStateState extends State<ExtensionHomeEmptyState> {
  late bool _showChallenge =
      extensionErrorIsCloudflareChallenge(widget.error);

  @override
  void didUpdateWidget(covariant ExtensionHomeEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (extensionErrorIsCloudflareChallenge(widget.error)) {
      _showChallenge = true;
    }
  }

  void _retrySource() {
    unawaited(widget.onRetry());
  }

  @override
  Widget build(BuildContext context) {
    final failureMessage = extensionRequestFailureMessage(widget.error);
    final httpStatusCode = extensionHttpStatusCode(widget.error);
    final challengeUrl = widget.challengeUrl?.trim();
    final hasChallengeUrl = challengeUrl?.isNotEmpty == true;
    final challengeDetected = extensionErrorIsCloudflareChallenge(
      widget.error,
    );
    final isPlainEmpty = widget.error == null && !challengeDetected;
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
                                    challengeDetected
                                        ? 'Vérification Cloudflare requise'
                                        : widget.error == null
                                        ? 'Aucun contenu disponible'
                                        : 'Impossible de charger le contenu',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      height: 1.3,
                                      letterSpacing: -0.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (httpStatusCode != null) ...[
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
                                  if (hasChallengeUrl && _showChallenge) ...[
                                    const SizedBox(height: 14),
                                    CloudflareBypassPanel(
                                      url: challengeUrl!,
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
                                  if (hasChallengeUrl && !_showChallenge) ...[
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