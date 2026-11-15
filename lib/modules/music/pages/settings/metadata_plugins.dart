import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/installed_plugin.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/utils/open_marketplace.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

/// Music plugin manager.
///
/// Installation, updates and the browseable catalogue live in the Watchtower
/// Extension Marketplace — the single entry point for every extension. This
/// screen only lists the plugins that are actually *installed* and exposes
/// their configuration (default provider, sign-in, removal).
class SettingsMetadataProviderPage extends HookConsumerWidget {
  const SettingsMetadataProviderPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final tabState = useState<int>(0);
    final theme = Theme.of(context);

    final plugins = ref.watch(metadataPluginsProvider);
    final installedPlugins = useMemoized<List<PluginConfiguration>?>(() {
      final all = plugins.asData?.value.plugins;
      if (all == null) return null;
      if (tabState.value == 0) return all;
      return all.where((d) {
        return d.abilities.contains(
          tabState.value == 1
              ? PluginAbilities.metadata
              : PluginAbilities.audioSource,
        );
      }).toList();
    }, [tabState.value, plugins.asData?.value]);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.plugins)),
        body: CustomScrollView(
          slivers: [
            // Where to install: the Marketplace owns installation.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Broken.element_4,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(context.l10n.browse_marketplace),
                    subtitle:
                        Text(context.l10n.plugins_install_in_marketplace),
                    trailing: const Icon(Broken.arrow_right_3),
                    onTap: () => openMarketplace(context),
                  ),
                ),
              ),
            ),

            // Filter chips (All / Metadata / Audio source)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (i, label) in [
                        context.l10n.all,
                        context.l10n.metadata,
                        context.l10n.audio_source,
                      ].indexed) ...[
                        FilterChip(
                          label: Text(label),
                          selected: tabState.value == i,
                          onSelected: (_) => tabState.value = i,
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: AppSectionHeader(title: context.l10n.installed),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            if (plugins.isLoading && plugins.asData?.value == null)
              SliverList.builder(
                itemCount: 3,
                itemBuilder: (context, _) => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ShimmerSkeleton(
                    enabled: true,
                    child: _PluginSkeletonCard(),
                  ),
                ),
              )
            else if ((installedPlugins ?? const []).isEmpty)
              SliverToBoxAdapter(child: _EmptyInstalled(tab: tabState.value))
            else
              SliverList.separated(
                itemCount: installedPlugins!.length,
                separatorBuilder: (context, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final plugin = installedPlugins[index];
                  final isDefaultMetadata =
                      plugins.asData!.value.defaultMetadataPluginConfig?.slug ==
                          plugin.slug;
                  final isDefaultAudioSource = plugins.asData!.value
                          .defaultAudioSourcePluginConfig?.slug ==
                      plugin.slug;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetadataInstalledPluginItem(
                      plugin: plugin,
                      isDefaultMetadata: isDefaultMetadata,
                      isDefaultAudioSource: isDefaultAudioSource,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Disclaimer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              MusicIcons.warning,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.disclaimer,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.third_party_plugin_dmca_notice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInstalled extends StatelessWidget {
  const _EmptyInstalled({required this.tab});

  /// 0 = all, 1 = metadata, 2 = audio source.
  final int tab;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (tab) {
      1 => context.l10n.metadata,
      2 => context.l10n.audio_source,
      _ => context.l10n.plugins,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Icon(
            Broken.element_4,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.no_installed_plugins(label),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => openMarketplace(context),
            icon: const Icon(Broken.element_4),
            label: Text(context.l10n.browse_marketplace),
          ),
        ],
      ),
    );
  }
}

class _PluginSkeletonCard extends StatelessWidget {
  const _PluginSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 220,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
