import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = _ProfileCopy.of(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.movie_filter_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: .52,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: .14),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 58,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        copy.anonymousTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        copy.anonymousSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _showAccountDialog(context, copy),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(copy.login),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileActionCard(
                  icon: Icons.insights_rounded,
                  title: copy.insights,
                  subtitle: copy.insightsSubtitle,
                  onTap: () => context.push('/statistics'),
                ),
                const SizedBox(height: 18),
                _ProfileActionGroup(
                  children: [
                    _ProfileAction(
                      icon: Icons.settings_outlined,
                      title: copy.settings,
                      onTap: () => context.push('/settings'),
                    ),
                    _ProfileAction(
                      icon: Icons.palette_outlined,
                      title: copy.appearance,
                      onTap: () => context.push('/appearance'),
                    ),
                    _ProfileAction(
                      icon: Icons.storage_outlined,
                      title: copy.storage,
                      onTap: () => context.push('/dataAndStorage'),
                    ),
                    _ProfileAction(
                      icon: Icons.dns_outlined,
                      title: copy.server,
                      onTap: () => _showMessage(context, copy.serverMessage),
                    ),
                    _ProfileAction(
                      icon: Icons.system_update_alt_rounded,
                      title: copy.checkUpdate,
                      onTap: () => context.push('/updates'),
                    ),
                    _ProfileAction(
                      icon: Icons.share_outlined,
                      title: copy.share,
                      onTap: () => Share.share(copy.shareMessage),
                    ),
                    _ProfileAction(
                      icon: Icons.info_outline_rounded,
                      title: copy.about,
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountDialog(BuildContext context, _ProfileCopy copy) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.login),
        content: Text(copy.accountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/settings');
            },
            child: Text(copy.settings),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileActionGroup extends StatelessWidget {
  const _ProfileActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ProfileCopy {
  const _ProfileCopy({
    required this.title,
    required this.anonymousTitle,
    required this.anonymousSubtitle,
    required this.login,
    required this.insights,
    required this.insightsSubtitle,
    required this.settings,
    required this.appearance,
    required this.storage,
    required this.server,
    required this.serverMessage,
    required this.checkUpdate,
    required this.share,
    required this.shareMessage,
    required this.about,
    required this.accountMessage,
    required this.close,
  });

  final String title;
  final String anonymousTitle;
  final String anonymousSubtitle;
  final String login;
  final String insights;
  final String insightsSubtitle;
  final String settings;
  final String appearance;
  final String storage;
  final String server;
  final String serverMessage;
  final String checkUpdate;
  final String share;
  final String shareMessage;
  final String about;
  final String accountMessage;
  final String close;

  static _ProfileCopy of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final base = language == 'fr'
        ? const _ProfileCopy(
        title: 'Moi',
        anonymousTitle: 'Compte anonyme',
        anonymousSubtitle:
            'Utilisez Watchtower sans compte. Vos préférences restent sur cet appareil.',
        login: 'Connexion / inscription',
        insights: 'Statistiques de visionnage',
        insightsSubtitle: 'Suivez vos habitudes de lecture et de visionnage',
        settings: 'Paramètres',
        appearance: 'Apparence',
        storage: 'Données et stockage',
        server: 'État du serveur',
        serverMessage: 'Les services TMDB et les sources sont vérifiés à la demande.',
        checkUpdate: 'Rechercher une mise à jour',
        share: 'Partager l’application',
        shareMessage: 'Découvrez Watchtower, votre bibliothèque de contenus.',
        about: 'À propos',
        accountMessage:
            'La gestion de compte en ligne n’est pas activée dans cette version de Watchtower. Vous pouvez continuer avec le profil local et les réglages de l’application.',
        close: 'Fermer',
      )
        : const _ProfileCopy(
      title: 'Me',
      anonymousTitle: 'Anonymous account',
      anonymousSubtitle:
          'Use Watchtower without an account. Your preferences stay on this device.',
      login: 'Login / Sign up',
      insights: 'Viewing insights',
      insightsSubtitle: 'Track your reading and watching habits',
      settings: 'Settings',
      appearance: 'Appearance',
      storage: 'Data and storage',
      server: 'Server status',
      serverMessage: 'TMDB and source services are checked on demand.',
      checkUpdate: 'Check for update',
      share: 'Share the app',
      shareMessage: 'Discover Watchtower, your personal content library.',
      about: 'About',
      accountMessage:
          'Online account management is not enabled in this Watchtower build. You can continue with the local profile and app settings.',
      close: 'Close',
    );
    final l10n = context.l10n;
    return base.copyWith(
      login: l10n.login,
      settings: l10n.settings,
      checkUpdate: l10n.check_for_update,
      share: l10n.share,
      about: l10n.about,
    );
  }

  _ProfileCopy copyWith({
    String? login,
    String? settings,
    String? checkUpdate,
    String? share,
    String? about,
  }) {
    return _ProfileCopy(
      title: title,
      anonymousTitle: anonymousTitle,
      anonymousSubtitle: anonymousSubtitle,
      login: login ?? this.login,
      insights: insights,
      insightsSubtitle: insightsSubtitle,
      settings: settings ?? this.settings,
      appearance: appearance,
      storage: storage,
      server: server,
      serverMessage: serverMessage,
      checkUpdate: checkUpdate ?? this.checkUpdate,
      share: share ?? this.share,
      shareMessage: shareMessage,
      about: about ?? this.about,
      accountMessage: accountMessage,
      close: close,
    );
  }
}