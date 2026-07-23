import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/components/adaptive/adaptive_select_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';

class SettingsProvidersSection extends ConsumerWidget {
  const SettingsProvidersSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final pluginsState = ref.watch(metadataPluginsProvider);
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);
    final theme = Theme.of(context);

    final allPlugins = pluginsState.asData?.value.plugins ?? [];
    final metadataPlugins = allPlugins
        .where((p) => p.abilities.contains(PluginAbilities.metadata))
        .toList();
    final audioPlugins = allPlugins
        .where((p) => p.abilities.contains(PluginAbilities.audioSource))
        .toList();

    final defaultMetadataIdx =
        pluginsState.asData?.value.defaultMetadataPlugin ?? -1;
    final defaultAudioIdx =
        pluginsState.asData?.value.defaultAudioSourcePlugin ?? -1;

    // Convert global index → per-type index
    int metaSelIdx = -1;
    if (defaultMetadataIdx >= 0) {
      final slug = allPlugins[defaultMetadataIdx].slug;
      metaSelIdx =
          metadataPlugins.indexWhere((p) => p.slug == slug);
    }
    int audioSelIdx = -1;
    if (defaultAudioIdx >= 0) {
      final slug = allPlugins[defaultAudioIdx].slug;
      audioSelIdx = audioPlugins.indexWhere((p) => p.slug == slug);
    }

    return SectionCardWithHeading(
      heading: 'Providers',
      children: [
        // ── Metadata Provider selector ─────────────────────────────────
        metadataPlugins.isEmpty
            ? ListTile(
                leading: const Icon(SpotubeIcons.album),
                title: const Text('Metadata'),
                subtitle: Text(
                  context.l10n.no_default_metadata_provider_selected,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () =>
                      context.pushRoute(const SettingsMetadataProviderRoute()),
                  child: const Text('Browse'),
                ),
              )
            : AdaptiveSelectTile<int>(
                secondary: const Icon(SpotubeIcons.album),
                title: const Text('Metadata'),
                value: metaSelIdx < 0 ? 0 : metaSelIdx,
                options: [
                  for (int i = 0; i < metadataPlugins.length; i++)
                    SelectItemButton(
                      value: i,
                      child: Text(
                        metadataPlugins[i].name.length > 20
                            ? '${metadataPlugins[i].name.substring(0, 18)}…'
                            : metadataPlugins[i].name,
                      ),
                    ),
                ],
                onChanged: (idx) async {
                  if (idx == null || idx < 0) return;
                  await pluginsNotifier
                      .setDefaultMetadataPlugin(metadataPlugins[idx]);
                },
              ),

        const Divider(height: 0, indent: 16, endIndent: 16),

        // ── Audio Source selector ──────────────────────────────────────
        audioPlugins.isEmpty
            ? ListTile(
                leading: const Icon(SpotubeIcons.music),
                title: const Text('Audio Source'),
                subtitle: Text(
                  context.l10n.install_a_metadata_provider,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () =>
                      context.pushRoute(const SettingsMetadataProviderRoute()),
                  child: const Text('Browse'),
                ),
              )
            : AdaptiveSelectTile<int>(
                secondary: const Icon(SpotubeIcons.music),
                title: const Text('Audio Source'),
                value: audioSelIdx < 0 ? 0 : audioSelIdx,
                options: [
                  for (int i = 0; i < audioPlugins.length; i++)
                    SelectItemButton(
                      value: i,
                      child: Text(
                        audioPlugins[i].name.length > 20
                            ? '${audioPlugins[i].name.substring(0, 18)}…'
                            : audioPlugins[i].name,
                      ),
                    ),
                ],
                onChanged: (idx) async {
                  if (idx == null || idx < 0) return;
                  await pluginsNotifier
                      .setDefaultAudioSourcePlugin(audioPlugins[idx]);
                },
              ),

        const Divider(height: 0, indent: 16, endIndent: 16),

        // ── Manage Extensions link ─────────────────────────────────────
        ListTile(
          leading: const Icon(SpotubeIcons.plugin),
          title: const Text('Manage Extensions'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () =>
              context.pushRoute(const SettingsMetadataProviderRoute()),
        ),
      ],
    );
  }
}
