import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class LiveTvScreen extends StatelessWidget {
  const LiveTvScreen({super.key});

  static const _channels = [
    _LiveChannel(
      'France 24',
      _LiveChannelKind.internationalNews,
      Broken.people,
      'https://www.france24.com/fr/direct',
    ),
    _LiveChannel(
      'Al Jazeera',
      _LiveChannelKind.liveNews,
      Broken.global,
      'https://www.aljazeera.com/live',
    ),
    _LiveChannel(
      'NASA TV',
      _LiveChannelKind.scienceAndSpace,
      Broken.video,
      'https://www.nasa.gov/nasatv/',
    ),
    _LiveChannel(
      'DW',
      _LiveChannelKind.europeanNews,
      Broken.global,
      'https://www.dw.com/en/live-tv/s-100825',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        title: Text(context.l10n.media_live_tv),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF63171B), Color(0xFF24131C)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Broken.video, color: Colors.white, size: 30),
                const SizedBox(height: 14),
                Text(
                  context.l10n.media_watch_live,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.media_world_channels,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.media_available_channels,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._channels.map((channel) => _ChannelTile(channel: channel)),
        ],
      ),
    );
  }
}

/// The channel blurb is a stable key so the screen stays localizable.
enum _LiveChannelKind {
  internationalNews,
  liveNews,
  scienceAndSpace,
  europeanNews,
}

class _LiveChannel {
  final String name;
  final _LiveChannelKind kind;
  final IconData icon;
  final String url;

  const _LiveChannel(this.name, this.kind, this.icon, this.url);

  String description(AppLocalizations l10n) => switch (kind) {
        _LiveChannelKind.internationalNews => l10n.media_international_news,
        _LiveChannelKind.liveNews => l10n.media_live_news,
        _LiveChannelKind.scienceAndSpace => l10n.media_science_space,
        _LiveChannelKind.europeanNews => l10n.media_european_news,
      };
}

class _ChannelTile extends StatelessWidget {
  final _LiveChannel channel;

  const _ChannelTile({required this.channel});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(channel.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_open_channel_failed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE50914).withValues(alpha: 0.18),
          child: Icon(channel.icon, color: const Color(0xFFFF5A5F)),
        ),
        title: Text(
          channel.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          channel.description(context.l10n),
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: const Icon(Broken.arrow_right_3, color: Colors.white54),
        onTap: () => _open(context),
      ),
    );
  }
}
