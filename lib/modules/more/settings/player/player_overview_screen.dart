import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Video player settings hub, modelled on Aniyomi's "Lecteur" section.
class PlayerOverviewScreen extends StatelessWidget {
  const PlayerOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;

    final entries = <(IconData, String, String, String)>[
      (
        Broken.play_circle,
        l10n.internal_player,
        'Progression, contrôles, orientation',
        '/playerMode',
      ),
      (
        Broken.mouse,
        'Gestes',
        'Chercher, double tap, contrôles',
        '/playerGestureScreen',
      ),
      (
        Broken.cpu,
        l10n.decoder,
        'Décodage matériel, format de pixel, désentrelacement',
        '/playerDecoderScreen',
      ),
      (
        Broken.message_text,
        'Sous-titres',
        'Langues préférées, liste blanche, liste noire',
        '/playerSubtitleScreen',
      ),
      (
        Broken.volume_high,
        l10n.video_audio,
        'Langues préférées, correction de la hauteur, canaux audio',
        '/playerAudioScreen',
      ),
      (
        Broken.command,
        l10n.custom_buttons,
        'Exécuter du code lua avec des boutons personnalisés',
        '/customButtonScreen',
      ),
      (
        Broken.code,
        'Éditeur de scripts',
        'Modifier et créer de nouveaux scripts et options de script',
        '/playerScriptEditor',
      ),
      (
        Broken.link,
        'Torrent',
        'TorrServer options',
        '/playerTorrentScreen',
      ),
      (
        Broken.setting_4,
        l10n.advanced,
        'Configuration mpv',
        '/playerAdvancedScreen',
      ),
      (
        Broken.folder,
        'Fichiers utilisateur',
        'Scripts, shaders et polices personnalisés',
        '/playerAdvancedScreen',
      ),
    ];

    return SettingsSubpageScaffold(
      title: l10n.player,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final (icon, title, subtitle, route) = entries[index];
              return ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push(route),
              );
            },
            childCount: entries.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
