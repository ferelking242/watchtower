import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_bus.dart';

/// Full-screen resolver for a Cloudflare refusal.
///
/// The notification action ("Battre le challenge") used to push the extension
/// home, which is useless when the refused URL is a media CDN (Surrit behind
/// MissAV) or when the blocked screen is not the one being displayed. This
/// route always opens something the user can act on: the refused page itself,
/// in a real browser session, with the bypass panel driving the resolution.
class CloudflareChallengeScreen extends StatelessWidget {
  const CloudflareChallengeScreen({
    super.key,
    required this.url,
    this.sourceId,
  });

  final String url;
  final int? sourceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Cloudflare'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            CloudflareChallengeBus.instance.clear();
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Résous le défi ci-dessous, puis relance la lecture. '
                'La session est conservée pour les prochaines requêtes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: CloudflareBypassPanel(
                  url: url,
                  sourceId: sourceId,
                  bounded: true,
                  onResolved: () => CloudflareChallengeBus.instance.clear(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
