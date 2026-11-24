import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';

class SettingsScrobblingPage extends HookConsumerWidget {
  static const name = "settings_scrobbling";

  const SettingsScrobblingPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return SettingsSubpageScaffold(
      title: context.l10n.audio_scrobblers,
      showSearch: false,
      leading: const MusicBackButton(),
      slivers: [
        SliverToBoxAdapter(
          child: SectionCardWithHeading(
            heading: context.l10n.scrobbling,
            icon: Broken.musicnote,
            children: [
              ListTile(
                title: Text(context.l10n.login_with_lastfm),
                trailing: const Icon(Broken.arrow_right_3),
                onTap: () => context.navigateTo(const LastFMLoginRoute()),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
