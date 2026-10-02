import 'package:flutter/material.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';

/// Full-screen fallback for Cloudflare notifications that cannot be matched
/// to an installed extension.
class CloudflareChallengeScreen extends StatelessWidget {
  const CloudflareChallengeScreen({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host;
    final title = host == null || host.isEmpty
        ? 'Challenge Cloudflare'
        : host;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Résolvez le contrôle de sécurité ici, puis revenez dans '
                'l’application.',
                style: TextStyle(height: 1.45),
              ),
            ),
            CloudflareBypassPanel(url: url),
          ],
        ),
      ),
    );
  }
}