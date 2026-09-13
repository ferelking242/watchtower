import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.tertiaryContainer],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primary,
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profil local', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Vos préférences restent dans Watchtower.',
                          style: TextStyle(fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _ProfileSectionTitle('Préférences'),
          _ProfileTile(
            icon: Icons.palette_outlined,
            title: 'Apparence',
            subtitle: 'Thème, couleurs et navigation',
            onTap: () => context.push('/appearance'),
          ),
          _ProfileTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Interface & effets',
            subtitle: 'Animation des fleurs, flou et cartes',
            onTap: () => context.push('/uiSettings'),
          ),
          _ProfileTile(
            icon: Icons.tune_rounded,
            title: 'Navigation',
            subtitle: 'Choisir les entrées du Hub et du menu',
            onTap: () => context.push('/customNavigationSettings'),
          ),
          const SizedBox(height: 16),
          const _ProfileSectionTitle('Données'),
          _ProfileTile(
            icon: Icons.storage_rounded,
            title: 'Données et stockage',
            subtitle: 'Sauvegardes, cache et fichiers locaux',
            onTap: () => context.push('/dataAndStorage'),
          ),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Réglages Watchtower',
            subtitle: 'Tous les réglages de l’application',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final String text;

  const _ProfileSectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
      );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}