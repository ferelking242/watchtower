import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/default_plugin_picker.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/installed_plugin.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/utils/open_marketplace.dart';

/// Music plugins installed on this device.
///
/// The list is read from the plugin database, so it shows exactly what the user
/// installed from the Marketplace (or the plugins Watchtower ships) and nothing
/// else — no hardcoded catalogue, no placeholder providers. Installing,
/// updating and browsing all happen in the Marketplace, which is the single
/// entry point for every extension.
class SettingsMetadataProviderPage extends HookConsumerWidget {
  const SettingsMetadataProviderPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final query = useState<String>('');
    final plugins = ref.watch(metadataPluginsProvider);
    final state = plugins.asData?.value;

    final q = query.value.trim().toLowerCase();
    final installed = [
      for (final plugin in state?.plugins ?? const <PluginConfiguration>[])
        if (q.isEmpty ||
            plugin.name.toLowerCase().contains(q) ||
            plugin.author.toLowerCase().contains(q))
          plugin,
    ];

    return SettingsSubpageScaffold(
      title: context.l10n.plugins,
      searchHint: context.l10n.search,
      onSearchChanged: (value) => query.value = value,
      leading: const MusicBackButton(),
      slivers: [
        if (state == null)
          const SliverToBoxAdapter(child: _PluginsSkeleton())
        else if (installed.isEmpty)
          SliverToBoxAdapter(child: _EmptyInstalled(hasQuery: q.isNotEmpty))
        else ...[
          // Every row below is an installed plugin, so a section header saying
          // "Installed" only repeated what the page already guarantees.
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final plugin in installed)
                  MetadataInstalledPluginItem(
                    plugin: plugin,
                    isDefaultMetadata:
                        state.defaultMetadataPluginConfig?.slug == plugin.slug,
                    isDefaultAudioSource:
                        state.defaultAudioSourcePluginConfig?.slug ==
                        plugin.slug,
                  ),
              ],
            ),
          ),
          if (q.isEmpty)
            SliverToBoxAdapter(child: _DefaultsSection(state: state)),
        ],
        SliverToBoxAdapter(
          child: SectionCardWithHeading(
            heading: context.l10n.browse_marketplace,
            icon: Broken.shop,
            children: [
              ListTile(
                title: Text(context.l10n.browse_marketplace),
                subtitle: Text(context.l10n.plugins_install_in_marketplace),
                trailing: const Icon(Broken.arrow_right_3),
                onTap: () => openMarketplace(context),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Which plugin fills each slot, as one row per ability. Tapping a row opens
/// the picker for that slot, so switching provider no longer requires hunting
/// for the per-plugin overflow menu further up the page.
class _DefaultsSection extends ConsumerWidget {
  const _DefaultsSection({required this.state});

  final MetadataPluginState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCardWithHeading(
      heading: context.l10n.defaults,
      icon: Broken.setting_2,
      children: [
        _DefaultRow(
          icon: Broken.discount_shape,
          label: context.l10n.metadata,
          value: state.defaultMetadataPluginConfig?.name,
          onTap: () => showDefaultPluginPicker(
            context,
            ref,
            ability: PluginAbilities.metadata,
          ),
        ),
        _DefaultRow(
          icon: Broken.musicnote,
          label: context.l10n.audio_source,
          value: state.defaultAudioSourcePluginConfig?.name,
          onTap: () => showDefaultPluginPicker(
            context,
            ref,
            ability: PluginAbilities.audioSource,
          ),
        ),
      ],
    );
  }
}

class _DefaultRow extends StatelessWidget {
  const _DefaultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? context.l10n.none,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  color: value == null ? cs.onSurfaceVariant : cs.primary,
                  fontWeight: value == null ? null : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Broken.arrow_right_3,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInstalled extends StatelessWidget {
  const _EmptyInstalled({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          Icon(
            hasQuery ? Broken.search_normal : Broken.element_4,
            size: 34,
            color: cs.onSurfaceVariant.withValues(alpha: .5),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? context.l10n.nothing_found
                : context.l10n.no_installed_plugins(context.l10n.plugins),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PluginsSkeleton extends StatelessWidget {
  const _PluginsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar(double width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(120), const SizedBox(height: 6), bar(70)],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
