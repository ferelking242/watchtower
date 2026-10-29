import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/utils/system_settings.dart';

bool isOfflineContentError(Object error) {
  final message = error.toString().toLowerCase();
  const offlineIndicators = [
    'socketexception',
    'httpexception',
    'connection refused',
    'connection reset',
    'connection timed out',
    'network is unreachable',
    'failed host lookup',
    'no address associated with hostname',
    'network request failed',
    'failed to fetch',
    'fetch failed',
    'networkerror',
    'clientexception',
    'unknownhostexception',
    'no internet',
    'offline',
    'timeout',
    'unexpected end of json input',
    'unexpected end of input',
  ];
  return offlineIndicators.any(message.contains);
}

class OfflineContentState extends StatelessWidget {
  const OfflineContentState({
    this.title = 'Pas de connexion Internet',
    this.message =
        'Les pages de ce chapitre ne sont pas disponibles hors ligne. '
        'Reconnectez-vous pour les charger.',
    this.onRetry,
    super.key,
  });

  /// Headline shown above the message.
  final String title;

  /// Body copy explaining what the user can do.
  final String message;

  /// Optional retry action. When provided a second, text button is shown
  /// beneath the network-settings button.
  final VoidCallback? onRetry;

  Future<void> _openNetworkSettings(BuildContext context) =>
      openNetworkSettings(context);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 180,
              child: Lottie.asset(
                'assets/animations/no_connection.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openNetworkSettings(context),
              icon: const Icon(Broken.wifi, size: 18),
              label: const Text('Activer le réseau'),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Broken.refresh_2, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
