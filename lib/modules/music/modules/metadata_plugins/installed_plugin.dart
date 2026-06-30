import 'package:flutter/material.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:watchtower/modules/music/collections/spotube_icons.dart';
  import 'package:watchtower/modules/music/components/markdown/markdown.dart';
  import 'package:watchtower/modules/music/extensions/constrains.dart';
  import 'package:watchtower/modules/music/extensions/context.dart';
  import 'package:watchtower/modules/music/models/metadata/metadata.dart';
  import 'package:watchtower/modules/music/modules/metadata_plugins/plugin_update_available_dialog.dart';
  import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
  import 'package:watchtower/modules/music/provider/metadata_plugin/core/support.dart';
  import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
  import 'package:watchtower/modules/music/provider/metadata_plugin/updater/update_checker.dart';
  import 'package:url_launcher/url_launcher.dart';

  final validAbilities = {
    PluginAbilities.metadata: ("Metadata", SpotubeIcons.album),
    PluginAbilities.audioSource: ("Audio Source", SpotubeIcons.music),
  };

  Widget _withTheme(ThemeData data, Widget child) =>
      Theme(data: data, child: child);

  Widget _badgePrimary(BuildContext context,
      {Widget? leading, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: leading != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 14,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  child: leading,
                ),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                  child: child,
                ),
              ],
            )
          : DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
              child: child,
            ),
    );
  }

  Widget _badgeSecondary(
    BuildContext context, {
    Widget? leading,
    required Widget child,
    VoidCallback? onPressed,
  }) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: leading != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 14,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: leading,
                ),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                  child: child,
                ),
              ],
            )
          : DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
              child: child,
            ),
    );
    if (onPressed != null) {
      return GestureDetector(onTap: onPressed, child: content);
    }
    return content;
  }

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
      final mediaQuery = MediaQuery.sizeOf(context);

      final metadataPlugin = ref.watch(metadataPluginProvider);
      final audioSourcePlugin = ref.watch(audioSourcePluginProvider);
      final pluginSnapshot = switch ((isDefaultMetadata, isDefaultAudioSource)) {
        (true, _) => metadataPlugin,
        (false, true) => audioSourcePlugin,
        _ => null,
      };

      final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

      final requiresAuth = (isDefaultMetadata || isDefaultAudioSource) &&
          plugin.abilities.contains(PluginAbilities.authentication);
      final supportsScrobbling = isDefaultMetadata &&
          plugin.abilities.contains(PluginAbilities.scrobbling);

      final isMetadataAuthenticatedSnapshot =
          ref.watch(metadataPluginAuthenticatedProvider);
      final isAudioSourceAuthenticatedSnapshot =
          ref.watch(audioSourcePluginAuthenticatedProvider);
      final isAuthenticated = (isDefaultMetadata &&
              isMetadataAuthenticatedSnapshot.asData?.value == true) ||
          (isDefaultAudioSource &&
              isAudioSourceAuthenticatedSnapshot.asData?.value == true);

      final metadataUpdateAvailable =
          ref.watch(metadataPluginUpdateCheckerProvider);
      final audioSourceUpdateAvailable =
          ref.watch(audioSourcePluginUpdateCheckerProvider);
      final updateAvailable = switch ((isDefaultMetadata, isDefaultAudioSource)) {
        (true, _) => metadataUpdateAvailable,
        (false, true) => audioSourceUpdateAvailable,
        _ => null,
      };
      final hasUpdate = updateAvailable?.asData?.value != null;

      final themeData = Theme.of(context);

      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            FutureBuilder(
              future: pluginsNotifier.getLogoPath(plugin),
              builder: (context, snapshot) {
                final repoUrl = plugin.repository != null
                    ? Uri.tryParse(plugin.repository!)
                    : null;
                final repoOwner = repoUrl?.pathSegments.firstOrNull;

                final isOfficial =
                    repoUrl?.host == "github.com" && repoOwner == "KRTirtho";

                return ListTile(
                  leading: snapshot.hasData
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            snapshot.data!,
                            width: 36,
                            height: 36,
                          ),
                        )
                      : Container(
                          height: 36,
                          width: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(SpotubeIcons.plugin),
                        ),
                  title: Text(plugin.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text(plugin.description),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final ability in plugin.abilities)
                            if (validAbilities.keys.contains(ability))
                              _badgeSecondary(
                                context,
                                leading: Icon(validAbilities[ability]!.$2),
                                child: Text(validAbilities[ability]!.$1),
                              ),
                        ],
                      ),
                      if (repoUrl != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isOfficial)
                              _badgePrimary(
                                context,
                                leading: const Icon(SpotubeIcons.done),
                                child: Text(context.l10n.official),
                              )
                            else ...[
                              Text(context.l10n.author_name(plugin.author)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 4,
                                  children: [
                                    const Icon(SpotubeIcons.warning,
                                        size: 14, color: Colors.white),
                                    Text(
                                      context.l10n.third_party,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            _badgeSecondary(
                              context,
                              leading: const Icon(SpotubeIcons.connect),
                              child: Text(repoUrl.host),
                              onPressed: () {
                                launchUrl(repoUrl);
                              },
                            ),
                            _badgeSecondary(
                              context,
                              child: Padding(
                                padding: const EdgeInsets.all(1),
                                child: Text(
                                  "${context.l10n.version}: ${plugin.version}",
                                ),
                              ),
                            ),
                          ],
                        )
                    ],
                  ),
                  trailing: IconButton(
                    onPressed: () async {
                      await pluginsNotifier.removePlugin(plugin);
                    },
                    icon: const Icon(
                      SpotubeIcons.trash,
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
            if ((requiresAuth && !isAuthenticated) ||
                hasUpdate ||
                supportsScrobbling)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  spacing: 12,
                  children: [
                    if (requiresAuth && !isAuthenticated)
                      Row(
                        spacing: 8,
                        children: [
                          const Icon(SpotubeIcons.warning, color: Colors.yellow),
                          Text(context.l10n.plugin_requires_authentication),
                        ],
                      ),
                    if (hasUpdate)
                      SizedBox(
                        width: double.infinity,
                        child: ListTile(
                          leading: const Icon(SpotubeIcons.update),
                          title: Text(context.l10n.update_available),
                          subtitle: Text(
                            updateAvailable!.asData!.value!.version,
                          ),
                          trailing: FilledButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _withTheme(
                                  themeData,
                                  MetadataPluginUpdateAvailableDialog(
                                    plugin: plugin,
                                    update: updateAvailable.asData!.value!,
                                  ),
                                ),
                              );
                            },
                            child: Text(context.l10n.update),
                          ),
                        ),
                      ),
                    if (supportsScrobbling)
                      SizedBox(
                        width: double.infinity,
                        child: ListTile(
                          leading: const Icon(SpotubeIcons.info),
                          title: Text(context.l10n.supports_scrobbling),
                          subtitle: Text(context.l10n.plugin_scrobbling_info),
                        ),
                      )
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (plugin.abilities.contains(PluginAbilities.metadata))
                      TextButton(
                        onPressed: !isDefaultMetadata
                            ? () async {
                                await pluginsNotifier
                                    .setDefaultMetadataPlugin(plugin);
                              }
                            : null,
                        child: Text(
                          isDefaultMetadata
                              ? context.l10n.default_metadata_source
                              : context.l10n.set_default_metadata_source,
                        ),
                      ),
                    if (plugin.abilities.contains(PluginAbilities.audioSource))
                      TextButton(
                        onPressed: !isDefaultAudioSource
                            ? () async {
                                await pluginsNotifier
                                    .setDefaultAudioSourcePlugin(plugin);
                              }
                            : null,
                        child: Text(
                          isDefaultAudioSource
                              ? context.l10n.default_audio_source
                              : context.l10n.set_default_audio_source,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize:
                      mediaQuery.smAndUp ? MainAxisSize.min : MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    if (isDefaultMetadata || isDefaultAudioSource)
                      Consumer(builder: (context, ref, _) {
                        final metadataSupportTextSnapshot =
                            ref.watch(metadataPluginSupportTextProvider);
                        final audioSourceSupportTextSnapshot =
                            ref.watch(audioSourcePluginSupportTextProvider);

                        final supportTextSnapshot =
                            switch ((isDefaultMetadata, isDefaultAudioSource)) {
                          (true, _) => metadataSupportTextSnapshot,
                          (false, true) => audioSourceSupportTextSnapshot,
                          _ => null,
                        };

                        if ((supportTextSnapshot?.asData?.value?.isEmpty ??
                            true)) {
                          return const SizedBox.shrink();
                        }

                        return TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => _withTheme(
                                themeData,
                                AlertDialog(
                                  title: Text(context.l10n.support),
                                  content: AppMarkdown(
                                    data: supportTextSnapshot!.asData!.value!,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                      },
                                      child: Text(context.l10n.close),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(SpotubeIcons.info),
                          label: Text(context.l10n.support),
                        );
                      }),
                    if ((isDefaultMetadata || isDefaultAudioSource) &&
                        requiresAuth &&
                        !isAuthenticated)
                      FilledButton.icon(
                        onPressed: pluginSnapshot?.asData?.value != null
                            ? () async {
                                final plugin = pluginSnapshot?.asData?.value;
                                if (plugin == null) return;
                                await plugin.auth.authenticate();
                              }
                            : null,
                        icon: pluginSnapshot?.isLoading == true
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(SpotubeIcons.login),
                        label: Text(context.l10n.login),
                      )
                    else if ((isDefaultMetadata || isDefaultAudioSource) &&
                        requiresAuth &&
                        isAuthenticated)
                      FilledButton.icon(
                        onPressed: () async {
                          await pluginSnapshot?.asData?.value?.auth.logout();
                        },
                        icon: const Icon(SpotubeIcons.logout),
                        label: Text(context.l10n.logout),
                      ),
                  ],
                )
              ],
            )
          ],
        ),
      );
    }
  }
  