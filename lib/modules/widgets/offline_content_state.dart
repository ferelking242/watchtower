import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
  const OfflineContentState({super.key});

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
              'Pas de connexion Internet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les pages de ce chapitre ne sont pas disponibles hors ligne. '
              'Reconnectez-vous pour les charger.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
