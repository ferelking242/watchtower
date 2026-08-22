import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

class NoDefaultMetadataPlugin extends StatelessWidget {
  const NoDefaultMetadataPlugin({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Undraw(
            height: 200 * 1.0,
            illustration: UndrawIllustration.stars,
            color: Theme.of(context).colorScheme.primary,
          ),
          AutoSizeText(
            context.l10n.no_default_metadata_provider_selected,
            style: Theme.of(context).textTheme.titleLarge!,
            maxLines: 1,
          ),
          FilledButton(
            child: Text(context.l10n.manage_metadata_providers),
            onPressed: () {
              context.pushRoute(const SettingsMetadataProviderRoute());
            },
          ),
        ],
      ),
    );
  }
}
