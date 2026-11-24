import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/components/markdown/markdown.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/plugin_update_available_dialog.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/catalogue.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/support.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/updater/update_checker.dart';

/// One installed music plugin, rendered as a single compact settings row.
///
/// Everything comes from the installed archive (name, author, version,
/// abilities) plus app state (default slot, sign-in, update), so the row never
/// claims a plugin the user does not have. Abilities are icon-only with a
/// tooltip: a sentence like "This plugin scrobbles your music to generate your
/// listening history" would wrap to three lines and blow the row up in every
/// language.
class MetadataInstalledPluginItem extends HookConsumerWidget {
  final PluginConfiguration plugin;
  final bool isDefaultMetadata;
  final bool isDefaultAudioSource;

  const MetadataInstalledPluginItem({
    super.key,
    required this.plugin,
    required this.isDefaultMetadata,
    required this.isDefaultAudioSource,
  });

  @override
  Widget build(BuildContext context, ref) {
    final cs = Theme.of(context).colorScheme;
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final isDefault = isDefaultMetadata || isDefaultAudioSource;
    final needsAuth = plugin.abilities.contains(PluginAbilities.authentication);
    final scrobbles = plugin.abilities.contains(PluginAbilities.scrobbling);

    final isAuthenticated =
        (isDefaultMetadata &&
            ref.watch(metadataPluginAuthenticatedProvider).asData?.value ==
                true) ||
        (isDefaultAudioSource &&
            ref.watch(audioSourcePluginAuthenticatedProvider).asData?.value ==
                true);

    final updateAvailable = switch ((isDefaultMetadata, isDefaultAudioSource)) {
      (true, _) => ref.watch(metadataPluginUpdateCheckerProvider),
      (false, true) => ref.watch(audioSourcePluginUpdateCheckerProvider),
      _ => null,
    };
    final update = updateAvailable?.asData?.value;

    final repoUrl = plugin.repository != null
        ? Uri.tryParse(plugin.repository!)
        : null;
    final isOfficial =
        repoUrl?.host == "github.com" &&
        repoUrl?.pathSegments.firstOrNull == kOfficialPluginOwner;

    return InkWell(
      onTap: needsAuth ? () => _toggleAuth(ref, isAuthenticated) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            _PluginLogo(
              logo: useMemoized(() => pluginsNotifier.getLogoPath(plugin), [
                plugin.slug,
                plugin.version,
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plugin.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 5),
                        Icon(Broken.tick_circle, size: 13, color: cs.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      isOfficial ? 'Watchtower' : context.l10n.third_party,
                      'v${plugin.version}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (scrobbles)
              Tooltip(
                message: context.l10n.supports_scrobbling,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Broken.musicnote,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (needsAuth)
              Tooltip(
                message: isAuthenticated
                    ? context.l10n.logout
                    : context.l10n.plugin_requires_authentication,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => _toggleAuth(ref, isAuthenticated),
                  icon: Icon(
                    isAuthenticated ? Broken.logout : Broken.login,
                    color: isAuthenticated ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (update != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: context.l10n.update,
                icon: const Icon(Broken.refresh),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => MetadataPluginUpdateAvailableDialog(
                    plugin: plugin,
                    update: update,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Broken.more_2, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onSelected: (value) async {
                switch (value) {
                  case "metadata":
                    await pluginsNotifier.setDefaultMetadataPlugin(plugin);
                  case "audio":
                    await pluginsNotifier.setDefaultAudioSourcePlugin(plugin);
                  case "support":
                    final text =
                        ref
                            .read(metadataPluginSupportTextProvider)
                            .asData
                            ?.value ??
                        "";
                    if (text.isEmpty || !context.mounted) return;
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.l10n.support),
                        content: AppMarkdown(data: text),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.close),
                          ),
                        ],
                      ),
                    );
                  case "repo":
                    if (repoUrl != null) launchUrl(repoUrl);
                  case "remove":
                    await pluginsNotifier.removePlugin(plugin);
                }
              },
              itemBuilder: (context) => [
                if (plugin.abilities.contains(PluginAbilities.metadata))
                  PopupMenuItem(
                    value: "metadata",
                    enabled: !isDefaultMetadata,
                    child: _MenuRow(
                      icon: Broken.discount_shape,
                      label: context.l10n.metadata,
                      checked: isDefaultMetadata,
                    ),
                  ),
                if (plugin.abilities.contains(PluginAbilities.audioSource))
                  PopupMenuItem(
                    value: "audio",
                    enabled: !isDefaultAudioSource,
                    child: _MenuRow(
                      icon: Broken.musicnote,
                      label: context.l10n.audio_source,
                      checked: isDefaultAudioSource,
                    ),
                  ),
                if (isDefault)
                  PopupMenuItem(
                    value: "support",
                    child: _MenuRow(
                      icon: Broken.info_circle,
                      label: context.l10n.support,
                    ),
                  ),
                if (repoUrl != null)
                  PopupMenuItem(
                    value: "repo",
                    child: _MenuRow(icon: Broken.link, label: repoUrl.host),
                  ),
                PopupMenuItem(
                  value: "remove",
                  child: _MenuRow(
                    icon: Broken.trash,
                    label: context.l10n.delete,
                    color: cs.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAuth(WidgetRef ref, bool isAuthenticated) async {
    // Only the default plugin instance is live, so signing in from another row
    // promotes it first; otherwise the button would silently do nothing.
    if (!isDefaultMetadata && !isDefaultAudioSource) {
      final notifier = ref.read(metadataPluginsProvider.notifier);
      if (plugin.abilities.contains(PluginAbilities.metadata)) {
        await notifier.setDefaultMetadataPlugin(plugin);
      } else if (plugin.abilities.contains(PluginAbilities.audioSource)) {
        await notifier.setDefaultAudioSourcePlugin(plugin);
      }
    }

    final provider = isDefaultAudioSource && !isDefaultMetadata
        ? audioSourcePluginProvider
        : metadataPluginProvider;
    final snapshot = await ref.read(provider.future);
    if (snapshot == null) return;

    if (isAuthenticated) {
      await snapshot.auth.logout();
    } else {
      await snapshot.auth.authenticate();
    }
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool checked;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.color,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        if (checked)
          Icon(
            Broken.tick_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

/// Brand icon for a plugin: the archive's own logo.png when it ships one, else
/// a neutral plugin glyph. A missing or unreadable image falls back to the
/// glyph, so the row never shows a broken icon.
class _PluginLogo extends StatelessWidget {
  final Future<File?> logo;

  const _PluginLogo({required this.logo});

  Widget _placeholder(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(MusicIcons.plugin, size: 16),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: logo,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context),
            ),
          );
        }
        return _placeholder(context);
      },
    );
  }
}
