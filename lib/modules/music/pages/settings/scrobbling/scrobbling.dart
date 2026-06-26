import 'package:flutter/material.dart'
    show ListTile, ListTileTheme, ListTileThemeData, Material, MaterialType;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

class SettingsScrobblingPage extends HookConsumerWidget {
  static const name = "settings_scrobbling";

  const SettingsScrobblingPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return Material(
      type: MaterialType.transparency,
      child: ListTileTheme(
        data: ListTileThemeData(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 0,
          shape: RoundedRectangleBorder(
            borderRadius: context.theme.borderRadiusLg,
            side: BorderSide(
              color: context.theme.colorScheme.border,
              width: .5,
            ),
          ),
          textColor: context.theme.colorScheme.foreground,
          iconColor: context.theme.colorScheme.foreground,
          selectedColor: context.theme.colorScheme.accent,
          subtitleTextStyle: context.theme.typography.xSmall,
        ),
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            headers: [TitleBar(title: Text(context.l10n.scrobbling))],
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Card(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(SpotubeIcons.lastFm, color: Colors.red),
                    title: Text(context.l10n.login_with_lastfm),
                    subtitle: Text(context.l10n.scrobble_to_lastfm),
                    trailing: Button.secondary(
                      leading: const Icon(SpotubeIcons.lastFm),
                      onPressed: () {
                        context.navigateTo(const LastFMLoginRoute());
                      },
                      child: Text(context.l10n.connect),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
