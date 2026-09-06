import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: .5,
            ),
          ),
          textColor: Theme.of(context).colorScheme.onSurface,
          iconColor: Theme.of(context).colorScheme.onSurface,
          selectedColor: Theme.of(context).colorScheme.secondary,
          subtitleTextStyle: Theme.of(context).textTheme.labelSmall!,
        ),
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            appBar: AppBar(title: Text(context.l10n.scrobbling)),
            body: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Card(
                  child: ListTile(
                    title: Text(context.l10n.login_with_lastfm),
                    trailing: ElevatedButton(
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
