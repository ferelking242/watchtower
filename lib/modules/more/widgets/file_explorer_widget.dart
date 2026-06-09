import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart';

  class FileExplorerWidget extends StatelessWidget {
    const FileExplorerWidget({super.key});

    static const _kWatchtowerSiteUrl =
        'https://ferelking242.github.io/watchtower/';

    Future<void> _openWebView() async {
      final uri = Uri.parse(_kWatchtowerSiteUrl);
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.language_rounded, color: cs.primary, size: 22),
        ),
        title: const Text('Site Watchtower'),
        subtitle: const Text(
          'Ouvre le site officiel Watchtower',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: _openWebView,
      );
    }
  }
  