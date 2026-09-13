import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTvScreen extends StatelessWidget {
  const LiveTvScreen({super.key});

  static const _channels = [
    _LiveChannel('France 24', 'Actualités internationales', Icons.public_rounded,
        'https://www.france24.com/fr/direct'),
    _LiveChannel('Al Jazeera', 'News en direct', Icons.language_rounded,
        'https://www.aljazeera.com/live'),
    _LiveChannel('NASA TV', 'Science et espace', Icons.rocket_launch_rounded,
        'https://www.nasa.gov/nasatv/'),
    _LiveChannel('DW', 'Actualités européennes', Icons.travel_explore_rounded,
        'https://www.dw.com/en/live-tv/s-100825'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        title: const Text('TV Live'),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.live_tv_rounded, color: Colors.white, size: 30),
                SizedBox(height: 14),
                Text('Regarder en direct',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Accédez aux pages officielles des chaînes depuis Watchtower.',
                    style: TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Chaînes disponibles',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ..._channels.map((channel) => _ChannelTile(channel: channel)),
        ],
      ),
    );
  }
}

class _LiveChannel {
  final String name;
  final String description;
  final IconData icon;
  final String url;

  const _LiveChannel(this.name, this.description, this.icon, this.url);
}

class _ChannelTile extends StatelessWidget {
  final _LiveChannel channel;

  const _ChannelTile({required this.channel});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(channel.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la chaîne')),
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
        title: Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(channel.description, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white54),
        onTap: () => _open(context),
      ),
    );
  }
}