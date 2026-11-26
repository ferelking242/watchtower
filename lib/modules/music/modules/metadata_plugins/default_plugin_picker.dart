import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/utils/open_marketplace.dart';

/// Lets the user pick which installed plugin fills an ability slot.
///
/// The settings page used to print the current default as read-only text and
/// expect the user to find the per-plugin overflow menu, which was the single
/// most confusing part of the plugins screen. Tapping the row now lists every
/// installed plugin able to do the job.
Future<void> showDefaultPluginPicker(
  BuildContext context,
  WidgetRef ref, {
  required PluginAbilities ability,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DefaultPluginPickerSheet(ability: ability),
  );
}

class _DefaultPluginPickerSheet extends HookConsumerWidget {
  const _DefaultPluginPickerSheet({required this.ability});

  final PluginAbilities ability;

  bool get _isAudioSource => ability == PluginAbilities.audioSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final query = useState('');

    final pluginsState = ref.watch(metadataPluginsProvider).asData?.value;
    final current = _isAudioSource
        ? pluginsState?.defaultAudioSourcePluginConfig
        : pluginsState?.defaultMetadataPluginConfig;

    final candidates = [
      for (final plugin in pluginsState?.plugins ?? const <PluginConfiguration>[])
        if (plugin.abilities.contains(ability)) plugin,
    ];

    final q = query.value.trim().toLowerCase();
    final visible = [
      for (final plugin in candidates)
        if (q.isEmpty ||
            plugin.name.toLowerCase().contains(q) ||
            plugin.author.toLowerCase().contains(q))
          plugin,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              _isAudioSource
                  ? context.l10n.default_audio_source
                  : context.l10n.default_metadata_source,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _isAudioSource
                  ? context.l10n.set_default_audio_source
                  : context.l10n.set_default_metadata_source,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          if (candidates.length > 4)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (value) => query.value = value,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.search,
                  prefixIcon: const Icon(Broken.search_normal, size: 18),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Flexible(
            child: visible.isEmpty
                ? _EmptyState(hasQuery: q.isNotEmpty)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final plugin = visible[index];
                      return _PluginOption(
                        plugin: plugin,
                        selected: plugin.slug == current?.slug,
                        onTap: () async {
                          final notifier =
                              ref.read(metadataPluginsProvider.notifier);
                          if (_isAudioSource) {
                            await notifier.setDefaultAudioSourcePlugin(plugin);
                          } else {
                            await notifier.setDefaultMetadataPlugin(plugin);
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PluginOption extends StatelessWidget {
  const _PluginOption({
    required this.plugin,
    required this.selected,
    required this.onTap,
  });

  final PluginConfiguration plugin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.18)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          plugin.name.isEmpty ? '?' : plugin.name[0].toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        plugin.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${plugin.author} • v${plugin.version}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: selected
          ? Icon(Broken.tick_circle, color: cs.primary)
          : Icon(
              Broken.record_circle,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Broken.search_normal : Broken.element_4,
            size: 32,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? context.l10n.nothing_found
                : context.l10n.no_installed_plugins(context.l10n.plugins),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                openMarketplace(context);
              },
              icon: const Icon(Broken.shop, size: 18),
              label: Text(context.l10n.browse_marketplace),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
