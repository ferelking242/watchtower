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
        l10n.internal_player_info,
        '/playerMode',
      ),
      (
        Broken.mouse,
        l10n.settings_idx_title_gestes,
        l10n.player_gestures_subtitle,
        '/playerGestureScreen',
      ),
      (
        Broken.cpu,
        l10n.decoder,
        l10n.decoder_info,
        '/playerDecoderScreen',
      ),
      (
        Broken.message_text,
        l10n.settings_idx_title_sous_titres,
        l10n.player_subtitles_subtitle,
        '/playerSubtitleScreen',
      ),
      (
        Broken.volume_high,
        l10n.video_audio,
        l10n.video_audio_info,
        '/playerAudioScreen',
      ),
      (
        Broken.command,
        l10n.custom_buttons,
        l10n.custom_buttons_info,
        '/customButtonScreen',
      ),
      (
        Broken.code,
        l10n.player_script_editor_title,
        l10n.player_script_editor_subtitle,
        '/playerScriptEditor',
      ),
      (
        Broken.link,
        l10n.settings_idx_title_torrent,
        l10n.player_torrent_subtitle,
        '/playerTorrentScreen',
      ),
      (
        Broken.setting_4,
        l10n.advanced,
        l10n.advanced_info,
        '/playerAdvancedScreen',
      ),
      (
        Broken.folder,
        l10n.settings_idx_title_fichiers_utilisateur,
        l10n.player_user_files_subtitle,
        '/playerAdvancedScreen',
      ),
    ];

    return SettingsSubpageScaffold(
      title: l10n.player_video,
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
